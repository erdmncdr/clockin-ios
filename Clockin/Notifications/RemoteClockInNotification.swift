import Combine
import Foundation

/// Uses the same successful store events as the Mac tip. A session start is
/// the available identity; RunningSession has no originating-device field.
@MainActor
final class RemoteClockInNotification {
    static let enabledKey = "Clockin.NotifyRemoteClockIn.v1"
    static let handledStartsKey = "Clockin.RemoteClockInHandledStarts.v1"
    static let handledCutoffKey = "Clockin.RemoteClockInHandledCutoff.v1"
    static let recentStartLimit = 256
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
        // Yuklenen arsiv ve basarili yerel yazimlar (geri yukleme dahil)
        // sayac kaybolmadan once sessizce hatirlanir. Mac olaylari degismez.
        remember(store.running?.start)
        store.didPersist.sink { [weak self, weak store] in
            self?.remember(store?.running?.start)
        }.store(in: &subscriptions)
        store.didApplySyncedRunning.sink { [weak self] change in
            self?.applied(previous: change.previous, current: change.current, provenance: change.provenance)
        }.store(in: &subscriptions)
    }

    // En yeni 256 baslangici sakla; atilan en yeni tarihe kadar olan tum
    // baslangiclar artik sessizdir. Yas siniri yok; esik yalnizca budamada ilerler.
    @discardableResult
    private func remember(_ start: Date?) -> Bool {
        let saved = defaults.array(forKey: Self.handledStartsKey) as? [Date] ?? []
        var cutoff = defaults.object(forKey: Self.handledCutoffKey) as? Date
        var starts = Set(saved.filter { cutoff == nil || $0 > cutoff! })
        let unseen = start.map { (cutoff == nil || $0 > cutoff!) && !starts.contains($0) } ?? false
        if unseen, let start { starts.insert(start) }
        let sorted = starts.sorted()
        if sorted.count > Self.recentStartLimit {
            cutoff = sorted[sorted.count - Self.recentStartLimit - 1]
            // Dizi kisalmadan esigi yaz: arada kesilirse eski kimlikler
            // tekrar uygun hale gelmesin. Kapali ayarda da ayni yol kullanilir.
            defaults.set(cutoff, forKey: Self.handledCutoffKey)
        }
        let recent = Array(sorted.suffix(Self.recentStartLimit))
        if saved != recent { defaults.set(recent, forKey: Self.handledStartsKey) }
        return unseen && start.map { cutoff == nil || $0 > cutoff! } == true
    }

    private var enabled: Bool { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }

    private func applied(previous: RunningSession?, current: RunningSession?, provenance: RunningApplyProvenance) {
        let unseen = remember(current?.start)
        guard let current else { return }
        let start = current.start
        // Claim synchronously, before any await. Active/opted-out arrivals also
        // stay quiet on later echoes, and local starts survive multiple sessions.
        guard provenance == .remoteChange, current.start != previous?.start,
              unseen, enabled, !isActive() else { return }
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
