import Foundation

struct MonthRunningPoint: Identifiable {
    let day: Date
    let daily: TimeInterval
    let cumulative: TimeInterval
    var id: Date { day }
}

struct MonthTargetPoint: Identifiable {
    let day: Date
    let duration: TimeInterval
    var id: Date { day }
}

struct MonthPerformance {
    let duration: TimeInterval
    let earned: Double
    let workedDays: Int
    let averageDuration: TimeInterval
    let averageEarnings: Double
    let goal: GoalProgress?
    let projectedDuration: TimeInterval?
    let comparisonInterval: DateInterval
    let comparisonDuration: TimeInterval
    let cumulative: [MonthRunningPoint]
    let target: [MonthTargetPoint]
    let isCurrent: Bool
    var difference: TimeInterval { duration - comparisonDuration }

    init(snapshot: EarningsSnapshot, period: EarningsPeriod, sessions: [WorkSession],
         monthlyGoal: Double, now: Date, calendar: Calendar = .current) {
        duration = snapshot.duration
        earned = snapshot.earned
        workedDays = snapshot.activeDays
        averageDuration = snapshot.activeDayAverage
        averageEarnings = workedDays == 0 ? 0 : earned / Double(workedDays)
        goal = GoalProgress(worked: duration, hours: monthlyGoal)
        isCurrent = period.isCurrent
        let recent = sessions.filter { MonthlyGoalPace.includes(start: $0.start, now: now) }.reduce(0) { $0 + $1.duration }
        projectedDuration = isCurrent ? MonthlyGoalPace(recentCompleted: recent, now: now, calendar: calendar)
            .projection(worked: duration) : nil
        let start = period.interval.start
        let end = period.interval.end
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let visibleEnd = min(end, tomorrow)
        let elapsedDays = calendar.dateComponents([.day], from: start, to: visibleEnd).day ?? 0
        let previousStart = calendar.date(byAdding: .month, value: -1, to: start)!
        let previousDays = calendar.dateComponents([.day], from: previousStart, to: start).day ?? 0
        let comparisonEnd = calendar.date(byAdding: .day, value: min(elapsedDays, previousDays), to: previousStart)!
        comparisonInterval = DateInterval(start: previousStart, end: comparisonEnd)
        comparisonDuration = sessions.filter { $0.start >= previousStart && $0.start < comparisonEnd }
            .reduce(0) { $0 + $1.duration }
        let daily = Dictionary(uniqueKeysWithValues: snapshot.points.map { ($0.day, $0.duration) })
        var values: [MonthRunningPoint] = []
        var total: TimeInterval = 0
        var day = start
        while day < visibleEnd {
            let worked = daily[day, default: 0]
            total += worked
            values.append(MonthRunningPoint(day: day, daily: worked, cumulative: total))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        cumulative = values
        if let goal {
            target = [MonthTargetPoint(day: start, duration: 0),
                      MonthTargetPoint(day: calendar.date(byAdding: .day, value: -1, to: end)!, duration: goal.target)]
        } else {
            target = []
        }
    }
}
