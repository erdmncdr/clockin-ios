import Foundation

enum AppGroup { static let snapshotURL = URL(fileURLWithPath: "/tmp/unused-clockin24-snapshot.json") }
var checks = 0
@MainActor func check(_ value: Bool, _ message: String) {
    guard value else { print("FAIL \(message)"); exit(1) }
    checks += 1; print("ok \(message)")
}
let now = Date(timeIntervalSince1970: 1_800_000_000)
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
let session = WorkSession(id: UUID(), start: now - 3600, end: now, duration: 3600,
                          note: "first", hourlyRate: 25, source: "Clockin")
var duplicate = session; duplicate.note = "conflicting copy"; duplicate.hourlyRate = 50
let snapshot = EarningsSnapshot(sessions: [session, duplicate], running: nil, range: .all,
    now: now, calendar: calendar, earnings: { $0.earnings }, activeEarnings: 0, rate: { _ in 30 })
check(snapshot.sessions.count == 2 && snapshot.earned == 75, "duplicate IDs cannot trap or lose money in an in-memory earnings projection")
let insights = InsightsSnapshot(sessions: [session], sessionEarnings: [:], now: now, calendar: calendar)
check(insights.totalEarnings == 25, "missing rate-resolved earnings fall back to the session's stored rate")
var bad = session; bad.end = bad.start - 1
check(InsightsSnapshot(sessions: [bad], sessionEarnings: [:], now: now, calendar: calendar).sessionCount == 0,
      "reversed session cannot enter calendar or XP aggregation")
check(!SessionOverlap.intersects(session, bad), "reversed intervals do not overlap")
var data = ClockinData(); data.sessions = [session, duplicate, bad]
let encoded = try JSONEncoder().encode(data)
let archive = try ClockinArchive.read(encoded, at: now)
check(archive.data.sessions == [session] && archive.rejectedCount == 2, "archive retains the first valid ID and quarantines duplicate and reversed rows")
check(archive.quarantine.map { String(decoding: $0, as: UTF8.self).contains("conflicting copy") } == true,
      "duplicate conflict bytes remain available for recovery")
for value in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -.greatestFiniteMagnitude, Double(Int.max), Double(Int.min)] {
    let result = Int(clampingFinite: value)
    check(value.isNaN ? result == 0 : value > 0 ? result == .max : result == .min, "safe integer conversion: \(value)")
    let text = DurationText.clock(value)
    check(!text.isEmpty, "duration rendering survives \(value)")
    let progress = MenuBarStatus.goalPercent(value, goal: .leastNonzeroMagnitude)
    check((0...999).contains(progress), "menu-bar percentage clamps before integer conversion: \(value)")
    check(EarningsChartAxis.earningsUpperBound(value).isFinite, "chart bounds remain finite: \(value)")
}
check(GoalProgress(worked: 0, hours: .greatestFiniteMagnitude) == nil, "overflowing goal seconds are rejected")
let tinyPace = InsightsGoalEstimate.make(dailyGoal: 0, monthlyGoal: 100,
    todayDuration: 0, monthDuration: 0, recentCompleted: .leastNormalMagnitude,
    running: nil, now: now, calendar: calendar)
check(tinyPace.monthly == .workDays(Int.max, fitsInMonth: false), "tiny nonzero pace cannot overflow days-to-go")
check(LevelPrestige(level: Int.max).nextUnlock == Int.max, "largest cosmetic level cannot overflow next unlock")
check(PastedTextImporter.approvedSummaryDuration(in: "9223372036854775807h 59m Approved") == nil,
      "pasted Int.max hours cannot overflow integer multiplication")
check(PastedTextImporter.approvedSummaryDuration(in: "2h 30m Approved") == 9000, "normal pasted totals remain exact")
for zone in ["America/New_York", "Europe/Berlin", "Pacific/Apia"] {
    calendar.timeZone = TimeZone(identifier: zone)!
    for parts in [DateComponents(year: 2026, month: 3, day: 8, hour: 22), DateComponents(year: 2026, month: 11, day: 1, hour: 22)] {
        let start = calendar.date(from: parts)!
        let early = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: start)!
        let end = EntryTimes.end(start: start, end: early, calendar: calendar)
        check(end > start, "overnight session advances a calendar day: \(zone)")
        let week = MonthWeek.interval(containing: start, calendar: calendar)
        check(week.end >= week.start && week.contains(start), "week bounds survive DST: \(zone)")
        let period = EarningsPeriod(range: .month, anchor: start, now: start, calendar: calendar)
        let empty = EarningsSnapshot(sessions: [], running: nil, range: .month, now: start, calendar: calendar,
            period: period, earnings: { $0.earnings }, activeEarnings: 0, rate: { _ in nil })
        let performance = MonthPerformance(snapshot: empty, period: period, sessions: [], monthlyGoal: 100,
                                          now: start - 86400 * 90, calendar: calendar)
        check(performance.comparisonInterval.duration >= 0, "future month under a backward clock cannot create reversed DateInterval: \(zone)")
    }
}
let longHistory: [Date: TimeInterval] = [.distantPast: 3600, now: 3600]
let weeks = InsightsPeriods.dayWeeks(daily: longHistory, now: now, range: Int.max, calendar: calendar)
check(weeks.count <= InsightsPeriods.maximumBuckets && !weeks.isEmpty, "huge saved heatmap range is bounded")
let buckets = InsightsPeriods.buckets(daily: longHistory, earnings: [:], grouping: .day, now: now, calendar: calendar)
check(buckets.count <= InsightsPeriods.maximumBuckets, "centuries of empty calendar cells cannot grow without a bound")
for grouping in InsightsGrouping.allCases {
    let bounded = InsightsPeriods.buckets(daily: longHistory, earnings: [:], grouping: grouping, now: now, calendar: calendar)
    check(bounded.count <= InsightsPeriods.maximumBuckets && bounded.last.map { $0.start <= now && $0.end > now } == true,
          "bounded \(grouping) history always retains the current bucket")
}
let desired = Array(repeating: now, count: 100)
let chime = ChimeSchedule.reconcile(desired: desired, existing: [-1: now, Int.max: now])
check(chime.additions.count <= ChimeSchedule.maximumCount, "repeated notification dates keep bounded unique slot keys")
var corrupt = ClockinSnapshot.empty; corrupt.day = Date(timeIntervalSinceReferenceDate: 1e100)
let corruptBytes = try JSONEncoder().encode(corrupt)
check((try? JSONDecoder().decode(ClockinSnapshot.self, from: corruptBytes)) == nil, "invalid persisted widget date is rejected before timer construction")
let timer = LiveTimerRange.interval(from: Date(timeIntervalSinceReferenceDate: .nan), at: now)
check(timer.lowerBound <= timer.upperBound, "timer range is safe even with a nonfinite origin")
check(!CloudSyncCapability.permits(containers: nil, services: ["CloudKit"]), "missing container entitlement disables sync")
check(!CloudSyncCapability.permits(containers: [CloudSyncCapability.containerID], services: nil), "missing CloudKit service disables sync")
check(CloudSyncCapability.permits(containers: [CloudSyncCapability.containerID], services: ["CloudKit"]), "matching signed capabilities allow sync")
for size in 0..<128 {
    check(CloudSyncCapability.signedEntitlements(in: Data(repeating: 255, count: size)) == nil, "truncated signature length \(size) is rejected safely")
}
// Gercek XML yetki blogu tasiyan kucuk arm64 Mach-O ornegi.
func word(_ n: Int, big: Bool = false) -> Data {
    let v = UInt32(n)
    return Data((big ? [24,16,8,0] : [0,8,16,24]).map { UInt8(truncatingIfNeeded: v >> $0) })
}
let xml = try PropertyListSerialization.data(fromPropertyList: ["com.apple.developer.icloud-container-identifiers": [CloudSyncCapability.containerID], "com.apple.developer.icloud-services": ["CloudKit"]], format: .xml, options: 0)
let length = 28 + xml.count
var macho = word(0xfeedfacf) + Data(repeating: 0, count: 12) + word(1) + word(16) + Data(repeating: 0, count: 8)
macho += word(0x1d) + word(16) + word(48) + word(length)
macho += word(0xfade0cc0, big: true) + word(length, big: true) + word(1, big: true) + word(5, big: true) + word(20, big: true)
macho += word(0xfade7171, big: true) + word(8 + xml.count, big: true) + xml
check(CloudSyncCapability.signedEntitlements(in: macho)?["com.apple.developer.icloud-services"] as? [String] == ["CloudKit"], "iOS signed executable entitlement parser accepts valid XML slot")
for offset in [16,20,36,40,44,52,56,64,72] {
    var malformed = macho; malformed.replaceSubrange(offset..<(offset+4), with: Data(repeating: 255, count: 4))
    check(CloudSyncCapability.signedEntitlements(in: malformed) == nil, "malformed signature offset/size \(offset) is rejected")
}
print("All \(checks) crash audit checks passed.")
