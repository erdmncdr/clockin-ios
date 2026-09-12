import Foundation

enum EarningsRange: String, CaseIterable, Identifiable {
    case week = "7D", month = "30D", quarter = "3M", all = "ALL"
    var id: String { rawValue }
    var days: Int? {
        switch self { case .week: 7; case .month: 30; case .quarter: 90; case .all: nil }
    }
    func interval(at now: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let start = days.flatMap { calendar.date(byAdding: .day, value: 1 - $0, to: today) } ?? .distantPast
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        return DateInterval(start: start, end: end)
    }
}

struct EarningsDay: Identifiable {
    let day: Date
    var duration: TimeInterval = 0
    var earned: Double = 0
    var rate: Double?
    var id: Date { day }
    var converted: Double? { rate.map { earned * $0 } }
}

struct EarningsSnapshot {
    let sessions: [WorkSession]
    let points: [EarningsDay]
    let includesActive: Bool
    var duration: TimeInterval { points.reduce(0) { $0 + $1.duration } }
    var earned: Double { points.reduce(0) { $0 + $1.earned } }
    var converted: Double? {
        guard points.allSatisfy({ $0.rate != nil }) else { return nil }
        return points.reduce(0) { $0 + ($1.converted ?? 0) }
    }

    init(sessions: [WorkSession], running: RunningSession?, range: EarningsRange, now: Date,
         calendar: Calendar = .current, earnings: (WorkSession) -> Double,
         activeEarnings: Double, rate: (Date) -> Double?) {
        let interval = range.interval(at: now, calendar: calendar)
        func included(_ date: Date) -> Bool { date >= interval.start && date < interval.end }
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
        points = days.values.map { point in
            var point = point
            point.rate = rate(point.day)
            return point
        }.sorted { $0.day < $1.day }
    }
}
