import Foundation

struct SyncSidecar: Codable, Sendable {
    var schema = 2
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
    var hasForeignStaged = false
    var needsFirstMergeReview: Bool { !firstMergeCompleted && hasForeignStaged }
    var permitsUpload: Bool { firstMergeCompleted || (initialUploadAllowed && !needsFirstMergeReview) }
    var staged: [String: SyncRecord] = [:]
    var quarantine: [SyncQuarantine] = []
    var recoveryInbox: [SyncRecovery] = []
    var localIssues: [SyncLocalIssue] = []
    var recoveryOverflow = false
    var quarantineOverflow = false
    // Acknowledgments exist only for the two active overflow episodes.
    var acknowledgedNotices: [String] = []
    var firstBackupPath: String?

    init(deviceID: String = UUID().uuidString) { self.deviceID = deviceID }

    mutating func touch() { revision += 1 }

    mutating func queue(_ changes: [SyncRecord]) {
        for record in changes { records[record.key] = record.pruned() }
        pending = Set(pending + changes.map(\.key)).subtracting(localIssues.map(\.recordKey)).sorted()
        touch()
    }

    mutating func capture(previous: SyncSnapshot?, current: SyncSnapshot, at date: Date) throws {
        guard SessionDuration.isValidDate(date) else { throw SyncFailure.invalid("Invalid local clock") }
        let last = records.values.map(\.maximumStamp.modifiedAt).max() ?? .distantPast
        let stampDate = date > last ? date : Date(timeIntervalSinceReferenceDate: last.timeIntervalSinceReferenceDate.nextUp)
        let stamp = SyncStamp(modifiedAt: stampDate, modifiedBy: deviceID, sequence: sequence + 1)
        var issues: [SyncLocalIssue] = []
        let changes = try SyncCore.diff(previous: previous, current: current, known: records, stamp: stamp,
                                        onInvalid: { issues.append(.init(recordKey: String($0.prefix(256)))) })
        let changedIssues = issues != localIssues
        localIssues = Array(Set(issues.map(\.recordKey))).sorted().map { .init(recordKey: $0) }
        pending.removeAll { key in issues.contains { $0.recordKey == key } }
        guard !changes.isEmpty else { if changedIssues { touch() }; return }
        let before = records
        sequence += 1
        queue(changes)
        if let previous {
            addRecoveries(try SyncCore.displaced(local: before, merged: records, before: previous, after: current, deviceID: deviceID, includeReplacements: false))
        }
        // A local edit can itself lose to a known permanent deletion or an earlier purchase.
        // Capture its authored payload even though it never entered the retained top K.
        let displacedEdits = changes.filter { $0.winner?.id != "\(stamp.modifiedBy):\(stamp.sequence)" }
        if !displacedEdits.isEmpty {
            let values = try SyncCore.payloads(current, onInvalid: { _ in })
            for record in displacedEdits {
                guard let value = values[record.key]?.winner, value.payload != record.winner?.payload else { continue }
                let version = SyncVersion(stamp: stamp, payload: value.payload,
                                          parents: before[record.key]?.versions.map(\.id).sorted() ?? [],
                                          observed: before[record.key]?.maximumStamp)
                addRecoveries([.init(recordKey: record.key, version: version, reason: "Replaced value")])
            }
        }

    }

    mutating func receive(_ incoming: [SyncRecord], snapshot: SyncSnapshot,
                          onReject: (([String]) -> Void)? = nil) throws -> SyncMerge? {
        if !firstMergeCompleted {
            let merged = try SyncCore.merge(local: staged, incoming: incoming, onto: snapshot)
            onReject?(merged.quarantine.map(\.recordKey))
            staged = merged.records
            if incoming.contains(where: { record in
                (try? SyncCore.validate(record)) != nil && record.versions.contains { $0.stamp.modifiedBy != deviceID }
            }) { hasForeignStaged = true }
            for record in incoming where records[record.key] == record { pending.removeAll { $0 == record.key } }
            addQuarantine(merged.quarantine)
            touch()
            return nil
        }
        var merge = try SyncCore.merge(local: records, incoming: incoming, onto: snapshot, deviceID: deviceID)
        onReject?(merge.quarantine.map(\.recordKey))
        merge.snapshot = preservingLocalOnly(merge.snapshot, from: snapshot)
        merge.recoveries.removeAll { entry in localIssues.contains { $0.recordKey == entry.recordKey } }
        addRecoveries(merge.recoveries)
        records = merge.records
        // Fetching our exact pending value also acknowledges a save whose response was lost.
        for record in incoming where records[record.key] == record { pending.removeAll { $0 == record.key } }
        pending = Set(pending + merge.resend.map(\.key)).subtracting(localIssues.map(\.recordKey)).sorted()
        addQuarantine(merge.quarantine)
        touch()
        merge.recoveries = recoveryInbox; merge.notices = activeNotices
        return merge
    }

    func preview(snapshot: SyncSnapshot) throws -> SyncFirstPreview {
        var preview = try SyncCore.firstPreview(local: records, incoming: Array(staged.values), snapshot: snapshot, revision: revision, deviceID: deviceID)
        preview.merge.snapshot = preservingLocalOnly(preview.merge.snapshot, from: snapshot)
        preview.mergedCount = preview.merge.snapshot.data.sessions.count
        preview.duplicates = max(0, preview.localCount + preview.remoteCount - preview.mergedCount)
        preview.merge.recoveries.removeAll { entry in localIssues.contains { $0.recordKey == entry.recordKey } }
        preview.merge.notices = preview.merge.recoveries.map(\.notice)
        return preview
    }

    mutating func commit(_ preview: SyncFirstPreview, backup: SyncBackupReceipt) throws {
        guard preview.revision == revision && backup.revision == revision else { throw SyncFailure.stalePreview }
        guard !firstMergeCompleted else { throw SyncFailure.stalePreview }
        records = preview.merge.records
        // Only send records which the fetched server does not already contain.
        pending = records.keys.filter { key in records[key] != staged[key] && !localIssues.contains { $0.recordKey == key } }.sorted()
        addQuarantine(preview.merge.quarantine)
        addRecoveries(Self.worthKeeping(preview.merge.recoveries, merged: preview.merge.snapshot))
        staged = [:]; hasForeignStaged = false; firstMergeCompleted = true; firstBackupPath = backup.url.path
        touch()
    }

    mutating func acknowledge(_ record: SyncRecord, systemFields fields: Data) {
        rememberSystemFields(fields, for: record.key)
        if records[record.key] == record { pending.removeAll { $0 == record.key } }
        touch()
    }

    /// The user approved "entries recorded on both devices are kept once" in the preview.
    /// An alias identical to the entry that was kept tells them nothing new; one whose
    /// note, rate or source differs is still worth a look. The first merge of 585 shared
    /// entries otherwise filled the 50-entry inbox and evicted everything else.
    static func worthKeeping(_ entries: [SyncRecovery], merged: SyncSnapshot) -> [SyncRecovery] {
        var kept: [String: WorkSession] = [:]
        for session in merged.data.sessions { kept[SyncCore.importKey(session)] = session }
        return entries.filter { entry in
            guard entry.reason == "Import-key duplicate",
                  let alias = try? SyncCoding.decode(WorkSession.self, entry.version.payload),
                  let survivor = kept[SyncCore.importKey(alias)] else { return true }
            return alias.note != survivor.note || alias.hourlyRate != survivor.hourlyRate
                || alias.source != survivor.source || alias.matchedExternalSource != survivor.matchedExternalSource
        }
    }

    /// Clears everything the user has seen at once.
    mutating func acknowledgeAllRecoveries() {
        recoveryInbox.removeAll()
        recoveryOverflow = false
        cleanAcknowledgments()
        touch()
    }

    mutating func addRecoveries(_ entries: [SyncRecovery]) {
        for var entry in entries where !recoveryInbox.contains(where: { $0.id == entry.id }) {
            if entry.recoveredAt == nil { entry.recoveredAt = .now }
            recoveryInbox.append(entry)
            while recoveryInbox.count > SyncBounds.recoveryCount || SyncBounds.size(recoveryInbox) > SyncBounds.recoveryBytes {
                recoveryInbox.removeFirst(); recoveryOverflow = true
            }
        }
        cleanAcknowledgments()
    }

    mutating func addQuarantine(_ entries: [SyncQuarantine]) {
        for var entry in entries {
            // Diagnostic metadata is bounded too; payload bytes are either retained whole or evicted whole.
            entry.recordKey = String(decoding: entry.recordKey.utf8.prefix(256), as: UTF8.self)
            entry.reason = String(decoding: entry.reason.utf8.prefix(512), as: UTF8.self)
            guard !quarantine.contains(entry) else { continue }
            quarantine.append(entry)
            // Reserve at most sixteen opaque future-catalog envelopes, within the overall budget.
            while quarantine.filter(\.futureCatalog).count > SyncBounds.futureCatalogCount {
                if let index = quarantine.firstIndex(where: \.futureCatalog) { quarantine.remove(at: index) }
                quarantineOverflow = true
            }
            while quarantine.count > SyncBounds.quarantineCount || SyncBounds.size(quarantine) > SyncBounds.quarantineBytes {
                quarantine.removeFirst(); quarantineOverflow = true
            }
        }
        cleanAcknowledgments()
    }

    var activeNotices: [SyncNotice] {
        var result = recoveryInbox.map(\.notice)
        if recoveryOverflow { result.append(.init(id: "recovery-overflow", message: String(localized: "Recovery inbox full. Oldest entries were removed.", bundle: .app))) }
        if quarantineOverflow { result.append(.init(id: "quarantine-overflow", message: String(localized: "Quarantine full. Oldest entries were removed.", bundle: .app))) }
        return result.filter { !acknowledgedNotices.contains($0.id) }
    }

    func notices(_ merge: SyncMerge) -> [SyncNotice] { activeNotices }

    mutating func acknowledgeNotices(_ ids: [String]) {
        recoveryInbox.removeAll { ids.contains($0.id) }
        for id in ids where id == "recovery-overflow" || id == "quarantine-overflow" {
            if !acknowledgedNotices.contains(id) { acknowledgedNotices.append(id) }
        }
        // An episode ends only after acknowledgment AND explicit review creates capacity.
        if ids.contains("recovery-overflow") && recoveryInbox.isEmpty { recoveryOverflow = false }
        if ids.contains("quarantine-overflow") && quarantine.isEmpty { quarantineOverflow = false }
        cleanAcknowledgments(); touch()
    }

    mutating func removeQuarantine(at index: Int) {
        guard quarantine.indices.contains(index) else { return }
        quarantine.remove(at: index)
        if quarantine.isEmpty && acknowledgedNotices.contains("quarantine-overflow") { quarantineOverflow = false }
        cleanAcknowledgments(); touch()
    }

    private mutating func cleanAcknowledgments() {
        if recoveryInbox.isEmpty && acknowledgedNotices.contains("recovery-overflow") { recoveryOverflow = false }
        acknowledgedNotices = acknowledgedNotices.filter {
            ($0 == "recovery-overflow" && recoveryOverflow) || ($0 == "quarantine-overflow" && quarantineOverflow)
        }.sorted()
    }

    func preservingLocalOnly(_ projected: SyncSnapshot, from local: SyncSnapshot) -> SyncSnapshot {
        var result = projected
        let keys = Set(localIssues.map(\.recordKey))
        result.data.sessions.removeAll { keys.contains("Session:" + $0.id.uuidString) }
        result.data.sessions += local.data.sessions.filter { keys.contains("Session:" + $0.id.uuidString) }
        if keys.contains("Profile:Profile") { result.data.hourlyRate = local.data.hourlyRate; result.data.currencyCode = local.data.currencyCode }
        if keys.contains("Running:Running") { result.data.running = local.data.running }
        if keys.contains("WardrobeState:WardrobeState") { result.wardrobe = local.wardrobe }
        for key in keys where key.hasPrefix("Preference:") {
            let name = String(key.dropFirst("Preference:".count)); result.preferences[name] = local.preferences[name]
        }
        result.data.rateRules = (result.data.rateRules ?? []).filter { !keys.contains("RateRule:" + $0.id.uuidString) }
            + (local.data.rateRules ?? []).filter { keys.contains("RateRule:" + $0.id.uuidString) }
        func localPurchase(_ value: WardrobePurchase) -> Bool {
            keys.contains(String(("WardrobePurchase:" + SyncCore.purchaseName(value.itemID)).prefix(256)))
        }
        result.ledger = result.ledger.filter { !localPurchase($0) } + local.ledger.filter(localPurchase)
        return result
    }

    mutating func rememberSystemFields(_ fields: Data, for key: String) {
        guard records[key] != nil || staged[key] != nil, fields.count <= SyncBounds.systemFieldBytes else {
            systemFields[key] = nil; return // Safe refetch/conditional-create fallback.
        }
        systemFields[key] = fields
    }

    // Conservative serialized bound; identity growth is explicit, not a history leak.
    var byteBound: Int {
        let registerBytes = (Array(records.values) + Array(staged.values)).reduce(0) { $0 + $1.kind.envelopeBound + 256 }
        let identities = Set(records.keys).union(staged.keys).union(localIssues.map(\.recordKey)).count
        return 16 * 1024 + SyncBounds.base64(SyncBounds.engineBytes)
            + registerBytes + identities * (SyncBounds.base64(SyncBounds.systemFieldBytes) + 2048)
            + SyncBounds.recoveryBytes + SyncBounds.quarantineBytes
    }

    func validateLocalBounds(byteCount: Int) throws {
        let known = Set(records.keys).union(staged.keys)
        guard SyncBounds.identifier(deviceID), (accountID?.utf8.count ?? 0) <= 1024,
              (firstBackupPath?.utf8.count ?? 0) <= 1024,
              recoveryInbox.count <= SyncBounds.recoveryCount,
              SyncBounds.size(recoveryInbox) <= SyncBounds.recoveryBytes,
              Set(recoveryInbox.map(\.id)).count == recoveryInbox.count,
              quarantine.count <= SyncBounds.quarantineCount,
              quarantine.filter(\.futureCatalog).count <= SyncBounds.futureCatalogCount,
              SyncBounds.size(quarantine) <= SyncBounds.quarantineBytes,
              (engineState?.count ?? 0) <= SyncBounds.engineBytes,
              systemFields.values.allSatisfy({ $0.count <= SyncBounds.systemFieldBytes }),
              Set(systemFields.keys).isSubset(of: known),
              pending == Set(pending).sorted(), Set(pending).isSubset(of: Set(records.keys)),
              localIssues.allSatisfy({ $0.recordKey.utf8.count <= 256 }),
              Set(localIssues.map(\.recordKey)).count == localIssues.count,
              Set(pending).isDisjoint(with: localIssues.map(\.recordKey)),
              acknowledgedNotices == Set(acknowledgedNotices).sorted(),
              acknowledgedNotices.allSatisfy({ ($0 == "recovery-overflow" && recoveryOverflow)
                  || ($0 == "quarantine-overflow" && quarantineOverflow) }),
              byteCount <= byteBound else { throw SyncFailure.invalid("Sidecar limits exceeded") }
    }

    // Account transitions halt the adapter. This state is retained for the original account.
    mutating func resetTransport() {
        engineState = nil; systemFields = [:]
        pending = records.keys.filter { key in !localIssues.contains { $0.recordKey == key } }.sorted(); touch()
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
        guard state.schema == 2 else { throw SyncFailure.unsupportedVersion }
        guard SyncBounds.identifier(state.deviceID) else { throw SyncFailure.invalid("Missing device identity") }
        for (key, record) in [state.records, state.staged].flatMap({ $0 }) {
            guard key == record.key else { throw SyncFailure.invalid("Sidecar key mismatch") }
            try SyncCore.validate(record)
        }
        try state.validateLocalBounds(byteCount: SyncBounds.size(state))
        writtenRevision = state.revision
        return state
    }

    func save(_ state: SyncSidecar) throws {
        if let writtenRevision, state.revision < writtenRevision { return }
        let bytes = try SyncCoding.encode(state)
        try state.validateLocalBounds(byteCount: bytes.count)
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
