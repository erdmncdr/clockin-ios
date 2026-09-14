import Foundation

enum NudgeTone: String, CaseIterable, Sendable {
    case grumpy = "Grumpy", friendly = "Friendly"
    var imageName: String { self == .grumpy ? "angry1" : "pose2" }
}

enum NudgeKind: String, Codable, CaseIterable, Sendable {
    case pausedTooLong, leftEarly, goalMissed, streakAtRisk, noWorkToday, goneQuiet
    var priority: Int { Self.allCases.firstIndex(of: self)! }
}

struct PlannedNudge: Equatable, Codable, Sendable {
    let kind: NudgeKind
    let fireDate: Date
    let day: Date
    let identifier: String
    let title: String
    let body: String
    let imageName: String
    let sequence: Int
}

struct NudgeMood: Equatable, Sendable {
    let kind: NudgeKind
    let isAngry: Bool
    let line: String
}

struct NudgeInput: Sendable {
    var now: Date
    var calendar: Calendar
    var dailyDurations: [Date: TimeInterval] = [:]
    var sessions: [WorkSession] = []
    var running: RunningSession?
    var observedPauseDate: Date?
    var dailyGoalHours: Double = 0
    var tone: NudgeTone = .grumpy
    var enabled = true
    // Teslim saati gecen istekler, yeniden planlamada gunluk hakki tuketir.
    var consumed: [PlannedNudge] = []
}

struct NudgeHabit: Equatable {
    let expectedWeekdays: Set<Int>
    let typicalStartHour: Double
    var anchorMinutes: Int { min(14 * 60, max(9 * 60, Int(typicalStartHour * 60) + 90)) }
}

enum NudgePlanner {
    static let enabledKey = "Clockin.NudgesEnabled"
    static let toneKey = "Clockin.NudgeTone"
    static let prefix = "Clockin.Nudge."
    static let maximumPending = 12

    static func habits(_ input: NudgeInput) -> NudgeHabit {
        let calendar = input.calendar
        let today = calendar.startOfDay(for: input.now)
        let cutoff = calendar.date(byAdding: .day, value: -28, to: today)!
        let days = workedDays(input).filter { $0 >= cutoff && $0 < today }
        guard days.count >= 5 else { return NudgeHabit(expectedWeekdays: Set(2...6), typicalStartHour: 10) }
        var counts: [Int: Int] = [:]
        for day in days { counts[calendar.component(.weekday, from: day), default: 0] += 1 }
        var firstStarts: [Date: Date] = [:]
        let starts = input.sessions.map(\.start) + (input.running.map { [$0.start] } ?? [])
        for start in starts where start >= cutoff && start < today {
            let day = calendar.startOfDay(for: start)
            guard days.contains(day) else { continue }
            firstStarts[day] = min(firstStarts[day] ?? start, start)
        }
        let hours = firstStarts.values.map { Double(calendar.component(.hour, from: $0)) }.sorted()
        let median: Double
        if hours.isEmpty { median = 10 }
        else if hours.count.isMultiple(of: 2) { median = (hours[hours.count / 2 - 1] + hours[hours.count / 2]) / 2 }
        else { median = hours[hours.count / 2] }
        return NudgeHabit(expectedWeekdays: Set(counts.filter { $0.value >= 2 }.keys), typicalStartHour: median)
    }

    static func plan(_ input: NudgeInput) -> [PlannedNudge] {
        guard input.enabled else { return [] }
        let calendar = input.calendar
        let today = calendar.startOfDay(for: input.now)
        let days = workedDays(input)
        let habit = habits(input)
        let remaining = remainingTime(input)
        var candidates: [PlannedNudge] = []
        func add(_ kind: NudgeKind, _ date: Date, sequence: Int = 0) {
            candidates.append(make(kind, date: date, input: input, sequence: sequence))
        }
        if input.running?.isPaused == true, let pause = input.observedPauseDate, pause <= input.now {
            add(.pausedTooLong, pause.addingTimeInterval(45 * 60), sequence: 1)
            add(.pausedTooLong, pause.addingTimeInterval(2 * 3600), sequence: 2)
        }
        if input.running == nil, days.contains(today), remaining > 0,
           let end = lastEndToday(input), calendar.component(.hour, from: end) < 19 {
            add(.leftEarly, end.addingTimeInterval(3600))
        }
        if days.contains(today), remaining > 0, input.running?.isPaused != false {
            add(.goalMissed, time(on: today, minutes: 21 * 60, calendar: calendar))
        }
        if !days.contains(today), streakEndingYesterday(input) >= 3 {
            add(.streakAtRisk, time(on: today, minutes: 20 * 60 + 30, calendar: calendar))
        }
        var quietDays: Set<Date> = []
        if let last = days.filter({ $0 <= today }).max(),
           calendar.dateComponents([.day], from: last, to: today).day ?? 0 >= 3 {
            for offset in [3, 7] {
                let day = calendar.date(byAdding: .day, value: offset, to: last)!
                quietDays.insert(day)
                if !days.contains(day) { add(.goneQuiet, time(on: day, minutes: habit.anchorMinutes, calendar: calendar)) }
            }
        }
        for offset in 0...6 {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            if habit.expectedWeekdays.contains(calendar.component(.weekday, from: day)),
               !days.contains(day), !quietDays.contains(day) {
                add(.noWorkToday, time(on: day, minutes: habit.anchorMinutes, calendar: calendar))
            }
        }
        return select(candidates, input: input)
    }

    // Ayni gun tekrar acilsa da onceki teslimler kotayi ve araligi korur.
    static func select(_ candidates: [PlannedNudge], input: NudgeInput) -> [PlannedNudge] {
        let consumed = input.consumed.filter { $0.fireDate <= input.now }
        var accepted: [PlannedNudge] = []
        let ordered = candidates.sorted {
            if $0.kind.priority != $1.kind.priority { return $0.kind.priority < $1.kind.priority }
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            return $0.identifier < $1.identifier
        }
        for candidate in ordered {
            let hour = input.calendar.component(.hour, from: candidate.fireDate)
            guard candidate.fireDate > input.now, hour >= 8, hour < 22,
                  !consumed.contains(where: { $0.identifier == candidate.identifier }),
                  !accepted.contains(where: { $0.identifier == candidate.identifier }) else { continue }
            let sameDay = (consumed + accepted).filter {
                input.calendar.isDate($0.fireDate, inSameDayAs: candidate.fireDate)
            }
            guard sameDay.count < 2 else { continue }
            if candidate.kind == .goalMissed, sameDay.contains(where: {
                $0.kind == .leftEarly && candidate.fireDate.timeIntervalSince($0.fireDate) >= 0
                    && candidate.fireDate.timeIntervalSince($0.fireDate) <= 2 * 3600
            }) { continue }
            let secondPause = candidate.kind == .pausedTooLong && candidate.sequence == 2
            guard sameDay.allSatisfy({ previous in
                let previousSecond = previous.kind == .pausedTooLong && previous.sequence == 2
                return secondPause || previousSecond || abs(candidate.fireDate.timeIntervalSince(previous.fireDate)) >= 2 * 3600
            }) else { continue }
            accepted.append(candidate)
        }
        // Gunluk oncelik seciminden sonra en yakin gunleri kuyrukta tut.
        return Array(accepted.sorted { $0.fireDate < $1.fireDate }.prefix(maximumPending))
    }

    static func currentMood(_ input: NudgeInput) -> NudgeMood? {
        guard input.enabled, input.running?.isPaused != false else { return nil }
        let calendar = input.calendar
        let today = calendar.startOfDay(for: input.now)
        let days = workedDays(input)
        let habit = habits(input)
        var kind: NudgeKind?
        var broken = false
        if input.running?.isPaused == true, let pause = input.observedPauseDate,
           input.now.timeIntervalSince(pause) >= 45 * 60 { kind = .pausedTooLong }
        else if days.contains(today), remainingTime(input) > 0,
                input.now >= time(on: today, minutes: 21 * 60, calendar: calendar) { kind = .goalMissed }
        else if input.running == nil, days.contains(today), remainingTime(input) > 0,
                let end = lastEndToday(input), calendar.component(.hour, from: end) < 19,
                input.now >= end.addingTimeInterval(3600) { kind = .leftEarly }
        else if !days.contains(today) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            let before = calendar.date(byAdding: .day, value: -2, to: today)!
            broken = !days.contains(yesterday) && WorkedDayStreak.length(endingOn: before, days: days, calendar: calendar) >= 3
            if broken { kind = .streakAtRisk }
            else if let last = days.max(), calendar.dateComponents([.day], from: last, to: today).day ?? 0 >= 3 { kind = .goneQuiet }
            else if streakEndingYesterday(input) >= 3,
                    input.now >= time(on: today, minutes: 20 * 60 + 30, calendar: calendar) { kind = .streakAtRisk }
            else if habit.expectedWeekdays.contains(calendar.component(.weekday, from: today)),
                    input.now >= time(on: today, minutes: habit.anchorMinutes, calendar: calendar) { kind = .noWorkToday }
        }
        guard let kind else { return nil }
        let copy = NudgeCopy.text(kind: kind, tone: input.tone, day: today, calendar: calendar,
                                  remaining: remainingTime(input), brokenStreak: broken)
        return NudgeMood(kind: kind, isAngry: input.tone == .grumpy, line: copy.body)
    }

    static func workedDays(_ input: NudgeInput) -> Set<Date> {
        var days = Set(input.dailyDurations.keys.filter { $0 <= input.now }.map { input.calendar.startOfDay(for: $0) })
        if let running = input.running, running.start <= input.now { days.insert(input.calendar.startOfDay(for: running.start)) }
        return days
    }

    static func streakEndingYesterday(_ input: NudgeInput) -> Int {
        let yesterday = input.calendar.date(byAdding: .day, value: -1, to: input.calendar.startOfDay(for: input.now))!
        return WorkedDayStreak.length(endingOn: yesterday, days: workedDays(input), calendar: input.calendar)
    }

    static func time(on day: Date, minutes: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)!
    }

    private static func remainingTime(_ input: NudgeInput) -> TimeInterval {
        guard input.dailyGoalHours.isFinite, input.dailyGoalHours > 0 else { return 0 }
        let today = input.calendar.startOfDay(for: input.now)
        let completed = input.dailyDurations.filter { input.calendar.isDate($0.key, inSameDayAs: today) }.values.reduce(0, +)
        let active = input.running.map { input.calendar.isDate($0.start, inSameDayAs: today) ? $0.elapsed(at: input.now) : 0 } ?? 0
        return max(0, input.dailyGoalHours * 3600 - completed - active)
    }

    private static func lastEndToday(_ input: NudgeInput) -> Date? {
        input.sessions.filter {
            input.calendar.isDate($0.start, inSameDayAs: input.now)
                && input.calendar.isDate($0.end, inSameDayAs: input.now) && $0.end <= input.now
        }.map(\.end).max()
    }

    static func make(_ kind: NudgeKind, date: Date, input: NudgeInput, sequence: Int = 0) -> PlannedNudge {
        let day = input.calendar.startOfDay(for: date)
        let components = input.calendar.dateComponents([.year, .month, .day], from: day)
        let stamp = String(format: "%04d%02d%02d", components.year!, components.month!, components.day!)
        let suffix = sequence == 0 ? "" : ".\(sequence)"
        let copy = NudgeCopy.text(kind: kind, tone: input.tone, day: day, calendar: input.calendar, remaining: remainingTime(input))
        return PlannedNudge(kind: kind, fireDate: date, day: day, identifier: "\(prefix)\(kind.rawValue).\(stamp)\(suffix)",
                            title: copy.title, body: copy.body, imageName: input.tone.imageName, sequence: sequence)
    }
}

struct NudgePauseObservation: Codable, Equatable {
    let start: Date
    let accumulated: TimeInterval
    let date: Date

    static func reconcile(_ previous: Self?, running: RunningSession?, now: Date) -> Self? {
        guard let running, running.isPaused else { return nil }
        if let previous, previous.start == running.start, previous.accumulated == running.accumulated {
            return previous
        }
        return Self(start: running.start, accumulated: running.accumulated, date: now)
    }
}
