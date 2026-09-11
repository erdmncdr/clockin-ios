import Foundation

/// Widget'in okudugu ozet.
///
/// Ucret kurallari ve gunluk toplamlar uygulamada `ClockStore` ile hesaplanip
/// buraya yazilir. Widget oturum listesini okuyup ayni hesabi ikinci kez
/// yapmaz; iki kopya zamanla birbirinden ayrisirdi.
struct ClockinSnapshot: Codable, Equatable, Sendable {
    /// Toplamlarin hesaplandigi gunun baslangici.
    var day: Date
    /// Yalnizca tamamlanmis oturumlar; calisan seans ayrica eklenir.
    var completedToday: TimeInterval
    var earnedToday: Double
    var running: RunningSession?
    /// Su an gecerli saatlik ucret.
    var hourlyRate: Double
    var currencyCode: String

    static let empty = ClockinSnapshot(
        day: .distantPast, completedToday: 0, earnedToday: 0,
        running: nil, hourlyRate: 0, currencyCode: "USD"
    )
}

extension ClockinSnapshot {
    @MainActor
    init(store: ClockStore, at date: Date = .now) {
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
            currencyCode: store.currencyCode
        )
    }

    /// `ClockStore` ile ayni kural: calisan seans yalnizca bugun basladiysa
    /// bugune sayilir.
    func runningCountsToday(at date: Date) -> Bool {
        guard let running else { return false }
        return Calendar.current.isDate(running.start, inSameDayAs: date)
    }

    /// Ozet dunden kaldiysa tamamlanmis toplamlar bugune ait degildir.
    private func isSameDay(_ date: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: date)
    }

    func todayDuration(at date: Date) -> TimeInterval {
        let completed = isSameDay(date) ? completedToday : 0
        let active = runningCountsToday(at: date) ? (running?.elapsed(at: date) ?? 0) : 0
        return completed + active
    }

    func todayEarnings(at date: Date) -> Double {
        let completed = isSameDay(date) ? earnedToday : 0
        let active = runningCountsToday(at: date) ? (running?.elapsed(at: date) ?? 0) / 3600 * hourlyRate : 0
        return completed + active
    }

    static func load(from url: URL = AppGroup.snapshotURL) -> ClockinSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ClockinSnapshot.self, from: data)
    }

    func write(to url: URL = AppGroup.snapshotURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
