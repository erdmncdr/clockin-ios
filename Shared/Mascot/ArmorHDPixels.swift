import CoreGraphics
import Foundation

struct ArmorHDPixels {
  struct Cell {
    var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0, a: UInt8 = 0
    var kind: UInt8 = 0
    var color: ArmorHDColor { .init(r: Double(r) / 255, g: Double(g) / 255, b: Double(b) / 255) }
  }
  var cells: [Cell]
  let anchors: ArmorHDAnchors
  let frame: String

  init(_ source: CGImage, frame: String, anchors: ArmorHDAnchors) {
    self.anchors = anchors
    self.frame = frame
    let n = 157
    var bytes = [UInt8](repeating: 0, count: n * n * 4)
    bytes.withUnsafeMutableBytes { data in
      let c = CGContext(
        data: data.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      c.interpolationQuality = .none
      c.draw(source, in: CGRect(x: 0, y: 0, width: n, height: n))
    }
    cells = (0..<n * n).map { i in
      let p = i * 4
      let a = Int(bytes[p + 3])
      func straight(_ c: Int) -> UInt8 { a == 0 ? 0 : UInt8(min(255, Int(bytes[p + c]) * 255 / a)) }
      return Cell(r: straight(0), g: straight(1), b: straight(2), a: UInt8(a))
    }
    for i in cells.indices {
      let p = cells[i]
      let x = Double(i % n) * 2
      let y = Double(i / n) * 2
      guard p.a > 100 else {
        cells[i] = Cell()
        continue
      }
      let hi = Double(max(p.r, p.g, p.b))
      let lo = Double(min(p.r, p.g, p.b))
      let sat = (hi - lo) / max(1, hi)
      let prop =
        (frame.hasPrefix("c") && x < 130 && y > 176)
        || (frame.hasPrefix("t") && ((x > 198 && y > 181) || (y > 234 && x > 94)))
      let symbol =
        !frame.hasPrefix("pose") && ["a", "p", "z"].contains(String(frame.prefix(1)))
        && x > anchors.head[0] + 32 && x < anchors.head[0] + 62
        && y > anchors.head[1] - 24 && y < anchors.head[1] + 20
      if symbol && sat > 0.25
        && (frame.hasPrefix("a")
          ? (p.r > 180 && p.g < 90) : (Int(p.b) > Int(p.r) + 20 && Int(p.g) > Int(p.r) + 15))
      {
        cells[i].kind = 8
      } else if prop {
        cells[i].kind = 5
      } else if Int(p.g) - Int(p.r) > 30 && Int(p.b) - Int(p.r) > 30 && hi > 100 {
        cells[i].kind = 4
      } else if hi < 80 {
        cells[i].kind = 1
      } else if sat < 0.55 {
        cells[i].kind = hi < 135 ? 7 : 2
      } else if p.r > p.g && p.r > p.b {
        cells[i].kind = 3
      } else {
        cells[i].kind = 5
      }
    }
    // The visor is a hole in the colour mask, but not in the helmet's dome.
    let vx = Int(anchors.visor[0] / 2)
    let vy = Int(anchors.visor[1] / 2)
    var candidates = [Int]()
    for y in max(0, vy - 7)...min(n - 1, vy + 7) {
      for x in max(0, vx - 7)...min(n - 1, vx + 7) {
        if cells[y * n + x].kind == 1 { candidates.append(y * n + x) }
      }
    }
    if let start = candidates.min(by: {
      abs($0 % n - vx) + abs($0 / n - vy) < abs($1 % n - vx) + abs($1 / n - vy)
    }) {
      var queue = [start]
      var cursor = 0
      cells[start].kind = 6
      while cursor < queue.count {
        let i = queue[cursor]
        cursor += 1
        for j in [i - 1, i + 1, i - n, i + n]
        where j >= 0 && j < cells.count && abs(j % n - i % n) <= 1 {
          if cells[j].kind == 1 {
            cells[j].kind = 6
            queue.append(j)
          }
        }
      }
    }
    // Expressions can be grey or white as well as cyan. Keep every enclosed stroke emissive.
    for y in 0..<n {
      let row = (0..<n).filter { cells[y * n + $0].kind == 6 }
      if let left = row.first, let right = row.last, right > left {
        for x in left...right where cells[y * n + x].kind != 6 && cells[y * n + x].kind != 0 {
          cells[y * n + x].kind = 4
        }
      }
    }
  }

  // Source values describe materials, not relief. A shadow within a plate must
  // never become a second surface normal or a dark hole in the metal.
  func geometry() -> ArmorHDGeometry {
    let w = 157
    var labels = cells.map { $0.kind == 7 ? UInt8(1) : $0.kind }
    let mug = ArmorHDMug.pose(frame)
    let hands =
      ArmorHDMug.hands(frame)
      ?? (frame == "pose2"
        ? [[134.0, 49.0], [161.0, 54.0]] : [anchors.handL, anchors.handR].compactMap { $0 })
    for i in labels.indices {
      let x = Double(i % w) * 2
      let y = Double(i / w) * 2
      // Props are reconstructed separately in their original coordinate space.
      if labels[i] == 5 { labels[i] = 0 }
      if let mug {
        let mask = CGRect(
          x: mug.minX - 2, y: mug.minY - 3, width: mug.width + 18, height: mug.height + 5)
        if mask.contains(CGPoint(x: x, y: y)) { labels[i] = 0 }
        if ArmorHDMug.raised(frame) && labels[i] == 4 && (174...187).contains(x)
          && (99...145).contains(y)
        {
          labels[i] = 6
        }
      }
      for h in hands where hypot(x - h[0], y - h[1]) < 12 {
        if labels[i] != 0 { labels[i] = 1 }
      }
    }
    // Majority filtering only changes plate/joint classes. Preserve narrow trim
    // and expression strokes, and preserve the silhouette's connected outline.
    for _ in 0..<2 {
      let old = labels
      for y in 1..<w - 1 {
        for x in 1..<w - 1 {
          let i = y * w + x
          guard old[i] == 1 || old[i] == 2 else { continue }
          var metal = 0
          var dark = 0
          for dy in -1...1 {
            for dx in -1...1 {
              let k = old[i + dy * w + dx]
              if k == 2 { metal += 1 }
              if k == 1 { dark += 1 }
            }
          }
          if metal == 9 { labels[i] = 2 } else if dark >= 7 { labels[i] = 1 }
        }
      }
    }
    // Merge tiny islands into the adjacent material with the longest border.
    // Empty space and visor/eye glyphs are excluded from this denoising.
    for region in Self.components(labels, width: w) where region.count < 12 {
      let kind = labels[region[0]]
      guard kind == 2 else { continue }
      var neighbours = [Int](repeating: 0, count: 8)
      for i in region {
        for j in [i - 1, i + 1, i - w, i + w]
        where j >= 0 && j < labels.count && abs(j % w - i % w) <= 1 {
          let k = labels[j]
          if k != kind && (k == 1 || k == 2 || k == 3) { neighbours[Int(k)] += 1 }
        }
      }
      if let best = (1...3).max(by: { neighbours[$0] < neighbours[$1] }), neighbours[best] > 0 {
        for i in region { labels[i] = UInt8(best) }
      }
    }
    // Seated hands and the overhead stretch can touch adjacent white plates
    // in the art grid. Split those semantic parts before fitting convex shells.
    for i in labels.indices where labels[i] == 2 {
      let x = i % w * 2
      let y = i / w * 2
      if frame.hasPrefix("c") && y >= 235 { labels[i] = x < 181 ? 10 : 11 }
      if frame == "pose2" && y < 77 { labels[i] = 12 }
    }
    let symbolCells = labels.indices.filter { labels[$0] == 8 }
    var symbol: CGRect?
    if let first = symbolCells.first {
      var rect = CGRect(x: first % w * 2, y: first / w * 2, width: 2, height: 2)
      for i in symbolCells {
        rect = rect.union(CGRect(x: i % w * 2, y: i / w * 2, width: 2, height: 2))
        labels[i] = 0
      }
      symbol = rect
    }
    let silhouette = labels.map { $0 == 0 ? UInt8(0) : UInt8(1) }
    let base = Self.paths(silhouette, width: w, tolerance: 0.85)
    let parts = Self.paths(labels, width: w, tolerance: 0.85)
    return ArmorHDGeometry(
      base: base.map(\.path), parts: parts, hands: hands, symbol: symbol, frame: frame, mug: mug)
  }

  static func components(_ labels: [UInt8], width w: Int) -> [[Int]] {
    var seen = [Bool](repeating: false, count: labels.count)
    var result = [[Int]]()
    for start in labels.indices where labels[start] != 0 && !seen[start] {
      var queue = [start]
      var cursor = 0
      seen[start] = true
      while cursor < queue.count {
        let i = queue[cursor]
        cursor += 1
        for j in [i - 1, i + 1, i - w, i + w]
        where j >= 0 && j < labels.count && abs(j % w - i % w) <= 1 {
          if !seen[j] && labels[j] == labels[start] {
            seen[j] = true
            queue.append(j)
          }
        }
      }
      result.append(queue)
    }
    return result
  }

  struct Part {
    let kind: UInt8
    let path: CGPath
  }
  // Trace directed cell edges, simplify the staircase, then fit a continuous
  // cubic contour. All this is resolution and skin independent and cached.
  static func paths(_ labels: [UInt8], width w: Int, tolerance: CGFloat) -> [Part] {
    var result = [Part]()
    let stride = w + 1
    for region in components(labels, width: w) {
      let kind = labels[region[0]]
      guard region.count >= (kind == 4 ? 1 : 3) else { continue }
      var edges = [Int: [Int]]()
      func edge(_ a: Int, _ b: Int) { edges[a, default: []].append(b) }
      for i in region {
        let x = i % w
        let y = i / w
        let a = y * stride + x
        if y == 0 || labels[i - w] != kind { edge(a, a + 1) }
        if x == w - 1 || labels[i + 1] != kind { edge(a + 1, a + stride + 1) }
        if y == w - 1 || labels[i + w] != kind { edge(a + stride + 1, a + stride) }
        if x == 0 || labels[i - 1] != kind { edge(a + stride, a) }
      }
      // Plates are formed, convex shells. Their source holes are painted
      // grime or highlights, not dents. Keep separate connected plates but
      // regularize each outline before adding a single domed reflection.
      if kind == 2 || kind == 3 || kind == 6 || kind >= 10 {
        let vertices = edges.keys.map {
          CGPoint(x: CGFloat($0 % stride) * 2, y: CGFloat($0 / stride) * 2)
        }
        let hull = convexHull(vertices)
        if hull.count > 2 {
          result.append(
            Part(kind: kind >= 10 ? 2 : kind, path: ArmorHDShape.smooth(hull, tension: 0.45)))
        }
        continue
      }
      let path = CGMutablePath()
      // Stable starting order also makes cache misses byte deterministic.
      for start in edges.keys.sorted() {
        while edges[start]?.isEmpty == false {
          var loop = [CGPoint]()
          var at = start
          repeat {
            loop.append(CGPoint(x: at % stride, y: at / stride))
            guard let next = edges[at]?.popLast() else { break }
            at = next
          } while at != start && loop.count < region.count * 4 + 4
          guard loop.count >= 4 else { continue }
          // RDP needs two open halves for a closed contour.
          // Low-pass the contour positions, never the shaded colour.
          let original = loop
          let radius = kind == 4 ? 2 : 3
          for i in loop.indices {
            var x: CGFloat = 0
            var y: CGFloat = 0
            for d in -radius...radius {
              let p = original[(i + d + original.count) % original.count]
              x += p.x
              y += p.y
            }
            loop[i] = CGPoint(x: x / CGFloat(2 * radius + 1), y: y / CGFloat(2 * radius + 1))
          }
          let half = loop.count / 2
          let epsilon: CGFloat = kind == 4 ? 0.35 : tolerance
          let a = simplify(Array(loop[0...half]), epsilon)
          let b = simplify(Array(loop[half...]) + [loop[0]], epsilon)
          let points = (a.dropLast() + b.dropLast()).map { CGPoint(x: $0.x * 2, y: $0.y * 2) }
          path.addPath(ArmorHDShape.smooth(Array(points), tension: kind == 4 ? 0.35 : 0.5))
        }
      }
      result.append(Part(kind: kind, path: path))
    }
    return result
  }
  static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
    let points = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
    func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
    var lower = [CGPoint]()
    var upper = [CGPoint]()
    for p in points {
      while lower.count >= 2 && cross(lower[lower.count - 2], lower.last!, p) <= 0 {
        lower.removeLast()
      }
      lower.append(p)
    }
    for p in points.reversed() {
      while upper.count >= 2 && cross(upper[upper.count - 2], upper.last!, p) <= 0 {
        upper.removeLast()
      }
      upper.append(p)
    }
    return Array(lower.dropLast()) + Array(upper.dropLast())
  }
  static func simplify(_ points: [CGPoint], _ epsilon: CGFloat) -> [CGPoint] {
    guard points.count > 2, let a = points.first, let b = points.last else { return points }
    let dx = b.x - a.x
    let dy = b.y - a.y
    let length = max(0.0001, dx * dx + dy * dy)
    var distance: CGFloat = 0
    var index = 0
    for i in 1..<points.count - 1 {
      let p = points[i]
      let u = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length))
      let d = hypot(p.x - a.x - u * dx, p.y - a.y - u * dy)
      if d > distance {
        distance = d
        index = i
      }
    }
    if distance <= epsilon { return [a, b] }
    return Array(simplify(Array(points[...index]), epsilon).dropLast())
      + simplify(Array(points[index...]), epsilon)
  }
}

struct ArmorHDGeometry {
  let base: [CGPath]
  let parts: [ArmorHDPixels.Part]
  let hands: [[Double]]
  let symbol: CGRect?
  let frame: String
  let mug: CGRect?

  func draw(in c: CGContext, style: ArmorHDStyle) {
    let s = ArmorHDShade(c: c, rim: style.light)
    for p in base {
      let b = p.boundingBoxOfPath
      s.gradient(
        p,
        [
          ArmorHDColor(r: 0.065, g: 0.085, b: 0.12).cg,
          ArmorHDColor(r: 0.014, g: 0.02, b: 0.032).cg,
        ],
        [0, 1], CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.maxY))
      s.stroke(p, ArmorHDColor.black.alpha(0.85), 0.8)
    }
    for part in parts where part.kind == 2 || part.kind == 3 {
      s.part(
        part.path, part.kind == 3 ? style.trim : style.plate, polish: 1.2,
        shadow: 0.45)
    }
    for part in parts where part.kind == 6 {
      let b = part.path.boundingBoxOfPath
      s.gradient(
        part.path,
        [
          ArmorHDColor(r: 0.065, g: 0.13, b: 0.18).cg,
          ArmorHDColor(r: 0.008, g: 0.015, b: 0.026).cg,
        ],
        [0, 1], CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.midX, y: b.maxY))
      s.stroke(part.path, ArmorHDColor.black.alpha(0.9), 1)
    }
    for part in parts where part.kind == 4 {
      c.saveGState()
      c.setShadow(offset: .zero, blur: 3, color: style.light.alpha(0.7))
      s.fill(part.path, style.light.mix(.white, 0.8).cg)
      s.stroke(part.path, style.light.mix(.white, 0.8).cg, 0.9)
      c.restoreGState()
    }
  }

  func drawHands(in c: CGContext, style: ArmorHDStyle) {
    let s = ArmorHDShade(c: c, rim: style.light)
    for hand in hands {
      let x = hand[0]
      let y = hand[1]
      let gauntlet = ArmorHDShape.smooth(
        ArmorHDShape.points([
          (x - 10, y - 7), (x - 5, y - 11), (x + 6, y - 9), (x + 11, y - 3), (x + 9, y + 8),
          (x - 4, y + 10), (x - 11, y + 4),
        ]))
      s.part(gauntlet, style.plate, polish: 1.3, shadow: 0.6)
      let ridge = CGMutablePath()
      ridge.move(to: CGPoint(x: x - 8, y: y - 3))
      ridge.addQuadCurve(to: CGPoint(x: x + 8, y: y - 3), control: CGPoint(x: x, y: y - 9))
      s.stroke(ridge, style.trim.metal(0.22).cg, 1.5)
      s.stroke(s.translated(ridge, 0, -0.8), style.trim.metal(1).cg, 1.1)
      for k in [-1.0, 0, 1] {
        let seam = CGMutablePath()
        seam.move(to: CGPoint(x: x + k * 4, y: y - 3))
        seam.addLine(to: CGPoint(x: x + k * 4 + 1, y: y + 3))
        s.stroke(seam, ArmorHDColor.black.alpha(0.28), 0.65)
      }
    }
  }
  func drawSymbols(in c: CGContext, style: ArmorHDStyle) {
    let s = ArmorHDShade(c: c, rim: style.light)
    if let original = symbol {
      let b = original.offsetBy(dx: 8, dy: -18)
      let p = CGMutablePath()
      if frame.hasPrefix("z") {
        for j in 0..<3 {
          let size = CGFloat(3 + j)
          let x = b.minX + CGFloat(j) * 6
          let y = b.maxY - CGFloat(j) * 6 - 3
          p.move(to: CGPoint(x: x, y: y))
          p.addLine(to: CGPoint(x: x + size, y: y))
          p.addLine(to: CGPoint(x: x, y: y + size))
          p.addLine(to: CGPoint(x: x + size, y: y + size))
        }
        s.glow(p, width: 0.65, strength: 0.8)
      } else if frame.hasPrefix("a") {
        for sx: CGFloat in [-1, 1] {
          for sy: CGFloat in [-1, 1] {
            p.move(to: CGPoint(x: b.midX + sx * 6, y: b.midY + sy * 2))
            p.addQuadCurve(
              to: CGPoint(x: b.midX + sx * 2, y: b.midY + sy * 6),
              control: CGPoint(x: b.midX + sx * 2, y: b.midY + sy * 2))
          }
        }
        ArmorHDShade(c: c, rim: ArmorHDColor(r: 1, g: 0.16, b: 0.09)).glow(
          p, width: 1, strength: 0.95)
      } else {
        p.addPath(
          ArmorHDShape.smooth(
            ArmorHDShape.points([
              (b.midX, b.minY), (b.midX + 2, b.midY - 2), (b.maxX, b.midY),
              (b.midX + 2, b.midY + 2),
              (b.midX, b.maxY), (b.midX - 2, b.midY + 2), (b.minX, b.midY),
              (b.midX - 2, b.midY - 2),
            ]), tension: 0.18))
        s.glow(p, width: 0.8, strength: 1)
        s.fill(p, style.light.mix(.white, 0.8).cg)
      }
    }
  }

}

// Semantic prop poses measured from the source ceramic silhouettes. These cover
// the complete coffee sequence, including the lift, sip and return to the floor.
enum ArmorHDMug {
  static func raised(_ frame: String) -> Bool { ["c07", "c08", "c09", "c12"].contains(frame) }
  static func pose(_ frame: String) -> CGRect? {
    guard frame.hasPrefix("c") else { return nil }
    if raised(frame) { return CGRect(x: 154, y: 145, width: 44, height: 52) }
    if ["c10", "c11"].contains(frame) { return CGRect(x: 148, y: 188, width: 44, height: 48) }
    if ["c06", "c13"].contains(frame) { return CGRect(x: 42, y: 220, width: 42, height: 50) }
    return CGRect(x: 62, y: 218, width: 42, height: 50)
  }
  static func hands(_ frame: String) -> [[Double]]? {
    if raised(frame) { return [[146, 174], [207, 174]] }
    if ["c10", "c11"].contains(frame) { return [[138, 214], [201, 214]] }
    if ["c06", "c13"].contains(frame) { return [[89, 211], [189, 229]] }
    return nil
  }
}
