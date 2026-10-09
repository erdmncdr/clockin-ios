import Foundation
import CoreGraphics
import ImageIO
import SwiftUI

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("website/dist/assets/gallery")
func read<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent("Shared/Mascot/" + path)))
}
func image(_ path: String) -> CGImage {
    let url = root.appendingPathComponent("Shared/Mascot/" + path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError(path) }
    return image
}
func save(_ image: CGImage?, _ name: String) {
    guard let image, let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil) else { fatalError(name) }
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), name)
}
func canvas(_ width: Int, _ height: Int, scale: Double = 1) -> CGContext {
    let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .none
    c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: scale, y: -scale)
    return c
}
func draw(_ img: CGImage, _ rect: CGRect, in c: CGContext, mirrored: Bool = false) {
    c.saveGState(); c.translateBy(x: mirrored ? rect.maxX : rect.minX, y: rect.maxY)
    c.scaleBy(x: mirrored ? -1 : 1, y: -1)
    c.draw(img, in: CGRect(origin: .zero, size: rect.size)); c.restoreGState()
}
let anchors = try read([String: WardrobeAnchors].self, "Frames/mascot-anchors.json")
let sprites = try read([String: WardrobeSprite].self, "Wardrobe/wardrobe-sprites.json")
let home = try read(WardrobeHome.self, "Home/home-items.json")
let original = image("Frames/h01.png")
let robot = WardrobeArt.removingAntenna(original, frame: "h01")
save(WardrobeArt.composite(robot: robot, parts: [], size: 628), "outfit-base")
let clear = canvas(314, 314).makeImage()!
var outfit = WardrobeState()
for (i, id) in ["cap", "round-glasses", "scarf"].enumerated() {
    let sprite = sprites[id]!
    outfit.equipped[sprite.slot] = id
    let images = Dictionary(uniqueKeysWithValues: outfit.equipped.values.map { ($0, image("Wardrobe/" + $0 + ".png")) })
    let parts = WardrobeArt.overlays(frame: "h01", outfit: outfit, images: images, anchorManifest: anchors, spriteManifest: sprites)
    precondition(parts.count == i + 1)
    save(WardrobeArt.composite(robot: robot, parts: parts, size: 628), "outfit-\(i + 1)")
    save(WardrobeArt.composite(robot: clear, parts: parts.filter { $0.id == id }, size: 628), "layer-\(id)")
}
for (name, ids) in [
    ("cozy", ["round-rug", "bookshelf", "potted-plant", "wall-clock", "cat-bed", "big-plant", "desk-lamp"]),
    ("night", ["round-rug", "bookshelf", "potted-plant", "string-lights", "floor-lamp", "bean-bag", "record-player"]),
    ("studio", ["round-rug", "bookshelf", "poster", "certificate", "coffee-machine", "guitar", "desk-monitor"])
] {
    let room = home.rooms[name]!
    let c = canvas(1080, 720, scale: 3)
    draw(image("Home/" + room.file), CGRect(x: 0, y: 0, width: 360, height: 240), in: c)
    for id in ids {
        let item = home.items[id]!, img = image("Home/" + home.items[id]!.file)
        let rect = HomeSceneLayout.furnitureRect(item, in: room, imageSize: CGSize(width: img.width, height: img.height), layout: .deskLeft)
        draw(img, rect, in: c)
    }
    let activity: CompanionHomeActivity = .idle
    let center = activity.center(in: room, layout: .deskLeft)
    draw(original, CGRect(x: center.x - activity.side/2, y: center.y - activity.side/2, width: activity.side, height: activity.side), in: c)
    save(c.makeImage(), "room-" + name)
}
for (index, stage) in [0, 3, 5, 8].enumerated() {
    save(ArmorHD.render(frame: "h01", style: .rank(stage), size: 700), "armor-\(index)")
    let style = LevelPrestige(level: max(1, stage * LevelPrestige.interval))
    let badge = HStack(spacing: 9) {
        PrestigeInsignia(style: style).frame(width: 26, height: 28)
        VStack(spacing: 5) {
            Text("\(style.level)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
            PrestigeGroove(style: style, fraction: 0.65).frame(width: 66, height: 5)
        }
    }.padding(.horizontal, 10).padding(.vertical, 8)
    .background { ZStack { PrestigeMetalFrame(style: style); RankSignature(style: style, layer: .under, time: nil) } }
    .overlay { ZStack { PrestigeFrontOrnaments(style: style); RankSignature(style: style, layer: .over, time: nil) } }
    .frame(width: 210, height: 96)
    let renderer = ImageRenderer(content: badge); renderer.scale = 3
    save(renderer.cgImage, "rank-\(index)")
}
// The app derives sleepy/angry moods from the hello clip timings; preserve the frames.
for prefix in ["a", "z"] {
    for suffix in ["01", "02", "06", "07", "08", "10", "11"] {
        let id = prefix + suffix
        save(WardrobeArt.composite(robot: image("Frames/" + id + ".png"), parts: [], size: 314), id)
    }
}
