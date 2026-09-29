import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else { print("FAILED: \(message)"); exit(1) }
    checks += 1; print("ok: \(message)")
}
func isolated(_ body: (UserDefaults) -> Void) {
    let name = "Clockin.macmigration.test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    body(defaults)
}
for (old, new) in [("Glass", "glass"), ("Ping", "tiny-ping"), ("Pop", "pop"), ("Tink", "tiny-ping"),
                   ("Funk", "wood-block"), ("Submarine", "singing-bowl"), ("Sosumi", "soft-bell")] {
    isolated { defaults in
        defaults.set(old, forKey: "Clockin.ChimeSound")
        MacLegacyMigration.migrate(in: defaults)
        check(defaults.string(forKey: "Clockin.ChimeSound") == new, "\(old) maps to \(new)")
        check(defaults.string(forKey: "Clockin.Legacy.ChimeSound") == old, "\(old) kept for downgrade")
    }
}
for (old, new) in [("Month", "M"), ("7D", "W"), ("30D", "M"), ("3M", "6M"), ("ALL", "All")] {
    isolated { defaults in
        defaults.set(old, forKey: "Clockin.HistoryRange")
        MacLegacyMigration.migrate(in: defaults)
        check(defaults.string(forKey: "Clockin.HistoryRange") == new, "\(old) history maps to \(new)")
        check(defaults.string(forKey: "Clockin.Legacy.HistoryRange") == old, "\(old) history kept for downgrade")
    }
}
for (old, new) in [("Week", "Week"), ("Month", "Month"), ("All", "Day")] {
    isolated { defaults in
        defaults.set(old, forKey: "Clockin.HeatmapRange")
        MacLegacyMigration.migrate(in: defaults)
        check(defaults.string(forKey: "Clockin.InsightsHeatmapGrouping") == new, "\(old) heatmap grouping by meaning")
        check(defaults.object(forKey: "Clockin.InsightsHeatmapDayRange") as? Int == 0, "\(old) heatmap retains full archive")
        check(defaults.string(forKey: "Clockin.HeatmapRange") == old
              && defaults.string(forKey: "Clockin.Legacy.HeatmapRange") == old, "old heatmap selection preserved")
    }
}
isolated { defaults in
    MacLegacyMigration.migrate(in: defaults)
    let preferences = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("Clockin.") }
    check(Set(preferences.keys) == [MacLegacyMigration.versionKey], "fresh install only writes version marker")
    MacLegacyMigration.migrate(in: defaults)
    check(NSDictionary(dictionary: preferences).isEqual(to: defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("Clockin.") }), "fresh migration is idempotent")
}
isolated { defaults in
    for key in ["ChimeSound", "HistoryRange", "HeatmapRange"] { defaults.set("Unknown", forKey: "Clockin.\(key)") }
    MacLegacyMigration.migrate(in: defaults)
    for key in ["ChimeSound", "HistoryRange", "HeatmapRange"] {
        check(defaults.string(forKey: "Clockin.\(key)") == "Unknown"
              && defaults.string(forKey: "Clockin.Legacy.\(key)") == "Unknown", "unknown \(key) preserved")
    }
    check(defaults.object(forKey: "Clockin.InsightsHeatmapGrouping") == nil, "unknown heatmap does not invent a mapping")
}
isolated { defaults in
    defaults.set("Glass", forKey: "Clockin.ChimeSound")
    defaults.set("3M", forKey: "Clockin.HistoryRange")
    defaults.set("All", forKey: "Clockin.HeatmapRange")
    defaults.set(8.0, forKey: "Clockin.GoalDailyHours")
    defaults.set(false, forKey: "Clockin.AutoCheckUpdates")
    defaults.set(1.15, forKey: "Clockin.UIScale")
    defaults.set("Carbon", forKey: "Clockin.Theme")
    defaults.set("tr", forKey: "Clockin.Language")
    MacLegacyMigration.migrate(in: defaults)
    let once = defaults.dictionaryRepresentation()
    MacLegacyMigration.migrate(in: defaults)
    check(NSDictionary(dictionary: once).isEqual(to: defaults.dictionaryRepresentation()), "repeated run does not change any value")
    check(defaults.bool(forKey: "Clockin.HasConfiguredGoal"), "existing daily goal counts as configured")
    check(defaults.double(forKey: "Clockin.GoalDailyHours") == 8, "existing goal value unchanged")
    check(defaults.object(forKey: "Clockin.AutoCheckUpdates") as? Bool == false
          && defaults.double(forKey: "Clockin.UIScale") == 1.15, "shell-owned migrations left untouched")
    check(defaults.string(forKey: "Clockin.Theme") == "Carbon" && defaults.string(forKey: "Clockin.Language") == "tr", "theme and language kept")
    defaults.set("marimba", forKey: "Clockin.ChimeSound")
    defaults.set("W", forKey: "Clockin.HistoryRange")
    defaults.set(4, forKey: "Clockin.InsightsHeatmapDayRange")
    defaults.set("Month", forKey: "Clockin.InsightsHeatmapGrouping")
    defaults.set(0, forKey: "Clockin.GoalDailyHours")
    let changed = defaults.dictionaryRepresentation()
    MacLegacyMigration.migrate(in: defaults)
    check(NSDictionary(dictionary: changed).isEqual(to: defaults.dictionaryRepresentation()), "second run preserves user edits")
    check(defaults.string(forKey: "Clockin.Legacy.ChimeSound") == "Glass"
          && defaults.string(forKey: "Clockin.Legacy.HistoryRange") == "3M", "user edits do not replace downgrade copies")
    check(defaults.bool(forKey: "Clockin.HasConfiguredGoal"), "clearing migrated goal does not reopen onboarding")
}
isolated { defaults in
    defaults.set(120, forKey: "Clockin.GoalMonthlyHours")
    MacLegacyMigration.migrate(in: defaults)
    check(defaults.bool(forKey: "Clockin.HasConfiguredGoal"), "monthly-only goal counts as configured")
}
isolated { defaults in
    defaults.set("Week", forKey: "Clockin.HeatmapRange")
    defaults.set("Month", forKey: "Clockin.InsightsHeatmapGrouping")
    defaults.set(4, forKey: "Clockin.InsightsHeatmapDayRange")
    defaults.set("marimba", forKey: "Clockin.ChimeSound")
    defaults.set("6M", forKey: "Clockin.HistoryRange")
    MacLegacyMigration.migrate(in: defaults)
    check(defaults.string(forKey: "Clockin.InsightsHeatmapGrouping") == "Month"
          && defaults.integer(forKey: "Clockin.InsightsHeatmapDayRange") == 4, "existing new heatmap preferences win")
    check(defaults.string(forKey: "Clockin.ChimeSound") == "marimba"
          && defaults.string(forKey: "Clockin.HistoryRange") == "6M", "already-modern preferences preserved")
    check(defaults.object(forKey: "Clockin.Legacy.ChimeSound") == nil
          && defaults.object(forKey: "Clockin.Legacy.HistoryRange") == nil, "modern preferences not mislabeled legacy")
}
print("\(checks) macmigration checks passed")
