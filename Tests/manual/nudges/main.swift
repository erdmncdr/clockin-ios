import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
let base = calendar.date(from: DateComponents(year: 2027, month: 1, day: 18))!
let hour: TimeInterval = 3600
@MainActor func date(_ offset: Int = 0, _ hours: Int = 8, _ minutes: Int = 0) -> Date {
    let day = calendar.date(byAdding: .day, value: offset, to: base)!
    return NudgePlanner.time(on: day, minutes: hours * 60 + minutes, calendar: calendar)
}
@MainActor func session(_ offset: Int, start: Int = 10, end: Int = 12) -> WorkSession {
    WorkSession(id: UUID(), start: date(offset, start), end: date(offset, end),
        duration: Double(end - start) * hour, note: "Example", hourlyRate: 1, source: "manual")
}
@MainActor func input(now: Date? = nil, work: [WorkSession] = []) -> NudgeInput {
    var daily: [Date: TimeInterval] = [:]
    for session in work { daily[calendar.startOfDay(for: session.start), default: 0] += session.duration }
    return NudgeInput(now: now ?? date(), calendar: calendar, dailyDurations: daily, sessions: work)
}
@MainActor func kind(_ value: NudgeInput, _ kind: NudgeKind) -> [PlannedNudge] {
    NudgePlanner.plan(value).filter { $0.kind == kind }
}
@MainActor func nudge(_ kind: NudgeKind, _ hours: Int, offset: Int = 0, sequence: Int = 0) -> PlannedNudge {
    NudgePlanner.make(kind, date: date(offset, hours), input: input(), sequence: sequence)
}

let empty = input()
check(NudgePlanner.habits(empty) == NudgeHabit(expectedWeekdays: Set(2...6), typicalStartHour: 10), "no history defaults to weekdays and ten")
let sparse = input(work: (-4 ... -1).map { session($0, start: 18, end: 19) })
check(NudgePlanner.habits(sparse).typicalStartHour == 10, "fewer than five worked days uses default")
let weekends = input(work: [-1, -2, -8, -9, -15, -16].map { session($0) })
check(NudgePlanner.habits(weekends).expectedWeekdays == [1, 7], "two of four weekday occurrences determines expected days")
let old = input(work: [-29, -30, -31, -32, -33, -34].map { session($0, start: 18, end: 19) })
check(NudgePlanner.habits(old).typicalStartHour == 10, "history before the previous 28 days is excluded")
var median = input(work: zip(-5 ... -1, [6, 8, 10, 12, 18]).map { session($0.0, start: $0.1, end: $0.1 + 1) })
check(NudgePlanner.habits(median).typicalStartHour == 10, "odd median uses first start hour per day")
median.sessions.append(session(-3, start: 18, end: 19))
check(NudgePlanner.habits(median).typicalStartHour == 10, "second session on the same day does not skew median")
let even = input(work: zip(-6 ... -1, [6, 8, 9, 10, 12, 18]).map { session($0.0, start: $0.1, end: $0.1 + 1) })
check(NudgePlanner.habits(even).typicalStartHour == 9.5, "even median averages the middle hours")
check(NudgePlanner.habits(even).anchorMinutes == 11 * 60, "median plus ninety minutes retains half hours")
check(NudgePlanner.habits(input(work: (-5 ... -1).map { session($0, start: 3, end: 4) })).anchorMinutes == 9 * 60, "anchor clamps to nine")
check(NudgePlanner.habits(input(work: (-5 ... -1).map { session($0, start: 18, end: 19) })).anchorMinutes == 14 * 60, "anchor clamps to fourteen")

var dailyWorker = input(work: (-28 ... -1).map { session($0) })
check(kind(dailyWorker, .noWorkToday).count == 7, "all expected days plan today plus six future days")
check(kind(dailyWorker, .noWorkToday).map(\.day) == (0...6).map { date($0, 0) }, "seven dates are local calendar days")
dailyWorker.dailyDurations[base] = hour
check(kind(dailyWorker, .noWorkToday).count == 6, "work today removes today's no-work nudge")
var running = input()
running.running = RunningSession(start: date(0, 7), accumulated: 0, resumedAt: date(0, 7), note: "")
check(!kind(running, .noWorkToday).contains { $0.day == base }, "unpaused running session counts as worked today")
running.running?.resumedAt = nil
check(!kind(running, .noWorkToday).contains { $0.day == base }, "paused running session also counts as worked today")
running.running?.start = date(-1, 23)
check(kind(running, .noWorkToday).contains { $0.day == base }, "overnight running session belongs to its start day")

var paused = input(now: date(0, 10))
paused.running = RunningSession(start: date(0, 8), accumulated: hour, resumedAt: nil, note: "")
paused.observedPauseDate = date(0, 10)
check(kind(paused, .pausedTooLong).map(\.fireDate) == [date(0, 10, 45), date(0, 12)], "pause schedules forty-five minutes and two hours")
check(kind(paused, .pausedTooLong).map(\.sequence) == [1, 2], "pause occurrences have stable distinct identities")
var resumed = paused
let resumedNow = resumed.now
resumed.running?.resumedAt = resumedNow
check(kind(resumed, .pausedTooLong).isEmpty, "resume cancels both pause reminders")
resumed.running = nil
check(kind(resumed, .pausedTooLong).isEmpty, "clock out or cancel removes pause reminders")
var observation = NudgePauseObservation.reconcile(nil, running: paused.running, now: paused.now)
check(observation?.date == paused.now, "first paused observation records wall time")
paused.running?.note = "Edited example"
check(NudgePauseObservation.reconcile(observation, running: paused.running, now: date(0, 11)) == observation, "note edit preserves pause observation")
observation = try JSONDecoder().decode(NudgePauseObservation.self, from: JSONEncoder().encode(observation!))
check(NudgePauseObservation.reconcile(observation, running: paused.running, now: date(0, 11))?.date == date(0, 10), "pause observation survives persistence")
paused.running?.accumulated += 60
check(NudgePauseObservation.reconcile(observation, running: paused.running, now: date(0, 11))?.date == date(0, 11), "new accumulated value starts a new pause observation")
check(NudgePauseObservation.reconcile(observation, running: nil, now: date()) == nil, "ending clears pause observation")
var active = paused.running!
active.resumedAt = date(0, 11)
check(NudgePauseObservation.reconcile(observation, running: active, now: date(0, 11)) == nil, "resume clears persisted pause")
active.resumedAt = nil
active.start = date(0, 9)
check(NudgePauseObservation.reconcile(observation, running: active, now: date(0, 11))?.start == active.start, "new session start replaces pause identity")

var left = input(now: date(0, 17), work: [session(0, start: 10, end: 17)])
left.dailyGoalHours = 8
check(kind(left, .leftEarly).first?.fireDate == date(0, 18), "leaving below goal schedules one hour after last end")
check(kind(left, .leftEarly).first?.body.contains("1h") == true, "left-early copy contains compact remaining duration")
check(kind(left, .goalMissed).count == 1, "goal reminder remains with three hours of spacing")
var lateLeft = input(now: date(0, 18), work: [session(0, start: 12, end: 18)])
lateLeft.dailyGoalHours = 8
check(kind(lateLeft, .leftEarly).count == 1 && kind(lateLeft, .goalMissed).isEmpty, "left-early at nineteen suppresses goal at the exact two-hour boundary")
var pastLeft = lateLeft
pastLeft.now = date(0, 20)
pastLeft.consumed = kind(lateLeft, .leftEarly)
check(kind(pastLeft, .goalMissed).isEmpty, "already delivered left-early also suppresses close goal reminder")
var atNineteen = input(now: date(0, 19), work: [session(0, start: 16, end: 19)])
atNineteen.dailyGoalHours = 8
check(kind(atNineteen, .leftEarly).isEmpty && kind(atNineteen, .goalMissed).count == 1, "last end at nineteen is not left early")
left.dailyGoalHours = 7
check(kind(left, .leftEarly).isEmpty && kind(left, .goalMissed).isEmpty, "reached goal has neither goal nudge")
left.dailyGoalHours = 0
check(kind(left, .leftEarly).isEmpty && kind(left, .goalMissed).isEmpty, "disabled goal has neither goal nudge")
var pauseGoal = paused
pauseGoal.dailyGoalHours = 8
check(kind(pauseGoal, .goalMissed).isEmpty, "higher-priority pause pair consumes daily cap")
pauseGoal.running?.resumedAt = date(0, 10)
check(kind(pauseGoal, .goalMissed).isEmpty, "unpaused running session suppresses goal reminder")

let streak2 = input(work: [-2, -1].map { session($0) })
let streak3 = input(work: [-3, -2, -1].map { session($0) })
check(kind(streak2, .streakAtRisk).isEmpty, "two-day streak does not trigger")
check(kind(streak3, .streakAtRisk).first?.fireDate == date(0, 20, 30), "three-day streak triggers at twenty-thirty")
var workedStreak = streak3
workedStreak.dailyDurations[base] = 0
check(kind(workedStreak, .streakAtRisk).isEmpty, "zero-duration completed day counts just like Insights")
let quiet = input(work: [session(-3)])
check(kind(quiet, .goneQuiet).map(\.day) == [date(0, 0), date(4, 0)], "gone quiet only targets third and seventh days")
check(!kind(quiet, .noWorkToday).contains { [date(0, 0), date(4, 0)].contains($0.day) }, "gone quiet replaces no-work on the same day")
let quiet4 = input(work: [session(-4)])
check(kind(quiet4, .goneQuiet).map(\.day) == [date(3, 0)], "fourth quiet day only plans remaining seventh-day reminder")
check(kind(input(work: [session(-8)]), .goneQuiet).isEmpty, "no recurring gone-quiet nudges beyond day seven")
check(kind(input(work: [session(-2)]), .goneQuiet).isEmpty, "gone-quiet planning begins after three quiet days")
check(kind(empty, .goneQuiet).isEmpty, "no fabricated quiet anniversary for an empty history")

let candidates = [nudge(.noWorkToday, 10), nudge(.streakAtRisk, 20), nudge(.leftEarly, 16), nudge(.goalMissed, 21)]
let selected = NudgePlanner.select(candidates, input: empty)
check(Set(selected.map(\.kind)) == [.leftEarly, .goalMissed], "daily cap keeps highest priority kinds")
check(NudgePlanner.select([nudge(.leftEarly, 16), nudge(.noWorkToday, 17)], input: empty).count == 1, "less than two hours apart drops lower priority")
check(NudgePlanner.select([nudge(.leftEarly, 16), nudge(.noWorkToday, 18)], input: empty).count == 2, "exact two-hour gap is allowed normally")
let pausePair = kind(paused, .pausedTooLong)
check(pausePair.count == 2 && pausePair[1].fireDate.timeIntervalSince(pausePair[0].fireDate) == 75 * 60, "second pause fire is exempt from spacing")
check(NudgePlanner.select([nudge(.leftEarly, 7), nudge(.goalMissed, 22)], input: empty).isEmpty, "quiet hours drop requests without shifting")
var beforeEight = input(now: date(0, 7))
check(NudgePlanner.select([nudge(.leftEarly, 8), nudge(.goalMissed, 21)], input: beforeEight).count == 2, "eight and twenty-one are outside quiet hours")
check(NudgePlanner.select([nudge(.leftEarly, 8), nudge(.goalMissed, 7)], input: empty).isEmpty, "past and exact-now requests are not scheduled")
var nightPause = paused
nightPause.now = date(0, 21, 30)
nightPause.observedPauseDate = nightPause.now
check(kind(nightPause, .pausedTooLong).isEmpty, "pause fires during quiet hours are dropped")
let many = (0...8).flatMap { [nudge(.leftEarly, 10, offset: $0), nudge(.goalMissed, 21, offset: $0)] }
check(NudgePlanner.select(many, input: empty).count == 12, "pending request cap is twelve")
check(NudgePlanner.select(many, input: empty).last?.day == date(5, 0), "pending cap retains nearest days")
var spent = input(now: date(0, 14))
spent.consumed = [nudge(.noWorkToday, 10), nudge(.pausedTooLong, 12, sequence: 2)]
check(NudgePlanner.select([nudge(.goalMissed, 21)], input: spent).isEmpty, "replanning cannot reset today's delivered cap")
spent.consumed = [nudge(.noWorkToday, 13)]
spent.now = date(0, 13, 30)
check(NudgePlanner.select([nudge(.leftEarly, 14), nudge(.goalMissed, 15)], input: input(now: date(0, 13, 30))).count == 1, "new candidates still obey priority and spacing")
check(NudgePlanner.select([nudge(.leftEarly, 14)], input: spent).isEmpty, "delivered requests participate in two-hour spacing")
var spentAgain = input()
spentAgain.consumed = [nudge(.noWorkToday, 10)]
spentAgain.now = date(0, 11)
check(NudgePlanner.select([nudge(.noWorkToday, 14)], input: spentAgain).isEmpty, "same kind and day cannot repeat with a changed anchor")

check(NudgePlanner.plan(quiet) == NudgePlanner.plan(quiet), "copy and identifiers are deterministic across runs")
var friendly = quiet
friendly.tone = .friendly
let grumpyPlan = NudgePlanner.plan(quiet)
let friendlyPlan = NudgePlanner.plan(friendly)
check(grumpyPlan.map(\.identifier) == friendlyPlan.map(\.identifier), "tone changes preserve identifiers and dates")
check(zip(grumpyPlan, friendlyPlan).allSatisfy { $0.imageName == "angry1" && $1.imageName == "pose2" && $0.body != $1.body }, "tone changes text and image")
for tone in NudgeTone.allCases {
    for kind in NudgeKind.allCases {
        let lines = (0..<4).map { NudgeCopy.text(kind: kind, tone: tone, day: date($0, 0), calendar: calendar, remaining: 7800).body }
        check(Set(lines).count == 4, "four deterministic variants for \(tone.rawValue) \(kind.rawValue)")
    }
}
check(grumpyPlan.allSatisfy { $0.identifier.hasPrefix("Clockin.Nudge.\($0.kind.rawValue).2027") }, "identifiers use required prefix kind and calendar date")
var off = quiet
off.enabled = false
check(NudgePlanner.plan(off).isEmpty && NudgePlanner.currentMood(off) == nil, "disabled input suppresses notifications and mood")
check(NudgePlanner.currentMood(empty) == nil, "before anchor mood is normal")
var pastAnchor = empty
pastAnchor.now = date(0, 11, 30)
check(NudgePlanner.currentMood(pastAnchor)?.kind == .noWorkToday, "expected day at anchor gets no-work mood")
var weekend = input(now: date(5, 15))
check(NudgePlanner.currentMood(weekend) == nil, "unexpected day has no no-work mood")
var moodPause = paused
moodPause.now = date(0, 10, 44)
check(NudgePlanner.currentMood(moodPause) == nil, "short pause keeps normal mood")
moodPause.now = date(0, 10, 45)
check(NudgePlanner.currentMood(moodPause)?.kind == .pausedTooLong, "forty-five minute pause gets grumpy mood")
moodPause.tone = .friendly
check(NudgePlanner.currentMood(moodPause)?.isAngry == false, "friendly mood uses normal companion")
let moodResumeDate = moodPause.now
moodPause.running?.resumedAt = moodResumeDate
check(NudgePlanner.currentMood(moodPause) == nil, "working always restores normal mood")
var missed = atNineteen
missed.now = date(0, 21)
check(NudgePlanner.currentMood(missed)?.kind == .goalMissed, "missed goal after twenty-one gets goal mood")
var leftMood = lateLeft
leftMood.now = date(0, 19)
check(NudgePlanner.currentMood(leftMood)?.kind == .leftEarly, "left-early mood begins after one hour")
let broken = input(work: [-4, -3, -2].map { session($0) })
check(NudgePlanner.currentMood(broken)?.kind == .streakAtRisk, "missed yesterday after three days gets broken streak mood")
check(NudgePlanner.currentMood(broken)?.line != NudgePlanner.currentMood(pastAnchor)?.line, "broken streak has matching distinct copy")
check(NudgePlanner.currentMood(quiet)?.kind == .goneQuiet, "three quiet days gets return mood")
var atRisk = streak3
atRisk.now = date(0, 20, 30)
check(NudgePlanner.currentMood(atRisk)?.kind == .streakAtRisk, "evening streak risk takes precedence over no-work mood")
var yesterdayRunning = broken
yesterdayRunning.running = RunningSession(start: date(-1, 23), accumulated: 0, resumedAt: date(-1, 23), note: "")
check(NudgePlanner.currentMood(yesterdayRunning) == nil, "overnight active session always uses working companion")

var dst = Calendar(identifier: .gregorian)
dst.timeZone = TimeZone(identifier: "America/New_York")!
let dstNow = dst.date(from: DateComponents(year: 2027, month: 3, day: 13, hour: 8))!
var dstInput = NudgeInput(now: dstNow, calendar: dst)
for offset in -28 ... -1 {
    let day = dst.date(byAdding: .day, value: offset, to: dst.startOfDay(for: dstNow))!
    dstInput.dailyDurations[day] = hour
}
let dstPlan = NudgePlanner.plan(dstInput).filter { $0.kind == .noWorkToday }
check(dstPlan.count == 7 && dstPlan.allSatisfy { dst.component(.hour, from: $0.fireDate) == 11 && dst.component(.minute, from: $0.fireDate) == 30 }, "injected timezone preserves anchor across daylight saving")
check(dstPlan[1].fireDate.timeIntervalSince(dstPlan[0].fireDate) == 23 * hour, "calendar-day planning avoids fixed twenty-four-hour drift")
print("\(checks) nudge checks passed")
