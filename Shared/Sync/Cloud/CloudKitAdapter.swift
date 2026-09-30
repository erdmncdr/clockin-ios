import CloudKit
import Foundation
import OSLog

private let syncLog = Logger(subsystem: "com.erdmncdr.clockin", category: "sync")

@available(iOS 17.0, macOS 14.0, *)
enum ClockinCloudRecord {
    static let containerID = "iCloud.com.erdmncdr.clockin"
    static let zoneID = CKRecordZone.ID(zoneName: "Clockin", ownerName: CKCurrentUserDefaultName)
    static let maximumPayloadBytes = SyncBounds.envelopeBytes

    static func id(_ record: SyncRecord) -> CKRecord.ID {
        // UUID session names remain compatible with the proposed schema; all others are namespaced.
        CKRecord.ID(recordName: record.kind == .session ? record.name : record.key, zoneID: zoneID)
    }

    static func decode(_ record: CKRecord) throws -> SyncRecord {
        guard record.recordID.zoneID == zoneID,
              let bytes = record["payload"] as? Data, bytes.count <= maximumPayloadBytes,
              let schema = record["schema"] as? Int64, schema == 2 else {
            throw SyncFailure.invalid("Invalid CloudKit envelope")
        }
        let value = try SyncCoding.decode(SyncRecord.self, bytes)
        try SyncCore.validate(value)
        guard record.recordType == value.kind.rawValue, id(value) == record.recordID,
              let winner = value.winner,
              record["modifiedAt"] as? Date == winner.stamp.modifiedAt,
              record["modifiedBy"] as? String == winner.stamp.modifiedBy else {
            throw SyncFailure.invalid("CloudKit identity or stamp mismatch")
        }
        return value
    }

    static func encode(_ value: SyncRecord, systemFields: Data?) throws -> CKRecord {
        try SyncCore.validate(value)
        let bytes = try SyncCoding.encode(value)
        guard bytes.count <= maximumPayloadBytes else {
            throw SyncFailure.invalid("Invalid schema-2 envelope exceeds defensive byte limit")
        }
        let record: CKRecord
        if let systemFields {
            let decoder = try NSKeyedUnarchiver(forReadingFrom: systemFields)
            decoder.requiresSecureCoding = true
            defer { decoder.finishDecoding() }
            guard let restored = CKRecord(coder: decoder), restored.recordID == id(value),
                  restored.recordType == value.kind.rawValue else { throw SyncFailure.invalid("Invalid system fields") }
            record = restored
        } else { record = CKRecord(recordType: value.kind.rawValue, recordID: id(value)) }
        record["schema"] = Int64(2) as CKRecordValue
        record["payload"] = bytes as CKRecordValue
        record["modifiedAt"] = value.winner?.stamp.modifiedAt as CKRecordValue?
        record["modifiedBy"] = value.winner?.stamp.modifiedBy as CKRecordValue?
        return record
    }

    static func systemFields(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class ClockinCloudAdapter: CKSyncEngineDelegate, SyncTransport {
    private let bridge: SyncBridge
    private let container: CKContainer
    private let clock: any SyncClock
    private let retry: SyncWakeup
    private var engine: CKSyncEngine?
    private var pass = SyncSendPass()
    private var launchTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var stopped = false
    private var halted = false
    private var fetchFailed = false
    private var passFailed = false
    private var retryAfter: Date?
    private var launchBackoff = SyncLaunchBackoff()
    private var generation = 0
    private var blockedKeys = Set<String>()
    private(set) var status: SyncStatus = .off { didSet { didChange?() } }
    private(set) var lastSuccessfulSync: Date? { didSet { didChange?() } }
    var didChange: (@MainActor @Sendable () -> Void)?

    init(bridge: SyncBridge, clock: any SyncClock = SystemSyncClock()) {
        self.bridge = bridge; self.clock = clock; retry = SyncWakeup(clock: clock)
        container = CKContainer(identifier: ClockinCloudRecord.containerID)
    }

    // Retryable and idempotent. Repeated callers share the launch already in flight.
    func launch() async {
        guard !stopped, !halted else { return }
        if engine != nil { await synchronize(); return }
        if let launchTask { await launchTask.value; return }
        guard retryAfter.map({ $0 <= clock.now }) ?? true else { scheduleRetry(); return }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLaunch()
            self.launchTask = nil
        }
        launchTask = task
        await task.value
    }

    private func performLaunch() async {
        let generation = generation
        status = .starting
        do {
            let accountStatus = try await container.accountStatus()
            guard isCurrent(generation) else { return }
            switch Self.accountState(accountStatus) {
            case .absent:
                retryAfter = nil; retry.cancel()
                report(.accountProblem)
                return
            case .temporary:
                retryLaunch()
                return
            case .available: break
            }
            let account = try await container.userRecordID().recordName
            guard isCurrent(generation) else { return }
            if let previous = bridge.state.accountID, previous != account {
                halted = true
                report(.accountProblem)
                return
            }
            try bridge.setAccount(account)
            try bridge.reconcileLocalArchive()
            let serialized = try bridge.state.engineState.map { try SyncCoding.decode(CKSyncEngine.State.Serialization.self, $0) }
            guard await bridge.persist(), isCurrent(generation) else {
                if isCurrent(generation) { report(.paused(.storage)) }
                return
            }
            var config = CKSyncEngine.Configuration(database: container.privateCloudDatabase,
                                                    stateSerialization: serialized, delegate: self)
            config.automaticallySync = false
            let engine = CKSyncEngine(config)
            self.engine = engine
            launchBackoff.reset(); retryAfter = nil; retry.cancel()
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClockinCloudRecord.zoneID))])
            await synchronize()
        } catch is CancellationError { return }
        catch {
            guard isCurrent(generation) else { return }
            if let cloud = error as? CKError {
                // A failed identity lookup is not evidence that the account disappeared.
                // Only accountStatus.noAccount/restricted above takes the no-account branch.
                if Self.failure(cloud.code).action == .engineRetry && cloud.code != .operationCancelled {
                    retryLaunch(minimum: cloud.retryAfterSeconds ?? 0)
                } else { report(cloud.code == .notAuthenticated ? .accountProblem : .paused(.sendFailed)) }
            } else { report(.paused(.invalidData)) }
        }
    }

    func synchronize() async {
        guard !stopped, !halted else { return }
        guard let engine else { await launch(); return }
        if let syncTask {
            _ = pass.request()
            await syncTask.value
            return
        }
        guard pass.request() else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                guard !self.stopped, !self.halted, self.engine === engine else { break }
                if self.retryAfter.map({ $0 > self.clock.now }) == true { self.scheduleRetry(); break }
                self.retryAfter = nil; self.retry.cancel()
                await self.synchronizePass(engine)
            } while self.pass.finishPass()
            self.pass.cancel()
            self.syncTask = nil
        }
        syncTask = task
        await task.value
    }

    private func synchronizePass(_ engine: CKSyncEngine) async {
        let generation = generation
        status = .syncing
        passFailed = false; fetchFailed = false
        bridge.markFetchComplete(false)
        do {
            do { try await engine.fetchChanges(.init(scope: .zoneIDs([ClockinCloudRecord.zoneID]))) }
            catch let error as CKError where error.code == .zoneNotFound { recoverZone(engine) }
            guard isCurrent(generation), !fetchFailed else { return }
            bridge.markFetchComplete(true)
            bridge.allowInitialUploadIfSafe()
            guard bridge.state.permitsUpload else { report(.paused(.firstMerge)); return }
            guard await bridge.persist(), isCurrent(generation) else {
                if isCurrent(generation) { report(.paused(.storage)) }
                return
            }
            // Only once per pass. A permanent error is eligible again on the NEXT pass.
            enqueuePending(engine)
            try await engine.sendChanges(.init(scope: .zoneIDs([ClockinCloudRecord.zoneID])))
            guard isCurrent(generation), !passFailed else { return }
            guard await bridge.persist(), isCurrent(generation) else {
                if isCurrent(generation) { report(.paused(.storage)) }
                return
            }
            if bridge.state.pending.isEmpty {
                lastSuccessfulSync = clock.now
                status = .upToDate
            } else {
                // Kalan kayitlar yeni bir tetik beklemesin; ilk yuklemede 639
                // kaydin 39'u bir sonraki acilisa kadar bekliyordu.
                report(.paused(.sendFailed))
                delayRetry(30)
            }
        } catch is CancellationError { return }
        catch { if isCurrent(generation) { handle(error) } }
    }

    func accountMayHaveChanged() async {
        guard !stopped else { return }
        // An apply failure must not be cleared by an unrelated account notification.
        guard !halted || status == .accountProblem else { return }
        generation += 1
        let generation = generation
        retry.cancel(); retryAfter = nil; halted = true
        let previous = engine
        engine = nil
        await previous?.cancelOperations()
        await launchTask?.value
        await syncTask?.value
        guard !stopped, self.generation == generation else { return }
        halted = false
        // launch rechecks the original account binding before opening an engine.
        await launch()
    }

    func stop() async {
        stopped = true; generation += 1
        launchTask?.cancel(); syncTask?.cancel()
        retry.cancel(); retryAfter = nil
        let previous = engine; engine = nil
        await previous?.cancelOperations()
        await launchTask?.value
        await syncTask?.value
        status = .off
    }

    private func isCurrent(_ value: Int) -> Bool { value == generation && !stopped && !halted }

    private func enqueuePending(_ engine: CKSyncEngine, readding: Bool = false) {
        for key in bridge.state.pending where !blockedKeys.contains(key) && !pass.deferred.contains(key) {
            guard let record = bridge.state.records[key] else { continue }
            if readding { readd(record, engine: engine) }
            else { engine.state.add(pendingRecordZoneChanges: [.saveRecord(ClockinCloudRecord.id(record))]) }
        }
    }

    private func readd(_ record: SyncRecord, engine: CKSyncEngine) {
        guard bridge.state.permitsUpload, bridge.state.pending.contains(record.key),
              !blockedKeys.contains(record.key) else { return }
        guard pass.permitReadd(record.key) else {
            engine.state.remove(pendingRecordZoneChanges: [.saveRecord(ClockinCloudRecord.id(record))])
            report(.paused(.retryLimit)); passFailed = true
            return
        }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(ClockinCloudRecord.id(record))])
    }

    private struct BatchSource: SyncBatchSource {
        let adapter: ClockinCloudAdapter
        let engine: CKSyncEngine
        let context: CKSyncEngine.SendChangesContext
        var pendingIDs: [CKRecord.ID] {
            engine.state.pendingRecordZoneChanges.compactMap {
                if case .saveRecord(let id) = $0 { return id }
                return nil // This schema sends tombstones, never hard deletes.
            }
        }
        func contains(_ id: CKRecord.ID) -> Bool { id.zoneID == ClockinCloudRecord.zoneID && context.options.scope.contains(id) }
        func record(for id: CKRecord.ID) -> (CKRecord, bytes: Int)? {
            let key = id.recordName.contains(":") ? id.recordName : "Session:" + id.recordName
            guard !adapter.blockedKeys.contains(key), !adapter.pass.deferred.contains(key),
                  adapter.bridge.state.pending.contains(key),
                  let value = adapter.bridge.state.records[key] else { return nil }
            do {
                let record = try ClockinCloudRecord.encode(value, systemFields: adapter.bridge.state.systemFields[key])
                return (record, (record["payload"] as? Data)?.count ?? 0)
            } catch {
                syncLog.error("encode failed for \(key, privacy: .public): \(String(describing: error), privacy: .public)")
                adapter.pass.deferRecord(key)
                adapter.passFailed = true
                adapter.report(.paused(.invalidData))
                return nil
            }
        }
        func removeUnavailable(_ id: CKRecord.ID) {
            engine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                  syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard engine === syncEngine, !halted, !stopped, bridge.state.permitsUpload else { return nil }
        guard await bridge.persist() else {
            passFailed = true; report(.paused(.storage)); return nil
        }
        guard engine === syncEngine, !halted, !stopped else { return nil }
        let records = SyncBatchBuilder.build(BatchSource(adapter: self, engine: syncEngine, context: context))
        guard !records.isEmpty else { return nil }
        return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: records, atomicByZone: false)
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard engine === syncEngine, !halted, !stopped else { return }
        do {
            switch event {
            case .stateUpdate(let update):
                bridge.updateEngineState(try SyncCoding.encode(update.stateSerialization))
            case .accountChange(let change):
                switch change.changeType {
                case .signIn(let user) where bridge.state.accountID == user.recordName: break
                default:
                    halted = true; generation += 1; retry.cancel()
                    report(.accountProblem)
                    await syncEngine.cancelOperations()
                    return
                }
            case .fetchedRecordZoneChanges(let changes):
                var valid: [SyncRecord] = []
                for change in changes.modifications {
                    if let value = decodeOrQuarantine(change.record) { valid.append(value) }
                }
                let rejected = try bridge.receive(valid)
                for change in changes.modifications {
                    if let value = try? ClockinCloudRecord.decode(change.record) {
                        bridge.rememberSystemFields(ClockinCloudRecord.systemFields(change.record), for: value.key)
                    }
                }
                blockRejected(rejected)
                for deletion in changes.deletions {
                    bridge.quarantine(.init(recordKey: deletion.recordID.recordName, bytes: Data(),
                                            reason: "Unexpected server deletion; local value retained"))
                    if let value = bridge.state.records.values.first(where: { ClockinCloudRecord.id($0) == deletion.recordID }) {
                        blockedKeys.insert(value.key)
                    }
                    report(.paused(.invalidData)); passFailed = true
                }
            case .sentRecordZoneChanges(let changes):
                for record in changes.savedRecords {
                    let value = try ClockinCloudRecord.decode(record)
                    bridge.acknowledge(value, fields: ClockinCloudRecord.systemFields(record))
                }
                for failure in changes.failedRecordSaves {
                    let value = try? ClockinCloudRecord.decode(failure.record)
                    switch Self.failure(failure.error.code).action {
                    case .join:
                        if let server = failure.error.serverRecord, let remote = decodeOrQuarantine(server) {
                            bridge.rememberSystemFields(ClockinCloudRecord.systemFields(server), for: remote.key)
                            blockRejected(try bridge.receive([remote]))
                            if let joined = bridge.state.records[remote.key] { readd(joined, engine: syncEngine) }
                        } else { deferFailure(value, id: failure.record.recordID, engine: syncEngine) }
                    case .clearFields:
                        if let value {
                            bridge.clearSystemFields(for: value.key)
                            readd(value, engine: syncEngine)
                        } else { deferFailure(nil, id: failure.record.recordID, engine: syncEngine) }
                    case .rebuildZone: recoverZone(syncEngine)
                    case .engineRetry:
                        // CKSyncEngine owns these retries. Never remove or re-add here.
                        handle(failure.error)
                    case .deferToNextPass:
                        deferFailure(value, id: failure.record.recordID, engine: syncEngine)
                        handle(failure.error)
                    }
                }
            case .fetchedDatabaseChanges(let changes):
                if changes.deletions.contains(where: { $0.zoneID == ClockinCloudRecord.zoneID }) { recoverZone(syncEngine) }
            case .sentDatabaseChanges(let changes):
                for failure in changes.failedZoneSaves { handle(failure.error) }
            case .didFetchRecordZoneChanges(let result):
                if let error = result.error {
                    if error.code == .zoneNotFound { recoverZone(syncEngine) }
                    else { fetchFailed = true; handle(error) }
                }
            default: break
            }
            if !(await bridge.persist()) { passFailed = true; report(.paused(.storage)) }
            didChange?()
        } catch {
            // Never checkpoint a cursor past an unapplied primary write.
            halted = true; generation += 1; retry.cancel()
            report(.paused(.invalidData))
            await syncEngine.cancelOperations()
        }
    }

    private func deferFailure(_ value: SyncRecord?, id: CKRecord.ID, engine: CKSyncEngine) {
        if let value { pass.deferRecord(value.key) }
        engine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
        passFailed = true
        report(.paused(.sendFailed))
    }

    private func decodeOrQuarantine(_ record: CKRecord) -> SyncRecord? {
        // Another device may still carry a preference that is now device-local.
        // It is not bad data; ignore it instead of raising a quarantine notice.
        let name = record.recordID.recordName
        if name.hasPrefix("Preference:"), SyncPreferences.deviceKeys.contains(String(name.dropFirst("Preference:".count))) {
            return nil
        }
        do { return try ClockinCloudRecord.decode(record) }
        catch {
            let bytes = (record["payload"] as? Data) ?? ClockinCloudRecord.systemFields(record)
            bridge.quarantine(.init(recordKey: record.recordID.recordName, bytes: bytes,
                                    reason: String(describing: error), futureCatalog: error as? SyncFailure == .unknownCatalog))
            if let local = bridge.state.records.values.first(where: { ClockinCloudRecord.id($0) == record.recordID }) {
                blockedKeys.insert(local.key)
            }
            report(.paused(.invalidData)); passFailed = true
            return nil
        }
    }

    private func blockRejected(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        blockedKeys.formUnion(keys)
        // A restarted adapter must not use a rejected envelope's change tag to overwrite it.
        // With no system fields, a later save is a conditional create and refetches the conflict.
        for key in keys { bridge.clearSystemFields(for: key) }
        report(.paused(.invalidData)); passFailed = true
    }

    private func recoverZone(_ engine: CKSyncEngine) {
        bridge.resetTransport()
        // Record re-add caps also bound zone recreation in this pass.
        guard pass.permitReadd("zone:Clockin") else {
            report(.paused(.retryLimit)); passFailed = true; return
        }
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClockinCloudRecord.zoneID))])
        enqueuePending(engine, readding: true)
    }

    static func accountState(_ status: CKAccountStatus) -> SyncAccountState {
        switch status {
        case .available: .available
        case .noAccount, .restricted: .absent
        case .couldNotDetermine, .temporarilyUnavailable: .temporary
        @unknown default: .temporary
        }
    }

    static func failure(_ code: CKError.Code) -> SyncSendFailure {
        switch code {
        case .serverRecordChanged: .serverRecordChanged
        case .unknownItem: .unknownItem
        case .zoneNotFound: .zoneNotFound
        case .networkFailure: .networkFailure
        case .networkUnavailable: .networkUnavailable
        case .zoneBusy: .zoneBusy
        case .serviceUnavailable: .serviceUnavailable
        case .requestRateLimited: .requestRateLimited
        case .notAuthenticated: .notAuthenticated
        case .operationCancelled: .operationCancelled
        default: .other
        }
    }

    private func handle(_ error: any Error) {
        passFailed = true
        syncLog.error("send error: \(String(describing: error), privacy: .public)")
        guard let cloud = error as? CKError else { report(.paused(.sendFailed)); return }
        switch cloud.code {
        case .quotaExceeded:
            report(.paused(.quota)); delayRetry(max(60, cloud.retryAfterSeconds ?? 60))
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            report(.waitingForNetwork); delayRetry(max(5, cloud.retryAfterSeconds ?? 5))
        case .notAuthenticated:
            // This send error is retryable by the engine. An account-change event is authoritative.
            report(.accountProblem); delayRetry(max(30, cloud.retryAfterSeconds ?? 30))
        case .operationCancelled: report(.paused(.sendFailed))
        default:
            report(.paused(.sendFailed))
            if let delay = cloud.retryAfterSeconds { delayRetry(max(5, delay)) }
        }
    }

    private func report(_ value: SyncStatus) {
        syncLog.notice("status: \(String(describing: value), privacy: .public)")
        status = value; bridge.report(value.message)
    }
    private func retryLaunch(minimum: TimeInterval = 0) {
        report(.waitingForNetwork)
        delayRetry(launchBackoff.nextDelay(minimum: minimum))
    }
    private func delayRetry(_ delay: TimeInterval) {
        let date = clock.now.addingTimeInterval(delay)
        retryAfter = max(retryAfter ?? date, date)
        scheduleRetry()
    }
    private func scheduleRetry() {
        guard !stopped, !halted, let date = retryAfter else { return }
        retry.schedule(at: date) { [weak self] in
            guard let self, !self.stopped, !self.halted else { return }
            await self.synchronize()
        }
    }
}
