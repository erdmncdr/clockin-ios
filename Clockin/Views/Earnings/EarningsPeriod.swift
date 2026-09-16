import Foundation

enum EarningsRange: String, CaseIterable, Identifiable {
    case week = "W", month = "M", sixMonths = "6M", all = "All"
    var id: String { rawValue }

    func interval(at now: Date, calendar: Calendar = .current) -> DateInterval {
        EarningsPeriod(range: self, anchor: now, now: now, calendar: calendar).interval
    }
}

struct EarningsPeriod: Equatable {
    let range: EarningsRange
    let anchor: Date
    let interval: DateInterval
    let isCurrent: Bool

    init(range: EarningsRange, anchor: Date, now: Date, calendar: Calendar = .current) {
        self.range = range
        self.anchor = min(anchor, now)
        func bounds(_ date: Date) -> DateInterval {
            switch range {
            case .week:
                let day = calendar.startOfDay(for: date)
                let offset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
                let start = calendar.date(byAdding: .day, value: -offset, to: day)!
                return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
            case .month:
                return calendar.dateInterval(of: .month, for: date)!
            case .sixMonths:
                // Alti aylik sayfalar bugunun ayinda biter; onceki bloklar ust uste binmez.
                let currentMonth = calendar.dateInterval(of: .month, for: now)!.start
                let month = calendar.dateInterval(of: .month, for: date)!.start
                let distance = max(0, calendar.dateComponents([.month], from: month, to: currentMonth).month ?? 0)
                let end = calendar.date(byAdding: .month, value: 1 - (distance / 6) * 6, to: currentMonth)!
                return DateInterval(start: calendar.date(byAdding: .month, value: -6, to: end)!, end: end)
            case .all:
                return DateInterval(start: .distantPast,
                                    end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!)
            }
        }
        interval = bounds(self.anchor)
        isCurrent = interval == bounds(now)
    }

    var canGoForward: Bool { range != .all && !isCurrent }

    func paged(by direction: Int, now: Date, calendar: Calendar = .current) -> Self {
        guard range != .all, direction != 0, direction < 0 || canGoForward else { return self }
        let step = direction < 0 ? -1 : 1
        let component: Calendar.Component = range == .week ? .day : .month
        let amount = range == .week ? 7 : (range == .sixMonths ? 6 : 1)
        let next = calendar.date(byAdding: component, value: step * amount, to: anchor)!
        return Self(range: range, anchor: next, now: now, calendar: calendar)
    }

    func switching(to range: EarningsRange, now: Date, calendar: Calendar = .current) -> Self {
        Self(range: range, anchor: anchor, now: now, calendar: calendar)
    }

    func title(calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard range != .all else { return "All time" }
        let last = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        func format(_ date: Date, _ template: String) -> String {
            formatter.setLocalizedDateFormatFromTemplate(template)
            return formatter.string(from: date)
        }
        if range == .month { return format(interval.start, "MMMMyyyy") }
        let sameYear = calendar.component(.year, from: interval.start) == calendar.component(.year, from: last)
        let firstTemplate = range == .week ? (sameYear ? "MMMd" : "MMMdyyyy") : (sameYear ? "MMM" : "MMMyyyy")
        return "\(format(interval.start, firstTemplate)) to \(format(last, range == .week ? "MMMdyyyy" : "MMMyyyy"))"
    }
}

enum EarningsSwipe {
    static func isHorizontal(x: Double, y: Double) -> Bool { abs(x) > abs(y) * 2 }
    static func page(x: Double, y: Double) -> Int? {
        guard abs(x) >= 44, isHorizontal(x: x, y: y) else { return nil }
        return x > 0 ? -1 : 1
    }
}
