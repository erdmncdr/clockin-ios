import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1) }
}
func bytes(_ image: CGImage) -> [UInt8] {
    if image.alphaInfo == .last && image.bitsPerPixel == 32 {
        let data = image.dataProvider!.data! as Data
        return (0..<image.height).flatMap { Array(data[($0*image.bytesPerRow)..<($0*image.bytesPerRow+image.width*4)]) }
    }
    var result = [UInt8](repeating: 0, count: image.width*image.height*4)
    result.withUnsafeMutableBytes { buffer in
        let c = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                          bytesPerRow: image.width*4, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.interpolationQuality = .none
        c.draw(image, in: CGRect(x:0,y:0,width:image.width,height:image.height))
    }
    return result
}
func load(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source,0,nil) else {
        fatalError("Cannot decode \(url.path)")
    }
    return image
}
// The connected dark face encloses its eyes. Sleep letters and sparks outside
// that component are animation effects, even when they share the glow palette.
func visorMask(_ raw: [UInt8], _ anchor: WardrobePoint) -> Set<Int> {
    func dark(_ index: Int) -> Bool {
        let i = index*4
        return raw[i+3] > 240 && max(raw[i],raw[i+1],raw[i+2]) < 80
    }
    let candidates = (0..<(314*314)).filter { index in
        abs(Double(index%314)-anchor.x) < 12 && abs(Double(index/314)-anchor.y) < 12 && dark(index)
    }
    guard let start = candidates.min(by: {
        hypot(Double($0%314)-anchor.x,Double($0/314)-anchor.y) < hypot(Double($1%314)-anchor.x,Double($1/314)-anchor.y)
    }) else { return [] }
    var visited: Set<Int> = [start], queue = [start], cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]; cursor += 1
        for next in [index-1,index+1,index-314,index+314] where next >= 0 && next < 314*314 && abs(next%314-index%314) <= 1 {
            if !visited.contains(next) && dark(next) { visited.insert(next); queue.append(next) }
        }
    }
    var mask = Set<Int>()
    for y in 0..<314 {
        let row = visited.filter { $0/314 == y }.map { $0%314 }
        if let lo = row.min(), let hi = row.max() { for x in lo...hi { mask.insert(y*314+x) } }
    }
    return mask
}
func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data: Data(bytes)).map { String(format:"%02x",$0) }.joined() }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let frames = root.appendingPathComponent("Shared/Mascot/Frames")
let baseline = try JSONDecoder().decode([String:String].self, from: Data(contentsOf: root.appendingPathComponent("Tests/manual/skins/colorway-baseline.json")))
let catalog = WardrobeCatalog.items.filter { $0.slot == .skin }
require(catalog.count == 6 && Set(catalog.map(\.id)) == Set(WardrobeSkins.all.keys), "catalog and bundled manifest match six skins")
require(WardrobeCategory.allCases.first == .skins && WardrobeCategory.skins.items.count == 6, "skins category first")
require(WardrobeCategory.skins.symbol == "shield.lefthalf.filled", "skins category symbol")
require(WardrobeArt.anchors.count == 66 && WardrobeSkins.shoulders.count == 66, "63 frame and three fixed pose anchor maps")
var sourceImages = [String: CGImage](), originalImages = [String: CGImage]()
for frame in WardrobeArt.anchors.keys.sorted() {
    let image = load(frame.hasPrefix("pose")
        ? root.appendingPathComponent("Clockin/Assets.xcassets/\(frame).imageset/\(frame).png")
        : frames.appendingPathComponent(frame+".png"))
    originalImages[frame] = image
    sourceImages[frame] = WardrobeArt.composite(robot:image,parts:[],size:314)!
    for (id,way) in WardrobeArt.colorways {
        var b = bytes(image); WardrobePalette.recolor(&b,colorway:way)
        require(digest(b) == baseline[id+"/"+frame], "legacy colorway changed: \(id)/\(frame)")
    }
}
require(baseline.count == 396, "396 independent pre-change digests")
print("ok: 396 legacy colorway/frame SHA256 matches, including all fixed poses")

let ramp = WardrobeColorway(name:"ramp",identity:false,rules:[.init(kind:"shell",hue:[0,360],saturation:[0,1],luminance:[80,240],stops:["#000000","#404040","#808080","#C0C0C0","#FFFFFF"])])
var rampPixels: [UInt8] = [80,80,80,255,120,120,120,255,160,160,160,255,200,200,200,255,240,240,240,255]
WardrobePalette.recolor(&rampPixels,colorway:ramp)
require(stride(from:0,to:20,by:4).map{rampPixels[$0]} == [0,64,128,192,255], "five-stop interpolation visits every stop")
var shortPixels: [UInt8] = [255,255,255,255,8,9]
WardrobePalette.recolor(&shortPixels,colorway:ramp)
require(shortPixels == [255,255,255,255,8,9], "trailing partial pixels ignored")
let missing = WardrobeState.decode("{\"equipped\":{\"head\":\"cap\"},\"colorway\":\"mint\"}")
require(missing.look == "mint" && WardrobeSkins.skin(for: missing) == nil, "old JSON retains colorway and has no skin")
require(WardrobeState.decode("{}").look == "classic", "old minimal JSON default")
var outfit = missing
outfit.equipped = ["head":"cap","face":"round-glasses","neck":"scarf","back":"wings","hand":"mug"]
let previous = outfit.equipped
// Selecting any garment or colorway must reveal that selection immediately.
for selection in WardrobeCatalog.items where WardrobeSlot.outfit.contains(selection.slot) && selection.slot != .skin {
    var worn = outfit
    worn.equipped["skin"] = "skin-paladin"
    let saved = worn
    let preview = worn.previewing(selection)
    require(preview.equipped["skin"] == nil, "preview removes skin for \(selection.id)")
    require(worn == saved, "preview leaves saved outfit intact")
    worn.equip(selection)
    require(worn == saved, "unowned selection cannot remove skin")
    worn.owned.insert(selection.id)
    worn.equip(selection)
    require(worn.equipped["skin"] == nil, "equip removes skin for \(selection.id)")
    require(selection.slot == .colorway ? worn.colorway == selection.id : worn.equipped[selection.slot.rawValue] == selection.id,
            "selected garment or colorway is visible")
    for (slot, id) in previous where slot != selection.slot.rawValue {
        require(worn.equipped[slot] == id, "other garments return after selecting \(selection.id)")
    }
}
for selection in WardrobeCatalog.items where selection.isHomeItem {
    var worn = outfit; worn.equipped["skin"] = "skin-paladin"; worn.owned.insert(selection.id)
    worn.equip(selection)
    require(worn.equipped["skin"] == "skin-paladin", "home selection keeps skin")
}
print("ok: garment/colorway equip and preview remove skin, restore garments; unowned/home selections preserve skin")
var ledger = [WardrobePurchase]()
var pieceImages = [String: CGImage]()
let clear = CGContext(data:nil,width:314,height:314,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
var placementCount = 0, eyeCount = 0, absentCount = 0, omittedHelms = 0, fistPixels = 0
for item in catalog {
    let skin = WardrobeSkins.all[item.id]!
    require(skin.id == item.id && skin.name == item.name, "manifest identity")
    require(WardrobeArt.available(item), "skin available: \(item.id)")
    require(skin.material.rules.count == 6 && skin.material.rules.allSatisfy { (3...5).contains($0.stops?.count ?? 0) }, "six multi-stop metal classes")
    let original = originalImages["h01"]!
    var expectedMaterial = bytes(original)
    WardrobePalette.recolor(&expectedMaterial, colorway: skin.material)
    require(expectedMaterial != bytes(original), "skin material changes the shell and energy")
    require(bytes(WardrobeArt.recolor(original,colorway:skin.id)) == expectedMaterial, "skin id selects its material rules")
    require(["embers","stars","sparks","motes","feathers"].contains(skin.effects.aura), "aura kind")
    require((2...3).contains(skin.effects.auraColors.count), "aura color count")
    require(([skin.effects.sheen,skin.effects.glow]+skin.effects.auraColors).allSatisfy { WardrobePalette.rgb($0) != nil }, "effect hex colors")
    var unowned = outfit; unowned.equip(item)
    require(unowned.equipped["skin"] == nil, "unowned skin cannot equip")
    require(!outfit.buy(item,earned:0,ledger:&ledger,now:.distantPast), "insufficient coins")
    require(outfit.buy(item,earned:100_000,ledger:&ledger,now:.distantPast), "buy and equip skin")
    require(!outfit.buy(item,earned:100_000,ledger:&ledger,now:.distantPast), "skin bought only once")
    require(outfit.look == item.id && WardrobeSkins.skin(for:outfit)?.id == item.id, "look resolves skin")
    require(WardrobeState.decode(outfit.json) == outfit, "skin state JSON roundtrip")
    require(previous.allSatisfy { outfit.equipped[$0.key] == $0.value }, "underlying outfit retained")
    require(WardrobeArt.hidesAntenna(outfit) == skin.hidesAntenna, "skin antenna policy")
    for piece in skin.pieces {
        guard let image = WardrobeArt.decode(piece.id+".png",folder:"Skins") else { fatalError("Missing piece \(piece.id)") }
        pieceImages[piece.id] = image
        let b = bytes(image), w = image.width, h = image.height
        require(w%2 == 0 && h%2 == 0, "even sprite dimensions")
        require((0..<Double(w)).contains(piece.pivot.x) && (0..<Double(h)).contains(piece.pivot.y), "pivot inside sprite")
        require(["front","back"].contains(piece.layer), "piece layer")
        require(["head","neck","back","shoulderL","shoulderR"].contains(piece.anchorPoint), "piece anchor")
        require(piece.motion == nil || ["flap","sway"].contains(piece.motion!), "motion kind")
        if piece.id.hasSuffix("wings") { require(piece.motion == "flap", "wings flap") }
        if piece.id.hasSuffix("cape") { require(piece.motion == "sway", "capes sway") }
        var colors = Set<UInt32>()
        for y in stride(from:0,to:h,by:2) { for x in stride(from:0,to:w,by:2) {
            let i = (y*w+x)*4
            require(b[i+3] == 0 || b[i+3] == 255, "no antialiasing in sprite")
            for (dx,dy) in [(1,0),(0,1),(1,1)] {
                let j = ((y+dy)*w+x+dx)*4
                require(b[i..<(i+4)] == b[j..<(j+4)], "2x2 art grid: \(piece.id)")
            }
            if b[i+3] > 0 { colors.insert(UInt32(b[i])<<16 | UInt32(b[i+1])<<8 | UInt32(b[i+2])) }
        } }
        require(colors.count >= 5, "shaded material: \(piece.id)")
    }
    for frame in WardrobeArt.anchors.keys.sorted() {
        let anchor = WardrobeArt.anchors[frame]!, source = sourceImages[frame]!, raw = bytes(source)
        let parts = WardrobeArt.overlays(frame:frame,outfit:outfit,images:pieceImages)
        require(!parts.isEmpty && parts.allSatisfy { $0.id.hasPrefix(item.id+"-") }, "skin hides garment overlays")
        for piece in skin.pieces {
            guard let part = parts.first(where: { $0.id == piece.id }) else {
                if frame == "pose2" && piece.id.hasSuffix("-helm") {
                    require(piece.omittedFrames == ["pose2"], "raised fists omit head adornment")
                    omittedHelms += 1; continue
                }
                require(piece.anchorPoint.hasPrefix("shoulder") && WardrobeSkins.shoulders[frame]?[piece.anchorPoint] == nil, "only unavailable shoulders omitted")
                absentCount += 1; continue
            }
            let a = part.tilt * .pi / 180
            for (x,y) in [(0.0,0.0),(Double(part.image.width),0),(0,Double(part.image.height)),(Double(part.image.width),Double(part.image.height))] {
                let px = part.origin.x + x*cos(a)-y*sin(a), py = part.origin.y + x*sin(a)+y*cos(a)
                require((0...314).contains(px) && (0...314).contains(py), "clipped \(piece.id)/\(frame): \(px),\(py)")
            }
            placementCount += 1
        }
        let face = visorMask(raw, anchor.visor)
        require(!face.isEmpty, "detected visor interior")
        let helm = bytes(WardrobeArt.composite(robot:clear,parts:parts.filter { $0.id.hasSuffix("-helm") },size:314)!)
        let coveredFace = face.filter { helm[$0*4+3] > 0 }.sorted()
        require(coveredFace.isEmpty, "helm covers visor \(item.id)/\(frame): \(coveredFace.prefix(8).map { [ $0%314, $0/314 ] })")
        let front = bytes(WardrobeArt.composite(robot:clear,parts:parts.filter{ !$0.behind },size:314)!)
        let recolored = bytes(WardrobeArt.recolor(source,colorway:skin.id))
        if frame == "pose2" {
            let rendered = bytes(WardrobeArt.composite(robot:WardrobeArt.recolor(source,colorway:skin.id),parts:parts,size:314)!)
            var count = 0
            // Native pose2 knuckles, above the forehead and antenna cutout.
            for y in 32..<59 { for x in 110..<177 {
                let i = (y*314+x)*4
                if raw[i+3] == 255 {
                    require(front[i+3] == 0, "pose2 front armour covers fist: \(item.id)")
                    require(rendered[i..<(i+4)] == recolored[i..<(i+4)], "pose2 fist pixels stay in front")
                    count += 1
                }
            } }
            require(count > 100, "pose2 fist mask is nonempty")
            fistPixels += count
        }
        for y in 0..<314 { for x in 0..<314 {
            let i = (y*314+x)*4
            if raw[i+3] == 255 && max(raw[i],raw[i+1],raw[i+2]) < 80 {
                require(raw[i..<(i+4)] == recolored[i..<(i+4)], "visor/dark ink changed \(item.id)/\(frame)")
            }
            let eye = raw[i+3] > 100 && raw[i+1] > 80 && raw[i+2] > 90
                && Int(raw[i+1])-Int(raw[i]) > 30 && Int(raw[i+2])-Int(raw[i]) > 30
                && face.contains(y*314+x)
            if eye {
                require(front[i+3] == 0, "front piece covers eye \(item.id)/\(frame) at \(x),\(y)")
                eyeCount += 1
            }
        } }
    }
    outfit.equipped["skin"] = nil
    require(outfit.look == "mint" && outfit.equipped == previous, "taking skin off restores complete outfit")
}
require(ledger.map(\.cost) == [3000,3500,4000,5000,6000,10000], "exact skin prices")
print("ok: 6 purchasable skins, \(pieceImages.count) shaded 2x2 sprites and effect/motion metadata")
print("ok: \(placementCount) unclipped placements over 66 poses; \(absentCount) deliberately omitted shoulders")
print("ok: \(eyeCount) uncovered expression pixels; all dark visor pixels unchanged")
require(omittedHelms == 6, "all six pose2 helms omitted")
print("ok: \(fistPixels) pose2 fist pixels preserved in front; \(omittedHelms) head adornments omitted")
print("ok: look, skin lookup, buy/equip/remove, preserved garments and old state JSON")

let capImage = WardrobeArt.decode("cap.png",folder:"Wardrobe")!
require(WardrobeArt.overlays(frame:"h01",outfit:outfit,images:["cap":capImage]).map(\.id) == ["cap"], "garment overlays restored")
require(WardrobeArt.hidesAntenna(outfit), "headwear hides antenna without skin")
outfit.equipped.removeValue(forKey:"head")
require(!WardrobeArt.hidesAntenna(outfit), "bare companion antenna returns")
outfit.equipped["skin"] = "unknown"
require(outfit.look == "mint" && WardrobeSkins.skin(for:outfit) == nil, "unknown skin falls back")
let originals = originalImages
let cache = WardrobeFrameCache(decode: { id,_ in originals[id] })
var cachedOutfit = WardrobeState(); cachedOutfit.colorway = "mint"
let bare = await cache.composite(frame:"h01",outfit:cachedOutfit,size:80)!
for item in catalog {
    cachedOutfit.owned.insert(item.id); cachedOutfit.equip(item)
    let robot = await cache.image("h01",outfit:cachedOutfit)!
    let expected = WardrobeArt.recolor(WardrobeArt.removingAntenna(originals["h01"]!,frame:"h01"),colorway:item.id)
    require(bytes(robot) == bytes(expected), "cache uses skin material")
    let still = await cache.composite(frame:"h01",outfit:cachedOutfit,size:80)!
    require(still.width == 80 && bytes(still) != bytes(bare), "skin still at 80px")
    let expectedStill = WardrobeArt.composite(robot:robot,parts:WardrobeArt.overlays(frame:"h01",outfit:cachedOutfit,images:pieceImages),size:80)!
    require(bytes(still) == bytes(expectedStill), "composite decodes all skin pieces")
    let again = await cache.composite(frame:"h01",outfit:cachedOutfit,size:80)!
    require(still === again, "still cached")
    let fixed = await cache.composite(frame:"pose3",outfit:cachedOutfit,size:314)
    require(fixed != nil, "fixed pose cache")
    let typing = await cache.image("t01",outfit:cachedOutfit)!
    require(bytes(typing)[(286*314+133)*4+3] > 0, "typing keeps seated boots")
}
cachedOutfit.equipped["skin"] = nil
let restored = await cache.composite(frame:"h01",outfit:cachedOutfit,size:80)!
require(bytes(restored) == bytes(bare), "cached unskinned look restored")
print("ok: production bundle lookup, skin recolor/frame/still cache, seated boots and fixed poses")
print("All skin checks passed")
