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
    var theme: ClockinThemeChoice = .carbon
    var isAngry = false

    static let empty = ClockinSnapshot(
        day: .distantPast, completedToday: 0, earnedToday: 0,
        running: nil, hourlyRate: 0, currencyCode: "USD"
    )
}

extension ClockinSnapshot {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Date.self, forKey: .day)
        completedToday = try container.decode(TimeInterval.self, forKey: .completedToday)
        earnedToday = try container.decode(Double.self, forKey: .earnedToday)
        running = try container.decodeIfPresent(RunningSession.self, forKey: .running)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        isAngry = try container.decodeIfPresent(Bool.self, forKey: .isAngry) ?? false
        // Eski dosyalarda tema yok; kullanicinin widget verisi kaybolmasin.
        theme = try container.decodeIfPresent(ClockinThemeChoice.self, forKey: .theme) ?? .carbon
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

    /// Calisan seans icin widget girdilerinin zamanlari, bir saatlik.
    ///
    /// Sure metni kendisi sayar, tutar sayamaz; her girdi o anin tutarini
    /// yazar. Dakikada bir girdi, devam ettirmeden ya da clock in'den sonra
    /// tutari tam bir dakika donuk birakiyordu ve widget bozuk gorunuyordu.
    /// Bu yuzden ilk iki dakika bes saniyede bir, onuncu dakikaya kadar on
    /// bes saniyede bir, sonra dakikada bir. Girdiler onceden uretildigi icin
    /// sistemin yenileme butcesinden dusmez; saat dolunca bir kez yenilenir.
    static func runningTimelineDates(from now: Date) -> [Date] {
        var offsets: [TimeInterval] = []
        // Her girdi widget'i yeniden cizdirir; bes saniyelik adimlar sayac
        // calistikca telefonu isitiyordu. Kurus hassasiyeti icin bu yeterli.
        offsets += stride(from: 0, to: 120, by: 15).map { $0 }
        offsets += stride(from: 120, to: 600, by: 30).map { $0 }
        offsets += stride(from: 600, to: 3600, by: 60).map { $0 }
        return offsets.map { now.addingTimeInterval($0) }
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
