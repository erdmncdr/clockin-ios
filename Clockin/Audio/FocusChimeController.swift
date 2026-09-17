import AVFoundation
import UIKit
import Combine
import Foundation
import UserNotifications

@MainActor
final class FocusChimeController: NSObject, ObservableObject, UNUserNotificationCenterDelegate, AVAudioPlayerDelegate {
    static let shared = FocusChimeController()
    @Published private(set) var permissionText = "Checking notification permission"
    @Published private(set) var canNotify = false
    @Published private(set) var needsSystemSettings = false
    @Published private(set) var errorMessage: String?
    private let center = UNUserNotificationCenter.current()
    private let identifiers = (0..<ChimeSchedule.maximumCount).map { "Clockin.FocusChime.\($0)" }
    private var revision = 0
    private var worker: Task<Void, Never>?
    private var running: RunningSession?
    private var enabled = false
    private var interval = 10
    private var sound = FocusChimeSound.defaultSound
    private var lastInput: Input?
    private var player: AVAudioPlayer?
    private var ownsAudioSession = false
    private var playbackObservers: [NSObjectProtocol] = []

    private struct Input: Equatable {
        let running: RunningSession?
        let enabled: Bool
        let interval: Int
        let sound: String
    }

    override private init() {
        super.init()
        center.delegate = self
        LongSessionReminderNotification.register(on: center)
        let notifications = NotificationCenter.default
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.mediaServicesWereResetNotification,
                     UIApplication.didEnterBackgroundNotification] {
            playbackObservers.append(notifications.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor in self?.stopPlayback() }
            })
        }
        playbackObservers.append(notifications.addObserver(forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: nil) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor in self?.stopPlayback() }
            }
        })
    }

    // Izin isteme yalnizca kullanicinin acma hareketinden cagrilir.
    func requestPermission() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
        catch { errorMessage = "Could not request notifications: \(error.localizedDescription)" }
        await refreshPermission()
        enqueue()
        LongSessionReminderController.shared.update(running: SharedStore.clock.running, force: true)
        NudgeController.shared.update(store: SharedStore.clock)
    }

    func refreshPermission() async {
        let settings = await center.notificationSettings()
        canNotify = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        needsSystemSettings = settings.authorizationStatus == .denied || settings.authorizationStatus == .provisional || (canNotify && settings.soundSetting != .enabled)
        switch settings.authorizationStatus {
        case .notDetermined: permissionText = "Not requested. Turn on Focus chime to allow notifications."
        case .denied: permissionText = "Notifications denied"
        case .provisional: permissionText = "Quiet delivery only. Enable sounds in system Settings."
        case .authorized, .ephemeral:
            permissionText = settings.soundSetting == .enabled ? "Notifications and sounds allowed" : "Notifications allowed, sounds disabled"
        @unknown default: permissionText = "Notification permission unknown"
        }
    }

    /// Girdiler degismediyse kuyruga dokunulmaz. `SessionMirror` her kayit
    /// duzenlemesinde cagirir; her seferinde yirmi bildirimi silip yeniden
    /// kurmak gereksiz. On plandaki dakikalik tamamlama `force` ile gelir.
    func update(running: RunningSession?, enabled: Bool, interval: Int, sound: String, force: Bool = false) {
        let selected = FocusChimeSound.selected(sound)
        let input = Input(running: running, enabled: enabled, interval: interval, sound: selected.rawValue)
        guard force || input != lastInput else { return }
        lastInput = input
        self.running = running
        self.enabled = enabled
        self.interval = interval
        self.sound = selected
        enqueue()
    }

    private func enqueue() {
        revision += 1
        // Durdurma, devam eden bir izin veya ekleme istegini beklemez.
        if !enabled || running == nil || running?.isPaused == true {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            await self.drain()
            self.worker = nil
        }
    }

    private func drain() async {
        // Tek yazici eski async eklemelerin yeni takvimi ezmesini engeller.
        var processed = -1
        while processed != revision {
            processed = revision
            await refreshPermission()
            guard processed == revision else { continue }
            errorMessage = nil
            let pending = await center.pendingNotificationRequests()
            guard processed == revision else { continue }
            let otherCount = pending.filter { !identifiers.contains($0.identifier) }.count
            // Henuz eklenmemis hatirlatici ve nudgelar icin de yer ayir.
            let reminderReserve = pending.contains { $0.identifier == LongSessionReminderNotification.identifier } ? 0 : 1
            let nudgeCount = pending.filter { $0.identifier.hasPrefix(NudgePlanner.prefix) }.count
            let reserved = reminderReserve + max(0, NudgePlanner.maximumPending - nudgeCount)
            let now = Date.now
            let working = enabled && canNotify && running?.isPaused == false
            let dates = ChimeSchedule.fireDates(now: now, worked: running?.elapsed(at: now) ?? 0,
                isPaused: running?.isPaused ?? true, enabled: working, intervalMinutes: interval,
                count: max(0, 64 - otherCount - reserved))
            let existing = Dictionary(uniqueKeysWithValues: pending.compactMap { request -> (Int, Date)? in
                guard let slot = identifiers.firstIndex(of: request.identifier) else { return nil }
                let date = (request.content.userInfo["fireDate"] as? Double).map(Date.init(timeIntervalSinceReferenceDate:))
                return (slot, date ?? .distantPast)
            })
            // Dakikalik tamamlama ayni bildirimleri silip eklemez.
            let changes = ChimeSchedule.reconcile(desired: dates, existing: existing)
            if !changes.removed.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: changes.removed.map { identifiers[$0] })
            }
            if working && dates.isEmpty { errorMessage = "No notification slots available. Reopen Clockin later to try again." }
            for (index, date) in changes.additions.sorted(by: { $0.value < $1.value }) {
                guard processed == revision else { break }
                let content = UNMutableNotificationContent()
                content.title = "Focus chime"
                content.body = "Another interval of focused work."
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound.fileName))
                content.userInfo = ["fireDate": date.timeIntervalSinceReferenceDate]
                let delay = date.timeIntervalSinceNow
                guard delay > 0 else { continue }
                let request = UNNotificationRequest(identifier: identifiers[index], content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false))
                do { try await center.add(request) }
                catch { errorMessage = "Could not schedule chimes: \(error.localizedDescription)"; break }
            }
        }
    }

    func preview(sound raw: String) {
        play(FocusChimeSound.selected(raw))
    }

    func updatePlaybackVolume() {
        player?.volume = Float(FocusChimeVolume.selected())
    }

    private func play(_ sound: FocusChimeSound) {
        stopPlayback()
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: nil) else {
            errorMessage = "Could not find the selected chime sound."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            // Radyo ortak oturumu kullaniyor; kategorisini degistirme.
            if !FocusRadioController.shared.ownsAudioSession {
                try session.setCategory(.ambient, mode: .default)
                ownsAudioSession = true
                try session.setActive(true)
            }
            let player = try AVAudioPlayer(contentsOf: url)
            self.player = player
            player.delegate = self
            updatePlaybackVolume()
            guard player.prepareToPlay(), player.play() else {
                stopPlayback()
                errorMessage = "Could not play the selected chime."
                return
            }
            errorMessage = nil
        } catch {
            stopPlayback()
            errorMessage = "Could not play chime: \(error.localizedDescription)"
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        // Can bittiginde radyo veya baska uygulamalarin sesi kesilmesin.
        if ownsAudioSession && !FocusRadioController.shared.ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        ownsAudioSession = false
    }

    func retainSessionForChime() -> Bool {
        guard player != nil else { return false }
        do {
            // Radyo biterken can tamamlanir; oturum yeniden etkinlestirilmez.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            ownsAudioSession = true
            return true
        } catch {
            stopPlayback()
            return false
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finishPlayback(id: ObjectIdentifier(player), succeeded: flag)
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        finishPlayback(id: ObjectIdentifier(player), succeeded: false)
    }

    nonisolated private func finishPlayback(id: ObjectIdentifier, succeeded: Bool) {
        Task { @MainActor [weak self] in
            guard let self, let player = self.player, ObjectIdentifier(player) == id else { return }
            self.stopPlayback()
            if !succeeded { self.errorMessage = "Could not finish playing the chime." }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        if id.hasPrefix(NudgePlanner.prefix) { return [] }
        if id == LongSessionReminderNotification.identifier {
            let start = Self.reminderStart(notification.request.content)
            return await MainActor.run {
                LongSessionReminderController.shared.shouldPresent(start: start) ? [.sound, .banner] : []
            }
        }
        guard id.hasPrefix("Clockin.FocusChime.") else { return [] }
        return await MainActor.run {
            guard self.enabled, let running = SharedStore.clock.running, !running.isPaused else { return [] }
            self.play(FocusChimeSound.migrate())
            return [.banner]
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse) async {
        if response.notification.request.identifier.hasPrefix(NudgePlanner.prefix) {
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                await MainActor.run { NudgeController.shared.openToday = true }
            }
            return
        }
        guard response.notification.request.content.categoryIdentifier == LongSessionReminderNotification.category else { return }
        let start = Self.reminderStart(response.notification.request.content)
        await LongSessionReminderController.shared.handle(action: response.actionIdentifier, start: start)
    }

    nonisolated private static func reminderStart(_ content: UNNotificationContent) -> Date? {
        guard let value = content.userInfo[LongSessionReminderNotification.startKey] as? Double,
              value.isFinite else { return nil }
        return Date(timeIntervalSinceReferenceDate: value)
    }

    func finishPendingUpdates() async { await worker?.value }
}
