import Foundation

/// Half-open calendar weeks that start on Monday, whatever the device's first weekday.
enum CalendarWeek {
    static func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let date = SessionDuration.isValidDate(date) ? date : .distantPast
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) - 2 + 7) % 7
        // Gece yarisi DST gecisinde startOfDay 01:00 olabilir; sinirlar gun basina sabitlenir.
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: day) ?? day)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: start) ?? start)
        return DateInterval(start: start, end: max(start, end))
    }
}
