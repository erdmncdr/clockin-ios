import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

func near(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) < 0.000001 }

func end(of beat: LevelUpHapticBeat) -> Double {
    if case .continuous(let duration) = beat.kind { return beat.time + duration }
    return beat.time
}

let regular = LevelUpTiming.beats(milestone: false)
let milestone = LevelUpTiming.beats(milestone: true)
check(LevelUpTiming.impact == 0.62 && LevelUpTiming.rankReveal == 1.7, "shared cinematic timing")
for (name, beats) in [("regular", regular), ("milestone", milestone)] {
    check(beats.map(\.time) == beats.map(\.time).sorted(), "\(name) beats sorted by time")
    check(beats.allSatisfy {
        $0.time.isFinite && $0.time >= 0 && (0...1).contains($0.intensity) && (0...1).contains($0.sharpness)
    }, "\(name) times and strengths valid")
    check(beats.allSatisfy { beat in
        switch beat.kind {
        case .transient: return beat.envelope.isEmpty
        case .continuous(let duration):
            return duration.isFinite && duration > 0 && beat.envelope.count >= 2
                && beat.envelope.first?.time == 0 && beat.envelope.last?.time == 1
                && beat.envelope.map(\.time) == beat.envelope.map(\.time).sorted()
                && beat.envelope.allSatisfy { (0...1).contains($0.time) && (0...1).contains($0.value) }
        }
    }, "\(name) continuous envelopes valid")
    let impacts = beats.filter { $0.kind == .transient && near($0.time, LevelUpTiming.impact) }
    check(impacts.count == 1 && impacts[0].intensity == 1 && impacts[0].sharpness == 0.75,
          "\(name) has one full-strength impact")
    check(beats.allSatisfy { end(of: $0) < 2.2 }, "\(name) ends before 2.2 seconds")
}
let charges = regular.filter { $0.time < LevelUpTiming.impact }
check(charges.count == 1 && charges[0].time == 0 && end(of: charges[0]) <= LevelUpTiming.impact
      && charges[0].kind == .continuous(duration: LevelUpTiming.impact - 0.02),
      "one charge ends before impact")
let charge = charges[0]
check(near(charge.intensity * charge.envelope[0].value, 0.12)
      && near(charge.intensity * charge.envelope[charge.envelope.count - 1].value, 0.6)
      && charge.envelope.map(\.value) == charge.envelope.map(\.value).sorted() && charge.sharpness == 0.25,
      "charge rises from 0.12 to 0.6 with soft sharpness")
let tails = regular.filter { $0.kind == .continuous(duration: 0.4) && $0.time == LevelUpTiming.impact }
check(tails.count == 1 && tails[0].intensity == 0.5 && tails[0].sharpness == 0.2
      && tails[0].envelope.first?.value == 1 && tails[0].envelope.last?.value == 0
      && tails[0].envelope.map(\.value) == tails[0].envelope.map(\.value).sorted(by: >),
      "impact tail decays from 0.5 to silence over 0.4 seconds")
check(regular.count == 4 && regular.contains {
    $0.kind == .transient && near($0.time, LevelUpTiming.impact + 0.06)
        && $0.intensity == 0.55 && $0.sharpness == 0.35
}, "regular pattern contains only charge, double thump and tail")
check(regular.allSatisfy { $0.time < LevelUpTiming.rankReveal }, "regular has no rank reveal beats")
check(Array(milestone.prefix(regular.count)) == regular, "milestone preserves the regular pattern")
let reveal = Array(milestone.dropFirst(regular.count))
check(reveal.count == 4 && reveal.allSatisfy { $0.kind == .transient && $0.time >= LevelUpTiming.rankReveal },
      "milestone adds exactly four rank reveal transients")
check(reveal[0].time == LevelUpTiming.rankReveal && reveal[0].intensity == 0.9 && reveal[0].sharpness == 0.6
      && reveal.dropFirst().enumerated().allSatisfy { index, beat in
          near(beat.time, LevelUpTiming.rankReveal + Double(index + 1) * 0.12)
              && beat.intensity == 0.32 && beat.sharpness == 0.9
      }, "rank reveal has three light sparkles spaced 0.12 seconds apart")
print("\(checks) levelup checks passed")
