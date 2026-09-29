import CloudKit
import Foundation

@available(iOS 17.0, macOS 14.0, *)
enum ClockinCloudRecord {
    static let containerID = "iCloud.com.erdmncdr.clockin"
    static let zoneID = CKRecordZone.ID(zoneName: "Clockin", ownerName: CKCurrentUserDefaultName)
    static let maximumPayloadBytes = 750_000

    static func id(_ record: SyncRecord) -> CKRecord.ID {
        // UUID session names remain compatible with the proposed schema; all others are namespaced.
        CKRecord.ID(recordName: record.kind == .session ? record.name : record.key, zoneID: zoneID)
    }

    static func decode(_ record: CKRecord) throws -> SyncRecord {
        guard record.recordID.zoneID == zoneID,
              let bytes = record["payload"] as? Data, bytes.count <= maximumPayloadBytes,
              let schema = record["schema"] as? Int64, schema == 1 else {
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
            throw SyncFailure.invalid("Record history exceeds the upload limit; export and migrate history before syncing this record")
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
        record["schema"] = Int64(1) as CKRecordValue
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
final class ClockinCloudAdapter: CKSyncEngineDelegate {
    private let bridge: SyncBridge
    private let container: CKContainer
    private var engine: CKSyncEngine?
    private var synchronizing = false
    private var halted = false
    private var fetchFailed = false
    private var retryAfter: Date?
    private var blockedKeys = Set<String>()

    init(bridge: SyncBridge) {
        self.bridge = bridge
        container = CKContainer(identifier: ClockinCloudRecord.containerID)
    }

    // No engine or account access happens until the application explicitly calls launch.
    func launch() async throws {
        guard engine == nil, !halted else { return }
        let account = try await container.userRecordID().recordName
        if let previous = bridge.state.accountID, previous != account {
            halted = true
            bridge.report("iCloud account changed. Keep this archive and sidecar for the original account; choose an account migration explicitly.")
            throw SyncFailure.accountChanged
        }
        bridge.setAccount(account)
        try bridge.reconcileLocalArchive()
        let serialized = try bridge.state.engineState.map { try SyncCoding.decode(CKSyncEngine.State.Serialization.self, $0) }
        guard await bridge.persist() else { return }
        var config = CKSyncEngine.Configuration(database: container.privateCloudDatabase,
                                                stateSerialization: serialized, delegate: self)
        // Explicit scheduling enforces the account, first-merge, and disk durability gates.
        config.automaticallySync = false
        let engine = CKSyncEngine(config)
        self.engine = engine
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClockinCloudRecord.zoneID))])
        await synchronize()
    }

    // Call on foreground, after local saves/preferences/wardrobe changes, and on remote notification.
    func synchronize() async {
        guard let engine, !halted, !synchronizing, retryAfter.map({ $0 <= .now }) ?? true else { return }
        synchronizing = true
        defer { synchronizing = false }
        do {
            fetchFailed = false
            bridge.markFetchComplete(false)
            do { try await engine.fetchChanges(.init(scope: .zoneIDs([ClockinCloudRecord.zoneID]))) }
            catch let error as CKError where error.code == .zoneNotFound { recoverZone(engine) }
            guard !halted, !fetchFailed else { return }
            bridge.markFetchComplete(true)
            bridge.allowInitialUploadIfSafe()
            guard bridge.state.permitsUpload, await bridge.persist(), !halted else { return }
            enqueuePending(engine)
            try await engine.sendChanges(.init(scope: .zoneIDs([ClockinCloudRecord.zoneID])))
        } catch { handle(error) }
    }

    private func enqueuePending(_ engine: CKSyncEngine) {
        let records = bridge.state.pending.compactMap { bridge.state.records[$0] }
            .filter { !blockedKeys.contains($0.key) }
        engine.state.add(pendingRecordZoneChanges: records.map { .saveRecord(ClockinCloudRecord.id($0)) })
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                  syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard !halted, bridge.state.permitsUpload, await bridge.persist(), !halted else { return nil }
        var records: [CKRecord] = []
        var bytes = 0
        for key in bridge.state.pending where !blockedKeys.contains(key) {
            guard let value = bridge.state.records[key], context.options.scope.contains(ClockinCloudRecord.id(value)) else { continue }
            do {
                let record = try ClockinCloudRecord.encode(value, systemFields: bridge.state.systemFields[key])
                let count = (record["payload"] as? Data)?.count ?? 0
                if records.count >= 100 || bytes + count > 1_500_000 { break }
                records.append(record); bytes += count
            } catch { blockedKeys.insert(key); bridge.report(String(describing: error)) }
        }
        guard !records.isEmpty else { return nil }
        return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: records, atomicByZone: false)
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard !halted else { return }
        do {
            switch event {
            case .stateUpdate(let update):
                bridge.updateEngineState(try SyncCoding.encode(update.stateSerialization))
            case .accountChange(let change):
                switch change.changeType {
                case .signIn(let user) where bridge.state.accountID == user.recordName: break
                default:
                    // Never publish the previous account's history into a new private database.
                    halted = true
                    bridge.report("iCloud account changed or signed out. Sync is paused; local data and the account-bound sidecar are retained.")
                    await syncEngine.cancelOperations()
                    return
                }
            case .fetchedRecordZoneChanges(let changes):
                var valid: [SyncRecord] = []
                for change in changes.modifications {
                    if let value = decodeOrQuarantine(change.record) {
                        valid.append(value)
                        bridge.rememberSystemFields(ClockinCloudRecord.systemFields(change.record), for: value.key)
                    }
                }
                try bridge.receive(valid)
                blockRejected(valid)
                for deletion in changes.deletions {
                    // Supported deletions are saved tombstones, never hard deletes.
                    bridge.quarantine(.init(recordKey: deletion.recordID.recordName, bytes: Data(),
                                            reason: "Unexpected server deletion; local value retained"))
                    if let value = bridge.state.records.values.first(where: { ClockinCloudRecord.id($0) == deletion.recordID }) {
                        blockedKeys.insert(value.key)
                    }
                    bridge.report("A record was deleted outside Clockin sync. Local data is retained for recovery.")
                }
            case .sentRecordZoneChanges(let changes):
                for record in changes.savedRecords {
                    let value = try ClockinCloudRecord.decode(record)
                    bridge.acknowledge(value, fields: ClockinCloudRecord.systemFields(record))
                }
                for failure in changes.failedRecordSaves {
                    let value = try? ClockinCloudRecord.decode(failure.record)
                    if failure.error.code == .serverRecordChanged,
                       let server = failure.error.serverRecord, let remote = decodeOrQuarantine(server) {
                        bridge.rememberSystemFields(ClockinCloudRecord.systemFields(server), for: remote.key)
                        try bridge.receive([remote])
                        blockRejected([remote])
                    } else if failure.error.code == .unknownItem, let value {
                        bridge.clearSystemFields(for: value.key)
                    } else { handle(failure.error) }
                }
                enqueuePending(syncEngine)
            case .fetchedDatabaseChanges(let changes):
                if changes.deletions.contains(where: { $0.zoneID == ClockinCloudRecord.zoneID }) {
                    recoverZone(syncEngine)
                }
            case .sentDatabaseChanges(let changes):
                for failure in changes.failedZoneSaves { handle(failure.error) }
            case .didFetchRecordZoneChanges(let result):
                if let error = result.error {
                    if error.code == .zoneNotFound { recoverZone(syncEngine) }
                    else { fetchFailed = true; handle(error) }
                }
            default: break
            }
            _ = await bridge.persist()
        } catch {
            // Do not persist a fetch cursor after an unapplied change. Relaunch refetches.
            halted = true
            bridge.report("Sync paused after an apply/validation failure: \(error). The archive is retained.")
            await syncEngine.cancelOperations()
        }
    }

    private func decodeOrQuarantine(_ record: CKRecord) -> SyncRecord? {
        do { return try ClockinCloudRecord.decode(record) }
        catch {
            let bytes = (record["payload"] as? Data) ?? ClockinCloudRecord.systemFields(record)
            bridge.quarantine(.init(recordKey: record.recordID.recordName, bytes: bytes, reason: String(describing: error)))
            if let local = bridge.state.records.values.first(where: { ClockinCloudRecord.id($0) == record.recordID }) {
                blockedKeys.insert(local.key)
            }
            bridge.report("An invalid iCloud record was quarantined. It has not been applied, overwritten, or deleted.")
            return nil
        }
    }

    private func blockRejected(_ records: [SyncRecord]) {
        for record in records {
            let bytes = try? SyncCoding.encode(record)
            if bridge.state.quarantine.contains(where: { $0.recordKey == record.key && $0.bytes == bytes }) {
                blockedKeys.insert(record.key)
                bridge.report("A conflicting revision identity was quarantined. The server record is retained for review.")
            }
        }
    }

    private func recoverZone(_ engine: CKSyncEngine) {
        bridge.resetTransport()
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: ClockinCloudRecord.zoneID))])
        enqueuePending(engine)
        bridge.report("The Clockin zone is missing. Retained records will rebuild it after first-merge approval.")
    }

    private func handle(_ error: any Error) {
        guard let cloud = error as? CKError else { bridge.report(String(describing: error)); return }
        if let delay = cloud.retryAfterSeconds { retryAfter = Date().addingTimeInterval(delay) }
        switch cloud.code {
        case .zoneNotFound:
            if let engine { recoverZone(engine) }
        case .unknownItem:
            bridge.report("An iCloud record is missing. Its retained local value will be retried.")
        case .quotaExceeded:
            retryAfter = .now.addingTimeInterval(max(60, cloud.retryAfterSeconds ?? 60))
            bridge.report("iCloud storage is full. Pending changes remain on this device.")
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            retryAfter = .now.addingTimeInterval(max(5, cloud.retryAfterSeconds ?? 5))
            bridge.report("iCloud is temporarily unavailable. Pending changes will retry on the next sync trigger.")
        case .notAuthenticated:
            halted = true
            bridge.report("Sign in to the original iCloud account, then reopen Clockin to resume sync.")
        default:
            bridge.report("iCloud sync error \(cloud.code.rawValue): \(cloud.localizedDescription). Pending changes are retained.")
        }
    }
}
