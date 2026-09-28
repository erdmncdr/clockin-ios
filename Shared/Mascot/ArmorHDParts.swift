import CoreGraphics
import Foundation

enum ArmorHDShape {
  static func smooth(_ points: [CGPoint], tension: CGFloat = 0.5) -> CGPath {
    let path = CGMutablePath()
    let n = points.count
    guard n > 2 else { return path }
    path.move(to: points[0])
    for i in 0..<n {
      let a = points[(i + n - 1) % n]
      let b = points[i]
      let c = points[(i + 1) % n]
      let d = points[(i + 2) % n]
      let k = tension / 3
      path.addCurve(
        to: c, control1: .init(x: b.x + (c.x - a.x) * k, y: b.y + (c.y - a.y) * k),
        control2: .init(x: c.x - (d.x - b.x) * k, y: c.y - (d.y - b.y) * k))
    }
    path.closeSubpath()
    return path
  }
  static func poly(_ points: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    p.addLines(between: points)
    p.closeSubpath()
    return p
  }
  static func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), transform: nil)
  }
  static func points(_ values: [(CGFloat, CGFloat)]) -> [CGPoint] {
    values.map { .init(x: $0.0, y: $0.1) }
  }
  static func feather(_ base: CGPoint, _ tip: CGPoint, width: CGFloat) -> CGPath {
    let dx = tip.x - base.x
    let dy = tip.y - base.y
    let length = max(0.001, hypot(dx, dy))
    func at(_ f: CGFloat, _ across: CGFloat) -> CGPoint {
      .init(x: base.x + dx * f - dy / length * across, y: base.y + dy * f + dx / length * across)
    }
    return smooth([
      base, at(0.3, width * 0.36), at(0.62, width / 2), at(0.9, width * 0.34), tip,
      at(0.9, -width * 0.34), at(0.62, -width / 2), at(0.3, -width * 0.36),
    ])
  }
}

struct ArmorHDShade {
  let c: CGContext
  let rim: ArmorHDColor
  func fill(_ path: CGPath, _ color: CGColor) {
    c.addPath(path)
    c.setFillColor(color)
    c.fillPath()
  }
  func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat) {
    c.addPath(path)
    c.setStrokeColor(color)
    c.setLineWidth(width)
    c.setLineCap(.round)
    c.strokePath()
  }
  func gradient(
    _ path: CGPath, _ colors: [CGColor], _ stops: [CGFloat], _ start: CGPoint, _ end: CGPoint
  ) {
    c.saveGState()
    c.addPath(path)
    c.clip()
    let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: stops)!
    c.drawLinearGradient(
      gradient, start: start, end: end,
      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    c.restoreGState()
  }
  func translated(_ path: CGPath, _ x: CGFloat, _ y: CGFloat) -> CGPath {
    var t = CGAffineTransform(translationX: x, y: y)
    return path.copy(using: &t)!
  }
  func part(
    _ path: CGPath, _ tone: ArmorHDTone, pale: Bool = false, polish: Double = 1,
    shadow: CGFloat = 1, softRelief: Bool = false
  ) {
    let b = path.boundingBoxOfPath
    let tall = b.height > b.width * 1.6
    let wide = b.width > b.height * 1.6
    if softRelief {
      c.saveGState()
      c.setShadow(
        offset: CGSize(width: 1.3 * shadow, height: -2.4 * shadow), blur: 2 * shadow,
        color: ArmorHDColor.black.alpha(0.5))
      fill(path, tone.metal(0.2).cg)
      c.restoreGState()
    } else {
      // Subpixel contact relief is a vector edge, avoiding a temporary shadow
      // bitmap for each reconstructed plate. The broad reflection stays intact.
      fill(translated(path, 1.3 * shadow, 2.4 * shadow), ArmorHDColor.black.alpha(0.45))
    }
    let exposures: [Double] = pale ? [0.9, 1, 0.9, 0.32, 0.66] : [0.66, 0.98, 0.66, 0.2, 0.45]
    let start =
      tall
      ? CGPoint(x: b.minX, y: b.midY - b.width * 0.3)
      : wide ? CGPoint(x: b.midX - b.height * 0.3, y: b.minY) : CGPoint(x: b.minX, y: b.minY)
    let end =
      tall
      ? CGPoint(x: b.maxX, y: b.midY + b.width * 0.3)
      : wide ? CGPoint(x: b.midX + b.height * 0.3, y: b.maxY) : CGPoint(x: b.maxX, y: b.maxY)
    var reflection = exposures.map { tone.metal($0).mix(.white, pale && $0 > 0.85 ? 0.35 : 0) }
    if tone.prismatic && !softRelief {
      reflection[1] = reflection[1].mix(.hsv(0.52, 0.5, 1), 0.28)
      reflection[2] = reflection[2].mix(.hsv(0.94, 0.4, 1), 0.24)
    }
    gradient(path, reflection.map(\.cg), [0, 0.2, 0.42, 0.8, 1], start, end)
    if tone.prismatic && softRelief {
      // Thin-film colour stays in the reflection band, preserving the white-gold core.
      gradient(
        path,
        [
          ArmorHDColor.hsv(0.52, 0.6, 1).alpha(0), ArmorHDColor.hsv(0.52, 0.6, 1).alpha(0.32),
          ArmorHDColor.hsv(0.77, 0.5, 1).alpha(0.3), ArmorHDColor.hsv(0.94, 0.45, 1).alpha(0.22),
          ArmorHDColor.hsv(0.12, 0.5, 1).alpha(0),
        ], [0, 0.18, 0.32, 0.48, 0.65], start, end)
    }
    c.saveGState()
    c.addPath(path)
    c.clip()
    if softRelief {
      c.setShadow(
        offset: .zero, blur: max(1, min(b.width, b.height) * 0.1),
        color: ArmorHDColor.black.alpha(0.45))
    }
    stroke(translated(path, -1.4, -2.2), ArmorHDColor.black.alpha(0.3), 2.2)
    c.setShadow(offset: .zero, blur: 0, color: nil)
    if polish > 0 && (softRelief || b.width * b.height > 180) {
      c.saveGState()
      c.setBlendMode(.plusLighter)
      let spot =
        tall
        ? CGRect(
          x: b.minX + b.width * 0.22, y: b.minY + b.height * 0.12, width: b.width * 0.2,
          height: b.height * 0.42)
        : CGRect(
          x: b.minX + b.width * 0.16, y: b.minY + b.height * 0.1, width: b.width * 0.34,
          height: max(1.5, b.height * 0.16))
      c.translateBy(x: spot.midX, y: spot.midY)
      c.scaleBy(x: spot.width / 2, y: spot.height / 2)
      let g = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [ArmorHDColor.white.alpha(0.48 * polish), ArmorHDColor.white.alpha(0)] as CFArray,
        locations: [0, 1])!
      c.drawRadialGradient(
        g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
      c.restoreGState()
    }
    stroke(translated(path, 0.8, 1), ArmorHDColor.white.alpha(0.26), 0.9)
    c.setBlendMode(.plusLighter)
    stroke(translated(path, -1.1, 0.2), rim.alpha(0.6), 1.5)
    c.restoreGState()
    stroke(path, ArmorHDColor.black.alpha(0.62), 0.8)
  }
  // Reconstructed shells already have a separate joint backing. Their narrow
  // contact edge and directional reflection need no per-plate shadow bitmap.
  func plate(_ path: CGPath, _ tone: ArmorHDTone) {
    let b = path.boundingBoxOfPath
    let tall = b.height > b.width * 1.6
    let wide = b.width > b.height * 1.6
    let start =
      tall
      ? CGPoint(x: b.minX, y: b.midY - b.width * 0.3)
      : wide ? CGPoint(x: b.midX - b.height * 0.3, y: b.minY) : CGPoint(x: b.minX, y: b.minY)
    let end =
      tall
      ? CGPoint(x: b.maxX, y: b.midY + b.width * 0.3)
      : wide ? CGPoint(x: b.midX + b.height * 0.3, y: b.maxY) : CGPoint(x: b.maxX, y: b.maxY)
    var colors = [0.66, 0.98, 0.66, 0.2, 0.45].map { tone.metal($0) }
    if tone.prismatic {
      colors[1] = colors[1].mix(.hsv(0.52, 0.5, 1), 0.28)
      colors[2] = colors[2].mix(.hsv(0.94, 0.4, 1), 0.24)
    }
    gradient(path, colors.map(\.cg), [0, 0.2, 0.42, 0.8, 1], start, end)
    if b.width * b.height < 160 {
      stroke(path, ArmorHDColor.black.alpha(0.62), 0.7)
      return
    }
    c.saveGState()
    c.addPath(path)
    c.clip()
    stroke(translated(path, 0.8, 1), ArmorHDColor.white.alpha(0.26), 0.9)
    c.setBlendMode(.plusLighter)
    stroke(translated(path, -1.1, 0.2), rim.alpha(0.6), 1.5)
    c.restoreGState()
    stroke(path, ArmorHDColor.black.alpha(0.62), 0.8)
  }
  func edge(_ path: CGPath, _ tone: ArmorHDTone, width: CGFloat = 2.5) {
    c.saveGState()
    c.addPath(path)
    c.clip()
    let band = path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 2)
    let b = path.boundingBoxOfPath
    gradient(
      band, [tone.metal(0.98).cg, tone.metal(0.66).cg, tone.metal(0.2).cg], [0, 0.42, 1],
      CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.maxY))
    c.restoreGState()
    stroke(path, ArmorHDColor.black.alpha(0.62), 0.6)
  }
  func glow(_ path: CGPath, width: CGFloat = 1.3, strength: Double = 1) {
    c.saveGState()
    c.setBlendMode(.plusLighter)
    c.setShadow(offset: .zero, blur: width * 4, color: rim.alpha(0.65 * strength))
    stroke(path, rim.alpha(0.7 * strength), width * 2)
    c.setShadow(offset: .zero, blur: 0, color: nil)
    stroke(path, rim.mix(.white, 0.7).alpha(strength), width * 0.65)
    c.restoreGState()
  }
  func cloth(_ path: CGPath, _ tone: ArmorHDTone) {
    let b = path.boundingBoxOfPath
    gradient(
      path, [0.3, 0.62, 0.3, 0.62, 0.3].map { tone.metal($0).cg }, [0, 0.25, 0.5, 0.75, 1],
      CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.minY + b.height * 0.12))
    gradient(
      path, [ArmorHDColor.black.alpha(0.05), ArmorHDColor.black.alpha(0.5)], [0, 1],
      CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.maxY))
  }
}

struct ArmorHDParts {
  typealias S = ArmorHDShape
  let context: CGContext
  let style: ArmorHDStyle
  let anchors: ArmorHDAnchors
  let frame: String
  let shoulders: [String: [Double]]
  let headFit: ArmorHDHeadFit
  var shade: ArmorHDShade { .init(c: context, rim: style.light) }
  func placed(_ name: String, _ point: [Double], rotate: Bool = false, _ body: () -> Void) {
    // HD fitting belongs to the renderer, independent of removable pixel skins.
    guard name != "helm" || frame != "pose2" else { return }
    let offsets: [String: [Double]]
    switch name {
    case "wings": offsets = ["pose2": [6, 0], "pose4": [8, 0]]
    case "chest": offsets = ["c": [0, 2], "t": [0, 2], "pose2": [0, 2]]
    default: offsets = [:]
    }
    let offset = offsets[frame] ?? offsets[String(frame.prefix(1))] ?? [0, 0]
    context.saveGState()
    if name == "helm" || name == "halo" { context.concatenate(headFit.transform) }
    context.translateBy(x: point[0] + offset[0], y: point[1] + offset[1])
    if rotate { context.rotate(by: anchors.tilt * .pi / 180) }
    body()
    context.restoreGState()
  }
  func back() { designedBack() }
  func paladinBack() {
    placed("sword", anchors.back) {
      context.translateBy(x: 42, y: -48)
      context.scaleBy(x: 0.7, y: 0.7)
      context.rotate(by: 0.48)
      let blade = S.poly(S.points([(-6, -26), (6, -26), (6, 35), (0, 52), (-6, 35)]))
      shade.part(blade, style.plate, polish: 1.3)
      let ridge = CGMutablePath()
      ridge.move(to: .init(x: 0, y: -22))
      ridge.addLine(to: .init(x: 0, y: 45))
      shade.stroke(ridge, ArmorHDColor.white.alpha(0.7), 0.8)
      for y in stride(from: 0, through: 36, by: 12) {
        shade.glow(
          S.poly(
            S.points([(0, CGFloat(y) - 2), (2, CGFloat(y)), (0, CGFloat(y) + 2), (-2, CGFloat(y))])),
          width: 0.55, strength: 0.7)
      }
      let grip = CGPath(
        roundedRect: CGRect(x: -3.5, y: -62, width: 7, height: 33), cornerWidth: 2, cornerHeight: 2,
        transform: nil)
      shade.part(grip, style.cloth, polish: 0.2)
      for y in stride(from: -57, through: -33, by: 4) {
        let line = CGMutablePath()
        line.move(to: .init(x: -3, y: y))
        line.addLine(to: .init(x: 3, y: y + 2))
        shade.stroke(line, style.trim.metal(0.55).cg, 0.7)
      }
      shade.part(
        S.smooth(
          S.points([
            (-23, -35), (-14, -31), (0, -29), (14, -31), (23, -35), (17, -25), (0, -23), (-17, -25),
          ])),
        style.trim)
      shade.part(S.oval(0, -64, 11, 11), style.trim, polish: 1.5)
    }
    // Seated, the body is near the floor: the wings rise folded from the
    // shoulder blades instead of spreading low and wide behind it.
    let seated = ["c", "t"].contains(String(frame.prefix(1)))
    placed("wings", seated ? [anchors.neck[0], anchors.neck[1] + 4] : anchors.back) {
      for side: CGFloat in [-1, 1] {
        let base = CGPoint(x: side * (seated ? 20 : 22), y: -6)
        for (reach, width, alpha) in [
          (CGFloat(1), CGFloat(19), 0.56), (CGFloat(0.6), CGFloat(14), 0.72),
        ] {
          for i in (0..<7).reversed() {
            let f = CGFloat(i) / 6
            let angle = seated ? -1.15 + 1.1 * f : -1.3 + 1.48 * f
            let length = (137 - 43 * f) * reach * (seated ? 0.86 : 1)
            let tip = CGPoint(
              x: base.x + side * cos(angle) * length, y: base.y + sin(angle) * length)
            let feather = S.feather(base, tip, width: width)
            context.saveGState()
            context.setBlendMode(.plusLighter)
            shade.gradient(
              feather,
              [
                ArmorHDColor.white.alpha(alpha), style.light.alpha(alpha * 0.75),
                style.light.alpha(0.08),
              ],
              [0, 0.65, 1], base, tip)
            let shaft = CGMutablePath()
            shaft.move(to: base)
            shaft.addLine(
              to: CGPoint(x: base.x + (tip.x - base.x) * 0.88, y: base.y + (tip.y - base.y) * 0.88))
            shade.stroke(shaft, ArmorHDColor.white.alpha(alpha * 0.45), 0.55)
            if reach == 1 {
              let dx = tip.x - base.x
              let dy = tip.y - base.y
              let length = hypot(dx, dy)
              let nx = dy / length * side
              let ny = -abs(dx / length)
              for j in 0..<3 {
                let along = CGFloat(0.42) + CGFloat(j) * 0.18
                let x = base.x + dx * along + nx * 6
                let y = base.y + dy * along + ny * 6
                let flame = S.smooth(
                  S.points([
                    (x - 1.7, y + 1), (x - 2, y - 2), (x + 1, y - 8 - CGFloat(j)), (x + 2, y - 1),
                  ]))
                shade.fill(flame, style.light.alpha(0.4))
                shade.stroke(flame, style.light.mix(.white, 0.55).alpha(0.3), 0.5)
              }
            }
            context.restoreGState()
          }
        }
      }
    }
    placed("halo", anchors.head, rotate: true) {
      shade.glow(S.oval(0, 31, 128, 124), width: 1.4, strength: 0.85)
      for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        let p = S.oval(cos(a) * 64, 31 + sin(a) * 62, 2.8, 2.8)
        shade.fill(p, style.light.mix(.white, 0.8).cg)
      }
    }
  }

  func gem(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    let socket = S.poly(
      S.points([(x, y - r * 1.5), (x + r * 1.1, y), (x, y + r * 1.5), (x - r * 1.1, y)]))
    shade.part(socket, style.trim, polish: 1.4, shadow: 0.5)
    let top = CGPoint(x: x, y: y - r)
    let right = CGPoint(x: x + r * 0.7, y: y)
    let bottom = CGPoint(x: x, y: y + r)
    let left = CGPoint(x: x - r * 0.7, y: y)
    let center = CGPoint(x: x - r * 0.16, y: y - r * 0.2)
    for (a, b, c) in [
      (top, right, 0.75), (right, bottom, 0.24), (bottom, left, 0.44), (left, top, 1.0),
    ] {
      shade.fill(
        S.poly([a, b, center]), style.light.mix(c > 0.6 ? .white : .black, abs(c - 0.5) * 1.4).cg)
    }
    shade.fill(S.oval(x - r * 0.2, y - r * 0.4, r * 0.35, r * 0.25), ArmorHDColor.white.cg)
  }
  func props(mug: CGRect?) {
    if let mug {
      context.saveGState()
      context.translateBy(x: mug.minX, y: mug.minY)
      context.scaleBy(x: mug.width / 42, y: mug.height / 50)
      context.translateBy(x: -62, y: -218)
      let ceramic = ArmorHDTone(hue: 0.08, saturation: 0.06)
      // Rounded ceramic handle behind the cup, with a dark opening.
      let handle = S.oval(109, 239, 18, 24)
      shade.part(handle, ceramic, pale: true, polish: 1.1, shadow: 0.4)
      shade.fill(S.oval(110, 239, 9, 14), ArmorHDColor(r: 0.045, g: 0.05, b: 0.07).cg)
      let cup = S.smooth(
        S.points([(62, 220), (82, 218), (102, 220), (103, 259), (96, 268), (68, 268), (62, 261)]),
        tension: 0.25)
      shade.part(cup, ceramic, pale: true, polish: 1.4, shadow: 0.8)
      shade.fill(S.oval(82, 221, 39, 10), ArmorHDColor(r: 0.35, g: 0.13, b: 0.045).cg)
      shade.fill(S.oval(82, 222, 31, 5), ArmorHDColor(r: 0.055, g: 0.025, b: 0.014).cg)
      shade.stroke(S.oval(82, 220, 39, 10), ArmorHDColor.white.alpha(0.9), 1.6)
      // The orange maker's seal remains part of the prop's identity.
      let seal = S.smooth(
        S.points([(82, 238), (89, 241), (91, 249), (86, 256), (78, 256), (73, 250), (75, 242)]),
        tension: 0.25)
      shade.gradient(
        seal, [ArmorHDColor(r: 1, g: 0.55, b: 0.15).cg, ArmorHDColor(r: 1, g: 0.25, b: 0.045).cg],
        [0, 1], CGPoint(x: 75, y: 239), CGPoint(x: 91, y: 256))
      for j in 0..<2 {
        let steam = CGMutablePath()
        let x = CGFloat(78 + j * 9)
        steam.move(to: CGPoint(x: x, y: 210))
        steam.addCurve(
          to: CGPoint(x: x + 2, y: 181 + CGFloat(j * 6)), control1: CGPoint(x: x - 12, y: 202),
          control2: CGPoint(x: x + 12, y: 196))
        shade.stroke(steam, ArmorHDColor.white.alpha(0.16), 3.5)
        shade.stroke(steam, ArmorHDColor.white.alpha(0.6), 0.95)
      }
      context.restoreGState()
    }
    if frame.hasPrefix("t") {
      let metal = ArmorHDTone(hue: 0.64, saturation: 0.65)
      let base = S.poly(S.points([(94, 239), (176, 232), (239, 248), (176, 268)]))
      shade.part(base, metal, polish: 1.2, shadow: 0.7)
      let deck = S.poly(S.points([(99, 239), (176, 235), (222, 248), (176, 261)]))
      shade.gradient(
        deck, [metal.metal(0.58).cg, metal.metal(0.15).cg], [0, 1], CGPoint(x: 110, y: 232),
        CGPoint(x: 180, y: 262))
      let cyan = ArmorHDShade(c: context, rim: ArmorHDColor(r: 0.03, g: 0.84, b: 1))
      for row in 0..<4 {
        for col in 0..<9 {
          let x = CGFloat(112 + col * 8 + row * 3)
          let y = CGFloat(239 + row * 4) - CGFloat(col) * 0.35
          let key = S.poly(
            S.points([(x, y), (x + 5, y - 0.3), (x + 7, y + 1.4), (x + 2, y + 1.8)]))
          shade.fill(key, ArmorHDColor(r: 0.14, g: 0.8, b: 0.96).alpha(0.7))
        }
      }
      let screen = S.smooth(
        S.points([(198, 195), (266, 188), (245, 252), (177, 263)]), tension: 0.06)
      shade.part(screen, metal, polish: 1.1, shadow: 0.7)
      let face = S.poly(S.points([(202, 199), (261, 193), (241, 247), (184, 257)]))
      shade.gradient(
        face,
        [ArmorHDColor(r: 0.08, g: 0.19, b: 0.29).cg, ArmorHDColor(r: 0.08, g: 0.07, b: 0.16).cg],
        [0, 1], CGPoint(x: 196, y: 201), CGPoint(x: 239, y: 248))
      cyan.glow(screen, width: 0.9, strength: 0.8)
      let logo = S.smooth(
        S.points([
          (220, 223), (227, 221), (231, 226), (228, 234), (220, 239), (214, 236), (215, 229),
        ]))
      cyan.glow(logo, width: 0.8, strength: 0.85)
      let glint = CGMutablePath()
      glint.move(to: CGPoint(x: 205, y: 199))
      glint.addLine(to: CGPoint(x: 239, y: 195))
      shade.stroke(glint, ArmorHDColor.white.alpha(0.5), 1)
    }
  }
  func front() { designedFront() }
  func paladinChest() {
    let seated = frame.hasPrefix("c") || frame.hasPrefix("t")
    let h: CGFloat = seated ? 28 : 43
    let w: CGFloat = frame.hasPrefix("t") ? 37 : 51
    let hem: CGFloat = seated ? h + 10 : h + 52
    let tabard = S.smooth(
      S.points([
        (-w * 0.25, h - 3), (w * 0.25, h - 3), (w * 0.3, hem - 9), (0, hem), (-w * 0.3, hem - 9),
      ]),
      tension: 0.3)
    shade.cloth(tabard, style.cloth)
    shade.edge(tabard, style.trim, width: 3.4)
    for side: CGFloat in [-1, 1] {
      let fold = CGMutablePath()
      fold.move(to: CGPoint(x: side * w * 0.14, y: h + 4))
      fold.addQuadCurve(
        to: CGPoint(x: side * w * 0.19, y: hem - 8),
        control: CGPoint(x: side * w * 0.08, y: (h + hem) / 2))
      shade.stroke(fold, ArmorHDColor.black.alpha(0.3), 0.8)
      shade.stroke(shade.translated(fold, 0.9, 0), style.cloth.metal(0.85).alpha(0.4), 0.7)
    }
    let shell = S.smooth(
      S.points([
        (-w / 2, 2), (0, 5), (w / 2, 2), (w * 0.53, h * 0.4), (w * 0.4, h * 0.83), (0, h),
        (-w * 0.4, h * 0.83), (-w * 0.53, h * 0.4),
      ]))
    shade.part(shell, style.plate, polish: 1.6)
    shade.edge(shell, style.trim, width: 2.2)
    for side: CGFloat in [-1, 1] {
      let engraving = CGMutablePath()
      engraving.move(to: .init(x: side * w * 0.4, y: h * 0.34))
      engraving.addCurve(
        to: .init(x: side * 5, y: h * 0.66), control1: .init(x: side * w * 0.32, y: h * 0.65),
        control2: .init(x: side * 10, y: h * 0.58))
      shade.stroke(engraving, ArmorHDColor.black.alpha(0.4), 1)
      shade.stroke(shade.translated(engraving, 0.4, 0.7), style.trim.metal(0.98).alpha(0.8), 0.6)
    }
    gem(0, h * 0.36, seated ? 4 : 5)
    if !seated {
      for y: CGFloat in [h - 2, h + 6] {
        let lame = S.smooth(
          S.points([(-21, y), (0, y + 3), (21, y), (19, y + 7), (0, y + 11), (-19, y + 7)]),
          tension: 0.3)
        shade.part(lame, style.plate, polish: 1.1, shadow: 0.5)
        shade.edge(lame, style.trim, width: 1.7)
      }
      let emblem = CGMutablePath()
      emblem.addPath(S.oval(0, h + 32, 6, 6))
      for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        emblem.move(to: .init(x: cos(a) * 4.5, y: h + 32 + sin(a) * 4.5))
        emblem.addLine(to: .init(x: cos(a) * 7, y: h + 32 + sin(a) * 7))
      }
      shade.stroke(emblem, style.trim.metal(0.9).cg, 0.9)
    }
  }
  func paladinShoulder(_ side: CGFloat) {
    for i in 0..<2 {
      let base = CGPoint(x: side * 8, y: 8 - CGFloat(i) * 3)
      let tip = CGPoint(x: side * (25 - CGFloat(i) * 4), y: -6 - CGFloat(i) * 6)
      shade.part(S.feather(base, tip, width: 8), style.trim, polish: 1.2, shadow: 0.5)
    }
    let dome = S.smooth(
      S.points([(-17, 3), (-12, -6), (1, -9), (15, -4), (19, 9), (10, 18), (-9, 16)]))
    shade.part(dome, style.plate, polish: 1.6)
    shade.edge(dome, style.trim, width: 2.8)
  }
  func paladinHelm() {
    for side: CGFloat in [-1, 1] {
      for i in 0..<3 {
        let base = CGPoint(x: side * 39, y: 25 - CGFloat(i) * 4)
        let tip = CGPoint(x: side * (60 - CGFloat(i) * 6), y: 9 - CGFloat(i) * 11)
        shade.part(S.feather(base, tip, width: 9), style.trim, polish: 1.2, shadow: 0.6)
      }
    }
    let circlet = S.poly(
      S.points([
        (-29, 13), (-20, 6), (-11, 10), (0, -3), (11, 10), (20, 6), (29, 13), (25, 19), (0, 16),
        (-25, 19),
      ]))
    shade.part(circlet, style.trim, polish: 1.3, shadow: 0.8)
    gem(0, 8, 4)
  }
}

// Each authored part uses the same bevels, reflections and contact shadows as
// the paladin. Fitting is in the shared 314-point canvas, never output pixels.
extension ArmorHDParts {
  var seated: Bool { frame.hasPrefix("c") || frame.hasPrefix("t") }
  func line(_ points: [(CGFloat, CGFloat)]) -> CGPath {
    let p = CGMutablePath()
    p.addLines(between: S.points(points))
    return p
  }
  func star(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, points: Int = 8) -> CGPath {
    S.poly(
      (0..<points * 2).map { i in
        let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
        let r = i.isMultiple(of: 2) ? radius : radius * 0.32
        return CGPoint(x: x + cos(angle) * r, y: y + sin(angle) * r)
      })
  }
  func crescent(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: .init(x: x + r * 0.6, y: y - r))
    p.addCurve(
      to: .init(x: x + r * 0.6, y: y + r),
      control1: .init(x: x - r * 1.8, y: y - r), control2: .init(x: x - r * 1.8, y: y + r))
    p.addCurve(
      to: .init(x: x + r * 0.6, y: y - r),
      control1: .init(x: x - r * 0.65, y: y + r * 0.5),
      control2: .init(x: x - r * 0.65, y: y - r * 0.5))
    p.closeSubpath()
    return p
  }
  // Thin ornaments use one reflective gradient and a drawn contact edge.
  // A separate blurred shadow and radial light per vane obscures feather
  // overlap and spends most of the frame budget on offscreen buffers.
  func lamina(_ path: CGPath, _ tone: ArmorHDTone) {
    let b = path.boundingBoxOfPath
    let colors: [CGColor]
    if tone.prismatic {
      colors = [
        tone.metal(0.58).cg, ArmorHDColor(r: 1, g: 0.9, b: 0.96).cg,
        ArmorHDColor(r: 0.91, g: 1, b: 0.99).cg, tone.metal(0.98).cg, tone.metal(0.48).cg,
      ]
    } else {
      colors = [0.55, 0.96, 0.8, 0.4, 0.68].map { tone.metal($0).cg }
    }
    shade.gradient(
      path, colors, [0, 0.22, 0.43, 0.76, 1],
      .init(x: b.minX, y: b.minY), .init(x: b.maxX, y: b.maxY))
    shade.stroke(path, tone.metal(0.12).alpha(0.8), 1.2)
    shade.stroke(path, ArmorHDColor.white.alpha(0.55), 0.5)
  }
  func leaf(_ base: CGPoint, _ tip: CGPoint, width: CGFloat, tone: ArmorHDTone) {
    let p = S.feather(base, tip, width: width)
    lamina(p, tone)
    shade.stroke(p, style.trim.metal(0.65).alpha(0.65), 0.65)
    let vein = CGMutablePath()
    vein.move(to: base)
    vein.addLine(to: tip)
    shade.stroke(vein, tone.metal(0.98).alpha(0.7), 0.65)
  }
  func pearl(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    lamina(S.oval(x, y, r * 2.6, r * 2.6), style.trim)
    lamina(S.oval(x, y, r * 2, r * 2), style.plate)
    shade.fill(S.oval(x - r * 0.3, y - r * 0.4, r * 0.55, r * 0.4), ArmorHDColor.white.cg)
  }
  func wingedClasp(_ y: CGFloat, span: CGFloat) {
    for side: CGFloat in [-1, 1] {
      for i in (0..<3).reversed() {
        leaf(
          .init(x: side * 3, y: y + 2),
          .init(x: side * (span - CGFloat(i) * 3), y: y - 8 + CGFloat(i) * 4),
          width: 5, tone: style.plate)
      }
    }
    pearl(0, y, 4.2)
  }
  func designedBack() {
    switch style.design.back {
    case .thrusters: thrusters()
    case .mantle, .constellation, .bladeCape:
      cape()
      if style.design.back == .bladeCape { blackBlade() }
    case .seraph:
      seraphWings()
      placed("halo", anchors.head, rotate: true) {
        for (w, h, y) in [(CGFloat(130), CGFloat(118), CGFloat(28)), (110, 98, 28)] {
          shade.glow(S.oval(0, y, w, h), width: 0.9, strength: 0.8)
        }
        for side: CGFloat in [-1, 1] { pearl(side * 49, -5, 1.8) }
      }
    case .paladin:
      paladinBack()
      return
    }
    particles()
  }
  func cape() {
    // The neck is the shoulder line. The back anchor is near the waist in
    // seated frames and must not be used as the cloth's hanging point.
    placed("cape", anchors.neck) {
      let h: CGFloat = 275 - anchors.neck[1]
      let w: CGFloat = seated ? 75 : 65
      let torn = style.design.back == .bladeCape
      let hem: [(CGFloat, CGFloat)] =
        torn
        ? [
          (w, h - 13), (w - 12, h - 2), (w - 19, h - 20), (w - 32, h), (10, h - 8), (-5, h - 1),
          (-23, h - 17), (-40, h), (-w, h - 8),
        ]
        : [(w, h - 7), (w * 0.65, h), (0, h + 2), (-w * 0.65, h), (-w, h - 7)]
      let outline = [
        (-29.0, -5.0), (0.0, -8.0), (29.0, -5.0), (seated ? 43.0 : 50.0, Double(h) * 0.65),
      ]
      let path = S.smooth(
        S.points(outline.map { (CGFloat($0.0), CGFloat($0.1)) } + hem + [(-w * 0.67, h * 0.65)]),
        tension: torn ? 0.08 : 0.3)
      shade.cloth(path, style.cloth)
      context.saveGState()
      context.addPath(path)
      context.clip()
      let hues: [Double] = [0.39, 0.46, 0.51, 0.7, 0.78, 0.86, 0.48, 0.43, 0.4]
      for i in 0..<9 {
        let f = CGFloat(i) / 8
        let x = -w + 2 * w * f
        let top = (x / w) * 29
        let bottom = x + (seated ? sin(f * .pi * 3) * 9 : 0)
        let fold = S.smooth(
          S.points([(top - 5, -5), (top + 6, -5), (bottom + 10, h + 4), (bottom - 10, h + 4)]),
          tension: 0.15)
        if style.design.back == .mantle {
          let hue = hues[i % hues.count]
          shade.gradient(
            fold,
            [
              ArmorHDColor.hsv(hue, 0.75, 0.2).cg, ArmorHDColor.hsv(hue, 0.66, 0.6).cg,
              ArmorHDColor.hsv(hue, 0.48, 0.98).cg,
            ], [0, 0.55, 1], .init(x: top, y: 0), .init(x: bottom, y: h))
          // Longitudinal colour and transverse light are separate: each
          // curtain has a dark valley, bright ridge and a luminous hem.
          shade.gradient(
            fold,
            [
              ArmorHDColor.black.alpha(0.6), ArmorHDColor.white.alpha(0.1),
              ArmorHDColor.black.alpha(0.45),
            ],
            [0, 0.4, 1], .init(x: bottom - 10, y: h / 2), .init(x: bottom + 10, y: h / 2))
        } else {
          shade.gradient(
            fold,
            [style.cloth.metal(0.15).cg, style.cloth.metal(0.68).cg, style.cloth.metal(0.22).cg],
            [0, 0.5, 1], .init(x: bottom - 10, y: h / 2), .init(x: bottom + 10, y: h / 2))
        }
        let crease = CGMutablePath()
        crease.move(to: .init(x: top, y: 0))
        crease.addQuadCurve(
          to: .init(x: bottom, y: h - 2), control: .init(x: top * 1.5, y: h * 0.72))
        shade.stroke(crease, ArmorHDColor.black.alpha(0.25), 1.2)
        if seated {
          // The final fold bends along the floor into the pooled hem.
          shade.stroke(
            line([(bottom - 10, h - 7), (bottom, h - 3), (bottom + 9, h - 5)]),
            style.light.alpha(0.3), 0.8)
        }
      }
      if style.design.back == .constellation {
        for side: CGFloat in [-1, 1] {
          let points = S.points([
            (side * 36, 26), (side * 46, 46), (side * 37, 63), (side * 55, 87), (side * 42, h - 9),
          ])
          let thread = CGMutablePath()
          thread.addLines(between: points)
          shade.stroke(thread, style.light.alpha(0.38), 0.65)
          for (i, p) in points.enumerated() {
            shade.glow(star(p.x, p.y, i.isMultiple(of: 2) ? 2.8 : 1.8, points: 4), width: 0.55)
          }
        }
      }
      context.restoreGState()
      shade.edge(path, style.trim, width: 2)
      shade.stroke(path, style.light.alpha(0.38), 0.65)
    }
  }
  func blackBlade() {
    placed("blade", anchors.neck) {
      context.translateBy(x: 29, y: -20)
      context.rotate(by: -0.64)
      let blade = S.poly(S.points([(-5, -39), (5, -39), (7, 93), (0, 111), (-7, 93)]))
      shade.part(blade, style.plate, polish: 0.5, softRelief: false)
      shade.stroke(line([(0, -32), (0, 103)]), ArmorHDColor.hsv(0.76, 0.6, 0.62).cg, 1)
      shade.part(
        S.poly(S.points([(-20, -40), (-12, -47), (0, -43), (12, -47), (20, -40), (0, -36)])),
        style.trim, softRelief: false)
      shade.part(
        S.poly(S.points([(-3, -68), (3, -68), (3, -44), (-3, -44)])), style.plate, softRelief: false
      )
      gem(0, -69, 3)
    }
  }
  func thrusters() {
    placed("thrusters", anchors.neck) {
      for side: CGFloat in [-1, 1] {
        context.saveGState()
        context.translateBy(x: side * 43, y: seated ? 4 : 0)
        let h: CGFloat = seated ? 48 : 64
        let pod = S.poly(
          S.points([(-12, -11), (6, -15), (13, -6), (13, h), (6, h + 6), (-12, h + 2)]))
        shade.part(pod, style.plate, polish: 0.7, softRelief: false)
        shade.edge(pod, style.trim, width: 1.6)
        shade.glow(line([(side * 8, -3), (side * 8, h - 10)]), width: 1.8)
        for y in stride(from: 3, through: Int(h) - 10, by: 9) {
          shade.stroke(
            line([(-7, CGFloat(y)), (3, CGFloat(y) - 2)]), ArmorHDColor.black.alpha(0.8), 2)
        }
        let nozzle = S.poly(S.points([(-10, h - 2), (11, h - 2), (8, h + 10), (-7, h + 10)]))
        shade.part(nozzle, style.trim, polish: 0.5, softRelief: false)
        let flame = S.smooth(
          S.points([(-7, h + 9), (7, h + 9), (8, h + 24), (0, h + 48), (-8, h + 25)]), tension: 0.25
        )
        shade.gradient(
          flame,
          [ArmorHDColor.white.cg, style.light.cg, ArmorHDColor.hsv(0.73, 0.9, 1).alpha(0.15)],
          [0, 0.27, 1],
          .init(x: 0, y: h + 9), .init(x: 0, y: h + 48))
        shade.glow(line([(0, h + 10), (-1, h + 31)]), width: 1.6)
        context.restoreGState()
      }
    }
  }
  func seraphWings() {
    placed("wings", [anchors.neck[0], anchors.neck[1] + 4]) {
      for side: CGFloat in [-1, 1] {
        // Three separate fans with air between their tip envelopes.
        let fans: [(CGFloat, CGFloat, CGFloat, CGFloat)] =
          seated
          ? [(-1.22, 108, 0, 0.46), (-0.65, 104, 6, 0.42), (-0.08, 72, 14, 0.38)]
          : [(-1.1, 119, -4, 0.55), (0.04, 119, 4, 0.45), (0.78, 87, 24, 0.35)]
        for (angle, length, y, spread) in fans.reversed() {
          let base = CGPoint(x: side * 19, y: y)
          var vanes = [(CGPath, CGPoint)]()
          let fan = CGMutablePath()
          for i in (0..<6).reversed() {
            let f = CGFloat(i) / 5
            let a = angle + spread * f
            let available = side < 0 ? anchors.neck[0] - 12 : 302 - anchors.neck[0]
            let fittedLength = min(length, (available - 19) / max(0.1, cos(angle)))
            let l = fittedLength * (1 - f * 0.25)
            let tip = CGPoint(x: base.x + side * cos(a) * l, y: base.y + sin(a) * l)
            let dx = tip.x - base.x
            let dy = tip.y - base.y
            let norm = max(1, hypot(dx, dy))
            let nx = -dy / norm * 6.5
            let ny = dx / norm * 6.5
            let feather = CGMutablePath()
            feather.move(to: base)
            feather.addCurve(
              to: tip,
              control1: .init(x: base.x + dx * 0.3 + nx, y: base.y + dy * 0.3 + ny),
              control2: .init(x: tip.x - dx * 0.1 + nx, y: tip.y - dy * 0.1 + ny))
            feather.addCurve(
              to: base,
              control1: .init(x: tip.x - dx * 0.1 - nx, y: tip.y - dy * 0.1 - ny),
              control2: .init(x: base.x + dx * 0.3 - nx, y: base.y + dy * 0.3 - ny))
            feather.closeSubpath()
            fan.addPath(feather)
            vanes.append((feather, tip))
          }
          // One coherent iridescent reflection across each fan. Individual
          // contact edges, shafts and pearl tips retain the layered feathers.
          let tip = vanes.last!.1
          for (i, vane) in vanes.enumerated() {
            let (feather, tip) = vane
            shade.fill(feather, style.trim.metal(0.72 + Double(i) * 0.025).mix(.white, 0.45).cg)
            shade.stroke(feather, style.trim.metal(0.22).alpha(0.7), 0.8)
            let shaft = CGMutablePath()
            shaft.move(to: base)
            shaft.addLine(to: tip)
            shade.stroke(shaft, ArmorHDColor.white.alpha(0.9), 1)
          }
          shade.gradient(
            fan,
            [
              style.trim.metal(0.5).alpha(0.55),
              ArmorHDColor(r: 1, g: 0.76, b: 0.91).alpha(0.65),
              ArmorHDColor(r: 0.65, g: 0.96, b: 0.99).alpha(0.65), ArmorHDColor.white.alpha(0.9),
            ],
            [0, 0.34, 0.65, 1], base, tip)
          for (_, tip) in vanes {
            shade.fill(S.oval(tip.x, tip.y, 3.2, 3.2), ArmorHDColor.white.cg)
          }
          for i in 0..<3 {
            let a = angle + CGFloat(i) * spread / 2
            let tip = CGPoint(
              x: base.x + side * cos(a) * length * 0.45, y: base.y + sin(a) * length * 0.45)
            let covert = S.feather(base, tip, width: 10)
            lamina(covert, style.trim)
          }
        }
      }
    }
  }
  func particles() {
    // Deterministic accents complement the app's animated aura metadata.
    let phase = CGFloat(Int(frame.suffix(2)) ?? 2)
    for i in 0..<8 {
      let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
      let x = max(14, min(300, anchors.neck[0] + side * (73 + CGFloat(i % 3) * 10)))
      let y = CGFloat(70 + i * 24) + sin(phase + CGFloat(i)) * 5
      switch style.design.back {
      case .thrusters:
        shade.glow(line([(x - 2, y - 4), (x + 2, y), (x - 1, y + 3)]), width: 0.5, strength: 0.7)
      case .constellation: shade.glow(star(x, y, 2.3, points: 4), width: 0.4, strength: 0.8)
      case .seraph:
        let feather = S.feather(.init(x: x, y: y + 4), .init(x: x + side * 4, y: y - 4), width: 2.5)
        shade.fill(feather, ArmorHDColor.hsv(0.52 + Double(i % 3) * 0.19, 0.25, 1).alpha(0.75))
      default: shade.fill(S.oval(x, y, 1.7, 2.4), style.light.alpha(0.6))
      }
    }
  }
  func designedFront() {
    placed("chest", anchors.neck) { designedChest() }
    for (name, side) in [("shoulderL", CGFloat(-1)), ("shoulderR", CGFloat(1))] {
      guard let point = shoulders[name] else { continue }
      placed(name, [point[0] + side * 10, point[1] - 5]) { designedShoulder(side) }
    }
    placed("helm", anchors.head, rotate: true) { designedHelm() }
  }
  func designedChest() {
    if style.design.chest == .paladin {
      paladinChest()
      return
    }
    let h: CGFloat = seated ? 28 : 40
    let w: CGFloat = frame.hasPrefix("t") ? 34 : 49
    let plate = S.poly(
      S.points([
        (-w / 2, 1), (0, 5), (w / 2, 1), (w / 2 - 3, h * 0.72), (0, h), (-w / 2 + 3, h * 0.72),
      ]))
    shade.part(plate, style.plate, polish: 1.1, softRelief: false)
    shade.edge(plate, style.trim, width: 2)
    switch style.design.chest {
    case .circuit:
      let v = line([(-w * 0.36, 10), (0, h * 0.67), (w * 0.36, 10)])
      shade.stroke(v, ArmorHDColor.black.cg, 4.2)
      shade.glow(v, width: 1.3)
      let pink = ArmorHDShade(c: context, rim: .init(r: 1, g: 0.15, b: 0.73))
      pink.glow(S.oval(0, h * 0.67, 3, 3), width: 1.3)
      for side: CGFloat in [-1, 1] {
        shade.stroke(
          line([(side * w * 0.32, h * 0.74), (side * w * 0.14, h * 0.85)]),
          style.trim.metal(0.7).cg, 0.8)
      }
    case .leaf:
      leaf(.init(x: 0, y: h - 6), .init(x: 0, y: 8), width: 16, tone: style.trim)
      gem(0, h * 0.5, 3)
    case .star:
      shade.part(
        star(0, h * 0.48, seated ? 10 : 14), style.trim, polish: 1.3, shadow: 0.5, softRelief: false
      )
      shade.glow(star(0, h * 0.48, 8), width: 0.65)
      gem(0, h * 0.48, 2.8)
    case .ruby:
      let gorget = S.poly(
        S.points([
          (-w / 2, 3), (-20, -5), (-12, 7), (0, 0), (12, 7), (20, -5), (w / 2, 3), (14, 24), (0, h),
          (-14, 24),
        ]))
      shade.part(gorget, style.plate, polish: 0.5, softRelief: false)
      shade.edge(gorget, style.trim, width: 2)
      gem(0, h * 0.5, seated ? 5 : 7)
    case .pearl: wingedClasp(h * 0.47, span: 22)
    case .paladin: paladinChest()
    }
  }
  func designedShoulder(_ side: CGFloat) {
    switch style.design.pauldrons {
    case .vents:
      let shell = S.poly(S.points([(-19, 1), (-9, -10), (9, -10), (21, 1), (18, 17), (-14, 17)]))
      shade.part(shell, style.plate, softRelief: false)
      shade.edge(shell, style.trim, width: 2)
      for i in 0..<3 {
        let x = CGFloat(-8 + i * 7)
        shade.stroke(line([(x, -2), (x + 2, 6)]), ArmorHDColor.black.alpha(0.85), 2)
      }
      shade.glow(line([(-12, 11), (13, 11)]), width: 1.25)
    case .leaves:
      for i in (0..<3).reversed() {
        leaf(
          .init(x: -side * 12, y: -4 + CGFloat(i) * 4),
          .init(x: side * (22 - CGFloat(i) * 3), y: 4 + CGFloat(i) * 8), width: 17,
          tone: style.plate)
      }
    case .crescents:
      let dome = S.smooth(S.points([(-16, 0), (-9, -9), (9, -9), (18, 4), (13, 17), (-12, 15)]))
      shade.part(dome, style.plate, softRelief: false)
      shade.edge(dome, style.trim)
      context.saveGState()
      context.scaleBy(x: side, y: 1)
      shade.part(crescent(0, 4, 14), style.plate, pale: true, shadow: 0.4, softRelief: false)
      shade.glow(star(6, 4, 4, points: 4), width: 0.6)
      context.restoreGState()
    case .spikes:
      // Spikes lean outward, away from the visor and its expression.
      for i in 0..<3 {
        let x = side * CGFloat(7 + i * 6)
        let spike = S.poly(
          S.points([(x - 4, 7), (x + side * 9, -20 - CGFloat(i % 2) * 5), (x + 5, 9)]))
        shade.part(spike, style.plate, polish: 0.4, shadow: 0.4, softRelief: false)
        shade.edge(spike, style.trim, width: 1)
      }
      let shell = S.poly(S.points([(-17, 2), (0, -7), (20, 0), (23, 15), (0, 22), (-16, 13)]))
      shade.part(shell, style.plate, polish: 0.5, softRelief: false)
      shade.edge(shell, style.trim, width: 2.3)
    case .feathers:
      for i in (0..<3).reversed() {
        leaf(
          .init(x: -side * 8, y: -3), .init(x: side * (19 - CGFloat(i) * 4), y: 6 + CGFloat(i) * 6),
          width: 10, tone: style.plate)
      }
      pearl(-side * 4, 2, 2.2)
    case .paladin: paladinShoulder(side)
    }
  }
  func designedHelm() {
    switch style.design.helm {
    case .hud:
      let band = S.poly(
        S.points([
          (-43, 20), (-43, 4), (-28, -2), (28, -2), (43, 4), (43, 20), (36, 17), (34, 6), (-34, 6),
          (-36, 17),
        ]))
      shade.part(band, style.plate, polish: 0.7, softRelief: false)
      shade.glow(line([(-38, 13), (-38, 4), (-23, 2)]), width: 1)
      shade.glow(line([(38, 13), (38, 4), (23, 2)]), width: 1)
      // Side HUD brackets track the visor height without crossing the eye area.
      let dy = CGFloat(anchors.visor[1] - anchors.head[1])
      for side: CGFloat in [-1, 1] {
        shade.glow(
          line([
            (side * 44, dy - 18), (side * 49, dy - 12), (side * 49, dy + 13), (side * 44, dy + 18),
          ]), width: 0.9)
      }
    case .leaves:
      for side: CGFloat in [-1, 1] {
        let stem = line([(side * 23, 14), (side * 33, -3), (side * 31, -22)])
        shade.stroke(stem, style.trim.metal(0.8).cg, 3)
        for i in 0..<3 {
          leaf(
            .init(x: side * (25 + CGFloat(i) * 3), y: 10 - CGFloat(i) * 9),
            .init(x: side * (46 - CGFloat(i) * 4), y: -1 - CGFloat(i) * 11), width: 8,
            tone: style.plate)
        }
      }
      shade.part(
        S.smooth(S.points([(-28, 14), (0, 5), (28, 14), (22, 19), (0, 12), (-22, 19)])), style.trim,
        shadow: 0.3, softRelief: false)
      gem(0, 10, 3)
    case .moon:
      shade.part(
        S.smooth(S.points([(-31, 14), (0, 7), (31, 14), (24, 19), (0, 13), (-24, 19)])),
        style.plate, shadow: 0.3, softRelief: false)
      context.saveGState()
      context.translateBy(x: 0, y: 0)
      context.rotate(by: -.pi / 2)
      shade.part(crescent(0, 0, 19), style.plate, pale: true, shadow: 0.4, softRelief: false)
      context.restoreGState()
      shade.glow(star(0, -2, 4, points: 4), width: 0.5)
    case .horns:
      for side: CGFloat in [-1, 1] {
        let horn = S.smooth(
          S.points([
            (side * 29, 17), (side * 42, 6), (side * 47, -10), (side * 40, -30), (side * 36, -8),
            (side * 24, 5),
          ]), tension: 0.2)
        shade.part(horn, style.plate, polish: 0.6, softRelief: false)
        shade.edge(horn, style.trim, width: 1.6)
      }
      let brow = S.poly(
        S.points([(-32, 13), (-20, 7), (0, -1), (20, 7), (32, 13), (23, 19), (0, 10), (-23, 19)]))
      shade.part(brow, style.plate, polish: 0.6, softRelief: false)
      shade.edge(brow, style.trim, width: 1.4)
      gem(0, 6, 3)
    case .pearl:
      let band = S.smooth(S.points([(-31, 13), (0, 8), (31, 13), (27, 18), (0, 14), (-27, 18)]))
      shade.part(band, style.trim, pale: true, shadow: 0.3, softRelief: false)
      for x: CGFloat in [-23, -12, 12, 23] { pearl(x, 13, 1.7) }
      wingedClasp(3, span: 22)
    case .paladin: paladinHelm()
    }
  }
}
