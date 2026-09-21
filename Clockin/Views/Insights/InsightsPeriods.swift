import Foundation

enum InsightsGrouping: String, CaseIterable {
    case day = "Day", week = "Week", month = "Month"
}

struct InsightsPeriod: Identifiable {
    let start: Date
    let end: Date
    var duration: TimeInterval = 0
    var earnings: Double = 0
    var intensity: Double = 0
    var id: Date { start }

    func conversion(currencyCode: String, startRate: Double?, latestRate: Double?) -> InsightsConversion? {
        guard currencyCode == "USD", let rate = startRate ?? latestRate else { return nil }
        return InsightsConversion(earnings: earnings * rate, rate: rate, usedLatest: startRate == nil)
    }
}

struct InsightsConversion {
    let earnings: Double
    let rate: Double
    let usedLatest: Bool
}

enum InsightsPeriods {
    static func weekStart(_ date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    static func dayWeeks(daily: [Date: TimeInterval], now: Date, range: Int, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let last = weekStart(today, calendar: calendar)
        let first = range == 0
            ? weekStart(min(daily.keys.min() ?? today, today), calendar: calendar)
            : calendar.date(byAdding: .weekOfYear, value: -(max(1, range) - 1), to: last) ?? last
        return starts(from: first, through: last, component: .weekOfYear, calendar: calendar)
    }

    // Takvim adimlari yaz saati gecislerinde de donem sinirlarini korur.
    static func buckets(daily: [Date: TimeInterval], earnings: [Date: Double],
                        grouping: InsightsGrouping, now: Date, calendar: Calendar) -> [InsightsPeriod] {
        let component: Calendar.Component = grouping == .month ? .month : (grouping == .week ? .weekOfYear : .day)
        func start(_ date: Date) -> Date {
            if grouping == .week { return MonthWeek.interval(containing: date, calendar: calendar).start }
            return calendar.dateInterval(of: component, for: date)?.start ?? calendar.startOfDay(for: date)
        }
        let today = calendar.startOfDay(for: now)
        let keys = Set(daily.keys).union(earnings.keys)
        let first = start(min(keys.min() ?? today, today))
        var dates: [Date] = []
        var cursor = first
        while cursor <= today {
            dates.append(cursor)
            let next = grouping == .week ? MonthWeek.interval(containing: cursor, calendar: calendar).end
                : calendar.date(byAdding: component, value: 1, to: cursor)!
            guard next > cursor else { break }
            cursor = next
        }
        var totals: [Date: InsightsPeriod] = [:]
        for date in dates {
            totals[date] = InsightsPeriod(start: date,
                end: grouping == .week ? MonthWeek.interval(containing: date, calendar: calendar).end
                    : calendar.date(byAdding: component, value: 1, to: date) ?? date)
        }
        for day in keys {
            let key = start(day)
            guard totals[key] != nil else { continue }
            totals[key]?.duration += daily[day, default: 0]
            totals[key]?.earnings += earnings[day, default: 0]
        }
        let maximum = max(1, totals.values.map(\.earnings).max() ?? 1)
        return dates.compactMap { date in
            guard var period = totals[date] else { return nil }
            period.intensity = heatIntensity(period.earnings, reference: maximum)
            return period
        }
    }

    static func heatIntensity(_ value: Double, reference: Double = 8) -> Double {
        value > 0 ? min(1, 0.25 + value / reference * 0.75) : 0
    }

    private static func starts(from first: Date, through last: Date,
                               component: Calendar.Component, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var cursor = first
        while cursor <= last {
            result.append(cursor)
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return result
    }
}
