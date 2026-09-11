import Foundation

enum PastedImportError: LocalizedError {
    case noEntries

    var errorDescription: String? {
        "No time entries were recognized. Copy one or more rows including the date, start time, and end time."
    }
}

enum PastedTextImporter {
    private static let weekdays = Set(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])
    private static let statuses = Set(["approved", "submitted", "draft", "unapproved"])
    private static let ignoredSources = Set(["new", "new entry", "submit selected", "hours", "total", "timecards", "me", "my time"])

    static func parse(_ text: String, hourlyRate: Double, now: Date = .now) throws -> [WorkSession] {
        let lines = text.components(separatedBy: .newlines)
            .map(clean)
            .filter { !$0.isEmpty }
        let flattened = lines.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let range = extractDateRange(from: flattened)
        let pattern = #"(?i)\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s*(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})\s+(Approved|Submitted|Draft|Unapproved)\s+(.+?)\s+(\d{1,2}:\d{2})\s+(\d{1,2}:\d{2})(?:\s+(\d+)\s*([MH]))?"#
        if let regex = try? NSRegularExpression(pattern: pattern), !flattened.isEmpty {
            let matches = regex.matches(in: flattened, range: NSRange(flattened.startIndex..., in: flattened))
            let parsed = matches.compactMap { match -> WorkSession? in
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

        var results: [WorkSession] = []
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
                    results.append(WorkSession(
                        id: UUID(), start: start, end: end, duration: end.timeIntervalSince(start),
                        note: "\(status) • \(source)", hourlyRate: hourlyRate, source: source
                    ))
                }
            }
            index = max(index + 1, endIndex)
        }

        guard !results.isEmpty else { throw PastedImportError.noEntries }
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
                                    status: String, source: String, hourlyRate: Double) -> WorkSession? {
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
        return WorkSession(
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
