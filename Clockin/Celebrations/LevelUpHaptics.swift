import CoreHaptics
import UIKit

/// The level-up felt in the hand: a hum that builds during the charge, a heavy
/// double thump on the impact and, on a new rank, a second beat with sparkles.
/// Falls back to the plain success tap wherever the pattern cannot play.
@MainActor
enum LevelUpHaptics {
    private static var engine: CHHapticEngine?
    private static var started = false
    private static var players: [any CHHapticPatternPlayer] = []

    static func play(milestone: Bool) {
        guard Haptics.enabled, UIApplication.shared.applicationState == .active else { return }
        stopPlayers()
        do {
            guard !UIAccessibility.isReduceMotionEnabled,
                  CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
                Haptics.play(.levelUp)
                return
            }
            let engine = try prepareEngine()
            let beats = LevelUpTiming.beats(milestone: milestone)
            var transients: [CHHapticEvent] = []
            var continuous: [CHHapticEvent] = []
            var curves: [CHHapticParameterCurve] = []
            for beat in beats {
                let parameters = [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(beat.intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(beat.sharpness))
                ]
                switch beat.kind {
                case .transient:
                    transients.append(CHHapticEvent(eventType: .hapticTransient, parameters: parameters,
                                                    relativeTime: beat.time))
                case .continuous(let duration):
                    continuous.append(CHHapticEvent(eventType: .hapticContinuous, parameters: parameters,
                                                    relativeTime: beat.time, duration: duration))
                    curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                        controlPoints: beat.envelope.map {
                            .init(relativeTime: $0.time * duration, value: Float($0.value))
                        }, relativeTime: beat.time))
                }
            }
            // Curves affect every event in a player, so keep the transients independent.
            let continuousPattern = try CHHapticPattern(events: continuous, parameterCurves: curves)
            let transientPattern = try CHHapticPattern(events: transients, parameters: [])
            players.append(try engine.makePlayer(with: continuousPattern))
            players.append(try engine.makePlayer(with: transientPattern))
            let startTime = engine.currentTime + 0.01
            for player in players { try player.start(atTime: startTime) }
        } catch {
            engine?.stop(completionHandler: nil)
            players.removeAll()
            started = false
            Haptics.play(.levelUp)
        }
    }

    private static func stopPlayers() {
        for player in players { try? player.stop(atTime: CHHapticTimeImmediate) }
        players.removeAll()
    }

    private static func prepareEngine() throws -> CHHapticEngine {
        let current: CHHapticEngine
        if let engine {
            current = engine
        } else {
            current = try CHHapticEngine()
            current.playsHapticsOnly = true
            current.isAutoShutdownEnabled = true
            current.stoppedHandler = { @Sendable _ in
                Task { @MainActor in
                    started = false
                    players.removeAll()
                }
            }
            // After a reset the next level-up starts the engine again.
            current.resetHandler = { @Sendable in
                Task { @MainActor in
                    started = false
                    players.removeAll()
                }
            }
            engine = current
        }
        if !started {
            try current.start()
            started = true
        }
        return current
    }
}
