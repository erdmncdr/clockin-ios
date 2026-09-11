import Foundation

// ClockStore uses ObservableObject and @Published and brings unrelated store
// dependencies. This compile-only stand-in supplies just the interface used by
// ClockinSnapshot.init(store:at:). That initializer is NOT tested here.
// No snapshot arithmetic or RunningSession logic is copied into this harness.
@MainActor
final class ClockStore {
    var running: RunningSession? { fatalError("Store is outside this harness") }
    var dailyDurations: [Date: TimeInterval] { fatalError("Store is outside this harness") }
    var hourlyRate: Double { fatalError("Store is outside this harness") }
    var currencyCode: String { fatalError("Store is outside this harness") }
    func currentEarnings(at date: Date) -> Double { fatalError("Store is outside this harness") }
    func earnings(on date: Date) -> Double { fatalError("Store is outside this harness") }
    func effectiveRate(at date: Date, fallback: Double) -> Double {
        fatalError("Store is outside this harness")
    }
}

// Replace AppGroup only to satisfy the default URL arguments. Every file call
// below passes an explicit temporary URL. Accidentally using a default fails
// immediately, without looking up or touching the real App Group container.
enum AppGroup {
    static var snapshotURL: URL { fatalError("Pass an explicit temporary URL") }
}

// Return a failure count so all checks run without shared mutable global state.
func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Int {
    if condition() {
        print("ok: \(message)")
        return 0
    }
    print("FAIL: \(message)")
    return 1
}

func close(_ actual: Double, _ expected: Double) -> Bool {
    abs(actual - expected) < 0.000_001
}

func runChecks() -> Int {
    var failures = 0
    var calendar = Calendar(identifier: .gregorian)
    // Match production's Calendar.current day boundaries in any local zone.
    // Dates are fixed local calendar dates, never relative to Date.now.
    calendar.timeZone = TimeZone.current
    func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour))!
    }

    let today = date(15, 12)
    let later = date(15, 13)
    let todayStart = calendar.startOfDay(for: today)
    let yesterdayStart = calendar.startOfDay(for: date(14, 12))
    let running = RunningSession(
        start: date(15, 10), accumulated: 1800, resumedAt: date(15, 11), note: "fixed fixture"
    )
    let snapshot = ClockinSnapshot(
        day: todayStart, completedToday: 3600, earnedToday: 42.5,
        running: running, hourlyRate: 23.75, currencyCode: "USD"
    )

    failures += check(snapshot.runningCountsToday(at: today), "same-day running session counts today")
    failures += check(close(running.elapsed(at: today), 5400), "elapsed includes accumulated and resumed time")
    failures += check(close(snapshot.todayDuration(at: today), 9000), "duration adds completed 3600 and active 5400 seconds")
    failures += check(close(snapshot.todayDuration(at: later), 12600), "active duration grows by one hour")
    failures += check(close(snapshot.todayEarnings(at: today), 78.125), "earnings add 42.5 and 1.5 hours at 23.75 without cent rounding")

    var idle = snapshot
    idle.running = nil
    failures += check(!idle.runningCountsToday(at: today), "no running session does not count today")
    failures += check(close(idle.todayDuration(at: today), 3600), "idle duration keeps completed time")
    failures += check(close(idle.todayEarnings(at: today), 42.5), "idle earnings keep completed earnings")

    var stale = idle
    stale.day = yesterdayStart
    failures += check(stale.todayDuration(at: today) == 0, "yesterday's completed duration is discarded")
    failures += check(stale.todayEarnings(at: today) == 0, "yesterday's completed earnings are discarded")
    stale.running = RunningSession(
        start: date(14, 10), accumulated: 1800, resumedAt: date(14, 11), note: "overnight"
    )
    failures += check(!stale.runningCountsToday(at: today), "yesterday's running session does not count today")
    failures += check(stale.todayDuration(at: today) == 0, "fully stale snapshot has zero duration today")
    failures += check(stale.todayEarnings(at: today) == 0, "fully stale snapshot has zero earnings today")

    var overnight = snapshot
    overnight.running = stale.running
    // Even a resume today does not move an overnight session into today's totals.
    overnight.running?.resumedAt = date(15, 11)
    failures += check(!overnight.runningCountsToday(at: today), "start date controls eligibility even after a resume today")
    failures += check(close(overnight.todayDuration(at: today), 3600), "overnight running time is excluded from current completed duration")
    failures += check(close(overnight.todayEarnings(at: today), 42.5), "overnight running earnings are excluded")

    var paused = snapshot
    paused.running = RunningSession(
        start: running.start, accumulated: 5400, resumedAt: nil, note: "paused"
    )
    failures += check(paused.running?.isPaused == true, "nil resumedAt marks a paused session")
    failures += check(paused.running?.elapsed(at: today) == 5400, "paused elapsed equals accumulated time")
    failures += check(paused.running?.elapsed(at: later) == 5400, "paused elapsed does not grow")
    failures += check(close(paused.todayDuration(at: today), 9000), "paused duration includes accumulated time")
    failures += check(close(paused.todayDuration(at: later), 9000), "paused snapshot duration does not grow")
    failures += check(close(paused.todayEarnings(at: today), 78.125), "paused earnings include accumulated time")
    failures += check(close(paused.todayEarnings(at: later), 78.125), "paused earnings do not grow")

    // Ambiguous mixed-day state: production discards only completed totals,
    // keeping an eligible active session even when snapshot.day is stale.
    var mixedDay = snapshot
    mixedDay.day = yesterdayStart
    failures += check(mixedDay.runningCountsToday(at: today), "running eligibility is independent of snapshot.day")
    failures += check(close(mixedDay.todayDuration(at: today), 5400), "stale day with today's running session keeps only active duration")
    failures += check(close(mixedDay.todayEarnings(at: today), 35.625), "stale day with today's running session keeps only active earnings")

    var futureResume = snapshot
    futureResume.running?.resumedAt = later
    failures += check(close(futureResume.todayDuration(at: today), 5400), "future resume clamps additional elapsed to zero, preserving accumulated time")
    failures += check(close(futureResume.todayEarnings(at: today), 54.375), "future resume cannot subtract accumulated earnings")
    failures += check(ClockinSnapshot.empty.todayDuration(at: today) == 0, "empty snapshot duration is zero")
    failures += check(ClockinSnapshot.empty.todayEarnings(at: today) == 0, "empty snapshot earnings are zero")

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("clockin-snapshot-test-\(UUID().uuidString)", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        // Cleanup also runs after a thrown I/O error or failed assertion.
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                failures += check(false, "temporary directory cleanup: \(error)")
            }
        }

        let url = directory.appendingPathComponent("nested/snapshot.json")
        try snapshot.write(to: url)
        failures += check(ClockinSnapshot.load(from: url) == snapshot, "write/load round-trip preserves the entire running snapshot")
        try paused.write(to: url)
        failures += check(ClockinSnapshot.load(from: url) == paused, "overwriting and round-tripping a paused snapshot preserves nil resumedAt")
        try idle.write(to: url)
        failures += check(ClockinSnapshot.load(from: url) == idle, "idle snapshot round-trip preserves nil running")

        // This valid JSON fixture deliberately omits the optional running field.
        let withoutRunning = """
        {"day":\(todayStart.timeIntervalSinceReferenceDate),"completedToday":3600,"earnedToday":42.5,"hourlyRate":23.75,"currencyCode":"USD"}
        """
        let legacyURL = directory.appendingPathComponent("legacy.json")
        try Data(withoutRunning.utf8).write(to: legacyURL)
        failures += check(ClockinSnapshot.load(from: legacyURL) == idle, "missing optional running decodes as nil")

        // Synthesized Codable supplies no defaults for missing required fields.
        // Remove each newer metadata field from an otherwise valid JSON object.
        let encoded = try JSONEncoder().encode(snapshot)
        let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        for key in ["hourlyRate", "currencyCode"] {
            var legacy = object
            legacy.removeValue(forKey: key)
            try JSONSerialization.data(withJSONObject: legacy).write(to: legacyURL)
            failures += check(ClockinSnapshot.load(from: legacyURL) == nil, "missing required \(key) returns nil without crashing")
        }

        let corruptURL = directory.appendingPathComponent("corrupt.json")
        try Data("{ not json".utf8).write(to: corruptURL)
        failures += check(ClockinSnapshot.load(from: corruptURL) == nil, "malformed JSON returns nil")
        failures += check(ClockinSnapshot.load(from: directory.appendingPathComponent("missing.json")) == nil, "missing file returns nil")
    } catch {
        failures += check(false, "temporary file checks: \(error)")
    }
    return failures
}

// No main-actor operation is invoked: init(store:at:) is intentionally excluded.
let failures = runChecks()
print(failures == 0 ? "snapshot checks passed" : "snapshot checks failed: \(failures)")
exit(failures == 0 ? 0 : 1)
