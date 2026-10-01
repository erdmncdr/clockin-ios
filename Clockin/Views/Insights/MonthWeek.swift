import Foundation

/// Half-open intervals: 1–7, 8–14, 15–21, 22–28, then the remaining days.
/// Calendar arithmetic preserves local midnight through daylight-saving changes.
enum MonthWeek {
    static func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let date = SessionDuration.isValidDate(date) ? date : .distantPast
        let month = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        let offset = (calendar.component(.day, from: date) - 1) / 7 * 7
        let start = (calendar.date(byAdding: .day, value: offset, to: month.start) ?? month.start)
        let end = min(month.end, (calendar.date(byAdding: .day, value: 7, to: start) ?? start))
        return DateInterval(start: start, end: max(start, end))
    }
}
