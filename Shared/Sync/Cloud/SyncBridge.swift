import Foundation

// Inert until explicitly created. The application owns primary saves and UI.
@MainActor
final class SyncBridge {
    typealias Apply = @MainActor @Sendable (SyncSnapshot, RunningApplyProvenance) throws -> Void
    typealias Backup = @MainActor @Sendable (URL, UInt64) async throws -> SyncBackupReceipt
    var willReceive: (@MainActor @Sendable () -> Void)?
    var didChange: (@MainActor @Sendable () -> Void)?
    /// Diagnostic count of accepted full local captures (not a persisted revision counter).
    private(set) var localSaveCount = 0
    private(set) var state: SyncSidecar { didSet { didChange?() } }
    private(set) var snapshot: SyncSnapshot
    private var transportError: String?
    private var persistenceError: String?
    var lastError: String? { persistenceError ?? state.localIssues.first?.message ?? transportError }
    var localErrors: [SyncLocalIssue] { state.localIssues }
    private(set) var fetchComplete = false
    private let disk: SyncSidecarStore
    private let apply: Apply
    private let backup: Backup
    private var applyingRemote = false
    private var persistenceBatchDepth = 0
    private var scheduledPersistence: Task<Void, Never>?

    deinit { scheduledPersistence?.cancel() }

    // Callback patlamalari tek flush olur; gonderim sinirlari persist() kullanir.
    func beginPersistenceBatch() {
        persistenceBatchDepth += 1
        scheduledPersistence?.cancel(); scheduledPersistence = nil
    }

    @discardableResult
    func endPersistenceBatch() async -> Bool {
        persistenceBatchDepth = max(0, persistenceBatchDepth - 1)
        return persistenceBatchDepth > 0 ? true : await persist()
    }

    func schedulePersist() {
        guard persistenceBatchDepth == 0, scheduledPersistence == nil else { return }
        scheduledPersistence = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard let self else { return }
            self.scheduledPersistence = nil
            _ = await self.persist()
        }
    }

    init(state: SyncSidecar, snapshot: SyncSnapshot, disk: SyncSidecarStore,
         backup: Backup? = nil, apply: @escaping Apply) {
        self.state = state; self.snapshot = snapshot; self.disk = disk; self.apply = apply
        self.backup = backup ?? { try await disk.backup(archiveURL: $0, revision: $1) }
    }

    // Call after the primary save succeeds, for all three stores, on the main actor.
    func localDidSave(_ current: SyncSnapshot, at date: Date = .now) throws {
        guard !applyingRemote else { return }
        try state.capture(previous: snapshot, current: current, at: date)
        snapshot = current
        localSaveCount += 1
    }

    func seedIfNeeded(at date: Date = .now) throws {
        guard state.records.isEmpty else { return }
        try state.capture(previous: nil, current: snapshot, at: date)
    }

    // Launch reconciliation uses the previous projected snapshot to find offline/disk-only edits.
    func reconcileLocalArchive(at date: Date = .now) throws {
        if state.records.isEmpty { try seedIfNeeded(at: date); return }
        let projected = try SyncCore.materialize(state.records, onto: SyncSnapshot(data: ClockinData())).snapshot
        try state.capture(previous: projected, current: snapshot, at: date)
    }

    @discardableResult
    func receive(_ records: [SyncRecord]) throws -> [String] {
        willReceive?()
        var candidate = state
        var rejected: [String] = []
        let merge = try candidate.receive(records, snapshot: snapshot, onReject: { rejected = $0 })
        if let merge { try applyMerged(merge.snapshot, provenance: .remoteChange) }
        state = candidate
        // Transport must not infer rejection from the capped quarantine, which may have evicted bytes.
        return rejected
    }

    func review() throws -> SyncMerge {
        var result = try SyncCore.merge(local: state.records, incoming: [], onto: snapshot)
        result.snapshot = state.preservingLocalOnly(result.snapshot, from: snapshot)
        result.recoveries = state.recoveryInbox; result.notices = state.activeNotices
        return result
    }

    func markFetchComplete(_ complete: Bool) { fetchComplete = complete; didChange?() }

    func allowInitialUploadIfSafe() {
        guard fetchComplete, !state.firstMergeCompleted, !state.needsFirstMergeReview,
              !state.initialUploadAllowed else { return }
        state.initialUploadAllowed = true
        state.touch()
    }

    func firstPreview() throws -> SyncFirstPreview {
        guard fetchComplete && state.needsFirstMergeReview else {
            throw SyncFailure.invalid("No completed foreign-data fetch to review")
        }
        return try state.preview(snapshot: snapshot)
    }

    // Call only after the user approves this exact preview. Edits during backup invalidate it.
    func approveFirstMerge(_ preview: SyncFirstPreview, archiveURL: URL) async throws {
        guard preview.revision == state.revision else { throw SyncFailure.stalePreview }
        let backup = try await backup(archiveURL, preview.revision)
        var candidate = state
        try candidate.commit(preview, backup: backup)
        try applyMerged(preview.merge.snapshot, provenance: .initialImport)
        state = candidate
        _ = await persist()
    }

    private func applyMerged(_ merged: SyncSnapshot, provenance: RunningApplyProvenance) throws {
        applyingRemote = true
        defer { applyingRemote = false }
        try apply(merged, provenance)
        snapshot = merged
    }

    @discardableResult
    func persist(force: Bool = false) async -> Bool {
        scheduledPersistence?.cancel(); scheduledPersistence = nil
        defer { didChange?() }
        let captured = state
        do { try await disk.save(captured, force: force); persistenceError = nil; return captured.revision == state.revision }
        catch { persistenceError = String(localized: "Sync sidecar could not be saved: \(error.localizedDescription)", bundle: .app); return false }
    }

    func updateEngineState(_ data: Data) {
        let bounded = data.count <= SyncBounds.engineBytes ? data : nil
        if bounded == nil { report(String(localized: "Sync checkpoint exceeded its limit. Changes will be fetched again.", bundle: .app)) }
        guard state.engineState != bounded else { return }
        state.engineState = bounded
        state.touch()
    }
    func setAccount(_ id: String) throws {
        guard id.utf8.count <= 1024 else { throw SyncFailure.invalid("Invalid account identity") }
        guard state.accountID != id else { return }
        state.accountID = id; state.touch()
    }
    @discardableResult
    func bindEnvironment(_ environment: String) -> Bool { state.bindEnvironment(environment) }
    func resetTransport() { state.resetTransport() }
    func rememberSystemFields(_ fields: Data, for key: String) {
        let old = state.systemFields[key]
        state.rememberSystemFields(fields, for: key)
        if old != state.systemFields[key] { state.touch() }
    }
    func clearSystemFields(for key: String) {
        guard state.systemFields.removeValue(forKey: key) != nil else { return }
        state.touch()
    }
    func acknowledge(_ record: SyncRecord, fields: Data) { state.acknowledge(record, systemFields: fields) }
    func quarantine(_ entry: SyncQuarantine) { state.addQuarantine([entry]); state.touch() }
    func removeQuarantine(at index: Int) { state.removeQuarantine(at: index) }
    func acknowledgeNotices(_ ids: [String]) { state.acknowledgeNotices(ids) }
    func acknowledgeAllRecoveries() { state.acknowledgeAllRecoveries() }
    func report(_ message: String) { transportError = message }
}
