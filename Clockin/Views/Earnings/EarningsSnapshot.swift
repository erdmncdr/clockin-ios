import Foundation

struct EarningsDay: Identifiable {
    let day: Date
    var duration: TimeInterval = 0
    var earned: Double = 0
    var rate: Double?
    var id: Date { day }
    var converted: Double?
}

struct EarningsSnapshot {
    let interval: DateInterval
    let sessions: [WorkSession]
    let points: [EarningsDay]
    let includesActive: Bool
    // Guncel sayfada bugune kadar, gecmis sayfada donemin tum gunleri.
    let calendarDays: Int
    let duration: TimeInterval
    let activeDays: Int
    let earned: Double
    let converted: Double?
    let hasConvertedDays: Bool
    let sessionAmounts: [UUID: HistoryAmount]
    var money: HistoryAmount { HistoryAmount(earned: earned, converted: converted) }
    var dailyAverage: TimeInterval { duration / Double(calendarDays) }
    var weeklyAverage: TimeInterval { dailyAverage * 7 }
    /// Mac'teki gibi ortalama ay uzunlugu.
    var monthlyAverage: TimeInterval { dailyAverage * 30.44 }
    /// Yalnizca calisilan gunlerin ortalamasi; hic calisilmadiysa sifir.
    var activeDayAverage: TimeInterval { activeDays == 0 ? 0 : duration / Double(activeDays) }

    init(sessions: [WorkSession], running: RunningSession?, range: EarningsRange, now: Date,
         calendar: Calendar = .current, period: EarningsPeriod? = nil, earnings: (WorkSession) -> Double,
         activeEarnings: Double, rate: (Date) -> Double?) {
        let interval = period?.interval ?? range.interval(at: now, calendar: calendar)
        self.interval = interval
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        func included(_ date: Date) -> Bool { date >= interval.start && date < min(interval.end, tomorrow) }
        self.sessions = sessions.filter { included($0.start) }
        var days: [Date: EarningsDay] = [:]
        var amounts: [UUID: Double] = [:]
        for session in self.sessions {
            let day = calendar.startOfDay(for: session.start)
            var point = days[day] ?? EarningsDay(day: day)
            point.duration += session.duration
            let earned = earnings(session)
            amounts[session.id] = earned
            point.earned += earned
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
            point.converted = point.rate.map { point.earned * $0 }
            return point
        }.sorted { $0.day < $1.day }
        hasConvertedDays = points.contains { $0.rate != nil }
        duration = points.reduce(0) { $0 + $1.duration }
        activeDays = points.filter { $0.duration > 0 }.count
        earned = points.reduce(0) { $0 + $1.earned }
        converted = points.allSatisfy { $0.rate != nil }
            ? points.reduce(0) { $0 + ($1.converted ?? 0) } : nil
        let rates = Dictionary(uniqueKeysWithValues: points.map { ($0.day, $0.rate) })
        sessionAmounts = Dictionary(uniqueKeysWithValues: self.sessions.map { session in
            let value = amounts[session.id, default: 0]
            let rate = rates[calendar.startOfDay(for: session.start)] ?? nil
            return (session.id, HistoryAmount(earned: value, converted: rate.map { value * $0 }))
        })
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

// Eksik kur varsa toplam tek para biriminde kalir.
struct HistoryAmount {
    let earned: Double
    let converted: Double?

    func value(showTRY: Bool) -> Double { showTRY ? (converted ?? earned) : earned }
    func code(currency: String, showTRY: Bool) -> String {
        showTRY && converted != nil ? "TRY" : currency
    }
    func divided(by divisor: Double) -> HistoryAmount {
        HistoryAmount(earned: earned / divisor, converted: converted.map { $0 / divisor })
    }
}

struct HistoryDayGroup {
    let day: Date
    var sessions: [WorkSession] = []
    var duration: TimeInterval = 0
    var money = HistoryAmount(earned: 0, converted: 0)
}

struct HistoryPage {
    let snapshot: EarningsSnapshot
    let months: [EarningsMonthBar]
    let days: [HistoryDayGroup]
    let performance: MonthPerformance?
    let hasMissingRates: Bool

    init(sessions: [WorkSession], running: RunningSession?, period: EarningsPeriod,
         monthlyGoal: Double, now: Date, calendar: Calendar = .current,
         earnings: (WorkSession) -> Double, activeEarnings: Double, rate: (Date) -> Double?) {
        let snapshot = EarningsSnapshot(sessions: sessions, running: running, range: period.range,
            now: now, calendar: calendar, period: period, earnings: earnings,
            activeEarnings: activeEarnings, rate: rate)
        self.snapshot = snapshot
        months = snapshot.monthlyBars(calendar: calendar)
        performance = period.range == .month ? MonthPerformance(snapshot: snapshot, period: period, sessions: sessions,
            monthlyGoal: monthlyGoal, now: now, calendar: calendar, earnings: earnings, rate: rate) : nil
        var groups: [Date: HistoryDayGroup] = [:]
        for session in snapshot.sessions {
            let day = calendar.startOfDay(for: session.start)
            let amount = snapshot.sessionAmounts[session.id]!
            groups[day, default: HistoryDayGroup(day: day)].sessions.append(session)
            groups[day]!.duration += session.duration
            let previous = groups[day]!.money
            groups[day]!.money = HistoryAmount(earned: previous.earned + amount.earned,
                converted: previous.converted.flatMap { value in amount.converted.map { value + $0 } })
        }
        days = groups.values.sorted { $0.day > $1.day }
        hasMissingRates = snapshot.converted == nil ||
            (period.range == .month && performance?.projectedEarnings != nil && performance?.projectedConverted == nil)
    }
}
