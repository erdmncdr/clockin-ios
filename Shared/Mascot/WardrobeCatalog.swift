import Foundation

// Kimlikler sanat dosyalarinin kok adlariyla aynidir.
enum WardrobeCatalog {
    static let items: [WardrobeItem] = [
        .init(id: "ataturk-portrait", name: "Atatürk portrait", slot: .wallLeft, unlock: .free),
        .init(id: "turkish-flag", name: "Turkish flag", slot: .wallRight, unlock: .free),
        .init(id: "cap", name: "Cap", slot: .head, unlock: .free),
        .init(id: "round-glasses", name: "Round glasses", slot: .face, unlock: .free),
        .init(id: "headphones", name: "Headphones", slot: .head, unlock: .hours(25)),
        .init(id: "mug", name: "Mug", slot: .hand, unlock: .hours(50)),
        .init(id: "cape", name: "Cape", slot: .back, unlock: .hours(100)),
        .init(id: "antenna", name: "Gold antenna", slot: .head, unlock: .hours(250)),
        .init(id: "crown", name: "Crown", slot: .head, unlock: .level(50)),
        .init(id: "wizard-hat", name: "Wizard hat", slot: .head, unlock: .streak(30)),
        .init(id: "bow-tie", name: "Bow tie", slot: .neck, unlock: .badge("first")),
        .init(id: "scarf", name: "Scarf", slot: .neck, unlock: .coins(50)),
        .init(id: "sunglasses", name: "Sunglasses", slot: .face, unlock: .coins(100)),
        .init(id: "balloon", name: "Balloon", slot: .hand, unlock: .coins(150)),
        .init(id: "backpack", name: "Backpack", slot: .back, unlock: .coins(300)),
        .init(id: "wings", name: "Wings", slot: .back, unlock: .coins(1500)),
        .init(id: "beanie", name: "Beanie", slot: .head, unlock: .coins(75)),
        .init(id: "party-hat", name: "Party hat", slot: .head, unlock: .coins(100)),
        .init(id: "chef-hat", name: "Chef hat", slot: .head, unlock: .coins(200)),
        .init(id: "cowboy-hat", name: "Cowboy hat", slot: .head, unlock: .coins(300)),
        .init(id: "pixel-shades", name: "Pixel shades", slot: .face, unlock: .coins(150)),
        .init(id: "monocle", name: "Monocle", slot: .face, unlock: .coins(250)),
        .init(id: "gold-medal", name: "Gold medal", slot: .neck, unlock: .coins(300)),
        .init(id: "necktie", name: "Necktie", slot: .neck, unlock: .coins(100)),
        .init(id: "jetpack", name: "Jetpack", slot: .back, unlock: .coins(1000)),
        .init(id: "trophy", name: "Trophy", slot: .hand, unlock: .coins(500)),
        .init(id: "small-flag", name: "Explorer flag", slot: .hand, unlock: .coins(150)),
        .init(id: "classic", name: "Classic", slot: .colorway, unlock: .free),
        .init(id: "mint", name: "Mint", slot: .colorway, unlock: .coins(200)),
        .init(id: "sunset", name: "Sunset", slot: .colorway, unlock: .coins(200)),
        .init(id: "midnight", name: "Midnight", slot: .colorway, unlock: .coins(500)),
        .init(id: "gold", name: "Gold", slot: .colorway, unlock: .coins(500)),
        .init(id: "stealth", name: "Stealth", slot: .colorway, unlock: .coins(500)),
        .init(id: "cozy", name: "Cozy", slot: .room, unlock: .free),
        .init(id: "studio", name: "Studio", slot: .room, unlock: .coins(750)),
        .init(id: "night", name: "Night", slot: .room, unlock: .coins(1000)),
        .init(id: "cat-bed", name: "Sleeping cat bed", slot: .floorLeft, unlock: .coins(50)),
        .init(id: "big-plant", name: "Big plant", slot: .floorRight, unlock: .coins(100)),
        .init(id: "poster", name: "Poster", slot: .wallLeft, unlock: .coins(100)),
        .init(id: "wall-clock", name: "Wall clock", slot: .wallRight, unlock: .coins(150)),
        .init(id: "potted-plant", name: "Potted plant", slot: .window, unlock: .coins(200)),
        .init(id: "round-rug", name: "Round rug", slot: .rug, unlock: .coins(150)),
        .init(id: "desk-monitor", name: "Desk and monitor", slot: .desk, unlock: .coins(400)),
        .init(id: "bookshelf", name: "Bookshelf", slot: .shelf, unlock: .coins(300)),
        .init(id: "companion-bed", name: "Companion bed", slot: .floorRight, unlock: .coins(350)),
        .init(id: "bean-bag", name: "Bean bag", slot: .floorRight, unlock: .coins(250)),
        .init(id: "guitar", name: "Guitar", slot: .floorRight, unlock: .coins(500)),
        .init(id: "floor-lamp", name: "Floor lamp", slot: .floorLeft, unlock: .coins(200)),
        .init(id: "coffee-machine", name: "Coffee corner", slot: .floorLeft, unlock: .coins(400)),
        .init(id: "desk-lamp", name: "Writing desk", slot: .desk, unlock: .coins(300)),
        .init(id: "record-player", name: "Record player console", slot: .desk, unlock: .coins(600)),
        .init(id: "certificate", name: "Framed certificate", slot: .wallRight, unlock: .coins(200)),
        .init(id: "string-lights", name: "String lights", slot: .wallLeft, unlock: .coins(150))
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
        case .headwear: String(localized: "Headwear", bundle: .app)
        case .eyewear: String(localized: "Eyewear", bundle: .app)
        case .neckwear: String(localized: "Neck accessories", bundle: .app)
        case .back: String(localized: "Back accessories", bundle: .app)
        case .handheld: String(localized: "Handheld items", bundle: .app)
        case .colors: String(localized: "Colors", bundle: .app)
        case .rooms: String(localized: "Rooms", bundle: .app)
        case .furniture: String(localized: "Furniture", bundle: .app)
        case .plants: String(localized: "Plants", bundle: .app)
        case .lighting: String(localized: "Lighting", bundle: .app)
        case .decor: String(localized: "Decorations", bundle: .app)
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
