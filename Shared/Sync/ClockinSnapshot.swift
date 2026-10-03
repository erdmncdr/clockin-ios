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
    var font: ClockinFontChoice = .system
    var isAngry = false
    var companionFriendly = false
    var companionLastWorkedDay: Date?
    var companionProudUntil: Date?
    var wardrobeJSON: String?
    var companionAccessoryID: String?

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
        companionFriendly = try container.decodeIfPresent(Bool.self, forKey: .companionFriendly) ?? false
        companionLastWorkedDay = try container.decodeIfPresent(Date.self, forKey: .companionLastWorkedDay)
        companionProudUntil = try container.decodeIfPresent(Date.self, forKey: .companionProudUntil)
        wardrobeJSON = try container.decodeIfPresent(String.self, forKey: .wardrobeJSON)
        companionAccessoryID = try container.decodeIfPresent(String.self, forKey: .companionAccessoryID)
        // Eski dosyalarda tema yok; kullanicinin widget verisi kaybolmasin.
        theme = try container.decodeIfPresent(ClockinThemeChoice.self, forKey: .theme) ?? .carbon
        font = try container.decodeIfPresent(ClockinFontChoice.self, forKey: .font) ?? .system
        guard SessionDuration.isValidDate(day), SessionDuration.isValid(completedToday),
              earnedToday.isFinite, hourlyRate.isFinite, hourlyRate >= 0,
              running?.hasValidDuration() ?? true,
              companionLastWorkedDay.map(SessionDuration.isValidDate) ?? true,
              companionProudUntil.map(SessionDuration.isValidDate) ?? true else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                   debugDescription: "Invalid widget snapshot values"))
        }
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
    /// Sureyi sistem sayar; para her girdide yeniden hesaplanir. Ilk degisim
    /// 30 saniyede, sonra en gec iki dakikada gelir. Tek girdiye dusurmek
    /// parayi dondurur; 74 girdiyi arsivlemek ise widget butcesini asiyordu.
    static func runningTimelineDates(from now: Date) -> [Date] {
        let offsets: [TimeInterval] = [0, 30, 60] + Array(stride(from: 120.0, through: 3600, by: 120))
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
