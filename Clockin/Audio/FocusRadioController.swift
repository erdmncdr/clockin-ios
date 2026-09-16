import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class FocusRadioController: ObservableObject {
    static let shared = FocusRadioController()
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var volume: Double = 0.7 {
        didSet { player?.volume = Float(min(1, max(0, volume))) }
    }
    var isStarted: Bool { player != nil }
    private var isInterrupted = false
    private var player: AVPlayer?
    private var monitor: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var commandTargets: [(MPRemoteCommand, Any)] = []

    private init() {
        let commands = MPRemoteCommandCenter.shared()
        commandTargets = [
            (commands.playCommand, commands.playCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.play() }
                return .success
            }),
            (commands.pauseCommand, commands.pauseCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.stop() }
                return .success
            }),
            (commands.togglePlayPauseCommand, commands.togglePlayPauseCommand.addTarget { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if self.isStarted { self.stop() } else { self.play() }
                }
                return .success
            })
        ]
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
            object: nil, queue: nil) { [weak self] notification in
            let kind = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                if kind == AVAudioSession.InterruptionType.began.rawValue {
                    self.isInterrupted = true
                    if self.isStarted {
                        self.stop()
                        self.errorMessage = "Audio was interrupted. Press Play after the interruption ends."
                    }
                } else if kind == AVAudioSession.InterruptionType.ended.rawValue {
                    // shouldResume olsa bile kullanici Play'e basmali.
                    self.isInterrupted = false
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: nil) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                // Kulaklik cikinca hoparlorden beklenmedik yayin baslamasin.
                if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { self?.stop() }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        })
    }

    func play() {
        guard player == nil else { return }
        guard !isInterrupted else {
            errorMessage = "Audio is interrupted. Try Play after the interruption ends."
            return
        }
        errorMessage = nil
        FocusChimeController.shared.stopPlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Could not start audio: \(error.localizedDescription)"
            return
        }
        let item = AVPlayerItem(url: URL(string: "https://stream.radioparadise.com/aac-320")!)
        let player = AVPlayer(playerItem: item)
        player.volume = Float(volume)
        self.player = player
        isLoading = true
        updateNowPlaying()
        player.play()
        // Durum okumasi ana aktorde kalir; KVO nesneleri aktorler arasinda tasinmaz.
        monitor = Task { [weak self] in
            var waitingSince = ContinuousClock.now
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                if player.currentItem?.status == .failed || player.error != nil {
                    self.fail("Radio Paradise is unreachable. Check your connection and try again.")
                    return
                }
                let playing = player.timeControlStatus == .playing
                if self.isPlaying != playing {
                    self.isPlaying = playing
                    self.updateNowPlaying()
                }
                if self.isLoading == playing { self.isLoading = !playing }
                if playing { waitingSince = .now }
                else if waitingSince.duration(to: .now) >= .seconds(30) {
                    self.fail("Radio Paradise did not respond. Check your connection and try again.")
                    return
                }
                do { try await Task.sleep(for: .milliseconds(500)) }
                catch { return }
            }
        }
    }

    func stop() {
        FocusChimeController.shared.stopPlayback()
        monitor?.cancel()
        monitor = nil
        player?.pause()
        player = nil
        isPlaying = false
        isLoading = false
        // Istasyon bilgisi kalir; kilit ekranindaki Play bilincli olarak yeniden baslatir.
        updateNowPlaying()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func fail(_ message: String) {
        stop()
        errorMessage = message
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Radio Paradise",
            MPMediaItemPropertyArtist: "Focus radio",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
