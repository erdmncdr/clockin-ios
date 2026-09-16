import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
calendar.firstWeekday = 2
var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    precondition(condition, name)
    checks += 1
    print("ok: \(name)")
}
@MainActor func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, in cal: Calendar? = nil) -> Date {
    (cal ?? calendar).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}
@MainActor func session(_ start: Date, _ hours: Double) -> WorkSession {
    WorkSession(id: UUID(), start: start, end: start.addingTimeInterval(hours * 3600),
                duration: hours * 3600, note: "Fixture", hourlyRate: 40, source: "test")
}
let now = date(2026, 9, 17, 12)
@MainActor func period(_ range: EarningsRange, _ anchor: Date? = nil, at time: Date? = nil) -> EarningsPeriod {
    EarningsPeriod(range: range, anchor: anchor ?? time ?? now, now: time ?? now, calendar: calendar)
}
@MainActor func bounds(_ value: EarningsPeriod, _ start: Date, _ end: Date, _ name: String) {
    check(value.interval.start == start && value.interval.end == end, name)
}
let week = period(.week)
bounds(week, date(2026, 9, 14), date(2026, 9, 21), "Monday week bounds")
bounds(period(.week, date(2026, 9, 1)), date(2026, 8, 31), date(2026, 9, 7), "week crosses month")
bounds(period(.week, date(2026, 1, 1)), date(2025, 12, 29), date(2026, 1, 5), "week crosses year")
var sunday = calendar
sunday.firstWeekday = 1
bounds(EarningsPeriod(range: .week, anchor: now, now: now, calendar: sunday),
       date(2026, 9, 13), date(2026, 9, 20), "Sunday week respects calendar")
for (year, month, days) in [(2025, 2, 28), (2024, 2, 29), (2026, 4, 30), (2026, 1, 31)] {
    let value = period(.month, date(year, month, 12))
    check(value.interval.start == date(year, month, 1), "month starts on first: \(year)/\(month)")
    check(calendar.dateComponents([.day], from: value.interval.start, to: value.interval.end).day == days,
          "month has \(days) days")
}
bounds(period(.sixMonths), date(2026, 4, 1), date(2026, 10, 1), "current 6M ends after current month")
bounds(period(.sixMonths, date(2026, 3, 31)), date(2025, 10, 1), date(2026, 4, 1), "previous 6M crosses year")
bounds(period(.sixMonths, at: date(2026, 1, 12)), date(2025, 8, 1), date(2026, 2, 1), "January 6M crosses year")
let spring = period(.week, date(2026, 3, 8))
check(spring.interval.duration == 167 * 3600, "spring DST week is 167 hours")
let fall = period(.week, at: date(2026, 11, 1, 12))
check(fall.interval.duration == 169 * 3600, "fall DST week is 169 hours")
check(calendar.dateComponents([.day], from: spring.interval.start, to: spring.interval.end).day == 7, "DST keeps seven calendar days")
for range in [EarningsRange.week, .month, .sixMonths] {
    let current = period(range)
    let back = current.paged(by: -1, now: now, calendar: calendar)
    let older = back.paged(by: -1, now: now, calendar: calendar)
    check(back.interval.end == current.interval.start && older.interval.end == back.interval.start, "\(range) pages are adjacent")
    check(back.canGoForward && !current.canGoForward, "\(range) forward availability")
    check(back.paged(by: 1, now: now, calendar: calendar).interval == current.interval, "\(range) returns forward")
    check(current.paged(by: 1, now: now, calendar: calendar) == current, "\(range) cannot page into future")
    check(current.switching(to: .all, now: now, calendar: calendar).switching(to: range, now: now, calendar: calendar).interval == current.interval,
          "\(range) anchor survives All")
}
check(period(.all).paged(by: -1, now: now, calendar: calendar) == period(.all), "All never pages")
let boundaryWeek = period(.week, date(2026, 9, 1))
bounds(boundaryWeek.switching(to: .month, now: now, calendar: calendar), date(2026, 9, 1), date(2026, 10, 1), "cross-month week retains September anchor")
bounds(period(.month, date(2026, 8, 17)).switching(to: .week, now: now, calendar: calendar), date(2026, 8, 17), date(2026, 8, 24), "month to week retains date")
check(period(.month, date(2026, 8, 31)).paged(by: 1, now: now, calendar: calendar).anchor == now, "forward anchor clamps to now")
check(period(.month, date(2026, 3, 31)).paged(by: -1, now: now, calendar: calendar).anchor == date(2026, 2, 28), "paging clamps shorter month")
check(period(.week, date(2027, 1, 1)).interval == week.interval, "future anchor clamps to current period")
check(EarningsRange.allCases.map(\.rawValue) == ["W", "M", "6M", "All"], "persisted range values")

let sessions = [session(date(2026, 9, 1, 9), 2), session(date(2026, 9, 1, 14), 1),
                session(date(2026, 9, 11, 9), 7), session(date(2026, 9, 17, 9), 4),
                session(date(2026, 8, 1, 9), 2), session(date(2026, 8, 17, 9), 3),
                session(date(2026, 8, 18, 9), 8), session(date(2026, 3, 31, 9), 5),
                session(date(2026, 10, 1, 9), 99)]
@MainActor func snapshot(_ page: EarningsPeriod, items: [WorkSession]? = nil, at time: Date? = nil,
                         running: RunningSession? = nil, missing: Bool = false) -> EarningsSnapshot {
    EarningsSnapshot(sessions: items ?? sessions, running: running, range: page.range, now: time ?? now,
        calendar: calendar, period: page, earnings: { $0.earnings }, activeEarnings: 20,
        rate: { day in missing && calendar.component(.day, from: day) == 17 ? nil : (calendar.component(.day, from: day) == 1 ? 30 : 40) })
}
let month = snapshot(period(.month))
check(month.sessions.count == 4 && month.duration == 14 * 3600 && month.earned == 560, "current month session list and totals")
check(month.calendarDays == 17 && month.activeDays == 3, "current calendar days and unique worked days")
check(abs(month.activeDayAverage - 14 * 3600 / 3) < 0.001, "average per worked day")
check(month.converted == 21200, "historical TRY uses daily rates")
check(snapshot(period(.month), missing: true).converted == nil, "missing rates never give partial TRY total")
let previous = snapshot(period(.month, date(2026, 8, 17)))
check(previous.duration == 13 * 3600 && previous.earned == 520 && previous.sessions.count == 3, "previous page totals and list")
check(previous.calendarDays == 31, "past month uses full calendar days")
let weekSnapshot = snapshot(week)
check(weekSnapshot.duration == 4 * 3600 && weekSnapshot.calendarDays == 4, "week only includes visible elapsed days")
let previousWeek = snapshot(week.paged(by: -1, now: now, calendar: calendar))
check(previousWeek.duration == 7 * 3600 && previousWeek.calendarDays == 7, "previous week excludes neighboring pages")
let six = snapshot(period(.sixMonths))
check(six.duration == 27 * 3600 && six.sessions.count == 7, "6M excludes previous block and future")
check(six.monthlyBars(calendar: calendar).map(\.duration) == [13 * 3600, 14 * 3600], "6M groups daily work into months")
check(six.monthlyBars(calendar: calendar).reduce(0) { $0 + ($1.converted ?? 0) } == six.converted, "monthly TRY sums historical daily amounts")
check(snapshot(period(.sixMonths), missing: true).monthlyBars(calendar: calendar).allSatisfy { $0.converted == nil }, "incomplete months do not plot partial TRY")
check(snapshot(period(.all)).sessions.count == 8, "All excludes future sessions")
let running = RunningSession(start: date(2026, 9, 17, 10), accumulated: 1800, resumedAt: nil, note: "Fixture")
let active = snapshot(period(.month), running: running)
check(active.includesActive && active.duration == month.duration + 1800, "paused work adds worked time only")
check(active.earned == 580 && active.sessions.count == 4 && active.activeDays == 3, "active earnings separate from completed and unique day counts")
check(!snapshot(period(.month, date(2026, 8, 17)), running: running).includesActive, "active session excluded from previous page")
let overnight = session(date(2026, 8, 31, 23), 2)
check(snapshot(period(.month), items: [overnight]).duration == 0, "overnight work belongs to starting month")
check(snapshot(period(.month, date(2026, 8, 17)), items: [overnight]).duration == 7200, "overnight duration is preserved")
let empty = snapshot(period(.month), items: [])
check(empty.points.isEmpty && empty.duration == 0 && empty.activeDayAverage == 0, "empty page has zero totals")
check(snapshot(period(.all), items: []).calendarDays == 1, "empty All has safe divisor")
let onlyRunning = snapshot(period(.all), items: [], running: running)
check(onlyRunning.calendarDays == 1 && onlyRunning.includesActive, "All handles active-only archive")
check(month.points.map(\.day) == month.points.map(\.day).sorted(), "daily points are ordered")
let dst = snapshot(spring, items: [session(date(2026, 3, 8, 9), 1)])
check(dst.calendarDays == 7 && dst.duration == 3600, "DST page totals use calendar days")

let performance = MonthPerformance(snapshot: month, period: period(.month), sessions: sessions, monthlyGoal: 100, now: now, calendar: calendar)
check(performance.workedDays == 3 && performance.duration == 14 * 3600 && performance.earned == 560, "month performance totals")
check(abs(performance.averageDuration - 14 * 3600 / 3) < 0.001 && abs(performance.averageEarnings - 560 / 3) < 0.001, "performance averages")
check(performance.goal?.remaining == 86 * 3600 && performance.goal?.fraction == 0.14, "monthly goal percent and remaining")
check(abs(performance.projectedDuration! / 3600 - (14 + 11.0 / 7 * 13)) < 0.001, "projection uses Insights completed seven-day pace after today")
check(performance.comparisonInterval == DateInterval(start: date(2026, 8, 1), end: date(2026, 8, 18)), "same point last month includes day 17")
check(performance.comparisonDuration == 5 * 3600 && performance.difference == 9 * 3600, "same-point comparison excludes day 18")
check(performance.cumulative.count == 17 && performance.cumulative.first?.cumulative == 3 * 3600 && performance.cumulative.last?.cumulative == 14 * 3600, "cumulative starts on first and stops today")
check(performance.cumulative[1].daily == 0 && performance.cumulative[1].cumulative == 3 * 3600, "cumulative fills non-work days")
check(zip(performance.cumulative, performance.cumulative.dropFirst()).allSatisfy { $0.cumulative <= $1.cumulative }, "cumulative is monotonic")
check(performance.target.map(\.day) == [date(2026, 9, 1), date(2026, 9, 30)] && performance.target.map(\.duration) == [0, 100 * 3600], "target runs from zero on first to goal on last")
let noGoal = MonthPerformance(snapshot: empty, period: period(.month), sessions: [], monthlyGoal: 0, now: now, calendar: calendar)
check(noGoal.goal == nil && noGoal.target.isEmpty && noGoal.projectedDuration == nil, "no goal and no pace")
check(noGoal.workedDays == 0 && noGoal.averageDuration == 0 && noGoal.averageEarnings == 0, "empty performance averages")
let past = MonthPerformance(snapshot: previous, period: period(.month, date(2026, 8, 17)), sessions: sessions, monthlyGoal: 10, now: now, calendar: calendar)
check(!past.isCurrent && past.projectedDuration == nil && past.cumulative.count == 31, "past month has final numbers and no projection")
check(past.goal?.isReached == true && past.goal?.remaining == 0, "past month goal reached")
for (year, febDays) in [(2026, 28), (2024, 29)] {
    let time = date(year, 3, 31, 12)
    let page = period(.month, at: time)
    let fixtures = [session(date(year, 2, febDays, 10), 2), session(date(year, 3, 1, 10), 1)]
    let value = MonthPerformance(snapshot: snapshot(page, items: fixtures, at: time), period: page,
                                 sessions: fixtures, monthlyGoal: 20, now: time, calendar: calendar)
    check(value.comparisonInterval.end == date(year, 3, 1) && value.comparisonDuration == 7200, "shorter February \(febDays) is clamped without spilling into March")
}
let lastDay = date(2026, 9, 30, 12)
check(MonthlyGoalPace(recentCompleted: 7 * 3600, now: lastDay, calendar: calendar).projection(worked: 50 * 3600) == 50 * 3600, "last day projection does not count today twice")
let pace = MonthlyGoalPace(recentCompleted: 11 * 3600, now: now, calendar: calendar)
let estimate = InsightsGoalEstimate.make(dailyGoal: 0, monthlyGoal: 100, todayDuration: 0,
    monthDuration: month.duration, recentCompleted: 11 * 3600, running: nil, now: now, calendar: calendar)
check(estimate.monthly == .workDays(Int(ceil(86 / (pace.dailyAverage / 3600))), fitsInMonth: false), "Insights uses shared monthly pace")

@MainActor func prompt(daily: Double = 0, monthly: Double = 0, ever: Bool = false,
                       count: Int = 1, dismissed: Date? = nil) -> Bool {
    GoalPrompt.isVisible(daily: daily, monthly: monthly, everConfigured: ever, completedSessions: count,
                         dismissedAt: dismissed, now: now, calendar: calendar)
}
check(prompt(), "goal prompt after first completed session with no goals")
check(!prompt(dismissed: calendar.date(byAdding: .day, value: -6, to: now)), "dismissal within seven days hides prompt")
check(prompt(dismissed: calendar.date(byAdding: .day, value: -8, to: now)), "dismissal eight days ago expires")
check(prompt(dismissed: calendar.date(byAdding: .day, value: -7, to: now)), "dismissal expires at exactly seven calendar days")
check(!prompt(dismissed: now.addingTimeInterval(3600)), "future dismissal stays hidden")
check(!prompt(daily: 1) && !prompt(monthly: 1), "either goal hides prompt")
check(!prompt(ever: true), "goals later turned off do not restore prompt")
check(!prompt(count: 0), "brand-new install with no completed work stays hidden, idle or running")
check(GoalPrompt.hasGoal(daily: 0, monthly: 1) && !GoalPrompt.hasGoal(daily: 0, monthly: 0), "permanent suppression predicate")
check(EarningsSwipe.page(x: 60, y: 5) == -1 && EarningsSwipe.page(x: -60, y: 5) == 1, "horizontal swipe directions")
check(EarningsSwipe.page(x: 20, y: 0) == nil, "short movement does not page")
check(EarningsSwipe.page(x: 60, y: 45) == nil && EarningsSwipe.page(x: 5, y: 80) == nil, "diagonal and vertical movement do not page")
check(!EarningsSwipe.isHorizontal(x: 20, y: 10), "direction requires more than two-to-one ratio")
print("\(checks) earnings checks passed")
