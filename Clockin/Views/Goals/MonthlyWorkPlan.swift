import Foundation

/// A planning estimate: a weekly day count cannot identify actual days off.
/// Durations belong to session start dates, matching Clockin's other reports.
struct MonthlyWorkPlan {
    static let workdaysKey = "Clockin.WorkdaysPerWeek"

    struct Day: Identifiable {
        let date: Date
        let worked: TimeInterval
        let cumulative: TimeInterval
        var id: Date { date }
    }

    let month: DateInterval
    let today: Date
    let days: [Day]
    let workdaysPerWeek: Int
    let calendarDaysRemaining: Int
    let estimatedWorkdaysRemaining: Int
    let monthWorked: TimeInterval
    let todayWorked: TimeInterval
    let target: TimeInterval
    let dailyTarget: TimeInterval
    let sampleDays: Int
    let recentDailyAverage: TimeInterval?

    var remaining: TimeInterval { max(0, target - monthWorked) }
    var hasGoal: Bool { target > 0 }
    var isConfigured: Bool { hasGoal && workdaysPerWeek > 0 }
    var reached: Bool { hasGoal && remaining == 0 }
    var fraction: Double { hasGoal ? min(1, monthWorked / target) : 0 }

    /// A whole-day target, crediting work already done today. If today has
    /// already met that target, spread only the outstanding work over later days.
    var requiredDaily: TimeInterval? {
        guard isConfigured else { return nil }
        guard !reached else { return 0 }
        let count = Double(estimatedWorkdaysRemaining)
        let balanced = (remaining + todayWorked) / count
        if todayWorked >= balanced, count > 1 { return remaining / (count - 1) }
        return balanced
    }

    var suggestedDailyHours: Double? {
        guard let requiredDaily, requiredDaily > 0, requiredDaily <= 24 * 3600 else { return nil }
        // Round up to an actionable quarter hour, never below the needed pace.
        return ceil(requiredDaily / 900) / 4
    }

    var todayRemaining: TimeInterval? { requiredDaily.map { max(0, $0 - todayWorked) } }
    var dailyGoalTooLow: Bool { requiredDaily.map { dailyTarget + 60 < $0 } ?? false }
    var projectedMonthEnd: TimeInterval? { recentDailyAverage.map(projectedTotal) }
    var plannedMonthEnd: TimeInterval? {
        isConfigured && dailyTarget > 0 ? projectedTotal(dailyTarget) : nil
    }

    private func projectedTotal(_ daily: TimeInterval) -> TimeInterval {
        monthWorked + max(0, daily - todayWorked)
            + daily * Double(max(0, estimatedWorkdaysRemaining - 1))
    }

    init(daily: [Date: TimeInterval], monthlyGoalHours: Double, dailyGoalHours: Double,
         workdaysPerWeek: Int, now: Date, calendar: Calendar = .current) {
        today = calendar.startOfDay(for: now)
        month = calendar.dateInterval(of: .month, for: now)!
        self.workdaysPerWeek = (1...7).contains(workdaysPerWeek) ? workdaysPerWeek : 0
        calendarDaysRemaining = calendar.dateComponents([.day], from: today, to: month.end).day ?? 1
        estimatedWorkdaysRemaining = self.workdaysPerWeek == 0 ? 0 :
            max(1, Int(ceil(Double(calendarDaysRemaining * self.workdaysPerWeek) / 7)))
        target = monthlyGoalHours.isFinite && monthlyGoalHours > 0 ? min(744, monthlyGoalHours) * 3600 : 0
        dailyTarget = dailyGoalHours.isFinite && dailyGoalHours > 0 ? min(24, dailyGoalHours) * 3600 : 0

        var valid: [Date: TimeInterval] = [:]
        for (date, duration) in daily where date <= now && duration.isFinite && duration > 0 {
            valid[calendar.startOfDay(for: date), default: 0] += duration
        }
        todayWorked = valid[today, default: 0]
        var cursor = month.start
        var total: TimeInterval = 0
        var points: [Day] = []
        while cursor <= today {
            let worked = valid[cursor, default: 0]
            total += worked
            points.append(Day(date: cursor, worked: worked, cumulative: total))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        days = points
        monthWorked = total

        // Exclude today's unfinished day from the pace sample. Include quiet
        // days after the first recorded work so a slowdown lowers the forecast.
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let sampleStart = max(weekAgo, valid.keys.min() ?? today)
        sampleDays = max(0, calendar.dateComponents([.day], from: sampleStart, to: today).day ?? 0)
        let sampleEnd = today
        let recent = valid.filter { $0.key >= sampleStart && $0.key < sampleEnd }.values.reduce(0, +)
        if sampleDays > 0, self.workdaysPerWeek > 0 {
            recentDailyAverage = recent / (Double(sampleDays * self.workdaysPerWeek) / 7)
        } else {
            recentDailyAverage = nil
        }
    }
}
