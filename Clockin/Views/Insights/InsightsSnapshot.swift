import Foundation

struct InsightsSnapshot {
    var daily: [Date: TimeInterval]
    var dailyEarnings: [Date: Double] = [:]
    var totalDuration: TimeInterval = 0
    var totalEarnings: Double = 0
    var monthDuration: TimeInterval = 0
    var monthEarnings: Double = 0
    var recentWeek: TimeInterval = 0
    var previousWeek: TimeInterval = 0
    var longestSession: TimeInterval = 0
    var sessionCount = 0
    var longestStreak = 0
    var currentStreak = 0
    var goalDays = 0
    var doubleGoalDays = 0
    var goalMonths = 0
    var baseXP = 0
    var streakXP = 0

    var goalXP: Int { goalDays * 100 + doubleGoalDays * 250 + goalMonths * 500 }
    var xp: Int { baseXP + goalXP + streakXP }
    var level: Int { max(1, xp / 500 + 1) }

    @MainActor
    init(store: ClockStore, now: Date, dailyGoal: Double, monthlyGoal: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let previousStart = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        daily = store.dailyDurations

        // Tum kayitlarin kazanci ve rekorlari satir basina degil, bir kez hesaplanir.
        for session in store.sessions {
            let day = calendar.startOfDay(for: session.start)
            dailyEarnings[day, default: 0] += store.earnings(for: session)
            totalDuration += session.duration
            longestSession = max(longestSession, session.duration)
            sessionCount += 1
        }
        if let running = store.running {
            let day = calendar.startOfDay(for: running.start)
            totalDuration += running.elapsed(at: now)
            daily[day, default: 0] += running.elapsed(at: now)
            dailyEarnings[day, default: 0] += store.currentEarnings(at: now)
        }

        var months: [Date: TimeInterval] = [:]
        let days = daily.keys.sorted()
        var previousDay: Date?
        var consecutive = 0
        for day in days {
            let duration = daily[day, default: 0]
            let earnings = dailyEarnings[day, default: 0]
            totalEarnings += earnings
            let month = calendar.dateInterval(of: .month, for: day)?.start ?? day
            months[month, default: 0] += duration
            if calendar.isDate(day, equalTo: today, toGranularity: .month) {
                monthDuration += duration
                monthEarnings += earnings
            }
            if day >= weekStart && day <= today { recentWeek += duration }
            if day >= previousStart && day < weekStart { previousWeek += duration }
            if dailyGoal > 0 {
                if duration >= dailyGoal * 3600 { goalDays += 1 }
                if duration >= dailyGoal * 7200 { doubleGoalDays += 1 }
            }
            if let previousDay, calendar.dateComponents([.day], from: previousDay, to: day).day == 1 {
                consecutive += 1
            } else {
                consecutive = 1
            }
            longestStreak = max(longestStreak, consecutive)
            previousDay = day
        }
        if monthlyGoal > 0 {
            goalMonths = months.values.filter { $0 >= monthlyGoal * 3600 }.count
        }
        var cursor = today
        if daily[cursor] == nil {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while daily[cursor] != nil {
            currentStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor), previous < cursor else { break }
            cursor = previous
        }
        // Mac ile ayni yuvarlama ve biriken seri bonuslari korunur.
        baseXP = Int(totalDuration / 3600 * 100)
        for (threshold, bonus) in [(3, 100), (7, 250), (14, 500), (30, 1_000), (60, 2_000)] {
            if longestStreak >= threshold { streakXP += bonus }
        }
    }
}
