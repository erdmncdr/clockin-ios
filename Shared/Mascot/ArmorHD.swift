import CoreGraphics
import Foundation
import ImageIO

struct ArmorHDColor: Sendable {
  var r: Double, g: Double, b: Double
  var cg: CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
  func alpha(_ a: Double) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
  func mix(_ other: Self, _ t: Double) -> Self {
    let t = max(0, min(1, t))
    return .init(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
  }
  static let white = Self(r: 1, g: 1, b: 1)
  static let black = Self(r: 0, g: 0, b: 0)
  static func hsv(_ h: Double, _ s: Double, _ v: Double) -> Self {
    let h = (h - floor(h)) * 6
    let c = v * s
    let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
    let rgb: (Double, Double, Double)
    switch h {
    case ..<1: rgb = (c, x, 0)
    case ..<2: rgb = (x, c, 0)
    case ..<3: rgb = (0, c, x)
    case ..<4: rgb = (0, x, c)
    case ..<5: rgb = (x, 0, c)
    default: rgb = (c, 0, x)
    }
    return .init(r: rgb.0 + v - c, g: rgb.1 + v - c, b: rgb.2 + v - c)
  }
  var hex: String { String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255)) }
}

struct ArmorHDTone: Sendable {
  let hue: Double, saturation: Double
  var prismatic: Bool = false
  // ForgeTone's exposure curve, independent of the application's UI module.
  func metal(_ e: Double) -> ArmorHDColor {
    let e = max(0, min(1, e))
    return .hsv(hue, (0.8 - 0.62 * e) * saturation, 0.16 + 0.84 * e)
  }
}

struct ArmorHDStyle: Sendable {
  let name: String
  let plate: ArmorHDTone
  let trim: ArmorHDTone
  let cloth: ArmorHDTone
  let light: ArmorHDColor

  static func rank(_ stage: Int) -> Self {
    let i = max(0, min(8, stage))
    let metals = [
      (0.6, 0.2), (0.075, 0.85), (0.72, 0.25), (0.12, 0.9), (0.55, 0.12),
      (0.42, 0.45), (0.12, 0.85), (0.62, 0.1), (0.12, 0.28),
    ]
    let faces = [
      (0.6, 0.35), (0.06, 0.55), (0.74, 0.75), (0.07, 0.85), (0.55, 0.85),
      (0.44, 0.85), (0.985, 0.85), (0.67, 0.85), (0.72, 0.3),
    ]
    let stones = [
      (0.57, 0.45), (0.48, 0.7), (0.8, 0.8), (0.08, 1.0), (0.52, 0.85),
      (0.38, 0.95), (0.985, 1.0), (0.63, 0.95), (0.58, 0.08),
    ]
    return .init(
      name: [
        "Steel", "Bronze", "Silver", "Gold", "Platinum", "Emerald", "Sovereign", "Sapphire",
        "White gold",
      ][
        i],
      // RankMaterial hues, with stronger plate saturation for the small companion.
      plate: .init(hue: metals[i].0,
        saturation: [0.95, 1.2, 0.85, 1.2, 0.3, 1.25, 1.05, 0.32, 0.28][i], prismatic: i == 8),
      trim: .init(hue: faces[i].0, saturation: [0.18, 0.5, 1.1, 0.9, 1.0, 0.25, 1.2, 1.25, 0.75][i]),
      cloth: .init(hue: faces[i].0, saturation: faces[i].1),
      light: .hsv(stones[i].0, 0.62 * max(0.2, stones[i].1), 0.96))
  }
  static let gold = rank(3)
  static let steel = rank(0)
  static let bronze = rank(1)
  static let emerald = rank(5)
  static let whiteGold = rank(8)

  var cacheIdentity: String {
    [
      plate.hue, plate.saturation, trim.hue, trim.saturation, cloth.hue, cloth.saturation,
      light.r, light.g, light.b,
    ].map { String($0.bitPattern, radix: 16) }.joined(separator: "-") + "-" + [plate, trim, cloth].map { $0.prismatic ? "1" : "0" }.joined()
  }

}

struct ArmorHDAnchors: Decodable, Sendable {
  let head: [Double], visor: [Double], neck: [Double], back: [Double]
  let handL: [Double]?, handR: [Double]?
  let tilt: Double
  func point(_ values: [Double]) -> CGPoint { CGPoint(x: values[0], y: values[1]) }
}

struct ArmorHDResources: Sendable {
  struct Manifest: Decodable, Sendable {
    let shoulders: [String: [String: [Double]]]
  }
  let anchors: [String: ArmorHDAnchors]
  let manifest: Manifest
  static func url(_ file: String, folder: String) -> URL? {
    for subdir in [nil, folder, "Mascot/" + folder] as [String?] {
      if let url = Bundle.main.url(forResource: file, withExtension: nil, subdirectory: subdir) {
        return url
      }
    }
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Shared/Mascot/" + folder + "/" + file)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
  static func read<T: Decodable>(_ name: String, _ folder: String, as type: T.Type) -> T? {
    url(name, folder: folder).flatMap { try? Data(contentsOf: $0) }.flatMap {
      try? JSONDecoder().decode(type, from: $0)
    }
  }
  static let shared: Self? = {
    guard let a = read("mascot-anchors.json", "Frames", as: [String: ArmorHDAnchors].self),
      let fixed = read("fixed-pose-anchors.json", "Frames", as: [String: ArmorHDAnchors].self),
      let manifest = read("skins.json", "Skins", as: Manifest.self)
    else { return nil }
    return Self(anchors: a.merging(fixed) { _, new in new }, manifest: manifest)
  }()
  static func image(_ frame: String) -> CGImage? {
    var url = url(frame + ".png", folder: "Frames")
    if url == nil, ["pose2", "pose3", "pose4"].contains(frame) {
      url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Clockin/Assets.xcassets/\(frame).imageset/\(frame).png")
    }
    guard let url, let provider = CGDataProvider(url: url as CFURL) else { return nil }
    return CGImage(
      pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )
  }
}

// CGPath is immutable after construction. The lock protects the bounded geometry
// store; each caller owns its CGContext, so rendering can run off the main thread.
private final class ArmorHDGeometryStore: @unchecked Sendable {
  let lock = NSLock()
  var values: [String: ArmorHDGeometry] = [:]
  var order: [String] = []
  func get(_ frame: String, make: () -> ArmorHDGeometry?) -> ArmorHDGeometry? {
    lock.lock()
    defer { lock.unlock() }
    if let value = values[frame] { return value }
    guard let value = make() else { return nil }
    if order.count >= 24 { values.removeValue(forKey: order.removeFirst()) }
    values[frame] = value
    order.append(frame)
    return value
  }
  func clear() {
    lock.lock()
    defer { lock.unlock() }
    values.removeAll()
    order.removeAll()
  }
}

enum ArmorHD {
  static let rendererVersion = "armorhd-4"
  static let frameSize = 480
  // The source antenna is preserved as part of the reconstructed helmet.
  static let hidesAntenna = false
  private static let geometryStore = ArmorHDGeometryStore()
  static func clearGeometryCache() { geometryStore.clear() }
  static func geometry(frame: String) -> ArmorHDGeometry? {
    guard let source = ArmorHDResources.image(frame) else { return nil }
    return geometry(source: source, frame: frame)
  }
  // A frame id identifies immutable source art. Bump rendererVersion if that art changes.
  static func geometry(source: CGImage, frame: String) -> ArmorHDGeometry? {
    geometryStore.get(frame) {
      guard let anchors = ArmorHDResources.shared?.anchors[frame] else { return nil }
      return ArmorHDPixels(source, frame: frame, anchors: anchors).geometry()
    }
  }
  static func render(frame: String, style: ArmorHDStyle = .gold, size: Int) -> CGImage? {
    guard let source = ArmorHDResources.image(frame) else { return nil }
    return render(source: source, frame: frame, style: style, size: size)
  }
  static func render(source: CGImage, frame: String, style: ArmorHDStyle = .gold, size: Int) -> CGImage? {
    guard (32...2048).contains(size), let resources = ArmorHDResources.shared,
      let anchors = resources.anchors[frame],
      let geometry = geometry(source: source, frame: frame), let context = context(size)
    else { return nil }
    context.scaleBy(x: CGFloat(size) / 314, y: CGFloat(size) / 314)
    context.translateBy(x: 0, y: 314)
    context.scaleBy(x: 1, y: -1)
    let parts = ArmorHDParts(
      context: context, style: style, anchors: anchors, frame: frame,
      shoulders: resources.manifest.shoulders[frame] ?? [:])
    parts.back()
    geometry.draw(in: context, style: style)
    parts.front()
    parts.props(mug: geometry.mug)
    geometry.drawHands(in: context, style: style)
    geometry.drawSymbols(in: context, style: style)
    return context.makeImage()
  }
  // Disk policy stays in the Foundation-only cache. ImageIO is used only here
  // at the renderer boundary, without AppKit, UIKit or SwiftUI.
  static func render(frame: String, style: ArmorHDStyle = .gold, size: Int, cache: ArmorHDCache)
    throws -> CGImage?
  {
    guard let source = ArmorHDResources.image(frame) else { return nil }
    return try render(source: source, frame: frame, style: style, size: size, cache: cache)
  }
  static func render(source: CGImage, frame: String, style: ArmorHDStyle = .gold,
                     size: Int, cache: ArmorHDCache) throws -> CGImage? {
    guard (32...2048).contains(size), ArmorHDResources.shared?.anchors[frame] != nil else {
      return nil
    }
    let key = ArmorHDCache.Key(
      version: rendererVersion, frame: frame, style: style.cacheIdentity, size: size)
    if let data = try cache.read(key),
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width == size,
      image.height == size
    {
      return image
    }
    guard let image = render(source: source, frame: frame, style: style, size: size) else { return nil }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    try cache.write(data as Data, for: key)
    return image
  }
  static func context(_ size: Int) -> CGContext? {
    CGContext(
      data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    )
  }
  static func draw(_ image: CGImage, in context: CGContext) {
    context.saveGState()
    context.translateBy(x: 0, y: 314)
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: 314, height: 314))
    context.restoreGState()
  }
}
