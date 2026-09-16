import Foundation

// Exercise the real store-to-widget boundary using isolated, synthetic data.
enum AppGroup {
    static var snapshotURL: URL { fatalError("Pass an explicit test URL") }
}

var failures = 0
var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    print("\(condition ? "ok" : "FAILED"): \(name)")
    checks += 1
    if !condition { failures += 1 }
}

MainActor.assumeIsolated {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clockin-feedback-\(UUID())")
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    var data = ClockinData()
    data.hourlyRate = 80
    data.rateRules = [RateRule(effectiveFrom: yesterday, hourlyRate: 40),
                      RateRule(effectiveFrom: today, hourlyRate: 80)]
    data.running = RunningSession(start: today.addingTimeInterval(-3600), accumulated: 7200,
                                  resumedAt: nil, note: "Overnight fixture")
    let url = directory.appendingPathComponent("clockin.json")
    try! JSONEncoder().encode(data).write(to: url)
    let store = ClockStore(fileURL: url)
    let snapshot = ClockinSnapshot(store: store, at: today)
    check(store.currentEarnings(at: today) == 80, "overnight session earns 2 hours at 40")
    check(snapshot.hourlyRate == 40, "widget and Live Activity receive the session's 40/hour rate")
    check(snapshot.todayEarnings(at: today) == 0, "overnight session is not counted as today's work")
    store.updateCurrency("TRY")
    let changed = ClockinSnapshot(store: store, at: today)
    check(changed.currencyCode == "TRY", "currency changes reach widget snapshot")
    check(store.currentEarnings(at: today).money(code: "TRY").contains("₺")
          || store.currentEarnings(at: today).money(code: "TRY").contains("TRY"),
          "TRY formatting does not retain USD")
    store.cancelRunning()
    let count = store.rateRules.count
    store.addRateRule(effectiveFrom: today, hourlyRate: 120)
    check(store.rateRules.count == count && store.statusMessage != nil,
          "adding a second rate with the same start day is rejected with an explanation")
    check(store.currentRate(at: today) == 80, "rejected rate cannot silently replace the existing rate")
    let oldID = store.rateRules.first!.id
    store.updateRateRule(id: oldID, effectiveFrom: today, hourlyRate: 140)
    check(store.rateRules.first(where: { $0.id == oldID })?.effectiveFrom == yesterday,
          "editing a rate cannot create an ambiguous start day either")
    if let current = store.rateRules.first(where: { $0.effectiveFrom == today }) {
        store.updateRateRule(id: current.id, effectiveFrom: today, hourlyRate: 100)
        check(store.currentRate(at: today) == 100, "editing the current rule updates earnings rate")
    }

    // Existing backups can already contain duplicate start dates. Keep the
    // selected label and calculation consistent without rewriting history.
    data.running = nil
    data.rateRules = [RateRule(effectiveFrom: today, hourlyRate: 40),
                      RateRule(effectiveFrom: today, hourlyRate: 120)]
    let legacyURL = directory.appendingPathComponent("legacy.json")
    try! JSONEncoder().encode(data).write(to: legacyURL)
    let legacy = ClockStore(fileURL: legacyURL)
    check(legacy.effectiveRateRule(at: today)?.hourlyRate == legacy.currentRate(at: today),
          "legacy duplicate dates select the same current label and earnings rate")

    // Adjacent entries inside the same minute are not overlapping. Editors
    // must pass the preserved saved times, not the minute-only picker values.
    let end = today.addingTimeInterval(9 * 3600 + 30)
    let first = WorkSession(id: UUID(), start: end.addingTimeInterval(-3600), end: end,
                            duration: 3600, note: "", hourlyRate: 40, source: "Clockin")
    let second = WorkSession(id: UUID(), start: end.addingTimeInterval(1), end: end.addingTimeInterval(3601),
                             duration: 3600, note: "", hourlyRate: 40, source: "Clockin")
    check(SessionOverlap.touching(start: second.start, end: second.end, in: [first, second], excluding: second.id).isEmpty,
          "saved second-precision adjacent entries have no overlap")
    check(SessionOverlap.touching(start: calendar.dateInterval(of: .minute, for: second.start)!.start,
                                  end: second.end, in: [first, second], excluding: second.id).count == 1,
          "minute-only editor times reproduce the false overlap")
    let longStart = yesterday.addingTimeInterval(9 * 3600 + 17)
    let longEnd = calendar.date(byAdding: .hour, value: 26, to: longStart)!
    let long = WorkSession(id: UUID(), start: longStart, end: longEnd, duration: 25 * 3600,
                           note: "One hour break", hourlyRate: 40, source: "Clockin")
    let edit = EntryTimes.editorTimes(day: long.start, startTime: long.start, endTime: long.end, replacing: long)
    check(edit.start == long.start && edit.end == long.end,
          "opening a 26-hour record preserves both dates and seconds")
    check(EntryTimes.workedDuration(start: edit.start, end: edit.end, replacing: long) == 25 * 3600,
          "note-only edits preserve 25 worked hours and the one-hour break")
    let adjacentEdit = EntryTimes.editorTimes(day: second.start, startTime: second.start, endTime: second.end, replacing: second)
    check(SessionOverlap.touching(start: adjacentEdit.start, end: adjacentEdit.end, in: [first, second], excluding: second.id).isEmpty,
          "the real editor resolver does not introduce an overlap between adjacent records")

    var longData = ClockinData()
    longData.rateRules = []
    longData.sessions = [long]
    let longURL = directory.appendingPathComponent("long.json")
    try! JSONEncoder().encode(longData).write(to: longURL)
    let longStore = ClockStore(fileURL: longURL)
    check(longStore.updateSession(id: long.id, start: edit.start, end: edit.end, note: "Edited note"),
          "a note-only long-session edit saves successfully")
    let reopened = ClockStore(fileURL: longURL)
    check(reopened.sessions.first?.duration == 25 * 3600 && reopened.sessions.first?.end == long.end,
          "reopening preserves the long-session duration, end date, and seconds")
    check(reopened.sessions.first?.note == "Edited note", "the changed note persists")
    let movedEnd = long.end.addingTimeInterval(3600)
    let longer = EntryTimes.editorTimes(day: long.start, startTime: long.start, endTime: movedEnd, replacing: long)
    check(calendar.isDate(longer.end, inSameDayAs: movedEnd), "editing the end time preserves its explicit end date")
    let overnight = EntryTimes.editorTimes(day: yesterday, startTime: yesterday.addingTimeInterval(22 * 3600),
                                          endTime: yesterday.addingTimeInterval(6 * 3600), replacing: nil)
    check(overnight.end == today.addingTimeInterval(6 * 3600), "new time-only entries still infer overnight shifts")
    let equal = EntryTimes.editorTimes(day: today, startTime: today, endTime: today, replacing: nil)
    check(equal.start == equal.end, "equal new times do not silently turn into 24 hours")

}
print("\(checks) feedback checks passed")
exit(failures == 0 ? 0 : 1)
