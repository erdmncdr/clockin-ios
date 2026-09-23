import Foundation

enum WardrobeSlot: String, CaseIterable, Codable, Sendable {
    case head, face, neck, back, hand, colorway, room
    case floorLeft, floorRight, wallLeft, wallRight, window, rug, desk, shelf
    static let outfit: [Self] = [.head, .face, .neck, .back, .hand, .colorway]
    static let furniture: [Self] = [.floorLeft, .floorRight, .wallLeft, .wallRight, .window, .rug, .desk, .shelf]
}

enum WardrobeUnlock: Equatable, Sendable {
    case free, hours(Int), level(Int), streak(Int), badge(String), coins(Int)
    var price: Int? { if case .coins(let cost) = self { return cost }; return nil }
    var label: String {
        switch self {
        case .free: String(localized: "Free")
        case .hours(let n): String(localized: "\(n) hours of work")
        case .level(let n): String(localized: "Level \(n)")
        case .streak(let n): String(localized: "\(n)-day streak")
        case .badge(let id): id == "first" ? String(localized: "First session badge") : String(localized: "Badge: \(id)")
        case .coins(let n): String(localized: "\(n) coins")
        }
    }
    func met(by progress: WardrobeProgress) -> Bool {
        switch self {
        case .free: true
        case .hours(let n): progress.hours >= Double(n)
        case .level(let n): progress.level >= n
        case .streak(let n): progress.streak >= n
        case .badge(let id): progress.badges.contains(id)
        case .coins: false
        }
    }
}

struct WardrobeItem: Identifiable, Sendable {
    let id: String
    let name: String
    let slot: WardrobeSlot
    let unlock: WardrobeUnlock
    var isHomeItem: Bool { slot == .room || WardrobeSlot.furniture.contains(slot) }
}

struct WardrobeProgress: Sendable {
    var hours = 0.0
    var level = 1
    var streak = 0
    var badges: Set<String> = []
}

struct WardrobePurchase: Codable, Equatable, Sendable {
    let itemID: String
    let cost: Int
    let date: Date
}

struct WardrobeState: Codable, Equatable, Sendable {
    var owned: Set<String> = []
    var equipped: [String: String] = [:]
    var colorway = "classic"
    var room = "cozy"
    var furniture: [String: String] = [:]
    var seeded = false
    var homeLayout: CompanionHomeLayout = .deskLeft
    var homeLampOn = true
    var homeArrangement = RoomArrangement()

    init() {}
    private enum CodingKeys: String, CodingKey {
        case owned, equipped, colorway, room, furniture, seeded, homeLayout, homeLampOn, homeArrangement
    }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        owned = try values.decodeIfPresent(Set<String>.self, forKey: .owned) ?? []
        equipped = try values.decodeIfPresent([String:String].self, forKey: .equipped) ?? [:]
        colorway = try values.decodeIfPresent(String.self, forKey: .colorway) ?? "classic"
        room = try values.decodeIfPresent(String.self, forKey: .room) ?? "cozy"
        furniture = try values.decodeIfPresent([String:String].self, forKey: .furniture) ?? [:]
        seeded = try values.decodeIfPresent(Bool.self, forKey: .seeded) ?? false
        homeLayout = CompanionHomeLayout(rawValue: try values.decodeIfPresent(String.self, forKey: .homeLayout) ?? "") ?? .deskLeft
        homeLampOn = try values.decodeIfPresent(Bool.self, forKey: .homeLampOn) ?? true
        homeArrangement = (try? values.decode(RoomArrangement.self, forKey: .homeArrangement)) ?? .init()
    }

    func previewing(_ item: WardrobeItem) -> Self {
        var copy = self
        copy.owned.insert(item.id)
        copy.equip(item)
        return copy
    }

    static let stateKey = "Clockin.WardrobeState"
    static let ledgerKey = "Clockin.WardrobeLedger"
    static let deskKey = "Clockin.WardrobeShowHomeInDeskMode"

    static func decode(_ json: String?) -> Self {
        json?.data(using: .utf8).flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
    }
    var json: String? { (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } }

    mutating func unlock(_ progress: WardrobeProgress, legacy: String? = nil, legacyOwned: Set<String> = []) -> [String] {
        let newlyOwned = WardrobeCatalog.items.filter { !owned.contains($0.id) && $0.unlock.met(by: progress) }.map(\.id)
        owned.formUnion(newlyOwned)
        if !seeded {
            let legacyIDs = ["headphones", "mug", "cape", "antenna"]
            owned.formUnion(legacyOwned.intersection(legacyIDs))
            if let legacy {
                // Eski secici yalnizca kazanilmis esyayi kaydedebiliyordu.
                if legacyIDs.contains(legacy) { owned.insert(legacy) }
                let id = legacy == "Auto" ? legacyIDs.last(where: { owned.contains($0) }) : legacy
                if let id, let item = WardrobeCatalog.item(id), owned.contains(id) { equip(item) }
            }
            seeded = true
            return []
        }
        return newlyOwned
    }

    mutating func equip(_ item: WardrobeItem) {
        guard owned.contains(item.id) else { return }
        if item.slot == .colorway { colorway = item.id }
        else if item.slot == .room { room = item.id }
        else if WardrobeSlot.furniture.contains(item.slot) { furniture[item.slot.rawValue] = item.id }
        else { equipped[item.slot.rawValue] = item.id }
    }

    mutating func buy(_ item: WardrobeItem, earned: Int, ledger: inout [WardrobePurchase], now: Date) -> Bool {
        guard !owned.contains(item.id), let cost = item.unlock.price, cost > 0,
              WardrobeCoins.balance(earned: earned, ledger: ledger) >= cost else { return false }
        ledger.append(.init(itemID: item.id, cost: cost, date: now))
        owned.insert(item.id)
        equip(item)
        return true
    }
}

enum WardrobeCoins {
    static func earned(durations: [TimeInterval], goalDays: Int, badges: Int, level: Int) -> Int {
        // Oturum saniyeleri tasinmaz; tam dakikalar birlikte coin'e cevrilir.
        let minutes = durations.reduce(0.0) { sum, duration in
            sum + (duration.isFinite ? floor(max(0, duration) / 60) : 0)
        }
        let total = floor(minutes / 6) + Double(max(0, goalDays)) * 25
            + Double(max(0, badges)) * 50 + Double(max(0, level)) * 100
        return Int(min(Double(Int.max / 2), total))
    }
    static func balance(earned: Int, ledger: [WardrobePurchase]) -> Int {
        ledger.reduce(max(0, earned)) { max(0, $0 - min(max(0, $1.cost), $0)) }
    }
}

struct WardrobePoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        x = try values.decode(Double.self); y = try values.decode(Double.self)
        guard x.isFinite, y.isFinite else { throw DecodingError.dataCorruptedError(in: values, debugDescription: "Invalid point") }
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.unkeyedContainer(); try values.encode(x); try values.encode(y)
    }
}

struct WardrobeAnchors: Codable, Sendable {
    let head: WardrobePoint
    let visor: WardrobePoint
    let neck: WardrobePoint
    let back: WardrobePoint
    let handL: WardrobePoint?
    let handR: WardrobePoint?
    let tilt: Double
    func point(_ key: String) -> WardrobePoint? {
        switch key {
        case "head": head
        case "visor": visor
        case "neck": neck
        case "back": back
        case "handR": handR
        default: nil
        }
    }
}

struct WardrobeSprite: Codable, Sendable {
    let slot: String
    let anchorPoint: String
    let pivot: WardrobePoint
    let layer: String
    /// Authored fitting adjustments for side-facing clips and fixed poses.
    let poseOffsets: [String: WardrobePoint]?

    func offset(for frameID: String) -> WardrobePoint {
        poseOffsets?[frameID] ?? poseOffsets?[String(frameID.prefix(1))] ?? WardrobePoint(0, 0)
    }
}
struct WardrobeRoom: Codable, Sendable {
    let name: String
    let file: String
    let floorY: Double
    let slots: [String: WardrobePoint]
    let mascotSpot: WardrobePoint
}
struct WardrobeFurniture: Codable, Sendable {
    let name: String
    let file: String
    let slot: String
    let pivot: WardrobePoint
}
struct WardrobeHome: Codable, Sendable {
    var rooms: [String: WardrobeRoom] = [:]
    var items: [String: WardrobeFurniture] = [:]
}

enum WardrobeGeometry {
    static func tilt(sprite: WardrobeSprite, frame: WardrobeAnchors) -> Double {
        ["head", "face"].contains(sprite.slot) ? frame.tilt : 0
    }
    static func origin(pivot: WardrobePoint, anchor: WardrobePoint, degrees: Double) -> WardrobePoint {
        let angle = degrees * .pi / 180
        return .init(anchor.x - pivot.x * cos(angle) + pivot.y * sin(angle),
                     anchor.y - pivot.x * sin(angle) - pivot.y * cos(angle))
    }
    static func placement(sprite: WardrobeSprite, frame: WardrobeAnchors, frameID: String = "") -> WardrobePoint? {
        // Keep the selection, but free occupied hands for the entire pose.
        if sprite.slot == "hand", frameID.hasPrefix("t") || frameID.hasPrefix("c") { return nil }
        guard frame.tilt.isFinite, let anchor = frame.point(sprite.slot == "hand" ? "handR" : sprite.anchorPoint) else { return nil }
        let offset = sprite.offset(for: frameID)
        guard offset.x.isFinite, offset.y.isFinite else { return nil }
        let fitted = WardrobePoint(anchor.x + offset.x, anchor.y + offset.y)
        return origin(pivot: sprite.pivot, anchor: fitted, degrees: tilt(sprite: sprite, frame: frame))
    }
}


enum CompanionHomeLayout: String, Codable, CaseIterable, Sendable {
    case deskLeft, deskRight
    var title: String { self == .deskLeft ? String(localized: "Room left") : String(localized: "Room right") }
    var mirrored: Bool { self == .deskRight }
    func x(_ x: Double) -> Double { mirrored ? 360 - x : x }
}

enum CompanionHomeActivity: String, CaseIterable, Sendable {
    case idle, working, relaxing, sleeping
    static func resolve(working: Bool, paused: Bool, elapsed: Double, tired: Bool, furniture: [String:String]) -> Self {
        if working { return .working }
        // Rest never hides an active session. A long paused session can use the bed.
        if !working && (tired || (paused && elapsed >= 4 * 3600)), furniture["floorRight"] == "companion-bed" { return .sleeping }
        if !working && furniture["floorRight"] == "bean-bag" { return .relaxing }
        return .relaxing
    }
    var title: String {
        switch self {
        case .idle: String(localized: "At home")
        case .working: String(localized: "Working")
        case .relaxing: String(localized: "Taking a break")
        case .sleeping: String(localized: "Resting")
        }
    }
    var mood: MascotMood {
        switch self { case .idle: .hello; case .working: .working; case .relaxing: .coffee; case .sleeping: .tired }
    }
    var side: Double { self == .idle ? 136 : (self == .sleeping ? 96 : (self == .relaxing ? 116 : 118)) }
    func center(in room: WardrobeRoom, layout: CompanionHomeLayout, furniture: [String:String] = [:], roomID: String = "", arrangement: RoomArrangement = .init()) -> WardrobePoint {
        let point: WardrobePoint
        switch self {
        case .idle: point = .init(room.mascotSpot.x, room.mascotSpot.y - side * (mood.feet - 0.5))
        case .working:
            return HomeSceneLayout.seatedCenter(in: room, layout: layout, side: side, feet: mood.feet, furniture: furniture, roomID: roomID, arrangement: arrangement)
        case .relaxing:
            return HomeSceneLayout.seatedCenter(in: room, layout: layout, side: side, feet: mood.feet, furniture: furniture, roomID: roomID, arrangement: arrangement)
        case .sleeping:
            let bed = room.slots["floorRight"] ?? .init(302,224)
            let delta = HomeSceneLayout.attachmentOffset("companion-bed",in:room,layout:layout,roomID:roomID,arrangement:arrangement)
            return .init(layout.x(bed.x - 7) + delta.x, bed.y - 28 + delta.y)
        }
        return .init(layout.x(point.x), point.y)
    }
}

enum CompanionHomeLight: String, Sendable {
    case day, dusk, night
    static func at(hour: Int) -> Self {
        if hour >= 8 && hour < 18 { return .day }
        if hour >= 18 && hour < 21 || hour >= 6 && hour < 8 { return .dusk }
        return .night
    }
}
