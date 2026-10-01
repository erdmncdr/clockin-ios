import Foundation

enum MacChartInspection {
    static func date(_ value: Date?, monthly: Bool, interval: DateInterval,
                     now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let value else { return nil }
        let date = monthly ? calendar.dateInterval(of: .month, for: value)?.start : calendar.startOfDay(for: value)
        guard let date, date <= calendar.startOfDay(for: now),
              date >= interval.start, date < interval.end else { return nil }
        return date
    }
}
