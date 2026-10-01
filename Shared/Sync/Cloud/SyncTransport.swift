import Foundation

/// Outcome of a completed app sync wake. Approval gates aren't failures;
/// transport, validation and persistence errors are, even after a partial apply.
enum SyncFetchResult: Equatable, Sendable {
    case newData, noData, failed

    static func result(appliedChanges: Bool, status: SyncStatus) -> Self {
        switch status {
        case .off: return .noData
        case .upToDate, .paused(.firstMerge), .paused(.postponed):
            return appliedChanges ? .newData : .noData
        case .starting, .syncing, .waitingForNetwork, .accountProblem, .paused:
            return .failed
        }
    }
}

// Shared by the real transport and offline harnesses. No CloudKit access is needed.
@MainActor
protocol SyncTransport: AnyObject {
    var status: SyncStatus { get }
    var lastSuccessfulSync: Date? { get }
    var didChange: (@MainActor @Sendable () -> Void)? { get set }
    func launch() async
    func synchronize() async
    func accountMayHaveChanged() async
    func stop() async
}

enum SyncPauseReason: Equatable, Sendable {
    case firstMerge, postponed, storage, invalidData, sendFailed, quota, retryLimit
    var message: String {
        switch self {
        case .firstMerge: String(localized: "Review the first merge to continue syncing.", bundle: .app)
        case .postponed: String(localized: "First merge postponed. Your data stays on this device.", bundle: .app)
        case .storage: String(localized: "Sync could not save its data. Check available storage and try again.", bundle: .app)
        case .invalidData: String(localized: "Sync paused because data could not be applied. Your archive is retained.", bundle: .app)
        case .sendFailed: String(localized: "Some changes could not be sent. They remain on this device for the next sync.", bundle: .app)
        case .quota: String(localized: "iCloud storage is full. Pending changes remain on this device.", bundle: .app)
        case .retryLimit: String(localized: "Sync reached its retry limit. Pending changes will wait for the next sync.", bundle: .app)
        }
    }
}

enum SyncStatus: Equatable, Sendable {
    case off, starting, syncing, upToDate, waitingForNetwork, paused(SyncPauseReason), accountProblem
    var message: String {
        switch self {
        case .off: String(localized: "Sync is off", bundle: .app)
        case .starting: String(localized: "Starting sync", bundle: .app)
        case .syncing: String(localized: "Syncing", bundle: .app)
        case .upToDate: String(localized: "Up to date", bundle: .app)
        case .waitingForNetwork: String(localized: "Waiting for network", bundle: .app)
        case .paused(let reason): reason.message
        case .accountProblem: String(localized: "Sign in to the original iCloud account to sync this archive.", bundle: .app)
        }
    }
}

enum SyncSendFailure: CaseIterable {
    case serverRecordChanged, unknownItem, zoneNotFound
    case networkFailure, networkUnavailable, zoneBusy, serviceUnavailable, requestRateLimited
    case notAuthenticated, operationCancelled, other
    enum Action { case join, clearFields, rebuildZone, engineRetry, deferToNextPass }
    var action: Action {
        switch self {
        case .serverRecordChanged: .join
        case .unknownItem: .clearFields
        case .zoneNotFound: .rebuildZone
        case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
             .requestRateLimited, .notAuthenticated, .operationCancelled: .engineRetry
        case .other: .deferToNextPass
        }
    }
}

struct SyncSendPass {
    private(set) var running = false
    private(set) var rerunRequested = false
    private var readds: [String: Int] = [:]
    private(set) var deferred: Set<String> = []
    let limit: Int
    init(limit: Int = 3) { self.limit = limit }

    mutating func request() -> Bool {
        if running { rerunRequested = true; return false }
        running = true
        beginPass()
        return true
    }
    mutating func finishPass() -> Bool {
        if rerunRequested { rerunRequested = false; beginPass(); return true }
        running = false
        return false
    }
    mutating func cancel() { running = false; rerunRequested = false; beginPass() }
    private mutating func beginPass() { readds = [:]; deferred = [] }
    mutating func deferRecord(_ key: String) { deferred.insert(key) }
    mutating func permitReadd(_ key: String) -> Bool {
        guard !deferred.contains(key), readds[key, default: 0] < limit else {
            deferred.insert(key); return false
        }
        readds[key, default: 0] += 1
        return true
    }
}

enum SyncAccountState { case available, absent, temporary }

struct SyncLaunchBackoff {
    private(set) var failures = 0
    mutating func nextDelay(minimum: TimeInterval = 0) -> TimeInterval {
        failures = min(failures + 1, 7)
        return max(minimum, min(300, 5 * pow(2, Double(failures - 1))))
    }
    mutating func reset() { failures = 0 }
}

@MainActor
protocol SyncBatchSource {
    associatedtype ID
    associatedtype Record
    var pendingIDs: [ID] { get }
    func contains(_ id: ID) -> Bool
    func record(for id: ID) -> (Record, bytes: Int)?
    func removeUnavailable(_ id: ID)
}

enum SyncBatchBuilder {
    // Source is the ENGINE's pending list. Bridge-only pending values cannot leak into a batch.
    @MainActor static func build<S: SyncBatchSource>(_ source: S, limit: Int = 100,
                                                    byteLimit: Int = 1_500_000) -> [S.Record] {
        var result: [S.Record] = []
        var bytes = 0
        for id in source.pendingIDs where source.contains(id) {
            guard let (record, count) = source.record(for: id) else {
                source.removeUnavailable(id)
                continue
            }
            guard result.count < limit, bytes + count <= byteLimit else { break }
            result.append(record); bytes += count
        }
        return result
    }
}

@MainActor
protocol SyncClock {
    var now: Date { get }
    func sleep(until deadline: Date) async throws
}

struct SystemSyncClock: SyncClock {
    var now: Date { .now }
    func sleep(until deadline: Date) async throws {
        try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
    }
}

@MainActor
final class SyncWakeup {
    private let clock: any SyncClock
    private var task: Task<Void, Never>?
    private var generation = 0
    private(set) var deadline: Date?
    init(clock: any SyncClock = SystemSyncClock()) { self.clock = clock }
    deinit { task?.cancel() }

    func schedule(at date: Date, action: @escaping @MainActor @Sendable () async -> Void) {
        guard deadline != date else { return }
        cancel()
        deadline = date
        let generation = generation
        let clock = clock
        task = Task { [weak self] in
            do { try await clock.sleep(until: date) } catch { return }
            guard !Task.isCancelled, let self, self.generation == generation else { return }
            self.deadline = nil; self.task = nil
            await action()
        }
    }
    func cancel() {
        generation += 1
        task?.cancel(); task = nil; deadline = nil
    }
}
