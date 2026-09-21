import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
@MainActor func date(_ year: Int = 2026, _ month: Int = 9, _ day: Int, _ hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}
var count = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else { print("FAIL: \(message)"); exit(1) }
    count += 1
}
func near(_ x: Double?, _ y: Double) -> Bool { x.map { abs($0 - y) < 0.001 } ?? false }
@MainActor func plan(_ daily: [Date: Double] = [:], goal: Double = 160, dailyGoal: Double = 4,
          week: Int = 5, now: Date = date(2026, 9, 21)) -> MonthlyWorkPlan {
    MonthlyWorkPlan(daily: daily.mapValues { $0 * 3600 }, monthlyGoalHours: goal,
                    dailyGoalHours: dailyGoal, workdaysPerWeek: week, now: now, calendar: calendar)
}
let behind = plan([date(2026, 9, 1): 96])
check(behind.calendarDaysRemaining == 10 && behind.estimatedWorkdaysRemaining == 8, "ten days remaining estimates eight workdays at five per week")
check(near(behind.requiredDaily, 8 * 3600), "64 remaining hours across eight estimated days needs eight hours")
check(behind.suggestedDailyHours == 8 && behind.dailyGoalTooLow, "four hour goal needs an eight hour recommendation")
let during = plan([date(2026, 9, 1): 96, date(2026, 9, 21): 4])
check(near(during.requiredDaily, 8 * 3600) && near(during.todayRemaining, 4 * 3600), "today's work reduces today's remainder without inflating full-day target")
let extra = plan([date(2026, 9, 1): 96, date(2026, 9, 21): 15])
check(near(extra.requiredDaily, 7 * 3600) && extra.todayRemaining == 0, "extra work today lowers future target")
check(near(plan([date(2026, 9, 1):160]).requiredDaily,0), "reached goal needs no more work")
check(plan([date(2026, 9, 1):170]).reached, "over target remains reached")
check(plan(week:0).requiredDaily == nil && plan(week:8).requiredDaily == nil, "schedule requires explicit valid choice")
check(!plan(goal:0).isConfigured && !plan(goal:.nan).hasGoal, "disabled and invalid goals have no plan")
let oneDay = plan([date(2026, 9, 1):154, date(2026, 9, 30):2],now:date(2026,9,30))
check(oneDay.estimatedWorkdaysRemaining == 1 && near(oneDay.requiredDaily,6 * 3600) && near(oneDay.todayRemaining,4 * 3600), "last day credits today's completed work")
check(plan(goal:160,now:date(2026,9,30)).suggestedDailyHours == nil, "impossible day never offers apply above 24h")
check(plan(goal:0.1,now:date(2026,9,30)).suggestedDailyHours == 0.25, "suggestions round up to quarter hour")
check(plan().projectedMonthEnd == nil, "no records means no invented forecast")
check(plan([date(2026,9,21):2]).projectedMonthEnd == nil, "today alone cannot establish a finished-day average")
var steady: [Date:Double] = [:]
for d in 14...18 { steady[date(2026,9,d)] = 8 }
let pace = plan(steady)
check(pace.sampleDays == 7 && near(pace.recentDailyAverage,8 * 3600), "five eight-hour workdays plus two rest days yield eight hours per workday")
check(near(pace.projectedMonthEnd,104 * 3600), "forecast adds eight estimated workdays to 40 actual hours")
check(near(pace.plannedMonthEnd,72 * 3600), "configured four-hour target predicts a different outcome from actual pace")
steady[date(2026,9,18)] = 0
check(plan(steady).projectedMonthEnd! < pace.projectedMonthEnd!, "missing a planned day's work lowers the forecast")
let quiet = plan([date(2026,9,1):40])
check(quiet.recentDailyAverage == 0 && near(quiet.projectedMonthEnd,40 * 3600), "seven quiet days project no additional work")
let filtered = plan([date(2026,9,1):10, date(2026,10,1):99, date(2026,9,2):.nan, date(2026,9,3): -2])
check(near(filtered.monthWorked,10 * 3600), "future and invalid input cannot inflate actual progress")
check(plan([date(2026,8,31):8]).monthWorked == 0, "previous month work informs pace but not this month's actual total")
check(plan(now:date(2028,2,1)).calendarDaysRemaining == 29, "leap February has 29 days")
check(plan(now:date(2026,2,1)).calendarDaysRemaining == 28, "ordinary February has 28 days")
check(near(plan([date(2026,9,1):96],week:3).requiredDaily,12.8 * 3600), "three-day week needs a higher target")
check(near(plan([date(2026,9,1):96],week:7).requiredDaily,6.4 * 3600), "seven-day week spreads the remaining work")
check(plan(steady,dailyGoal:2).projectedMonthEnd == plan(steady,dailyGoal:10).projectedMonthEnd, "editing a goal cannot fabricate a better actual-pace forecast")
check(plan([date(2026,9,30):8],now:date(2026,10,1)).monthWorked == 0, "new month resets current progress")
calendar.timeZone = TimeZone(identifier:"America/New_York")!
check(plan(now:date(2026,3,1)).calendarDaysRemaining == 31, "DST uses calendar days, not fixed seconds")
print("TOTAL \(count) FAILED 0")
