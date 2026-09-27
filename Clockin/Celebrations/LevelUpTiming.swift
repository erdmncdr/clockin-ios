import Foundation

/// Keeps the animation's impact and the haptic impact on the same timeline.
/// Times are on the card's own clock, which stops for `hitstop` just after
/// the impact; `wall(_:)` gives the real seconds for the haptics.
enum LevelUpTiming {
    /// Seconds from presentation to the impact.
    static let impact: Double = 2.2
    /// Seconds before the impact when everything draws in and goes quiet.
    static let hush: Double = 0.3
    /// A pulse that quickens through the charge, ending as the hush begins.
    static let pulses: [Double] = [0.35, 0.72, 1.02, 1.28, 1.5, 1.66, 1.78, 1.86]
    /// Seconds from presentation to the milestone rank reveal.
    static let rankReveal: Double = 3.9
    /// How long the strike holds, the way a fighting game freezes on a hit.
    static let hitstop: Double = 0.1
    /// The card's time at which the strike holds: the new number is already
    /// white hot and the bloom has begun.
    static let hold: Double = impact + 0.04

    /// The card's time `elapsed` real seconds after it appeared.
    static func scene(_ elapsed: Double) -> Double {
        elapsed <= hold ? elapsed : max(hold, elapsed - hitstop)
    }

    /// The real seconds at which the card reaches `scene`.
    static func wall(_ scene: Double) -> Double {
        scene <= hold ? scene : scene + hitstop
    }

    /// When the charge's arcs of energy strike: one on every pulse and ever
    /// more as it builds. The sound's crackles land on the same moments.
    static let strikes: [Double] = pulses + (0..<34).map { 0.4 + (impact - hush - 0.45) * sqrt(scatter($0, 41)) }

    /// The same scatter on every run, so a replay looks and sounds identical.
    static func scatter(_ i: Int, _ salt: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: (i &* 73_856_093) ^ (salt &* 19_349_663) ^ 0x5bd1_e995)
        h ^= h >> 33; h &*= 0xff51_afd7_ed55_8ccd
        h ^= h >> 33; h &*= 0xc4ce_b9fe_1a85_ec53
        h ^= h >> 33
        return Double(h % 10_000) / 10_000
    }
}

struct LevelUpHapticBeat: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case transient
        case continuous(duration: Double)
    }

    struct EnvelopePoint: Equatable, Sendable {
        let time: Double
        let value: Double
    }

    let time: Double
    let kind: Kind
    let intensity: Double
    let sharpness: Double
    /// Normalized time and intensity multipliers for a continuous beat.
    var envelope: [EnvelopePoint] = []
}

extension LevelUpTiming {
    /// A hum that builds under the quickening pulse, silence for the hush, then
    /// the impact lands on that silence.
    static func beats(milestone: Bool) -> [LevelUpHapticBeat] {
        var beats: [LevelUpHapticBeat] = [
            .init(time: 0, kind: .continuous(duration: impact - hush), intensity: 0.6, sharpness: 0.25,
                  envelope: [.init(time: 0, value: 0.2), .init(time: 0.7, value: 0.5), .init(time: 1, value: 1)])
        ]
        for (index, time) in pulses.enumerated() {
            beats.append(.init(time: time, kind: .transient, intensity: 0.26 + 0.05 * Double(index), sharpness: 0.3))
        }
        beats += [
            .init(time: impact, kind: .transient, intensity: 1, sharpness: 0.8),
            .init(time: impact, kind: .continuous(duration: 0.9), intensity: 0.75, sharpness: 0.15,
                  envelope: [.init(time: 0, value: 1), .init(time: 1, value: 0)]),
            .init(time: impact + 0.06, kind: .transient, intensity: 0.6, sharpness: 0.35)
        ]
        if milestone {
            let reveal = wall(rankReveal)
            beats.append(.init(time: reveal, kind: .transient, intensity: 0.9, sharpness: 0.6))
            for index in 1...3 {
                beats.append(.init(time: reveal + Double(index) * 0.12,
                                   kind: .transient, intensity: 0.32, sharpness: 0.9))
            }
        }
        return beats
    }
}
