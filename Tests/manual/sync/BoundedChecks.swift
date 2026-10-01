import Foundation

// Fail inside large simulations without printing tens of thousands of identical checks.
func invariant(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw SyncFailure.invalid("CHECK: " + message) }
}

func sample(_ kind: SyncKind, index: Int, device: String = "property") throws -> SyncRecord {
    let time = Double(index + 100)
    switch kind {
    case .session:
        return try record(kind, uuid(9000).uuidString, session(9000, note: "edit-\(index)"),
                          device: device, time: time, deleted: index % 17 == 16)
    case .rateRule:
        return try record(kind, uuid(9001).uuidString, RateRule(id: uuid(9001), effectiveFrom: date(0), hourlyRate: Double(index)),
                          device: device, time: time, deleted: index % 17 == 16)
    case .profile:
        return try record(kind, "Profile", SyncProfile(hourlyRate: Double(index), currencyCode: "USD"), device: device, time: time)
    case .running:
        return try record(kind, "Running", SyncRunning(session: run(Double(index), paused: true)), device: device, time: time)
    case .preference:
        return try record(kind, "Clockin.SeenAccessoryIDs", SyncPreference.strings([WardrobeCatalog.items[index % WardrobeCatalog.items.count].id]), device: device, time: time)
    case .purchase:
        return try record(kind, SyncCore.purchaseName("mint"), WardrobePurchase(itemID: "mint", cost: 100 + index % 5, date: date(Double(index % 7))), device: device, time: time)
    case .wardrobe:
        var value = WardrobeState(); value.owned = [WardrobeCatalog.items[index % WardrobeCatalog.items.count].id]
        value.homeLampOn = index % 2 == 0
        return try record(kind, "WardrobeState", SyncWardrobe(value), device: device, time: time)
    }
}

// Unpruned union is deliberately separate from production join (which already applies P).
func rawUnion(_ a: SyncRecord, _ b: SyncRecord) -> SyncRecord {
    var result = a
    var versions: [String: SyncVersion] = [:]
    for var value in a.versions + b.versions {
        value.parents = Set(value.parents + (versions[value.id]?.parents ?? [])).sorted()
        versions[value.id] = value
    }
    result.versions = Array(versions.values)
    result.maximumStamp = max(a.maximumStamp, b.maximumStamp)
    result.ownership = Set(a.ownership + b.ownership).sorted()
    return result
}

@MainActor func algebraChecks() throws {
    for seed in 1...500 {
        var rng = RNG(state: UInt64(seed))
        for kind in SyncKind.allCases {
            let pool = try (0..<40).map { try sample(kind, index: $0) }
            func subset(_ indexes: [Int]) -> SyncRecord {
                var result = pool[indexes[0]]
                result.versions = indexes.map { pool[$0].versions[0] }
                result.ownership = Set(indexes.flatMap { pool[$0].ownership }).sorted()
                result.maximumStamp = result.versions.map(\.stamp).max()!
                // Valid raw registers have no dangling edges. Pruning may remove these targets.
                for i in result.versions.indices where i > 0 {
                    let earlier = result.versions[..<i].suffix(kind.capacity)
                    result.versions[i].parents = earlier.map(\.id).sorted()
                    result.versions[i].observed = earlier.map(\.stamp).max()
                }
                return result
            }
            // Shared revisions have immutable observed floors; use independent devices per branch.
            var a = subset((0..<40).filter { $0 % 3 == 0 || rng.next(2) == 0 })
            var b = subset((0..<40).filter { $0 % 3 == 1 || rng.next(2) == 0 })
            var c = subset((0..<40).filter { $0 % 3 == 2 || rng.next(2) == 0 })
            for branch in 0..<3 {
                var value = [a, b, c][branch]
                for i in value.versions.indices {
                    value.versions[i].stamp.modifiedBy = "branch-\(branch)"
                    value.versions[i].parents = value.versions[i].parents.map { $0.replacingOccurrences(of: "property:", with: "branch-\(branch):") }
                    value.versions[i].observed?.modifiedBy = "branch-\(branch)"
                }
                value.maximumStamp.modifiedBy = "branch-\(branch)"
                if branch == 0 { a = value } else if branch == 1 { b = value } else { c = value }
            }
            let full = rawUnion(a, b).pruned()
            let bounded = try a.pruned().joined(with: b.pruned())
            try invariant(full == bounded, "prune/join seed \(seed) \(kind)")
            try invariant(bounded == b.pruned().joined(with: a.pruned()), "commutativity")
            try invariant(bounded == bounded.joined(with: bounded), "idempotence")
            try invariant(bounded.joined(with: c.pruned()) == a.pruned().joined(with: b.pruned().joined(with: c.pruned())), "associativity")
            try SyncCore.validate(bounded)
        }
    }
    check(true, "3,500 random register triples: pruning homomorphism, associativity, commutativity, idempotence")

    // A repeated revision can arrive with different projected parent edges.
    var chain = try sample(.profile, index: 0)
    var earlier = chain
    for i in 1...30 {
        var next = try sample(.profile, index: i)
        next.versions[0].parents = chain.versions.map(\.id).sorted()
        next.versions[0].observed = chain.maximumStamp
        chain = try chain.joined(with: next)
        if i == 3 { earlier = chain }
        if i == 5 {
            try check(chain.joined(with: earlier) == chain, "same revision with differently pruned parents joins without identity collision")
        }
    }
    try check(chain.joined(with: earlier) == chain, "stale parent edges cannot regrow a pruned register")
}

@MainActor func limitAndRecoveryChecks() async throws {
    var state = SyncSidecar(deviceID: "recover"); state.firstMergeCompleted = true
    let started = try record(.running, "Running", SyncRunning(session: run(1)), device: "recover", time: 100)
    state.queue([started])
    let applied = try merge([started]).snapshot
    let remote = try record(.running, "Running", SyncRunning(session: run(2)), device: "remote", time: 101)
    let displaced = try state.receive([remote], snapshot: applied)!
    check(state.recoveryInbox.count == 1 && state.recoveryInbox[0].version == started.winner,
          "capture exact applied timer before a remote winner displaces it")
    let inbox = state.recoveryInbox
    _ = try state.receive([started, remote], snapshot: displaced.snapshot)
    check(state.recoveryInbox == inbox, "duplicate/reordered deliveries do not recapture recovery")
    state.acknowledgeNotices(inbox.map(\.id))
    _ = try state.receive([started], snapshot: displaced.snapshot)
    check(state.recoveryInbox.isEmpty && state.acknowledgedNotices.isEmpty, "ack removes payload and ID; stale delivery cannot recreate them")

    let local = try sample(.session, index: 1, device: "recover")
    let winner = try sample(.session, index: 2, device: "remote")
    state.queue([local])
    _ = try state.receive([winner], snapshot: merge([local]).snapshot)
    check(state.recoveryInbox.contains { $0.version == local.winner }, "K=1 captures authored losing edit before pruning")
    var sequential = try sample(.session, index: 3, device: "remote")
    sequential.versions[0].observed = winner.maximumStamp
    let noConflict = try SyncCore.merge(local: [local.key: local], incoming: [sequential], onto: merge([local]).snapshot)
    check(noConflict.recoveries.allSatisfy { $0.reason == "Replaced value" }, "sequential replacement after ancestor pruning never reports a conflict")

    // Count cap and one notice through an uninterrupted overflow episode.
    state.recoveryInbox = []
    for i in 0..<80 {
        let value = try sample(.running, index: i).winner!
        state.addRecoveries([.init(recordKey: "Running:Running", version: value, reason: "Displaced timer")])
    }
    check(state.recoveryInbox.count == 50 && state.recoveryInbox.first?.version.stamp.sequence == 130,
          "recovery count cap evicts oldest unacknowledged entries")
    check(state.activeNotices.filter { $0.id == "recovery-overflow" }.count == 1, "one recovery overflow notice per episode")
    state.acknowledgeNotices(["recovery-overflow"])
    state.addRecoveries([.init(recordKey: "Running:Running", version: try sample(.running, index: 81).winner!, reason: "Displaced timer")])
    check(!state.activeNotices.contains { $0.id == "recovery-overflow" }, "further evictions do not repeat acknowledged overflow notice")
    state.acknowledgeNotices(state.recoveryInbox.map(\.id))
    check(!state.recoveryOverflow && state.acknowledgedNotices.isEmpty, "review drains overflow episode and its acknowledgment")
    for i in 0..<40 {
        var value = session(9100 + i, note: String(repeating: "\u{0001}", count: 2000))
        value.source = "CSV"
        let r = try record(.session, value.id.uuidString, value, time: Double(200 + i))
        try SyncCore.validate(r)
        state.addRecoveries([.init(recordKey: r.key, version: r.winner!, reason: "Concurrent edit")])
    }
    check(state.recoveryInbox.count < 40 && SyncBounds.size(state.recoveryInbox) <= SyncBounds.recoveryBytes && state.recoveryOverflow,
          "256 KB recovery cap counts encoded bytes and starts a new overflow episode")
    let retained = state.recoveryInbox
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("bounded-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: temp) }
    let store = SyncSidecarStore(archiveURL: temp.appendingPathComponent("clockin.json"))
    try await store.save(state)
    let loaded = try await store.load()!
    check(loaded.recoveryInbox == retained && loaded.recoveryOverflow, "recovery inbox and overflow survive durable restart")

    for i in 0..<130 { state.addQuarantine([.init(recordKey: "bad-\(i)", bytes: Data([1]), reason: "invalid")]) }
    check(state.quarantine.count == 100 && state.quarantine.first?.recordKey == "bad-30", "quarantine count cap evicts oldest")
    for i in 0..<20 { state.addQuarantine([.init(recordKey: "large-\(i)", bytes: Data(repeating: 1, count: 100_000), reason: "invalid")]) }
    check(SyncBounds.size(state.quarantine) <= SyncBounds.quarantineBytes && state.quarantine.count < 20,
          "1 MB quarantine cap counts base64 and metadata")
    state.addQuarantine([.init(recordKey: "too-large", bytes: Data(repeating: 2, count: 2_000_000), reason: "invalid")])
    check(state.quarantine.isEmpty && state.activeNotices.contains { $0.id == "quarantine-overflow" },
          "single oversized quarantine entry is evicted whole with notice")
    state.acknowledgeNotices(["quarantine-overflow"])
    check(!state.quarantineOverflow && !state.acknowledgedNotices.contains("quarantine-overflow"), "quarantine acknowledgment drops with ended episode")
    for i in 0..<20 {
        let future = try record(.purchase, SyncCore.purchaseName("future-\(i)"), WardrobePurchase(itemID: "future-\(i)", cost: 1, date: date(1)))
        let result = try merge([future])
        state.addQuarantine(result.quarantine)
    }
    check(state.quarantine.filter(\.futureCatalog).count == 16 && state.quarantineOverflow,
          "future catalog envelopes retained opaquely in sixteen-entry allowance")

    var initial = blank(); initial.data.sessions = [session(9200)]
    initial.preferences["Clockin.Theme"] = .string("Carbon")
    var seeded = SyncSidecar(deviceID: "limits"); seeded.firstMergeCompleted = true
    try seeded.capture(previous: nil, current: initial, at: date(100))
    let bridge = SyncBridge(state: seeded, snapshot: initial, disk: store) { _, _ in }
    var oversized = initial
    oversized.data.sessions[0].note = String(repeating: "n", count: 2001)
    oversized.preferences["Clockin.Theme"] = .string(String(repeating: "x", count: 257))
    oversized.data.hourlyRate = 77
    try bridge.localDidSave(oversized, at: date(200))
    check(bridge.localErrors.count == 2 && bridge.lastError != nil && bridge.localErrors[0].messageKey == "sync.localValueInvalid",
          "local limit errors surfaced as localizable bridge issues")
    check(!bridge.state.pending.contains("Session:" + uuid(9200).uuidString)
          && !bridge.state.pending.contains("Preference:Clockin.Theme") && bridge.state.pending.contains("Profile:Profile"),
          "over-limit records stay local-only while valid sibling edit uploads")
    let replacement = try record(.session, uuid(9200).uuidString, session(9200, note: "remote"), device: "remote", time: 500)
    try bridge.receive([replacement])
    check(bridge.snapshot.data.sessions[0].note.count == 2001 && bridge.localErrors.count == 2,
          "remote merge cannot overwrite an invalid locally saved value")
    try bridge.localDidSave(bridge.snapshot, at: date(501))
    check(bridge.localErrors.count == 2, "unchanged invalid values keep their local-only errors")
    var fixed = bridge.snapshot; fixed.data.sessions[0].note = "fixed"; fixed.preferences["Clockin.Theme"] = .string("Paper")
    try bridge.localDidSave(fixed, at: date(502))
    check(bridge.localErrors.isEmpty && bridge.state.pending.contains(replacement.key), "editing within limits clears errors and resumes upload")
    var bad = replacement; var badSession = session(9200, note: String(repeating: "x", count: 2001))
    bad.versions[0].payload = try SyncCoding.encode(badSession)
    try check(merge([bad]).quarantine.count == 1, "remote oversized note quarantined")
    badSession.note = "a" + String(repeating: "\u{0301}", count: 9000)
    bad.versions[0].payload = try SyncCoding.encode(badSession)
    try check(merge([bad]).quarantine.count == 1, "unbounded combining-scalar grapheme rejected by byte limit")
    let array = try record(.preference, "Clockin.SeenAccessoryIDs", SyncPreference.strings(Array(repeating: "mint", count: 257)))
    try check(merge([array]).quarantine.count == 1, "remote string array exceeds 256 entries")
    let string = try record(.preference, "Clockin.Theme", SyncPreference.string(String(repeating: "x", count: 257)))
    try check(merge([string]).quarantine.count == 1, "remote preference string exceeds 256 characters")
    var mismatch = replacement; mismatch.sessionFact = .init(clockinStart: date(1000))
    try check(SyncCore.merge(local: [replacement.key: replacement], incoming: [mismatch], onto: initial).quarantine.count == 1,
              "disagreeing immutable clockinStart is quarantined")

    var facts = try sample(.wardrobe, index: 0)
    var seen = try sample(.preference, index: 0)
    for i in 1..<WardrobeCatalog.items.count {
        facts = try facts.joined(with: sample(.wardrobe, index: i))
        seen = try seen.joined(with: sample(.preference, index: i))
    }
    check(facts.versions.count == 8 && facts.ownership.count == WardrobeCatalog.items.count
          && seen.ownership == facts.ownership, "ownership and seen facts survive every originating payload being pruned")
    var purchase = try sample(.purchase, index: 0)
    for i in 1...100 { purchase = try purchase.joined(with: sample(.purchase, index: i)) }
    let selected = try SyncCoding.decode(WardrobePurchase.self, purchase.winner!.payload)
    check(purchase.versions.count == 3 && selected.date == date(0) && selected.cost == 100
          && purchase.maximumStamp == stamp("property", 200), "purchase retains earliest winner plus two and unpruned maximum stamp")

    var closed = SyncSidecar(deviceID: "closed"); closed.firstMergeCompleted = true
    var before = blank(); before.data.sessions = [session(9300)]
    try closed.capture(previous: nil, current: before, at: date(100))
    for i in 1...20 {
        var next = before; next.data.sessions[0].start = date(Double(i)); next.data.sessions[0].end = date(Double(i + 100))
        if i >= 10 { next.data.sessions[0].source = "CSV" }
        try closed.capture(previous: before, current: next, at: date(Double(100 + i))); before = next
    }
    var after = before; after.data.sessions = []
    try closed.capture(previous: before, current: after, at: date(200))
    let dead = closed.records["Session:" + uuid(9300).uuidString]!
    let stalePause = try record(.running, "Running", SyncRunning(session: run(0, paused: true)), device: "offline", time: 1_000_000)
    let projected = try closed.receive([stalePause], snapshot: after)!
    check(dead.versions.count == 1 && dead.winner!.payload.isEmpty && dead.sessionFact?.clockinStart == date(0)
          && projected.snapshot.data.running == nil, "edited then deleted session keeps original start and defeats arbitrarily newer stale pause")
    let oldEdit = try record(.session, uuid(9300).uuidString, session(9300), device: "old", time: 2_000_000)
    _ = try closed.receive([oldEdit], snapshot: projected.snapshot)
    check(closed.records[dead.key]?.winner?.deleted == true, "permanent deletion outranks arbitrarily newer offline live revision")

    var unseeded = blank(); unseeded.data.running = run(0)
    try check(merge([dead], onto: unseeded).snapshot.data.running == nil,
              "durable completion closes a local run even before a Running register exists")
    var localLedger = blank()
    localLedger.ledger = [.init(itemID: "future-item", cost: 7, date: date(1))]
    var ledgerState = SyncSidecar(deviceID: "ledger"); ledgerState.firstMergeCompleted = true
    try ledgerState.capture(previous: nil, current: localLedger, at: date(200))
    let knownPurchase = try record(.purchase, SyncCore.purchaseName("mint"), WardrobePurchase(itemID: "mint", cost: 200, date: date(1)))
    let joinedLedger = try ledgerState.receive([knownPurchase], snapshot: localLedger)!.snapshot.ledger
    check(Set(joinedLedger.map(\.itemID)) == ["future-item", "mint"],
          "one local-only purchase preserves itself without hiding valid remote ledger entries")

    var stage = SyncSidecar(deviceID: "stage")
    for i in 0..<100 { _ = try stage.receive([sample(.running, index: i)], snapshot: blank()) }
    check(stage.staged["Running:Running"]?.versions.count == 8 && stage.recoveryInbox.isEmpty,
          "unapproved staged records prune without generating unapplied recovery")
    var gate = SyncSidecar(deviceID: "gate")
    _ = try gate.receive([record(.preference, "Clockin.Theme", SyncPreference.string("foreign"), device: "foreign", time: 1)], snapshot: blank())
    for i in 2...12 {
        _ = try gate.receive([record(.preference, "Clockin.Theme", SyncPreference.string("local"), device: "gate", time: Double(i))], snapshot: blank())
    }
    check(gate.needsFirstMergeReview, "pruning all foreign staged revisions cannot erase first-merge approval gate")

    let unseen = try record(.preference, "Clockin.Theme", SyncPreference.string("unseen"), device: "author", time: 100)
    let unseenReplacement = try record(.preference, "Clockin.Theme", SyncPreference.string("new"), device: "winner", time: 101)
    var observer = SyncSidecar(deviceID: "observer"); observer.firstMergeCompleted = true; observer.queue([unseen])
    _ = try observer.receive([unseenReplacement], snapshot: blank())
    check(observer.recoveryInbox.isEmpty, "unapplied remote loser cannot generate local recovery")
    var author = SyncSidecar(deviceID: "author"); author.firstMergeCompleted = true; author.queue([unseen])
    _ = try author.receive([unseenReplacement], snapshot: blank())
    check(author.recoveryInbox.count == 1, "remote winner captures this device's authored revision even when no longer applied")

    var swept = SyncSidecar(deviceID: "recover"); swept.firstMergeCompleted = true; swept.queue([started])
    let sweep = try (200..<212).map { try sample(.running, index: $0, device: "remote") }
    _ = try swept.receive(sweep, snapshot: applied)
    check(swept.records[started.key]?.versions.contains(where: { $0.id == started.winner!.id }) == false
          && swept.recoveryInbox.first?.version == started.winner,
          "displacement captures a revision that is pruned in the same incoming batch")

    let edgeNote = try record(.session, uuid(9500).uuidString, session(9500, note: String(repeating: "x", count: 2000)))
    let edgeString = try record(.preference, "Clockin.Theme", SyncPreference.string(String(repeating: "x", count: 256)))
    let edgeArray = try record(.preference, "Clockin.SeenAccessoryIDs", SyncPreference.strings(Array(repeating: "mint", count: 256)))
    try check(merge([edgeNote, edgeString, edgeArray]).quarantine.isEmpty, "exact note/string/array character-count boundaries accepted")
    var overRun = run(0); overRun.note = String(repeating: "x", count: 2001)
    let remoteOverRun = try record(.running, "Running", SyncRunning(session: overRun))
    try check(merge([remoteOverRun]).quarantine.count == 1, "running note uses same remote note limit")
    var localOverRun = blank(); localOverRun.data.running = overRun
    var runLimits = SyncSidecar(deviceID: "run-limits"); runLimits.firstMergeCompleted = true
    try runLimits.capture(previous: nil, current: localOverRun, at: date(100))
    check(runLimits.localIssues.map(\.recordKey) == ["Running:Running"] && runLimits.records["Running:Running"] == nil,
          "oversized local running note remains local-only")
    try await store.save(runLimitsWithNewRevision(runLimits, after: loaded.revision))
    let errorReload = try await store.load()!
    check(errorReload.localIssues == runLimits.localIssues, "local-only issue survives sidecar restart")

    bridge.updateEngineState(Data(repeating: 1, count: SyncBounds.engineBytes + 1))
    check(bridge.state.engineState == nil && bridge.lastError != nil, "oversized engine checkpoint dropped with explicit refetch notice")
    bridge.rememberSystemFields(Data(repeating: 1, count: SyncBounds.systemFieldBytes), for: replacement.key)
    check(bridge.state.systemFields[replacement.key]?.count == SyncBounds.systemFieldBytes, "system-field exact byte cap accepted")
    bridge.rememberSystemFields(Data(repeating: 1, count: SyncBounds.systemFieldBytes + 1), for: replacement.key)
    bridge.rememberSystemFields(Data([1]), for: "unknown")
    check(bridge.state.systemFields[replacement.key] == nil && bridge.state.systemFields["unknown"] == nil,
          "oversized and unknown-identity system fields cannot grow sidecar")

    var conflictSource = blank()
    conflictSource.data.sessions = (1...110).map { session(9600 + $0, start: Double($0 * 100)) }
    var conflicts = SyncSidecar(deviceID: "conflicts"); conflicts.firstMergeCompleted = true
    try conflicts.capture(previous: nil, current: conflictSource, at: date(20000))
    let disagreeing = conflicts.records.values.filter { $0.kind == .session }.map { value -> SyncRecord in
        var result = value; result.sessionFact = .init(clockinStart: date(99999)); return result
    }
    let conflictBridge = SyncBridge(state: conflicts, snapshot: conflictSource, disk: store) { _, _ in }
    let rejected = try conflictBridge.receive(disagreeing)
    check(Set(rejected) == Set(disagreeing.map(\.key)) && conflictBridge.state.quarantine.count == 100,
          "all 110 rejected keys reach transport even when quarantine evicts ten envelopes")
    var stagedRejections: [String] = []
    conflicts.firstMergeCompleted = false; conflicts.staged = conflicts.records
    _ = try conflicts.receive(disagreeing, snapshot: conflictSource, onReject: { stagedRejections = $0 })
    check(Set(stagedRejections) == Set(rejected), "staged rejection reporting also survives quarantine eviction")

    var invalidFirst = SyncSidecar(deviceID: "invalid-first")
    var firstLocal = blank(); firstLocal.data.sessions = [session(9800, note: String(repeating: "x", count: 2001))]
    try invalidFirst.capture(previous: nil, current: firstLocal, at: date(100))
    _ = try invalidFirst.receive([record(.session, uuid(9800).uuidString, session(9800), device: "remote", deleted: true)], snapshot: firstLocal)
    let firstPlan = try invalidFirst.preview(snapshot: firstLocal)
    check(firstPlan.mergedCount == 1 && firstPlan.merge.snapshot.data.sessions.count == 1 && firstPlan.duplicates == 0,
          "first-merge preview counts include preserved local-only sessions")

    // Remote observed an unrelated higher stamp, so the floor masks actual concurrency.
    // This must still capture the applied loser, using neutral rather than unproven conflict copy.
    var masked = try sample(.session, index: 5, device: "different")
    masked.versions[0].observed = stamp("unrelated", 104)
    let maskedMerge = try SyncCore.merge(local: [local.key: local], incoming: [masked], onto: merge([local]).snapshot)
    check(maskedMerge.recoveries.first?.version == local.winner && maskedMerge.recoveries.first?.reason == "Replaced value",
          "uncertain concurrency preserves the losing payload without asserting a conflict")
    var attemptedRestore = after; attemptedRestore.data.sessions = [session(9300, note: "offline edit of deleted identity")]
    try closed.capture(previous: after, current: attemptedRestore, at: date(2_000_001))
    check(closed.records[dead.key]?.winner?.deleted == true && closed.recoveryInbox.contains {
        (try? SyncCoding.decode(WorkSession.self, $0.version.payload).note) == "offline edit of deleted identity"
    }, "local edit that loses immediately to a permanent tombstone enters recovery before pruning")

}

func runLimitsWithNewRevision(_ state: SyncSidecar, after revision: UInt64) -> SyncSidecar {
    var result = state; result.revision = revision + 1; return result
}

@MainActor func envelopeChecks() throws {
    var budget = SyncSidecar(deviceID: String(repeating: "d", count: 128))
    for kind in SyncKind.allCases {
        var value = try sample(kind, index: 1)
        var object = try JSONSerialization.jsonObject(with: value.winner!.payload) as! [String: Any]
        object["padding"] = ""
        let empty = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        object["padding"] = String(repeating: "x", count: kind.payloadBytes - empty.count)
        let payload = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        value.versions = (0..<kind.capacity).map { i in
            .init(stamp: .init(modifiedAt: date(Double(i + 100)), modifiedBy: String(repeating: "d", count: 128), sequence: UInt64.max - UInt64(kind.capacity - i)),
                  payload: payload)
        }
        value.maximumStamp = value.versions.last!.stamp
        for i in value.versions.indices where i > 0 {
            value.versions[i].parents = value.versions[..<i].map(\.id).sorted()
            value.versions[i].observed = value.versions[i - 1].stamp
        }
        if kind == .wardrobe || kind == .preference { value.ownership = SyncBounds.catalog.sorted() }
        try SyncCore.validate(value)
        budget.queue([value]); budget.staged[value.key] = value
        budget.rememberSystemFields(Data(repeating: 1, count: SyncBounds.systemFieldBytes), for: value.key)
        let size = SyncBounds.size(value)
        check(size < kind.envelopeBound && kind.envelopeBound < SyncBounds.envelopeBytes,
              "worst payload \(kind.rawValue): \(size) B < bound \(kind.envelopeBound) B < defensive 524288 B")
    }
    budget.accountID = String(repeating: "\u{0001}", count: 1024)
    budget.firstBackupPath = String(repeating: "\u{0001}", count: 1024)
    budget.engineState = Data(repeating: 1, count: SyncBounds.engineBytes)
    for i in 0..<100 {
        budget.addQuarantine([.init(recordKey: "bad-\(i)", bytes: Data(repeating: 2, count: 7700), reason: "invalid")])
        var version = budget.records["Session:" + uuid(9000).uuidString]!.winner!
        version.stamp.sequence = UInt64(i)
        budget.addRecoveries([.init(recordKey: "Session:" + uuid(9000).uuidString, version: version, reason: "Concurrent edit")])
    }
    let size = SyncBounds.size(budget)
    try budget.validateLocalBounds(byteCount: size)
    check(size <= budget.byteBound, "simultaneously populated sidecar ceilings: \(size) B < bound \(budget.byteBound) B")
    var tooMany = try sample(.running, index: 0)
    tooMany.versions = try (0..<9).map { try sample(.running, index: $0).winner! }
    tooMany.maximumStamp = tooMany.versions.last!.stamp
    try check(merge([tooMany]).quarantine.count == 1, "remote register over K is quarantined")
    var dangling = try sample(.profile, index: 2); dangling.versions[0].parents = ["absent:1"]
    try check(merge([dangling]).quarantine.count == 1, "remote dangling causal parent is quarantined")
    let identity = try sample(.profile, index: 1)
    var reused = identity; reused.versions[0].payload = try SyncCoding.encode(SyncProfile(hourlyRate: 99, currencyCode: "USD"))
    try check(SyncCore.merge(local: [identity.key: identity], incoming: [reused], onto: blank()).quarantine.count == 1,
              "retained revision identity cannot be reused with different immutable content")

}

@MainActor func boundedChecks() async throws {
    try algebraChecks()
    try await limitAndRecoveryChecks()
    try envelopeChecks()
    if !CommandLine.arguments.contains("--quick") { try longRunChecks() }
}

struct LongReplica {
    var state: SyncSidecar
    var snapshot = blank()
    var encoded: [String: (SyncRecord, Int)] = [:]
    var maximumEnvelope: [SyncKind: Int] = [:]
    var maximumSidecar = 0
    var boundAtMaximum = 0
    var mutations = 0

    init(_ id: String) throws {
        state = .init(deviceID: id); state.firstMergeCompleted = true
        try state.capture(previous: nil, current: snapshot, at: date(0))
        try measure()
    }
    mutating func edit(previous: SyncSnapshot, current: SyncSnapshot, time: Double) throws {
        // A synthetic store supplies just the changed domain; both snapshots omit the same others.
        // This avoids repeatedly encoding every immutable daily session in the load generator.
        try state.capture(previous: previous, current: current, at: date(time))
        snapshot = try SyncCore.materialize(state.records, onto: snapshot).snapshot
        try invariant(state.localIssues.isEmpty, "simulation generated invalid local data")
        try measure()
    }
    mutating func receive(_ values: [SyncRecord]) throws {
        snapshot = try state.receive(values, snapshot: snapshot)!.snapshot
        try invariant(state.quarantine.isEmpty, "simulation quarantined a valid register")
        try measure()
    }
    mutating func measure() throws {
        mutations += 1
        var recordContribution = 0
        for (key, record) in state.records {
            if encoded[key]?.0 != record {
                try SyncCore.validate(record)
                let size = SyncBounds.size(record)
                try invariant(size <= record.kind.envelopeBound, "per-kind envelope bound")
                encoded[key] = (record, size)
                maximumEnvelope[record.kind] = max(maximumEnvelope[record.kind] ?? 0, size)
            }
            recordContribution += SyncBounds.size(key) + 1 + encoded[key]!.1
        }
        recordContribution += max(0, state.records.count - 1)
        // Exact JSON object additivity: {} is already in the shell; insert key:value pairs and commas.
        // Cross-check this against the full encoder periodically and after final convergence.
        var shell = state; shell.records = [:]
        let size = SyncBounds.size(shell) + recordContribution
        try invariant(size <= state.byteBound, "sidecar formula at mutation \(mutations)")
        if mutations % 500 == 0 { try invariant(size == SyncBounds.size(state), "incremental size equals full serialization") }
        if size > maximumSidecar { maximumSidecar = size; boundAtMaximum = state.byteBound }
        try invariant(state.recoveryInbox.count <= 50 && SyncBounds.size(state.recoveryInbox) <= SyncBounds.recoveryBytes, "local recovery bound")
        if let running = snapshot.data.running {
            try invariant(!state.records.values.contains { $0.sessionFact?.clockinStart == running.start }, "closed run resurrected")
        }
        for record in state.records.values where record.kind.removeWins && record.versions.contains(where: \.deleted) {
            try invariant(record.winner?.deleted == true, "deleted identity resurrected")
        }
    }
}

@MainActor func longRunChecks() throws {
    var rng = RNG(state: 0x07B2026)
    var replicas = try (0..<3).map { try LongReplica("long-\($0)") }
    var offlineUntil = [0, 0, 1200]
    var longestOffline = 1200
    var stale: [SyncRecord] = []
    var offlineEpisodes = 1
    let days = 5 * 365 + 2
    for day in 1...days {
        let index = rng.next(3)
        let time = Double(day * 86_400)
        var previous = blank(); previous.data.running = replicas[index].snapshot.data.running
        var current = previous; current.data.running = run(time)
        current.preferences["Clockin.Theme"] = .string("theme-\(day % 9)")
        previous.preferences["Clockin.Theme"] = replicas[index].snapshot.preferences["Clockin.Theme"]
        try replicas[index].edit(previous: previous, current: current, time: time + 1)
        for operation in 1...4 {
            previous = blank(); previous.data.running = replicas[index].snapshot.data.running
            current = previous
            current.data.running?.resumedAt = operation % 2 == 1 ? nil : date(time + Double(operation * 300))
            current.data.running?.accumulated += 300
            current.preferences["Clockin.ChimeIntervalMinutes"] = .integer(15 + operation + day % 4)
            previous.preferences["Clockin.ChimeIntervalMinutes"] = replicas[index].snapshot.preferences["Clockin.ChimeIntervalMinutes"]
            try replicas[index].edit(previous: previous, current: current, time: time + Double(operation * 300) + 1)
        }
        // Occasional abandoned unfinished timers exercise inbox capture during later replacement.
        if day % 31 != 0 {
            previous = blank(); previous.data.running = replicas[index].snapshot.data.running
            current = previous; current.data.running = nil
            current.data.sessions = [session(100_000 + day, start: time, note: "Day \(day)")]
            try replicas[index].edit(previous: previous, current: current, time: time + 3600)
        }
        if day % 9 == 0 {
            previous = blank(); previous.wardrobe = replicas[index].snapshot.wardrobe
            current = previous; current.wardrobe.homeLampOn.toggle()
            current.wardrobe.owned.insert(WardrobeCatalog.items[day % WardrobeCatalog.items.count].id)
            current.preferences["Clockin.SeenAccessoryIDs"] = .strings(current.wardrobe.owned.sorted())
            previous.preferences["Clockin.SeenAccessoryIDs"] = replicas[index].snapshot.preferences["Clockin.SeenAccessoryIDs"]
            try replicas[index].edit(previous: previous, current: current, time: time + 4000)
        }
        if day % 23 == 0, let value = replicas[index].snapshot.data.sessions.first {
            previous = blank(); previous.data.sessions = [value]; current = previous
            current.data.sessions[0].note = "Corrected on day \(day)"
            current.data.sessions[0].start = value.start.addingTimeInterval(1)
            try replicas[index].edit(previous: previous, current: current, time: time + 4100)
        }
        if day % 29 == 0, let value = replicas[index].snapshot.data.sessions.first {
            previous = blank(); previous.data.sessions = [value]; current = blank()
            try replicas[index].edit(previous: previous, current: current, time: time + 4200)
        }
        if day % 30 == 0 {
            previous = blank(); previous.data.rateRules = replicas[index].snapshot.data.rateRules
            current = previous
            current.data.rateRules = [.init(id: uuid(200_000), effectiveFrom: date(0), hourlyRate: Double(25 + day % 100))]
            previous.data.hourlyRate = replicas[index].snapshot.data.hourlyRate
            current.data.hourlyRate = Double(25 + day % 100)
            current.ledger = [.init(itemID: "mint", cost: 200, date: date(time))]
            previous.ledger = replicas[index].snapshot.ledger
            try replicas[index].edit(previous: previous, current: current, time: time + 4300)
        }
        for device in replicas.indices where offlineUntil[device] <= day && rng.next(100) == 0 {
            let length = [7, 30, 180, 900][rng.next(4)]
            offlineUntil[device] = day + length; longestOffline = max(longestOffline, length); offlineEpisodes += 1
        }
        let online = replicas.indices.filter { offlineUntil[$0] <= day }
        if day % 7 == 0 && online.count > 1 {
            let values = rng.shuffled(online.flatMap { Array(replicas[$0].state.records.values) })
            for destination in online { try replicas[destination].receive(rng.shuffled(values + Array(values.prefix(2)))) }
            let expected = try SyncCoding.encode(replicas[online[0]].state.records)
            let expectedProjection = try bytes(replicas[online[0]].snapshot)
            try invariant(online.allSatisfy { try SyncCoding.encode(replicas[$0].state.records) == expected
                && bytes(replicas[$0].snapshot) == expectedProjection }, "online anti-entropy convergence")
        }
        if day == 30 { stale = Array(replicas[2].state.records.values) }
        if day % 365 == 0 { emit("simulation completed year \(day / 365), identities \(replicas.map { $0.state.records.count })") }
    }
    let all = rng.shuffled(replicas.flatMap { Array($0.state.records.values) })
    for i in replicas.indices { try replicas[i].receive(rng.shuffled(all + Array(all.prefix(10)))) }
    let registers = try SyncCoding.encode(replicas[0].state.records)
    let projection = try bytes(replicas[0].snapshot)
    try check(replicas.allSatisfy { try SyncCoding.encode($0.state.records) == registers && bytes($0.snapshot) == projection },
              "five years / three replicas converge in projection and every retained register byte")
    for i in replicas.indices {
        let recoveries = replicas[i].state.recoveryInbox
        let notices = replicas[i].state.activeNotices
        try replicas[i].receive(rng.shuffled(stale + stale))
        try invariant(SyncCoding.encode(replicas[i].state.records) == registers, "old replica changed winner/register")
        try invariant(replicas[i].state.recoveryInbox == recoveries && replicas[i].state.activeNotices == notices, "old replica generated stale notices")
        try invariant(SyncBounds.size(replicas[i].state) <= replicas[i].state.byteBound, "full final sidecar bound")
    }
    check(true, "1,797-day-old replica replay changes no winners, registers, recoveries or notices")
    let mutations = replicas.reduce(0) { $0 + $1.mutations }
    check(true, "\(days) daily-use days, \(mutations) measured mutations, \(offlineEpisodes) offline episodes; longest \(longestOffline) days")
    for kind in SyncKind.allCases {
        let maximum = replicas.map { $0.maximumEnvelope[kind] ?? 0 }.max()!
        emit("LONG-RUN envelope \(kind.rawValue): maximum \(maximum), bound \(kind.envelopeBound) bytes")
    }
    for replica in replicas {
        emit("LONG-RUN sidecar \(replica.state.deviceID): maximum \(replica.maximumSidecar), bound then \(replica.boundAtMaximum), final identities \(replica.state.records.count) bytes")
    }
}
