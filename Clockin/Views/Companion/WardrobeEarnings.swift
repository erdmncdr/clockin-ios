import Foundation

struct WardrobeEarnings {
    let coins: Int
    let goalDays: Int
    let progress: WardrobeProgress

    init(sessions: [WorkSession], dailyGoal: Double, now: Date, calendar: Calendar) {
        var stats = InsightsSnapshot(sessions: sessions,
            sessionEarnings: Dictionary(sessions.map { ($0.id, 0.0) }, uniquingKeysWith: { first, _ in first }),
            now: now, calendar: calendar)
        // Arsivde kazanilmis seri rozetleri bugunun tarihine gore coin kaybetmez.
        stats.currentStreak = stats.longestStreak
        let badges = Set(stats.badges.filter(\.unlocked).map(\.id))
        goalDays = dailyGoal.isFinite && dailyGoal > 0 ? stats.daily.values.filter { $0 >= dailyGoal * 3600 }.count : 0
        coins = WardrobeCoins.earned(durations: sessions.map(\.duration), goalDays: goalDays, badges: badges.count, level: stats.level)
        progress = WardrobeProgress(hours: stats.totalDuration / 3600, level: stats.level, streak: stats.longestStreak, badges: badges)
    }
}
