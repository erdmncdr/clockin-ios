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
            .init(id: "first", title: String(localized: "First session"), requirement: String(localized: "Complete your first session"), icon: "flag.fill", unlocked: total > 0, progress: String(localized: "\(sessionCount) sessions")),
            .init(id: "ten", title: String(localized: "10-hour club"), requirement: String(localized: "Work 10 total hours"), icon: "clock.fill", unlocked: total >= 10, progress: progressText(DurationText.compact(total * 3600), String(localized: "10h"))),
            .init(id: "fifty", title: String(localized: "Half-century"), requirement: String(localized: "Work 50 total hours"), icon: "flame.fill", unlocked: total >= 50, progress: progressText(DurationText.compact(total * 3600), String(localized: "50h"))),
            .init(id: "hundred", title: String(localized: "Century"), requirement: String(localized: "Work 100 total hours"), icon: "bolt.fill", unlocked: total >= 100, progress: progressText(DurationText.compact(total * 3600), String(localized: "100h"))),
            .init(id: "quarter", title: String(localized: "Quarter kilo"), requirement: String(localized: "Work 250 total hours"), icon: "crown.fill", unlocked: total >= 250, progress: progressText(DurationText.compact(total * 3600), String(localized: "250h"))),
            .init(id: "fivehundred", title: String(localized: "Half-thousand"), requirement: String(localized: "Work 500 total hours"), icon: "crown.fill", unlocked: total >= 500, progress: progressText(DurationText.compact(total * 3600), String(localized: "500h"))),
            .init(id: "sevenfifty", title: String(localized: "Three-quarter legend"), requirement: String(localized: "Work 750 total hours"), icon: "medal.fill", unlocked: total >= 750, progress: progressText(DurationText.compact(total * 3600), String(localized: "750h"))),
            .init(id: "thousand", title: String(localized: "Thousand-hour"), requirement: String(localized: "Work 1,000 total hours"), icon: "trophy.fill", unlocked: total >= 1_000, progress: progressText(DurationText.compact(total * 3600), String(localized: "1,000h"))),
            .init(id: "titan", title: String(localized: "Time titan"), requirement: String(localized: "Work 1,500 total hours"), icon: "diamond.fill", unlocked: total >= 1_500, progress: progressText(DurationText.compact(total * 3600), String(localized: "1,500h"))),
            .init(id: "streak", title: String(localized: "On a roll"), requirement: String(localized: "Keep a 3-day streak"), icon: "flame.circle.fill", unlocked: currentStreak >= 3, progress: progressText(String(currentStreak), String(localized: "3 days"))),
            .init(id: "weekstreak", title: String(localized: "Weekly fire"), requirement: String(localized: "Keep a 7-day streak"), icon: "calendar.badge.clock", unlocked: currentStreak >= 7, progress: progressText(String(currentStreak), String(localized: "7 days"))),
            .init(id: "monthstreak", title: String(localized: "Unstoppable"), requirement: String(localized: "Keep a 30-day streak"), icon: "infinity", unlocked: currentStreak >= 30, progress: progressText(String(currentStreak), String(localized: "30 days"))),
            .init(id: "streak14", title: String(localized: "Fortnight fire"), requirement: String(localized: "Reach a 14-day streak"), icon: "sparkles", unlocked: longestStreak >= 14, progress: progressText(String(longestStreak), String(localized: "14 days"))),
            .init(id: "streak60", title: String(localized: "Seasoned"), requirement: String(localized: "Reach a 60-day streak"), icon: "mountain.2.fill", unlocked: longestStreak >= 60, progress: progressText(String(longestStreak), String(localized: "60 days"))),
            .init(id: "week", title: String(localized: "Weekly finisher"), requirement: String(localized: "Log 7 sessions"), icon: "calendar.badge.plus", unlocked: sessionCount >= 7, progress: progressText(String(sessionCount), String(localized: "7 sessions"))),
            .init(id: "sessions25", title: String(localized: "Session collector"), requirement: String(localized: "Log 25 sessions"), icon: "square.stack.3d.up.fill", unlocked: sessionCount >= 25, progress: progressText(String(sessionCount), String(localized: "25 sessions"))),
            .init(id: "marathon", title: String(localized: "Marathon"), requirement: String(localized: "Complete a 4-hour session"), icon: "figure.run", unlocked: longestSession >= 4 * 3600, progress: progressText(DurationText.compact(longestSession), String(localized: "4h"))),
            .init(id: "ultra", title: String(localized: "Ultra focus"), requirement: String(localized: "Complete an 8-hour session"), icon: "bolt.circle.fill", unlocked: longestSession >= 8 * 3600, progress: progressText(DurationText.compact(longestSession), String(localized: "8h"))),
            .init(id: "xp", title: String(localized: "XP engine"), requirement: String(localized: "Earn 10,000 XP"), icon: "star.fill", unlocked: xp >= 10_000, progress: progressText(String(xp), String(localized: "10,000 XP"))),
            // Mac'teki hedef rozetlerinin yerine sabit esikler: hedef
            // kullanicinin sectigi bir sayi oldugu icin istenildigi kadar
            // kucultulup rozet acilabiliyordu.
            .init(id: "fullday", title: String(localized: "Full day"), requirement: String(localized: "Work 8 hours in one day"), icon: "target", unlocked: fullDays >= 1, progress: String(localized: "\(fullDays) 8-hour days")),
            .init(id: "longday", title: String(localized: "Long day"), requirement: String(localized: "Work 10 hours in one day"), icon: "arrow.up.right.circle.fill", unlocked: longDays >= 1, progress: String(localized: "\(longDays) 10-hour days")),
            .init(id: "bigmonth", title: String(localized: "Hundred-hour month"), requirement: String(localized: "Work 100 hours in a calendar month"), icon: "calendar.circle.fill", unlocked: bigMonths >= 1, progress: String(localized: "\(bigMonths) 100-hour months")),
            .init(id: "xp25", title: String(localized: "Quarter XP"), requirement: String(localized: "Earn 25,000 XP"), icon: "rosette", unlocked: xp >= 25_000, progress: progressText(String(xp), String(localized: "25,000 XP"))),
            .init(id: "active5", title: String(localized: "Getting steady"), requirement: String(localized: "Work on 5 different days"), icon: "calendar", unlocked: daily.count >= 5, progress: progressText(String(daily.count), String(localized: "5 active days"))),
            .init(id: "active25", title: String(localized: "Calendar regular"), requirement: String(localized: "Work on 25 different days"), icon: "calendar.badge.checkmark", unlocked: daily.count >= 25, progress: progressText(String(daily.count), String(localized: "25 active days"))),
            .init(id: "active100", title: String(localized: "Daily craft"), requirement: String(localized: "Work on 100 different days"), icon: "calendar.circle", unlocked: daily.count >= 100, progress: progressText(String(daily.count), String(localized: "100 active days"))),
            .init(id: "earlybird", title: String(localized: "Early bird"), requirement: String(localized: "Start 5 sessions before 08:00"), icon: "sunrise.fill", unlocked: earlyBirdSessions >= 5, progress: progressText(String(earlyBirdSessions), String(localized: "5 early starts"))),
            .init(id: "nightowl", title: String(localized: "Night owl"), requirement: String(localized: "Start 5 sessions after 22:00"), icon: "moon.stars.fill", unlocked: nightOwlSessions >= 5, progress: progressText(String(nightOwlSessions), String(localized: "5 late starts"))),
            .init(id: "weekend", title: String(localized: "Weekend warrior"), requirement: String(localized: "Work on 4 weekend days"), icon: "sun.max.fill", unlocked: weekendDays >= 4, progress: progressText(String(weekendDays), String(localized: "4 weekend days"))),
            .init(id: "sessions50", title: String(localized: "Deep archive"), requirement: String(localized: "Log 50 sessions"), icon: "books.vertical.fill", unlocked: sessionCount >= 50, progress: progressText(String(sessionCount), String(localized: "50 sessions"))),
            .init(id: "sessions100", title: String(localized: "Century sessions"), requirement: String(localized: "Log 100 sessions"), icon: "building.columns.fill", unlocked: sessionCount >= 100, progress: progressText(String(sessionCount), String(localized: "100 sessions"))),
            .init(id: "sessions200", title: String(localized: "Archive master"), requirement: String(localized: "Log 200 sessions"), icon: "square.stack.3d.up.fill", unlocked: sessionCount >= 200, progress: progressText(String(sessionCount), String(localized: "200 sessions"))),
            .init(id: "sessions500", title: String(localized: "Session institution"), requirement: String(localized: "Log 500 sessions"), icon: "building.2.crop.circle.fill", unlocked: sessionCount >= 500, progress: progressText(String(sessionCount), String(localized: "500 sessions"))),
            .init(id: "ultra12", title: String(localized: "Iron focus"), requirement: String(localized: "Complete a 12-hour session"), icon: "hourglass.bottomhalf.filled", unlocked: longestSession >= 12 * 3600, progress: progressText(DurationText.compact(longestSession), String(localized: "12h"))),
            .init(id: "ultra15", title: String(localized: "Deep dive"), requirement: String(localized: "Complete a 15-hour session"), icon: "water.waves", unlocked: longestSession >= 15 * 3600, progress: progressText(DurationText.compact(longestSession), String(localized: "15h"))),
            .init(id: "fullday7", title: String(localized: "Full week"), requirement: String(localized: "Work 8 hours on 7 days"), icon: "checkmark.seal.fill", unlocked: fullDays >= 7, progress: progressText(String(fullDays), String(localized: "7 8-hour days"))),
            .init(id: "fullday30", title: String(localized: "Full month"), requirement: String(localized: "Work 8 hours on 30 days"), icon: "target", unlocked: fullDays >= 30, progress: progressText(String(fullDays), String(localized: "30 8-hour days"))),
            .init(id: "bigmonth3", title: String(localized: "Quarter of hundreds"), requirement: String(localized: "Work 100 hours in 3 calendar months"), icon: "calendar.badge.checkmark", unlocked: bigMonths >= 3, progress: progressText(String(bigMonths), String(localized: "3 100-hour months"))),
            .init(id: "bigmonth12", title: String(localized: "Year of hundreds"), requirement: String(localized: "Work 100 hours in 12 calendar months"), icon: "calendar.badge.clock", unlocked: bigMonths >= 12, progress: progressText(String(bigMonths), String(localized: "12 100-hour months"))),
            .init(id: "streak90", title: String(localized: "Season streak"), requirement: String(localized: "Reach a 90-day streak"), icon: "flame.circle.fill", unlocked: longestStreak >= 90, progress: progressText(String(longestStreak), String(localized: "90 days"))),
            .init(id: "streak180", title: String(localized: "Half-year fire"), requirement: String(localized: "Reach a 180-day streak"), icon: "sun.max.fill", unlocked: longestStreak >= 180, progress: progressText(String(longestStreak), String(localized: "180 days"))),
            .init(id: "streak365", title: String(localized: "Year-round"), requirement: String(localized: "Reach a 365-day streak"), icon: "globe.americas.fill", unlocked: longestStreak >= 365, progress: progressText(String(longestStreak), String(localized: "365 days"))),
            .init(id: "active250", title: String(localized: "Always on"), requirement: String(localized: "Work on 250 different days"), icon: "calendar.badge.clock", unlocked: daily.count >= 250, progress: progressText(String(daily.count), String(localized: "250 active days"))),
            .init(id: "active500", title: String(localized: "Permanent practice"), requirement: String(localized: "Work on 500 different days"), icon: "calendar.circle.fill", unlocked: daily.count >= 500, progress: progressText(String(daily.count), String(localized: "500 active days"))),
            .init(id: "xp50", title: String(localized: "XP architect"), requirement: String(localized: "Earn 50,000 XP"), icon: "star.circle.fill", unlocked: xp >= 50_000, progress: progressText(String(xp), String(localized: "50,000 XP"))),
            .init(id: "xp100", title: String(localized: "XP legend"), requirement: String(localized: "Earn 100,000 XP"), icon: "sparkles", unlocked: xp >= 100_000, progress: progressText(String(xp), String(localized: "100,000 XP")))
        ] + collectionBadges
    }

    private func progressText(_ current: String, _ target: String) -> String { current + " / " + target }
}
