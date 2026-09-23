import Foundation

enum StatsSharePrivacy: String, CaseIterable, Identifiable {
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
    case publicStats = "Public"
    case privateStats = "Private"
    var id: Self { self }
}

enum StatsSharePage: String, CaseIterable, Identifiable {
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
    case overview = "Overview", rhythm = "Rhythm", milestones = "Milestones"
    var id: Self { self }
}

enum StatsShareMode: String, CaseIterable, Identifiable {
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
    case current = "Current page", all = "All 3"
    var id: Self { self }
    func pages(current: StatsSharePage) -> [StatsSharePage] {
        self == .all ? StatsSharePage.allCases : [current]
    }
}

// Ham degerler kimliktir; ekranda ve paylasilan resimde title gorunur.
enum StatsShareField: String, CaseIterable {
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
    case time = "Time invested", earnings = "Earned", sessions = "Sessions"
    case activeDays = "Active days", streak = "Streak", badges = "Badges", xp = "Total XP"
    case bestDay = "Best day", bestDayDuration = "Best day duration", longestStreak = "Best streak"
    case weekday = "Best weekday", hour = "Power hour", level = "Level"
    case fullDays = "8-hour days", longDays = "10-hour days", bigMonths = "100-hour months", momentum = "Momentum"
}

struct StatsShareRow: Equatable, Identifiable {
    let field: StatsShareField
    let value: String
    var id: StatsShareField { field }
}

enum StatsShareFields {
    // Gizli degerler gorunumde saklanmaz; onizleme ve PNG ayni secilmis satirlari kullanir.
    static func rows(page: StatsSharePage, privacy: StatsSharePrivacy,
                     values: [StatsShareField: String]) -> [StatsShareRow] {
        let fields: [StatsShareField]
        switch page {
        case .overview:
            fields = privacy == .publicStats
                ? [.time, .earnings, .sessions, .activeDays, .streak]
                : [.streak, .badges, .xp]
        case .rhythm:
            fields = [.bestDay, .longestStreak, .activeDays, .weekday, .hour, .sessions]
        case .milestones:
            fields = [.level, .xp, .badges, .fullDays, .longDays, .bigMonths, .momentum]
        }
        return fields.map { field in
            var value = values[field] ?? String(localized: "No sessions")
            if field == .bestDay, privacy == .publicStats,
               values[.bestDay] != nil, let duration = values[.bestDayDuration] {
                value += " • " + duration
            }
            return StatsShareRow(field: field, value: value)
        }
    }
}
