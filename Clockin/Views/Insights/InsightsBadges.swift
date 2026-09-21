import Foundation

struct InsightsBadge: Identifiable {
    let id: String
    let title: String
    let requirement: String
    let icon: String
    let unlocked: Bool
    let progress: String
}

extension InsightsSnapshot {
    var badges: [InsightsBadge] {
        let total = totalDuration / 3600
        return [
            .init(id: "first", title: "First session", requirement: "Complete your first session", icon: "flag.fill", unlocked: total > 0, progress: String(sessionCount) + " sessions"),
            .init(id: "ten", title: "10-hour club", requirement: "Work 10 total hours", icon: "clock.fill", unlocked: total >= 10, progress: progressText(DurationText.compact(total * 3600), "10h")),
            .init(id: "fifty", title: "Half-century", requirement: "Work 50 total hours", icon: "flame.fill", unlocked: total >= 50, progress: progressText(DurationText.compact(total * 3600), "50h")),
            .init(id: "hundred", title: "Century", requirement: "Work 100 total hours", icon: "bolt.fill", unlocked: total >= 100, progress: progressText(DurationText.compact(total * 3600), "100h")),
            .init(id: "quarter", title: "Quarter kilo", requirement: "Work 250 total hours", icon: "crown.fill", unlocked: total >= 250, progress: progressText(DurationText.compact(total * 3600), "250h")),
            .init(id: "fivehundred", title: "Half-thousand", requirement: "Work 500 total hours", icon: "crown.fill", unlocked: total >= 500, progress: progressText(DurationText.compact(total * 3600), "500h")),
            .init(id: "sevenfifty", title: "Three-quarter legend", requirement: "Work 750 total hours", icon: "medal.fill", unlocked: total >= 750, progress: progressText(DurationText.compact(total * 3600), "750h")),
            .init(id: "thousand", title: "Thousand-hour", requirement: "Work 1,000 total hours", icon: "trophy.fill", unlocked: total >= 1_000, progress: progressText(DurationText.compact(total * 3600), "1,000h")),
            .init(id: "titan", title: "Time titan", requirement: "Work 1,500 total hours", icon: "diamond.fill", unlocked: total >= 1_500, progress: progressText(DurationText.compact(total * 3600), "1,500h")),
            .init(id: "streak", title: "On a roll", requirement: "Keep a 3-day streak", icon: "flame.circle.fill", unlocked: currentStreak >= 3, progress: progressText(String(currentStreak), "3 days")),
            .init(id: "weekstreak", title: "Weekly fire", requirement: "Keep a 7-day streak", icon: "calendar.badge.clock", unlocked: currentStreak >= 7, progress: progressText(String(currentStreak), "7 days")),
            .init(id: "monthstreak", title: "Unstoppable", requirement: "Keep a 30-day streak", icon: "infinity", unlocked: currentStreak >= 30, progress: progressText(String(currentStreak), "30 days")),
            .init(id: "streak14", title: "Fortnight fire", requirement: "Reach a 14-day streak", icon: "sparkles", unlocked: longestStreak >= 14, progress: progressText(String(longestStreak), "14 days")),
            .init(id: "streak60", title: "Seasoned", requirement: "Reach a 60-day streak", icon: "mountain.2.fill", unlocked: longestStreak >= 60, progress: progressText(String(longestStreak), "60 days")),
            .init(id: "week", title: "Weekly finisher", requirement: "Log 7 sessions", icon: "calendar.badge.plus", unlocked: sessionCount >= 7, progress: progressText(String(sessionCount), "7 sessions")),
            .init(id: "sessions25", title: "Session collector", requirement: "Log 25 sessions", icon: "square.stack.3d.up.fill", unlocked: sessionCount >= 25, progress: progressText(String(sessionCount), "25 sessions")),
            .init(id: "marathon", title: "Marathon", requirement: "Complete a 4-hour session", icon: "figure.run", unlocked: longestSession >= 4 * 3600, progress: progressText(DurationText.compact(longestSession), "4h")),
            .init(id: "ultra", title: "Ultra focus", requirement: "Complete an 8-hour session", icon: "bolt.circle.fill", unlocked: longestSession >= 8 * 3600, progress: progressText(DurationText.compact(longestSession), "8h")),
            .init(id: "xp", title: "XP engine", requirement: "Earn 10,000 XP", icon: "star.fill", unlocked: xp >= 10_000, progress: progressText(String(xp), "10,000 XP")),
            // Mac'teki hedef rozetlerinin yerine sabit esikler: hedef
            // kullanicinin sectigi bir sayi oldugu icin istenildigi kadar
            // kucultulup rozet acilabiliyordu.
            .init(id: "fullday", title: "Full day", requirement: "Work 8 hours in one day", icon: "target", unlocked: fullDays >= 1, progress: String(fullDays) + " 8-hour days"),
            .init(id: "longday", title: "Long day", requirement: "Work 10 hours in one day", icon: "arrow.up.right.circle.fill", unlocked: longDays >= 1, progress: String(longDays) + " 10-hour days"),
            .init(id: "bigmonth", title: "Hundred-hour month", requirement: "Work 100 hours in a calendar month", icon: "calendar.circle.fill", unlocked: bigMonths >= 1, progress: String(bigMonths) + " 100-hour months"),
            .init(id: "xp25", title: "Quarter XP", requirement: "Earn 25,000 XP", icon: "rosette", unlocked: xp >= 25_000, progress: progressText(String(xp), "25,000 XP")),
            .init(id: "active5", title: "Getting steady", requirement: "Work on 5 different days", icon: "calendar", unlocked: daily.count >= 5, progress: progressText(String(daily.count), "5 active days")),
            .init(id: "active25", title: "Calendar regular", requirement: "Work on 25 different days", icon: "calendar.badge.checkmark", unlocked: daily.count >= 25, progress: progressText(String(daily.count), "25 active days")),
            .init(id: "active100", title: "Daily craft", requirement: "Work on 100 different days", icon: "calendar.circle", unlocked: daily.count >= 100, progress: progressText(String(daily.count), "100 active days")),
            .init(id: "earlybird", title: "Early bird", requirement: "Start 5 sessions before 08:00", icon: "sunrise.fill", unlocked: earlyBirdSessions >= 5, progress: progressText(String(earlyBirdSessions), "5 early starts")),
            .init(id: "nightowl", title: "Night owl", requirement: "Start 5 sessions after 22:00", icon: "moon.stars.fill", unlocked: nightOwlSessions >= 5, progress: progressText(String(nightOwlSessions), "5 late starts")),
            .init(id: "weekend", title: "Weekend warrior", requirement: "Work on 4 weekend days", icon: "sun.max.fill", unlocked: weekendDays >= 4, progress: progressText(String(weekendDays), "4 weekend days")),
            .init(id: "sessions50", title: "Deep archive", requirement: "Log 50 sessions", icon: "books.vertical.fill", unlocked: sessionCount >= 50, progress: progressText(String(sessionCount), "50 sessions")),
            .init(id: "sessions100", title: "Century sessions", requirement: "Log 100 sessions", icon: "building.columns.fill", unlocked: sessionCount >= 100, progress: progressText(String(sessionCount), "100 sessions")),
            .init(id: "sessions200", title: "Archive master", requirement: "Log 200 sessions", icon: "square.stack.3d.up.fill", unlocked: sessionCount >= 200, progress: progressText(String(sessionCount), "200 sessions")),
            .init(id: "sessions500", title: "Session institution", requirement: "Log 500 sessions", icon: "building.2.crop.circle.fill", unlocked: sessionCount >= 500, progress: progressText(String(sessionCount), "500 sessions")),
            .init(id: "ultra12", title: "Iron focus", requirement: "Complete a 12-hour session", icon: "hourglass.bottomhalf.filled", unlocked: longestSession >= 12 * 3600, progress: progressText(DurationText.compact(longestSession), "12h")),
            .init(id: "ultra15", title: "Deep dive", requirement: "Complete a 15-hour session", icon: "water.waves", unlocked: longestSession >= 15 * 3600, progress: progressText(DurationText.compact(longestSession), "15h")),
            .init(id: "fullday7", title: "Full week", requirement: "Work 8 hours on 7 days", icon: "checkmark.seal.fill", unlocked: fullDays >= 7, progress: progressText(String(fullDays), "7 8-hour days")),
            .init(id: "fullday30", title: "Full month", requirement: "Work 8 hours on 30 days", icon: "target", unlocked: fullDays >= 30, progress: progressText(String(fullDays), "30 8-hour days")),
            .init(id: "bigmonth3", title: "Quarter of hundreds", requirement: "Work 100 hours in 3 calendar months", icon: "calendar.badge.checkmark", unlocked: bigMonths >= 3, progress: progressText(String(bigMonths), "3 100-hour months")),
            .init(id: "bigmonth12", title: "Year of hundreds", requirement: "Work 100 hours in 12 calendar months", icon: "calendar.badge.clock", unlocked: bigMonths >= 12, progress: progressText(String(bigMonths), "12 100-hour months")),
            .init(id: "streak90", title: "Season streak", requirement: "Reach a 90-day streak", icon: "flame.circle.fill", unlocked: longestStreak >= 90, progress: progressText(String(longestStreak), "90 days")),
            .init(id: "streak180", title: "Half-year fire", requirement: "Reach a 180-day streak", icon: "sun.max.fill", unlocked: longestStreak >= 180, progress: progressText(String(longestStreak), "180 days")),
            .init(id: "streak365", title: "Year-round", requirement: "Reach a 365-day streak", icon: "globe.americas.fill", unlocked: longestStreak >= 365, progress: progressText(String(longestStreak), "365 days")),
            .init(id: "active250", title: "Always on", requirement: "Work on 250 different days", icon: "calendar.badge.clock", unlocked: daily.count >= 250, progress: progressText(String(daily.count), "250 active days")),
            .init(id: "active500", title: "Permanent practice", requirement: "Work on 500 different days", icon: "calendar.circle.fill", unlocked: daily.count >= 500, progress: progressText(String(daily.count), "500 active days")),
            .init(id: "xp50", title: "XP architect", requirement: "Earn 50,000 XP", icon: "star.circle.fill", unlocked: xp >= 50_000, progress: progressText(String(xp), "50,000 XP")),
            .init(id: "xp100", title: "XP legend", requirement: "Earn 100,000 XP", icon: "sparkles", unlocked: xp >= 100_000, progress: progressText(String(xp), "100,000 XP"))
        ] + collectionBadges
    }

    private func progressText(_ current: String, _ target: String) -> String { current + " / " + target }
}
