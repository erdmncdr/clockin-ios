import Foundation

var checks = 0
@MainActor func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL: \(message)") }
    checks += 1
    print("ok \(message)")
}
func badge(_ id: String) -> CelebrationBadge { .init(id: id, title: "Badge \(id)", icon: "star") }
func show(_ queue: inout CelebrationQueue, now: Double = 100, blocked: Bool = false, active: Bool = true, visible: Bool = true) {
    queue.presentNext(active: active, blocked: blocked, companionVisible: visible, now: now)
}
let day = Date(timeIntervalSince1970: 1_700_000_000)
var archive = CelebrationState()
archive.level = 56
archive.focusHours = 270
archive.badges = (1...8).map { badge(String($0)) }
archive.day = day
archive.streak = 30

var first = CelebrationQueue()
first.ingest(archive, now: 0, canReact: true)
check(first.pending.isEmpty, "existing archive is silent on first run")
check(first.lastLevel == 56, "first run seeds current level")
check(first.seenBadgeIDs == Set(archive.badges.map(\.id)), "first run seeds every unlocked badge")
show(&first)
check(first.current == nil, "first run has no presentation")

var level = CelebrationQueue(lastLevel: 54, seenBadgeIDs: Set(archive.badges.map(\.id)))
level.ingest(archive, now: 0, canReact: false)
check(level.pending == [.levelUp(level: 56, hours: 270)], "stored level catches background progress")
check(level.lastLevel == 54, "queued level is not marked shown")
show(&level, blocked: true)
check(level.current == nil && level.pending.count == 1, "sheet queues level")
show(&level, active: false)
check(level.current == nil, "inactive scene queues level")
var newer = archive
newer.level = 60
level.ingest(newer, now: 1, canReact: false)
check(level.pending == [.levelUp(level: 60, hours: 270)], "multiple gained levels coalesce to latest")
show(&level)
check(level.current == .levelUp(level: 60, hours: 270), "free screen presents latest level")
check(level.lastLevel == 60, "shown level is persisted")
level.finish()
level.ingest(newer, now: 2, canReact: false)
check(level.pending.isEmpty, "same level never repeats")
level.ingest(archive, now: 3, canReact: false)
check(level.pending.isEmpty, "lower restored level does not celebrate")
var relaunched = CelebrationQueue(lastLevel: level.lastLevel, seenBadgeIDs: level.seenBadgeIDs)
relaunched.ingest(newer, now: 0, canReact: false)
check(relaunched.pending.isEmpty, "persistence suppresses replay after relaunch")

var badges = CelebrationQueue(lastLevel: 56, seenBadgeIDs: ["1", "2"])
badges.ingest(archive, now: 0, canReact: false)
check(badges.pending.count == 4, "six unlocks create three banners plus summary")
check(badges.pending[0] == .badge(badge("3")), "seen ids excluded")
check(badges.pending[1] == .badge(badge("4")), "second unseen id ordered")
check(badges.pending[2] == .badge(badge("5")), "third unseen id ordered")
check(badges.pending[3] == .moreBadges(["6", "7", "8"]), "overflow preserves exact count and ids")
badges.ingest(archive, now: 1, canReact: false)
check(badges.pending.count == 4, "queued ids deduplicated")
show(&badges, blocked: true)
check(badges.current == nil, "badge waits behind sheet")
check(badges.seenBadgeIDs == ["1", "2"], "queued badges are not marked shown")
for index in 3...5 {
    show(&badges)
    check(badges.current == .badge(badge(String(index))), "badge \(index) presents in order")
    check(badges.seenBadgeIDs?.contains(String(index)) == true, "presented badge \(index) marked seen")
    badges.finish()
}
show(&badges)
check(badges.current == .moreBadges(["6", "7", "8"]), "fourth banner is and N more")
check(badges.seenBadgeIDs == Set(archive.badges.map(\.id)), "summary marks overflow ids seen")
badges.finish()
var locked = archive
locked.badges = []
badges.ingest(locked, now: 2, canReact: false)
badges.ingest(archive, now: 3, canReact: false)
check(badges.pending.isEmpty, "relocked streak badges do not repeat")

var empty = CelebrationQueue()
var idle = CelebrationState()
idle.day = day
empty.ingest(idle, now: 0, canReact: true)
check(empty.seenBadgeIDs == [], "empty installation seeds an empty set")
var working = idle
working.sessionStart = day
empty.ingest(working, now: 0, canReact: true)
check(empty.pending == [.reaction(.clockIn)], "clock in queues only a live reaction")
show(&empty, now: 0)
check(empty.current == .reaction(.clockIn), "clock in reaction plays")
check(empty.lastReactionAt == 0, "reaction gate uses presentation time")
empty.finish()
var paused = working
paused.paused = true
empty.ingest(paused, now: 19.99, canReact: true)
check(empty.pending.isEmpty, "reaction suppressed before 20 seconds")
empty.ingest(working, now: 20, canReact: true)
empty.ingest(paused, now: 20, canReact: true)
check(empty.pending == [.reaction(.pause)], "reaction allowed at 20 seconds")
show(&empty, now: 20)
empty.ingest(working, now: 50, canReact: true)
empty.ingest(paused, now: 51, canReact: true)
check(empty.pending.isEmpty, "no overlapping reactions")
empty.suspend()
check(empty.pending.isEmpty && empty.current == nil, "background drops in-flight reaction")

func triggers(_ old: CelebrationState?, _ new: CelebrationState) -> [CelebrationReaction] {
    CelebrationRules.reactions(from: old, to: new)
}
check(triggers(nil, archive).isEmpty, "first state never generates live reactions")
check(triggers(idle, working) == [.clockIn], "clock in trigger")
check(triggers(working, paused) == [.pause], "pause trigger")
check(triggers(paused, working).isEmpty, "resume is silent")
var stopped = idle
stopped.savedPreviousSession = true
check(triggers(working, stopped) == [.clockOut], "saved clock out trigger")
check(triggers(working, idle).isEmpty, "cancel is not clock out")
var beforeGoal = working
beforeGoal.dailyGoal = 2
beforeGoal.dailyHours = 1.99
var afterGoal = beforeGoal
afterGoal.dailyHours = 2
check(triggers(beforeGoal, afterGoal) == [.dailyGoal], "daily goal crossing")
check(triggers(afterGoal, afterGoal).isEmpty, "reached goal does not repeat")
afterGoal.dailyGoal = 1
check(triggers(beforeGoal, afterGoal).isEmpty, "goal edits are silent")
afterGoal = beforeGoal
afterGoal.dailyHours = 3
afterGoal.day = day.addingTimeInterval(86400)
check(triggers(beforeGoal, afterGoal).isEmpty, "new day does not replay old goal")
var beforeMoney = working
beforeMoney.earnings = 9.9
beforeMoney.nextMoneyTarget = 10
var afterMoney = beforeMoney
afterMoney.earnings = 10
afterMoney.nextMoneyTarget = 20
check(triggers(beforeMoney, afterMoney) == [.moneyMilestone], "MoneyMomentum next target crossed")
afterMoney.earnings = 40
check(triggers(beforeMoney, afterMoney) == [.moneyMilestone], "multiple money targets produce one reaction")
afterMoney.currency = "TRY"
check(triggers(beforeMoney, afterMoney).isEmpty, "currency change does not cross a milestone")
afterMoney.currency = "USD"
afterMoney.sessionStart = day.addingTimeInterval(1)
check(triggers(beforeMoney, afterMoney).isEmpty, "new session resets money target")
for milestone in [3, 7, 14, 30, 60] {
    var old = idle
    old.streak = milestone - 1
    var new = old
    new.streak = milestone
    check(triggers(old, new) == [.streak], "streak \(milestone) trigger")
    check(triggers(new, new).isEmpty, "streak \(milestone) does not repeat")
}
var oldStreak = idle
oldStreak.streak = 2
var newStreak = idle
newStreak.streak = 60
check(triggers(oldStreak, newStreak) == [.streak], "several streak thresholds collapse")

for reason in ["hidden", "inactive", "covered", "companion off", "reduce motion"] {
    var queue = CelebrationQueue(lastLevel: 1, seenBadgeIDs: [])
    queue.ingest(idle, now: 0, canReact: false)
    queue.ingest(working, now: 1, canReact: false)
    check(queue.pending.isEmpty, "\(reason) skips reaction without queueing")
    queue.ingest(working, now: 50, canReact: true)
    check(queue.pending.isEmpty, "\(reason) does not replay skipped reaction")
}
var disappeared = CelebrationQueue(lastLevel: 1, seenBadgeIDs: [])
disappeared.ingest(idle, now: 0, canReact: true)
disappeared.ingest(working, now: 1, canReact: true)
show(&disappeared, visible: false)
check(disappeared.current == nil && disappeared.pending.isEmpty, "visibility rechecked before delivery")
check(disappeared.reserveTap(now: 100), "tap reserves shared reaction gate")
check(!disappeared.reserveTap(now: 119.9), "tap cannot overlap automatic gate")
check(disappeared.reserveTap(now: 120), "tap allowed after cooldown")

for reduceMotion in [false, true] {
    for enabled in [false, true] {
        let policy = CelebrationPresentation(reduceMotion: reduceMotion, companionEnabled: enabled)
        check(policy.companion == enabled, "companion visibility \(reduceMotion) \(enabled)")
        check(policy.motion == (enabled && !reduceMotion), "motion variant \(reduceMotion) \(enabled)")
        check(policy.confetti == (enabled && !reduceMotion), "confetti variant \(reduceMotion) \(enabled)")
    }
}
for isActive in [false, true] {
    var hiddenBeforeDelivery = CelebrationQueue(lastLevel: 1, seenBadgeIDs: [])
    hiddenBeforeDelivery.ingest(idle, now: 0, canReact: true)
    hiddenBeforeDelivery.ingest(working, now: 1, canReact: true)
    show(&hiddenBeforeDelivery, blocked: isActive, active: isActive)
    check(hiddenBeforeDelivery.pending.isEmpty, "blocked or inactive delivery drops live reaction \(isActive)")
}

var interrupted = CelebrationQueue(lastLevel: 55, seenBadgeIDs: Set(archive.badges.map(\.id)))
interrupted.ingest(archive, now: 0, canReact: false)
show(&interrupted)
interrupted.ingest(newer, now: 1, canReact: false)
interrupted.suspend()
check(interrupted.pending == [.levelUp(level: 60, hours: 270)], "suspending old level preserves only newer pending level")
show(&interrupted)
interrupted.suspend()
check(interrupted.current == nil && interrupted.pending.count == 1, "interrupted overlay resumes after modal")
show(&interrupted, blocked: true)
check(interrupted.current == nil, "multiple modal blockers keep queue closed")
show(&interrupted)
check(interrupted.current == .levelUp(level: 60, hours: 270), "interrupted overlay resumes with same level")
var accumulating = CelebrationQueue(lastLevel: 56, seenBadgeIDs: ["1", "2"])
var few = archive
few.badges = Array(archive.badges.prefix(3))
accumulating.ingest(few, now: 0, canReact: false)
show(&accumulating)
accumulating.suspend()
show(&accumulating)
accumulating.ingest(archive, now: 1, canReact: false)
check(accumulating.pending.filter { if case .badge = $0 { return true }; return false }.count == 2,
      "resumed badge does not consume batch limit twice")
check(accumulating.pending.last == .moreBadges(["6", "7", "8"]), "batch cap spans updates during presentation")

check(CelebrationRules.levelKey == "Clockin.LastCelebratedLevel", "level persistence key")
check(CelebrationRules.badgesKey == "Clockin.SeenBadgeIDs", "badge persistence key")

check(CelebrationEvent.levelUp(level: 75, hours: 370).autoDismissDelay == nil, "level card waits for explicit dismissal")
check(CelebrationEvent.reaction(.clockIn).autoDismissDelay == 1.6, "brief companion reaction still expires")
check(CelebrationEvent.badge(badge("test")).autoDismissDelay == 4, "badge banner allows reading time")
print("\(checks) celebration checks passed")
