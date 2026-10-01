import AppKit
import Combine
import Sparkle

/// Sparkle owns scheduling, signature verification, installation and relaunch.
/// Keep one controller alive for the lifetime of this menu bar application.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    /// True once Sparkle has started. Keep actions available during background
    /// work; a requested check waits until Sparkle can start or focus its UI.
    @Published private(set) var isReady = false
    /// A version a background check found and did not put in front of the
    /// user. The menu bar and Settings show it until the user opens it.
    @Published private(set) var pendingVersion: String?
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var startupError: String?

    private let controller: SPUStandardUpdaterController
    private let reminders = GentleUpdateReminders()
    private var started = false
    private var checkRequested = false
    private var checkAvailability: AnyCancellable?
    private var observations = Set<AnyCancellable>()

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private init() {
        // Preserve an existing user's opt-out exactly once. From here on,
        // Sparkle is the sole owner of this preference and the update schedule.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "SUEnableAutomaticChecks") == nil,
           let previous = defaults.object(forKey: "Clockin.AutoCheckUpdates") as? Bool {
            defaults.set(previous, forKey: "SUEnableAutomaticChecks")
        }
        defaults.removeObject(forKey: "Clockin.AutoCheckUpdates")
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: reminders
        )
        reminders.onChange = { [weak self] version in self?.pendingVersion = version }
        checkAvailability = controller.updater.publisher(for: \.canCheckForUpdates)
            .sink { @Sendable [weak self] available in
                // Sparkle publishes on main. Defer until its state transition
                // (and any gentle-reminder callback) has finished.
                guard available else { return }
                DispatchQueue.main.async { self?.performRequestedCheck() }
            }
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .sink { @Sendable [weak self] value in Task { @MainActor in self?.automaticallyChecksForUpdates = value } }
            .store(in: &observations)
        controller.updater.publisher(for: \.lastUpdateCheckDate)
            .sink { @Sendable [weak self] value in Task { @MainActor in self?.lastChecked = value } }
            .store(in: &observations)
    }

    func start() {
        guard !started else { return }
        do {
            try controller.updater.start()
            started = true
            isReady = true
            startupError = nil
        } catch {
            startupError = error.localizedDescription
        }
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    /// Starts a check, or brings an update that is already open or waiting
    /// to the front.
    func checkForUpdates() {
        guard started else { return }
        checkRequested = true
        // Let the menu or panel close before Sparkle presents its window.
        DispatchQueue.main.async { [self] in
            performRequestedCheck()
        }
    }

    private func performRequestedCheck() {
        // False while a background appcast is loading; true again when an
        // update is ready (even if hidden by gentle reminders), or work ends.
        guard checkRequested, started, controller.updater.canCheckForUpdates else { return }
        checkRequested = false
        // Sparkle activates the app when presenting/focusing its own window.
        controller.checkForUpdates(nil)
    }
}

/// Clockin is a menu-bar app, so it is rarely the active app when a scheduled
/// check finds an update. Sparkle would then order its alert behind other
/// windows, where it goes unnoticed. Right after launch Sparkle can show it in
/// front; otherwise the update is offered from the menu bar and Settings until
/// the user opens it.
@MainActor
private final class GentleUpdateReminders: NSObject, SPUStandardUserDriverDelegate {
    // Sparkle's user driver invokes these callbacks on the main thread.
    var onChange: (@MainActor (String?) -> Void)?

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate, !state.userInitiated else { return }
        let version = update.displayVersionString
        Task { @MainActor [weak self] in self?.onChange?(version) }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor [weak self] in self?.onChange?(nil) }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor [weak self] in self?.onChange?(nil) }
    }
}
