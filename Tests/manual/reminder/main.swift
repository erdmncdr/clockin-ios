import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

let now = Date(timeIntervalSince1970: 1_800_000_000)
let hour: TimeInterval = 3600
func date(_ worked: TimeInterval, hours: Int = 10, paused: Bool = false,
          reminded: Bool = false, snooze: Date? = nil) -> Date? {
    LongSessionReminderSchedule.fireDate(now: now, worked: worked, isPaused: paused,
        hours: hours, alreadyReminded: reminded, snoozedUntil: snooze)
}

check(date(0) == now.addingTimeInterval(10 * hour), "zero work reaches default threshold in ten hours")
check(date(3 * hour) == now.addingTimeInterval(7 * hour), "partial work subtracts worked time")
check(date(0, hours: 8) == now.addingTimeInterval(8 * hour), "eight hour choice")
check(date(0, hours: 12) == now.addingTimeInterval(12 * hour), "twelve hour choice")
check(date(10 * hour - 0.5) == now.addingTimeInterval(1), "subsecond boundary uses minimum notification delay")
check(date(3 * hour, paused: true) == nil, "paused session has no reminder")
check(date(3 * hour, hours: 0) == nil, "off has no reminder")
check(date(11 * hour) == now.addingTimeInterval(1), "already past threshold fires once")
check(date(10 * hour) == now.addingTimeInterval(1), "exact threshold fires once")
check(date(11 * hour, reminded: true) == nil, "consumed reminder never repeats automatically")
let snooze = LongSessionReminderSchedule.snoozeDate(now: now)
check(snooze == now.addingTimeInterval(hour), "snooze is one hour of wall time")
check(date(11 * hour, reminded: true, snooze: snooze) == snooze, "explicit snooze overrides consumed threshold")
check(date(11 * hour, paused: true, snooze: snooze) == nil, "pause suppresses snooze")
check(date(11 * hour, hours: 0, snooze: snooze) == nil, "off suppresses snooze")
check(date(11 * hour, reminded: true, snooze: now) == nil, "expired snooze does not repeat")
check(date(.nan) == nil && date(.infinity) == nil && date(-1) == nil, "invalid work is rejected")
check(date(0, hours: -1) == nil && date(0, hours: 9) == nil, "unknown choices are rejected")

var running = RunningSession(start: now.addingTimeInterval(-5 * hour), accumulated: 2 * hour,
    resumedAt: now.addingTimeInterval(-hour), note: "Example")
var state = LongSessionReminderState(start: running.start)
let original = state.reconcile(running: running, hours: 10, now: now)
check(original == now.addingTimeInterval(7 * hour), "breaks are excluded using RunningSession elapsed")
running.note = "Changed example"
check(state.reconcile(running: running, hours: 10, now: now.addingTimeInterval(60)) == original,
    "metadata edit preserves fire date")
running.accumulated = running.elapsed(at: now)
running.resumedAt = nil
check(state.reconcile(running: running, hours: 10, now: now) == nil, "pause removes pending date")
running.resumedAt = now.addingTimeInterval(hour)
check(state.reconcile(running: running, hours: 10, now: now.addingTimeInterval(hour)) == now.addingTimeInterval(8 * hour),
    "resume shifts threshold by pause duration")
check(state.reconcile(running: running, hours: 0, now: now.addingTimeInterval(hour)) == nil,
    "off clears an existing schedule")
check(state.reconcile(running: running, hours: 10, now: now.addingTimeInterval(hour)) != nil,
    "re-enabling before threshold restores reminder")

let late = now.addingTimeInterval(12 * hour)
check(state.reconcile(running: running, hours: 10, now: late) == nil,
    "delivered threshold is consumed on refresh")
let data = try JSONEncoder().encode(state)
var restored = try JSONDecoder().decode(LongSessionReminderState.self, from: data)
check(restored.reconcile(running: running, hours: 8, now: late) == nil,
    "cold launch and lowered setting cannot repeat a consumed reminder")
restored.snooze(now: late)
let snoozedDate = late.addingTimeInterval(hour)
check(restored.reconcile(running: running, hours: 10, now: late.addingTimeInterval(60)) == snoozedDate,
    "refresh preserves explicit snooze deadline")
var restoredSnooze = try JSONDecoder().decode(LongSessionReminderState.self, from: JSONEncoder().encode(restored))
check(restoredSnooze.reconcile(running: running, hours: 10, now: late.addingTimeInterval(120)) == snoozedDate,
    "snooze survives cold launch")
check(restoredSnooze.reconcile(running: running, hours: 10, now: snoozedDate) == nil,
    "delivered snooze is consumed")
restored.snooze(now: late)
running.resumedAt = nil
check(restored.reconcile(running: running, hours: 10, now: late) == nil,
    "pause cancels queued snooze")
running.resumedAt = late
check(restored.reconcile(running: running, hours: 10, now: late) == nil,
    "resume does not revive a cancelled snooze")

var overdue = LongSessionReminderState(start: running.start)
running.accumulated = 11 * hour
check(overdue.reconcile(running: running, hours: 8, now: late) == late.addingTimeInterval(1),
    "lowering threshold schedules a single overdue reminder")
check(overdue.reconcile(running: running, hours: 8, now: late) == late.addingTimeInterval(1),
    "rapid refresh retains overdue deadline")
overdue = try JSONDecoder().decode(LongSessionReminderState.self, from: JSONEncoder().encode(overdue))
check(overdue.reconcile(running: running, hours: 8, now: late.addingTimeInterval(2)) == nil,
    "persisted overdue reminder cannot loop")

check(LongSessionReminderSchedule.matches(start: running.start, running: running), "matching notification identity accepted")
check(!LongSessionReminderSchedule.matches(start: running.start.addingTimeInterval(-1), running: running),
    "stale session identity rejected")
check(!LongSessionReminderSchedule.matches(start: running.start, running: nil), "ended or cancelled session rejected")
check(!LongSessionReminderSchedule.matches(start: nil, running: running), "missing identity rejected")
// 3 saat calisilip mola verilmis, sonra devam edilmis bir oturum.
let resumed = RunningSession(start: now, accumulated: 3 * hour, resumedAt: now.addingTimeInterval(4 * hour), note: "")
let evening = now.addingTimeInterval(12 * hour)
check(LongSessionReminderSchedule.earliestEnd(running: resumed, now: evening) == resumed.resumedAt,
    "earliest end is the last resume")
check(LongSessionReminderSchedule.validEnd(resumed.resumedAt!, running: resumed, now: evening)
    && LongSessionReminderSchedule.validEnd(evening, running: resumed, now: evening), "both end time boundaries accepted")
check(!LongSessionReminderSchedule.validEnd(now.addingTimeInterval(2 * hour), running: resumed, now: evening),
    "end inside the worked time before the break is rejected")
check(!LongSessionReminderSchedule.validEnd(evening.addingTimeInterval(1), running: resumed, now: evening),
    "future end rejected")
check(resumed.elapsed(at: resumed.resumedAt!) == 3 * hour, "ending at the last resume keeps the earlier worked time")
var paused = resumed
paused.resumedAt = nil
check(LongSessionReminderSchedule.earliestEnd(running: paused, now: evening) == paused.start,
    "paused session falls back to start")
var future = resumed
future.resumedAt = evening.addingTimeInterval(hour)
check(LongSessionReminderSchedule.earliestEnd(running: future, now: evening) == evening, "future resume clamps to now")
print("\(checks) reminder checks passed")
