import Combine
import Foundation
import UserNotifications

// Kritik sesler ozel yetki ister; burada yalnizca normal sistem sesleri var.
enum FocusChimeSound: String, CaseIterable, Identifiable {
    case notification = "Default notification"
    case ringtone = "Default ringtone"
    var id: String { rawValue }
    var sound: UNNotificationSound { self == .ringtone ? .defaultRingtone : .default }
}

@MainActor
final class FocusChimeController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
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
    private var sound = FocusChimeSound.notification
    private var lastInput: Input?

    private struct Input: Equatable {
        let running: RunningSession?
        let enabled: Bool
        let interval: Int
        let sound: String
    }

    override private init() {
        super.init()
        center.delegate = self
    }

    // Izin isteme yalnizca kullanicinin acma hareketinden cagrilir.
    func requestPermission() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
        catch { errorMessage = "Could not request notifications: \(error.localizedDescription)" }
        await refreshPermission()
        enqueue()
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
        let input = Input(running: running, enabled: enabled, interval: interval, sound: sound)
        guard force || input != lastInput else { return }
        lastInput = input
        self.running = running
        self.enabled = enabled
        self.interval = interval
        self.sound = FocusChimeSound(rawValue: sound) ?? .notification
        enqueue()
    }

    private func enqueue() {
        revision += 1
        // Durdurma, devam eden bir izin veya ekleme istegini beklemez.
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
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
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            await refreshPermission()
            guard processed == revision else { continue }
            errorMessage = nil
            guard enabled, canNotify, let running, !running.isPaused else { continue }
            let now = Date.now
            let pending = await center.pendingNotificationRequests()
            guard processed == revision else { continue }
            let otherCount = pending.filter { !identifiers.contains($0.identifier) }.count
            let dates = ChimeSchedule.fireDates(now: now, worked: running.elapsed(at: now),
                isPaused: running.isPaused, enabled: enabled, intervalMinutes: interval,
                count: max(0, 64 - otherCount))
            if dates.isEmpty { errorMessage = "No notification slots available. Reopen Clockin later to try again." }
            for (index, date) in dates.enumerated() {
                guard processed == revision else { break }
                let content = UNMutableNotificationContent()
                content.title = "Focus chime"
                content.body = "Another interval of focused work."
                content.sound = sound.sound
                let delay = date.timeIntervalSinceNow
                guard delay > 0 else { continue }
                let request = UNNotificationRequest(identifier: identifiers[index], content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false))
                do { try await center.add(request) }
                catch { errorMessage = "Could not schedule chimes: \(error.localizedDescription)"; break }
            }
        }
    }

    func preview(sound raw: String) async {
        await refreshPermission()
        guard canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus chime preview"
        content.body = "Your selected system sound."
        content.sound = (FocusChimeSound(rawValue: raw) ?? .notification).sound
        do {
            try await center.add(UNNotificationRequest(identifier: "Clockin.FocusChimePreview",
                content: content, trigger: nil))
        } catch { errorMessage = "Could not preview chime: \(error.localizedDescription)" }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        if id == "Clockin.FocusChimePreview" { return [.sound, .banner] }
        guard id.hasPrefix("Clockin.FocusChime.") else { return [] }
        return await MainActor.run {
            guard self.enabled, let running = SharedStore.clock.running, !running.isPaused else { return [] }
            return [.sound, .banner]
        }
    }
}
