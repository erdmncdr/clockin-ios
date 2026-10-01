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

enum SessionDisplay {
    static var timecardEntry: String { String(localized: "Timecard entry", bundle: .app) }

    static func isClockin(_ session: WorkSession) -> Bool { session.source == "Clockin" }

    static func isMatched(_ session: WorkSession) -> Bool {
        guard let matched = session.matchedExternalSource, !matched.isEmpty else { return false }
        return matched != session.source
    }

    static func note(_ session: WorkSession) -> String {
        // Yapistirici kaynak adini nota da ekler; diskteki metin korunur.
        for source in [session.source, session.matchedExternalSource].compactMap({ $0 }) where !source.isEmpty {
            let suffix = " • \(source)"
            guard session.note.hasSuffix(suffix) else { continue }
            let status = String(session.note.dropLast(suffix.count))
            if ["approved", "submitted", "draft", "unapproved", "imported"].contains(status.lowercased()) {
                return status
            }
        }
        return session.note
    }

    static func storedNote(_ editedNote: String, for session: WorkSession) -> String {
        editedNote == note(session) ? session.note : editedNote
    }

    static func subtitle(_ session: WorkSession) -> String {
        if isMatched(session) { return String(localized: "Matched timecard", bundle: .app) }
        let note = note(session)
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return note }
        return isClockin(session) ? "Clockin" : String(localized: "Imported timecard", bundle: .app)
    }
}

enum RateHistorySummary: Equatable {
    case single(Double)
    case changed(earlier: Double, current: Double, on: Date)
    case custom
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

// Bildirim karari sayacin yasina degil, verinin gelis yoluna dayanir.
enum RunningApplyProvenance: Sendable {
    case remoteChange
    case initialImport
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

struct ClockinData: Codable, Equatable, Sendable {
    var hourlyRate: Double = 25
    var currencyCode: String = "USD"
    var running: RunningSession?
    var sessions: [WorkSession] = []
    var pinVisible: Bool = false
    var rateRules: [RateRule]?
}

extension ClockinData {
    init(from decoder: any Decoder) throws {
        try self.init(from: decoder, validatingDurations: true)
    }

    fileprivate init(from decoder: any Decoder, validatingDurations: Bool) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        running = try container.decodeIfPresent(RunningSession.self, forKey: .running)
        sessions = try container.decode([WorkSession].self, forKey: .sessions)
        pinVisible = try container.decode(Bool.self, forKey: .pinVisible)
        rateRules = try container.decodeIfPresent([RateRule].self, forKey: .rateRules)
        // Kati okuyucular yedegi butun olarak dogrular.
        guard !validatingDurations || (sessions.allSatisfy(\.hasValidDuration)
                                      && (running?.hasValidDuration() ?? true)) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Invalid session duration or dates."
            ))
        }
    }
}

/// Sure hatalarini ayirir; sema hatalari yine tum okumayi durdurur.
struct ClockinArchive {
    let data: ClockinData
    let quarantine: Data?
    let rejectedCount: Int

    static func read(_ bytes: Data, at date: Date = .now) throws -> Self {
        struct Unchecked: Decodable {
            let data: ClockinData
            init(from decoder: any Decoder) throws {
                data = try ClockinData(from: decoder, validatingDurations: false)
            }
        }
        var data = try JSONDecoder().decode(Unchecked.self, from: bytes).data
        var seen = Set<UUID>()
        let rejected = data.sessions.indices.filter {
            !data.sessions[$0].hasValidDuration || !seen.insert(data.sessions[$0].id).inserted
        }
        let rejectRunning = data.running.map { !$0.hasValidDuration(at: date) } ?? false
        let count = rejected.count + (rejectRunning ? 1 : 0)
        guard count > 0 else { return Self(data: data, quarantine: nil, rejectedCount: 0) }
        // Bilinmeyen alanlar, sayi yazimi ve bosluklar da aynen korunur.
        var scanner = ArchiveJSONSlices(bytes)
        let fields = try scanner.object()
        guard let sessions = fields["sessions"] else { throw CocoaError(.fileReadCorruptFile) }
        var rows = ArchiveJSONSlices(sessions)
        let entries = try rows.array()
        guard entries.count == data.sessions.count else { throw CocoaError(.fileReadCorruptFile) }
        var quarantine = Data("{\"sessions\":[".utf8)
        for (offset, index) in rejected.enumerated() {
            if offset > 0 { quarantine.append(contentsOf: ",".utf8) }
            quarantine.append(entries[index])
        }
        quarantine.append(contentsOf: "],\"running\":".utf8)
        if rejectRunning, let running = fields["running"] { quarantine.append(running) }
        else { quarantine.append(contentsOf: "null".utf8) }
        quarantine.append(contentsOf: "}".utf8)
        let rejectedIndices = Set(rejected)
        data.sessions = data.sessions.enumerated().compactMap { rejectedIndices.contains($0.offset) ? nil : $0.element }
        if rejectRunning { data.running = nil }
        return Self(data: data, quarantine: quarantine, rejectedCount: count)
    }
}

// Yalnizca decoder'in dogruladigi JSON'dan ham deger dilimleri alir.
private struct ArchiveJSONSlices {
    let bytes: [UInt8]
    var index = 0
    init(_ data: Data) { bytes = Array(data) }

    mutating func whitespace() {
        while index < bytes.count, [9, 10, 13, 32].contains(bytes[index]) { index += 1 }
    }
    mutating func consume(_ byte: UInt8) throws {
        whitespace()
        guard index < bytes.count, bytes[index] == byte else { throw CocoaError(.fileReadCorruptFile) }
        index += 1
    }
    mutating func value() throws -> Data {
        whitespace()
        let start = index
        var depth = 0
        var quoted = false
        var escaped = false
        while index < bytes.count {
            let byte = bytes[index]
            if quoted {
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { quoted = false }
            } else {
                if depth == 0, [44, 58, 93, 125, 9, 10, 13, 32].contains(byte) { break }
                if byte == 34 { quoted = true }
                else if byte == 91 || byte == 123 { depth += 1 }
                else if byte == 93 || byte == 125 { depth -= 1 }
            }
            index += 1
        }
        guard index > start, depth == 0, !quoted else { throw CocoaError(.fileReadCorruptFile) }
        return Data(bytes[start..<index])
    }
    mutating func object() throws -> [String: Data] {
        try consume(123)
        var fields: [String: Data] = [:]
        whitespace()
        while index < bytes.count, bytes[index] != 125 {
            let key = try JSONDecoder().decode(String.self, from: value())
            try consume(58)
            let raw = try value()
            // Decoder ile belirsiz bir esleme yapmamak icin yinelenen anahtari reddet.
            guard fields[key] == nil else { throw CocoaError(.fileReadCorruptFile) }
            fields[key] = raw
            whitespace()
            if index < bytes.count, bytes[index] == 125 { break }
            try consume(44)
        }
        try consume(125)
        return fields
    }
    mutating func array() throws -> [Data] {
        try consume(91)
        var entries: [Data] = []
        whitespace()
        while index < bytes.count, bytes[index] != 93 {
            entries.append(try value())
            whitespace()
            if index < bytes.count, bytes[index] == 93 { break }
            try consume(44)
        }
        try consume(93)
        return entries
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
        // Sayilar metin olarak gomulur: yerellestirilmis tam sayi binlik ayraci
        // alir ve 876000h, 876.000h olurdu.
        if minutes < 60 { return String(localized: "\(String(minutes))m", bundle: .app) }
        let hours = String(minutes / 60)
        let remainder = minutes % 60
        return remainder == 0 ? String(localized: "\(hours)h", bundle: .app) : String(localized: "\(hours)h \(String(remainder))m", bundle: .app)
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
        let date = SessionDuration.isValidDate(date) ? date : .distantPast
        let origin = SessionDuration.isValidDate(origin) ? origin : date
        return origin...max(origin, date).addingTimeInterval(7 * 86_400)
    }
}

extension Double {
    /// Ekranda saniyede onlarca kez cagriliyor. `NumberFormatter` her
    /// cagrida yeniden kuruluyordu; `FormatStyle` deger tipi oldugu icin
    /// ayni ciktiyi kurulum maliyeti olmadan uretir.
    func money(code: String, maxFractionDigits: Int = 2) -> String {
        let maximum = min(20, max(0, maxFractionDigits))
        let minimum = min(2, maximum)
        return formatted(.currency(code: code).precision(.fractionLength(minimum...maximum)))
    }
}

extension Int {
    // Double(Int.max) yukariya yuvarlanir; Int'e cevirmeden once karsilastir.
    init(clampingFinite value: Double) {
        if value.isNaN { self = 0 }
        else if value >= Double(Int.max) { self = .max }
        else if value <= Double(Int.min) { self = .min }
        else { self = Int(value) }
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
