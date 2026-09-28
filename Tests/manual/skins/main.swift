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
func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data: Data(bytes)).map { String(format:"%02x",$0) }.joined() }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let frames = root.appendingPathComponent("Shared/Mascot/Frames")
let baseline = try JSONDecoder().decode([String:String].self, from: Data(contentsOf: root.appendingPathComponent("Tests/manual/skins/colorway-baseline.json")))
let effectBaseline = try JSONDecoder().decode([String: WardrobeSkinEffects].self, from: Data(contentsOf: root.appendingPathComponent("Tests/manual/skins/effects-baseline.json")))
for (id, effects) in effectBaseline { require(WardrobeSkins.all[id]?.effects == effects, "original skin effects unchanged: \(id)") }
let allSkins = WardrobeCatalog.items.filter { $0.slot == .skin }
let catalog = allSkins.filter { WardrobeSkins.all[$0.id]?.design != "paladin" }
let hdCatalog = allSkins.filter { WardrobeSkins.all[$0.id]?.hd != nil }
require(allSkins.count == 14 && catalog.count == 5 && hdCatalog.count == 14 && Set(allSkins.map(\.id)) == Set(WardrobeSkins.all.keys), "catalog and bundled manifest match fourteen skins")
require(WardrobeCategory.allCases.first == .skins && WardrobeCategory.skins.items.count == 14, "skins category first")
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

let missing = WardrobeState.decode("{\"equipped\":{\"head\":\"cap\"},\"colorway\":\"mint\"}")
require(missing.look == "mint" && WardrobeSkins.skin(for: missing) == nil, "old JSON retains colorway and has no skin")
require(WardrobeState.decode("{}").look == "classic", "old minimal JSON default")
var outfit = missing
outfit.equipped = ["head":"cap","face":"round-glasses","neck":"scarf","back":"wings","hand":"mug"]
let previous = outfit.equipped
// Selecting any garment or colorway must reveal that selection immediately.
for selection in WardrobeCatalog.items where WardrobeSlot.outfit.contains(selection.slot) && selection.slot != .skin {
    var worn = outfit
    worn.equipped["skin"] = "skin-paladin-solar"
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
    var worn = outfit; worn.equipped["skin"] = "skin-paladin-solar"; worn.owned.insert(selection.id)
    worn.equip(selection)
    require(worn.equipped["skin"] == "skin-paladin-solar", "home selection keeps skin")
}
print("ok: garment/colorway equip and preview remove skin, restore garments; unowned/home selections preserve skin")
let capImage = WardrobeArt.decode("cap.png", folder: "Wardrobe")!
let originals = originalImages
let oldNova = WardrobeState.decode("{\"owned\":[\"skin-nova\"],\"equipped\":{\"skin\":\"skin-nova\",\"head\":\"cap\"},\"colorway\":\"mint\"}")
require(oldNova.owned.contains("skin-nova") && oldNova.look == "skin-nova" && WardrobeSkins.isHD(oldNova), "pre-HD Nova remains owned and worn")
require(WardrobeState.decode(oldNova.json) == oldNova, "legacy Nova state round trip")
var removed = oldNova; removed.equipped["skin"] = nil
require(removed.look == "mint" && removed.equipped["head"] == "cap", "removal restores saved outfit")
require(WardrobeArt.overlays(frame: "h01", outfit: removed, images: ["cap": capImage]).map(\.id) == ["cap"], "garments restored")
removed.equipped["skin"] = "unknown"
require(removed.look == "mint" && !WardrobeSkins.isHD(removed), "unknown skin falls back")
print("ok: pre-HD owned/worn Nova JSON, round trip, remove restores garments and colorway, unknown id fallback")

let ranks = ["Spark", "Orbit", "Nebula", "Solar", "Nova", "Aurora", "Sovereign", "Celestial", "Eternal"]
let expectedIDs = ranks.map { "skin-paladin-" + $0.lowercased() }
require(Array(hdCatalog.prefix(9)).map(\.id) == expectedIDs && Array(WardrobeCategory.skins.items.prefix(9)).map(\.id) == expectedIDs,
        "nine HD skins first, in rank order")
let prices = [2000,2500,3000,4000,5000,6000,7500,9000,12000,3500,4000,5000,6000,10000]
require(Array(hdCatalog.suffix(5)).map(\.id) == ArmorHDStyle.otherKeys.map { "skin-" + $0 }, "five design IDs and order unchanged")
let strings = (try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Shared/Localizable.xcstrings"))) as! [String:Any])["strings"] as! [String:[String:Any]]
@MainActor func localized(_ key: String, _ language: String) -> String? {
    let localizations = strings[key]?["localizations"] as? [String:[String:Any]]
    return (localizations?[language]?["stringUnit"] as? [String:String])?["value"]
}
require(WardrobeSkins.all["skin-paladin"] == nil && !allSkins.contains { $0.id == "skin-paladin" }, "pixel paladin removed")
let skinFiles = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Shared/Mascot/Skins").path)
require(!skinFiles.contains { $0.hasSuffix(".png") }, "no pixel skin PNGs")
let retired = WardrobeState.decode("{\"equipped\":{\"skin\":\"skin-paladin\",\"head\":\"cap\"},\"colorway\":\"mint\"}")
require(retired.look == "mint" && !WardrobeSkins.isHD(retired), "removed id falls back safely in old JSON")
require(!WardrobeSkins.isHD(missing), "old state is not HD")
require(ArmorHDCache.application.directory.path.contains("/Caches/") && ArmorHDCache.application.directory.lastPathComponent == "ArmorHD", "application Caches subdirectory")
let hdDirectory = root.appendingPathComponent("build/skin-checks/hd-cache-" + UUID().uuidString)
let disk = ArmorHDCache(directory: hdDirectory)
defer { try? FileManager.default.removeItem(at: hdDirectory) }
var hdLedger = [WardrobePurchase]()
var hdCount = 0
// Bundle-only run: a repository fallback cannot accidentally satisfy fixed poses.
require(FileManager.default.changeCurrentDirectoryPath(FileManager.default.temporaryDirectory.path), "leave repository for production HD matrix")
defer { _ = FileManager.default.changeCurrentDirectoryPath(root.path) }
let started = CFAbsoluteTimeGetCurrent()
for (index,item) in hdCatalog.enumerated() {
    let skin = WardrobeSkins.all[item.id]!
    require(skin.id == item.id && skin.name == item.name, "HD identity")
    if index < 9 {
        require(skin.name == ranks[index] + " Paladin", "rank name")
        require(localized(skin.name,"en") == skin.name && localized(skin.name,"tr") == localized(ranks[index],"tr")! + " Paladini", "rank localization")
        require(skin.hd == ranks[index].lowercased() && skin.design == "paladin", "rank material and paladin design")
    } else {
        require(skin.design == ArmorHDStyle.otherKeys[index - 9] && skin.hd == skin.design, "independent design and material keys")
        require(localized(skin.name, "tr") != nil, "existing Turkish skin name")
    }
    require(skin.hdStyle != nil && WardrobeArt.available(item), "complete HD skin without pieces")
    require(([skin.effects.sheen,skin.effects.glow]+skin.effects.auraColors).allSatisfy { WardrobePalette.rgb($0) != nil }, "HD effect colours")
    require(skin.effects.aura == ["sparks","motes","motes","embers","sparks","motes","embers","stars","feathers","sparks","motes","stars","embers","feathers"][index], "preserved aura")
    var worn = missing
    require(worn.buy(item,earned:100_000,ledger:&hdLedger,now:.distantPast), "buy HD skin")
    require(hdLedger.last?.cost == prices[index], "rank price")
    require(worn.look == item.id && WardrobeSkins.isHD(worn), "HD look and filtering flag")
    require(WardrobeState.decode(worn.json) == worn, "HD state roundtrip")
    require(!WardrobeArt.hidesAntenna(worn) && skin.hidesAntenna == ArmorHD.hidesAntenna, "HD retains source antenna")
    let pipeline = WardrobeFrameCache(hdCache:disk, decode: { id,fixed in
        // Fixed poses have no raw resource in this bundle. The caller supplies the decoded CGImage.
        guard fixed == id.hasPrefix("pose") else { return nil }
        return originals[id]
    })
    for frame in originals.keys.sorted() {
        let fixed = frame.hasPrefix("pose")
        guard let image = await pipeline.image(frame,outfit:worn,fixedPose:fixed) else { fatalError("HD cache miss: \(item.id)/\(frame)") }
        require(image.width == 480 && image.height == 480, "480 px HD frames")
        let byID = await pipeline.image(frame,colorway:item.id,fixedPose:fixed,hidingAntenna:true)
        require(image === byID, "outfit and id overloads reuse the same HD render")
        require(WardrobeArt.overlays(frame:frame,outfit:worn,images:["cap":capImage]).isEmpty, "HD suppresses garments")
        let composite = await pipeline.composite(frame:frame,outfit:worn,size:480)
        require(composite === image, "HD composite uses complete cached render")
        let key = ArmorHDCache.Key(version:ArmorHD.rendererVersion,frame:frame,style:skin.hdStyle!.cacheIdentity,size:480)
        let png = try disk.read(key)
        require(png != nil, "every HD frame persisted through ArmorHDCache")
        hdCount += 1
    }
    // A fresh pipeline must decode the persisted result without rewriting it.
    let fresh = WardrobeFrameCache(hdCache:disk,decode: { id,_ in originals[id] })
    for frame in originals.keys.sorted() {
        let key = ArmorHDCache.Key(version:ArmorHD.rendererVersion,frame:frame,style:skin.hdStyle!.cacheIdentity,size:480)
        let url = try disk.url(for:key)
        let before = try Data(contentsOf:url)
        let date = try url.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate
        let image = await fresh.image(frame,colorway:item.id,fixedPose:frame.hasPrefix("pose"))
        require(image?.width == 480, "fresh pipeline disk hit")
        let afterDate = try url.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate
        let after = try Data(contentsOf:url)
        require(date == afterDate && before == after, "disk hit has no rewrite")
    }
    let small = await pipeline.composite(frame:"h01",outfit:worn,size:80)!
    let full = await pipeline.image("h01",outfit:worn)!
    let c = ArmorHD.context(80)!; c.interpolationQuality = .high
    c.draw(full,in:CGRect(x:0,y:0,width:80,height:80))
    require(bytes(small) == bytes(c.makeImage()!), "80 px still linearly filters HD without garments")
    worn.equipped["head"] = "crown"
    let same = await pipeline.composite(frame:"h01",outfit:worn,size:80)
    require(same === small, "hidden garment changes do not split HD still cache")
}
print("ok: 14 HD catalog/manifest/localization entries, prices/order, effects, retired paladin and legacy JSON")
print("ok: \(hdCount) HD frame/style cache misses and disk hits at 480 px, including 42 fixed poses; look, overlays, antenna and linear stills")
print(String(format:"timing: HD pipeline matrix including validation %.2f s",CFAbsoluteTimeGetCurrent()-started))
let concurrentCache = WardrobeFrameCache(hdCache:disk,decode: { id,_ in originals[id] })
let concurrentFrames = await withTaskGroup(of: CGImage?.self, returning: [CGImage].self) { group in
    for _ in 0..<12 {
        group.addTask { await concurrentCache.image("h01",colorway:"skin-paladin-eternal") }
    }
    var results = [CGImage]()
    for await result in group { if let result { results.append(result) } }
    return results
}
require(concurrentFrames.count == 12 && concurrentFrames.allSatisfy { $0 === concurrentFrames[0] }, "concurrent HD requests share one image")
print("ok: concurrent HD requests share one cached image; bundle-only fixed-pose handoff")
print("All skin checks passed")
