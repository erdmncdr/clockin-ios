import Foundation

final class TestNow: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Date
    init(_ date: Date) { stored = date }
    var value: Date {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

@main struct PersistenceChecks {
    @MainActor static func main() async throws {
        var checks = 0
        func check(_ passed: Bool, _ name: String) {
            guard passed else { print("FAIL \(name)"); exit(1) }
            checks += 1; print("ok \(name)")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sync-writes-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("clockin.json")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = TestNow(now)
        let disk = SyncSidecarStore(archiveURL: url, now: { clock.value })
        var snapshot = SyncSnapshot(data: ClockinData())
        for i in 0..<1321 {
            let start = now.addingTimeInterval(Double(-i) * 86400)
            snapshot.data.sessions.append(WorkSession(id: UUID(), start: start, end: start + 3600,
                duration: 3600, note: "", hourlyRate: 25, source: "Clockin"))
        }
        var state = SyncSidecar(deviceID: "resource-test")
        state.firstMergeCompleted = true
        try state.capture(previous: nil, current: snapshot, at: now)
        state.pending = []
        state.accountID = "local-fixture"
        for key in state.records.keys { state.rememberSystemFields(Data(repeating: 42, count: 3200), for: key) }
        let bridge = SyncBridge(state: state, snapshot: snapshot, disk: disk) { _, _ in }
        check(await bridge.persist(), "initial multi-megabyte state persists")
        check(await disk.writeCount == 1, "initial state writes once")
        check(await disk.lastWriteWasOnMainThread == false, "sidecar encoding and atomic write run on the disk actor off the main thread")
        check(await disk.bytesWritten > 5_000_000, "fixture models the reported large sidecar")
        bridge.beginPersistenceBatch()
        for i in 0..<50 {
            bridge.updateEngineState(Data("checkpoint-\(i)".utf8))
            bridge.schedulePersist()
        }
        check(await disk.writeCount == 1, "fifty callback checkpoints stay coalesced during a pass")
        check(await bridge.endPersistenceBatch(), "pass flush succeeds")
        check(await disk.writeCount == 1, "a fetch pass that only moves the engine token defers the large write")
        clock.value = now.addingTimeInterval(SyncSidecarStore.engineOnlyInterval)
        check(await bridge.persist(), "deferred engine token flush succeeds")
        check(await disk.writeCount == 2, "the engine token is written once after the interval")
        check(try await SyncSidecarStore(archiveURL: url).load()?.engineState == Data("checkpoint-49".utf8),
              "the written engine token is the latest one")
        let revision = bridge.state.revision
        bridge.beginPersistenceBatch()
        for _ in 0..<50 {
            bridge.updateEngineState(Data("checkpoint-49".utf8))
            try bridge.setAccount("local-fixture")
            try bridge.receive([])
            bridge.markFetchComplete(true)
            bridge.allowInitialUploadIfSafe()
            bridge.schedulePersist()
        }
        check(await bridge.endPersistenceBatch(), "quiet poll flush succeeds")
        check(bridge.state.revision == revision, "quiet events do not advance the persisted revision")
        check(await disk.writeCount == 2, "quiet poll performs zero writes")
        check(await bridge.persist(), "repeated explicit safety barrier succeeds")
        check(await disk.writeCount == 2, "identical state skips even explicit writes")
        bridge.beginPersistenceBatch()
        var edit = snapshot; edit.data.hourlyRate = 30
        try bridge.localDidSave(edit, at: now + 1)
        check(await bridge.persist(), "pending edit is durable before a send")
        let beforeSend = await disk.writeCount
        let reopened = try await SyncSidecarStore(archiveURL: url).load()
        check(reopened?.pending == bridge.state.pending && !(reopened?.pending.isEmpty ?? true), "reopen sees pending outbox before send")
        for key in bridge.state.pending {
            if let record = bridge.state.records[key] { bridge.acknowledge(record, fields: Data([1])) }
        }
        check(await bridge.endPersistenceBatch(), "acknowledgment flush succeeds")
        check(await disk.writeCount == beforeSend + 1, "upload adds only the required acknowledgment barrier")
        let latest = bridge.state
        try await disk.save(state)
        check(try await disk.load()?.revision == latest.revision, "older captured revision cannot overwrite the latest state")
        let loadedDisk = SyncSidecarStore(archiveURL: url)
        if let loaded = try await loadedDisk.load() { try await loadedDisk.save(loaded) }
        check(await loadedDisk.writeCount == 0, "relaunch and quiet poll do not rewrite the loaded bytes")
        bridge.updateEngineState(Data("background".utf8)); bridge.schedulePersist()
        let beforeLifecycle = await disk.writeCount
        let deferredFlush = await bridge.persist()
        let afterDeferred = await disk.writeCount
        check(deferredFlush && afterDeferred == beforeLifecycle,
              "an ordinary flush inside the interval still defers an engine-token-only change")
        check(await bridge.persist(force: true), "background or termination barrier flushes a scheduled change immediately")
        check(try await loadedDisk.load()?.engineState == Data("background".utf8), "lifecycle flush is visible after reopen")
        let afterFlush = await disk.writeCount
        try await Task.sleep(for: .milliseconds(300))
        check(await disk.writeCount == afterFlush, "cancelled debounce cannot write again after lifecycle flush")
        let blocker = directory.appendingPathComponent("blocker")
        try Data([1]).write(to: blocker)
        let failingDisk = SyncSidecarStore(archiveURL: blocker.appendingPathComponent("clockin.json"))
        let failingBridge = SyncBridge(state: state, snapshot: snapshot, disk: failingDisk) { _, _ in }
        check(!(await failingBridge.persist()) && failingBridge.lastError != nil, "failed atomic save reports an error without a trap")
        try FileManager.default.removeItem(at: blocker)
        check(await failingBridge.persist(), "failed save remains dirty and retries")
        check(await failingDisk.writeCount == 1, "failed save does not count as a successful write")
        var exhausted = state
        exhausted.revision = .max
        exhausted.touch()
        var rejectedRevision = false
        do { try await disk.save(exhausted) } catch { rejectedRevision = true }
        check(rejectedRevision, "exhausted revision rejects persistence without overflowing or replacing disk state")
        exhausted = state; exhausted.sequence = .max
        var rejectedSequence = false
        do { try exhausted.capture(previous: snapshot, current: edit, at: now) } catch { rejectedSequence = true }
        check(rejectedSequence, "exhausted sequence rejects local capture without overflowing")
        print("All \(checks) persistence checks passed.")
    }
}
