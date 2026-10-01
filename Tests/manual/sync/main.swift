import Foundation

var checks = 0
@MainActor func check(_ value: @autoclosure () throws -> Bool, _ message: String) rethrows {
    guard try value() else { fatalError("FAIL: \(message)") }
    checks += 1
    emit("ok \(message)")
}
func emit(_ text: String) {
    // Keep progress visible when the long-run command is redirected to a log.
    try? FileHandle.standardOutput.write(contentsOf: Data((text + "\n").utf8))
}
func date(_ value: Double) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + value) }
func uuid(_ value: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))! }
func session(_ id: Int, start: Double = 0, note: String = "", source: String = "Clockin") -> WorkSession {
    .init(id: uuid(id), start: date(start), end: date(start + 60), duration: 60, note: note, hourlyRate: 25, source: source)
}
func run(_ start: Double, paused: Bool = false) -> RunningSession {
    .init(start: date(start), accumulated: 0, resumedAt: paused ? nil : date(start), note: "run \(start)")
}
func stamp(_ device: String, _ time: Double, sequence: UInt64? = nil) -> SyncStamp {
    .init(modifiedAt: date(time), modifiedBy: device, sequence: sequence ?? UInt64(time))
}
func record<T: Encodable>(_ kind: SyncKind, _ name: String, _ payload: T, device: String = "a",
                           time: Double = 100, deleted: Bool = false, sequence: UInt64? = nil) throws -> SyncRecord {
    .init(kind: kind, name: name, versions: [.init(stamp: stamp(device, time, sequence: sequence),
                                                 deleted: deleted, payload: try SyncCoding.encode(payload))])
}
func blank() -> SyncSnapshot { .init(data: ClockinData()) }
func merge(_ records: [SyncRecord], onto state: SyncSnapshot = blank()) throws -> SyncMerge {
    try SyncCore.merge(local: [:], incoming: records, onto: state)
}
func bytes(_ snapshot: SyncSnapshot) throws -> Data { try SyncCoding.encode(SyncCore.payloads(snapshot)) }

var original = blank()
original.data.sessions = [session(1)]
original.data.rateRules = [.init(id: uuid(2), effectiveFrom: date(0), hourlyRate: 25)]
original.preferences = ["Clockin.Theme": .string("Carbon")]
let seeded = try SyncCore.diff(previous: nil, current: original, known: [:], stamp: stamp("a", 100))
let known = Dictionary(uniqueKeysWithValues: seeded.map { ($0.key, $0) })
check(seeded.count == 6, "initial diff emits sessions, rules, profile, running, preference, wardrobe")
try check(SyncCore.diff(previous: original, current: original, known: known, stamp: stamp("a", 101)).isEmpty,
          "unchanged snapshot has no diff")
var changed = original
changed.data.pinVisible = true
changed.wardrobe.seeded = true
changed.preferences["Clockin.RemoteActivityConsent.v2"] = .bool(true)
changed.preferences["Clockin.USDTRYRates.v1"] = .double(999)
try check(SyncCore.diff(previous: original, current: changed, known: known, stamp: stamp("a", 101)).isEmpty,
          "pin, setup, consent and cache changes never upload")
changed.data.currencyCode = "EUR"
try check(SyncCore.diff(previous: original, current: changed, known: known, stamp: stamp("a", 101)).map(\.kind) == [.profile],
          "profile edit changes exactly one record")
changed = original; changed.data.sessions = []; changed.data.rateRules = []
let deletions = try SyncCore.diff(previous: original, current: changed, known: known, stamp: stamp("a", 102))
check(deletions.count == 2 && deletions.allSatisfy { $0.winner?.deleted == true }, "session and rule deletion use tombstones")

let a = try record(.session, uuid(1).uuidString, session(1, note: "a"))
let b = try record(.session, uuid(1).uuidString, session(1, note: "b"), device: "b")
try check(merge([a, b]).snapshot.data.sessions.first?.note == "b", "LWW ties break by stable device id")
try check(bytes(merge([a, b]).snapshot) == bytes(merge([b, a]).snapshot), "LWW order is commutative")
let tombstone = try record(.session, uuid(1).uuidString, session(1), time: 99, deleted: true)
let lateEdit = try record(.session, uuid(1).uuidString, session(1, note: "newer edit"), device: "b", time: 999)
let removed = try SyncCore.merge(local: [lateEdit.key: lateEdit], incoming: [tombstone], onto: merge([lateEdit]).snapshot)
check(removed.snapshot.data.sessions.isEmpty && !removed.recoveries.isEmpty, "deletion wins even against later offline edit and preserves it")
try check(SyncCoding.encode(removed.records) == SyncCoding.encode(merge([tombstone, lateEdit]).records), "delete conflict converges")
let rule = RateRule(id: uuid(9), effectiveFrom: date(0), hourlyRate: 10)
let ruleDelete = try record(.rateRule, rule.id.uuidString, rule, time: 101, deleted: true)
let ruleEdit = try record(.rateRule, rule.id.uuidString, rule, device: "b", time: 102)
try check(merge([ruleEdit, ruleDelete]).snapshot.data.rateRules?.isEmpty == true, "rate deletion wins")

let start = try record(.running, "Running", SyncRunning(session: run(0)))
let pause = try record(.running, "Running", SyncRunning(session: run(0, paused: true)), device: "b", time: 110)
let idle = try record(.running, "Running", SyncRunning(session: nil), device: "c", time: 111)
try check(merge([pause, idle]).snapshot.data.running == nil, "clock-out idle orders after pause")
try check(merge([idle, pause]).snapshot.data.running == nil, "out-of-order pause cannot replace later idle")
let completed = try record(.session, uuid(10).uuidString, session(10), device: "c", time: 109)
let newerPause = try record(.running, "Running", SyncRunning(session: run(0, paused: true)), device: "b", time: 999)
try check(merge([completed, newerPause]).snapshot.data.running == nil, "completed run defeats a newer offline pause")
let deleteCompleted = try record(.session, uuid(10).uuidString, session(10), device: "c", time: 112, deleted: true, sequence: 2)
try check(merge([completed, deleteCompleted, start]).snapshot.data.running == nil,
          "deleting completed session does not erase resurrection guard")
let laterStart = try record(.running, "Running", SyncRunning(session: run(10)), device: "b", time: 111)
let competing = try SyncCore.merge(local: [start.key: start], incoming: [laterStart], onto: merge([start]).snapshot)
check(competing.snapshot.data.running?.start == date(10), "later of two starts wins")
check(competing.recoveries.contains { $0.reason == "Displaced timer" } && competing.notices.count == 1,
      "losing run remains recoverable with stable notice")
try check(SyncCoding.encode(competing.records) == SyncCoding.encode(merge([laterStart, start]).records), "two starts converge in reverse order")
var resumeState = SyncSidecar(deviceID: "a"); resumeState.firstMergeCompleted = true
_ = try resumeState.receive([pause], snapshot: blank())
let remotelyPaused = try SyncCore.materialize(resumeState.records, onto: blank()).snapshot
var resumed = remotelyPaused; resumed.data.running?.resumedAt = date(120)
try resumeState.capture(previous: remotelyPaused, current: resumed, at: date(105))
let resumeMerged = try merge(Array(resumeState.records.values) + [pause])
check(resumeMerged.snapshot.data.running?.resumedAt == date(120), "resume after remote pause survives clock rollback and stale delivery")
try check(merge([try record(.session, uuid(10).uuidString, session(10, source: "CSV")), start]).snapshot.data.running != nil,
          "external-source history never closes a Clockin run")

var wardrobeA = WardrobeState(); wardrobeA.owned = ["cape"]; wardrobeA.colorway = "mint"
var wardrobeB = WardrobeState(); wardrobeB.owned = ["cap"]; wardrobeB.colorway = "gold"; wardrobeB.homeLampOn = false
wardrobeB.homeArrangement.set(.init(10, 20), for: "desk", room: "cozy")
let wa = try record(.wardrobe, "WardrobeState", SyncWardrobe(wardrobeA))
let wb = try record(.wardrobe, "WardrobeState", SyncWardrobe(wardrobeB), device: "b")
let wardrobe = try merge([wb, wa]).snapshot.wardrobe
check(wardrobe.owned == ["cape", "cap"] && wardrobe.colorway == "gold" && !wardrobe.homeLampOn,
      "wardrobe owned unions while selection and lamp use LWW")
check(wardrobe.homeArrangement.offset(for: "desk", room: "cozy") == .init(10, 20), "room arrangement follows selected state")
let purchase1 = WardrobePurchase(itemID: "mint", cost: 100, date: date(1))
let purchase2 = WardrobePurchase(itemID: "mint", cost: 120, date: date(2))
let p1 = try record(.purchase, SyncCore.purchaseName("mint"), purchase1)
let p2 = try record(.purchase, SyncCore.purchaseName("mint"), purchase2, device: "b")
let purchases = try merge([p2, p1, p1]).snapshot
check(purchases.ledger == [purchase1] && purchases.wardrobe.owned.contains("mint"), "same permanent item bought offline is one purchase at earliest price")
check(WardrobeCoins.balance(earned: 500, ledger: purchases.ledger) == 400, "coins derive from ledger with one charge")
let prefA = try record(.preference, "Clockin.Theme", SyncPreference.string("Carbon"))
let prefB = try record(.preference, "Clockin.Theme", SyncPreference.string("Paper"), device: "b")
try check(merge([prefB, prefA]).snapshot.preferences["Clockin.Theme"] == .string("Paper"), "preference LWW with ties")
let prefDelete = try record(.preference, "Clockin.Theme", SyncPreference.string("Paper"), device: "c", time: 200, deleted: true)
try check(merge([prefA, prefDelete]).snapshot.preferences["Clockin.Theme"] == nil, "preference reset is an ordered tombstone")
for key in SyncPreferences.deviceKeys + ["Clockin.PinnedWidth.Future", "Clockin.SomeNewKey", "coins"] {
    check(!SyncPreferences.accepts(key, .bool(true)), "device/unknown key excluded: \(key)")
}
let inventory = try String(contentsOfFile: "docs/mac-port-inventory.md", encoding: .utf8)
for row in inventory.components(separatedBy: "\n") where row.hasPrefix("| `") && (row.hasSuffix("| device |") || row.hasSuffix("| sync |")) {
    let columns = row.components(separatedBy: "|")
    let key = columns[1].trimmingCharacters(in: CharacterSet(charactersIn: " `"))
    let special = ["Clockin.WardrobeState", "Clockin.WardrobeLedger", "Clockin.RemoteActivityConsent.v2"]
    if row.hasSuffix("| device |") || key == "Clockin.RemoteActivityConsent.v2" {
        check(SyncPreferences.types[key] == nil, "inventory device policy: \(key)")
    } else if !special.contains(key) { check(SyncPreferences.types[key] != nil, "inventory sync coverage: \(key)") }
}

var localFirst = blank(); localFirst.data.sessions = [session(1), session(2, start: 200)]
let firstRecords = try SyncCore.diff(previous: nil, current: localFirst, known: [:], stamp: stamp("local", 1000))
let firstKnown = Dictionary(uniqueKeysWithValues: firstRecords.map { ($0.key, $0) })
let sharedID = try record(.session, uuid(1).uuidString, session(1), device: "remote")
let alias = try record(.session, uuid(3).uuidString, session(3, start: 200, note: "different metadata"), device: "remote")
let unique = try record(.session, uuid(4).uuidString, session(4, start: 400), device: "remote")
let preview = try SyncCore.firstPreview(local: firstKnown, incoming: [sharedID, alias, unique], snapshot: localFirst, revision: 1)
check(preview.localCount == 2 && preview.remoteCount == 3 && preview.duplicates == 2 && preview.mergedCount == 3,
      "first sync reports local 2 + remote 3 - duplicates 2 = merged 3")
check(preview.merge.records[alias.key] != nil, "unapplied remote duplicate remains its own retained identity")
check(preview.merge.recoveries.isEmpty, "unapplied remote duplicate creates no local recovery notice")
check(SyncCore.importKey(session(1)) == "1800000000|1800000060|60", "duplicate key matches ClockStore integer-second import key")
// An approved first merge keeps shared entries once; identical aliases are not "replaced" news.
do {
    var merged = blank(); merged.data.sessions = [session(1), session(2, start: 200, note: "kept")]
    let sameAlias = try record(.session, uuid(5).uuidString, session(5), device: "local")
    let noteAlias = try record(.session, uuid(6).uuidString, session(6, start: 200, note: "other note"), device: "local")
    let entries = [SyncRecovery(recordKey: sameAlias.key, version: sameAlias.winner!, reason: "Import-key duplicate"),
                   SyncRecovery(recordKey: noteAlias.key, version: noteAlias.winner!, reason: "Import-key duplicate")]
    let kept = SyncSidecar.worthKeeping(entries, merged: merged)
    check(kept.count == 1 && kept[0].recordKey == noteAlias.key,
          "first merge drops identical duplicate aliases and keeps one whose note differs")
}
var deletedAlias = preview.merge.snapshot; deletedAlias.data.sessions.removeAll { $0.start == date(200) }
let aliasDeletes = try SyncCore.diff(previous: preview.merge.snapshot, current: deletedAlias, known: preview.merge.records, stamp: stamp("local", 1001))
check(aliasDeletes.filter { $0.kind == .session && $0.winner?.deleted == true }.count == 2, "deleting collapsed session tombstones all known UUID aliases")

var invalidSession = session(99); invalidSession.duration = -1
let invalid = try record(.session, uuid(99).uuidString, invalidSession, device: "bad")
let invalidPref = try record(.preference, "Clockin.RemoteActivityConsent.v2", SyncPreference.bool(true), device: "bad")
var malformed = a; malformed.versions[0].payload = Data("{broken".utf8)
let mixed = try SyncCore.merge(local: known, incoming: [invalid, invalidPref, malformed, unique], onto: original)
check(mixed.quarantine.count == 3 && mixed.snapshot.data.sessions.count == 2, "bad records quarantine per-entry while valid remote data applies")
try check(mixed.quarantine[0].bytes == SyncCoding.encode(invalid), "quarantine preserves offending envelope bytes")
let unseededInvalid = try SyncCore.merge(local: [:], incoming: [invalid], onto: original)
check(unseededInvalid.snapshot.data.sessions == original.data.sessions, "invalid remote cannot empty an unseeded local archive")
var corruptedExisting = session(1); corruptedExisting.duration = -1
let badExisting = try record(.session, uuid(1).uuidString, corruptedExisting, device: "bad", time: 9999)
let keptExisting = try SyncCore.merge(local: known, incoming: [badExisting], onto: original)
check(keptExisting.snapshot.data.sessions == original.data.sessions, "invalid replacement cannot erase existing work")
let wrongType = try record(.preference, "Clockin.GoalDailyHours", SyncPreference.string("eight"), device: "bad")
try check(merge([wrongType]).quarantine.count == 1, "wrong preference type is quarantined")
let archive = try ClockinArchive.read(JSONEncoder().encode(ClockinData(hourlyRate: 25, currencyCode: "USD", sessions: [invalidSession, session(1)])), at: date(100))
check(archive.rejectedCount == 1 && mixed.quarantine.count > 0, "archive and sync share the same duration validator")
var echo = SyncSidecar(deviceID: "receiver"); echo.firstMergeCompleted = true
let received = try echo.receive([a, prefB], snapshot: blank())!
let beforeEcho = echo.pending
try echo.capture(previous: received.snapshot, current: received.snapshot, at: date(999))
check(beforeEcho.isEmpty && echo.pending.isEmpty, "applying remote state creates no echo upload")
let localWins = try SyncCore.merge(local: [b.key: b], incoming: [a], onto: blank())
check(localWins.resend.count == 1 && localWins.snapshot.data.sessions.first?.note == "b", "local-winning conflict resends joined history")
var notices = SyncSidecar(); notices.addRecoveries(competing.recoveries); notices.acknowledgeNotices(competing.notices.map(\.id))
check(notices.notices(competing).isEmpty, "notice acknowledgment prevents repeat presentation")

struct RNG {
    var state: UInt64
    mutating func next(_ n: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 32) % UInt64(n))
    }
    mutating func shuffled<T>(_ values: [T]) -> [T] {
        var result = values
        for i in result.indices.reversed() where i > 0 { result.swapAt(i, next(i + 1)) }
        return result
    }
}
struct Replica {
    var sidecar: SyncSidecar
    var snapshot = blank()
    init(_ id: String) throws {
        sidecar = SyncSidecar(deviceID: id); sidecar.firstMergeCompleted = true
        try sidecar.capture(previous: nil, current: snapshot, at: date(0))
    }
    mutating func edit(_ current: SyncSnapshot, time: Double) throws {
        try sidecar.capture(previous: snapshot, current: current, at: date(time))
        snapshot = try SyncCore.materialize(sidecar.records, onto: current).snapshot
    }
    mutating func receive(_ records: [SyncRecord]) throws {
        snapshot = try sidecar.receive(records, snapshot: snapshot)!.snapshot
    }
}

for seed in 1...30 {
    var rng = RNG(state: UInt64(seed))
    let replicaCount = seed % 2 + 2
    var replicas = try (0..<replicaCount).map { try Replica("device-\($0)") }
    var messages: [(Int, [SyncRecord])] = []
    for step in 1...80 {
        let index = rng.next(replicaCount)
        var next = replicas[index].snapshot
        let id = rng.next(12) + 100
        switch rng.next(12) {
        case 0, 1:
            let value = session(id, start: Double(id * 100), note: "edit-\(seed)-\(step)")
            next.data.sessions.removeAll { $0.id == value.id }; next.data.sessions.append(value)
        case 2: if !next.data.sessions.isEmpty { next.data.sessions.remove(at: rng.next(next.data.sessions.count)) }
        case 3: next.preferences["Clockin.Theme"] = .string("theme-\(rng.next(8))")
        case 4: next.data.hourlyRate = Double(rng.next(100)); next.data.currencyCode = rng.next(2) == 0 ? "USD" : "EUR"
        case 5:
            next.wardrobe.owned.insert(WardrobeCatalog.items[rng.next(8)].id); next.wardrobe.colorway = ["classic", "mint", "sunset", "gold", "stealth"][rng.next(5)]
            next.wardrobe.homeLampOn = rng.next(2) == 0
        case 6:
            let item = ["scarf", "sunglasses", "balloon", "backpack", "wings"][rng.next(5)]
            next.ledger.append(.init(itemID: item, cost: 50 + rng.next(20), date: date(Double(step))))
        case 7: next.data.running = run(Double(step), paused: rng.next(2) == 0)
        case 8:
            if var running = next.data.running {
                running.resumedAt = running.isPaused ? date(Double(step + 100)) : nil
                running.accumulated += Double(rng.next(20)); next.data.running = running
            }
        case 9:
            let ruleID = uuid(50_000 + rng.next(4))
            var rules = next.data.rateRules ?? []
            rules.removeAll { $0.id == ruleID }
            if rng.next(3) != 0 { rules.append(.init(id: ruleID, effectiveFrom: date(0), hourlyRate: Double(rng.next(100)))) }
            next.data.rateRules = rules
        case 10: next.preferences["Clockin.Theme"] = nil
        default:
            if let running = next.data.running {
                let finished = WorkSession(id: uuid(10_000 + seed * 100 + step), start: running.start,
                                           end: date(Double(step + 200)), duration: 30, note: "done", hourlyRate: 25, source: "Clockin")
                next.data.sessions.append(finished); next.data.running = nil
            }
        }
        try replicas[index].edit(next, time: Double(step + rng.next(4)))
        if step % 5 == 0 {
            let records = rng.shuffled(Array(replicas[index].sidecar.records.values))
            for destination in 0..<replicaCount where destination != index {
                messages.append((destination, Array(records.prefix(rng.next(records.count) + 1))))
            }
        }
        if step % 7 == 0 && !messages.isEmpty {
            let message = messages.remove(at: rng.next(messages.count))
            try replicas[message.0].receive(message.1)
        }
    }
    for message in rng.shuffled(messages) { try replicas[message.0].receive(message.1) }
    // Anti-entropy eventually delivers every retained version, with random batching and duplicates.
    let all = rng.shuffled(replicas.flatMap { Array($0.sidecar.records.values) })
    for index in replicas.indices {
        var delivery = rng.shuffled(all + Array(all.prefix(3)))
        while !delivery.isEmpty {
            let n = min(delivery.count, rng.next(9) + 1)
            try replicas[index].receive(Array(delivery.prefix(n))); delivery.removeFirst(n)
        }
    }
    let expected = try bytes(replicas[0].snapshot)
    let history = try SyncCoding.encode(replicas[0].sidecar.records)
    try check(replicas.allSatisfy { try bytes($0.snapshot) == expected && SyncCoding.encode($0.sidecar.records) == history },
              "convergence seed \(seed): \(replicaCount) replicas, 80 edits, random batches/orders, byte-identical state and history")
}

// Disk and integration checks run on the main actor without a test framework.
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clockin-sync-check-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let archiveURL = directory.appendingPathComponent("clockin.json")
let originalBytes = try JSONEncoder().encode(localFirst.data)
try originalBytes.write(to: archiveURL)
let disk = SyncSidecarStore(archiveURL: archiveURL)
var firstSidecar = SyncSidecar(deviceID: "local")
try firstSidecar.capture(previous: nil, current: localFirst, at: date(1000))
_ = try firstSidecar.receive([sharedID, alias, unique], snapshot: localFirst)
let firstPlan = try firstSidecar.preview(snapshot: localFirst)
check(!firstSidecar.firstMergeCompleted && firstSidecar.staged.count == 3, "first sync stages records before approval")
let receipt = try await disk.backup(archiveURL: archiveURL, revision: firstSidecar.revision)
try check(Data(contentsOf: receipt.url) == originalBytes, "first-merge backup preserves exact local archive bytes")
try firstSidecar.commit(firstPlan, backup: receipt)
firstSidecar.engineState = Data("test-engine-checkpoint".utf8)
firstSidecar.systemFields["Session:" + uuid(1).uuidString] = Data([1, 2, 3])
firstSidecar.touch()
try await disk.save(firstSidecar)
let restored = try await disk.load()!
try check(SyncCoding.encode(restored) == SyncCoding.encode(firstSidecar), "sidecar roundtrip preserves device, metadata, pending changes, and first-merge state")
try check(Data(contentsOf: archiveURL) == originalBytes, "sidecar and backup operations never rewrite primary archive")
var stale = SyncSidecar(deviceID: "stale"); stale.touch()
do { try stale.commit(firstPlan, backup: receipt); fatalError("accepted stale preview") }
catch { check(error as? SyncFailure == .stalePreview, "stale first-merge approval is rejected") }
var acknowledged = firstSidecar
let pendingRecord = acknowledged.records.values.first!
var updatedRecord = pendingRecord
updatedRecord.versions.append(.init(stamp: stamp("local", 2000, sequence: 999), payload: pendingRecord.winner!.payload))
acknowledged.queue([updatedRecord])
acknowledged.acknowledge(pendingRecord, systemFields: Data([1, 2, 3]))
check(acknowledged.pending.contains(pendingRecord.key), "old in-flight save acknowledgment cannot clear a newer edit")
let blocking = directory.appendingPathComponent("blocking")
try Data([0]).write(to: blocking)
let brokenDisk = SyncSidecarStore(archiveURL: blocking.appendingPathComponent("clockin.json"))
do { try await brokenDisk.save(firstSidecar); fatalError("expected disk failure") }
catch { try check(Data(contentsOf: archiveURL) == originalBytes, "sidecar disk failure cannot roll back primary save") }
var applied = 0
let bridge = SyncBridge(state: firstSidecar, snapshot: firstPlan.merge.snapshot, disk: disk) { _, _ in applied += 1 }
try bridge.receive([try record(.preference, "Clockin.Theme", SyncPreference.string("Blue"), device: "remote", time: 3000)])
check(applied == 1, "inert bridge delivers remote projection only through application callback")
var malformedIdle = start
malformedIdle.versions[0].payload = Data("{}".utf8)
let rejectedIdle = try merge([malformedIdle])
check(rejectedIdle.quarantine.count == 1, "running wire format requires an explicit state including idle")
var recoveredArchive = firstPlan.merge.snapshot
recoveredArchive.data.sessions.append(session(500, start: 5000))
let relaunchBridge = SyncBridge(state: firstSidecar, snapshot: recoveredArchive, disk: disk) { _, _ in }
try relaunchBridge.reconcileLocalArchive(at: date(3000))
check(relaunchBridge.state.pending.contains("Session:" + uuid(500).uuidString),
      "launch detects primary archive save that preceded a sidecar failure")
let postRemote = bridge.snapshot
try bridge.localDidSave(postRemote, at: date(3001))
check(!bridge.state.pending.contains("Preference:Clockin.Theme"), "bridge save callback after remote apply does not echo")
let rejectedBridge = SyncBridge(state: firstSidecar, snapshot: firstPlan.merge.snapshot, disk: disk) { _, _ in
    throw SyncFailure.invalid("Simulated primary write failure")
}
let beforeRejected = try SyncCoding.encode(rejectedBridge.state)
do { try rejectedBridge.receive([prefB]); fatalError("expected failed apply") }
catch { try check(SyncCoding.encode(rejectedBridge.state) == beforeRejected, "primary apply failure does not advance sync metadata") }
bridge.report("iCloud quota exceeded")
_ = await bridge.persist()
check(bridge.lastError == "iCloud quota exceeded", "sidecar persistence does not hide transport errors")
var approvalState = SyncSidecar(deviceID: "approval")
try approvalState.capture(previous: nil, current: localFirst, at: date(1000))
var approvalBridge: SyncBridge?
var queuedSave: Task<Void, any Error>?
approvalBridge = SyncBridge(state: approvalState, snapshot: localFirst,
                            disk: SyncSidecarStore(archiveURL: directory.appendingPathComponent("approval/clockin.json"))) { merged, _ in
    queuedSave = Task { @MainActor in
        var edited = merged
        edited.data.sessions.append(session(700, start: 7000))
        try approvalBridge!.localDidSave(edited, at: date(4000))
    }
}
approvalBridge!.markFetchComplete(true)
approvalBridge!.allowInitialUploadIfSafe()
check(approvalBridge!.state.permitsUpload && !approvalBridge!.state.firstMergeCompleted,
      "empty cloud permits initial upload without approving a future merge")
try approvalBridge!.receive([unique])
check(approvalBridge!.state.needsFirstMergeReview && !approvalBridge!.state.permitsUpload,
      "first foreign history pauses uploads and requires its own merge preview")
try await approvalBridge!.approveFirstMerge(approvalBridge!.firstPreview(), archiveURL: archiveURL)
try await queuedSave?.value
check(approvalBridge!.state.pending.contains("Session:" + uuid(700).uuidString),
      "local save during first-merge sidecar write is tracked")
var moved = firstSidecar
moved.cloudEnvironment = "Development"
check(moved.bindEnvironment("Production") && !moved.firstMergeCompleted && !moved.permitsUpload
      && moved.engineState == nil && moved.systemFields.isEmpty && moved.pending == moved.records.keys.sorted(),
      "state from another CloudKit environment meets the new server like a new device with history")
try moved.validateLocalBounds(byteCount: SyncCoding.encode(moved).count)
check(!moved.bindEnvironment("Production") && moved.cloudEnvironment == "Production",
      "binding the same environment again keeps sync state")
var untaggedMac = firstSidecar
check(!untaggedMac.bindEnvironment("Production") && untaggedMac.firstMergeCompleted
      && untaggedMac.engineState != nil && untaggedMac.cloudEnvironment == "Production",
      "untagged Mac state is adopted by the environment it runs in")
try await boundedChecks()
emit("All \(checks) sync checks passed.")
