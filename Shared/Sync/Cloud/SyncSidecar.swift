import Foundation

struct SyncSidecar: Codable, Sendable {
    var schema = 1
    var deviceID: String
    var sequence: UInt64 = 0
    var revision: UInt64 = 0
    var records: [String: SyncRecord] = [:]
    var pending: [String] = []
    var systemFields: [String: Data] = [:]
    var engineState: Data?
    var accountID: String?
    var firstMergeCompleted = false
    var initialUploadAllowed = false
    var needsFirstMergeReview: Bool {
        !firstMergeCompleted && staged.values.contains { record in
            record.versions.contains { $0.stamp.modifiedBy != deviceID }
        }
    }
    var permitsUpload: Bool { firstMergeCompleted || (initialUploadAllowed && !needsFirstMergeReview) }
    var staged: [String: SyncRecord] = [:]
    var quarantine: [SyncQuarantine] = []
    var acknowledgedNotices: [String] = []
    var firstBackupPath: String?

    init(deviceID: String = UUID().uuidString) { self.deviceID = deviceID }

    mutating func touch() { revision += 1 }

    mutating func queue(_ changes: [SyncRecord]) {
        for record in changes { records[record.key] = record }
        pending = Set(pending + changes.map(\.key)).sorted()
        touch()
    }

    mutating func capture(previous: SyncSnapshot?, current: SyncSnapshot, at date: Date) throws {
        guard SessionDuration.isValidDate(date) else { throw SyncFailure.invalid("Invalid local clock") }
        let last = records.values.flatMap(\.versions).map(\.stamp.modifiedAt).max() ?? .distantPast
        let stampDate = date > last ? date : Date(timeIntervalSinceReferenceDate: last.timeIntervalSinceReferenceDate.nextUp)
        let stamp = SyncStamp(modifiedAt: stampDate, modifiedBy: deviceID, sequence: sequence + 1)
        let changes = try SyncCore.diff(previous: previous, current: current, known: records, stamp: stamp)
        guard !changes.isEmpty else { return }
        sequence += 1
        queue(changes)
    }

    mutating func receive(_ incoming: [SyncRecord], snapshot: SyncSnapshot) throws -> SyncMerge? {
        if !firstMergeCompleted {
            let merged = try SyncCore.merge(local: staged, incoming: incoming, onto: snapshot)
            staged = merged.records
            for record in incoming where records[record.key] == record { pending.removeAll { $0 == record.key } }
            addQuarantine(merged.quarantine)
            touch()
            return nil
        }
        let merge = try SyncCore.merge(local: records, incoming: incoming, onto: snapshot)
        records = merge.records
        // Fetching our exact pending value also acknowledges a save whose response was lost.
        for record in incoming where records[record.key] == record { pending.removeAll { $0 == record.key } }
        pending = Set(pending + merge.resend.map(\.key)).sorted()
        addQuarantine(merge.quarantine)
        touch()
        return merge
    }

    func preview(snapshot: SyncSnapshot) throws -> SyncFirstPreview {
        try SyncCore.firstPreview(local: records, incoming: Array(staged.values), snapshot: snapshot, revision: revision)
    }

    mutating func commit(_ preview: SyncFirstPreview, backup: SyncBackupReceipt) throws {
        guard preview.revision == revision && backup.revision == revision else { throw SyncFailure.stalePreview }
        guard !firstMergeCompleted else { throw SyncFailure.stalePreview }
        records = preview.merge.records
        // Only send records which the fetched server does not already contain.
        pending = records.keys.filter { records[$0] != staged[$0] }.sorted()
        addQuarantine(preview.merge.quarantine)
        staged = [:]; firstMergeCompleted = true; firstBackupPath = backup.url.path
        touch()
    }

    mutating func acknowledge(_ record: SyncRecord, systemFields fields: Data) {
        systemFields[record.key] = fields
        if records[record.key] == record { pending.removeAll { $0 == record.key } }
        touch()
    }

    mutating func addQuarantine(_ entries: [SyncQuarantine]) {
        for entry in entries where !quarantine.contains(entry) { quarantine.append(entry) }
    }

    func notices(_ merge: SyncMerge) -> [SyncNotice] {
        merge.notices.filter { !acknowledgedNotices.contains($0.id) }
    }

    mutating func acknowledgeNotices(_ ids: [String]) {
        acknowledgedNotices = Set(acknowledgedNotices + ids).sorted(); touch()
    }

    // Account transitions halt the adapter. This state is retained for the original account.
    mutating func resetTransport() {
        engineState = nil; systemFields = [:]
        pending = records.keys.sorted(); touch()
    }
}

struct SyncBackupReceipt: Sendable {
    let url: URL
    let revision: UInt64
    fileprivate init(url: URL, revision: UInt64) { self.url = url; self.revision = revision }
}

// No primary-archive writes. All file work runs off the main actor.
actor SyncSidecarStore {
    let url: URL
    private var writtenRevision: UInt64?

    init(archiveURL: URL) { url = archiveURL.deletingLastPathComponent().appendingPathComponent("sync-state.json") }

    func load() throws -> SyncSidecar? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let state = try SyncCoding.decode(SyncSidecar.self, Data(contentsOf: url))
        guard state.schema == 1 else { throw SyncFailure.unsupportedVersion }
        guard !state.deviceID.isEmpty else { throw SyncFailure.invalid("Missing device identity") }
        for (key, record) in [state.records, state.staged].flatMap({ $0 }) {
            guard key == record.key else { throw SyncFailure.invalid("Sidecar key mismatch") }
            try SyncCore.validate(record)
        }
        writtenRevision = state.revision
        return state
    }

    func save(_ state: SyncSidecar) throws {
        if let writtenRevision, state.revision < writtenRevision { return }
        let bytes = try SyncCoding.encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        writtenRevision = state.revision
    }

    func backup(archiveURL: URL, revision: UInt64) throws -> SyncBackupReceipt {
        let bytes = try Data(contentsOf: archiveURL)
        _ = try ClockinArchive.read(bytes)
        let destination = archiveURL.deletingLastPathComponent()
            .appendingPathComponent("clockin-before-sync-\(UUID().uuidString).json")
        try bytes.write(to: destination, options: .withoutOverwriting)
        guard try Data(contentsOf: destination) == bytes else { throw SyncFailure.backupRequired }
        return SyncBackupReceipt(url: destination, revision: revision)
    }
}
