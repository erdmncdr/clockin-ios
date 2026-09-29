import Foundation

enum SyncCore {
    static func importKey(_ session: WorkSession) -> String {
        "\(Int(session.start.timeIntervalSince1970))|\(Int(session.end.timeIntervalSince1970))|\(Int(session.duration))"
    }

    static func purchaseName(_ itemID: String) -> String {
        Data(itemID.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "=", with: "")
    }

    static func payloads(_ snapshot: SyncSnapshot, onInvalid: ((String) -> Void)? = nil) throws -> [String: SyncRecord] {
        var records: [String: SyncRecord] = [:]
        func add<T: Encodable>(_ kind: SyncKind, _ name: String, _ value: T) throws {
            do {
                let record = SyncRecord(kind: kind, name: name, versions: [
                    SyncVersion(stamp: .init(modifiedAt: .distantPast, modifiedBy: "snapshot", sequence: 0),
                                payload: try SyncCoding.encode(value))
                ])
                records[record.key] = record
            } catch {
                if let onInvalid { onInvalid(kind.rawValue + ":" + name) } else { throw error }
            }
        }
        for session in snapshot.data.sessions { try add(.session, session.id.uuidString, session) }
        for rule in snapshot.data.rateRules ?? [] { try add(.rateRule, rule.id.uuidString, rule) }
        try add(.profile, "Profile", SyncProfile(hourlyRate: snapshot.data.hourlyRate, currencyCode: snapshot.data.currencyCode))
        try add(.running, "Running", SyncRunning(session: snapshot.data.running))
        for (key, value) in snapshot.preferences where SyncPreferences.types[key] != nil { try add(.preference, key, value) }
        try add(.wardrobe, "WardrobeState", SyncWardrobe(snapshot.wardrobe))
        // Items are permanent non-consumable unlocks. Charge once even if bought offline twice.
        for purchase in snapshot.ledger.sorted(by: purchaseLess) {
            let name = purchaseName(purchase.itemID)
            if records[SyncKind.purchase.rawValue + ":" + name] == nil { try add(.purchase, name, purchase) }
        }
        return records
    }

    static func purchaseLess(_ a: WardrobePurchase, _ b: WardrobePurchase) -> Bool {
        if a.date != b.date { return a.date < b.date }
        if a.cost != b.cost { return a.cost < b.cost }
        return a.itemID < b.itemID
    }

    static func diff(previous: SyncSnapshot?, current: SyncSnapshot, known: [String: SyncRecord],
                     stamp: SyncStamp, onInvalid: ((String) -> Void)? = nil) throws -> [SyncRecord] {
        var invalid = Set<String>()
        let old = try previous.map { try payloads($0, onInvalid: { invalid.insert($0) }) } ?? [:]
        invalid = []
        let new = try payloads(current, onInvalid: { invalid.insert($0) })
        var changes: [SyncRecord] = []
        for key in Set(old.keys).union(new.keys).sorted() where !invalid.contains(key) {
            guard let template = new[key] ?? old[key], let payload = template.winner?.payload else { continue }
            do {
                // Check even unchanged values: local-only errors survive subsequent unrelated saves.
                if let value = new[key] { try validate(value) }
                guard old[key]?.winner?.payload != new[key]?.winner?.payload else { continue }
                if template.kind == .purchase && new[key] == nil { continue }
                let history = known[key]?.versions ?? []
                let version = SyncVersion(stamp: stamp, deleted: new[key] == nil, payload: payload,
                                          parents: history.map(\.id).sorted(), observed: known[key]?.maximumStamp)
                var change = SyncRecord(kind: template.kind, name: template.name, versions: [version])
                if let prior = known[key] { change.sessionFact = prior.sessionFact }
                let record = try known[key].map { try $0.joined(with: change) } ?? change.pruned()
                try validate(record)
                changes.append(record)
            } catch { invalid.insert(key) }
        }
        // Delete known import aliases using the old visible value (tombstones contain no payload).
        for change in changes where change.kind == .session && change.winner?.deleted == true {
            guard let payload = old[change.key]?.winner?.payload,
                  let session = try? SyncCoding.decode(WorkSession.self, payload) else { continue }
            for alias in known.values where alias.kind == .session && alias.key != change.key {
                guard let value = alias.winner, !value.deleted,
                      let other = try? SyncCoding.decode(WorkSession.self, value.payload),
                      importKey(other) == importKey(session), !changes.contains(where: { $0.key == alias.key }) else { continue }
                let version = SyncVersion(stamp: stamp, deleted: true, payload: Data(),
                                          parents: alias.versions.map(\.id).sorted(), observed: alias.maximumStamp)
                var deletion = SyncRecord(kind: .session, name: alias.name, versions: [version])
                deletion.sessionFact = alias.sessionFact
                changes.append(try alias.joined(with: deletion))
            }
        }
        for key in invalid.sorted() {
            if let onInvalid { onInvalid(key) } else { throw SyncFailure.invalid("Local-only value: " + key) }
        }
        return changes.sorted { $0.key < $1.key }
    }

    static func validate(_ record: SyncRecord) throws {
        func require(_ condition: Bool, _ reason: String) throws {
            if !condition { throw SyncFailure.invalid(reason) }
        }
        try require(record.schema == 2, "Unsupported record schema")
        try require(!record.versions.isEmpty && record.name.utf8.count <= 200, "Invalid record identity")
        try require(record.versions.count <= record.kind.capacity, "Too many revisions")
        try require(Set(record.versions.map(\.id)).count == record.versions.count, "Duplicate revision")
        try require(validStamp(record.maximumStamp), "Invalid maximum stamp")
        try require(record.versions.allSatisfy { $0.stamp <= record.maximumStamp }, "Missing maximum stamp")
        try require(record.kind == .session ? record.sessionFact != nil : record.sessionFact == nil, "Missing or unexpected session fact")
        if let start = record.sessionFact?.clockinStart { try require(SessionDuration.isValidDate(start), "Invalid clockinStart") }
        let owns = record.kind == .wardrobe || (record.kind == .preference && record.name == "Clockin.SeenAccessoryIDs")
        try require(owns || record.ownership.isEmpty, "Unexpected ownership facts")
        try require(record.ownership == Set(record.ownership).sorted(), "Noncanonical ownership")
        try catalogIDs(record.ownership)
        let retained = Set(record.versions.map(\.id))
        for version in record.versions {
            try require(validStamp(version.stamp), "Invalid modification stamp")
            if let observed = version.observed { try require(validStamp(observed) && observed < version.stamp, "Invalid causal floor") }
            try require(version.parents.count <= record.kind.capacity && version.parents == Set(version.parents).sorted()
                        && Set(version.parents).isSubset(of: retained) && !version.parents.contains(version.id), "Invalid causal parents")
            for parent in record.versions where version.parents.contains(parent.id) {
                try require(version.observed.map { parent.stamp <= $0 } ?? false, "Parent exceeds causal floor")
            }
            try require(version.payload.count <= record.kind.payloadBytes, "Payload byte limit")
            try require(!version.deleted || record.kind.removeWins || record.kind == .preference, "Unsupported deletion")
            if record.kind.removeWins && version.deleted {
                try require(UUID(uuidString: record.name)?.uuidString == record.name && version.payload.isEmpty, "Invalid tombstone")
                continue
            }
            switch record.kind {
            case .session:
                let session = try SyncCoding.decode(WorkSession.self, version.payload)
                try require(session.id.uuidString == record.name && session.hasValidDuration
                            && session.hourlyRate.isFinite && session.hourlyRate >= 0
                            && SyncBounds.text(session.note, characters: 2000)
                            && SyncBounds.text(session.source, characters: 256)
                            && (session.matchedExternalSource.map { SyncBounds.text($0, characters: 256) } ?? true), "Invalid session")
            case .rateRule:
                let rule = try SyncCoding.decode(RateRule.self, version.payload)
                let object = try JSONSerialization.jsonObject(with: version.payload) as? [String: Any]
                try require(object?["id"] != nil && rule.id.uuidString == record.name
                            && SessionDuration.isValidDate(rule.effectiveFrom)
                            && rule.hourlyRate.isFinite && rule.hourlyRate >= 0
                            && (rule.effectiveUntil.map { SessionDuration.isValidDate($0) && $0 >= rule.effectiveFrom } ?? true),
                            "Invalid rate rule")
            case .profile:
                let value = try SyncCoding.decode(SyncProfile.self, version.payload)
                try require(record.name == "Profile" && value.hourlyRate.isFinite && value.hourlyRate >= 0
                            && value.currencyCode.utf8.count == 3
                            && value.currencyCode.utf8.allSatisfy { (65...90).contains($0) }, "Invalid profile")
            case .running:
                let value = try SyncCoding.decode(SyncRunning.self, version.payload)
                try require(record.name == "Running" && (value.session?.hasValidDuration(at: version.stamp.modifiedAt) ?? true)
                            && (value.session.map { SyncBounds.text($0.note, characters: 2000) } ?? true),
                            "Invalid running timer")
            case .preference:
                let value = try SyncCoding.decode(SyncPreference.self, version.payload)
                try require(SyncPreferences.accepts(record.name, value), "Excluded preference or wrong type")
                switch value {
                case .string(let text): try require(SyncBounds.text(text, characters: 256), "Preference string limit")
                case .strings(let values):
                    try require(values.count <= 256 && values.allSatisfy { SyncBounds.text($0, characters: 256) }, "Preference array limit")
                    try catalogIDs(values)
                    try require(Set(values).isSubset(of: Set(record.ownership)), "Missing ownership facts")
                default: break
                }
            case .purchase:
                let value = try SyncCoding.decode(WardrobePurchase.self, version.payload)
                try require(!value.itemID.isEmpty && value.cost > 0 && SessionDuration.isValidDate(value.date)
                            && purchaseName(value.itemID) == record.name, "Invalid purchase")
                try catalogIDs([value.itemID])
            case .wardrobe:
                let value = try SyncCoding.decode(SyncWardrobe.self, version.payload)
                try require(record.name == "WardrobeState" && value.owned == Set(value.owned).sorted(), "Invalid wardrobe")
                try catalogIDs(value.owned)
                try require(Set(value.owned).isSubset(of: Set(record.ownership)), "Missing ownership facts")
                try require(value.equipped.count <= 16 && value.furniture.count <= 16 && value.arrangement.count <= 16,
                            "Wardrobe collection limit")
                let choices = Array(value.equipped.values) + Array(value.furniture.values) + [value.colorway, value.room]
                try catalogIDs(choices)
                try require((Array(value.equipped.keys) + Array(value.furniture.keys)).allSatisfy { WardrobeSlot(rawValue: $0) != nil }, "Invalid wardrobe slot")
                for (room, items) in value.arrangement {
                    try require(items.count <= 64, "Arrangement item limit")
                    try require(SyncBounds.identifier(room, max: 64), "Invalid room")
                    for (item, point) in items {
                        try require(SyncBounds.identifier(item, max: 80) && point.x.isFinite && point.y.isFinite
                                    && abs(point.x) <= 360 && abs(point.y) <= 240, "Invalid arrangement")
                    }
                }
            }
        }
    }

    static func validStamp(_ stamp: SyncStamp) -> Bool {
        SessionDuration.isValidDate(stamp.modifiedAt) && SyncBounds.identifier(stamp.modifiedBy)
    }

    static func catalogIDs(_ ids: [String]) throws {
        guard ids.allSatisfy({ SyncBounds.catalog.contains($0) }) else { throw SyncFailure.unknownCatalog }
    }

    static func merge(local: [String: SyncRecord], incoming: [SyncRecord], onto snapshot: SyncSnapshot,
                      deviceID: String? = nil) throws -> SyncMerge {
        var records = local
        var quarantine: [SyncQuarantine] = []
        var server: [String: SyncRecord] = [:]
        for remote in incoming {
            do {
                try validate(remote)
                records[remote.key] = try records[remote.key].map { try $0.joined(with: remote) } ?? remote.pruned()
                server[remote.key] = remote
            } catch {
                quarantine.append(.init(recordKey: remote.key, bytes: (try? SyncCoding.encode(remote)) ?? Data(),
                                        reason: String(describing: error), futureCatalog: error as? SyncFailure == .unknownCatalog))
            }
        }
        let projection = try materialize(records, onto: snapshot)
        let recoveries = try displaced(local: local, merged: records, before: snapshot, after: projection.snapshot, deviceID: deviceID)
        return SyncMerge(records: records, snapshot: projection.snapshot,
                         resend: server.keys.sorted().compactMap { records[$0] == server[$0] ? nil : records[$0] },
                         quarantine: quarantine, recoveries: recoveries, notices: recoveries.map(\.notice))
    }

    // Only values this device had applied/authored are candidates. Replaying remote history is inert.
    static func displaced(local: [String: SyncRecord], merged: [String: SyncRecord],
                          before: SyncSnapshot, after: SyncSnapshot, deviceID: String? = nil,
                          includeReplacements: Bool = true) throws -> [SyncRecovery] {
        var result: [SyncRecovery] = []
        let beforeIDs = Set(before.data.sessions.map { $0.id.uuidString })
        let afterIDs = Set(after.data.sessions.map { $0.id.uuidString })
        let completed = Set(merged.values.compactMap { $0.sessionFact?.clockinStart })
        for old in local.values.sorted(by: { $0.key < $1.key }) {
            guard let prior = old.winner, !prior.deleted, let record = merged[old.key], let winner = record.winner else { continue }
            if old.kind == .running {
                guard let run = try SyncCoding.decode(SyncRunning.self, prior.payload).session,
                      before.data.running?.start == run.start, after.data.running?.start != run.start,
                      !completed.contains(run.start) else { continue }
                result.append(.init(recordKey: old.key, version: prior, reason: "Displaced timer"))
            } else if old.kind == .session,
                      beforeIDs.contains(old.name), !afterIDs.contains(old.name), !winner.deleted,
                      prior.id == winner.id {
                result.append(.init(recordKey: old.key, version: prior, reason: "Import-key duplicate"))
            } else if includeReplacements && prior.id != winner.id && prior.payload != winner.payload,
                      try prior.stamp.modifiedBy == deviceID || wasApplied(prior, record: old, snapshot: before) {
                // A causal floor can mask actual concurrency. Recovery must not depend on
                // certifying a conflict; sequential/uncertain replacements get neutral wording.
                result.append(.init(recordKey: old.key, version: prior,
                                    reason: prior.concurrent(with: winner) ? "Concurrent edit" : "Replaced value"))
            }
        }
        return result
    }

    private static func wasApplied(_ version: SyncVersion, record: SyncRecord, snapshot: SyncSnapshot) throws -> Bool {
        switch record.kind {
        case .session: return snapshot.data.sessions.contains(try SyncCoding.decode(WorkSession.self, version.payload))
        case .rateRule: return (snapshot.data.rateRules ?? []).contains(try SyncCoding.decode(RateRule.self, version.payload))
        case .profile:
            return try SyncCoding.decode(SyncProfile.self, version.payload) == SyncProfile(hourlyRate: snapshot.data.hourlyRate, currencyCode: snapshot.data.currencyCode)
        case .running: return try SyncCoding.decode(SyncRunning.self, version.payload).session == snapshot.data.running
        case .preference: return try SyncCoding.decode(SyncPreference.self, version.payload) == snapshot.preferences[record.name]
        case .purchase: return snapshot.ledger.contains(try SyncCoding.decode(WardrobePurchase.self, version.payload))
        case .wardrobe:
            var value = try SyncCoding.decode(SyncWardrobe.self, version.payload)
            // Ownership facts can grow independently of the selected revision.
            value.owned = snapshot.wardrobe.owned.sorted()
            return value == SyncWardrobe(snapshot.wardrobe)
        }
    }

    static func materialize(_ records: [String: SyncRecord], onto local: SyncSnapshot) throws
    -> (snapshot: SyncSnapshot, recoveries: [SyncRecovery], notices: [SyncNotice]) {
        var result = local
        result.preferences = SyncPreferences.filtered(local.preferences)
        var sessions = local.data.sessions.filter { records[SyncKind.session.rawValue + ":" + $0.id.uuidString] == nil }
        var rules = (local.data.rateRules ?? []).filter { records[SyncKind.rateRule.rawValue + ":" + $0.id.uuidString] == nil }
        var ledger = local.ledger.filter { records[SyncKind.purchase.rawValue + ":" + purchaseName($0.itemID)] == nil }
        var completed = Set(sessions.filter { $0.source == "Clockin" }.map(\.start))
        var runningRecord: SyncRecord?
        for record in records.values.sorted(by: { $0.key < $1.key }) {
            guard let winner = record.winner else { continue }
            switch record.kind {
            case .session:
                if let start = record.sessionFact?.clockinStart { completed.insert(start) }
                if !winner.deleted { sessions.append(try SyncCoding.decode(WorkSession.self, winner.payload)) }
            case .rateRule:
                if !winner.deleted { rules.append(try SyncCoding.decode(RateRule.self, winner.payload)) }
            case .profile:
                let profile = try SyncCoding.decode(SyncProfile.self, winner.payload)
                result.data.hourlyRate = profile.hourlyRate; result.data.currencyCode = profile.currencyCode
            case .running: runningRecord = record
            case .preference:
                if record.name == "Clockin.SeenAccessoryIDs" { result.preferences[record.name] = .strings(record.ownership) }
                else if winner.deleted { result.preferences[record.name] = nil }
                else { result.preferences[record.name] = try SyncCoding.decode(SyncPreference.self, winner.payload) }
            case .purchase:
                ledger.append(try SyncCoding.decode(WardrobePurchase.self, winner.payload))
            case .wardrobe:
                var wardrobe = try SyncCoding.decode(SyncWardrobe.self, winner.payload)
                wardrobe.owned = record.ownership
                result.wardrobe = wardrobe.applying(to: local.wardrobe)
            }
        }
        var byKey: [String: WorkSession] = [:]
        for session in sessions.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            if byKey[importKey(session)] == nil { byKey[importKey(session)] = session }
        }
        result.data.sessions = byKey.values.sorted { $0.id.uuidString < $1.id.uuidString }
        result.data.rateRules = rules.sorted { $0.id.uuidString < $1.id.uuidString }
        result.ledger = ledger.sorted { $0.itemID < $1.itemID }
        result.wardrobe.owned.formUnion(ledger.map(\.itemID))
        if case .strings(let ids) = result.preferences["Clockin.SeenAccessoryIDs"] { result.wardrobe.owned.formUnion(ids) }
        if let record = runningRecord, let winner = record.winner {
            let selected = try SyncCoding.decode(SyncRunning.self, winner.payload).session
            result.data.running = selected
        }
        if let start = result.data.running?.start, completed.contains(start) { result.data.running = nil }
        return (result, [], [])
    }

    static func firstPreview(local: [String: SyncRecord], incoming: [SyncRecord], snapshot: SyncSnapshot,
                             revision: UInt64, deviceID: String? = nil) throws -> SyncFirstPreview {
        let merge = try merge(local: local, incoming: incoming, onto: snapshot, deviceID: deviceID)
        let count = merge.snapshot.data.sessions.count
        // Remote count includes shared UUIDs; duplicates includes both shared UUIDs and import-key aliases.
        let localDevices = Set(local.values.flatMap(\.versions).map(\.stamp.modifiedBy))
        let remoteIDs = Set(incoming.filter {
            $0.kind == .session && $0.winner?.deleted == false && (try? validate($0)) != nil
                && $0.versions.contains { !localDevices.contains($0.stamp.modifiedBy) }
        }.map(\.name))
        let remoteCount = remoteIDs.count
        let duplicateCount = max(0, snapshot.data.sessions.count + remoteCount - count)
        return .init(localCount: snapshot.data.sessions.count, remoteCount: remoteCount,
                     duplicates: duplicateCount, mergedCount: count, revision: revision, merge: merge)
    }
}
