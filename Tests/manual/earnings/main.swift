import Foundation
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 12))!
@MainActor func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
@MainActor func session(_ offset: Int, hours: Double) -> WorkSession {
    let start = day(offset)
    return WorkSession(id: UUID(), start: start, end: start.addingTimeInterval(hours * 3600), duration: hours * 3600, note: "", hourlyRate: 25, source: "test")
}
let sessions = [session(0, hours: 2), session(-6, hours: 1), session(-7, hours: 4), session(-29, hours: 1), session(-30, hours: 3), session(-89, hours: 2), session(-90, hours: 5), session(1, hours: 9)]
var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1; print("ok: \(name)") }
@MainActor func snapshot(_ range: EarningsRange, running: RunningSession? = nil, missing: Bool = false) -> EarningsSnapshot {
    EarningsSnapshot(sessions: sessions, running: running, range: range, now: today, calendar: calendar,
        earnings: { $0.earnings }, activeEarnings: 12.5,
        rate: { date in missing ? nil : (calendar.isDate(date, inSameDayAs: today) ? 40 : 30) })
}
let week = snapshot(.week)
check(week.sessions.count == 2, "7D includes today and day -6, excludes -7 and future")
check(week.duration == 10800 && week.earned == 75, "weekly duration and original earnings")
check(week.converted == 2750, "historical conversion uses each day's rate, not latest for all")
check(snapshot(.month).sessions.count == 4, "30D calendar boundary")
check(snapshot(.quarter).sessions.count == 6, "3M means 90 calendar days")
check(snapshot(.all).sessions.count == 7, "ALL includes older history but not future records")
check(snapshot(.week, missing: true).converted == nil, "missing rates do not produce a misleading partial total")
let running = RunningSession(start: today.addingTimeInterval(-3600), accumulated: 1800, resumedAt: nil, note: "")
let paused = snapshot(.week, running: running)
check(paused.includesActive && paused.duration == 12600, "paused session adds only worked time")
check(paused.earned == 87.5 && paused.sessions.count == 2, "active earnings included separately from completed count")
let old = RunningSession(start: day(-7), accumulated: 1800, resumedAt: nil, note: "")
check(!snapshot(.week, running: old).includesActive, "active session outside period excluded by start day")
let empty = EarningsSnapshot(sessions: [], running: nil, range: .week, now: today, earnings: { $0.earnings }, activeEarnings: 0, rate: { _ in nil })
check(empty.points.isEmpty && empty.earned == 0, "empty archive")
check(week.points.map(\.day) == week.points.map(\.day).sorted(), "chart days chronological")
print("\(checks) earnings checks passed")
