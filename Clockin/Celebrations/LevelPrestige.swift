import Foundation

/// Cosmetic ranks advance every 75 levels. XP earning is unchanged.
struct LevelPrestige: Equatable {
    static let unlockLevels = [1, 75, 150, 225, 300, 375, 450, 525, 600]
    static let interval = 75
    let level: Int
    init(level: Int) { self.level = max(1, level) }
    var index: Int { level / Self.interval }
    /// No modulo: high ranks never fall back to the starter frame.
    var stage: Int { min(index, 8) }
    var name: String { [String(localized: "Spark"), String(localized: "Orbit"), String(localized: "Nebula"), String(localized: "Solar"), String(localized: "Nova"), String(localized: "Aurora"), String(localized: "Sovereign"), String(localized: "Celestial"), String(localized: "Eternal")][stage] }
    var symbol: String { ["sparkle", "star.circle.fill", "sparkles", "sun.max.fill", "star.fill", "crown.fill", "crown.fill", "moon.stars.fill", "diamond.fill"][stage] }
    var hue: Double { [0.44, 0.56, 0.72, 0.11, 0.94, 0.49, 0.115, 0.60, 0.12][stage] }
    var detail: String {
        [String(localized: "Polished core"), String(localized: "Cut metal frame"), String(localized: "Double rim"), String(localized: "Beveled frame"), String(localized: "Faceted frame"), String(localized: "Satin frame & halo"), String(localized: "Crowned gold frame"), String(localized: "Celestial arch"), String(localized: "Eternal crest")][stage]
    }
    var ornamentCount: Int { min(index + 1, 6) }
    var nextUnlock: Int { (index + 1) * Self.interval }
    var isMilestone: Bool { level.isMultiple(of: Self.interval) }
    var rankProgress: Double { Double(level % Self.interval) / Double(Self.interval) }
    static func progress(xp: Int) -> Double { Double(max(0, xp) % 500) / 500 }
}
