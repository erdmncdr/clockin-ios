import Foundation

@MainActor final class FakeBatch: SyncBatchSource {
    var pendingIDs: [String] = []
    var scope: Set<String> = []
    var bridgeRecords: [String: Int] = [:]
    var removed: [String] = []
    func contains(_ id: String) -> Bool { scope.contains(id) }
    func record(for id: String) -> (String, bytes: Int)? {
        bridgeRecords[id].map { (id, $0) }
    }
    func removeUnavailable(_ id: String) { removed.append(id) }
}

@main struct SendChecks {
    @MainActor static var count = 0
    @MainActor static func check(_ value: Bool, _ name: String) {
        guard value else { fatalError("FAILED: " + name) }
        count += 1; print("ok: " + name)
    }
    @MainActor static func main() async {
        let source = FakeBatch()
        source.bridgeRecords = ["engine-one": 100, "engine-two": 150, "bridge-only": 1, "outside": 100]
        source.scope = ["engine-one", "engine-two", "missing", "bridge-only"]
        source.pendingIDs = ["engine-one", "missing", "engine-two", "outside", "missing-outside"]
        check(SyncBatchBuilder.build(source) == ["engine-one", "engine-two"], "batch uses engine pending list and requested scope only")
        check(source.removed == ["missing"], "missing scoped body is removed from engine pending state")
        check(SyncBatchBuilder.build(source, limit: 1) == ["engine-one"], "batch enforces record count")
        check(SyncBatchBuilder.build(source, byteLimit: 200) == ["engine-one"], "batch enforces aggregate payload limit")
        source.pendingIDs = []
        check(SyncBatchBuilder.build(source).isEmpty && !source.bridgeRecords.isEmpty, "bridge-pending failed record cannot reenter an empty engine batch")

        check(SyncSendFailure.serverRecordChanged.action == .join, "serverRecordChanged retries only joined record")
        check(SyncSendFailure.unknownItem.action == .clearFields, "unknownItem retries only cleared record")
        check(SyncSendFailure.zoneNotFound.action == .rebuildZone, "zoneNotFound rebuilds zone and retained records")
        for error in [SyncSendFailure.networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                      .requestRateLimited, .notAuthenticated, .operationCancelled] {
            check(error.action == .engineRetry, "\(error) leaves retry ownership with engine")
        }
        check(SyncSendFailure.other.action == .deferToNextPass, "other errors remain in bridge until a later pass")

        var pass = SyncSendPass()
        check(pass.request(), "first trigger starts a pass")
        let coalesced = (0..<100).map { _ in !pass.request() }
        check(coalesced.allSatisfy { $0 }, "100 in-flight triggers coalesce")
        for _ in 0..<3 { check(pass.permitReadd("record"), "record recovery retry within cap") }
        check(!pass.permitReadd("record") && pass.deferred.contains("record"), "fourth re-add is deferred")
        check(pass.permitReadd("another"), "retry cap is per record")
        pass.deferRecord("permanent")
        check(!pass.permitReadd("permanent"), "permanent error is never re-added within current pass")
        check(pass.finishPass(), "burst produces one follow-up pass")
        check(pass.permitReadd("record") && pass.permitReadd("permanent"), "new pass resets retry budget and deferrals")
        check(!pass.finishPass() && !pass.running, "follow-up without new triggers ends loop")
        check(pass.request(), "next independent trigger starts normally")
        _ = pass.request(); pass.cancel()
        check(!pass.running && !pass.rerunRequested, "stop clears pending rerun")

        var backoff = SyncLaunchBackoff()
        check((0..<8).map { _ in backoff.nextDelay() } == [5, 10, 20, 40, 80, 160, 300, 300],
              "transient launch failures use capped exponential backoff")
        check(backoff.nextDelay(minimum: 600) == 600, "launch backoff respects server retryAfter")
        backoff.reset()
        check(backoff.nextDelay() == 5, "successful launch resets backoff")

        let clock = ManualSyncClock()
        let wakeup = SyncWakeup(clock: clock)
        var fires = 0
        let first = TestSignal()
        let deadline = clock.now.addingTimeInterval(5)
        wakeup.schedule(at: deadline) { fires += 1; first.signal() }
        await clock.registered(1)
        wakeup.schedule(at: deadline) { fires += 100 }
        check(clock.registrations == 1 && wakeup.deadline == deadline, "same retry deadline is coalesced")
        clock.advance(4)
        check(fires == 0, "retry cannot fire before retryAfter")
        clock.advance(1)
        await first.wait()
        check(fires == 1 && wakeup.deadline == nil, "retry fires automatically and clears scheduled state")

        let second = TestSignal()
        wakeup.schedule(at: clock.now.addingTimeInterval(2)) { fires += 100 }
        await clock.registered(2)
        wakeup.schedule(at: clock.now.addingTimeInterval(8)) { fires += 1; second.signal() }
        await clock.registered(3)
        clock.advance(8)
        await second.wait()
        check(fires == 2, "extending retryAfter cancels the earlier sleep")
        wakeup.schedule(at: clock.now.addingTimeInterval(1)) { fires += 100 }
        await clock.registered(4)
        wakeup.cancel()
        let third = TestSignal()
        wakeup.schedule(at: clock.now.addingTimeInterval(2)) { fires += 1; third.signal() }
        await clock.registered(5)
        clock.advance(2)
        await third.wait()
        check(fires == 3, "cancelled sleep cannot invoke stale retry action")
        clock.drain()
        print("All \(count) offline send checks passed.")
    }
}
