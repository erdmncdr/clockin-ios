import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

// Hedef yok
check(GoalProgress(worked: 3600, hours: 0) == nil, "a zero goal is no goal")
check(GoalProgress(worked: 3600, hours: -2) == nil, "a negative goal is no goal")
check(GoalProgress(worked: 3600, hours: .nan) == nil && GoalProgress(worked: 3600, hours: .infinity) == nil,
      "an invalid stored goal is no goal")

// Ilerleme
let half = GoalProgress(worked: 4 * 3600, hours: 8)!
check(half.fraction == 0.5 && !half.isReached && half.remaining == 4 * 3600, "half way leaves half the target to go")
let exact = GoalProgress(worked: 7.5 * 3600, hours: 7.5)!
check(exact.isReached && exact.fraction == 1 && exact.remaining == 0, "meeting a fractional goal exactly reaches it")
let over = GoalProgress(worked: 10 * 3600, hours: 8)!
check(over.fraction == 1 && over.remaining == 0 && over.worked == 10 * 3600, "going past the goal caps the bar but keeps the hours")
check(GoalProgress(worked: -60, hours: 1)!.worked == 0, "negative worked time reads as none")
check(GoalProgress(worked: 1799, hours: 0.5)!.isReached == false, "one second short is not reached")

// Ay toplami
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
@MainActor func day(_ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
}
let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 12))!
let daily: [Date: TimeInterval] = [day(2, 28): 5 * 3600, day(3, 1): 2 * 3600, day(3, 14): 3 * 3600, day(4, 1): 9 * 3600]
check(GoalProgress.monthWorked(daily: daily, active: 0, now: now, calendar: calendar) == 5 * 3600,
      "month total counts only this month's days")
check(GoalProgress.monthWorked(daily: daily, active: 1800, now: now, calendar: calendar) == 5.5 * 3600,
      "month total adds the running session")
check(GoalProgress.monthWorked(daily: [:], active: 0, now: now, calendar: calendar) == 0, "an empty month is zero")

// Yazilan saat
check(GoalProgress.parseHours("7.5", maximum: 24) == 7.5, "dot decimal parses")
check(GoalProgress.parseHours("7,5", maximum: 24) == 7.5, "comma decimal parses")
check(GoalProgress.parseHours(" 8 ", maximum: 24) == 8, "surrounding spaces are ignored")
check(GoalProgress.parseHours("0", maximum: 24) == 0, "zero is allowed and turns the goal off")
check(GoalProgress.parseHours("", maximum: 24) == nil, "empty input keeps the old goal")
check(GoalProgress.parseHours("7,", maximum: 24) == 7, "a trailing separator while typing still reads the whole hours")
check(GoalProgress.parseHours("abc", maximum: 24) == nil && GoalProgress.parseHours("1,2,3", maximum: 24) == nil,
      "text that is not a number is rejected")
check(GoalProgress.parseHours("25", maximum: 24) == nil, "a daily goal above 24 hours is rejected")
check(GoalProgress.parseHours("-1", maximum: 24) == nil, "a negative goal is rejected")
check(GoalProgress.parseHours("7.333", maximum: 24) == 7.33, "input is kept to two decimals")

// Adimlar
check(GoalProgress.stepped(7, by: 0.5, maximum: 24) == 7.5, "stepping up from a step line moves one step")
check(GoalProgress.stepped(7.3, by: 0.5, maximum: 24) == 7.5, "stepping up from between lines lands on the next line")
check(GoalProgress.stepped(7.3, by: -0.5, maximum: 24) == 7, "stepping down from between lines lands on the line below")
check(GoalProgress.stepped(7.5, by: -0.5, maximum: 24) == 7, "stepping down from a step line moves one step")
check(GoalProgress.stepped(0, by: -0.5, maximum: 24) == 0, "stepping down never goes below zero")
check(GoalProgress.stepped(23.8, by: 0.5, maximum: 24) == 24, "stepping up stops at the maximum")
check(GoalProgress.stepped(162, by: 5, maximum: 744) == 165 && GoalProgress.stepped(162, by: -5, maximum: 744) == 160,
      "monthly steps snap to five hours")
check(GoalProgress.stepped(.nan, by: 0.5, maximum: 24) == 0.5, "an invalid stored goal steps from zero")

print("\(checks) goal checks passed")
