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
                return MonthWeek.interval(containing: date, calendar: calendar)
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

    struct PageID: Hashable {
        let range: EarningsRange
        let interval: DateInterval
    }

    var pageID: PageID { PageID(range: range, interval: interval) }

    var canGoForward: Bool { range != .all && !isCurrent }

    func paged(by direction: Int, now: Date, calendar: Calendar = .current) -> Self {
        guard range != .all, direction != 0, direction < 0 || canGoForward else { return self }
        let step = direction < 0 ? -1 : 1
        if range == .week {
            let next = step < 0
                ? calendar.date(byAdding: .day, value: -1, to: interval.start)!
                : interval.end
            return Self(range: range, anchor: next, now: now, calendar: calendar)
        }
        let next = calendar.date(byAdding: .month, value: step * (range == .sixMonths ? 6 : 1), to: anchor)!
        return Self(range: range, anchor: next, now: now, calendar: calendar)
    }

    func switching(to range: EarningsRange, now: Date, calendar: Calendar = .current) -> Self {
        Self(range: range, anchor: anchor, now: now, calendar: calendar)
    }

    func title(calendar: Calendar = .current, locale: Locale = AppLanguage.formatLocale) -> String {
        guard range != .all else { return String(localized: "All time", bundle: .app) }
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
        let from = format(interval.start, firstTemplate), to = format(last, range == .week ? "MMMdyyyy" : "MMMyyyy")
        return String(localized: "\(from) to \(to)", bundle: .app)
    }
}

enum EarningsChartAxis {
    static func dateDomain(_ interval: DateInterval) -> ClosedRange<Date> {
        // Bitis sonraki donemin baslangicidir.
        interval.start...max(interval.start, interval.end.addingTimeInterval(-1))
    }

    static func dayMarks(in interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
        guard days > 2 else { return [interval.start] }
        // Son etiket saga yakin olunca kesiliyordu; son isaret donemin son
        // ceyreginden once kalir. Takvim adimlari DST'de de esit kalir.
        let step = max(1, days / 4)
        return (0..<min(4, days - 1)).compactMap {
            calendar.date(byAdding: .day, value: $0 * step, to: interval.start)
        }
    }

    static func earningsUpperBound(_ maximum: Double) -> Double {
        guard maximum.isFinite, maximum > 0 else { return 1 }
        let step = pow(10, floor(log10(maximum))) / 20
        // Yuvarlama sonrasi yuzde 10-15 bosluk kalir.
        return ceil(maximum * 1.1 / step - 1e-10) * step
    }
}

enum EarningsSwipe {
    static func isHorizontal(x: Double, y: Double) -> Bool { abs(x) > abs(y) * 2 }
    static func page(x: Double, y: Double) -> Int? {
        guard abs(x) >= 44, isHorizontal(x: x, y: y) else { return nil }
        return x > 0 ? -1 : 1
    }
}
