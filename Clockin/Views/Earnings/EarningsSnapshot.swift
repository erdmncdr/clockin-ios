import Foundation

struct EarningsDay: Identifiable {
    let day: Date
    var duration: TimeInterval = 0
    var earned: Double = 0
    var rate: Double?
    var id: Date { day }
    var converted: Double? { rate.map { earned * $0 } }
}

struct EarningsSnapshot {
    let interval: DateInterval
    let sessions: [WorkSession]
    let points: [EarningsDay]
    let includesActive: Bool
    // Guncel sayfada bugune kadar, gecmis sayfada donemin tum gunleri.
    let calendarDays: Int
    var duration: TimeInterval { points.reduce(0) { $0 + $1.duration } }
    var activeDays: Int { points.filter { $0.duration > 0 }.count }
    var dailyAverage: TimeInterval { duration / Double(calendarDays) }
    var weeklyAverage: TimeInterval { dailyAverage * 7 }
    /// Mac'teki gibi ortalama ay uzunlugu.
    var monthlyAverage: TimeInterval { dailyAverage * 30.44 }
    /// Yalnizca calisilan gunlerin ortalamasi; hic calisilmadiysa sifir.
    var activeDayAverage: TimeInterval { activeDays == 0 ? 0 : duration / Double(activeDays) }
    var earned: Double { points.reduce(0) { $0 + $1.earned } }
    var converted: Double? {
        guard points.allSatisfy({ $0.rate != nil }) else { return nil }
        return points.reduce(0) { $0 + ($1.converted ?? 0) }
    }

    init(sessions: [WorkSession], running: RunningSession?, range: EarningsRange, now: Date,
         calendar: Calendar = .current, period: EarningsPeriod? = nil, earnings: (WorkSession) -> Double,
         activeEarnings: Double, rate: (Date) -> Double?) {
        let interval = period?.interval ?? range.interval(at: now, calendar: calendar)
        self.interval = interval
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        func included(_ date: Date) -> Bool { date >= interval.start && date < min(interval.end, tomorrow) }
        self.sessions = sessions.filter { included($0.start) }
        var days: [Date: EarningsDay] = [:]
        for session in self.sessions {
            let day = calendar.startOfDay(for: session.start)
            var point = days[day] ?? EarningsDay(day: day)
            point.duration += session.duration
            point.earned += earnings(session)
            days[day] = point
        }
        includesActive = running.map { included($0.start) } ?? false
        if let running, includesActive {
            let day = calendar.startOfDay(for: running.start)
            var point = days[day] ?? EarningsDay(day: day)
            point.duration += running.elapsed(at: now)
            point.earned += activeEarnings
            days[day] = point
        }
        let first = range == .all ? (days.keys.min() ?? calendar.startOfDay(for: now)) : interval.start
        calendarDays = max(1, calendar.dateComponents([.day], from: first, to: min(interval.end, tomorrow)).day ?? 1)
        points = days.values.map { point in
            var point = point
            point.rate = rate(point.day)
            return point
        }.sorted { $0.day < $1.day }
    }
}

struct EarningsMonthBar: Identifiable {
    let day: Date
    var duration: TimeInterval = 0
    var earned: Double = 0
    var converted: Double? = 0
    var id: Date { day }
}

extension EarningsSnapshot {
    func monthlyBars(calendar: Calendar = .current) -> [EarningsMonthBar] {
        var months: [Date: EarningsMonthBar] = [:]
        for point in points {
            let month = calendar.dateInterval(of: .month, for: point.day)!.start
            var bar = months[month] ?? EarningsMonthBar(day: month)
            bar.duration += point.duration
            bar.earned += point.earned
            if let previous = bar.converted, let converted = point.converted {
                bar.converted = previous + converted
            } else {
                bar.converted = nil
            }
            months[month] = bar
        }
        return months.values.sorted { $0.day < $1.day }
    }
}
