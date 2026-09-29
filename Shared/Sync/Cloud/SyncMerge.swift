import Foundation

enum SyncCore {
    static func importKey(_ session: WorkSession) -> String {
        "\(Int(session.start.timeIntervalSince1970))|\(Int(session.end.timeIntervalSince1970))|\(Int(session.duration))"
    }

    static func purchaseName(_ itemID: String) -> String {
        Data(itemID.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "=", with: "")
    }

    static func payloads(_ snapshot: SyncSnapshot) throws -> [String: SyncRecord] {
        var records: [String: SyncRecord] = [:]
        func add<T: Encodable>(_ kind: SyncKind, _ name: String, _ value: T) throws {
            let record = SyncRecord(kind: kind, name: name, versions: [
                SyncVersion(stamp: .init(modifiedAt: .distantPast, modifiedBy: "snapshot", sequence: 0),
                            payload: try SyncCoding.encode(value))
            ])
            records[record.key] = record
        }
        for session in snapshot.data.sessions { try add(.session, session.id.uuidString, session) }
        for rule in snapshot.data.rateRules ?? [] { try add(.rateRule, rule.id.uuidString, rule) }
        try add(.profile, "Profile", SyncProfile(hourlyRate: snapshot.data.hourlyRate, currencyCode: snapshot.data.currencyCode))
        try add(.running, "Running", SyncRunning(session: snapshot.data.running))
        for (key, value) in SyncPreferences.filtered(snapshot.preferences) { try add(.preference, key, value) }
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
                     stamp: SyncStamp) throws -> [SyncRecord] {
        let old = try previous.map(payloads) ?? [:]
        let new = try payloads(current)
        var changes: [SyncRecord] = []
        for key in Set(old.keys).union(new.keys).sorted() {
            guard old[key]?.winner?.payload != new[key]?.winner?.payload else { continue }
            guard let template = new[key] ?? old[key], let payload = template.winner?.payload else { continue }
            if template.kind == .purchase, new[key] == nil { continue }
            let history = known[key]?.versions ?? []
            let superseded = Set(history.flatMap(\.parents))
            let version = SyncVersion(stamp: stamp, deleted: new[key] == nil, payload: payload,
                                      parents: history.map(\.id).filter { !superseded.contains($0) }.sorted())
            let change = SyncRecord(kind: template.kind, name: template.name, versions: [version])
            let record = try known[key].map { try $0.joined(with: change) } ?? change
            try validate(record)
            changes.append(record)
        }
        // A visible import duplicate may have several UUIDs. Delete every known alias.
        for change in changes where change.kind == .session && change.winner?.deleted == true {
            guard let deleted = change.winner, let session = try? SyncCoding.decode(WorkSession.self, deleted.payload) else { continue }
            for alias in known.values where alias.kind == .session && alias.key != change.key {
                guard let value = alias.winner, !value.deleted,
                      let other = try? SyncCoding.decode(WorkSession.self, value.payload),
                      importKey(other) == importKey(session), !changes.contains(where: { $0.key == alias.key }) else { continue }
                let version = SyncVersion(stamp: stamp, deleted: true, payload: value.payload,
                                          parents: alias.versions.map(\.id).sorted())
                changes.append(try alias.joined(with: .init(kind: .session, name: alias.name, versions: [version])))
            }
        }
        return changes.sorted { $0.key < $1.key }
    }

    static func validate(_ record: SyncRecord) throws {
        func require(_ condition: Bool, _ reason: String) throws {
            if !condition { throw SyncFailure.invalid(reason) }
        }
        try require(record.schema == 1, "Unsupported record schema")
        try require(!record.versions.isEmpty && record.name.utf8.count <= 200, "Invalid record identity")
        try require(Set(record.versions.map(\.id)).count == record.versions.count, "Duplicate revision")
        for version in record.versions {
            try require(SessionDuration.isValidDate(version.stamp.modifiedAt)
                        && !version.stamp.modifiedBy.isEmpty && version.stamp.modifiedBy.utf8.count <= 128,
                        "Invalid modification stamp")
            try require(!version.deleted || record.kind.removeWins || record.kind == .preference, "Unsupported deletion")
            switch record.kind {
            case .session:
                let session = try SyncCoding.decode(WorkSession.self, version.payload)
                try require(session.id.uuidString == record.name && session.hasValidDuration
                            && session.hourlyRate.isFinite && session.hourlyRate >= 0, "Invalid session")
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
                try require(record.name == "Running" && (value.session?.hasValidDuration(at: version.stamp.modifiedAt) ?? true),
                            "Invalid running timer")
            case .preference:
                let value = try SyncCoding.decode(SyncPreference.self, version.payload)
                try require(SyncPreferences.accepts(record.name, value), "Excluded preference or wrong type")
            case .purchase:
                let value = try SyncCoding.decode(WardrobePurchase.self, version.payload)
                try require(!value.itemID.isEmpty && value.cost > 0 && SessionDuration.isValidDate(value.date)
                            && purchaseName(value.itemID) == record.name, "Invalid purchase")
            case .wardrobe:
                let value = try SyncCoding.decode(SyncWardrobe.self, version.payload)
                try require(record.name == "WardrobeState" && value.owned == Set(value.owned).sorted(), "Invalid wardrobe")
                for (room, items) in value.arrangement {
                    try require(room.count <= 64, "Invalid room")
                    for (item, point) in items {
                        try require(item.count <= 80 && point.x.isFinite && point.y.isFinite
                                    && abs(point.x) <= 360 && abs(point.y) <= 240, "Invalid arrangement")
                    }
                }
            }
        }
    }

    static func merge(local: [String: SyncRecord], incoming: [SyncRecord], onto snapshot: SyncSnapshot) throws -> SyncMerge {
        var records = local
        var quarantine: [SyncQuarantine] = []
        var server: [String: SyncRecord] = [:]
        for remote in incoming {
            do {
                try validate(remote)
                let joined = try records[remote.key].map { try $0.joined(with: remote) } ?? remote
                records[remote.key] = try joined.joined(with: joined)
                server[remote.key] = remote
            } catch {
                quarantine.append(.init(recordKey: remote.key, bytes: (try? SyncCoding.encode(remote)) ?? Data(),
                                        reason: String(describing: error)))
            }
        }
        let projection = try materialize(records, onto: snapshot)
        return SyncMerge(records: records, snapshot: projection.snapshot,
                         resend: server.keys.sorted().compactMap { records[$0] == server[$0] ? nil : records[$0] },
                         quarantine: quarantine, recoveries: projection.recoveries, notices: projection.notices)
    }

    static func materialize(_ records: [String: SyncRecord], onto local: SyncSnapshot) throws
    -> (snapshot: SyncSnapshot, recoveries: [SyncRecovery], notices: [SyncNotice]) {
        var result = local
        result.preferences = SyncPreferences.filtered(local.preferences)
        var sessions = local.data.sessions.filter { records[SyncKind.session.rawValue + ":" + $0.id.uuidString] == nil }
        var rules = (local.data.rateRules ?? []).filter { records[SyncKind.rateRule.rawValue + ":" + $0.id.uuidString] == nil }
        var ledger = local.ledger.filter { records[SyncKind.purchase.rawValue + ":" + purchaseName($0.itemID)] == nil }
        var completed = Set(sessions.filter { $0.source == "Clockin" }.map(\.start))
        var recoveries: [SyncRecovery] = []
        var notices: [SyncNotice] = []
        var runningRecord: SyncRecord?
        for record in records.values.sorted(by: { $0.key < $1.key }) {
            guard let winner = record.winner else { continue }
            // Keep all losing values, including sequential history and deleted entries.
            for version in record.versions where version != winner || winner.deleted {
                recoveries.append(.init(recordKey: record.key, version: version, reason: "Previous or losing revision"))
            }
            let parentIDs = Set(record.versions.flatMap(\.parents))
            let heads = record.versions.filter { !parentIDs.contains($0.id) }
            if heads.count > 1 && record.kind != .purchase && record.kind != .running {
                notices.append(.init(id: "conflict:" + record.key,
                                     message: "Conflicting \(record.kind.rawValue) changes were resolved. Previous values are recoverable."))
            }
            switch record.kind {
            case .session:
                for version in record.versions {
                    let session = try SyncCoding.decode(WorkSession.self, version.payload)
                    if session.source == "Clockin" { completed.insert(session.start) }
                }
                if !winner.deleted { sessions.append(try SyncCoding.decode(WorkSession.self, winner.payload)) }
            case .rateRule:
                if !winner.deleted { rules.append(try SyncCoding.decode(RateRule.self, winner.payload)) }
            case .profile:
                let profile = try SyncCoding.decode(SyncProfile.self, winner.payload)
                result.data.hourlyRate = profile.hourlyRate; result.data.currencyCode = profile.currencyCode
            case .running: runningRecord = record
            case .preference:
                if winner.deleted { result.preferences[record.name] = nil }
                else if record.name == "Clockin.SeenAccessoryIDs" {
                    var owned = Set<String>()
                    for version in record.versions where !version.deleted {
                        if case .strings(let ids) = try SyncCoding.decode(SyncPreference.self, version.payload) { owned.formUnion(ids) }
                    }
                    result.preferences[record.name] = .strings(owned.sorted())
                } else { result.preferences[record.name] = try SyncCoding.decode(SyncPreference.self, winner.payload) }
            case .purchase:
                let purchases = try record.versions.map { try SyncCoding.decode(WardrobePurchase.self, $0.payload) }
                if let value = purchases.min(by: purchaseLess) { ledger.append(value) }
            case .wardrobe:
                var wardrobe = try SyncCoding.decode(SyncWardrobe.self, winner.payload)
                var owned = Set<String>()
                for version in record.versions { owned.formUnion(try SyncCoding.decode(SyncWardrobe.self, version.payload).owned) }
                wardrobe.owned = owned.sorted()
                result.wardrobe = wardrobe.applying(to: local.wardrobe)
            }
        }
        var byKey: [String: WorkSession] = [:]
        for session in sessions.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            if byKey[importKey(session)] == nil { byKey[importKey(session)] = session }
            else if let record = records[SyncKind.session.rawValue + ":" + session.id.uuidString], let version = record.winner {
                recoveries.append(.init(recordKey: record.key, version: version, reason: "Import-key duplicate"))
                let noticeID = "duplicate:" + importKey(session)
                if !notices.contains(where: { $0.id == noticeID }) {
                    notices.append(.init(id: noticeID, message: "Duplicate work entries were collapsed. All original values remain recoverable."))
                }
            }
        }
        result.data.sessions = byKey.values.sorted { $0.id.uuidString < $1.id.uuidString }
        result.data.rateRules = rules.sorted { $0.id.uuidString < $1.id.uuidString }
        result.ledger = ledger.sorted { $0.itemID < $1.itemID }
        result.wardrobe.owned.formUnion(ledger.map(\.itemID))
        if case .strings(let ids) = result.preferences["Clockin.SeenAccessoryIDs"] { result.wardrobe.owned.formUnion(ids) }
        if let record = runningRecord, let winner = record.winner {
            let selected = try SyncCoding.decode(SyncRunning.self, winner.payload).session
            result.data.running = selected.flatMap { completed.contains($0.start) ? nil : $0 }
            var byStart: [Date: SyncVersion] = [:]
            for version in record.versions {
                guard let run = try SyncCoding.decode(SyncRunning.self, version.payload).session else { continue }
                if byStart[run.start].map({ SyncVersion.less($0, version) }) ?? true { byStart[run.start] = version }
            }
            for start in byStart.keys.sorted() where start != result.data.running?.start && !completed.contains(start) {
                guard let version = byStart[start] else { continue }
                recoveries.append(.init(recordKey: record.key, version: version, reason: "Displaced timer"))
                notices.append(.init(id: "running:" + String(start.timeIntervalSinceReferenceDate),
                                     message: "Another timer state won. The displaced timer is available for recovery."))
            }
        }
        return (result, recoveries, notices.sorted { $0.id < $1.id })
    }

    static func firstPreview(local: [String: SyncRecord], incoming: [SyncRecord], snapshot: SyncSnapshot,
                             revision: UInt64) throws -> SyncFirstPreview {
        let merge = try merge(local: local, incoming: incoming, onto: snapshot)
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
