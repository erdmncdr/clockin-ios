import Foundation

enum FocusChimeSound: String, CaseIterable, Identifiable {
    case softBell = "soft-bell"
    case glass
    case marimba
    case chime
    case pop
    case woodBlock = "wood-block"
    case singingBowl = "singing-bowl"
    case tinyPing = "tiny-ping"

    static let defaultSound: Self = .chime
    static let preferenceKey = "Clockin.ChimeSound"
    var id: String { rawValue }
    var fileName: String { "clockin-\(rawValue).caf" }
    var displayName: String {
        switch self {
        case .softBell: String(localized: "Soft Bell")
        case .glass: String(localized: "Glass")
        case .marimba: String(localized: "Marimba")
        case .chime: String(localized: "Chime")
        case .pop: String(localized: "Pop")
        case .woodBlock: String(localized: "Wood Block")
        case .singingBowl: String(localized: "Singing Bowl")
        case .tinyPing: String(localized: "Tiny Ping")
        }
    }

    static func selected(_ stored: String?) -> Self {
        if stored == "Glass" { return .glass }
        return stored.flatMap(Self.init(rawValue:)) ?? defaultSound
    }

    @discardableResult
    static func migrate(in defaults: UserDefaults = .standard) -> Self {
        let stored = defaults.string(forKey: preferenceKey)
        let sound = selected(stored)
        if stored != sound.rawValue { defaults.set(sound.rawValue, forKey: preferenceKey) }
        return sound
    }
}

enum FocusChimeVolume {
    static let preferenceKey = "Clockin.ChimeVolume"
    static let defaultValue = 0.75
    static let range = 0.1...1.0

    static func clamped(_ stored: Double?) -> Double {
        guard let stored, stored.isFinite else { return defaultValue }
        return min(range.upperBound, max(range.lowerBound, stored))
    }

    static func selected(in defaults: UserDefaults = .standard) -> Double {
        clamped(defaults.object(forKey: preferenceKey) as? Double)
    }
}
