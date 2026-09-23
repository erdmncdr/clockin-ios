import Foundation

enum CompanionAccessory: String, CaseIterable, Identifiable, Sendable {
    case headphones, mug, cape, antenna

    static let storageKey = "Clockin.CompanionAccessory"
    static let seenKey = "Clockin.SeenAccessoryIDs"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .headphones: String(localized: "Headphones")
        case .mug: String(localized: "Mug")
        case .cape: String(localized: "Cape")
        case .antenna: String(localized: "Gold antenna")
        }
    }
    var symbol: String {
        switch self {
        case .headphones: "headphones"
        case .mug: "cup.and.saucer.fill"
        case .cape: "tshirt.fill"
        case .antenna: "antenna.radiowaves.left.and.right"
        }
    }
    var frame: String { "acc-" + rawValue }
    var requiredHours: Double {
        switch self {
        case .headphones: 25
        case .mug: 50
        case .cape: 100
        case .antenna: 250
        }
    }
    func isUnlocked(totalHours: Double) -> Bool { totalHours >= requiredHours }
    func menuLabel(totalHours: Double) -> String {
        isUnlocked(totalHours: totalHours) ? name : String(localized: "🔒 \(name) · \(Int(requiredHours))h")
    }
    func progressText(totalHours: Double) -> String {
        guard !isUnlocked(totalHours: totalHours) else { return String(localized: "Unlocked") }
        let hours = totalHours.isFinite ? max(0, totalHours) : 0
        let minutes = Int(ceil(max(0, requiredHours - hours) * 60 - 1e-9))
        return String(localized: "\(minutes / 60)h \(minutes % 60)m to go")
    }
    static func selection(_ stored: String, totalHours: Double) -> String {
        if stored == "None" { return stored }
        guard let accessory = Self(rawValue: stored), accessory.isUnlocked(totalHours: totalHours) else { return "Auto" }
        return stored
    }
    static func resolve(_ stored: String, totalHours: Double) -> Self? {
        let choice = selection(stored, totalHours: totalHours)
        if choice == "None" { return nil }
        if choice == "Auto" { return allCases.last { $0.isUnlocked(totalHours: totalHours) } }
        return Self(rawValue: choice)
    }

    // Tek karelik aksesuar cizimleri kliplere ve ziplamalara uygulanmaz.
    static func displayFrame(_ frame: String, helloRest: Bool, performingEvent: Bool, accessory: Self?) -> String {
        helloRest && !performingEvent ? (accessory?.frame ?? frame) : frame
    }
}
