import Foundation

/// Call before constructing views, chime controllers or celebration state.
enum MacLegacyMigration {
    static let versionKey = "Clockin.MacMigration.v2"

    static func migrate(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: versionKey) else { return }
        if let old = defaults.string(forKey: FocusChimeSound.preferenceKey),
           FocusChimeSound(rawValue: old) == nil {
            keep(old, as: "ChimeSound", in: defaults)
            if let sound = chime(old) { defaults.set(sound.rawValue, forKey: FocusChimeSound.preferenceKey) }
        }
        if let old = defaults.string(forKey: "Clockin.HistoryRange"),
           !["M", "W", "6M", "All"].contains(old) {
            keep(old, as: "HistoryRange", in: defaults)
            let ranges = ["Month": "M", "7D": "W", "30D": "M", "3M": "6M", "ALL": "All"]
            if let range = ranges[old] { defaults.set(range, forKey: "Clockin.HistoryRange") }
        }
        if let old = defaults.string(forKey: "Clockin.HeatmapRange") {
            keep(old, as: "HeatmapRange", in: defaults)
            let groups = ["Week": "Week", "Month": "Month", "All": "Day"]
            if let grouping = groups[old] {
                if defaults.object(forKey: "Clockin.InsightsHeatmapGrouping") == nil {
                    defaults.set(grouping, forKey: "Clockin.InsightsHeatmapGrouping")
                }
                // Every old aggregation covered the whole archive.
                if defaults.object(forKey: "Clockin.InsightsHeatmapDayRange") == nil {
                    defaults.set(0, forKey: "Clockin.InsightsHeatmapDayRange")
                }
            }
        }
        if defaults.double(forKey: "Clockin.GoalDailyHours") > 0
            || defaults.double(forKey: "Clockin.GoalMonthlyHours") > 0 {
            defaults.set(true, forKey: "Clockin.HasConfiguredGoal")
        }
        // Queue and wardrobe seed from the loaded archive on their first refresh.
        defaults.set(true, forKey: versionKey)
    }

    private static func keep(_ value: String, as name: String, in defaults: UserDefaults) {
        let key = "Clockin.Legacy.\(name)"
        if defaults.object(forKey: key) == nil { defaults.set(value, forKey: key) }
    }

    private static func chime(_ name: String) -> FocusChimeSound? {
        switch name {
        case "Glass": .glass          // Bright glass strike with a ringing tail.
        case "Ping": .tinyPing        // Short, high-pitched single ping.
        case "Pop": .pop              // Brief, rounded pop with little sustain.
        case "Tink": .tinyPing        // Tiny, bright metallic tap.
        case "Funk": .woodBlock       // Low, short percussive knock.
        case "Submarine": .singingBowl // Soft, low resonant tone with a longer tail.
        case "Sosumi": .softBell       // Rounded, mellow struck tone.
        default: nil                  // Preserve unsupported choices for review/downgrade.
        }
    }
}
