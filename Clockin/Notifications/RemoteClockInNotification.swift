import Combine
import Foundation

/// Uses the same successful store events as the Mac tip. A session start is
/// the available identity; RunningSession has no originating-device field.
@MainActor
final class RemoteClockInNotification {
    static let enabledKey = "Clockin.NotifyRemoteClockIn.v1"
    static let handledStartsKey = "Clockin.RemoteClockInHandledStarts.v1"
    static let identifierPrefix = "Clockin.RemoteClockIn."

    private let defaults: UserDefaults
    private let isActive: @MainActor () -> Bool
    private let canNotify: @MainActor () async -> Bool
    private let post: @MainActor (Date) async throws -> Void
    private var subscriptions: Set<AnyCancellable> = []
    private var worker: Task<Void, Never>?
    private weak var store: ClockStore?

    init(defaults: UserDefaults, isActive: @escaping @MainActor () -> Bool,
         canNotify: @escaping @MainActor () async -> Bool,
         post: @escaping @MainActor (Date) async throws -> Void) {
        self.defaults = defaults; self.isActive = isActive
        self.canNotify = canNotify; self.post = post
    }

    func start(store: ClockStore) {
        guard subscriptions.isEmpty else { return }
        self.store = store
        store.didClockInLocally.sink { [weak self] start in
            self?.remember(start)
        }.store(in: &subscriptions)
        store.didApplySyncedRunning.sink { [weak self] change in
            self?.applied(previous: change.previous, current: change.current)
        }.store(in: &subscriptions)
    }

    private func remember(_ start: Date) {
        var starts = defaults.array(forKey: Self.handledStartsKey) as? [Date] ?? []
        guard !starts.contains(start) else { return }
        starts.append(start)
        defaults.set(starts, forKey: Self.handledStartsKey)
    }

    private var enabled: Bool { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }

    private func applied(previous: RunningSession?, current: RunningSession?) {
        guard let current, current.start != previous?.start else { return }
        let start = current.start
        guard !(defaults.array(forKey: Self.handledStartsKey) as? [Date] ?? []).contains(start) else { return }
        // Claim synchronously, before any await. Active/opted-out arrivals also
        // stay quiet on later echoes, and local starts survive multiple sessions.
        remember(start)
        guard enabled, !isActive() else { return }
        let previousWork = worker
        worker = Task { [weak self] in
            await previousWork?.value
            guard let self, await self.canNotify(), self.enabled, !self.isActive(),
                  self.store?.running?.start == start else { return }
            // At most one submission per timer, including after relaunch. Do not
            // retry stale alerts or ask for authorization from this background path.
            try? await self.post(start)
        }
    }

    func finishPendingUpdates() async { await worker?.value }
}
