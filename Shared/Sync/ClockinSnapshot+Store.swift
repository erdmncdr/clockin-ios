import Foundation

extension ClockinSnapshot {
    @MainActor
    init(store: ClockStore, at date: Date = .now, theme: ClockinThemeChoice = .carbon) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let activeEarnings = store.running.map {
            calendar.isDate($0.start, inSameDayAs: date) ? store.currentEarnings(at: date) : 0
        } ?? 0
        // Kurus hassasiyetine yuvarlanir: calisan seansin milisaniyelik payi
        // her seferinde farkli bir deger uretip ayni ozeti yeniden yazdiriyordu.
        let earned = ((store.earnings(on: date) - activeEarnings) * 100).rounded() / 100
        self.init(
            day: day,
            completedToday: store.dailyDurations[day] ?? 0,
            earnedToday: max(0, earned),
            running: store.running,
            hourlyRate: store.effectiveRate(at: date, fallback: store.hourlyRate),
            currencyCode: store.currencyCode,
            theme: theme
        )
    }

}
