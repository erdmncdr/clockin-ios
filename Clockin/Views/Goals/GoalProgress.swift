import Foundation

/// Bir hedefin o anki durumu. Bugun ekranindaki cubuklar ve testler ayni
/// hesabi kullanir.
struct GoalProgress: Equatable {
    let worked: TimeInterval
    let target: TimeInterval

    /// `hours` sifir, negatif ya da gecersizse hedef yoktur.
    init?(worked: TimeInterval, hours: Double) {
        guard hours.isFinite, hours > 0 else { return nil }
        self.worked = max(0, worked.isFinite ? worked : 0)
        self.target = hours * 3600
    }

    var fraction: Double { min(worked / target, 1) }
    var isReached: Bool { worked >= target }
    var remaining: TimeInterval { max(0, target - worked) }

    /// Ayin tamamlanmis gunleri ve calisan seans. Mac'teki ay toplamiyla ayni
    /// kural: seans basladigi aya sayilir.
    static func monthWorked(daily: [Date: TimeInterval], active: TimeInterval,
                            now: Date, calendar: Calendar) -> TimeInterval {
        daily.reduce(0) { sum, entry in
            calendar.isDate(entry.key, equalTo: now, toGranularity: .month) ? sum + entry.value : sum
        } + active
    }

    /// Bir sonraki adim cizgisine gider: yarim saatlik adimla 7,3'ten yukari
    /// 7,5, asagi 7. Tam cizgideyse bir adim ilerler. Sinirlar asilmaz.
    static func stepped(_ hours: Double, by step: Double, maximum: Double) -> Double {
        let size = abs(step)
        guard size > 0 else { return hours }
        let current = hours.isFinite ? min(max(hours, 0), maximum) : 0
        let position = current / size
        let line = step > 0 ? (position + 1e-9).rounded(.down) + 1
                            : (position - 1e-9).rounded(.up) - 1
        return min(max((line * size * 100).rounded() / 100, 0), maximum)
    }

    /// "7,5" ve "7.5" ikisi de 7,5 saat. Bos, gecersiz ya da sinir disi girdi
    /// nil doner, cagiran eski degeri korur.
    static func parseHours(_ text: String, maximum: Double) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite,
              value >= 0, value <= maximum else { return nil }
        return (value * 100).rounded() / 100
    }
}

struct MonthlyGoalPace {
    let dailyAverage: TimeInterval
    let daysLeft: Int

    init(recentCompleted: TimeInterval, now: Date, calendar: Calendar) {
        dailyAverage = max(0, recentCompleted) / 7
        let today = calendar.startOfDay(for: now)
        let end = calendar.dateInterval(of: .month, for: now)!.end
        daysLeft = calendar.dateComponents([.day], from: today, to: end).day ?? 0
    }

    static func includes(start: Date, now: Date) -> Bool {
        start >= now.addingTimeInterval(-7 * 86_400) && start <= now
    }

    func projection(worked: TimeInterval) -> TimeInterval? {
        guard dailyAverage > 0 else { return nil }
        // Bugun zaten toplamda; tahmin yarindan ay sonuna kalan gunleri ekler.
        return worked + dailyAverage * Double(max(0, daysLeft - 1))
    }
}

enum GoalPrompt {
    static let dismissedKey = "Clockin.GoalPromptDismissedAt"
    static let configuredKey = "Clockin.HasConfiguredGoal"

    static func hasGoal(daily: Double, monthly: Double) -> Bool { daily > 0 || monthly > 0 }

    static func isVisible(daily: Double, monthly: Double, everConfigured: Bool,
                          completedSessions: Int, dismissedAt: Date?, now: Date,
                          calendar: Calendar = .current) -> Bool {
        guard !everConfigured, !hasGoal(daily: daily, monthly: monthly), completedSessions > 0 else { return false }
        guard let dismissedAt else { return true }
        let retry = calendar.date(byAdding: .day, value: 7, to: dismissedAt)!
        return now >= retry
    }
}
