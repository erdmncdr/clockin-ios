import Foundation

struct WorkSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var start: Date
    var end: Date
    var duration: TimeInterval
    var note: String
    var hourlyRate: Double
    var source: String
    var matchedExternalSource: String? = nil

    var earnings: Double { duration / 3600 * hourlyRate }

    var hasValidDuration: Bool {
        SessionDuration.isValid(duration)
            && SessionDuration.isValidDate(start) && SessionDuration.isValidDate(end)
            && end >= start
    }
}

struct RateRule: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var effectiveFrom: Date
    /// Inclusive end date for a manually bounded period. Nil means open-ended.
    var effectiveUntil: Date?
    var hourlyRate: Double

    init(id: UUID = UUID(), effectiveFrom: Date, effectiveUntil: Date? = nil, hourlyRate: Double) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.hourlyRate = hourlyRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        effectiveFrom = try container.decode(Date.self, forKey: .effectiveFrom)
        effectiveUntil = try container.decodeIfPresent(Date.self, forKey: .effectiveUntil)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
    }

    func applies(to date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard date >= effectiveFrom else { return false }
        guard let effectiveUntil else { return true }
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: effectiveUntil)) ?? effectiveUntil
        return date < endExclusive
    }
}

struct RunningSession: Codable, Equatable, Sendable {
    var start: Date
    var accumulated: TimeInterval
    var resumedAt: Date?
    var note: String

    var isPaused: Bool { resumedAt == nil }

    func elapsed(at date: Date = .now) -> TimeInterval {
        let additional = resumedAt.map { SessionDuration.clamped(date.timeIntervalSince($0)) } ?? 0
        return SessionDuration.clamped(SessionDuration.clamped(accumulated) + additional)
    }

    func hasValidDuration(at date: Date = .now) -> Bool {
        guard SessionDuration.isValid(accumulated), SessionDuration.isValidDate(start),
              SessionDuration.isValidDate(date) else { return false }
        guard let resumedAt else { return true }
        guard SessionDuration.isValidDate(resumedAt), resumedAt >= start else { return false }
        return SessionDuration.isValid(accumulated + max(0, date.timeIntervalSince(resumedAt)))
    }
}

struct ClockinData: Codable, Sendable {
    var hourlyRate: Double = 25
    var currencyCode: String = "USD"
    var running: RunningSession?
    var sessions: [WorkSession] = []
    var pinVisible: Bool = false
    var rateRules: [RateRule]?
}

extension ClockinData {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        running = try container.decodeIfPresent(RunningSession.self, forKey: .running)
        sessions = try container.decode([WorkSession].self, forKey: .sessions)
        pinVisible = try container.decode(Bool.self, forKey: .pinVisible)
        rateRules = try container.decodeIfPresent([RateRule].self, forKey: .rateRules)
        // Disk ve yedek ayni kurali kullanmali; bozuk sureler yayimlanan
        // store verisine girdikten sonra duzeltilirse aynalar da etkilenir.
        guard sessions.allSatisfy(\.hasValidDuration), running?.hasValidDuration() ?? true else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Invalid session duration or dates."
            ))
        }
    }
}

/// Elle girilen ya da duzenlenen kaydin saatleri. Duzenleyici onizlemesi ile
/// magaza ayni hesabi kullanir; ikisi ayri hesaplayinca ekranda gorulen sure
/// kaydedilenden farkli cikiyordu.
enum EntryTimes {
    /// Resolve the editor's day and minute-resolution controls into the
    /// exact timestamps used for preview, overlap checks, and saving.
    static func editorTimes(day: Date, startTime: Date, endTime: Date,
                            replacing old: WorkSession?, calendar: Calendar = .current) -> (start: Date, end: Date) {
        func combine(_ time: Date) -> Date {
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            let clock = calendar.dateComponents([.hour, .minute], from: time)
            components.hour = clock.hour
            components.minute = clock.minute
            return calendar.date(from: components) ?? day
        }
        let start = combine(startTime)
        // Existing entries expose an explicit end date in the editor. Only
        // new entries infer overnight work from time-only controls.
        let resolvedEnd = old == nil
            ? end(start: start, end: combine(endTime), calendar: calendar)
            : (calendar.dateInterval(of: .minute, for: endTime)?.start ?? endTime)
        if let old,
           calendar.isDate(start, equalTo: old.start, toGranularity: .minute),
           calendar.isDate(resolvedEnd, equalTo: old.end, toGranularity: .minute) {
            return (old.start, old.end)
        }
        return (start, resolvedEnd)
    }

    /// Bitis baslangictan onceyse ertesi gundur. Takvim gunu eklenir, 24 saat
    /// degil: saat geri alinan gecede 22:00-06:00 dokuz saattir.
    static func end(start: Date, end: Date, calendar: Calendar) -> Date {
        guard end < start else { return end }
        return calendar.date(byAdding: .day, value: 1, to: end) ?? end.addingTimeInterval(86_400)
    }

    /// Kaydedilecek calisilan sure. Yeni kayit araligin tamamidir. Saatleri
    /// degismeyen kayit suresini korur; saatleri degisen kayit, duraklatma ya
    /// da dis kaynak yuzunden aralikla sure arasindaki farki korur. Sonuc
    /// sifir ya da negatifse bu saatler kaydin molasindan kisadir.
    static func workedDuration(start: Date, end: Date, replacing old: WorkSession?) -> TimeInterval {
        guard let old else { return end.timeIntervalSince(start) }
        guard start != old.start || end != old.end else { return old.duration }
        let gap = old.end.timeIntervalSince(old.start) - old.duration
        return end.timeIntervalSince(start) - gap
    }
}

enum DurationText {
    static func clock(_ interval: TimeInterval) -> String {
        let seconds = Int(SessionDuration.clamped(interval))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    static func compact(_ interval: TimeInterval) -> String {
        let minutes = Int(SessionDuration.clamped(interval) / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

enum SessionDuration {
    /// 100 yillik sure siniri, 999 saat 59 dakika girisine ve gecmis toplamlarina
    /// yer birakir; bozuk verinin tarih ve tamsayi hesaplarini tasirmasini onler.
    static let maximum: TimeInterval = 100 * 365 * 86_400

    static func isValid(_ interval: TimeInterval) -> Bool {
        interval.isFinite && interval >= 0 && interval <= maximum
    }

    static func clamped(_ interval: TimeInterval) -> TimeInterval {
        if interval.isNaN || interval <= 0 { return 0 }
        return min(interval, maximum)
    }

    static func clockInElapsed(_ interval: TimeInterval) -> TimeInterval? {
        guard interval.isFinite, abs(interval) <= maximum else { return nil }
        return max(0, interval)
    }

    static func isValidDate(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite && date >= .distantPast && date <= .distantFuture
    }
}

enum LiveTimerRange {
    /// Geriye alinmis baslangic yedi gunu asabilir. Bitisi simdiden en az
    /// yedi gun ileri tutmak, geciken widget yenilemelerinde sayaci durdurmaz.
    static func interval(from origin: Date, at date: Date = .now) -> ClosedRange<Date> {
        origin...max(origin, date).addingTimeInterval(7 * 86_400)
    }
}

extension Double {
    /// Ekranda saniyede onlarca kez cagriliyor. `NumberFormatter` her
    /// cagrida yeniden kuruluyordu; `FormatStyle` deger tipi oldugu icin
    /// ayni ciktiyi kurulum maliyeti olmadan uretir.
    func money(code: String, maxFractionDigits: Int = 2) -> String {
        let maximum = max(0, maxFractionDigits)
        let minimum = min(2, maximum)
        return formatted(.currency(code: code).precision(.fractionLength(minimum...maximum)))
    }
}

// Hem Insights hem hatirlaticilar, sifir sureli kayit gununu da sayar.
enum WorkedDayStreak {
    static func length(endingOn day: Date, days: Set<Date>, calendar: Calendar) -> Int {
        var cursor = calendar.startOfDay(for: day)
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor), previous < cursor else { break }
            cursor = previous
        }
        return count
    }
}
