#if !WIDGET_EXTENSION
import Combine
import Foundation

/// App-process owner. Neither construction nor any trigger initializes stores/CloudKit while off.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class SyncCoordinator: ObservableObject {
    static let capabilityKey = "ClockinCloudSyncEnabled" // Boolean Info.plist key; absent = unsupported.
    static let preferenceKey = "Clockin.CloudSyncEnabled" // Device-local; absent = on in a capable build.
    static let shared = SyncCoordinator()

    var isEnabled: Bool {
        supportsSync() && (defaults.object(forKey: Self.preferenceKey) as? Bool ?? true)
    }
    @Published private(set) var status: SyncStatus = .off
    @Published private(set) var lastSuccessfulSync: Date?
    @Published private(set) var pendingFirstMerge: SyncFirstPreview?
    @Published private(set) var recoveryInbox: [SyncRecoveryEntry] = []
    @Published private(set) var issues: [SyncIssue] = []

    private let defaults: UserDefaults
    private let supportsSync: @MainActor () -> Bool
    private let makeStore: @MainActor () -> ClockStore
    private let makeWardrobe: @MainActor () -> WardrobeStore
    private let languageDefaults: @MainActor () -> UserDefaults?
    private let makeTransport: @MainActor (SyncBridge) -> any SyncTransport
    private let refreshServices: @MainActor () -> Void
    private let clock: any SyncClock
    private let debounce: SyncWakeup
    private var store: ClockStore?
    private var wardrobe: WardrobeStore?
    private var preferences: SyncPreferenceStore?
    private var bridge: SyncBridge?
    private var transport: (any SyncTransport)?
    private var subscriptions: Set<AnyCancellable> = []
    private var preferenceBaseline: [String: SyncPreference] = [:]
    private var work: Task<Void, Never>?
    private var shutdown: Task<Void, Never>?
    private var needsWork = false
    private var needsAccountCheck = false
    private var applying = false
    private var postponed = false
    private var localFailure: SyncPauseReason?
    private var generation = 0

    init(defaults: UserDefaults = .standard,
         supportsSync: @escaping @MainActor () -> Bool = {
             Bundle.main.bundleURL.pathExtension != "appex"
                 && Bundle.main.object(forInfoDictionaryKey: capabilityKey) as? Bool == true
         },
         makeStore: @escaping @MainActor () -> ClockStore = { SharedStore.clock },
         makeWardrobe: @escaping @MainActor () -> WardrobeStore = { WardrobeStore.shared },
         languageDefaults: @escaping @MainActor () -> UserDefaults? = { AppLanguage.shared },
         makeTransport: @escaping @MainActor (SyncBridge) -> any SyncTransport = { ClockinCloudAdapter(bridge: $0) },
         refreshServices: @escaping @MainActor () -> Void = {
             // refresh() also calls CelebrationCenter.refresh, which recalculates wardrobe earnings.
             SessionMirror.shared.refresh()
             SessionMirror.shared.refreshChimes(force: true)
         },
         clock: any SyncClock = SystemSyncClock()) {
        self.defaults = defaults; self.supportsSync = supportsSync
        self.makeStore = makeStore; self.makeWardrobe = makeWardrobe
        self.languageDefaults = languageDefaults; self.makeTransport = makeTransport
        self.refreshServices = refreshServices; self.clock = clock
        debounce = SyncWakeup(clock: clock)
    }

    deinit { work?.cancel() }

    /// Retain shared once at process launch, including a headless intent launch. The task handle
    /// is optional for callers that must await completion (background push and offline checks).
    @discardableResult
    func start() -> Task<Void, Never>? {
        guard isEnabled else { return turnOff() }
        needsWork = true
        if let work { return work }
        let generation = generation
        let task = Task { [weak self] in
            guard let self else { return }
            await self.run(generation: generation)
            if self.generation == generation { self.work = nil }
        }
        work = task
        return task
    }

    func sceneDidBecomeActive() {
        // Also covers missed/coalesced UserDefaults notifications while suspended.
        if isEnabled { preferencesDidChange() }
        start()
    }

    func handleRemoteNotification() async { await start()?.value }

    func accountMayHaveChanged() {
        guard isEnabled else { _ = turnOff(); return }
        needsAccountCheck = true
        start()
    }

    func setSyncEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.preferenceKey)
        start()
    }

    func approveFirstMerge() async {
        guard isEnabled, let bridge, let store, let preview = pendingFirstMerge else { return }
        // Capture a pending preference edit before approval; the old preview must then fail its
        // revision check rather than silently approving different data than the user reviewed.
        if debounce.deadline != nil { localDidPersist() }
        do {
            try await bridge.approveFirstMerge(preview, archiveURL: store.archiveURL)
            guard isEnabled else { return }
            postponed = false; localFailure = nil
            refreshPublishedState()
            await start()?.value
        } catch {
            if isEnabled {
                if localFailure == nil { localFailure = error as? SyncFailure == .stalePreview ? .firstMerge : .storage }
                refreshPublishedState()
            }
        }
    }

    func postponeFirstMerge() {
        guard isEnabled, pendingFirstMerge != nil else { return }
        postponed = true
        refreshPublishedState()
    }

    func acknowledge(_ id: String) {
        guard isEnabled, let bridge else { return }
        bridge.acknowledgeNotices([id])
        refreshPublishedState()
        start() // Persist acknowledgment through the same serialized worker.
    }

    private func turnOff() -> Task<Void, Never>? {
        guard work != nil || transport != nil || store != nil else { status = .off; return shutdown }
        generation += 1
        let oldWork = work
        oldWork?.cancel(); work = nil; debounce.cancel(); subscriptions.removeAll()
        let oldTransport = transport
        oldTransport?.didChange = nil; bridge?.didChange = nil; bridge?.willReceive = nil
        transport = nil; bridge = nil; store = nil; wardrobe = nil; preferences = nil
        needsWork = false; needsAccountCheck = false; localFailure = nil; postponed = false
        pendingFirstMerge = nil; recoveryInbox = []; issues = []; status = .off
        let previousShutdown = shutdown
        let task = Task {
            await previousShutdown?.value
            await oldTransport?.stop()
            await oldWork?.value
        }
        shutdown = task
        return task
    }

    private func run(generation: Int) async {
        do {
            // A cancelled worker must not await the shutdown task that is waiting for it.
            guard current(generation) else { return }
            // A fast off/on toggle must not open a second sidecar writer while old I/O drains.
            await shutdown?.value
            guard current(generation) else { return }
            let created = bridge == nil
            if created {
                status = .starting
                let store = makeStore()
                let wardrobe = makeWardrobe()
                let preferences = SyncPreferenceStore(standard: defaults, language: languageDefaults())
                let disk = SyncSidecarStore(archiveURL: store.archiveURL)
                let state = try await disk.load() ?? SyncSidecar()
                guard current(generation) else { return }
                self.store = store; self.wardrobe = wardrobe; self.preferences = preferences
                // Capture after the disk await so concurrent local edits during startup are included.
                let snapshot = capture(store: store, wardrobe: wardrobe, preferences: preferences)
                let bridge = SyncBridge(state: state, snapshot: snapshot, disk: disk) { [weak self] snapshot in
                    guard let self, self.isEnabled else { throw CancellationError() }
                    try self.apply(snapshot)
                }
                self.bridge = bridge
                localFailure = nil
                bridge.willReceive = { [weak self] in
                    guard let self else { return }
                    // An in-flight fetch can finish during a preference debounce. Record the
                    // current preferences before the bridge copies its merge candidate.
                    if self.debounce.deadline != nil { self.localDidPersist() }
                }
                bridge.didChange = { [weak self] in self?.refreshPublishedState() }
                preferenceBaseline = snapshot.preferences
                observe(store: store, wardrobe: wardrobe)
                let transport = makeTransport(bridge)
                self.transport = transport
                transport.didChange = { [weak self] in self?.refreshPublishedState() }
                needsWork = false
                await transport.launch()
                guard current(generation) else { return }
                refreshPublishedState()
            }
            while needsWork && current(generation) {
                needsWork = false
                guard let bridge, let transport else { return }
                guard await bridge.persist(), current(generation) else {
                    if current(generation) { localFailure = .storage; refreshPublishedState() }
                    return
                }
                if needsAccountCheck {
                    needsAccountCheck = false
                    await transport.accountMayHaveChanged()
                } else { await transport.synchronize() }
                guard current(generation) else { return }
                refreshPublishedState()
            }
        } catch {
            guard current(generation) else { return }
            localFailure = .storage
            refreshPublishedState()
        }
    }

    private func current(_ value: Int) -> Bool { generation == value && isEnabled && !Task.isCancelled }

    private func observe(store: ClockStore, wardrobe: WardrobeStore) {
        // These publishers are sent synchronously by @MainActor stores after persistence.
        store.didPersist.sink { [weak self] in self?.localDidPersist() }.store(in: &subscriptions)
        wardrobe.didPersist.sink { [weak self] in self?.localDidPersist() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                // Notifications can arrive on a background thread. Never read defaults/stores there.
                Task { @MainActor [weak self] in self?.preferencesDidChange() }
            }.store(in: &subscriptions)
    }

    private func capture(store: ClockStore, wardrobe: WardrobeStore, preferences: SyncPreferenceStore) -> SyncSnapshot {
        SyncSnapshot(data: store.data, preferences: preferences.capture(), wardrobe: wardrobe.state, ledger: wardrobe.ledger)
    }

    private func localDidPersist() {
        guard isEnabled, !applying, let bridge, let store, let wardrobe, let preferences else { return }
        let snapshot = capture(store: store, wardrobe: wardrobe, preferences: preferences)
        // A store save also captures any preference burst already in progress.
        debounce.cancel()
        preferenceBaseline = snapshot.preferences
        do {
            try bridge.localDidSave(snapshot, at: clock.now)
            localFailure = nil
            refreshPublishedState()
            start()
        } catch { localFailure = .invalidData; refreshPublishedState() }
    }

    private func preferencesDidChange() {
        guard isEnabled else { _ = turnOff(); return }
        guard !applying, let preferences else { return }
        let current = preferences.capture()
        guard current != preferenceBaseline else { return }
        preferenceBaseline = current
        debounce.schedule(at: clock.now.addingTimeInterval(0.5)) { [weak self] in self?.localDidPersist() }
    }

    private func apply(_ snapshot: SyncSnapshot) throws {
        guard isEnabled, let store, let wardrobe, let preferences else { throw CancellationError() }
        let local = capture(store: store, wardrobe: wardrobe, preferences: preferences)
        do {
            try SyncSnapshotValidation.validate(snapshot, preserving: local, issues: bridge?.localErrors ?? [], now: clock.now)
            guard snapshot.preferences[AppLanguage.key] == nil || preferences.language != nil else {
                throw SyncFailure.invalid("Language defaults suite unavailable")
            }
            let prepared = try wardrobe.prepareSynced(snapshot.wardrobe, ledger: snapshot.ledger)
            applying = true
            defer { applying = false }
            // No preference/wardrobe publication, including UserDefaults, before this succeeds.
            guard store.applySynced(snapshot.data) else {
                localFailure = .storage
                throw SyncFailure.invalid("Primary archive save failed")
            }
            preferences.apply(snapshot.preferences)
            wardrobe.applySynced(prepared)
            refreshServices()
            debounce.cancel()
            // Delayed defaults notifications from this apply see this exact baseline; no echo.
            preferenceBaseline = preferences.capture()
            localFailure = nil
        } catch {
            if localFailure == nil { localFailure = .invalidData }
            refreshPublishedState()
            throw error
        }
    }

    private func refreshPublishedState() {
        guard isEnabled else { return }
        if let bridge {
            pendingFirstMerge = try? bridge.firstPreview()
            recoveryInbox = bridge.state.recoveryInbox.map { SyncRecoveryEntry(recovery: $0) }
            issues = bridge.localErrors.map {
                SyncIssue(id: "local:" + $0.recordKey, kind: .localValue, recordKey: $0.recordKey, message: $0.message)
            } + bridge.state.quarantine.enumerated().map { index, value in
                SyncIssue(id: "quarantine:\(index):" + value.recordKey, kind: .quarantine, recordKey: value.recordKey,
                          message: String(localized: "An iCloud value was set aside for review. Your local data is retained.", bundle: .app),
                          quarantine: value)
            } + bridge.state.activeNotices.filter { $0.id.hasSuffix("-overflow") }.map {
                SyncIssue(id: $0.id, kind: .notice, recordKey: nil, message: $0.message)
            }
        }
        lastSuccessfulSync = transport?.lastSuccessfulSync ?? lastSuccessfulSync
        if let localFailure { status = .paused(localFailure) }
        else if pendingFirstMerge != nil { status = .paused(postponed ? .postponed : .firstMerge) }
        else { status = transport?.status ?? .starting }
    }
}
#endif
