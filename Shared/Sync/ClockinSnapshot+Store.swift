import Foundation

extension ClockinSnapshot {
    @MainActor
    init(store: ClockStore, at date: Date = .now, theme: ClockinThemeChoice = .carbon) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        // Calisan kazanci cikarmak iki farkli saati karistirip widget'i yeniletiyordu.
        let completed = store.completedTotals(on: date)
        self.init(
            day: day,
            completedToday: completed.duration,
            earnedToday: max(0, (completed.earnings * 100).rounded() / 100),
            running: store.running,
            hourlyRate: store.currentRate(at: date),
            currencyCode: store.currencyCode,
            theme: theme
        )
    }

}
