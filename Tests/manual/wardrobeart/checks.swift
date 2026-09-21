// From repository root:
// swift -module-cache-path /tmp/clockin-art-module-cache iOS/Tests/manual/wardrobeart/main.swift
// Optional first argument is a repository fixture root for negative checks.
import Foundation
import CoreGraphics
import ImageIO

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1) }
}
let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let root: URL = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1]) :
    (fm.fileExists(atPath: cwd.appendingPathComponent("iOS/Shared/Mascot").path) ? cwd : cwd.deletingLastPathComponent())
let mascot = root.appendingPathComponent("iOS/Shared/Mascot")
let frames = mascot.appendingPathComponent("Frames")
func decode<T: Decodable>(_ type: T.Type, _ path: URL) throws -> T {
    try JSONDecoder().decode(type, from: Data(contentsOf: path))
}
struct PNG {
    let width: Int, height: Int, pixels: [UInt8]
    init(_ url: URL) {
        require(FileManager.default.fileExists(atPath: url.path), "Missing image \(url.path)")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Undecodable PNG: \(url.path)")
        }
        require(image.bitsPerComponent == 8 && image.bitsPerPixel == 32 && image.alphaInfo == .last,
                "Expected straight RGBA: \(url.lastPathComponent)")
        width=image.width; height=image.height
        let raw=Array(image.dataProvider!.data! as Data)
        var packed=[UInt8]()
        for y in 0..<height { packed.append(contentsOf:raw[(y*image.bytesPerRow)..<(y*image.bytesPerRow+width*4)]) }
        pixels=packed
    }
    func rgb(_ i: Int) -> Int { Int(pixels[i])<<16 | Int(pixels[i+1])<<8 | Int(pixels[i+2]) }
    func checkArtGrid(_ id: String, opaque: Bool = false, cropped: Bool = false) {
        require(width%2==0 && height%2==0,"Odd art dimensions: \(id)")
        for y in stride(from:0,to:height,by:2) { for x in stride(from:0,to:width,by:2) {
            let i=(y*width+x)*4, alpha=pixels[i+3]
            require(alpha==255 || (!opaque && alpha==0),"Antialiased art: \(id)")
            for (dx,dy) in [(1,0),(0,1),(1,1)] {
                let j=((y+dy)*width+x+dx)*4
                require(pixels[i..<(i+4)]==pixels[j..<(j+4)],"Broken 2x2 art cell: \(id)")
            }
        } }
        if cropped {
            require((0..<width).contains{pixels[$0*4+3]>0},"Empty top edge: \(id)")
            require((0..<width).contains{pixels[((height-1)*width+$0)*4+3]>0},"Empty bottom edge: \(id)")
            require((0..<height).contains{pixels[($0*width)*4+3]>0},"Empty left edge: \(id)")
            require((0..<height).contains{pixels[($0*width+width-1)*4+3]>0},"Empty right edge: \(id)")
        }
    }
}
func point(_ p:[Double],_ w:Int,_ h:Int,_ message:String) {
    require(p.count==2 && p.allSatisfy{$0.isFinite},"Malformed point: \(message)")
    require(p[0]>=0 && p[0]<Double(w) && p[1]>=0 && p[1]<Double(h),"Point outside canvas: \(message)")
}
struct Anchor: Decodable {
    let head:[Double],visor:[Double],neck:[Double],back:[Double],handL:[Double]?,handR:[Double]?,tilt:Double
}
struct Garment: Decodable { let slot:String,anchorPoint:String,pivot:[Double],layer:String; let poseOffsets:[String:[Double]]? }
struct Room: Decodable { let name:String,file:String,floorY:Double,slots:[String:[Double]],mascotSpot:[Double] }
struct Furniture: Decodable { let name:String,file:String,slot:String,pivot:[Double] }
struct Home: Decodable { let rooms:[String:Room],items:[String:Furniture] }
let frameURLs = try fm.contentsOfDirectory(at:frames,includingPropertiesForKeys:nil).filter {
    $0.lastPathComponent.range(of:"^[htceazp].*\\.png$",options:.regularExpression) != nil
}
require(!frameURLs.isEmpty,"No companion frames")
let anchors = try decode([String:Anchor].self,frames.appendingPathComponent("mascot-anchors.json"))
let frameIDs=Set(frameURLs.map{$0.deletingPathExtension().lastPathComponent})
require(Set(anchors.keys)==frameIDs,"Anchor coverage must match every matching frame exactly")
let rawAnchors=try JSONSerialization.jsonObject(with:Data(contentsOf:frames.appendingPathComponent("mascot-anchors.json"))) as! [String:[String:Any]]
var sourceColors=Set<Int>()
for url in frameURLs {
    let id=url.deletingPathExtension().lastPathComponent, png=PNG(url), a=anchors[id]!
    require(png.width==314 && png.height==314,"Frame canvas: \(id)")
    require(Set(rawAnchors[id]!.keys)==Set(["head","visor","neck","back","handL","handR","tilt"]),"Anchor schema: \(id)")
    for (key,p) in [("head",a.head),("visor",a.visor),("neck",a.neck),("back",a.back),("handL",a.handL),("handR",a.handR)] {
        if let p=p { point(p,314,314,"\(id).\(key)") }
    }
    require(a.tilt.isFinite && abs(a.tilt)<=45,"Implausible tilt: \(id)")
    require(a.head[1]<a.visor[1] && a.visor[1]<a.neck[1] && a.neck[1]<a.back[1],"Anatomical order: \(id)")
    for i in stride(from:0,to:png.pixels.count,by:4) where png.pixels[i+3]==255 { sourceColors.insert(png.rgb(i)) }
}
print("ok: \(anchors.count) frames, exact coverage, finite in-canvas anchors and anatomical order")
let fixedAnchors = try decode([String:Anchor].self, frames.appendingPathComponent("fixed-pose-anchors.json"))
require(Set(fixedAnchors.keys) == Set(["pose2", "pose3", "pose4"]), "Fixed pose coverage")
let fixedRaw = try JSONSerialization.jsonObject(with: Data(contentsOf: frames.appendingPathComponent("fixed-pose-anchors.json"))) as! [String:[String:Any]]
let everyAnchor = anchors.merging(fixedAnchors) { original, _ in original }
let everyRaw = rawAnchors.merging(fixedRaw) { original, _ in original }
let wardrobeURL=mascot.appendingPathComponent("Wardrobe")
let wardrobe=try decode([String:Garment].self,wardrobeURL.appendingPathComponent("wardrobe-sprites.json"))
require(wardrobe.count>=24,"Need at least 24 garments")
let requiredSlots=["head":8,"face":4,"neck":4,"back":4,"hand":4]
let anchorForSlot=["head":"head","face":"visor","neck":"neck","back":"back","hand":"handR"]
for (slot,count) in requiredSlots { require(wardrobe.values.filter{$0.slot==slot}.count>=count,"Missing \(slot) garments") }
for (id,g) in wardrobe {
    require(g.anchorPoint==(id=="headphones" ? "visor":anchorForSlot[g.slot]),"Slot/anchor mismatch: \(id)")
    require(g.layer==(g.slot=="back" ? "back":"front"),"Wrong layer: \(id)")
    let png=PNG(wardrobeURL.appendingPathComponent(id+".png"))
    point(g.pivot,png.width,png.height,id+" pivot")
    png.checkArtGrid(id,cropped:true)
    // A garment must remain visible during the highest celebration poses too.
    for (frameID, frame) in everyAnchor {
        let raw = everyRaw[frameID]!
        guard var anchor = raw[g.anchorPoint] as? [Double] else { continue }
        let offset = g.poseOffsets?[frameID] ?? g.poseOffsets?[String(frameID.prefix(1))] ?? [0, 0]
        require(offset.count == 2 && offset.allSatisfy { $0.isFinite }, "Invalid pose offset: \(id)/\(frameID)")
        anchor[0] += offset[0]; anchor[1] += offset[1]
        let angle = (["head", "face"].contains(g.slot) ? frame.tilt : 0) * Double.pi / 180
        for (x, y) in [(0.0, 0.0), (Double(png.width), 0.0),
                       (0.0, Double(png.height)), (Double(png.width), Double(png.height))] {
            let dx = x - g.pivot[0], dy = y - g.pivot[1]
            let px = anchor[0] + dx * cos(angle) - dy * sin(angle)
            let py = anchor[1] + dx * sin(angle) + dy * cos(angle)
            require((0...314).contains(px) && (0...314).contains(py), "Garment clipped: \(frameID)/\(id)")
        }
    }
}
print("ok: \(wardrobe.count) garments, slot counts, layers, pivots, tight crops, 2x2 pixel cells and unclipped placement in every frame")
func rgbValue(_ s:String)->Int? {
    guard s.range(of:"^#[0-9A-F]{6}$",options:.regularExpression) != nil else { return nil }
    return Int(s.dropFirst(),radix:16)
}
let colorData = try Data(contentsOf: frames.appendingPathComponent("colorways.json"))
require(colorData.count < 20_000, "Colorways must stay under 20 KB")
let ways = try JSONDecoder().decode([String: WardrobeColorway].self, from: colorData)
require(Set(ways.keys) == Set(["classic","midnight","mint","sunset","gold","stealth"]), "Six colorways")
for (id, way) in ways {
    require(way.identity == (id == "classic"), "Only Classic is identity")
    require(Set(way.rules.map(\.kind)) == Set(["shell","highlights","grays","joints","accents","glow"]), "Color classes: \(id)")
    for rule in way.rules {
        require(rule.hue.count == 2 && rule.saturation.count == 2 && rule.luminance.count == 2, "Rule ranges")
        require(rule.targets.count == 2 && rule.targets.allSatisfy { rgbValue($0) != nil }, "Rule targets")
    }
    var black = [UInt8]()
    for source in sourceColors where max((source>>16)&255,(source>>8)&255,source&255)<80 {
        black += [UInt8((source>>16)&255), UInt8((source>>8)&255), UInt8(source&255), 255]
    }
    let visor = black
    WardrobePalette.recolor(&black, colorway: way)
    require(black == visor, "All source black visor shades preserved: \(id)")
    var tiny: [UInt8] = [232,232,232,255, 255,119,26,255, 73,235,255,128, 1,2,3,255, 255,255,255,0]
    let original = tiny
    WardrobePalette.recolor(&tiny, colorway: way)
    if id == "classic" { require(tiny == original, "Classic identity") }
    else {
        require(tiny[0..<3] != original[0..<3] && tiny[4..<7] != original[4..<7] && tiny[8..<11] != original[8..<11], "Tiny shell accent glow recolor")
        require(tiny[11] == 128 && tiny[12...] == original[12...], "Alpha, visor and transparent pixels unchanged")
    }
}
print("ok: \(ways.count) colorways, \(colorData.count) bytes, six classes, tiny RGBA recolor, classic identity and all source visor shades preserved")
let homeURL=mascot.appendingPathComponent("Home")
let home=try decode(Home.self,homeURL.appendingPathComponent("home-items.json"))
require(Set(["cozy","studio","night"]).isSubset(of:Set(home.rooms.keys)),"Missing rooms")
require(home.items.count>=16,"Need at least 16 home items")
let slots=Set(["floorLeft","floorRight","wallLeft","wallRight","window","rug","desk","shelf"])
for (id,room) in home.rooms {
    require(room.file=="room-"+id+".png","Unexpected room filename")
    let png=PNG(homeURL.appendingPathComponent(room.file))
    require(png.width==360 && png.height==240,"Room dimensions: \(id)")
    png.checkArtGrid(id,opaque:true)
    require(Set(room.slots.keys)==slots,"Room slots: \(id)")
    require(room.floorY>=0 && room.floorY<240,"Floor outside room")
    for (slot,p) in room.slots { point(p,360,240,id+" "+slot) }
    point(room.mascotSpot,360,240,id+" mascotSpot")
    require(room.mascotSpot[1]>=room.floorY,"Companion feet above floor")
}
for (id,item) in home.items {
    require(item.file==id+".png" && slots.contains(item.slot),"Item filename or slot: \(id)")
    let png=PNG(homeURL.appendingPathComponent(item.file))
    png.checkArtGrid(id)
    point(item.pivot,png.width,png.height,id+" pivot")
    for (roomID,room) in home.rooms {
        let slot=room.slots[item.slot]!,x=slot[0]-item.pivot[0],y=slot[1]-item.pivot[1]
        require(x>=0 && y>=0 && x+Double(png.width)<=360 && y+Double(png.height)<=240,"Furniture clipped: \(roomID)/\(id)")
    }
}
print("ok: \(home.rooms.count) rooms, \(home.items.count) items, slot/pivot placement and unclipped furniture in every room")
print("ok: wardrobe art contract")
