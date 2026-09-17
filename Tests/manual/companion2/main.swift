import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    precondition(condition, name)
    checks += 1
    print("ok: \(name)")
}
struct Seed: RandomNumberGenerator {
    var state: UInt64 = 77
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
let data = try Data(contentsOf: URL(fileURLWithPath: "Shared/Mascot/Frames/mascot-clips.json"))
let library = try MascotLibrary(data: data)
let hello = library[.hello]
for (mood, prefix) in [(MascotMood.tired, "z"), (.proud, "p")] {
    let clips = library[mood]
    check(clips.rest == prefix + "01", "\(mood) rest")
    check(mood.feet == MascotMood.hello.feet, "\(mood) feet")
    check(clips.frames == Set(hello.frames.map { prefix + $0.dropFirst() }), "\(mood) frame IDs")
    check(hello.clips.allSatisfy { name, steps in
        clips.clips[name] == steps.map { MascotStep(prefix + $0.frame.dropFirst(), $0.milliseconds) }
    }, "\(mood) timing and order")
    for frame in clips.frames {
        check(MascotFrameFallback.resolve(frame) { $0 == frame } == frame, "\(frame) preferred")
        check(MascotFrameFallback.resolve(frame) { $0.hasPrefix("h") } == "h" + frame.dropFirst(), "\(frame) matching hello fallback")
        check(MascotFrameFallback.resolve(frame) { $0 == "h01" } == "h01", "\(frame) rest fallback")
        check(MascotFrameFallback.resolve(frame) { _ in false } == nil, "\(frame) absent resources")
    }
}
check(MascotFrameFallback.candidates(for: "acc-mug") == ["acc-mug", "h01"], "accessory is not angry frame")
check(library[.proud].weights == hello.weights, "proud weights")
var random = Seed()
var director = MascotDirector(library[.tired], tired: true)
var hops = 0
var delays: [Double] = []
for _ in 0..<1000 {
    if case .hop = director.next(using: &random) { hops += 1 }
    delays.append(director.restDelay(using: &random))
}
check(hops == 0, "tired has no automatic hops")
check(delays.allSatisfy { (3.5...6.5).contains($0) }, "tired pauses 3.5 to 6.5 seconds")

let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
let working = RunningSession(start: now, accumulated: 0, resumedAt: now, note: "")
let paused = RunningSession(start: now, accumulated: 60, resumedAt: nil, note: "")
for friendly in [false, true] {
    for angry in [false, true] {
        for broken in [false, true] {
            for quiet in [0, 1, 2, 3, 7] {
                for expiry in [nil, now.addingTimeInterval(-1), now, now.addingTimeInterval(4)] as [Date?] {
                    for running in [nil, working, paused] as [RunningSession?] {
                        let expected: MascotAsset
                        if expiry.map({ $0 > now }) == true { expected = .proud }
                        else if running?.isPaused == false { expected = .working }
                        else if angry && !friendly { expected = .angry }
                        else if running == nil && (broken || quiet >= 2) { expected = .tired }
                        else { expected = running == nil ? .idle : .paused }
                        check(MascotAsset.session(running: running, angry: angry, friendly: friendly,
                            streakBrokenYesterday: broken, quietDays: quiet, proudUntil: expiry, now: now) == expected,
                              "decision friendly=\(friendly) angry=\(angry) broken=\(broken) quiet=\(quiet) expiry=\(String(describing: expiry)) session=\(running?.isPaused.description ?? "none")")
                    }
                }
            }
        }
    }
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
let today = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))!
let beforeDST = calendar.date(byAdding: .day, value: -2, to: today)!
check(MascotAsset.quietDays(since: beforeDST, now: today, calendar: calendar) == 2, "calendar quiet days across DST")
check(MascotAsset.quietDays(since: nil, now: today) == 0, "fresh user not tired")
check(MascotAsset.quietDays(since: today.addingTimeInterval(86400), now: today) == 0, "future work not quiet")

let catalog = CompanionAccessory.allCases
check(catalog.map(\.id) == ["headphones", "mug", "cape", "antenna"], "stable catalog IDs")
check(catalog.map(\.requiredHours) == [25, 50, 100, 250], "unlock hours")
check(catalog.map(\.name) == ["Headphones", "Mug", "Cape", "Gold antenna"], "catalog names")
for accessory in catalog {
    let threshold = accessory.requiredHours
    check(!accessory.symbol.isEmpty, "\(accessory) symbol")
    check(FileManager.default.fileExists(atPath: "Shared/Mascot/Frames/\(accessory.frame).png"), "\(accessory) art")
    check(!accessory.isUnlocked(totalHours: threshold - 0.001), "\(accessory) below threshold")
    check(accessory.isUnlocked(totalHours: threshold), "\(accessory) inclusive threshold")
    check(CompanionAccessory.resolve("Auto", totalHours: threshold) == accessory, "\(accessory) Auto highest")
    check(CompanionAccessory.resolve(accessory.id, totalHours: 1000) == accessory, "\(accessory) explicit choice")
    check(CompanionAccessory.selection(accessory.id, totalHours: 0) == "Auto", "\(accessory) locked fallback")
    check(accessory.menuLabel(totalHours: 0).contains("\(Int(threshold))h"), "\(accessory) locked label")
    check(accessory.menuLabel(totalHours: threshold) == accessory.name, "\(accessory) unlocked label")
    check(accessory.progressText(totalHours: threshold - 12.5) == "12h 30m to go", "\(accessory) progress text")
    check(accessory.progressText(totalHours: threshold - 0.001) == "0h 1m to go", "\(accessory) ceil remaining minute")
    check(accessory.progressText(totalHours: threshold) == "Unlocked", "\(accessory) unlocked progress")
    check(CompanionAccessory.displayFrame("h01", helloRest: true, performingEvent: false, accessory: accessory) == accessory.frame, "\(accessory) worn at rest")
    check(CompanionAccessory.displayFrame("h01", helloRest: true, performingEvent: true, accessory: accessory) == "h01", "\(accessory) plain hops and clips")
    check(CompanionAccessory.displayFrame("p01", helloRest: false, performingEvent: false, accessory: accessory) == "p01", "\(accessory) plain other moods")
}
check(CompanionAccessory.resolve("Auto", totalHours: 24.99) == nil, "Auto no unlock")
check(CompanionAccessory.resolve("None", totalHours: 1000) == nil, "None stays none")
check(CompanionAccessory.resolve("unknown", totalHours: 50) == .mug, "unknown uses Auto")
check(CompanionAccessory.resolve("antenna", totalHours: 50) == .mug, "locked stored choice uses Auto")
check(CompanionAccessory.resolve("Auto", totalHours: 24 + working.elapsed(at: now.addingTimeInterval(3600)) / 3600) == .headphones, "running hours unlock")

var state = CelebrationState()
state.totalHours = 100
var queue = CelebrationQueue(lastLevel: 1, seenBadgeIDs: [])
queue.ingest(state, now: 0, canReact: false)
check(queue.seenAccessoryIDs == Set(["headphones", "mug", "cape"]), "version seed independent of badge seed")
check(queue.pending.isEmpty, "first run silent")
state.totalHours = 250
queue.ingest(state, now: 1, canReact: false)
queue.ingest(state, now: 2, canReact: false)
check(queue.pending == [.accessory(.antenna)], "unlock queued once")
queue.presentNext(active: false, blocked: false, companionVisible: false, now: 3)
check(queue.current == nil && queue.pending.count == 1, "wait in background")
queue.presentNext(active: true, blocked: true, companionVisible: true, now: 3)
check(queue.current == nil, "wait behind sheet")
queue.presentNext(active: true, blocked: false, companionVisible: false, now: 4)
check(queue.current == .accessory(.antenna), "banner with companion off")
check(queue.seenAccessoryIDs?.contains("antenna") == true, "presentation marks seen")
queue.suspend()
queue.presentNext(active: true, blocked: false, companionVisible: true, now: 5)
check(queue.current == .accessory(.antenna), "interrupted banner resumes")
queue.finish()
var relaunched = CelebrationQueue(lastLevel: queue.lastLevel, seenBadgeIDs: queue.seenBadgeIDs, seenAccessoryIDs: queue.seenAccessoryIDs)
relaunched.ingest(state, now: 6, canReact: false)
check(relaunched.pending.isEmpty, "relaunch does not repeat")
state.totalHours = 0
relaunched.ingest(state, now: 7, canReact: false)
state.totalHours = 250
relaunched.ingest(state, now: 8, canReact: false)
check(relaunched.pending.isEmpty, "restore and re-unlock do not repeat")
var fresh = CelebrationQueue()
state.totalHours = 0
fresh.ingest(state, now: 0, canReact: false)
check(fresh.seenAccessoryIDs == [], "empty seed is non-nil")
state.totalHours = 100
fresh.ingest(state, now: 1, canReact: false)
check(fresh.pending == [.accessory(.headphones), .accessory(.mug), .accessory(.cape)], "multiple unlocks catalog order")

var old = CelebrationState()
old.sessionStart = now
var ended = CelebrationState()
ended.savedPreviousSession = true
for duration in [7199.0, 7200, 7201] {
    ended.savedPreviousDuration = duration
    check(CelebrationRules.earnsPride(from: old, to: ended) == (duration > 7200), "long clock-out threshold \(duration)")
}
ended.savedPreviousSession = false
check(!CelebrationRules.earnsPride(from: old, to: ended), "cancel earns no pride")
check(!CelebrationRules.earnsPride(from: nil, to: ended), "launch no pride")
old.day = now; old.dailyGoal = 1; old.dailyHours = 0.99
var reached = old; reached.dailyHours = 1
check(CelebrationRules.earnsPride(from: old, to: reached), "daily goal crossing")
check(!CelebrationRules.earnsPride(from: reached, to: reached), "goal no repeat")
reached.dailyGoal = 0.5
check(!CelebrationRules.earnsPride(from: old, to: reached), "edited goal no pride")
check(CelebrationEvent.levelUp(level: 2, hours: 5).startsPride, "level presentation earns pride")
check(CelebrationEvent.badge(CelebrationBadge(id: "sample", title: "Sample", icon: "star")).startsPride, "badge presentation earns pride")
check(CelebrationEvent.moreBadges(["sample"]).startsPride, "grouped badges earn pride")
check(!CelebrationEvent.accessory(.mug).startsPride, "accessory banner retains its own art")
check(!CelebrationEvent.reaction(.clockIn).startsPride, "ordinary session reaction is not pride")
check(CelebrationRules.proudDuration == 4, "four second pride")

check(MascotAnimationRate.sway.minimum == 8, "sway minimum 8 fps")
check(MascotAnimationRate.sway.maximum == 15, "sway maximum 15 fps")
check(MascotAnimationRate.sway.preferred == 12, "sway preferred 12 fps")
check(MascotAnimationRate.reaction.minimum == 24, "reaction minimum 24 fps")
check(MascotAnimationRate.reaction.maximum == 30, "reaction maximum 30 fps")
check(MascotAnimationRate.reaction.preferred == 30, "reaction preferred 30 fps")
for rate in MascotAnimationRate.allCases {
    check(rate.minimum > 0 && rate.minimum <= rate.preferred && rate.preferred <= rate.maximum,
          "\(rate) valid frame rate range")
}

for mood in [MascotMood.hello, .proud, .celebrate, .tired, .angry] {
    let schedule = MascotSwaySchedule.schedule(for: mood)
    check(schedule.active > 0 && schedule.rest > 0, "\(mood) finite burst")
    check(schedule.isMoving(at: 0), "\(mood) burst start")
    check(schedule.isMoving(at: schedule.active - 0.001), "\(mood) active until boundary")
    check(!schedule.isMoving(at: schedule.active), "\(mood) rest starts")
    check(!schedule.isMoving(at: schedule.cycle - 0.001), "\(mood) rest until next burst")
    check(schedule.isMoving(at: schedule.cycle), "\(mood) next burst")
    check(!schedule.isMoving(at: -1), "\(mood) before start")
}
check(MascotSwaySchedule.schedule(for: .hello).cycle == 13, "normal schedule 5.2 plus 7.8")
let tired = MascotSwaySchedule.schedule(for: .tired)
check(tired.active == 7.8 && tired.rest == 12 && tired.amplitude == 0.45, "slower smaller tired sway")
var snapshot = ClockinSnapshot.empty
snapshot.companionLastWorkedDay = now.addingTimeInterval(-3 * 86400)
snapshot.companionFriendly = true
snapshot.isAngry = true
snapshot.companionAccessoryID = "mug"
snapshot.companionProudUntil = now.addingTimeInterval(4)
let restored = try JSONDecoder().decode(ClockinSnapshot.self, from: JSONEncoder().encode(snapshot))
check(restored == snapshot, "widget fields round-trip")
check(restored.companionState(at: now) == .proud, "widget pride window")
check(restored.companionState(at: now.addingTimeInterval(4)) == .tired, "widget pride expires")
var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
for key in ["companionLastWorkedDay", "companionFriendly", "companionAccessoryID", "companionProudUntil"] { legacy.removeValue(forKey: key) }
let legacySnapshot = try JSONDecoder().decode(ClockinSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
check(!legacySnapshot.companionFriendly && legacySnapshot.companionProudUntil == nil && legacySnapshot.companionAccessoryID == nil, "legacy fields default")
print("\(checks) companion phase 2 checks passed")
