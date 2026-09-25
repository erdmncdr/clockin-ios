import Foundation

/// Keeps the animation's impact and the haptic impact on the same timeline.
enum LevelUpTiming {
    /// Seconds from presentation to the impact.
    static let impact: Double = 0.62
    /// Seconds from presentation to the milestone rank reveal.
    static let rankReveal: Double = 1.7
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
    static func beats(milestone: Bool) -> [LevelUpHapticBeat] {
        var beats: [LevelUpHapticBeat] = [
            .init(time: 0, kind: .continuous(duration: impact - 0.02), intensity: 0.6, sharpness: 0.25,
                  envelope: [.init(time: 0, value: 0.2), .init(time: 1, value: 1)]),
            .init(time: impact, kind: .transient, intensity: 1, sharpness: 0.75),
            .init(time: impact, kind: .continuous(duration: 0.4), intensity: 0.5, sharpness: 0.2,
                  envelope: [.init(time: 0, value: 1), .init(time: 1, value: 0)]),
            .init(time: impact + 0.06, kind: .transient, intensity: 0.55, sharpness: 0.35)
        ]
        if milestone {
            beats.append(.init(time: rankReveal, kind: .transient, intensity: 0.9, sharpness: 0.6))
            for index in 1...3 {
                beats.append(.init(time: rankReveal + Double(index) * 0.12,
                                   kind: .transient, intensity: 0.32, sharpness: 0.9))
            }
        }
        return beats
    }
}
