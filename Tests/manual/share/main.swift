// swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-share-module-cache iOS/Clockin/Views/Share/ShareStatsFields.swift iOS/Tests/manual/share/main.swift -o /tmp/clockin-share-checks && /tmp/clockin-share-checks
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

let values = Dictionary(uniqueKeysWithValues: StatsShareField.allCases.map { ($0, "value:\($0.rawValue)") })
func rows(_ page: StatsSharePage, _ privacy: StatsSharePrivacy) -> [StatsShareRow] {
    StatsShareFields.rows(page: page, privacy: privacy, values: values)
}
check(rows(.overview, .publicStats).map(\.field) == [.time, .earnings, .sessions, .activeDays, .streak],
      "Public overview matches Mac fields")
check(rows(.overview, .privateStats).map(\.field) == [.streak, .badges, .xp],
      "Private overview matches Mac fields")
check(rows(.rhythm, .publicStats).map(\.field) == [.bestDay, .longestStreak, .activeDays, .weekday, .hour, .sessions],
      "Rhythm keeps date, streak, active days, weekday, hour and sessions")
check(rows(.rhythm, .privateStats).first?.value == values[.bestDay], "Private best day contains date only")
check(rows(.rhythm, .publicStats).first?.value == "value:Best day • value:Best day duration",
      "Public best day includes duration")
check(rows(.milestones, .privateStats) == rows(.milestones, .publicStats), "Privacy preserves every milestone")
check(rows(.milestones, .privateStats).map(\.field) == [.level, .xp, .badges, .goalDays, .doubleGoalDays, .goalMonths, .momentum],
      "Milestones include all Mac fields")
// Tum sayfalarda gizlilik siniri korunmali; yalniz genel bakisi sinamak yeterli degil.
for page in StatsSharePage.allCases {
    let privateRows = rows(page, .privateStats)
    for field in [StatsShareField.time, .earnings, .bestDayDuration] {
        check(!privateRows.contains { $0.value.contains(values[field]!) }, "\(page.rawValue) omits \(field.rawValue)")
    }
    check(StatsShareMode.current.pages(current: page) == [page], "Current exports only \(page.rawValue)")
    check(StatsShareMode.all.pages(current: page) == [.overview, .rhythm, .milestones],
          "All 3 keeps page order from \(page.rawValue)")
}
for privacy in StatsSharePrivacy.allCases {
    let empty = StatsShareFields.rows(page: .rhythm, privacy: privacy, values: [:])
    check(empty.first?.value == "No sessions", "\(privacy.rawValue) has an empty best-day fallback")
    let durationOnly = StatsShareFields.rows(page: .rhythm, privacy: privacy, values: [.bestDayDuration: "8h"])
    check(durationOnly.first?.value == "No sessions", "\(privacy.rawValue) never invents a best day")
}
check(rows(.overview, .publicStats) == rows(.overview, .publicStats), "Repeated selection is deterministic")
print("\(checks) share checks passed")
