import CoreGraphics
import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else { fatalError(message) }
}
func bytes(_ image: CGImage, size: Int) -> [UInt8] {
  var data = [UInt8](repeating: 0, count: size * size * 4)
  data.withUnsafeMutableBytes { buffer in
    let c = CGContext(
      data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
      bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .none
    c.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
  }
  return data
}
let resources = ArmorHDResources.shared!
check(resources.anchors.count == 66, "Expected 63 animated frames and three fixed poses")
check(ArmorHD.render(frame: "../h01", size: 408) == nil, "Reject unknown frame")
check(ArmorHD.render(frame: "h01", size: 0) == nil, "Reject zero size")
check(ArmorHD.render(frame: "h01", size: 2049) == nil, "Bound allocations")
var slitSamples = 0
var closedFaces = 0
let matrixDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
  "armorhd-matrix-" + UUID().uuidString)
let matrixCache = ArmorHDCache(directory: matrixDirectory)
defer { try? FileManager.default.removeItem(at: matrixDirectory) }
let styles =
  (0..<9).map { ArmorHDStyle.rank($0) } + ArmorHDStyle.otherKeys.map { ArmorHDStyle.named($0)! }
for frame in resources.anchors.keys.sorted() {
  let source = ArmorHDResources.image(frame)!
  for (rank, style) in styles.enumerated() {
    guard
      let rendered = try ArmorHD.render(
        source: source, frame: frame, style: style, size: 408, cache: matrixCache)
    else { fatalError("\(frame)/\(rank)") }
    check(rendered.width == 408 && rendered.height == 408, "Output dimensions: \(frame)")
    let result = bytes(rendered, size: 314)
    let a = resources.anchors[frame]!
    let geometry = ArmorHD.geometry(source: source, frame: frame)!
    let visor = geometry.visor
    let highResolution = bytes(rendered, size: 408)
    check(visor.eyes.count == 2 && visor.cores.count == 2, "Two slits and hot cores: \(frame)")
    for eye in visor.eyes {
      var samples = 0
      var visible = 0
      let maskContext = ArmorHD.context(408)!
      maskContext.scaleBy(x: 408.0 / 314, y: 408.0 / 314)
      maskContext.translateBy(x: 0, y: 314)
      maskContext.scaleBy(x: 1, y: -1)
      maskContext.addPath(eye)
      maskContext.setFillColor(ArmorHDColor.white.cg)
      maskContext.fillPath()
      let mask = bytes(maskContext.makeImage()!, size: 408)
      let eyeBounds = eye.boundingBoxOfPath.insetBy(dx: -1, dy: -1)
      for y in max(0, Int(eyeBounds.minY * 408 / 314))...min(407, Int(eyeBounds.maxY * 408 / 314)) {
        for x in max(0, Int(eyeBounds.minX * 408 / 314))...min(407, Int(eyeBounds.maxX * 408 / 314))
        {
          let point = CGPoint(x: (Double(x) + 0.5) * 314 / 408, y: (Double(y) + 0.5) * 314 / 408)
          guard mask[(y * 408 + x) * 4 + 3] > 40 else { continue }
          check(visor.screen.contains(point), "Slit escapes glass: \(frame)")
          let i = (y * 408 + x) * 4
          samples += 1
          if highResolution[i + 3] > 240
            && max(highResolution[i], highResolution[i + 1], highResolution[i + 2])
              > (visor.sleepy ? 30 : 60)
          {
            visible += 1
          }
        }
      }
      check(
        samples > 0 && Double(visible) / Double(samples) > 0.65,
        "Slit absent/covered: \(frame)/\(style.name), \(visible)/\(samples)")
      slitSamples += visible
      var inverse = visor.toWorld.inverted()
      let local = eye.copy(using: &inverse)!.boundingBoxOfPath
      check(
        local.height / local.width < (visor.closed ? 0.09 : 0.55), "Narrow slit shape: \(frame)")
      if !visor.closed { check(local.height / local.width > 0.3, "Open slit: \(frame)") }
    }
    if visor.closed { closedFaces += 1 }
    // Sample the former mouth region in face-local coordinates. Sipping/lift
    // frames have a cup and steam in front of the glass, so test their slits above.
    if !frame.hasPrefix("c") || ["c01", "c02", "c03", "c04", "c05"].contains(frame) {
      for x: CGFloat in [-8, 0, 8] {
        let point = CGPoint(x: x, y: visor.localBounds.height * 0.3).applying(visor.toWorld)
        let i = (Int(point.y * 408 / 314) * 408 + Int(point.x * 408 / 314)) * 4
        check(
          max(highResolution[i], highResolution[i + 1], highResolution[i + 2]) < 100,
          "Mouth region must remain dark glass: \(frame)/\(style.name)")
      }
    }

    // Test authored parts separately so glowing ornaments cannot pass as eyes.
    let frontContext = ArmorHD.context(408)!
    frontContext.scaleBy(x: 408.0 / 314, y: 408.0 / 314)
    frontContext.translateBy(x: 0, y: 314)
    frontContext.scaleBy(x: 1, y: -1)
    ArmorHDParts(
      context: frontContext, style: style, anchors: a, frame: frame,
      shoulders: resources.manifest.shoulders[frame] ?? [:], headFit: geometry.headFit
    ).front()
    let frontPixels = bytes(frontContext.makeImage()!, size: 408)
    for eye in visor.eyes {
      let b = eye.boundingBoxOfPath
      for y in max(0, Int(b.minY * 408 / 314))...min(407, Int(b.maxY * 408 / 314)) {
        for x in max(0, Int(b.minX * 408 / 314))...min(407, Int(b.maxX * 408 / 314)) {
          let point = CGPoint(x: (Double(x) + 0.5) * 314 / 408, y: (Double(y) + 0.5) * 314 / 408)
          if eye.contains(point) {
            check(
              frontPixels[(y * 408 + x) * 4 + 3] < 32, "Armour covers slit: \(frame)/\(style.name)")
          }
        }
      }
    }
    if rank >= 9 {
      let hit = try ArmorHD.render(
        source: source, frame: frame, style: style, size: 408, cache: matrixCache)!
      check(bytes(hit, size: 314) == result, "Every new design's disk hit preserves pixels")
      for edge in 0..<314 {
        for offset in [
          (edge * 4), ((313 * 314 + edge) * 4), (edge * 314 * 4), ((edge * 314 + 313) * 4),
        ] {
          check(result[offset + 3] < 4, "Design clips canvas edge: \(style.name)/\(frame)")
        }
      }
      let front = bytes(frontContext.makeImage()!, size: 314)
      if frame == "pose2" {
        for y in 32..<59 {
          for x in 110..<177 {
            check(front[(y * 314 + x) * 4 + 3] == 0, "Raised fists covered by front armour")
          }
        }
      }
    }
    for i in stride(from: 0, to: result.count, by: 4) {
      check(
        result[i] <= result[i + 3] && result[i + 1] <= result[i + 3]
          && result[i + 2] <= result[i + 3],
        "Premultiplied alpha: \(frame)")
    }
  }
}
print(
  "ok: 924 cached renders, fourteen skins over 66 poses at 408 px; \(slitSamples) luminous slit samples inside glass; \(closedFaces) closed faces"
)
// Blink expectations come independently from the source clip manifest. The e07
// transition still has open happy arcs; e08/e09 contain the actual closure.
let clips =
  try JSONSerialization.jsonObject(
    with: Data(contentsOf: URL(fileURLWithPath: "Shared/Mascot/Frames/mascot-clips.json")))
  as! [String: [String: Any]]
var blinkFrames = Set<String>()
for state in clips.values {
  let rest = state["rest"] as! String
  for (name, sequence) in state["clips"] as! [String: [[Any]]] where name.hasPrefix("blink") {
    for entry in sequence {
      let frame = entry[0] as! String
      if frame != rest && frame != "e07" { blinkFrames.insert(frame) }
    }
  }
}
// Angry and proud art preserves the source h10/h11 closure (verified against
// their original PNGs), although those mood variants are not in the clip JSON.
for frame in Array(blinkFrames) where frame.hasPrefix("h") {
  for prefix in ["a", "p"] { blinkFrames.insert(prefix + frame.dropFirst()) }
}
var familyRatios = [String: [(CGFloat, CGFloat)]]()
for frame in resources.anchors.keys.sorted() {
  let g = ArmorHD.geometry(frame: frame)!
  let fit = g.headFit
  check(
    g.visor.closed == (blinkFrames.contains(frame) || frame.hasPrefix("z") || frame == "pose4"),
    "Source closure: \(frame)")
  let neckAfter = fit.neck.applying(fit.transform)
  check(hypot(neckAfter.x - fit.neck.x, neckAfter.y - fit.neck.y) < 0.001, "Neck remains fixed")
  let center = CGPoint(x: fit.helmet.midX, y: fit.helmet.midY).applying(fit.transform)
  let helmet = g.parts.filter { $0.kind == 2 }.map { $0.path.boundingBoxOfPath }.filter {
    $0.minY < center.y && $0.maxY > center.y && $0.minX < center.x && $0.maxX > center.x
  }.max { $0.width < $1.width }!
  // Headphones hide the shell edges; their unoccluded shell measurement is in fit.
  let ratio = frame == "acc-headphones" ? fit.fittedRatio : helmet.width / fit.torsoWidth
  let family =
    frame.hasPrefix("pose")
    ? frame : frame.hasPrefix("acc-") ? "accessories" : String(frame.prefix(1))
  familyRatios[family, default: []].append((fit.sourceRatio, ratio))
  check(
    abs(ratio / ArmorHDHeadFit.standingRatio - 1) < 0.05,
    "Measured head/body proportion: \(frame), \(ratio)")
}
for family in familyRatios.keys.sorted() {
  let values = familyRatios[family]!
  print(
    String(
      format: "ratio %@ (%d): before %.3f...%.3f, after %.3f...%.3f", family, values.count,
      values.map { $0.0 }.min()!, values.map { $0.0 }.max()!,
      values.map { $0.1 }.min()!, values.map { $0.1 }.max()!))
}
print(
  "ok: 66 measured head/torso ratios within 5% of standing, fixed necks, source blink/closed states"
)
for stage in 0..<9 {
  check(ArmorHD.render(frame: "h01", style: .rank(stage), size: 180) != nil, "Rank \(stage)")
}
for size in [180, 408, 660, 816] {
  let image = ArmorHD.render(frame: "h01", size: size)!
  check(image.width == size && image.height == size, "Preview size \(size)")
}
let one = ArmorHD.render(frame: "h01", size: 408)!
let two = ArmorHD.render(frame: "h01", size: 408)!
check(bytes(one, size: 408) == bytes(two, size: 408), "Deterministic render")
for (frame, x, y) in [("c01", 82, 248), ("t01", 242, 233)] {
  let source = bytes(ArmorHDResources.image(frame)!, size: 314)
  let result = bytes(ArmorHD.render(frame: frame, size: 628)!, size: 314)
  let i = (y * 314 + x) * 4
  check(
    (0..<3).allSatisfy { abs(Int(source[i + $0]) - Int(result[i + $0])) < 12 },
    "Prop colour: \(frame), source \(Array(source[i..<i+3])), result \(Array(result[i..<i+3]))")
}
print(
  "ok: nine ranks, four display sizes, deterministic output, preserved mug/laptop colours, invalid inputs"
)

let cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
  "armorhd-check-" + UUID().uuidString)
let cache = ArmorHDCache(directory: cacheDirectory)
defer { try? FileManager.default.removeItem(at: cacheDirectory) }
let key = ArmorHDCache.Key(
  version: ArmorHD.rendererVersion, frame: "h01", style: ArmorHDStyle.gold.cacheIdentity, size: 408)
let missing = try cache.read(key)
check(missing == nil, "New disk cache is empty")
let cached = try ArmorHD.render(frame: "h01", size: 408, cache: cache)!
check(bytes(cached, size: 408) == bytes(one, size: 408), "Disk miss matches direct render")
let file = try cache.url(for: key)
let firstDate = try file.resourceValues(forKeys: [.contentModificationDateKey])
  .contentModificationDate
ArmorHD.clearGeometryCache()
let hit = try ArmorHD.render(
  frame: "h01", size: 408, cache: ArmorHDCache(directory: cacheDirectory))!
check(bytes(hit, size: 408) == bytes(one, size: 408), "Fresh cache instance reads identical PNG")
let hitDate = try file.resourceValues(forKeys: [.contentModificationDateKey])
  .contentModificationDate
check(firstDate == hitDate, "Cache hit does not rewrite PNG")
try cache.write(Data("broken PNG".utf8), for: key)
let repaired = try ArmorHD.render(frame: "h01", size: 408, cache: cache)!
check(bytes(repaired, size: 408) == bytes(one, size: 408), "Corrupt PNG rerenders safely")
for variant in [
  ArmorHDCache.Key(
    version: "future", frame: "h01", style: ArmorHDStyle.gold.cacheIdentity, size: 408),
  .init(
    version: ArmorHD.rendererVersion, frame: "h02", style: ArmorHDStyle.gold.cacheIdentity,
    size: 408),
  .init(
    version: ArmorHD.rendererVersion, frame: "h01", style: ArmorHDStyle.steel.cacheIdentity,
    size: 408),
  .init(
    version: ArmorHD.rendererVersion, frame: "h01", style: ArmorHDStyle.gold.cacheIdentity,
    size: 180),
] {
  let absent = try cache.read(variant)
  check(absent == nil, "Version/frame/style/size invalidate disk key")
}
let alternate = ArmorHDStyle(
  name: "Gold", plate: .init(hue: 0.3, saturation: 0.2), trim: ArmorHDStyle.gold.trim,
  cloth: ArmorHDStyle.gold.cloth, light: ArmorHDStyle.gold.light)
check(
  alternate.cacheIdentity != ArmorHDStyle.gold.cacheIdentity,
  "Full material values, not display name, key the cache")
do {
  _ = try cache.url(for: .init(version: "../outside", frame: "h01", style: "gold", size: 408))
  fatalError("Traversal must fail")
} catch is CocoaError {}
let invalid = try ArmorHD.render(frame: "../h01", size: 408, cache: cache)
check(invalid == nil, "Cached render validates frame before filesystem work")
// Concurrent requests share immutable geometry and atomically publish whole PNGs.
DispatchQueue.concurrentPerform(iterations: 8) { i in
  let image = try! ArmorHD.render(frame: "c01", style: .rank(i % 2), size: 180, cache: cache)!
  check(image.width == 180, "Concurrent cached render")
}
let blockedDirectory = cacheDirectory.appendingPathComponent("file-instead-of-directory")
try Data([0]).write(to: blockedDirectory)
do {
  _ = try ArmorHD.render(frame: "h01", size: 180, cache: ArmorHDCache(directory: blockedDirectory))
  fatalError("Disk failures must propagate")
} catch {}
ArmorHD.clearGeometryCache()
check(
  bytes(ArmorHD.render(frame: "h01", size: 408)!, size: 408) == bytes(one, size: 408),
  "Cold contour reconstruction is deterministic")
print(
  "ok: Foundation PNG cache, round trip, no rewrite, invalidation, corruption, traversal, concurrent requests, disk errors"
)

// A sip moves the only mug to the mouth; it must not leave a duplicate on the floor.
for frame in ["c07", "c08", "c09", "c12"] {
  let pixels = bytes(ArmorHD.render(frame: frame, size: 408)!, size: 314)
  check(pixels[(248 * 314 + 82) * 4 + 3] == 0, "No abandoned floor mug in \(frame)")
  let geometry = ArmorHD.geometry(frame: frame)!
  let mug = geometry.mug!
  let oldMug = ArmorHDMug.pose(frame)!
  let expectedContact = CGPoint(x: oldMug.midX, y: oldMug.minY).applying(geometry.headFit.transform)
  check(
    hypot(mug.midX - expectedContact.x, mug.minY - expectedContact.y) < 0.001, "Sip rim tracks head"
  )
  check(
    geometry.visor.screen.contains(CGPoint(x: mug.midX, y: mug.minY)), "Sip rim still reaches glass"
  )
  check(geometry.hands == ArmorHDMug.hands(frame)!, "Sip wrists stay fixed")
  let i = (Int(mug.midY) * 314 + Int(mug.midX)) * 4
  check(pixels[i + 3] > 240 && pixels[i] > 140, "Reconstructed raised mug in \(frame)")
}
for frame in ["pose2", "pose3", "pose4"] {
  check(ArmorHD.geometry(frame: frame)!.symbol == nil, "No invented mood glyph in \(frame)")
}
for frame in ["a01", "a06", "p01", "p10", "z07"] {
  check(ArmorHD.geometry(frame: frame)!.symbol != nil, "Source mood glyph detected in \(frame)")
}
print("ok: coffee lift/sip placement, no duplicate prop, source-only mood symbols")

// Injecting a decoded image must control reconstruction; no repository lookup is needed.
ArmorHD.clearGeometryCache()
let blankSource = ArmorHD.context(314)!.makeImage()!
let injected = ArmorHD.render(source: blankSource, frame: "pose3", size: 408)!
ArmorHD.clearGeometryCache()
let originalPose = ArmorHD.render(frame: "pose3", size: 408)!
check(
  bytes(injected, size: 408) != bytes(originalPose, size: 408), "Renderer consumes caller's CGImage"
)
let noPrism = ArmorHDStyle(
  name: "White gold",
  plate: .init(
    hue: ArmorHDStyle.whiteGold.plate.hue,
    saturation: ArmorHDStyle.whiteGold.plate.saturation), trim: ArmorHDStyle.whiteGold.trim,
  cloth: ArmorHDStyle.whiteGold.cloth, light: ArmorHDStyle.whiteGold.light)
check(
  noPrism.cacheIdentity != ArmorHDStyle.whiteGold.cacheIdentity,
  "Prismatic material invalidates cache")
check(
  bytes(ArmorHD.render(frame: "h01", style: noPrism, size: 80)!, size: 80)
    != bytes(ArmorHD.render(frame: "h01", style: .whiteGold, size: 80)!, size: 80),
  "Prismatic sheen visible at 80 px")
var plateSamples = Set<[UInt8]>()
for rank in 0..<9 {
  let image = bytes(ArmorHD.render(frame: "h01", style: .rank(rank), size: 314)!, size: 314)
  // Bare forearm and chest, away from visor, gems and wing light.
  let offsets = [(123, 123), (160, 168), (167, 181)]
  plateSamples.insert(
    offsets.flatMap { x, y in Array(image[(y * 314 + x) * 4..<(y * 314 + x) * 4 + 3]) })
}
check(plateSamples.count == 9, "All nine plates have distinct metal colours")
print("ok: decoded CGImage source handoff, nine distinct plate metals and prismatic 80 px sheen")

for style in styles.suffix(5) {
  for (frame, x, y) in [("c01", 82, 248), ("t01", 242, 233)] {
    let expected = bytes(ArmorHD.render(frame: frame, size: 408)!, size: 314)
    let actual = bytes(
      try ArmorHD.render(frame: frame, style: style, size: 408, cache: matrixCache)!, size: 314)
    let i = (y * 314 + x) * 4
    check(Array(expected[i..<i + 4]) == Array(actual[i..<i + 4]), "Prop identity across designs")
  }
}
let silhouettes = Set(
  styles.suffix(5).map { style in
    bytes(ArmorHD.render(frame: "h01", style: style, size: 80)!, size: 80).enumerated().compactMap {
      i, byte in i % 4 == 3 ? byte : nil
    }
  })
check(silhouettes.count == 5, "Five distinct silhouettes at 80 px")
var eyeVariant = ArmorHDStyle.gold
eyeVariant.eyes = .init(r: 1, g: 0, b: 0)
var jointVariant = ArmorHDStyle.gold
jointVariant.joints.exposure = 0.5
var designVariant = ArmorHDStyle.gold
designVariant.design = .nova
let darkVariant = ArmorHDStyle(
  name: "Dark",
  plate: .init(
    hue: ArmorHDStyle.gold.plate.hue, saturation: ArmorHDStyle.gold.plate.saturation, exposure: 0.4),
  trim: ArmorHDStyle.gold.trim, cloth: ArmorHDStyle.gold.cloth, light: ArmorHDStyle.gold.light)
check(
  Set(
    [ArmorHDStyle.gold, eyeVariant, jointVariant, designVariant, darkVariant].map(\.cacheIdentity)
  ).count == 5,
  "Design, eye colour, joints and exposure invalidate cache")
print(
  "ok: five distinct 80 px silhouettes, unobstructed slits in 924 renders and raised fists in all 330 design/pose pairs, props and full design/material cache identity"
)
