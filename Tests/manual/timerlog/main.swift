import Foundation

@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { fatalError("FAILED: \(name)") }
    print("ok: \(name)")
}

MainActor.assumeIsolated {
    let suite = "timer-log-tests-\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let log = TimerStartLog(defaults: defaults)
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    check(log.entries.isEmpty, "new log is empty")
    for index in 0..<105 {
        log.record(.clockIn, origin: .app, at: date.addingTimeInterval(Double(index)))
    }
    check(log.entries.count == 100, "only the last 100 entries remain")
    check(log.entries.map(\.date) == (5..<105).reversed().map { date.addingTimeInterval(Double($0)) },
          "entries are newest first and oldest entries are removed")
    let encoded = defaults.data(forKey: TimerStartLog.key)!
    let decoded = try! JSONDecoder().decode([TimerStartLog.Entry].self, from: encoded)
    check(decoded == log.entries, "stored JSON round-trips including entry identity")
    check(TimerStartLog(defaults: defaults).entries == log.entries, "a new log instance reloads saved entries")
    let origins: [TimerOrigin: String] = [.app: "app", .widget: "widget", .controlCenter: "controlCenter",
                                        .sync: "sync", .shortcut: "shortcut", .link: "link", .pulse: "pulse"]
    check(Set(origins.keys) == Set(TimerOrigin.allCases), "every origin has a stable-value assertion")
    for (origin, raw) in origins {
        check(origin.rawValue == raw && TimerOrigin(rawValue: raw) == origin, "stable origin: \(raw)")
        check(try! JSONDecoder().decode(TimerOrigin.self, from: JSONEncoder().encode(origin)) == origin,
              "origin JSON: \(raw)")
    }
    log.record(.resume, origin: .sync, wasRunning: true, provenance: .initialImport)
    let reloaded = TimerStartLog(defaults: defaults)
    check(reloaded.entries.first?.provenance == .initialImport && reloaded.entries.first?.wasRunning == true,
          "sync provenance and previous-session state survive JSON")
    check(TimerStartLog.Action.clockIn.rawValue == "clockIn" && TimerStartLog.Action.resume.rawValue == "resume"
          && TimerStartLog.Action.clockOut.rawValue == "clockOut", "stable actions")
    check(TimerStartLog.SyncProvenance.remoteChange.rawValue == "remoteChange"
          && TimerStartLog.SyncProvenance.initialImport.rawValue == "initialImport", "stable sync provenance")
    log.clear()
    check(log.entries.isEmpty && defaults.data(forKey: TimerStartLog.key) == nil
          && TimerStartLog(defaults: defaults).entries.isEmpty, "clear removes both memory and saved data")
    defaults.set(Data("invalid JSON".utf8), forKey: TimerStartLog.key)
    check(TimerStartLog(defaults: defaults).entries.isEmpty, "damaged log does not prevent opening the app")
    log.clear()

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("timer-store-tests-\(UUID())")
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("clockin.json")
    let recordedAt = date.addingTimeInterval(90)
    let store = ClockStore(fileURL: file, now: { recordedAt }, timerStartLog: log)
    store.clockIn(at: date, origin: .widget)
    check(log.entries.first?.action == .clockIn && log.entries.first?.origin == .widget, "local start records its origin")
    store.clockIn(at: date, origin: .link)
    store.resume(at: date)
    check(log.entries.count == 1, "already-running start and resume are no-ops")
    store.pause(at: date.addingTimeInterval(10))
    check(log.entries.count == 1, "pause does not add a log entry")
    store.resume(at: date.addingTimeInterval(20), origin: .shortcut)
    check(log.entries.first?.action == .resume && log.entries.first?.origin == .shortcut, "resume records its origin")
    _ = store.clockOut(at: date.addingTimeInterval(30), origin: .controlCenter)
    check(log.entries.first?.action == .clockOut && log.entries.first?.origin == .controlCenter,
          "clock-out records its origin")
    check(log.entries.first?.date == recordedAt, "record receipt time even when the session end was backdated")
    _ = store.clockOut()
    check(log.entries.count == 3, "idle clock-out is a no-op")
    store.clockIn(at: date)
    check(log.entries.first?.origin == .app, "existing app calls default to app origin")
    _ = store.clockOut(at: date.addingTimeInterval(10), origin: .pulse)
    check(log.entries.first?.origin == .pulse, "native-host origin is preserved")
    log.clear()

    var incoming = store.data
    incoming.running = RunningSession(start: date, accumulated: 0, resumedAt: date, note: "")
    check(store.applySynced(incoming, provenance: .initialImport), "initial sync persists")
    check(log.entries.first?.action == .clockIn && log.entries.first?.origin == .sync
          && log.entries.first?.wasRunning == false && log.entries.first?.provenance == .initialImport,
          "initial import records an appearing session and prior idle state")
    _ = store.applySynced(incoming)
    incoming.running?.note = "changed note"
    _ = store.applySynced(incoming)
    incoming.running?.resumedAt = nil
    _ = store.applySynced(incoming)
    check(log.entries.count == 1, "unchanged sync, note changes and pause are not starts")
    incoming.running?.resumedAt = date.addingTimeInterval(20)
    _ = store.applySynced(incoming)
    check(log.entries.first?.action == .resume && log.entries.first?.wasRunning == true,
          "remote resume records the existing session")
    incoming.running?.start = date.addingTimeInterval(5)
    _ = store.applySynced(incoming)
    check(log.entries.first?.action == .clockIn && log.entries.first?.provenance == .remoteChange
          && log.entries.first?.wasRunning == true, "remote start replacement records prior session and provenance")
    incoming.running = nil
    _ = store.applySynced(incoming)
    check(log.entries.first?.action == .clockOut && log.entries.first?.wasRunning == true,
          "remote disappearance records clock-out")
    _ = store.applySynced(incoming)
    check(log.entries.count == 4, "repeated idle sync is not another clock-out")
    log.clear()

    func blockWrites() {
        try! FileManager.default.removeItem(at: file)
        try! FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
    }
    func allowWrites() { try! FileManager.default.removeItem(at: file) }
    blockWrites()
    store.clockIn(at: date, origin: .link)
    check(store.running == nil && log.entries.isEmpty, "failed clock-in neither changes state nor logs")
    incoming.running = RunningSession(start: date, accumulated: 0, resumedAt: date, note: "")
    check(!store.applySynced(incoming) && log.entries.isEmpty, "failed sync apply does not log")
    allowWrites()
    store.clockIn(at: date)
    store.pause(at: date.addingTimeInterval(10))
    log.clear()
    blockWrites()
    store.resume(at: date.addingTimeInterval(20), origin: .widget)
    check(store.running?.isPaused == true && log.entries.isEmpty, "failed resume preserves pause and does not log")
    check(store.clockOut(at: date.addingTimeInterval(30)) == nil && store.running != nil && log.entries.isEmpty,
          "failed clock-out preserves session and does not log")
    allowWrites()
    print("All timer log checks passed.")
}
