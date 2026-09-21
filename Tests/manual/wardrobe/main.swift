import Foundation
import CoreGraphics
import ImageIO

var checks = 0
@MainActor func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fatalError("FAIL: \(message)") }
    checks += 1
    print("ok \(message)")
}
func fixture<T: Decodable>(_ file: String, _ type: T.Type) -> T {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("fixtures/" + file)
    return try! JSONDecoder().decode(type, from: Data(contentsOf: url))
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let start = Date(timeIntervalSince1970: 1_700_006_400)
@MainActor func session(_ day: Int, _ duration: Double) -> WorkSession {
    let date = calendar.date(byAdding: .day, value: day, to: start)!
    return WorkSession(id: UUID(), start: date, end: date.addingTimeInterval(duration), duration: duration,
                       note: "Synthetic", hourlyRate: 0, source: "Clockin")
}
let archive = [session(0, 8 * 3600 + 59), session(1, 8 * 3600), session(2, 8 * 3600)]
let earning = WardrobeEarnings(sessions: archive, dailyGoal: 8, now: start.addingTimeInterval(3 * 86400), calendar: calendar)
check(earning.goalDays == 3, "three completed goal days")
check(earning.progress.level == 6, "archive level from hours and streak XP")
check(earning.progress.streak == 3, "archive streak")
check(earning.progress.badges == Set(["first", "ten", "streak", "marathon", "ultra", "fullday"]), "archive badges")
check(earning.coins == 240 + 75 + 300 + 600, "hours plus goals plus badges plus all reached levels")
check(WardrobeEarnings(sessions: archive, dailyGoal: 8, now: start.addingTimeInterval(100 * 86400), calendar: calendar).coins == earning.coins, "streak coins survive calendar drift")
check(WardrobeEarnings(sessions: [], dailyGoal: 0, now: start, calendar: calendar).coins == 100, "level one earns 100")
check(WardrobeCoins.earned(durations: [359, 359], goalDays: 0, badges: 0, level: 0) == 1, "floor each session to minutes then combine")
check(WardrobeCoins.earned(durations: [59, 59, 59, 59, 59, 59], goalDays: 0, badges: 0, level: 0) == 0, "seconds never pool into minutes")
check(WardrobeCoins.earned(durations: [.nan, .infinity, -60], goalDays: -1, badges: -1, level: -1) == 0, "invalid coin inputs are safe")
check(Set(WardrobeCatalog.items.map(\.id)).count == WardrobeCatalog.items.count, "unique catalog ids")
let categorizedItems = WardrobeCategory.allCases.flatMap(\.items)
check(categorizedItems.count == WardrobeCatalog.items.count, "catalog categories do not duplicate items")
check(Set(categorizedItems.map(\.id)) == Set(WardrobeCatalog.items.map(\.id)), "every catalog item is discoverable in a category")
check(WardrobeCategory.allCases.allSatisfy { !$0.items.isEmpty }, "category picker has no empty destinations")
check(WardrobeCatalog.items.allSatisfy { $0.category.isHome == $0.isHomeItem }, "category preview chooses the correct outfit or home scene")

let allBadges = Set(InsightsSnapshot(sessions: [], sessionEarnings: [:], now: start, calendar: calendar).badges.map(\.id))
for item in WardrobeCatalog.items {
    switch item.unlock {
    case .free: check(true, "\(item.id) free rule")
    case .coins(let n): check((50...1500).contains(n), "\(item.id) valid price")
    case .hours(let n), .level(let n), .streak(let n): check(n > 0, "\(item.id) valid milestone")
    case .badge(let id): check(allBadges.contains(id), "\(item.id) valid badge")
    }
}
var state = WardrobeState()
check(state.unlock(.init(hours: 100), legacy: "cape").isEmpty, "seed silently")
check(state.seeded && state.owned.isSuperset(of: ["classic", "cozy", "cap", "round-glasses", "headphones", "mug", "cape"]), "seed owns earned items")
check(state.equipped["back"] == "cape", "legacy cape migrated")
check(!state.owned.contains("mint"), "coins do not auto unlock purchases")
check(state.unlock(.init()).isEmpty && state.owned.contains("cape"), "milestone ownership remains after archive shrinks")
check(state.unlock(.init(hours: 250)) == ["antenna"], "new milestone only reported once")
check(state.unlock(.init(hours: 250)).isEmpty, "no repeat unlock")
for (id, slot, hours) in [("headphones", "head", 25.0), ("mug", "hand", 50.0), ("cape", "back", 100.0), ("antenna", "head", 250.0)] {
    var migrated = WardrobeState()
    _ = migrated.unlock(.init(hours: hours), legacy: id)
    check(migrated.equipped[slot] == id, "legacy \(id) migration")
}
for legacy in ["None", "unknown"] {
    var migrated = WardrobeState(); _ = migrated.unlock(.init(hours: 250), legacy: legacy)
    check(migrated.equipped.isEmpty, "\(legacy) no equipped item")
}
var auto = WardrobeState(); _ = auto.unlock(.init(hours: 100), legacy: "Auto")
check(auto.equipped["back"] == "cape", "Auto migrates highest earned accessory")
var historical = WardrobeState()
_ = historical.unlock(.init(), legacy: "cape", legacyOwned: ["headphones", "mug", "invalid"])
check(historical.equipped["back"] == "cape", "stored selection remains owned after archive reduction")
check(historical.owned.isSuperset(of: ["headphones", "mug", "cape"]) && !historical.owned.contains("invalid"), "legacy seen ownership migrates known ids only")
var ledger: [WardrobePurchase] = []
let scarf = WardrobeCatalog.item("scarf")!
check(!state.buy(scarf, earned: 49, ledger: &ledger, now: start), "insufficient balance cannot buy")
check(state.buy(scarf, earned: 100, ledger: &ledger, now: start), "purchase succeeds")
check(ledger == [.init(itemID: "scarf", cost: 50, date: start)], "ledger records cost id and date")
check(state.equipped["neck"] == "scarf" && state.owned.contains("scarf"), "purchase equips and owns")
check(WardrobeCoins.balance(earned: 100, ledger: ledger) == 50, "purchase deducted")
check(!state.buy(scarf, earned: 100, ledger: &ledger, now: start), "duplicate purchase refused")
check(!state.buy(WardrobeCatalog.item("crown")!, earned: 10000, ledger: &ledger, now: start), "milestone cannot be purchased")
check(WardrobeCoins.balance(earned: 0, ledger: ledger) == 0, "deleted archive never negative")
check(WardrobeCoins.balance(earned: 100, ledger: [.init(itemID: "bad", cost: -50, date: start)]) == 100, "negative ledger does not mint coins")
let anchors = fixture("mascot-anchors.json", [String: WardrobeAnchors].self)
let sprites = fixture("wardrobe-sprites.json", [String: WardrobeSprite].self)
check(WardrobeGeometry.placement(sprite: sprites["cap"]!, frame: anchors["h01"]!) == WardrobePoint(147, 52), "pivot lands on upright anchor")
let tilted = WardrobeGeometry.placement(sprite: sprites["cap"]!, frame: anchors["t01"]!)!
check(abs(tilted.x - 168) < 0.0001 && abs(tilted.y - 52) < 0.0001, "pivot rotates about anchor at 90 degrees")
check(WardrobeGeometry.placement(sprite: sprites["mug"]!, frame: anchors["t01"]!) == nil, "hand hidden without handR")
check(WardrobeGeometry.placement(sprite: sprites["mug"]!, frame: anchors["h01"]!) == WardrobePoint(208, 166), "handR placement")
check(sprites["cape"]!.layer == "back", "cape renders behind")
let colors = fixture("colorways.json", [String: WardrobeColorway].self)
var pixels: [UInt8] = [255,255,255,255, 255,136,0,255, 1,2,3,255, 255,255,255,0]
let original = pixels
WardrobePalette.recolor(&pixels, colorway: colors["classic"]!)
check(pixels == original, "classic identity")
WardrobePalette.recolor(&pixels, colorway: colors["mint"]!)
check(pixels == [231,255,240,255, 230,159,99,255, 1,2,3,255, 255,255,255,0], "tiny RGBA test image classifies shades and preserves transparency")
let artRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Shared/Mascot")
func real<T: Decodable>(_ path: String, _ type: T.Type) -> T {
    try! JSONDecoder().decode(type, from: Data(contentsOf: artRoot.appendingPathComponent(path)))
}
let realColors = real("Frames/colorways.json", [String: WardrobeColorway].self)
let realAnchors = real("Frames/mascot-anchors.json", [String: WardrobeAnchors].self)
let realSprites = real("Wardrobe/wardrobe-sprites.json", [String: WardrobeSprite].self)
let realHome = real("Home/home-items.json", WardrobeHome.self)
check((try! Data(contentsOf: artRoot.appendingPathComponent("Frames/colorways.json"))).count < 20_000, "real colorway file under 20 KB")
for (id, way) in realColors {
    check(Set(way.rules.map(\.kind)) == Set(["shell", "highlights", "grays", "joints", "accents", "glow"]), "\(id) has all six classes")
    var sample: [UInt8] = [175,175,175,255, 232,232,232,255, 79,70,65,255, 255,119,26,128]
    let before = sample
    WardrobePalette.recolor(&sample, colorway: way)
    check(Array(sample[8..<12]) == Array(before[8..<12]), "\(id) visor untouched")
    check(sample[15] == 128, "\(id) partial alpha preserved")
    if id == "classic" { check(sample == before, "real classic identity") }
    else { check(sample[0..<3] != sample[4..<7], "\(id) shadow and shell shading stay distinct") }
}
for item in WardrobeCatalog.items {
    let file: String
    switch item.slot {
    case .colorway:
        check(realColors[item.id] != nil, "catalog colorway \(item.id)")
        continue
    case .room:
        check(realHome.rooms[item.id] != nil, "catalog room \(item.id)")
        file = "Home/" + realHome.rooms[item.id]!.file
    default:
        if WardrobeSlot.furniture.contains(item.slot) {
            check(realHome.items[item.id]?.slot == item.slot.rawValue, "catalog furniture id and slot \(item.id)")
            file = "Home/" + realHome.items[item.id]!.file
        } else {
            check(realSprites[item.id]?.slot == item.slot.rawValue, "catalog sprite id and slot \(item.id)")
            file = "Wardrobe/" + item.id + ".png"
        }
    }
    check(FileManager.default.fileExists(atPath: artRoot.appendingPathComponent(file).path), "catalog asset \(file)")
}
let home = fixture("home-items.json", WardrobeHome.self)
let plant = home.items["plant"]!, room = home.rooms["cozy"]!
check(WardrobeGeometry.origin(pivot: plant.pivot, anchor: room.slots[plant.slot]!, degrees: 0) == WardrobePoint(32, 200), "furniture pivot on room slot")
check(room.mascotSpot == WardrobePoint(180, 220), "feet spot decoded")
check(room.slots["desk"] == nil, "missing room slot omitted")
let suite = "Clockin.WardrobeTests.\(UUID())"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
defaults.set(state.json, forKey: WardrobeState.stateKey)
defaults.set(String(data: try! JSONEncoder().encode(ledger), encoding: .utf8), forKey: WardrobeState.ledgerKey)
defaults.set(false, forKey: WardrobeState.deskKey)
let extra = WardrobeBackupSection(defaults: defaults)
var data = ClockinData(); data.sessions = archive
let backup = try! extra.adding(to: JSONEncoder().encode(data))
check((try! JSONDecoder().decode(ClockinData.self, from: backup)).sessions == archive, "wardrobe does not change ClockinData")
let restored = try! WardrobeBackupSection.read(from: backup)!
check(restored == extra, "backup optional section round trip")
defaults.removePersistentDomain(forName: suite)
restored.restore(to: defaults)
check(WardrobeState.decode(defaults.string(forKey: WardrobeState.stateKey)) == state, "restore outfit ownership and seed")
check(defaults.bool(forKey: WardrobeState.deskKey) == false, "restore desk preference")
check(try! WardrobeBackupSection.read(from: JSONEncoder().encode(data)) == nil, "old backups have no wardrobe")
check(WardrobeState.decode("broken") == WardrobeState(), "malformed state degrades safely")

func testImage(_ name: String) -> CGImage {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("fixtures/" + name)
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
    rgba.withUnsafeMutableBytes { bytes in
        let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    let offset = (y * image.width + x) * 4
    return Array(rgba[offset..<(offset + 4)])
}
let tiny = testImage("tiny.png")
let mapped = WardrobeArt.recolor(tiny, colorway: colors["mint"]!)
check(pixel(mapped, 0, 0) == [231,255,240,255], "actual PNG white pixel recolored")
check(pixel(mapped, 1, 0) == [230,159,99,255], "actual PNG accent recolored")
check(pixel(mapped, 0, 1) == [0,0,255,255], "actual PNG unmapped pixel unchanged")
check(pixel(mapped, 1, 1)[3] == 0, "actual PNG transparency retained")
let red = testImage("overlay.png")
let part = WardrobeOverlay(id: "test", image: red, origin: WardrobePoint(0, 0), tilt: 0, behind: false)
let front = WardrobeArt.composite(robot: tiny, parts: [part], size: 314)!
check(pixel(front, 0, 0) == [255,0,0,255], "front layer draws over robot")
check(pixel(front, 3, 3) == [255,255,255,255], "sprite cropped bounds do not stretch")
let back = WardrobeOverlay(id: "test", image: red, origin: WardrobePoint(0, 0), tilt: 0, behind: true)
check(pixel(WardrobeArt.composite(robot: tiny, parts: [back], size: 314)!, 0, 0) == [255,255,255,255], "back layer draws behind robot")
let transparentPart = WardrobeOverlay(id: "test", image: red, origin: WardrobePoint(200, 200), tilt: 0, behind: true)
check(pixel(WardrobeArt.composite(robot: tiny, parts: [transparentPart], size: 314)!, 200, 200) == [255,0,0,255], "back layer visible through transparent robot")
let still = WardrobeArt.composite(robot: tiny, parts: [], size: 80)!
check(still.width == 80 && still.height == 80, "widget composite rendered at requested size")
check(pixel(still, 0, 0) == [255,255,255,255] && pixel(still, 79, 0) == [255,136,0,255], "widget preserves top-left orientation and nearest colors")
check(WardrobeArt.composite(robot: tiny, parts: [], size: 0) == nil, "invalid composite size safe")
check(WardrobeArt.url("../escape.png", folder: "Home") == nil, "manifest filenames cannot escape resource folder")
check(WardrobeArt.overlays(frame: "missing", outfit: state, images: [:]).isEmpty, "missing frame anchors hide overlays")
var queue = CelebrationQueue()
queue.wardrobeUnlocked(first: true, names: ["Cap", "Cape"])
check(queue.pending == [.wardrobe(name: "Outfits, coins and home", introductory: true)], "one first-run banner")
queue = CelebrationQueue()
queue.wardrobeUnlocked(first: false, names: ["A", "B", "C", "D", "E"])
check(queue.pending.count == 4, "new items limited to three plus summary")
queue.presentNext(active: true, blocked: true, companionVisible: true, now: 0)
check(queue.current == nil && queue.pending.count == 4, "wardrobe banners wait for modal dismissal")
queue.presentNext(active: true, blocked: false, companionVisible: true, now: 0)
check(queue.current == .wardrobe(name: "A", introductory: false), "wardrobe banner presented by shared queue")

func realImage(_ relative: String) -> CGImage {
    if let image = HeritageArt.render((relative as NSString).lastPathComponent,
                                      source: artRoot.appendingPathComponent(relative)) { return image }
    let source = CGImageSourceCreateWithURL(artRoot.appendingPathComponent(relative) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
@MainActor func savePNG(_ image: CGImage, _ path: String) {
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    check(CGImageDestinationFinalize(destination), "PNG proof \(path)")
}
let artImages = realSprites.keys.reduce(into: [String: CGImage]()) { $0[$1] = realImage("Wardrobe/" + $1 + ".png") }
var dressed = WardrobeState()
dressed.equipped = ["head":"headphones", "face":"round-glasses", "neck":"scarf", "back":"wings", "hand":"mug"]
dressed.colorway = "mint"
for frame in realAnchors.keys.sorted() {
    let overlays = WardrobeArt.overlays(frame: frame, outfit: dressed, images: artImages, anchorManifest: realAnchors, spriteManifest: realSprites)
    check(overlays.contains { $0.id == "mug" } == (realAnchors[frame]!.handR != nil && !frame.hasPrefix("t") && !frame.hasPrefix("c")), "real occupied hand composition \(frame)")
    for overlay in overlays {
        let expected = ["headphones", "round-glasses"].contains(overlay.id) ? realAnchors[frame]!.tilt : 0
        check(overlay.tilt == expected, "real slot rotation \(frame)/\(overlay.id)")
    }
    let antenna = realSprites["antenna"]!, antennaImage = artImages["antenna"]!
    let origin = WardrobeGeometry.placement(sprite: antenna, frame: realAnchors[frame]!)!
    let angle = realAnchors[frame]!.tilt * .pi / 180
    for (x, y) in [(0.0,0.0), (Double(antennaImage.width),0.0), (0.0,Double(antennaImage.height)), (Double(antennaImage.width),Double(antennaImage.height))] {
        let px = origin.x + x * cos(angle) - y * sin(angle)
        let py = origin.y + x * sin(angle) + y * cos(angle)
        check((0...314).contains(px) && (0...314).contains(py), "antenna stays in canvas \(frame)")
    }
    let base = realImage("Frames/" + frame + ".png")
    let completed = frame.hasPrefix("t") ? WardrobeArt.seatedWorkingFrame(base, seated: realImage("Frames/c01.png")) : base
    let robot = WardrobeArt.recolor(completed, colorway: realColors["mint"]!)
    let image = WardrobeArt.composite(robot: robot, parts: overlays, size: 314)!
    check(image.width == 314, "real composition \(frame)")
    if ["h01","t01","c07","e01"].contains(frame) { savePNG(image, "/tmp/clockin-app-composition-" + frame + ".png") }
}
let fixedAnchors = real("Frames/fixed-pose-anchors.json", [String: WardrobeAnchors].self)
check(Set(fixedAnchors.keys) == Set(["pose2", "pose3", "pose4"]), "all fixed poses have anchors")
let allArtIDs = Set(realSprites.keys).union(realColors.keys).union(realHome.rooms.keys).union(realHome.items.keys)
check(Set(WardrobeCatalog.items.map(\.id)) == allArtIDs, "every art item is accessible in the catalog")
for id in ["pose2", "pose3", "pose4"] {
    let poseURL = artRoot.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Clockin/Assets.xcassets/" + id + ".imageset/" + id + ".png")
    let poseSource = CGImageSourceCreateWithURL(poseURL as CFURL, nil)!
    let pose = CGImageSourceCreateImageAtIndex(poseSource, 0, nil)!
    let recolored = WardrobeArt.recolor(pose, colorway: realColors["mint"]!)
    check(recolored !== pose && recolored.width == pose.width, "fixed pose real image recolors \(id)")
    let overlays = WardrobeArt.overlays(frame: id, outfit: dressed, images: artImages, anchorManifest: fixedAnchors, spriteManifest: realSprites)
    check(overlays.count == (id == "pose2" ? 4 : 5), "fixed pose keeps outfit and respects occupied hands \(id)")
    let composition = WardrobeArt.composite(robot: recolored, parts: overlays, size: 314)!
    savePNG(composition, "/tmp/clockin-app-composition-" + id + ".png")
}
// Clothing and palette previews must be isolated just like room previews.
for item in WardrobeCatalog.items where !item.isHomeItem {
    let id = item.id
    let original = WardrobeState()
    let draft = original.previewing(item)
    check(draft.owned.contains(id) && !original.owned.contains(id), "\(id) preview grants draft ownership only")
    check(original == WardrobeState(), "\(id) preview leaves live outfit unchanged")
    if item.slot == .colorway { check(draft.colorway == id, "preview uses selected colorway") }
    else { check(draft.equipped[item.slot.rawValue] == id, "\(id) preview equips selected clothing") }
}

// Room previews are value copies: trying a locked item must never grant it.
let bed = WardrobeCatalog.item("companion-bed")!
var originalHome = WardrobeState()
originalHome.owned = ["cozy", "cap"]
originalHome.equipped = ["head": "cap"]
originalHome.furniture = ["desk": "desk-monitor"]
let oldJSON = "{\"owned\":[\"cozy\",\"cap\"],\"equipped\":{\"head\":\"cap\"},\"room\":\"cozy\",\"colorway\":\"mint\",\"furniture\":{\"desk\":\"desk-monitor\"},\"seeded\":true}"
let migratedHome = WardrobeState.decode(oldJSON)
check(migratedHome.owned == originalHome.owned && migratedHome.colorway == "mint" && migratedHome.seeded, "old wardrobe saves retain ownership and color")
check(migratedHome.homeLayout == .deskLeft && migratedHome.homeLampOn, "old wardrobe saves get safe room defaults")
let previewHome = originalHome.previewing(bed)
check(previewHome.furniture["floorRight"] == bed.id && !originalHome.owned.contains(bed.id) && originalHome.furniture["floorRight"] == nil, "locked preview never changes real ownership or placement")
var newHome = previewHome
newHome.homeLayout = .deskRight; newHome.homeLampOn = false
check(WardrobeState.decode(newHome.json) == newHome, "layout and lamp survive save round trip")
var previewLedger = [WardrobePurchase]()
check(!originalHome.buy(bed, earned: 349, ledger: &previewLedger, now: start), "preview does not bypass bed price")
check(previewLedger.isEmpty && !originalHome.owned.contains(bed.id), "failed preview purchase leaves ledger and ownership intact")
check(originalHome.buy(bed, earned: 350, ledger: &previewLedger, now: start), "bed can be purchased once")
check(!originalHome.buy(bed, earned: 700, ledger: &previewLedger, now: start) && previewLedger.count == 1, "repeat choice cannot charge twice")
for hour in 0..<24 {
    let expected: CompanionHomeLight = (8..<18).contains(hour) ? .day : ((6..<8).contains(hour) || (18..<21).contains(hour) ? .dusk : .night)
    check(CompanionHomeLight.at(hour: hour) == expected, "window light boundary \(hour)")
}
let fullRoom = ["desk":"desk-monitor", "floorRight":"companion-bed"]
check(CompanionHomeActivity.resolve(working: true, paused: false, elapsed: 9*3600, tired: true, furniture: fullRoom) == .working, "long active session keeps working")
check(CompanionHomeActivity.resolve(working: false, paused: true, elapsed: 4*3600, tired: false, furniture: fullRoom) == .sleeping, "long paused session rests in bed")
check(CompanionHomeActivity.resolve(working: false, paused: false, elapsed: 0, tired: true, furniture: fullRoom) == .sleeping, "tired idle companion rests in owned bed")
check(CompanionHomeActivity.resolve(working: false, paused: true, elapsed: 60, tired: false, furniture: ["floorRight":"bean-bag"]) == .relaxing, "short break uses bean bag")
check(CompanionHomeActivity.resolve(working: false, paused: true, elapsed: 8*3600, tired: true, furniture: [:]) == .relaxing, "missing furniture rests on floor")
for (roomID,room) in realHome.rooms {
    for activity in CompanionHomeActivity.allCases {
        for layout in CompanionHomeLayout.allCases {
            let center = activity.center(in: room, layout: layout)
            let half = activity.side/2
            check(center.x-half >= 0 && center.x+half <= 360 && center.y-half >= 0, "companion canvas fits \(roomID)/\(activity)/\(layout)")
            let other = activity.center(in: room, layout: layout == .deskLeft ? .deskRight : .deskLeft)
            check(abs(center.x+other.x-360)<0.01 && center.y == other.y, "mirrored companion keeps floor height")
        }
    }
    for (id,item) in realHome.items {
        let image = realImage("Home/"+item.file)
        let origin = WardrobeGeometry.origin(pivot: item.pivot, anchor: room.slots[item.slot]!, degrees: 0)
        let mirroredX = 360-origin.x-Double(image.width)
        check(mirroredX >= 0 && mirroredX+Double(image.width) <= 360 && origin.y >= 0 && origin.y+Double(image.height) <= 240, "mirrored furniture stays inside \(roomID)/\(id)")
    }
}

for (roomID,room) in realHome.rooms {
    let candidates = realHome.items.filter { $0.value.slot != "rug" }.sorted { $0.key < $1.key }
    for (index,a) in candidates.enumerated() {
        for b in candidates.dropFirst(index+1) where a.value.slot != b.value.slot {
            @MainActor func rect(_ item: WardrobeFurniture) -> CGRect {
                let image = realImage("Home/"+item.file)
                let origin = WardrobeGeometry.origin(pivot:item.pivot,anchor:room.slots[item.slot]!,degrees:0)
                return CGRect(x:origin.x,y:origin.y,width:Double(image.width),height:Double(image.height))
            }
            check(!rect(a.value).intersects(rect(b.value)), "furniture slots do not collide \(roomID)/\(a.key)/\(b.key)")
        }
    }
}


for (roomID, room) in realHome.rooms {
    for layout in CompanionHomeLayout.allCases {
        for seat in [[:], ["floorRight":"bean-bag"]] {
            let expected = CompanionHomeActivity.working.center(in:room,layout:layout,furniture:seat)
            for desk in ["", "desk-monitor", "desk-lamp", "record-player"] {
                var equipped = seat
                if !desk.isEmpty { equipped["desk"] = desk }
                let activity = CompanionHomeActivity.resolve(working:true,paused:false,elapsed:60,tired:false,furniture:equipped)
                let actual = activity.center(in:room,layout:layout,furniture:equipped)
                check(activity == .working, "working pose does not require a desk")
                check(actual.x == expected.x && actual.y == expected.y, "changing desk cannot move companion")
            }
            let rest = CompanionHomeActivity.resolve(working:false,paused:false,elapsed:0,tired:false,furniture:seat)
            check(rest == .relaxing, "idle companion sits with or without bean bag")
        }
        check(HomeSceneLayout.mirrorsCompanion(.working,layout:layout) == (layout == .deskLeft), "typing faces selected room direction")
        check(HomeSceneLayout.mirrorsCompanion(.relaxing,layout:layout) == (layout == .deskRight), "resting faces selected room direction")
        let wall = CGRect(x:22,y:24,width:316,height:142)
        let window = CGRect(x:layout.mirrored ? 26 : 234,y:27,width:100,height:101)
        for id in ["ataturk-portrait", "turkish-flag"] {
            let item = realHome.items[id]!, image = realImage("Home/"+item.file)
            let rect = HomeSceneLayout.furnitureRect(item, in:room,
                imageSize:CGSize(width:image.width,height:image.height),layout:layout)
            check(wall.contains(rect), "wall art clears ceiling and trim: \(roomID)/\(id)/\(layout)")
            check(!rect.intersects(window), "wall art clears window: \(roomID)/\(id)/\(layout)")
        }
        for id in ["desk-monitor", "desk-lamp", "record-player"] {
            let item = realHome.items[id]!, image = realImage("Home/"+item.file)
            let rect = HomeSceneLayout.furnitureRect(item, in:room,
                imageSize:CGSize(width:image.width,height:image.height),layout:layout)
            let shelf = realHome.items["bookshelf"]!, shelfImage = realImage("Home/"+shelf.file)
            let shelfRect = HomeSceneLayout.furnitureRect(shelf,in:room,
                imageSize:CGSize(width:shelfImage.width,height:shelfImage.height),layout:layout)
            check(abs(rect.minY-shelfRect.maxY-8) < 0.01, "decorative desk clears bookshelf by eight points")
            check(abs(rect.midX-shelfRect.midX) < 0.01, "desk centered below bookshelf")
            check(abs(rect.maxY-room.floorY) < 0.01, "desk feet meet back-wall floor")
            check(abs(rect.width/rect.height-Double(image.width)/Double(image.height)) < 0.001, "desk artwork preserves proportions")
        }
    }
}

// Offline scene proof using the production wardrobe compositor and home geometry.
@MainActor func homeProof(roomID: String, activity: CompanionHomeActivity, layout: CompanionHomeLayout, deskID: String = "desk-monitor") {
    let room = realHome.rooms[roomID]!
    var outfit = WardrobeState()
    outfit.equipped = ["head":"beanie", "neck":"scarf"]
    let furniture = ["round-rug", "ataturk-portrait", "turkish-flag", "bookshelf", deskID, "potted-plant", "coffee-machine",
                     activity == .sleeping ? "companion-bed" : "bean-bag"]
    let context = CGContext(data:nil,width:720,height:480,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x:0,y:480); context.scaleBy(x:2,y:-2); context.interpolationQuality = .none
    func draw(_ image:CGImage,x:Double,y:Double,w:Double,h:Double,mirror:Bool=false) {
        context.saveGState()
        context.translateBy(x:mirror ? x+w : x,y:y+h)
        context.scaleBy(x:mirror ? -1:1,y:-1)
        context.draw(image,in:CGRect(x:0,y:0,width:w,height:h));context.restoreGState()
    }
    draw(realImage("Home/"+room.file),x:0,y:0,w:360,h:240,mirror:layout.mirrored)
    for id in furniture {
        let item=realHome.items[id]!,image=realImage("Home/"+item.file)
        let rect = HomeSceneLayout.furnitureRect(item, in: room,
            imageSize: CGSize(width: image.width, height: image.height), layout: layout)
        let p = WardrobePoint(rect.minX, rect.minY), x = rect.minX
        if ["floorLeft","floorRight","desk"].contains(item.slot) {
            context.setFillColor(CGColor(gray:0,alpha:0.16))
            context.fillEllipse(in:CGRect(x:x+rect.width*0.08,y:p.y+rect.height-6,width:rect.width*0.84,height:9))
        }
        draw(image,x:x,y:p.y,w:rect.width,h:rect.height,mirror:layout.mirrored && !HeritageArt.preservesOrientation(id))
    }
    let frame: String = switch activity {case .idle: "h01";case .working: "t01";case .relaxing: "c01";case .sleeping: "z01"}
    if activity == .sleeping { outfit.equipped = [:] }
    let overlays=WardrobeArt.overlays(frame:frame,outfit:outfit,images:artImages,anchorManifest:realAnchors,spriteManifest:realSprites)
    let original = realImage("Frames/"+frame+".png")
    let pose = activity == .working ? WardrobeArt.seatedWorkingFrame(original, seated: realImage("Frames/c01.png")) : original
    let robot=WardrobeArt.composite(robot:pose,parts:overlays,size:314)!
    let center=activity.center(in:room,layout:layout,furniture:Dictionary(uniqueKeysWithValues:furniture.map { (realHome.items[$0]!.slot,$0) })),side=activity.side
    context.saveGState()
    context.translateBy(x:center.x,y:center.y)
    if activity == .sleeping {
        context.rotate(by:layout.mirrored ? .pi/2:-.pi/2)
        context.addEllipse(in:CGRect(x:-side/2+117*side/314,y:-side/2+70*side/314,width:98*side/314,height:84*side/314)); context.clip()
    }
    draw(robot,x:-side/2,y:-side/2,w:side,h:side,mirror:HomeSceneLayout.mirrorsCompanion(activity, layout:layout))
    context.restoreGState()
    savePNG(context.makeImage()!, "/tmp/clockin-home-"+roomID+"-"+activity.rawValue+"-"+layout.rawValue+"-"+deskID+".png")
}
for roomID in realHome.rooms.keys.sorted() {
    for activity in CompanionHomeActivity.allCases {
        for layout in CompanionHomeLayout.allCases {
            for desk in (activity == .working ? ["desk-monitor", "desk-lamp", "record-player"] : ["desk-monitor"]) {
                homeProof(roomID:roomID,activity:activity,layout:layout,deskID:desk)
            }
        }
    }
}


// A sprite can fit inside the canvas yet disappear behind the robot. Measure
// the actual alpha masks at the same placement used by animation and widgets.
func rgba(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating:0,count:image.width*image.height*4)
    bytes.withUnsafeMutableBytes { buffer in
        let c = CGContext(data:buffer.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
    }
    return bytes
}
let emptyContext = CGContext(data:nil,width:314,height:314,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
let emptyRobot = emptyContext.makeImage()!

let visibilityAnchors = realAnchors.merging(fixedAnchors) { motion, _ in motion }
for frame in visibilityAnchors.keys.sorted() where !frame.hasPrefix("acc-") {
    let source: CGImage
    if frame.hasPrefix("pose") {
        let url = artRoot.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Clockin/Assets.xcassets/" + frame + ".imageset/" + frame + ".png")
        source = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
    } else { source = realImage("Frames/" + frame + ".png") }
    let robot = rgba(WardrobeArt.composite(robot: source, parts: [], size: 314)!)
    for id in ["wings", "cape", "backpack", "jetpack"] {
        var outfit = WardrobeState(); outfit.equipped = ["back": id]
        let parts = WardrobeArt.overlays(frame: frame, outfit: outfit, images: artImages,
                                       anchorManifest: visibilityAnchors, spriteManifest: realSprites)
        check(parts.count == 1 && parts[0].behind, "back accessory keeps depth \(frame)/\(id)")
        let layer = rgba(WardrobeArt.composite(robot: emptyRobot, parts: parts, size: 314)!)
        var total = 0, visible = 0, left = 0, right = 0
        let center = Int(visibilityAnchors[frame]!.back.x)
        for i in stride(from: 3, to: layer.count, by: 4) where layer[i] > 0 {
            total += 1
            if robot[i] == 0 {
                visible += 1
                if (i / 4) % 314 < center { left += 1 } else { right += 1 }
            }
        }
        let share = Double(visible) / Double(max(1, total))
        check(share >= (id == "wings" ? 0.40 : 0.15), "back accessory stays recognizable \(frame)/\(id) (\(share))")
        if id == "wings" { check(left >= 500 && right >= 500, "both wings visible \(frame)") }
    }
}

// Antenna removal must preserve the helmet, face and raised hands.
let headFrames = ["h01", "t01", "c01", "e01", "pose2", "pose3", "pose4"]
let headItems = realSprites.keys.filter { realSprites[$0]!.slot == "head" }.sorted()
for id in headItems {
    var outfit = WardrobeState(); outfit.equipped = ["head": id]
    check(WardrobeArt.hidesAntenna(outfit, spriteManifest: realSprites), "headwear hides built-in antenna: \(id)")
}
for id in ["unknown", "scarf", "wings"] {
    var outfit = WardrobeState(); outfit.equipped = ["head": id]
    check(!WardrobeArt.hidesAntenna(outfit, spriteManifest: realSprites), "invalid head slot retains antenna")
}
check(!WardrobeArt.hidesAntenna(WardrobeState(), spriteManifest: realSprites), "bare head retains antenna")
let headSheet = CGContext(data: nil, width: headFrames.count * 157, height: headItems.count * 157,
                         bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
headSheet.setFillColor(CGColor(gray: 0.13, alpha: 1)); headSheet.fill(CGRect(x: 0, y: 0, width: headSheet.width, height: headSheet.height))
for frame in visibilityAnchors.keys.sorted() where !frame.hasPrefix("acc-") {
    let original: CGImage
    if frame.hasPrefix("pose") {
        let url = artRoot.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Clockin/Assets.xcassets/" + frame + ".imageset/" + frame + ".png")
        original = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
    } else { original = realImage("Frames/" + frame + ".png") }
    let completed = frame.hasPrefix("t") ? WardrobeArt.seatedWorkingFrame(original, seated: realImage("Frames/c01.png")) : original
    let normalized = WardrobeArt.composite(robot: completed, parts: [], size: 314)!
    let hidden = WardrobeArt.removingAntenna(normalized, frame: frame)
    let rect = WardrobeArt.antennaRect(frame: frame)!
    check(pixel(hidden, Int(rect.midX), Int(rect.midY))[3] == 0, "headwear clears antenna \(frame)")
    let anchor = visibilityAnchors[frame]!
    check(pixel(hidden, Int(anchor.visor.x), Int(anchor.visor.y)) == pixel(normalized, Int(anchor.visor.x), Int(anchor.visor.y)), "headwear preserves face \(frame)")
    check(pixel(hidden, Int(anchor.head.x), Int(anchor.head.y + 5)) == pixel(normalized, Int(anchor.head.x), Int(anchor.head.y + 5)), "headwear preserves helmet \(frame)")
    guard let column = headFrames.firstIndex(of: frame) else { continue }
    for (row, id) in headItems.enumerated() {
        var outfit = WardrobeState(); outfit.equipped = ["head": id]
        let parts = WardrobeArt.overlays(frame: frame, outfit: outfit, images: artImages, anchorManifest: visibilityAnchors, spriteManifest: realSprites)
        let image = WardrobeArt.composite(robot: hidden, parts: parts, size: 314)!
        headSheet.draw(image, in: CGRect(x: column * 157, y: (headItems.count - 1 - row) * 157, width: 157, height: 157))
        if frame == "t01" && id == "cap" { savePNG(image, "/tmp/clockin-cap-working.png") }
    }
}
savePNG(headSheet.makeImage()!, "/tmp/clockin-headwear-sheet.png")
let classicBase = realImage("Frames/h01.png")
check(WardrobeArt.recolor(classicBase, colorway: realColors["classic"]!) === classicBase, "classic CGImage is identical without pixel work")


// Exercise the production decode/cache path, not only a preview compositor.
let sourceFrames = ["c01"] + realAnchors.keys.filter { $0.hasPrefix("t") }.sorted()
let workingSources = sourceFrames.reduce(into: [String: CGImage]()) { $0[$1] = realImage("Frames/" + $1 + ".png") }
// Coffee faces left; typing faces right. The seated boots must follow the torso.
let seatedSource = workingSources["c01"]!
let fittedLegs = WardrobeArt.workingLegs(from: seatedSource)!
for (x, y) in [(20, 40), (45, 32), (90, 24), (113, 40)] {
    check(pixel(fittedLegs, x, y) == pixel(seatedSource, 124 + 131 - x, 224 + y), "working boots face the laptop at \(x)/\(y)")
}
let workingCache = WardrobeFrameCache(decode: { id, _ in workingSources[id] })
let withAntenna = await workingCache.image("t01", colorway: "classic")!
let withoutAntenna = await workingCache.image("t01", colorway: "classic", hidingAntenna: true)!
check(pixel(withAntenna, 117, 60)[3] > 0 && pixel(withoutAntenna, 117, 60)[3] == 0, "cache separates original and headwear frames")
let restoredAntenna = await workingCache.image("t01", colorway: "classic")!
check(restoredAntenna === withAntenna, "removing headwear restores original cached antenna")

for frame in sourceFrames where frame.hasPrefix("t") {
    let completed = await workingCache.image(frame, colorway: "classic")
    check(completed != nil, "working frame decodes \(frame)")
    // Both boots extend below the old laptop-only silhouette and stay stable.
    for x in [133, 196] {
        check(pixel(completed!, x, 286)[3] > 0, "working boot present \(frame)/\(x)")
        let resting = await workingCache.image("t01", colorway: "classic")!
        check(pixel(completed!, x, 286) == pixel(resting, x, 286), "boots stable while typing \(frame)/\(x)")
    }
    for item in WardrobeCatalog.items where item.slot == .hand {
        var held = WardrobeState()
        held.equipped = ["hand": item.id]
        check(WardrobeArt.overlays(frame: frame, outfit: held, images: artImages, anchorManifest: realAnchors, spriteManifest: realSprites).isEmpty, "typing frees hands for \(item.id)/\(frame)")
        check(held.equipped["hand"] == item.id, "typing preserves selected item")
        check(WardrobeArt.overlays(frame: "h01", outfit: held, images: artImages, anchorManifest: realAnchors, spriteManifest: realSprites).count == 1, "idle restores \(item.id)")
    }
    savePNG(completed!, "/tmp/clockin-working-" + frame + ".png")
}
// Motion proof uses the same hinge, split and curve as the live layer host.
let wingProofURL = URL(fileURLWithPath: "/tmp/clockin-wing-flap.gif")
let wingProof = CGImageDestinationCreateWithURL(wingProofURL as CFURL, "com.compuserve.gif" as CFString, 37, nil)!
CGImageDestinationSetProperties(wingProof, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let wingImage = artImages["wings"]!, wingSprite = realSprites["wings"]!
let wingOrigin = WardrobeGeometry.placement(sprite: wingSprite, frame: realAnchors["t01"]!, frameID: "t01")!
let proofRobot = await workingCache.image("t01", colorway: "classic")!
for step in 0...36 {
    let pose = MascotWingMotion.pose(progress: Double(step) / 36)
    let c = CGContext(data: nil, width: 314, height: 314, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setFillColor(CGColor(gray: 0.075, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: 314, height: 314))
    c.translateBy(x: 0, y: 314); c.scaleBy(x: 1, y: -1); c.interpolationQuality = .none
    func draw(_ image: CGImage, _ rect: CGRect) {
        c.saveGState(); c.translateBy(x: rect.minX, y: rect.maxY); c.scaleBy(x: 1, y: -1)
        c.draw(image, in: CGRect(origin: .zero, size: rect.size)); c.restoreGState()
    }
    for left in [true, false] {
        let split = wingSprite.pivot.x
        let width = left ? split : Double(wingImage.width) - split
        let half = wingImage.cropping(to: CGRect(x: left ? 0 : split, y: 0, width: width, height: Double(wingImage.height)))!
        c.saveGState()
        c.translateBy(x: wingOrigin.x + split, y: wingOrigin.y + wingSprite.pivot.y)
        c.rotate(by: left ? pose.radians : -pose.radians); c.scaleBy(x: pose.scaleX, y: 1)
        draw(half, CGRect(x: left ? -split : 0, y: -wingSprite.pivot.y, width: width, height: Double(half.height)))
        c.restoreGState()
    }
    draw(proofRobot, CGRect(x: 0, y: 0, width: 314, height: 314))
    let delay = step == 36 ? MascotWingMotion.rest : MascotWingMotion.duration / 36
    CGImageDestinationAddImage(wingProof, c.makeImage()!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    if step == 9 { savePNG(c.makeImage()!, "/tmp/clockin-wing-fold.png") }
}
check(CGImageDestinationFinalize(wingProof), "animated wing composition proof")

check(WardrobeArt.workingLegs(from: tiny) == nil, "invalid seated source safely ignored")
let cache = WardrobeFrameCache(decode: { _, _ in
    precondition(!Thread.isMainThread, "Frame decode must leave main thread")
    return WardrobeArt.recolor(classicBase, colorway: realColors["mint"]!)
})
async let cachedFirst = cache.image("synthetic", colorway: "classic")
async let cachedSecond = cache.image("synthetic", colorway: "classic")
let cachedPair = await (cachedFirst, cachedSecond)
check(cachedPair.0 !== classicBase && cachedPair.0 != nil && cachedPair.0 === cachedPair.1, "concurrent frame requests share cached image off main thread")
print("\(checks) wardrobe checks passed including real art integration and cache")
