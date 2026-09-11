import Foundation

enum CSVImportError: LocalizedError {
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

enum CSVImporter {
    static func parse(data: Data, hourlyRate: Double) throws -> [WorkSession] {
        guard var text = String(data: data, encoding: .utf8) else { throw CSVImportError.unreadable }
        text = text.replacingOccurrences(of: "\u{feff}", with: "")
        let rows = parseRows(text)
        guard let header = rows.first else { throw CSVImportError.noValidRows }

        let names = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let startIndex = names.firstIndex(of: "start time"),
              let endIndex = names.firstIndex(of: "end time") else {
            throw CSVImportError.missingColumns
        }
        let durationIndex = names.firstIndex(of: "duration")
        let notesIndex = names.firstIndex(of: "notes")
        let sourceIndex = names.firstIndex(of: "time sheet source")

        let sessions = rows.dropFirst().compactMap { row -> WorkSession? in
            guard row.indices.contains(startIndex), row.indices.contains(endIndex),
                  let start = parseDate(row[startIndex]), let end = parseDate(row[endIndex]), end >= start else { return nil }

            let measured = end.timeIntervalSince(start)
            let duration: TimeInterval
            if let index = durationIndex, row.indices.contains(index), let milliseconds = Double(row[index]), milliseconds >= 0 {
                duration = milliseconds / 1000
            } else {
                duration = measured
            }

            return WorkSession(
                id: UUID(),
                start: start,
                end: end,
                duration: duration,
                note: value(at: notesIndex, in: row),
                hourlyRate: hourlyRate,
                source: value(at: sourceIndex, in: row).isEmpty ? "CSV import" : value(at: sourceIndex, in: row)
            )
        }
        guard !sessions.isEmpty else { throw CSVImportError.noValidRows }
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
