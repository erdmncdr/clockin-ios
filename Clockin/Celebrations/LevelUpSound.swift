import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The level-up heard: the charge building in the dark, the strike and a
/// chord that fades with the light, on the same clock as the card and the
/// haptics. Built by `Tools/make-levelup-sounds.swift`. It plays only while
/// Clockin is open, mixes with other audio and, unless Focus radio is
/// playing, follows the silent switch, like a chime in the app.
@MainActor
enum LevelUpSound {
    static let enabledKey = "Clockin.LevelUpSoundEnabled"
    private static var player: AVAudioPlayer?
    private static var fading: Task<Void, Never>?

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// `still` is a card that opens on its final frame; it hears only the
    /// strike and the chord.
    static func play(milestone: Bool, still: Bool) {
        guard enabled, UIApplication.shared.applicationState == .active else { return }
        halt()
        let name = still ? "clockin-levelup-still" : milestone ? "clockin-levelup-rank" : "clockin-levelup"
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        do {
            // Focus radio owns the shared session while it plays; leave its category alone.
            if !FocusRadioController.shared.ownsAudioSession {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default)
                try session.setActive(true)
            }
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.8
            guard player.prepareToPlay(), player.play() else { return }
            self.player = player
        } catch {
            halt()
        }
    }

    /// Fades out quickly when the card goes before the sound has finished,
    /// so the strike does not land on whatever comes next.
    static func stop() {
        guard let player, player.isPlaying else { return halt() }
        player.setVolume(0, fadeDuration: 0.15)
        fading = Task {
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            halt()
        }
    }

    private static func halt() {
        fading?.cancel()
        fading = nil
        player?.stop()
        player = nil
    }
}
