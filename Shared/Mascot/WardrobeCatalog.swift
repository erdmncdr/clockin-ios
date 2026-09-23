import Foundation

// Kimlikler sanat dosyalarinin kok adlariyla aynidir.
enum WardrobeCatalog {
    static let items: [WardrobeItem] = [
        .init(id: "ataturk-portrait", name: String(localized: "Atatürk portrait"), slot: .wallLeft, unlock: .free),
        .init(id: "turkish-flag", name: String(localized: "Turkish flag"), slot: .wallRight, unlock: .free),
        .init(id: "cap", name: String(localized: "Cap"), slot: .head, unlock: .free),
        .init(id: "round-glasses", name: String(localized: "Round glasses"), slot: .face, unlock: .free),
        .init(id: "headphones", name: String(localized: "Headphones"), slot: .head, unlock: .hours(25)),
        .init(id: "mug", name: String(localized: "Mug"), slot: .hand, unlock: .hours(50)),
        .init(id: "cape", name: String(localized: "Cape"), slot: .back, unlock: .hours(100)),
        .init(id: "antenna", name: String(localized: "Gold antenna"), slot: .head, unlock: .hours(250)),
        .init(id: "crown", name: String(localized: "Crown"), slot: .head, unlock: .level(50)),
        .init(id: "wizard-hat", name: String(localized: "Wizard hat"), slot: .head, unlock: .streak(30)),
        .init(id: "bow-tie", name: String(localized: "Bow tie"), slot: .neck, unlock: .badge("first")),
        .init(id: "scarf", name: String(localized: "Scarf"), slot: .neck, unlock: .coins(50)),
        .init(id: "sunglasses", name: String(localized: "Sunglasses"), slot: .face, unlock: .coins(100)),
        .init(id: "balloon", name: String(localized: "Balloon"), slot: .hand, unlock: .coins(150)),
        .init(id: "backpack", name: String(localized: "Backpack"), slot: .back, unlock: .coins(300)),
        .init(id: "wings", name: String(localized: "Wings"), slot: .back, unlock: .coins(1500)),
        .init(id: "beanie", name: String(localized: "Beanie"), slot: .head, unlock: .coins(75)),
        .init(id: "party-hat", name: String(localized: "Party hat"), slot: .head, unlock: .coins(100)),
        .init(id: "chef-hat", name: String(localized: "Chef hat"), slot: .head, unlock: .coins(200)),
        .init(id: "cowboy-hat", name: String(localized: "Cowboy hat"), slot: .head, unlock: .coins(300)),
        .init(id: "pixel-shades", name: String(localized: "Pixel shades"), slot: .face, unlock: .coins(150)),
        .init(id: "monocle", name: String(localized: "Monocle"), slot: .face, unlock: .coins(250)),
        .init(id: "gold-medal", name: String(localized: "Gold medal"), slot: .neck, unlock: .coins(300)),
        .init(id: "necktie", name: String(localized: "Necktie"), slot: .neck, unlock: .coins(100)),
        .init(id: "jetpack", name: String(localized: "Jetpack"), slot: .back, unlock: .coins(1000)),
        .init(id: "trophy", name: String(localized: "Trophy"), slot: .hand, unlock: .coins(500)),
        .init(id: "small-flag", name: String(localized: "Explorer flag"), slot: .hand, unlock: .coins(150)),
        .init(id: "classic", name: String(localized: "Classic"), slot: .colorway, unlock: .free),
        .init(id: "mint", name: String(localized: "Mint"), slot: .colorway, unlock: .coins(200)),
        .init(id: "sunset", name: String(localized: "Sunset"), slot: .colorway, unlock: .coins(200)),
        .init(id: "midnight", name: String(localized: "Midnight"), slot: .colorway, unlock: .coins(500)),
        .init(id: "gold", name: String(localized: "Gold"), slot: .colorway, unlock: .coins(500)),
        .init(id: "stealth", name: String(localized: "Stealth"), slot: .colorway, unlock: .coins(500)),
        .init(id: "cozy", name: String(localized: "Cozy"), slot: .room, unlock: .free),
        .init(id: "studio", name: String(localized: "Studio"), slot: .room, unlock: .coins(750)),
        .init(id: "night", name: String(localized: "Night"), slot: .room, unlock: .coins(1000)),
        .init(id: "cat-bed", name: String(localized: "Sleeping cat bed"), slot: .floorLeft, unlock: .coins(50)),
        .init(id: "big-plant", name: String(localized: "Big plant"), slot: .floorRight, unlock: .coins(100)),
        .init(id: "poster", name: String(localized: "Poster"), slot: .wallLeft, unlock: .coins(100)),
        .init(id: "wall-clock", name: String(localized: "Wall clock"), slot: .wallRight, unlock: .coins(150)),
        .init(id: "potted-plant", name: String(localized: "Potted plant"), slot: .window, unlock: .coins(200)),
        .init(id: "round-rug", name: String(localized: "Round rug"), slot: .rug, unlock: .coins(150)),
        .init(id: "desk-monitor", name: String(localized: "Desk and monitor"), slot: .desk, unlock: .coins(400)),
        .init(id: "bookshelf", name: String(localized: "Bookshelf"), slot: .shelf, unlock: .coins(300)),
        .init(id: "companion-bed", name: String(localized: "Companion bed"), slot: .floorRight, unlock: .coins(350)),
        .init(id: "bean-bag", name: String(localized: "Bean bag"), slot: .floorRight, unlock: .coins(250)),
        .init(id: "guitar", name: String(localized: "Guitar"), slot: .floorRight, unlock: .coins(500)),
        .init(id: "floor-lamp", name: String(localized: "Floor lamp"), slot: .floorLeft, unlock: .coins(200)),
        .init(id: "coffee-machine", name: String(localized: "Coffee corner"), slot: .floorLeft, unlock: .coins(400)),
        .init(id: "desk-lamp", name: String(localized: "Writing desk"), slot: .desk, unlock: .coins(300)),
        .init(id: "record-player", name: String(localized: "Record player console"), slot: .desk, unlock: .coins(600)),
        .init(id: "certificate", name: String(localized: "Framed certificate"), slot: .wallRight, unlock: .coins(200)),
        .init(id: "string-lights", name: String(localized: "String lights"), slot: .wallLeft, unlock: .coins(150))
    ]
    static func item(_ id: String) -> WardrobeItem? { items.first { $0.id == id } }
}

/// Shopping categories describe the object, independently of its placement slot.
enum WardrobeCategory: String, CaseIterable, Identifiable, Sendable {
    case headwear, eyewear, neckwear, back, handheld, colors
    case rooms, furniture, plants, lighting, decor

    var id: String { rawValue }
    var title: String {
        switch self {
        case .headwear: String(localized: "Headwear")
        case .eyewear: String(localized: "Eyewear")
        case .neckwear: String(localized: "Neck accessories")
        case .back: String(localized: "Back accessories")
        case .handheld: String(localized: "Handheld items")
        case .colors: String(localized: "Colors")
        case .rooms: String(localized: "Rooms")
        case .furniture: String(localized: "Furniture")
        case .plants: String(localized: "Plants")
        case .lighting: String(localized: "Lighting")
        case .decor: String(localized: "Decorations")
        }
    }
    var symbol: String {
        switch self {
        case .headwear: "graduationcap"
        case .eyewear: "eyeglasses"
        case .neckwear: "medal"
        case .back: "backpack"
        case .handheld: "hand.raised"
        case .colors: "paintpalette"
        case .rooms: "house"
        case .furniture: "chair.lounge"
        case .plants: "leaf"
        case .lighting: "lamp.floor"
        case .decor: "photo.artframe"
        }
    }
    var isHome: Bool {
        switch self {
        case .rooms, .furniture, .plants, .lighting, .decor: true
        default: false
        }
    }
    var items: [WardrobeItem] { WardrobeCatalog.items.filter { $0.category == self } }
}

extension WardrobeItem {
    var category: WardrobeCategory {
        switch id {
        case "big-plant", "potted-plant": return .plants
        case "floor-lamp", "string-lights": return .lighting
        case "poster", "wall-clock", "certificate", "guitar", "ataturk-portrait", "turkish-flag": return .decor
        default: break
        }
        switch slot {
        case .head: return .headwear
        case .face: return .eyewear
        case .neck: return .neckwear
        case .back: return .back
        case .hand: return .handheld
        case .colorway: return .colors
        case .room: return .rooms
        default: return .furniture
        }
    }
}
