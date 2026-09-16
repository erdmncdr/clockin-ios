import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    precondition(condition, name)
    checks += 1
    print("ok: \(name)")
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64 = 42
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

func near(_ left: Double, _ right: Double) -> Bool { abs(left - right) < 1e-9 }
func atRest(_ pose: MascotPose) -> Bool {
    near(pose.offsetY, 0) && near(pose.rotationDegrees, 0)
        && near(pose.scaleX, 1) && near(pose.scaleY, 1)
        && near(pose.shadowScaleX, 1) && near(pose.shadowScaleY, 1) && near(pose.shadowOpacity, 1)
}

let frames = URL(fileURLWithPath: "Shared/Mascot/Frames", isDirectory: true)
let data = try Data(contentsOf: frames.appendingPathComponent("mascot-clips.json"))
let library = try MascotLibrary(data: data)
check(library.moods.count == 5, "JSON decodes all five moods including derived angry")
for mood in MascotMood.allCases {
    let clips = library[mood]
    check(!clips.rest.isEmpty && !clips.clips.isEmpty && clips.frames.contains(clips.rest), "\(mood) has rest and clips")
    check(clips.clips.values.allSatisfy { !$0.isEmpty && $0.last?.frame == clips.rest && $0.last?.milliseconds == 0 },
          "\(mood) clips return to rest")
    check(clips.frames.allSatisfy { id in
        let bundled = mood == .angry ? "h" + id.dropFirst() : id
        return FileManager.default.fileExists(atPath: frames.appendingPathComponent(bundled + ".png").path)
    }, "\(mood) frames exist or have hello fallbacks")

    var random = SeededRandom()
    var director = MascotDirector(clips)
    var previous: String?
    var valid = true
    for _ in 0..<1000 {
        guard let event = director.next(using: &random) else { valid = false; break }
        let name: String
        switch event {
        case .clip(let clip): name = clip; valid = valid && clips.clips[clip] != nil
        case .hop: name = "hop"; valid = valid && clips.standing
        }
        valid = valid && name != previous
        previous = name
    }
    check(valid, "\(mood) director never repeats and only standing moods hop")
}

let hello = library[.hello]
let angry = library[.angry]
check(angry.rest == "a01" && angry.frames == Set(hello.frames.map { "a" + $0.dropFirst() }), "angry rewrites every hello frame prefix")
check(angry.weights == hello.weights && angry.standing == hello.standing, "angry keeps hello event structure")
check(hello.clips.allSatisfy { name, steps in
    angry.clips[name] == steps.map { MascotStep("a" + $0.frame.dropFirst(), $0.milliseconds) }
}, "angry preserves clip ordering and durations")

let sparse = MascotMoodClips(rest: "h01", standing: false,
    clips: ["blink": [MascotStep("h01", 0)]],
    weights: ["missing": 1000, "hop": 1000, "blink": 1, "zero": 0, "negative": -1])
var sparseDirector = MascotDirector(sparse)
var random = SeededRandom()
check(sparseDirector.next(using: &random) == .clip("blink"), "missing clips and non-standing hops are ignored")
check(sparseDirector.next(using: &random) == nil, "no eligible event returns nil instead of repeating")
let empty = MascotMoodClips(rest: "h01", standing: true, clips: [:], weights: ["missing": 10])
var emptyDirector = MascotDirector(empty)
check(emptyDirector.next(using: &random) == nil, "only missing weights produces no event")
var first = MascotDirector(hello), second = MascotDirector(hello)
var seed1 = SeededRandom(), seed2 = SeededRandom()
check((0..<500).allSatisfy { _ in first.next(using: &seed1) == second.next(using: &seed2) }, "seeded event sequence is deterministic")

var last: MascotReaction?
var seen: Set<MascotReaction> = []
var neverRepeats = true
for _ in 0..<1000 {
    let reaction = MascotReaction.pick(after: last, using: &random)
    neverRepeats = neverRepeats && reaction != last
    seen.insert(reaction)
    last = reaction
}
check(neverRepeats && seen.count == MascotReaction.allCases.count, "reaction picks cover all six without adjacent repeats")
check(MascotReaction.cheer.mood(from: .hello) == .celebrate, "cheer uses celebrate pose")

for height in [0.3, 0.75, 1, 1.3] {
    check(atRest(MascotMotion.hop(progress: 0, height: height)) && atRest(MascotMotion.hop(progress: 1, height: height)),
          "hop \(height) begins and ends at rest")
    check(MascotMotion.samples(count: 121) { MascotMotion.hop(progress: $0, height: height) }.contains { $0.offsetY < 0 },
          "hop \(height) lifts above the ground")
}
// Sitedeki egri: poz degisiminde kuculup asip dinlenmeye oturur.
check(near(MascotMotion.pop(progress: 0), 0.9) && near(MascotMotion.pop(progress: 1), 1), "pop starts small and ends at rest")
check(MascotMotion.pop(progress: 0.3) < 1 && near(MascotMotion.pop(progress: 0.6), 1.035), "pop keeps anticipation and overshoot")
check(near(MascotMotion.wiggle(progress: 0), 0) && near(MascotMotion.wiggle(progress: 1), 0), "wiggle begins and ends at rest")
let squashStart = MascotMotion.squash(progress: 0), squashEnd = MascotMotion.squash(progress: 1)
check(near(squashStart.scaleX, 1) && near(squashStart.scaleY, 1)
      && abs(squashEnd.scaleX - 1) < 0.005 && abs(squashEnd.scaleY - 1) < 0.005,
      "squash begins at rest and settles back")
check(MascotMotion.samples(count: 3) { $0 } == [0, 0.5, 1], "keyframe sampling includes both endpoints")

let date = Date(timeIntervalSinceReferenceDate: 1000)
let running = RunningSession(start: date, accumulated: 0, resumedAt: date, note: "")
let paused = RunningSession(start: date, accumulated: 120, resumedAt: nil, note: "")
check(MascotAsset.session(running: nil).mood == .hello, "idle maps to hello")
check(MascotAsset.session(running: running).mood == .working, "running maps to working")
check(MascotAsset.session(running: paused).mood == .coffee, "paused maps to coffee")
check(MascotAsset.session(running: nil, angry: true).mood == .angry, "idle Grumpy maps to angry")
check(MascotAsset.session(running: paused, angry: true).mood == .angry, "paused Grumpy maps to angry")
check(MascotAsset.session(running: running, angry: true).mood == .working, "working takes precedence over stale anger")
check(MascotAsset.celebrate.mood == .celebrate, "clock-out maps to celebrate")

var snapshot = ClockinSnapshot.empty
snapshot.isAngry = true
let encoded = try JSONEncoder().encode(snapshot)
check(try JSONDecoder().decode(ClockinSnapshot.self, from: encoded).isAngry, "angry flag round-trips")
var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
legacy.removeValue(forKey: "isAngry")
let legacyData = try JSONSerialization.data(withJSONObject: legacy)
check(try !JSONDecoder().decode(ClockinSnapshot.self, from: legacyData).isAngry, "old snapshot without angry flag still decodes")
print("\(checks) mascot checks passed")
