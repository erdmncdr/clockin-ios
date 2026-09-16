import Foundation

struct InsightsSnapshot {
    var daily: [Date: TimeInterval] = [:]
    var dailyEarnings: [Date: Double] = [:]
    var totalDuration: TimeInterval = 0
    var totalEarnings: Double = 0
    var monthDuration: TimeInterval = 0
    var monthEarnings: Double = 0
    var recentWeek: TimeInterval = 0
    var previousWeek: TimeInterval = 0
    var longestSession: TimeInterval = 0
    var sessionCount = 0
    var longestStreak = 0
    var currentStreak = 0
    /// Herkes icin ayni esikler; kullanicinin hedefine bagli degil.
    var fullDays = 0
    var longDays = 0
    var bigMonths = 0
    var baseXP = 0
    var streakXP = 0

    /// Seviye yalnizca calisilan saatten ve seriden gelir.
    ///
    /// Mac'te hedeflere de XP veriliyor: her hedef gunu +100, iki kati +250,
    /// her hedef ayi +500. Hedef kullanicinin kendi sectigi bir sayi ve
    /// degistirilince butun gecmis yeniden puanlaniyor; gunluk hedefi 10
    /// dakikaya ceken biri uzun bir arsivde aniden yuzlerce seviye aliyordu.
    /// Seviye herkes icin ayni sekilde sayilabilen seylere dayanmali. Hedefler
    /// kisisel takip icin kaliyor ama odul vermiyor.
    var xp: Int { baseXP + streakXP }

    static let fullDayHours: Double = 8
    static let longDayHours: Double = 10
    static let bigMonthHours: Double = 100
    var level: Int { max(1, xp / 500 + 1) }

    var averageSession: TimeInterval = 0
    var bestWeekday: Int?
    var bestStartHour: Int?
    var bestDay: Date?
    var bestDayDuration: TimeInterval = 0
    var recentMonth: TimeInterval = 0
    var previousMonth: TimeInterval = 0
    var earlyBirdSessions = 0
    var nightOwlSessions = 0
    var weekendDays = 0
    var goalEstimate = InsightsGoalEstimate()

    var hourlyEarnings: Double { totalDuration > 0 ? totalEarnings / totalDuration * 3600 : 0 }
    var monthTrend: Double {
        previousMonth > 0 ? (recentMonth - previousMonth) / previousMonth : (recentMonth > 0 ? 1 : 0)
    }

    // Kurallar store tarafinda cozulur; saf hesaplama etkin ucretleri duz girdi olarak alir.
    init(sessions: [WorkSession], running: RunningSession? = nil,
         sessionEarnings: [UUID: Double], runningEarnings: Double = 0,
         now: Date, calendar: Calendar, dailyGoal: Double = 0, monthlyGoal: Double = 0) {
        precondition(sessions.allSatisfy { sessionEarnings[$0.id] != nil },
                     "Pass rule-based earnings for every completed session.")
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let previousStart = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        var weekdays: [Int: TimeInterval] = [:]
        var hours: [Int: TimeInterval] = [:]
        var weekends: Set<Date> = []
        var recentCompleted: TimeInterval = 0
        // Takvim gunleri, bugun dahil. Mac burada simdiden geriye 30x24 saat
        // sayiyor; gecmis ekranindaki 30D ise takvim gunu sayiyor. Gece 02:00'de
        // bu, otuz bir gun onceki gunun buyuk kismini da katiyordu ve ayni
        // uygulamada "30 gun" icin iki ayri sayi gorunuyordu.
        let recentCutoff = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let priorCutoff = calendar.date(byAdding: .day, value: -59, to: today) ?? today

        // Tum kayitlarin kazanci ve rekorlari satir basina degil, bir kez hesaplanir.
        for session in sessions {
            let day = calendar.startOfDay(for: session.start)
            dailyEarnings[day, default: 0] += sessionEarnings[session.id]!
            daily[day, default: 0] += session.duration
            let weekday = calendar.component(.weekday, from: session.start)
            let hour = calendar.component(.hour, from: session.start)
            weekdays[weekday, default: 0] += session.duration
            hours[hour, default: 0] += session.duration
            if hour < 8 { earlyBirdSessions += 1 }
            if hour >= 22 { nightOwlSessions += 1 }
            if [1, 7].contains(weekday) { weekends.insert(day) }
            if session.start >= recentCutoff { recentMonth += session.duration }
            else if session.start >= priorCutoff { previousMonth += session.duration }
            if session.start >= now.addingTimeInterval(-7 * 86_400) { recentCompleted += session.duration }
            totalDuration += session.duration
            longestSession = max(longestSession, session.duration)
            sessionCount += 1
        }
        averageSession = sessions.isEmpty ? 0 : totalDuration / Double(sessions.count)
        // Mac esitlikte sozluk sirasina bagli; burada en kucuk takvim anahtari kazanir.
        bestWeekday = weekdays.keys.sorted().max { weekdays[$0, default: 0] < weekdays[$1, default: 0] }
        bestStartHour = hours.keys.sorted().max { hours[$0, default: 0] < hours[$1, default: 0] }
        bestDay = daily.keys.sorted().max { daily[$0, default: 0] < daily[$1, default: 0] }
        bestDayDuration = bestDay.map { daily[$0, default: 0] } ?? 0
        weekendDays = weekends.count
        if let running {
            let day = calendar.startOfDay(for: running.start)
            totalDuration += running.elapsed(at: now)
            daily[day, default: 0] += running.elapsed(at: now)
            dailyEarnings[day, default: 0] += runningEarnings
        }

        var months: [Date: TimeInterval] = [:]
        let days = daily.keys.sorted()
        var previousDay: Date?
        var consecutive = 0
        for day in days {
            let duration = daily[day, default: 0]
            let earnings = dailyEarnings[day, default: 0]
            totalEarnings += earnings
            let month = calendar.dateInterval(of: .month, for: day)?.start ?? day
            months[month, default: 0] += duration
            if calendar.isDate(day, equalTo: today, toGranularity: .month) {
                monthDuration += duration
                monthEarnings += earnings
            }
            if day >= weekStart && day <= today { recentWeek += duration }
            if day >= previousStart && day < weekStart { previousWeek += duration }
            if duration >= Self.fullDayHours * 3600 { fullDays += 1 }
            if duration >= Self.longDayHours * 3600 { longDays += 1 }
            if let previousDay, calendar.dateComponents([.day], from: previousDay, to: day).day == 1 {
                consecutive += 1
            } else {
                consecutive = 1
            }
            longestStreak = max(longestStreak, consecutive)
            previousDay = day
        }
        bigMonths = months.values.filter { $0 >= Self.bigMonthHours * 3600 }.count
        // Ay toplami donguden sonra belli oluyor; tahmin burada kurulur.
        goalEstimate = InsightsGoalEstimate.make(dailyGoal: dailyGoal, monthlyGoal: monthlyGoal,
            todayDuration: daily[today, default: 0], monthDuration: monthDuration,
            recentCompleted: recentCompleted, running: running, now: now, calendar: calendar)
        var cursor = today
        if daily[cursor] == nil {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        currentStreak = WorkedDayStreak.length(endingOn: cursor, days: Set(daily.keys), calendar: calendar)
        // Mac ile ayni yuvarlama ve biriken seri bonuslari korunur.
        baseXP = Int(totalDuration / 3600 * 100)
        for (threshold, bonus) in [(3, 100), (7, 250), (14, 500), (30, 1_000), (60, 2_000)] {
            if longestStreak >= threshold { streakXP += bonus }
        }
    }
}

/// Hedeflere ne zaman ulasilacagi.
///
/// Mac gunluk hedef icin "7 gunluk ortalamayla bugunun hedefi yaklasik N gun
/// uzakta" diyor ve kalan sureyi gunluk ortalamaya bolup yukari yuvarliyor.
/// Gunluk hedef en fazla 24 saat oldugu icin bu hep "1 gun" cikiyordu: gunde
/// on bir saat calisan birine kalan bir saat icin "bir gun uzakta" demek.
/// "Kac is gunu kaldi" sorusu yalnizca aylik hedefte anlamli; gunluk hedefte
/// anlamli olan saat.
struct InsightsGoalEstimate: Equatable {
    enum Daily: Equatable {
        case off, reached
        /// Calisirken: bu hizla hedefe ulasilan an.
        case finish(Date)
        /// Calisilmiyorken ya da duraklatilmisken: simdi baslanirsa ulasilan an.
        /// Gece yarisini gecse de dogru, cunku oturum basladigi gune sayilir.
        case startNow(Date)
    }
    enum Monthly: Equatable {
        case off, reached
        /// Son 7 gunun tamamlanmis ortalamasiyla kac is gunu kaldigi ve ayin
        /// kalan gunlerine sigip sigmadigi.
        case workDays(Int, fitsInMonth: Bool)
        /// Son 7 gunde tamamlanmis is yok; ortalama yok.
        case unavailable
    }

    var daily: Daily = .off
    var monthly: Monthly = .off

    static func make(dailyGoal: Double, monthlyGoal: Double, todayDuration: TimeInterval,
                     monthDuration: TimeInterval, recentCompleted: TimeInterval,
                     running: RunningSession?, now: Date, calendar: Calendar) -> Self {
        var estimate = InsightsGoalEstimate()
        if dailyGoal > 0 {
            let remaining = dailyGoal * 3600 - todayDuration
            if remaining <= 0 {
                estimate.daily = .reached
            } else if let running, !running.isPaused {
                estimate.daily = .finish(now.addingTimeInterval(remaining))
            } else {
                estimate.daily = .startNow(now.addingTimeInterval(remaining))
            }
        }
        if monthlyGoal > 0 {
            let remaining = monthlyGoal * 3600 - monthDuration
            let average = recentCompleted / 7
            if remaining <= 0 {
                estimate.monthly = .reached
            } else if average <= 0 {
                estimate.monthly = .unavailable
            } else {
                let days = Int(ceil(remaining / average))
                let today = calendar.startOfDay(for: now)
                let monthEnd = calendar.dateInterval(of: .month, for: now)?.end ?? today
                let daysLeft = calendar.dateComponents([.day], from: today, to: monthEnd).day ?? 0
                estimate.monthly = .workDays(days, fitsInMonth: days <= daysLeft)
            }
        }
        return estimate
    }
}
