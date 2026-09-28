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
var expressions = 0
var matches = 0
let matrixDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("armorhd-matrix-" + UUID().uuidString)
let matrixCache = ArmorHDCache(directory: matrixDirectory)
defer { try? FileManager.default.removeItem(at: matrixDirectory) }
for frame in resources.anchors.keys.sorted() {
  let source = ArmorHDResources.image(frame)!
  for rank in 0..<9 {
  guard let rendered = try ArmorHD.render(source: source, frame: frame, style: .rank(rank), size: 408, cache: matrixCache)
  else { fatalError("\(frame)/\(rank)") }
  check(rendered.width == 408 && rendered.height == 408, "Output dimensions: \(frame)")
  let result = bytes(rendered, size: 314)
  let original = bytes(source, size: 314)
  let a = resources.anchors[frame]!
  var samples = 0
  var visible = 0
  for y in max(0, Int(a.visor[1]) - 24)..<min(314, Int(a.visor[1]) + 25) {
    for x in max(0, Int(a.visor[0]) - 45)..<min(314, Int(a.visor[0]) + 46) {
      let i = (y * 314 + x) * 4
      let r = Int(original[i])
      let g = Int(original[i + 1])
      let b = Int(original[i + 2])
      if original[i + 3] > 240 && g - r > 45 && b - r > 45 && g > 140 {
        samples += 1
        if result[i + 3] > 240 && max(result[i], result[i + 1], result[i + 2]) > 150 {
          visible += 1
        }
      }
    }
  }
  // Boundary cells can move during contour reconstruction; the bulk of every glyph must survive.
  if samples > 0 {
    check(
      Double(visible) / Double(samples) > 0.7,
      "Expression covered or lost: \(frame), \(visible)/\(samples)")
    expressions += samples
    matches += visible
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
  "ok: 594 cached renders, nine ranks over 66 poses at 408 px; \(matches)/\(expressions) source expression samples remain luminous"
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
  let i = (176 * 314 + 175) * 4
  check(pixels[i + 3] > 240 && pixels[i] > 180, "Reconstructed raised mug in \(frame)")
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
let injected = ArmorHD.render(source:blankSource,frame:"pose3",size:408)!
ArmorHD.clearGeometryCache()
let originalPose = ArmorHD.render(frame:"pose3",size:408)!
check(bytes(injected,size:408) != bytes(originalPose,size:408), "Renderer consumes caller's CGImage")
let noPrism = ArmorHDStyle(name:"White gold",plate:.init(hue:ArmorHDStyle.whiteGold.plate.hue,
  saturation:ArmorHDStyle.whiteGold.plate.saturation),trim:ArmorHDStyle.whiteGold.trim,
  cloth:ArmorHDStyle.whiteGold.cloth,light:ArmorHDStyle.whiteGold.light)
check(noPrism.cacheIdentity != ArmorHDStyle.whiteGold.cacheIdentity, "Prismatic material invalidates cache")
check(bytes(ArmorHD.render(frame:"h01",style:noPrism,size:80)!,size:80) !=
  bytes(ArmorHD.render(frame:"h01",style:.whiteGold,size:80)!,size:80), "Prismatic sheen visible at 80 px")
var plateSamples = Set<[UInt8]>()
for rank in 0..<9 {
  let image = bytes(ArmorHD.render(frame:"h01",style:.rank(rank),size:314)!,size:314)
  // Bare forearm and chest, away from visor, gems and wing light.
  let offsets = [(123, 123), (160, 168), (167, 181)]
  plateSamples.insert(offsets.flatMap { x,y in Array(image[(y*314+x)*4..<(y*314+x)*4+3]) })
}
check(plateSamples.count == 9, "All nine plates have distinct metal colours")
print("ok: decoded CGImage source handoff, nine distinct plate metals and prismatic 80 px sheen")
