// swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-share-module-cache Shared/Core/AppLanguage.swift Clockin/Views/Share/ShareStatsFields.swift Clockin/Views/Share/LevelShareLayout.swift Tests/manual/share/main.swift -o /tmp/clockin-share-checks && /tmp/clockin-share-checks
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
check(rows(.milestones, .privateStats).map(\.field) == [.level, .xp, .badges, .fullDays, .longDays, .bigMonths, .momentum],
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

// The level-up picture: a story or a post, rendered at 3x.
check(LevelShareFormat.story.size.width == 360 && LevelShareFormat.story.size.height == 640 && LevelShareFormat.post.size.width == 360 && LevelShareFormat.post.size.height == 450,
      "story is 9:16 and post is 4:5")
check(LevelShareLayout.showsCompanion(.story, enabled: true) && !LevelShareLayout.showsCompanion(.post, enabled: true)
      && !LevelShareLayout.showsCompanion(.story, enabled: false), "the companion stands only on the story, when enabled")
check(LevelShareLayout.stageHeight(.story, companion: true) == 396 && LevelShareLayout.stageHeight(.story, companion: false) == 300
      && LevelShareLayout.stageHeight(.post, companion: true) == 300, "the stage keeps the card's heights")
check(!LevelShareLayout.showsStreak(1) && LevelShareLayout.showsStreak(2), "a streak shows from two days")
let taken = LevelShareSnapshot(level: 75, hours: 370, xp: 37_180, streak: 9, date: .now, companion: true)
check(taken.level == 75 && taken.hours == 370 && taken != LevelShareSnapshot(level: 75, hours: 370, xp: 37_180, streak: 9, date: taken.date, companion: true),
      "each press takes its own snapshot")
print("\(checks) share checks passed (level card)")
