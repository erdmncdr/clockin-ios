import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class FocusRadioController: ObservableObject {
    static let shared = FocusRadioController()
    @Published private(set) var state: RadioPlaybackState = .stopped
    @Published private(set) var station: RadioStation
    @Published private(set) var errorMessage: String?
    @Published var volume: Double = 0.7 {
        didSet { player?.volume = Float(min(1, max(0, volume))) }
    }
    var isPlaying: Bool { state == .playing }
    var isLoading: Bool { state == .connecting }
    var isStarted: Bool { state.keepsNowPlaying }
    private(set) var ownsAudioSession = false
    private var isInterrupted = false
    private var player: AVPlayer?
    private var itemObservation: NSKeyValueObservation?
    private var monitor: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var commandSession: UUID?

    private init() {
        station = RadioStation.selected(UserDefaults.standard.string(forKey: RadioStation.storageKey))
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
            object: nil, queue: nil) { [weak self] notification in
            let kind = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                if kind == AVAudioSession.InterruptionType.began.rawValue {
                    self.isInterrupted = true
                    if self.isStarted {
                        self.endPlayback(.interruption)
                        self.errorMessage = String(localized: "Audio was interrupted. Press Play after the interruption ends.")
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
            Task { @MainActor in
                self?.stop()
                self?.isInterrupted = false
            }
        })
    }

    func selectStation(id: String) {
        let selected = RadioStation.selected(id)
        guard selected != station else { return }
        station = selected
        UserDefaults.standard.set(selected.id, forKey: RadioStation.storageKey)
        errorMessage = nil
        guard let player else { return }
        let resume = state.requestsPlayback
        monitor?.cancel()
        monitor = nil
        player.pause()
        let item = AVPlayerItem(url: selected.url)
        player.replaceCurrentItem(with: item)
        observeFailure(of: item)
        state = resume ? .connecting : .paused
        updateNowPlaying()
        if resume {
            player.play()
            startMonitoring()
        }
    }

    func play() {
        guard !state.requestsPlayback else { return }
        guard !isInterrupted else {
            fail(String(localized: "Audio is interrupted. Try Play after the interruption ends."))
            return
        }
        errorMessage = nil
        if player == nil {
            FocusChimeController.shared.stopPlayback()
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                // Aktivasyon yarida kalsa da hata yolu oturumu temizler.
                ownsAudioSession = true
                try session.setActive(true)
            } catch {
                fail(String(localized: "Could not start audio: \(error.localizedDescription)"))
                return
            }
            let item = AVPlayerItem(url: station.url)
            player = AVPlayer(playerItem: item)
            observeFailure(of: item)
            player?.volume = Float(min(1, max(0, volume)))
            installRemoteCommands()
        }
        state = .connecting
        updateNowPlaying()
        player?.play()
        startMonitoring()
    }

    func pause() {
        guard state.requestsPlayback else { return }
        endPlayback(.pause)
    }

    func stop() {
        endPlayback(.stop)
        errorMessage = nil
    }

    private func startMonitoring() {
        monitor?.cancel()
        // Var olan akis kontrolu; duraklatilinca Today icin calismaz.
        monitor = Task { [weak self] in
            var waitingSince = ContinuousClock.now
            while !Task.isCancelled {
                guard let self, self.state.requestsPlayback, let player = self.player else { return }
                if player.currentItem?.status == .failed || player.error != nil {
                    self.fail(String(localized: "\(self.station.name) is unreachable. Check your connection and try again."))
                    return
                }
                let playing = player.timeControlStatus == .playing
                let state: RadioPlaybackState = playing ? .playing : .connecting
                if self.state != state {
                    self.state = state
                    self.updateNowPlaying()
                }
                if playing { waitingSince = .now }
                else if waitingSince.duration(to: .now) >= .seconds(30) {
                    self.fail(String(localized: "\(self.station.name) did not respond. Check your connection and try again."))
                    return
                }
                do { try await Task.sleep(for: .milliseconds(500)) }
                catch { return }
            }
        }
    }

    private func observeFailure(of item: AVPlayerItem) {
        itemObservation?.invalidate()
        let id = ObjectIdentifier(item)
        // Duraklatilmis akisin hatasi da temizlenir; yeni yoklama dongusu yok.
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                guard let self, let current = self.player?.currentItem,
                      ObjectIdentifier(current) == id else { return }
                self.fail(String(localized: "\(self.station.name) is unreachable. Check your connection and try again."))
            }
        }
    }

    private func endPlayback(_ reason: RadioPlaybackEnd) {
        monitor?.cancel()
        monitor = nil
        player?.pause()
        // Kisa can bitene kadar oturumu devralir; radyo yeniden etkinlesmez.
        let chimeNeedsSession = reason != .pause && ownsAudioSession
            && FocusChimeController.shared.retainSessionForChime()
        let cleanup = RadioCleanupDecision(reason, radioOwnsAudioSession: ownsAudioSession,
                                           chimeNeedsAudioSession: chimeNeedsSession)
        state = cleanup.state
        if cleanup.releasePlayer {
            itemObservation?.invalidate()
            itemObservation = nil
            player?.replaceCurrentItem(with: nil)
            player = nil
            ownsAudioSession = false
        }
        if cleanup.removeRemoteCommands {
            commandSession = nil
            for (command, target) in commandTargets {
                command.removeTarget(target)
                command.isEnabled = false
            }
            commandTargets.removeAll()
        }
        if cleanup.clearNowPlaying {
            let center = MPNowPlayingInfoCenter.default()
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
        } else {
            updateNowPlaying()
        }
        if cleanup.deactivateAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func fail(_ message: String) {
        endPlayback(.failure)
        errorMessage = message
    }

    private func installRemoteCommands() {
        guard commandTargets.isEmpty else { return }
        let session = UUID()
        commandSession = session
        let commands = MPRemoteCommandCenter.shared()
        addCommand(commands.playCommand, session: session) { $0.play() }
        addCommand(commands.pauseCommand, session: session) { $0.pause() }
        addCommand(commands.stopCommand, session: session) { $0.stop() }
        addCommand(commands.togglePlayPauseCommand, session: session) {
            if $0.state.requestsPlayback { $0.pause() } else { $0.play() }
        }
    }

    private func addCommand(_ command: MPRemoteCommand, session: UUID,
                            action: @escaping @MainActor @Sendable (FocusRadioController) -> Void) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] _ in
            Task { @MainActor in
                // Stop oncesi kuyruga giren komut yeni bir yayin baslatmasin.
                guard let self, self.commandSession == session else { return }
                action(self)
            }
            return .success
        }
        commandTargets.append((command, target))
    }

    private func updateNowPlaying() {
        guard state.keepsNowPlaying else { return }
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: station.name,
            MPMediaItemPropertyArtist: String(localized: "Radio Paradise • Focus radio"),
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        center.playbackState = isPlaying ? .playing : .paused
    }
}
