// swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/ClockStore.swift Shared/Core/ImportComparison.swift Shared/Core/PastedTextImporter.swift Shared/Core/CSVImporter.swift Shared/Core/SessionOverlap.swift Tests/manual/backups/main.swift -o /tmp/clockin-backup-tests && /tmp/clockin-backup-tests
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1; print("ok: \(name)")
}

@MainActor func session(hours: Double, note: String = "") -> WorkSession {
    let start = Date(timeIntervalSince1970: 1_786_000_000)
    return WorkSession(id: UUID(), start: start, end: start.addingTimeInterval(hours * 3600),
                       duration: hours * 3600, note: note, hourlyRate: 40, source: "Clockin")
}

/// Kendi klasorunde, verilen kayitlarla yazilmis bir store.
@MainActor func makeStore(_ sessions: [WorkSession]) -> (ClockStore, URL, URL) {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clockin-backup-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("clockin.json")
    var data = ClockinData()
    data.sessions = sessions
    try! JSONEncoder().encode(data).write(to: url)
    return (ClockStore(fileURL: url), dir, url)
}

@MainActor func writeBackup(_ sessions: [WorkSession], into dir: URL, name: String, age: TimeInterval) -> URL {
    let backups = dir.appendingPathComponent("Backups")
    try! FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
    var data = ClockinData()
    data.sessions = sessions
    let url = backups.appendingPathComponent(name)
    try! JSONEncoder().encode(data).write(to: url)
    try! FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: url.path)
    return url
}

// 1. Liste: en yenisi basta, sayilar dogru, bozuk dosya gizlenmez.
do {
    let (store, dir, _) = makeStore([session(hours: 1)])
    defer { try? FileManager.default.removeItem(at: dir) }
    _ = writeBackup([session(hours: 2), session(hours: 3)], into: dir, name: "clockin-old.json", age: 3 * 86_400)
    _ = writeBackup([session(hours: 4)], into: dir, name: "clockin-new.json", age: 86_400)
    try! Data("{ broken".utf8).write(to: dir.appendingPathComponent("Backups/clockin-broken.json"))
    let list = ClockStore.readBackups(in: store.backupDirectoryURL)
    let readable = list.filter(\.isReadable)
    // Store acilirken son 24 saatte yedek yoksa kendi yedegini alir; o en yenisi.
    check(readable.count == 3 && readable[0].sessionCount == 1 && !readable[0].isSafetyCopy,
          "opening the store takes its own automatic backup first")
    check(readable.dropFirst().map(\.url.lastPathComponent) == ["clockin-new.json", "clockin-old.json"],
          "backups are listed newest first")
    check(readable[1].sessionCount == 1 && readable[2].sessionCount == 2, "each backup reports its own entry count")
    check(abs(readable[2].totalDuration - 5 * 3600) < 1, "each backup reports its total worked time")
    check(list.contains { !$0.isReadable && $0.url.lastPathComponent == "clockin-broken.json" },
          "an unreadable backup is listed as unreadable, not hidden")
    check(ClockStore.readBackups(in: dir.appendingPathComponent("missing")).isEmpty, "no backup folder means an empty list")
}

// 2. Geri yukleme veriyi degistirir ve mevcut veriyi once kenara koyar.
do {
    let today = [session(hours: 1, note: "today A"), session(hours: 2, note: "today B")]
    let (store, dir, _) = makeStore(today)
    defer { try? FileManager.default.removeItem(at: dir) }
    let old = writeBackup([session(hours: 5, note: "old")], into: dir, name: "clockin-old.json", age: 86_400)

    check(store.restoreBackup(from: old), "restoring a readable backup succeeds")
    check(store.sessions.map(\.note) == ["old"], "restoring replaces the data with the backup")
    let safety = ClockStore.readBackups(in: store.backupDirectoryURL).filter(\.isSafetyCopy)
    check(safety.count == 1, "exactly one safety copy is kept before restoring")
    check(safety.first?.sessionCount == 2, "the safety copy holds the data from just before the restore")
    check(ClockStore.readBackups(in: store.backupDirectoryURL).first?.isSafetyCopy == true,
          "the safety copy is the newest entry in the list")

    // Geri alma: guvenlik kopyasini geri yuklemek eski hale dondurur.
    check(store.restoreBackup(from: safety[0].url), "restoring the safety copy succeeds")
    check(Set(store.sessions.map(\.note)) == ["today A", "today B"], "restoring the safety copy undoes the restore")
    let reopened = ClockStore(fileURL: dir.appendingPathComponent("clockin.json"))
    check(Set(reopened.sessions.map(\.note)) == ["today A", "today B"], "the undone state is what is on disk")
}

// 3. Bozuk bir yedek hicbir seye dokunmaz.
do {
    let (store, dir, _) = makeStore([session(hours: 1, note: "keep")])
    defer { try? FileManager.default.removeItem(at: dir) }
    let broken = dir.appendingPathComponent("broken.json")
    try! Data("{ nope".utf8).write(to: broken)
    check(!store.restoreBackup(from: broken), "restoring an unreadable file fails")
    check(store.sessions.map(\.note) == ["keep"], "a failed restore leaves the data alone")
    check(ClockStore.readBackups(in: store.backupDirectoryURL).filter(\.isSafetyCopy).isEmpty,
          "a restore that never started does not leave a safety copy behind")
    check(store.statusMessage?.hasPrefix("Could not restore") == true, "the failure is reported")
}

// 4. Diske yazilamazsa bellekteki degisiklik de geri alinir.
do {
    let original = session(hours: 1, note: "original")
    let (store, dir, _) = makeStore([original])
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        try? FileManager.default.removeItem(at: dir)
    }
    // Yedek klasoru yazilabilir kalir, ana dosyanin klasoru salt okunur olur:
    // guvenlik kopyasi alinabilir ama asil yazim basarisiz olur.
    let backup = writeBackup([session(hours: 9, note: "backup")], into: dir, name: "clockin-b.json", age: 86_400)
    try! FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)

    let start = Date(timeIntervalSince1970: 1_790_000_000)
    check(!store.addManualSession(start: start, end: start.addingTimeInterval(3600), note: "new"),
          "adding reports failure when the write fails")
    check(store.sessions.map(\.note) == ["original"], "a failed add does not leave a phantom entry on screen")
    check(store.statusMessage?.hasPrefix("Could not save") == true, "a failed add is not reported as added")

    check(!store.updateSession(id: original.id, start: original.start, end: original.end, note: "edited"),
          "editing reports failure when the write fails")
    check(store.sessions.first?.note == "original", "a failed edit is rolled back in memory")

    store.deleteSession(id: original.id)
    check(store.sessions.count == 1, "a failed delete keeps the entry")
    check(store.statusMessage?.hasPrefix("Could not save") == true, "a failed delete is not reported as deleted")

    store.importSessions([session(hours: 3, note: "imported").withSource("timeportal")])
    check(store.sessions.map(\.note) == ["original"], "a failed import is rolled back in memory")

    check(!store.restoreBackup(from: backup), "a restore whose write fails reports failure")
    check(store.sessions.map(\.note) == ["original"], "a restore whose write fails keeps the current data")
}

print("\(checks) backup checks passed")

extension WorkSession {
    func withSource(_ source: String) -> WorkSession {
        WorkSession(id: id, start: start.addingTimeInterval(86_400 * 30), end: end.addingTimeInterval(86_400 * 30),
                    duration: duration, note: note, hourlyRate: hourlyRate, source: source)
    }
}
