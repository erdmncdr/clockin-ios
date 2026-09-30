import Combine
import Foundation

/// Advice only: observing these events never changes the timer or the sync state.
@MainActor
final class MacLiveActivityTip: ObservableObject {
    static let shared = MacLiveActivityTip()
    static let dismissedKey = "Clockin.MacLiveActivityTipDismissed.v1"
    static let pendingKey = "Clockin.MacLiveActivityTipPending.v1"
    static let localStartKey = "Clockin.MacLiveActivityTipLocalStart.v1"

    @Published private(set) var isVisible: Bool
    private let defaults: UserDefaults
    private var subscriptions: Set<AnyCancellable> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isVisible = defaults.bool(forKey: Self.pendingKey) && !defaults.bool(forKey: Self.dismissedKey)
    }

    func start(store: ClockStore) {
        guard subscriptions.isEmpty else { return }
        store.didClockInLocally.sink { [weak self] start in
            self?.defaults.set(start, forKey: Self.localStartKey)
        }.store(in: &subscriptions)
        store.didApplySyncedRunning.sink { [weak self] change in
            self?.applied(previous: change.previous, current: change.current)
        }.store(in: &subscriptions)
    }

    private func applied(previous: RunningSession?, current: RunningSession?) {
        guard !defaults.bool(forKey: Self.dismissedKey), !isVisible,
              let current,
              // A local timer's pause/resume, note edits and sync echoes keep its start.
              current.start != previous?.start,
              current.start != defaults.object(forKey: Self.localStartKey) as? Date else { return }
        // A paused active session also has a mirrored Live Activity. Keep the advice
        // available until explicitly dismissed, including across process restarts.
        defaults.set(true, forKey: Self.pendingKey)
        isVisible = true
    }

    func dismiss() {
        defaults.set(true, forKey: Self.dismissedKey)
        defaults.removeObject(forKey: Self.pendingKey)
        isVisible = false
    }
}
