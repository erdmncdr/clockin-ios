import Foundation

enum BadgeTier: Int, CaseIterable, Identifiable {
    case launch = 1, orbit, lunar, solar, galactic, eternal
    var id: Int { rawValue }
    var title: String { ["Launch", "Orbit", "Lunar", "Solar", "Galactic", "Eternal"][rawValue - 1] }
    var caption: String {
        ["Begin your mission", "Build your rhythm", "Go beyond the familiar", "Make your work shine", "Leave your mark", "A lifetime-class achievement"][rawValue - 1]
    }
    static func forBadge(_ id: String) -> Self {
        switch id {
        case "first", "ten", "streak", "week", "active5", "collection1", "outfits1", "home1": .launch
        case "fifty", "weekstreak", "sessions25", "marathon", "fullday", "earlybird", "nightowl", "weekend",
             "collection5", "outfits3", "home3": .orbit
        case "hundred", "quarter", "streak14", "ultra", "xp", "longday", "bigmonth", "xp25", "active25",
             "sessions50", "sessions100", "fullday7", "collection10", "outfits6", "home6": .lunar
        case "fivehundred", "sevenfifty", "monthstreak", "streak60", "active100", "sessions200", "ultra12",
             "fullday30", "bigmonth3", "xp50", "collection20", "outfits12", "home12": .solar
        case "titan", "bigmonth12", "streak365", "active500": .eternal
        default: .galactic
        }
    }
}

/// Each family has its own drawn seal and motion language.
enum BadgeMission: Int, CaseIterable {
    case flight, signal, orbit, archive, habitat, suit
    var title: String {
        ["Flight time", "Focus streak", "Active days", "Session log", "Your collection", "Personal style"][rawValue]
    }
    static func forBadge(_ id: String) -> Self {
        if id.hasPrefix("outfits") { return .suit }
        if id.hasPrefix("collection") || id.hasPrefix("home") { return .habitat }
        if id.contains("streak") { return .signal }
        if id.hasPrefix("active") || id.hasPrefix("fullday") || id.hasPrefix("bigmonth") || ["longday", "earlybird", "nightowl", "weekend"].contains(id) { return .orbit }
        if id.hasPrefix("sessions") || ["first", "week"].contains(id) { return .archive }
        return .flight
    }
}

extension InsightsBadge {
    var tier: BadgeTier { .forBadge(id) }
    var mission: BadgeMission { .forBadge(id) }
    /// Stable detail variation without randomness or per-frame hashing.
    var visualSeed: Int { id.utf8.reduce(0) { ($0 * 31 + Int($1)) % 997 } }
}
