import AppKit
import Combine
import SwiftUI

/// iPhone'da `RootView`'un tasidigi tazelemeler: chime kuyrugu, uzun oturum
/// hatirlaticisi, nudge'lar ve kutlamalar. Mac'te ana pencere kapaliyken de
/// uygulama menu cubugunda calisir; bu yuzden bir gorunumde degil burada.
@MainActor
final class MacAppServices: ObservableObject {
    static let shared = MacAppServices()

    /// Barindirilan gorunumler bir `Scene` icinde degil; `scenePhase` onlara
    /// buradan verilir. Pencere gorunur ve ortulu degilse etkin sayilir:
    /// baska uygulamada calisirken yandaki sayac akmaya devam etmeli.
    @Published private(set) var scenePhase: ScenePhase = .background

    private struct Preferences: Equatable {
        var chime: [String]
        var nudges: [String]
        var accessory: String
        var goals: [Double]

        init(_ defaults: UserDefaults) {
            chime = [defaults.bool(forKey: "Clockin.ChimeEnabled").description,
                     String(defaults.integer(forKey: "Clockin.ChimeIntervalMinutes")),
                     defaults.string(forKey: "Clockin.ChimeSound") ?? ""]
            nudges = [(defaults.object(forKey: NudgePlanner.enabledKey) as? Bool ?? true).description,
                      defaults.string(forKey: NudgePlanner.toneKey) ?? ""]
            accessory = defaults.string(forKey: CompanionAccessory.storageKey) ?? "Auto"
            goals = [defaults.double(forKey: "Clockin.GoalDailyHours"),
                     defaults.double(forKey: "Clockin.GoalMonthlyHours")]
        }
    }

    private weak var store: ClockStore?
    private var preferences: Preferences?
    private var subscriptions: Set<AnyCancellable> = []
    private var ticker: Task<Void, Never>?

    func start(store: ClockStore) {
        guard self.store == nil else { return }
        self.store = store
        preferences = Preferences(.standard)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.preferencesChanged() } }
            .store(in: &subscriptions)
        let center = NotificationCenter.default
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                     NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                     NSWindow.didDeminiaturizeNotification, NSWindow.didBecomeKeyNotification,
                     NSWindow.willCloseNotification] {
            center.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in MainActor.assumeIsolated { self?.updatePhase() } }
                .store(in: &subscriptions)
        }
        updatePhase()
        // Mac uyandiginda ya da uygulama one geldiginde kuyruk hemen tazelensin.
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.tick(force: true) } }
            .store(in: &subscriptions)
        tick(force: true)
        ticker = Task { [weak self] in
            // iPhone'da on planda dakikada bir; Mac uygulamasi hep "on planda".
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                self?.tick(force: true)
            }
        }
    }

    func stop() {
        ticker?.cancel()
        subscriptions.removeAll()
    }

    private func tick(force: Bool) {
        guard let store else { return }
        FocusChimeController.shared.clearDelivered()
        LongSessionReminderController.shared.update(running: store.running, force: force)
        NudgeController.shared.update(store: store)
        SessionMirror.shared.refreshChimes(force: force)
        CelebrationCenter.shared.refresh(store: store)
    }

    private func preferencesChanged() {
        guard let store else { return }
        let current = Preferences(.standard)
        guard let old = preferences, old != current else { return }
        preferences = current
        if old.chime != current.chime { SessionMirror.shared.refreshChimes() }
        if old.nudges != current.nudges || old.goals != current.goals { NudgeController.shared.update(store: store) }
        if old.nudges != current.nudges || old.accessory != current.accessory { SessionMirror.shared.refreshCompanion() }
        if old.goals != current.goals {
            CelebrationCenter.shared.refresh(store: store)
            if GoalPrompt.hasGoal(daily: current.goals[0], monthly: current.goals[1]) {
                UserDefaults.standard.set(true, forKey: GoalPrompt.configuredKey)
            }
        }
    }

    private func updatePhase() {
        let window = MainWindowController.shared.window
        let visible = window.map { $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) } ?? false
        let phase: ScenePhase = visible ? .active : .background
        guard phase != scenePhase else { return }
        scenePhase = phase
        // Kutlamalar yalnizca gorunen, etkin pencerede oynar; iPhone'da
        // `RootView` bunu sahne evresiyle yapiyordu.
        CelebrationCenter.shared.setActive(false)
        if phase == .active, let store {
            CelebrationCenter.shared.refresh(store: store)
            CelebrationCenter.shared.setActive(true)
        }
    }
}
