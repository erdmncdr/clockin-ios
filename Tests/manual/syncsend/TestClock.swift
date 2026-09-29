import Foundation

@MainActor final class ManualSyncClock: SyncClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    private(set) var registrations = 0
    private var sleepers: [(Date, CheckedContinuation<Void, Never>)] = []
    private var observers: [(Int, CheckedContinuation<Void, Never>)] = []
    func sleep(until deadline: Date) async throws {
        await withCheckedContinuation { continuation in
            sleepers.append((deadline, continuation))
            registrations += 1
            let ready = observers.filter { $0.0 <= registrations }
            observers.removeAll { $0.0 <= registrations }
            ready.forEach { $0.1.resume() }
        }
        try Task.checkCancellation()
    }
    func registered(_ count: Int) async {
        if registrations >= count { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }
    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
        let ready = sleepers.filter { $0.0 <= now }
        sleepers.removeAll { $0.0 <= now }
        ready.forEach { $0.1.resume() }
    }
    func drain() { advance(1_000_000) }
}

@MainActor final class TestSignal {
    private var signalled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func signal() { signalled = true; waiters.forEach { $0.resume() }; waiters = [] }
    func wait() async {
        if signalled { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}
