import Foundation

// Synthetic data only. Never opens a real user's archive or preferences for fixtures.
// The four private models below are exact copies of the old Mac Models.swift,
// with only private access and Mac-prefixed type names changed (2026-09-29).
// The private CSV parser is likewise copied to prove the external-input path.

private struct MacWorkSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var start: Date
    var end: Date
    var duration: TimeInterval
    var note: String
    var hourlyRate: Double
    var source: String
    var matchedExternalSource: String? = nil

    var earnings: Double { duration / 3600 * hourlyRate }
}

private struct MacRateRule: Codable, Identifiable, Hashable, Sendable {
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

private struct MacRunningSession: Codable, Equatable, Sendable {
    var start: Date
    var accumulated: TimeInterval
    var resumedAt: Date?
    var note: String

    var isPaused: Bool { resumedAt == nil }

    func elapsed(at date: Date = .now) -> TimeInterval {
        accumulated + max(0, resumedAt.map { date.timeIntervalSince($0) } ?? 0)
    }
}

private struct MacClockinData: Codable, Sendable {
    var hourlyRate: Double = 25
    var currencyCode: String = "USD"
    var running: MacRunningSession?
    var sessions: [MacWorkSession] = []
    var pinVisible: Bool = false
    var rateRules: [MacRateRule]?
}

private enum MacCSVImportError: LocalizedError {
    case unreadable
    case missingColumns
    case noValidRows

    var errorDescription: String? {
        switch self {
        case .unreadable: "The CSV file could not be read."
        case .missingColumns: "Start Time and End Time columns are required."
        case .noValidRows: "No valid time entries were found."
        }
    }
}

private enum MacCSVImporter {
    static func parse(data: Data, hourlyRate: Double) throws -> [MacWorkSession] {
        guard var text = String(data: data, encoding: .utf8) else { throw MacCSVImportError.unreadable }
        text = text.replacingOccurrences(of: "\u{feff}", with: "")
        let rows = parseRows(text)
        guard let header = rows.first else { throw MacCSVImportError.noValidRows }

        let names = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let startIndex = names.firstIndex(of: "start time"),
              let endIndex = names.firstIndex(of: "end time") else {
            throw MacCSVImportError.missingColumns
        }
        let durationIndex = names.firstIndex(of: "duration")
        let notesIndex = names.firstIndex(of: "notes")
        let sourceIndex = names.firstIndex(of: "time sheet source")

        let sessions = rows.dropFirst().compactMap { row -> MacWorkSession? in
            guard row.indices.contains(startIndex), row.indices.contains(endIndex),
                  let start = parseDate(row[startIndex]), let end = parseDate(row[endIndex]), end >= start else { return nil }

            let measured = end.timeIntervalSince(start)
            let duration: TimeInterval
            if let index = durationIndex, row.indices.contains(index), let milliseconds = Double(row[index]), milliseconds >= 0 {
                duration = milliseconds / 1000
            } else {
                duration = measured
            }

            return MacWorkSession(
                id: UUID(),
                start: start,
                end: end,
                duration: duration,
                note: value(at: notesIndex, in: row),
                hourlyRate: hourlyRate,
                source: value(at: sourceIndex, in: row).isEmpty ? "CSV import" : value(at: sourceIndex, in: row)
            )
        }
        guard !sessions.isEmpty else { throw MacCSVImportError.noValidRows }
        return sessions
    }

    private static func value(at index: Int?, in row: [String]) -> String {
        guard let index, row.indices.contains(index) else { return "" }
        return row[index]
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        return standard.date(from: value)
    }

    static func parseRows(_ text: String) -> [[String]] {
        // Swift treats CRLF as one extended grapheme cluster. Normalize first so
        // Windows-style exports split into rows just like Unix-style CSV files.
        let text = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"": quoted = true
                case ",": row.append(field); field = ""
                case "\n":
                    row.append(field); field = ""
                    if !row.allSatisfy({ $0.isEmpty }) { rows.append(row) }
                    row = []
                case "\r": break
                default: field.append(character)
                }
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

// Exact renamed copy of the old pasted-text parser, for reachable date-bound tests.

private enum MacPastedImportError: LocalizedError {
    case noEntries

    var errorDescription: String? {
        "No time entries were recognized. Copy one or more rows including the date, start time, and end time."
    }
}

private enum MacPastedTextImporter {
    private static let weekdays = Set(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])
    private static let statuses = Set(["approved", "submitted", "draft", "unapproved"])
    private static let ignoredSources = Set(["new", "new entry", "submit selected", "hours", "total", "timecards", "me", "my time"])

    static func parse(_ text: String, hourlyRate: Double, now: Date = .now) throws -> [MacWorkSession] {
        let lines = text.components(separatedBy: .newlines)
            .map(clean)
            .filter { !$0.isEmpty }
        let flattened = lines.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let range = extractDateRange(from: flattened)
        let pattern = #"(?i)\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s*(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})\s+(Approved|Submitted|Draft|Unapproved)\s+(.+?)\s+(\d{1,2}:\d{2})\s+(\d{1,2}:\d{2})(?:\s+(\d+)\s*([MH]))?"#
        if let regex = try? NSRegularExpression(pattern: pattern), !flattened.isEmpty {
            let matches = regex.matches(in: flattened, range: NSRange(flattened.startIndex..., in: flattened))
            let parsed = matches.compactMap { match -> MacWorkSession? in
                func capture(_ position: Int) -> String? {
                    guard let range = Range(match.range(at: position), in: flattened) else { return nil }
                    return String(flattened[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard let monthName = capture(1), let month = monthNumber(monthName),
                      let dayText = capture(2), let dayNumber = Int(dayText),
                      let status = capture(3), let source = capture(4),
                      let startText = capture(5), let endText = capture(6),
                      let day = resolveDate(month: month, day: dayNumber, range: range, now: now) else { return nil }
                return makeSession(day: day, startText: startText, endText: endText,
                                   status: status, source: source, hourlyRate: hourlyRate)
            }
            if !parsed.isEmpty { return parsed }
        }

        var results: [MacWorkSession] = []
        var index = 0

        while index + 1 < lines.count {
            guard weekdays.contains(lines[index].lowercased()),
                  let monthDay = parseMonthDay(lines[index + 1]),
                  let day = resolveDate(month: monthDay.month, day: monthDay.day, range: range, now: now) else {
                index += 1
                continue
            }

            var endIndex = index + 2
            while endIndex < lines.count {
                if endIndex + 1 < lines.count,
                   weekdays.contains(lines[endIndex].lowercased()),
                   parseMonthDay(lines[endIndex + 1]) != nil { break }
                endIndex += 1
            }
            let block = Array(lines[(index + 2)..<endIndex])
            let timePositions = block.indices.filter { parseTime(block[$0]) != nil }
            if timePositions.count >= 2,
               let startParts = parseTime(block[timePositions[0]]),
               let endParts = parseTime(block[timePositions[1]]) {
                let calendar = Calendar.autoupdatingCurrent
                var startComponents = calendar.dateComponents([.year, .month, .day], from: day)
                startComponents.hour = startParts.hour
                startComponents.minute = startParts.minute
                var endComponents = calendar.dateComponents([.year, .month, .day], from: day)
                endComponents.hour = endParts.hour
                endComponents.minute = endParts.minute

                if let start = calendar.date(from: startComponents), var end = calendar.date(from: endComponents) {
                    if end < start { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
                    let status = block.first { statuses.contains($0.lowercased()) } ?? "Imported"
                    let statusPosition = block.firstIndex(of: status)
                    let source = statusPosition.flatMap { position -> String? in
                        let next = position + 1
                        guard block.indices.contains(next), parseTime(block[next]) == nil,
                              !ignoredSources.contains(block[next].lowercased()) else { return nil }
                        return block[next]
                    } ?? "Pasted timecard"
                    results.append(MacWorkSession(
                        id: UUID(), start: start, end: end, duration: end.timeIntervalSince(start),
                        note: "\(status) • \(source)", hourlyRate: hourlyRate, source: source
                    ))
                }
            }
            index = max(index + 1, endIndex)
        }

        guard !results.isEmpty else { throw MacPastedImportError.noEntries }
        return results
    }

    static func approvedSummaryDuration(in text: String) -> TimeInterval? {
        let cleaned = text.replacingOccurrences(of: "**", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let pattern = #"(?i)(\d+)h\s*(\d+)m?\s+Approved\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
              let hoursRange = Range(match.range(at: 1), in: cleaned),
              let minutesRange = Range(match.range(at: 2), in: cleaned),
              let hours = Int(cleaned[hoursRange]), let minutes = Int(cleaned[minutesRange]) else { return nil }
        return TimeInterval(hours * 3600 + minutes * 60)
    }

    private static func makeSession(day: Date, startText: String, endText: String,
                                    status: String, source: String, hourlyRate: Double) -> MacWorkSession? {
        guard let startParts = parseTime(startText), let endParts = parseTime(endText) else { return nil }
        let calendar = Calendar.autoupdatingCurrent
        var startComponents = calendar.dateComponents([.year, .month, .day], from: day)
        startComponents.hour = startParts.hour
        startComponents.minute = startParts.minute
        var endComponents = calendar.dateComponents([.year, .month, .day], from: day)
        endComponents.hour = endParts.hour
        endComponents.minute = endParts.minute
        guard let start = calendar.date(from: startComponents), var end = calendar.date(from: endComponents) else { return nil }
        if end < start { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
        return MacWorkSession(
            id: UUID(), start: start, end: end, duration: end.timeIntervalSince(start),
            note: "\(status) • \(source)", hourlyRate: hourlyRate, source: source
        )
    }

    private static func monthNumber(_ value: String) -> Int? {
        let months = ["january", "february", "march", "april", "may", "june",
                      "july", "august", "september", "october", "november", "december"]
        return months.firstIndex(of: value.lowercased()).map { $0 + 1 }
    }

    private static func clean(_ value: String) -> String {
        value.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseMonthDay(_ value: String) -> (month: Int, day: Int)? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d"
        guard let date = formatter.date(from: value) else { return nil }
        let parts = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return nil }
        return (month, day)
    }

    private static func parseTime(_ value: String) -> (hour: Int, minute: Int)? {
        let pieces = value.split(separator: ":")
        guard pieces.count == 2, let hour = Int(pieces[0]), let minute = Int(pieces[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    private static func extractDateRange(from text: String) -> ClosedRange<Date>? {
        let pattern = #"([A-Z][a-z]{2,8})\s+(\d{1,2}),\s+(\d{4})\s*-\s*([A-Z][a-z]{2,8})\s+(\d{1,2}),\s+(\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 7 else { return nil }
        let values = (1...6).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        guard values.count == 6,
              let start = date(monthName: values[0], day: values[1], year: values[2]),
              let end = date(monthName: values[3], day: values[4], year: values[5]) else { return nil }
        // Aralik ters yazilmissa `start...end` calisma aninda cokuyor. Boyle
        // bir aralik yil cikarmaya da yaramaz, yok sayilir.
        guard start <= end else { return nil }
        return start...end
    }

    private static func date(monthName: String, day: String, year: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d yyyy"
        if let date = formatter.date(from: "\(monthName) \(day) \(year)") { return date }
        formatter.dateFormat = "MMMM d yyyy"
        return formatter.date(from: "\(monthName) \(day) \(year)")
    }

    private static func resolveDate(month: Int, day: Int, range: ClosedRange<Date>?, now: Date) -> Date? {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        if let range {
            let startYear = calendar.component(.year, from: range.lowerBound)
            let endYear = calendar.component(.year, from: range.upperBound)
            for year in startYear...endYear {
                if let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                   candidate >= calendar.startOfDay(for: range.lowerBound),
                   candidate <= calendar.startOfDay(for: range.upperBound) { return candidate }
            }
        }

        let currentYear = calendar.component(.year, from: now)
        guard var candidate = calendar.date(from: DateComponents(year: currentYear, month: month, day: day)) else { return nil }
        if candidate > calendar.date(byAdding: .day, value: 1, to: now) ?? now {
            candidate = calendar.date(byAdding: .year, value: -1, to: candidate) ?? candidate
        }
        return candidate
    }
}

var checks = 0
@MainActor private func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

@MainActor private func run() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("clockin-maccompat-\(UUID().uuidString)")
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    let encoder = JSONEncoder() // Exactly the old Mac's default date/nonfinite strategies.
    let decoder = JSONDecoder()
    let now = Date()
    let start = now.addingTimeInterval(-7200)
    let end = start.addingTimeInterval(3600)
    let session = MacWorkSession(id: UUID(), start: start, end: end, duration: 2700,
                                note: "synthetic", hourlyRate: 42, source: "Clockin")
    let bounded = MacRateRule(effectiveFrom: start.addingTimeInterval(-86400),
                              effectiveUntil: start, hourlyRate: 42)
    let open = MacRateRule(effectiveFrom: now, hourlyRate: 55)
    var baseline = MacClockinData()
    baseline.hourlyRate = 42
    baseline.currencyCode = "TRY"
    baseline.pinVisible = true
    baseline.sessions = [session]
    baseline.rateRules = [bounded, open]

    func directory(_ name: String) throws -> URL {
        let dir = root.appendingPathComponent(name)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    func unreadable(in dir: URL) throws -> [URL] {
        try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("clockin-unreadable-") && $0.pathExtension == "json" }
    }
    // Compare JSON structurally: synthesized Codable is not Equatable and object key order is irrelevant.
    func sameJSON<T: Encodable, U: Encodable>(_ a: T, _ b: U) throws -> Bool {
        let left = try JSONSerialization.jsonObject(with: encoder.encode(a)) as! NSDictionary
        let right = try JSONSerialization.jsonObject(with: encoder.encode(b)) as! NSDictionary
        return left == right
    }
    func accepted(_ name: String, _ fixture: MacClockinData) throws {
        let bytes = try encoder.encode(fixture)
        let decoded = try decoder.decode(ClockinData.self, from: bytes)
        check(try sameJSON(decoded, fixture), "\(name): decoder preserves every Mac field")
        let dir = try directory(name), url = dir.appendingPathComponent("clockin.json")
        try bytes.write(to: url)
        let store = ClockStore(fileURL: url)
        let initialCopies = try unreadable(in: dir)
        check(store.statusMessage == nil && initialCopies.isEmpty,
              "\(name): store loads without unreadable copy")
        if fixture.rateRules == nil {
            let july = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1))!
            check(store.data.rateRules?.count == 1 && store.data.rateRules?.first?.effectiveFrom == july
                  && store.data.rateRules?.first?.hourlyRate == fixture.hourlyRate,
                  "\(name): missing rateRules migrates to July 2026 base rate")
            var migrated = fixture
            migrated.rateRules = try decoder.decode(MacClockinData.self, from: encoder.encode(store.data)).rateRules
            check(try sameJSON(store.data, migrated), "\(name): migration preserves all other fields")
        } else {
            check(try sameJSON(store.data, fixture), "\(name): present rateRules stays unchanged, including empty array")
            check(try Data(contentsOf: url) == bytes, "\(name): initialization does not rewrite scheduled archive")
        }
        // Public save path: retain currency but force an actual atomic store write.
        store.updateCurrency(fixture.currencyCode)
        let saved = try Data(contentsOf: url)
        let oldReadback = try decoder.decode(MacClockinData.self, from: saved)
        check(try sameJSON(oldReadback, store.data), "\(name): store save is lossless for downgrade decoder")
        let reopened = ClockStore(fileURL: url)
        check(try sameJSON(reopened.data, store.data), "\(name): second launch does not repeat rate migration")
        check(try unreadable(in: dir).isEmpty, "\(name): save and reopen leave no unreadable copy")
    }
    func rejected(_ name: String, _ input: MacClockinData, path: String) throws {
        var fixture = input
        var valid = baseline.sessions[0]; valid.id = UUID()
        fixture.sessions.append(valid)
        let bytes = try encoder.encode(fixture)
        _ = try decoder.decode(MacClockinData.self, from: bytes)
        do {
            _ = try decoder.decode(ClockinData.self, from: bytes)
            check(false, "\(name): expected current decoder rejection")
        } catch DecodingError.dataCorrupted(_) {
            check(true, "STRICT DECODER \(name): old Mac encodes/decodes; current decoder rejects [\(path)]")
        }
        let dir = try directory(name), url = dir.appendingPathComponent("clockin.json")
        try bytes.write(to: url)
        let store = ClockStore(fileURL: url)
        let copies = try unreadable(in: dir)
        check(copies.count == 1, "\(name): store creates exactly one unreadable copy")
        check(try Data(contentsOf: copies[0]) == bytes, "\(name): unreadable copy preserves original bytes")
        let raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        let sessions = try decoder.decode([WorkSession].self, from: encoder.encode(fixture.sessions))
        let rejectedIndices = sessions.indices.filter { !sessions[$0].hasValidDuration }
        let running = try fixture.running.map { try decoder.decode(RunningSession.self, from: encoder.encode($0)) }
        let rejectsRunning = running.map { !$0.hasValidDuration() } ?? false
        let count = rejectedIndices.count + (rejectsRunning ? 1 : 0)
        check(store.data.sessions == sessions.filter(\.hasValidDuration)
              && store.running == (rejectsRunning ? nil : running),
              "\(name): valid sessions and running timer survive")
        let quarantines = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("clockin-quarantine-") }
        check(quarantines.count == 1, "\(name): exactly one quarantine file")
        let quarantined = try JSONSerialization.jsonObject(with: Data(contentsOf: quarantines[0])) as! [String: Any]
        let rawSessions = raw["sessions"] as! [Any]
        let expected: [String: Any] = ["sessions": rejectedIndices.map { rawSessions[$0] },
                                       "running": rejectsRunning ? raw["running"]! : NSNull()]
        check(NSDictionary(dictionary: quarantined).isEqual(to: expected), "\(name): only rejected entries are preserved untouched")
        check(store.statusMessage?.hasPrefix("\(count) invalid entries") == true
              && store.statusMessage?.contains(quarantines[0].lastPathComponent) == true,
              "\(name): status reports rejected count and quarantine name")
        check(store.hourlyRate == fixture.hourlyRate && store.currencyCode == fixture.currencyCode
              && store.pinVisible == fixture.pinVisible, "\(name): profile and pin preference survive recovery")
        if fixture.rateRules != nil {
            check(try sameJSON(store.data, {
                var expected = fixture
                expected.sessions = fixture.sessions.enumerated().filter { !rejectedIndices.contains($0.offset) }.map(\.element)
                if rejectsRunning { expected.running = nil }
                return expected
            }()), "\(name): all remaining archive fields survive recovery")
        }
        let reopened = ClockStore(fileURL: url)
        check(reopened.data.sessions == store.data.sessions && reopened.running == store.running
              && reopened.statusMessage == nil, "\(name): repaired archive opens without another warning")
        check(try unreadable(in: dir).count == 1, "\(name): original safety copy remains after save and reopen")
        check(try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("clockin-quarantine-") }.count == 1,
              "\(name): second launch creates no extra quarantine")
    }

    try accepted("scheduled-nonUSD-pinned", baseline)
    var legacy = baseline; legacy.rateRules = nil
    let legacyObject = try JSONSerialization.jsonObject(with: encoder.encode(legacy)) as! [String: Any]
    check(legacyObject["rateRules"] == nil, "pre-schedule fixture truly omits rateRules")
    try accepted("pre-schedule", legacy)
    var empty = MacClockinData(); empty.rateRules = []
    try accepted("empty-archive", empty) // Valid JSON with zero sessions, not zero bytes.
    var emptyLegacy = empty; emptyLegacy.rateRules = nil
    try accepted("empty-pre-schedule", emptyLegacy)
    var running = baseline
    running.running = MacRunningSession(start: start, accumulated: 1200, resumedAt: end, note: "synthetic running")
    try accepted("running", running)
    running.running?.resumedAt = nil
    try accepted("paused", running)
    let csv = "Start Time,End Time,Duration,Notes,Time Sheet Source\n2026-03-04T09:00:00Z,2026-03-04T10:00:00Z,2700000,synthetic,timecard\n"
    var imported = baseline
    imported.sessions = try MacCSVImporter.parse(data: Data(csv.utf8), hourlyRate: 42)
    imported.sessions[0].matchedExternalSource = imported.sessions[0].source
    try accepted("csv-imported", imported)
    imported.sessions[0].source = "Clockin"
    try accepted("csv-matched-local", imported)
    var zero = baseline; zero.sessions[0].end = start; zero.sessions[0].duration = 0
    try accepted("zero-duration", zero)
    var longer = baseline; longer.sessions[0].duration = 7200
    try accepted("duration-exceeds-wall-span", longer)

    // Real user paths: backwards system clock while clocking out or resuming.
    var backwards = baseline
    backwards.sessions[0].end = start.addingTimeInterval(-60)
    backwards.sessions[0].duration = 0 // Mac RunningSession.elapsed clamps negative additional time.
    try rejected("clock-out-after-clock-rollback", backwards, path: "Mac ClockStore.swift:192-202 clockOut")
    var resume = baseline
    resume.running = MacRunningSession(start: start, accumulated: 0,
                                       resumedAt: start.addingTimeInterval(-60), note: "synthetic")
    try rejected("resume-before-start", resume, path: "Mac ClockStore.swift:183-188 resume")

    // Actual CSV parser accepts finite duration milliseconds with no 100-year cap.
    let huge = SessionDuration.maximum + 3600
    var csvHuge = baseline
    csvHuge.sessions = try MacCSVImporter.parse(data: Data(csv.replacingOccurrences(of: "2700000", with: String(huge * 1000)).utf8), hourlyRate: 42)
    csvHuge.sessions[0].matchedExternalSource = csvHuge.sessions[0].source
    check(csvHuge.sessions[0].duration == huge, "old CSV parser admits a finite duration over 100 years")
    try rejected("csv-over-100-years", csvHuge, path: "Mac CSVImporter.swift:38-39 -> ClockStore.swift:553-610 importSessions")
    // A matching imported row copies the same unvalidated duration into a Clockin entry.
    csvHuge.sessions[0].source = "Clockin"
    try rejected("csv-correction-over-100-years", csvHuge, path: "Mac ClockStore.swift:595-599 matched row")

    var futureCSV = baseline
    futureCSV.sessions = try MacCSVImporter.parse(data: Data(csv.replacingOccurrences(of: "2026-03-04", with: "5000-03-04").utf8), hourlyRate: 42)
    futureCSV.sessions[0].matchedExternalSource = futureCSV.sessions[0].source
    try rejected("csv-out-of-range-date", futureCSV, path: "Mac CSVImporter.swift:34-35 -> ClockStore.swift:428-433/553-610")
    var futurePaste = baseline
    futurePaste.sessions = try MacPastedTextImporter.parse("Mar 1, 5000 - Mar 7, 5000 Monday March 4 Approved synthetic 09:00 10:00", hourlyRate: 42)
    futurePaste.sessions[0].matchedExternalSource = futurePaste.sessions[0].source
    check(futurePaste.sessions[0].start > Date.distantFuture, "old pasted parser admits year 5000 from explicit range")
    try rejected("pasted-out-of-range-date", futurePaste, path: "Mac PastedTextImporter.swift:31-35/105-122 -> ClockStore.swift:439-442/553-610")

    // Store-call boundaries: reachable API paths, not a claim that the elapsed-time UI
    // can enter 100 years (ManualStartView clamps it to 999 h 59 m).
    var hugeRun = baseline
    hugeRun.running = MacRunningSession(start: now.addingTimeInterval(-huge), accumulated: huge, resumedAt: now, note: "synthetic")
    try rejected("clock-in-over-cap", hugeRun, path: "Mac ClockStore.swift:158-168 clockIn; API/system-date boundary")
    hugeRun.running?.resumedAt = nil
    try rejected("pause-over-cap", hugeRun, path: "Mac ClockStore.swift:175-180 pause after long elapsed/system-clock jump")
    var hugeDone = baseline
    hugeDone.sessions[0].start = now.addingTimeInterval(-huge)
    hugeDone.sessions[0].end = now
    hugeDone.sessions[0].duration = huge
    try rejected("manual-over-cap", hugeDone, path: "Mac ClockStore.swift:212-232 addManualSession API; UI usually one day")
    try rejected("edited-over-cap", hugeDone, path: "Mac ClockStore.swift:522-544 updateSession; oversized imported duration retained on note edit")
    try rejected("clock-out-over-cap", hugeDone, path: "Mac ClockStore.swift:192-202 clockOut after forward clock jump")
    // Backup import checks completed rows only for duration >= 0 and end >= start.
    check(hugeDone.sessions.allSatisfy { $0.duration >= 0 && $0.end >= $0.start }, "old backup guard accepts oversized completed duration")
    try rejected("restore-over-cap", hugeDone, path: "Mac ClockStore.swift:458-466 importBackup")
    var negative = baseline
    negative.running = MacRunningSession(start: start, accumulated: -1, resumedAt: nil, note: "synthetic")
    check(negative.sessions.allSatisfy { $0.duration >= 0 && $0.end >= $0.start }, "old backup guard never checks running")
    try rejected("restore-negative-running", negative, path: "Mac ClockStore.swift:458-466 importBackup of supplied JSON")
    var negativeDone = baseline; negativeDone.sessions[0].duration = -1
    try rejected("load-and-resave-negative-duration", negativeDone, path: "Mac ClockStore.swift:51-53 load then 419-422 updateCurrency; requires preexisting malformed file")
    try rejected("direct-import-negative-duration", negativeDone, path: "Mac ClockStore.swift:553-610 importSessions API; CSV parser itself falls back to measured duration")
    for (name, date) in [("before-distant-past", Date.distantPast.addingTimeInterval(-86400)),
                         ("after-distant-future", Date.distantFuture.addingTimeInterval(86400))] {
        var dated = baseline
        dated.sessions[0].start = date; dated.sessions[0].end = date.addingTimeInterval(60); dated.sessions[0].duration = 60
        try rejected(name, dated, path: "Mac ClockStore.swift:212-232 / 522-544 / 458-466: no date bounds in add/edit/restore")
    }
    var invalidRunDate = baseline
    invalidRunDate.running = MacRunningSession(start: Date.distantPast.addingTimeInterval(-86400), accumulated: 0, resumedAt: nil, note: "synthetic")
    try rejected("restore-out-of-range-running-date", invalidRunDate, path: "Mac ClockStore.swift:458-466 restore has no running validation")
    var invalidResumeDate = baseline
    invalidResumeDate.running = MacRunningSession(start: start, accumulated: 0,
        resumedAt: Date.distantFuture.addingTimeInterval(86400), note: "synthetic")
    try rejected("resume-out-of-range-date", invalidResumeDate, path: "Mac ClockStore.swift:183-188 resume / 458-466 restore")
    // Decoding uses Date.now, so a once-accepted active timer can age past the cap.
    var aged = baseline
    aged.running = MacRunningSession(start: now.addingTimeInterval(-huge), accumulated: 0,
                                     resumedAt: now.addingTimeInterval(-huge), note: "synthetic")
    try rejected("running-elapsed-over-cap-at-read", aged, path: "Mac clockIn then passage of time/system-clock jump; current Models.swift:135 validates at wall-clock now")

    // Nonfinite values are NOT writable Mac JSON: default JSONEncoder throws.
    for (label, value) in [("NaN", Double.nan), ("positive-infinity", Double.infinity), ("negative-infinity", -Double.infinity)] {
        var bad = baseline; bad.sessions[0].duration = value
        check((try? encoder.encode(bad)) == nil, "\(label) duration: old default encoder rejects before disk write")
        bad = baseline; bad.running = MacRunningSession(start: start, accumulated: value, resumedAt: nil, note: "synthetic")
        check((try? encoder.encode(bad)) == nil, "\(label) accumulated: old default encoder rejects before disk write")
        bad = baseline; bad.sessions[0].start = Date(timeIntervalSinceReferenceDate: value)
        check((try? encoder.encode(bad)) == nil, "\(label) date: old default encoder rejects before disk write")
    }
    // Neither decoder validates rate dates or finite negative monetary values.
    var oddRates = baseline
    oddRates.rateRules = [MacRateRule(effectiveFrom: Date.distantPast.addingTimeInterval(-86400), hourlyRate: -1)]
    try accepted("unvalidated-rate-fields", oddRates)
    var mixed = baseline
    var bad = baseline.sessions[0]; bad.id = UUID(); bad.duration = -1
    mixed.sessions.append(bad)
    bad.id = UUID(); bad.duration = SessionDuration.maximum + 1
    mixed.sessions.append(bad)
    mixed.running = MacRunningSession(start: start, accumulated: -1, resumedAt: nil, note: "invalid timer")
    try rejected("mixed-valid-and-invalid", mixed, path: "mixed archive with two invalid sessions and invalid timer")
    mixed.rateRules = nil
    try rejected("mixed-before-rate-migration", mixed, path: "quarantine before the missing-rate save")

    let mixedBytes = try encoder.encode(mixed)
    let blockedDir = try directory("quarantine-write-failure")
    let blockedURL = blockedDir.appendingPathComponent("clockin.json")
    try mixedBytes.write(to: blockedURL)
    var writes = 0
    let blocked = ClockStore(fileURL: blockedURL, writeQuarantine: { _, _ in
        writes += 1
        throw CocoaError(.fileWriteOutOfSpace)
    })
    check(writes == 1 && blocked.sessions.isEmpty && blocked.running == nil,
          "quarantine write failure publishes no archive entries")
    check(blocked.statusMessage?.contains("will not be overwritten") == true,
          "quarantine failure explains the protected original")
    check(try Data(contentsOf: blockedURL) == mixedBytes, "quarantine failure never saves rate migration over original")
    let blockedCopies = try unreadable(in: blockedDir)
    check(try blockedCopies.count == 1 && Data(contentsOf: blockedCopies[0]) == mixedBytes,
          "quarantine failure still retains byte-identical original safety copy")
    blocked.updateCurrency("EUR")
    blocked.clockIn()
    check(try Data(contentsOf: blockedURL) == mixedBytes, "later save paths cannot overwrite protected original")
    check(blocked.running == nil && blocked.timerPersistenceError != nil, "blocked timer start rolls back")
    let retried = ClockStore(fileURL: blockedURL)
    check(retried.sessions.count == 1 && retried.running == nil, "reopen retries recovery once storage works")

    // Include unknown fields, escaped delimiters and exact numeric spelling.
    let rawDir = try directory("raw-entry-preservation")
    let rawURL = rawDir.appendingPathComponent("clockin.json")
    let rawEntry = #"{ "id":"11111111-1111-1111-1111-111111111111", "start":800000000, "end":800000001, "duration":-1.000e0, "note":"braces } ], comma, quote \"", "hourlyRate":25, "source":"Mac", "unknown":{"integer":1234567890123456789,"nested":[true,null,{"x":"}"}]}}"#
    let rawRunning = #"{ "start":800000000, "accumulated":-1.00e0, "note":"old timer", "resumedAt":null, "unknown":[{"x":1234567890123456789}] }"#
    let rawBytes = Data((#"{"hourlyRate":25,"currencyCode":"USD","pinVisible":false,"sessions":["# + rawEntry + #"],"rateRules":[],"running":"# + rawRunning + "}").utf8)
    try rawBytes.write(to: rawURL)
    let rawStore = ClockStore(fileURL: rawURL)
    let rawCopies = try fm.contentsOfDirectory(at: rawDir, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("clockin-quarantine-") }
    check(rawStore.statusMessage != nil && rawCopies.count == 1, "raw entry fixture quarantines successfully")
    let rawQuarantine = try Data(contentsOf: rawCopies[0])
    check(String(decoding: rawQuarantine, as: UTF8.self).contains(rawEntry), "quarantine keeps rejected entry byte-for-byte including unknown fields")
    check(String(decoding: rawQuarantine, as: UTF8.self).contains(rawRunning), "quarantine keeps rejected timer byte-for-byte including unknown fields")
    _ = try JSONSerialization.jsonObject(with: rawQuarantine)

    for (name, bytes) in [("not-json", Data("not json".utf8)),
                           ("missing-top-level-key", Data(#"{"hourlyRate":25,"currencyCode":"USD","sessions":[]}"#.utf8))] {
        let dir = try directory(name), url = dir.appendingPathComponent("clockin.json")
        try bytes.write(to: url)
        let store = ClockStore(fileURL: url)
        check(store.sessions.isEmpty && store.running == nil && store.statusMessage != nil,
              "\(name): malformed archive retains whole-file failure")
        let copies = try unreadable(in: dir)
        check(try copies.count == 1 && Data(contentsOf: copies[0]) == bytes,
              "\(name): byte-identical unreadable copy retained")
        check(try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .allSatisfy { !$0.lastPathComponent.hasPrefix("clockin-quarantine-") },
              "\(name): malformed archive is not treated as entry quarantine")
    }

    let restoreDir = try directory("strict-restore")
    let restoreURL = restoreDir.appendingPathComponent("clockin.json")
    try encoder.encode(baseline).write(to: restoreURL)
    let restoreStore = ClockStore(fileURL: restoreURL)
    let beforeRestore = try Data(contentsOf: restoreURL)
    let backup = restoreDir.appendingPathComponent("mixed-backup.json")
    try mixedBytes.write(to: backup)
    check(!restoreStore.restoreBackup(from: backup), "restore rejects partial invalid backup as a whole")
    check(restoreStore.statusMessage?.contains("requires a complete valid archive") == true,
          "restore explains its all-or-nothing contract")
    restoreStore.importBackup(from: backup)
    check(try Data(contentsOf: restoreURL) == beforeRestore, "importBackup also leaves existing archive untouched")
    check(try Data(contentsOf: backup) == mixedBytes, "strict restore and import never modify supplied backup")
    check(ClockStore.readBackups(in: restoreDir).first(where: { $0.url.lastPathComponent == backup.lastPathComponent })?.isReadable == false,
          "backup listing stays strict, matching restore")

    print("\(checks) maccompat checks passed; legacy invalid entries quarantined without losing valid work")
}

do {
    try MainActor.assumeIsolated { try run() }
} catch {
    print("FAILED: unexpected error: \(error)")
    exit(1)
}
