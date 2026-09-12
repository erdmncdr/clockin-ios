// swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-insights-module-cache iOS/Shared/Core/Models.swift iOS/Clockin/Views/Insights/InsightsSnapshot.swift iOS/Clockin/Views/Insights/InsightsBadges.swift iOS/Clockin/Views/Insights/InsightsPeriods.swift iOS/Tests/manual/insights/main.swift -o /tmp/clockin-insights-tests && /tmp/clockin-insights-tests
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1; print("ok: \(name)")
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
calendar.firstWeekday = 2
@MainActor func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}
@MainActor func session(_ start: Date, _ hours: Double) -> WorkSession {
    WorkSession(id: UUID(), start: start, end: start.addingTimeInterval(hours * 3600),
                duration: hours * 3600, note: "", hourlyRate: 40, source: "Clockin")
}
let now = date(9, 13, 12)
@MainActor func snapshot(_ sessions: [WorkSession] = [], running: RunningSession? = nil,
                         daily: Double = 0, monthly: Double = 0) -> InsightsSnapshot {
    InsightsSnapshot(sessions: sessions, running: running, runningEarnings: (running?.elapsed(at: now) ?? 0) / 3600 * 40,
                     now: now, calendar: calendar, dailyGoal: daily, monthlyGoal: monthly)
}
let empty = snapshot()
check(empty.totalDuration == 0 && empty.averageSession == 0 && empty.hourlyEarnings == 0 && empty.monthTrend == 0, "empty report metrics are zero")
check(empty.bestWeekday == nil && empty.bestStartHour == nil && empty.bestDay == nil, "empty records are absent")
check(empty.badges.count == 46 && Set(empty.badges.map(\.id)).count == 46 && empty.badges.allSatisfy { !$0.unlocked }, "46 unique badges, all locked in empty archive")
check(empty.goalEstimate == InsightsGoalEstimate(), "no goals means no estimate lines")
check(snapshot(daily: 1).goalEstimate.daily == .startNow(date(9, 13, 13)), "idle daily goal says when starting now would reach it")
check(snapshot(monthly: 20).goalEstimate.daily == .off && snapshot(monthly: 20).goalEstimate.monthly == .unavailable,
      "monthly goal with no recent work has no average to estimate from")

let sunday = session(date(9, 13, 10), 2)
let monday = session(date(9, 7, 8), 2)
for records in [[sunday, monday], [monday, sunday]] {
    let value = snapshot(records)
    check(value.bestWeekday == 1 && value.bestStartHour == 8, "ties use lowest weekday and hour regardless of input order")
    check(value.bestDay == date(9, 7) && value.bestDayDuration == 7200, "best-day ties choose earliest completed day")
}
let multiple = snapshot([session(date(9, 7, 8), 2), session(date(9, 7, 14), 3), sunday])
check(multiple.bestWeekday == 2 && multiple.bestDayDuration == 18000 && multiple.averageSession == 8400, "reports sum duration by weekday and completed day")
let overnight = snapshot([session(date(8, 31, 23), 2), session(date(9, 1), 1)])
check(overnight.daily[date(8, 31)] == 7200 && overnight.daily[date(9, 1)] == 3600, "cross-midnight sessions stay on start day")
let active = RunningSession(start: date(9, 13, 11), accumulated: 0, resumedAt: date(9, 13, 11), note: "")
let live = snapshot([session(date(9, 12, 10), 2)], running: active, daily: 2)
check(live.totalDuration == 10800 && live.averageSession == 7200 && live.bestDayDuration == 7200, "running work contributes to totals but not completed reports")
check(live.hourlyEarnings == 30 && live.recentMonth == 7200, "hourly earnings includes active earnings while trend excludes active work")
check(live.goalEstimate.daily == .finish(date(9, 13, 13)), "running ETA adds only remaining daily work")
check(snapshot(running: active, daily: 1).goalEstimate.daily == .reached, "goal met exactly takes precedence over running ETA")
check(snapshot(running: active, daily: 0.5).goalEstimate.daily == .reached, "exceeded goal never estimates a past finish")
check(snapshot(running: active).badges.first { $0.id == "first" }?.unlocked == true, "Mac first-session badge includes positive running work")
let paused = RunningSession(start: active.start, accumulated: 3600, resumedAt: nil, note: "")
check(snapshot(running: paused, daily: 2).goalEstimate.daily == .startNow(date(9, 13, 13)),
      "paused work counts toward today and resuming now gives the finish time")
let previousNight = RunningSession(start: date(9, 12, 23), accumulated: 0, resumedAt: date(9, 12, 23), note: "")
check(snapshot(running: previousNight, daily: 1).goalEstimate.daily == .finish(date(9, 13, 13)), "overnight active work stays on yesterday for today's ETA")
// Aylik: 13 Eylul'de bu ay 14 saat var; son 7 gunde 14 saat, gunde 2 saat.
let sevenCutoff = now.addingTimeInterval(-7 * 86400)
let monthWork = [session(date(9, 8, 9), 7), session(date(9, 9, 9), 7)]
check(snapshot(monthWork, monthly: 20).goalEstimate.monthly == .workDays(3, fitsInMonth: true),
      "monthly goal: six hours left at two hours a day is three work days")
check(snapshot(monthWork, monthly: 100).goalEstimate.monthly == .workDays(43, fitsInMonth: false),
      "a monthly goal the month cannot hold at this pace says so")
check(snapshot(monthWork, monthly: 14).goalEstimate.monthly == .reached, "monthly goal met exactly is reached")
check(snapshot([session(sevenCutoff, 7)], monthly: 20).goalEstimate.monthly == .workDays(13, fitsInMonth: true),
      "seven-day average includes the exact cutoff")
check(snapshot([session(sevenCutoff.addingTimeInterval(-1), 7)], monthly: 20).goalEstimate.monthly == .unavailable,
      "seven-day average excludes one second before the cutoff")
// Mac'in gunluk hedef icin gun sayisi verdigi durum artik saat verir.
check(snapshot(monthWork, daily: 1).goalEstimate.daily == .startNow(date(9, 13, 13)),
      "a daily goal never turns into a number of days")
// 30 gun takvim gunudur, bugun dahil: History'deki 30D ile ayni gunler.
let todayStart = calendar.startOfDay(for: now)
let cutoff30 = calendar.date(byAdding: .day, value: -29, to: todayStart)!
let cutoff60 = calendar.date(byAdding: .day, value: -59, to: todayStart)!
let trend = snapshot([session(cutoff30, 2), session(cutoff30.addingTimeInterval(-1), 3), session(cutoff60, 1), session(cutoff60.addingTimeInterval(-1), 8)])
check(trend.recentMonth == 7200 && trend.previousMonth == 14400 && trend.monthTrend == -0.5, "30-day windows start at local midnight of calendar days, today included")
// Gece yarisindan az sonra, otuz bir gun onceki gunun aksami son 30 gune girmemeli.
let lateEvening = calendar.date(byAdding: .hour, value: -3, to: cutoff30)!
check(snapshot([session(lateEvening, 5)]).recentMonth == 0, "the evening before the window is not counted as recent, whatever the time of day")
check(snapshot([sunday]).monthTrend == 1, "positive recent work with no prior work has 100 percent trend")
let priced = InsightsSnapshot(sessions: [sunday], sessionEarnings: [sunday.id: 100], now: now, calendar: calendar)
check(priced.totalEarnings == 100 && priced.hourlyEarnings == 50, "store-resolved earnings override session's saved rate")

// Her esik ayri sinanir; tek buyuk arsiv yanlis dusuk esikleri gizleyebilir.
let integerThresholds: [(String, WritableKeyPath<InsightsSnapshot, Int>, Int)] = [
    ("streak", \.currentStreak, 3), ("weekstreak", \.currentStreak, 7), ("monthstreak", \.currentStreak, 30),
    ("streak14", \.longestStreak, 14), ("streak60", \.longestStreak, 60), ("streak90", \.longestStreak, 90),
    ("streak180", \.longestStreak, 180), ("streak365", \.longestStreak, 365),
    ("week", \.sessionCount, 7), ("sessions25", \.sessionCount, 25), ("sessions50", \.sessionCount, 50),
    ("sessions100", \.sessionCount, 100), ("sessions200", \.sessionCount, 200), ("sessions500", \.sessionCount, 500),
    ("xp", \.baseXP, 10000), ("xp25", \.baseXP, 25000), ("xp50", \.baseXP, 50000), ("xp100", \.baseXP, 100000),
    ("fullday", \.fullDays, 1), ("fullday7", \.fullDays, 7), ("fullday30", \.fullDays, 30),
    ("longday", \.longDays, 1), ("bigmonth", \.bigMonths, 1), ("bigmonth3", \.bigMonths, 3), ("bigmonth12", \.bigMonths, 12),
    ("earlybird", \.earlyBirdSessions, 5), ("nightowl", \.nightOwlSessions, 5), ("weekend", \.weekendDays, 4)
]
@MainActor func unlocked(_ value: InsightsSnapshot, _ id: String) -> Bool { value.badges.first { $0.id == id }?.unlocked == true }
for (id, key, threshold) in integerThresholds {
    var value = empty
    value[keyPath: key] = threshold - 1
    check(!unlocked(value, id), "\(id) locked below threshold")
    value[keyPath: key] = threshold
    check(unlocked(value, id), "\(id) unlocked exactly at threshold")
}
let hourThresholds: [(String, Double)] = [("ten", 10), ("fifty", 50), ("hundred", 100), ("quarter", 250), ("fivehundred", 500), ("sevenfifty", 750), ("thousand", 1000), ("titan", 1500)]
let sessionThresholds: [(String, Double)] = [("marathon", 4), ("ultra", 8), ("ultra12", 12), ("ultra15", 15)]
for (key, thresholds) in [(\InsightsSnapshot.totalDuration, hourThresholds), (\InsightsSnapshot.longestSession, sessionThresholds)] {
    for (id, hours) in thresholds {
        var value = empty
        value[keyPath: key] = hours * 3600 - 1
        check(!unlocked(value, id), "\(id) locked one second below threshold")
        value[keyPath: key] += 1
        check(unlocked(value, id), "\(id) unlocked exactly at hour threshold")
    }
}
for (id, count) in [("active5", 5), ("active25", 25), ("active100", 100), ("active250", 250), ("active500", 500)] {
    var value = empty
    for offset in 0..<(count - 1) { value.daily[now.addingTimeInterval(Double(offset) * 86400)] = 3600 }
    check(!unlocked(value, id), "\(id) locked one day below threshold")
    value.daily[now.addingTimeInterval(Double(count) * 86400)] = 3600
    check(unlocked(value, id), "\(id) unlocked exactly at active-day threshold")
}
// Seviye hile ile sisirilemez: hedef ne olursa olsun XP ve rozetler ayni.
let work = [session(date(9, 12), 2), session(date(9, 13), 2)]
let noGoals = snapshot(work)
for (daily, monthly) in [(0.1, 0.1), (1.0, 4.0), (24.0, 744.0)] {
    let withGoals = snapshot(work, daily: daily, monthly: monthly)
    check(withGoals.xp == noGoals.xp && withGoals.level == noGoals.level,
          "goals of \(daily)h a day and \(monthly)h a month do not change XP or level")
    check(withGoals.badges.map(\.unlocked) == noGoals.badges.map(\.unlocked),
          "goals of \(daily)h a day and \(monthly)h a month do not unlock badges")
}
check(noGoals.xp == 400, "XP is 100 per hour plus streak bonuses and nothing else")
// Sabit esikler: tam sinirda sayilir.
let fullDay = snapshot([session(date(9, 10, 8), 8), session(date(9, 11, 8), 7.99), session(date(9, 12, 8), 10)])
check(fullDay.fullDays == 2 && fullDay.longDays == 1, "8-hour and 10-hour days count at exactly the threshold")
let bigMonth = snapshot((1...10).map { session(date(8, $0, 8), 10) } + [session(date(9, 1, 8), 9)])
check(bigMonth.bigMonths == 1, "a calendar month counts once it holds 100 hours")
let streakRecords = (0..<14).map { session(calendar.date(byAdding: .day, value: -$0, to: date(9, 1))!, 1) }
let oldStreak = snapshot(streakRecords)
check(oldStreak.currentStreak == 0 && oldStreak.longestStreak == 14 && oldStreak.streakXP == 850, "historical longest streak retains cumulative bonuses")
check(unlocked(oldStreak, "streak14") && !unlocked(oldStreak, "streak"), "current streak badges relock independently of record badges")
let starts = snapshot((0..<5).flatMap { _ in [session(date(9, 12, 7, 59), 1), session(date(9, 12, 22), 1), session(date(9, 13, 8), 1), session(date(9, 13, 21, 59), 1)] })
check(starts.earlyBirdSessions == 5 && starts.nightOwlSessions == 5 && starts.weekendDays == 2, "early starts exclude 08:00, late starts include 22:00, weekends count unique days")

let daily: [Date: TimeInterval] = [date(8, 30): 3600, date(8, 31): 7200, date(9, 1): 3600, date(9, 7): 10800]
let earnings: [Date: Double] = [date(8, 30): 10, date(8, 31): 20, date(9, 1): 10, date(9, 7): 60]
let weeks = InsightsPeriods.buckets(daily: daily, earnings: earnings, grouping: .week, now: now, calendar: calendar)
check(weeks.map(\.start) == [date(8, 24), date(8, 31), date(9, 7)], "weeks start Monday across month edge")
check(weeks.map(\.duration) == [3600, 10800, 10800] && weeks.map(\.earnings) == [10, 30, 60], "weekly cells aggregate full calendar weeks")
check(weeks[1].intensity == 0.625 && weeks[2].intensity == 1, "relative earnings, not hours, determine aggregate color")
let months = InsightsPeriods.buckets(daily: daily, earnings: earnings, grouping: .month, now: now, calendar: calendar)
check(months.map(\.start) == [date(8, 1), date(9, 1)] && months.map(\.earnings) == [30, 70], "midnight month boundary belongs to new month")
check(months[0].end == date(9, 1) && months[1].end == date(10, 1), "month end is exclusive")
let liveBuckets = InsightsPeriods.buckets(daily: live.daily, earnings: live.dailyEarnings, grouping: .week, now: now, calendar: calendar)
check(liveBuckets.last?.duration == 10800 && liveBuckets.last?.earnings == 90, "aggregate cells include running work and earnings")
let blanks = InsightsPeriods.buckets(daily: [date(7, 1): 3600], earnings: [:], grouping: .month, now: now, calendar: calendar)
check(blanks.count == 3 && blanks[1].duration == 0 && blanks[1].intensity == 0, "empty intervening months stay visible")
check(InsightsPeriods.buckets(daily: [:], earnings: [:], grouping: .week, now: now, calendar: calendar).count == 1, "empty archive shows current empty period")
check(InsightsPeriods.dayWeeks(daily: daily, now: now, range: 4, calendar: calendar).count == 4 && InsightsPeriods.dayWeeks(daily: daily, now: now, range: 12, calendar: calendar).count == 12, "existing day ranges remain four and twelve weeks")
check(InsightsPeriods.dayWeeks(daily: daily, now: now, range: 0, calendar: calendar).first == date(8, 24), "all-day range includes earliest week")
let converted = months[1].conversion(currencyCode: "USD", startRate: 30, latestRate: 40)
check(converted?.earnings == 2100 && converted?.usedLatest == false, "period start rate beats latest rate")
check(months[1].conversion(currencyCode: "USD", startRate: nil, latestRate: 40)?.earnings == 2800, "missing period start rate falls back to latest")
check(months[1].conversion(currencyCode: "USD", startRate: nil, latestRate: nil) == nil && months[1].conversion(currencyCode: "EUR", startRate: 30, latestRate: 40) == nil, "missing rates and non-USD accounts do not invent TRY amounts")
var dstCalendar = calendar
dstCalendar.timeZone = TimeZone(identifier: "America/New_York")!
let dstStart = dstCalendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
let dstNow = dstCalendar.date(from: DateComponents(year: 2026, month: 3, day: 9))!
let dstPeriods = InsightsPeriods.buckets(daily: [dstStart: 3600], earnings: [:], grouping: .week, now: dstNow, calendar: dstCalendar)
check(dstPeriods[0].end == dstNow && dstPeriods[0].end.timeIntervalSince(dstStart) == 167 * 3600, "DST week uses calendar boundaries rather than fixed seconds")
let hourWinner = snapshot([session(date(9, 7, 9), 2), session(date(9, 8, 9), 2), session(date(9, 9, 14), 3)])
check(hourWinner.bestStartHour == 9, "best start hour sums multiple sessions instead of choosing the longest session")
let zeroRunning = RunningSession(start: now, accumulated: 0, resumedAt: now, note: "")
check(!unlocked(snapshot(running: zeroRunning), "first") && unlocked(snapshot([session(now, 1.0 / 3600)]), "first"), "first-session threshold is strictly positive work")
print("\(checks) insights checks passed")
