import Foundation

// Kayit duzenleme, gece yarisini asan bitis, calisan seansin kazanci ve ayni
// kayda eslesen iki ice aktarma satiri. Tarihler, saatler ve ucretler
// uydurmadir.

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

var berlin = Calendar(identifier: .gregorian)
berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
func at(_ calendar: Calendar, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

// Gece yarisini asan bitis
do {
    let start = at(berlin, 3, 4, 22), sameDayEnd = at(berlin, 3, 4, 6)
    check(EntryTimes.end(start: start, end: sameDayEnd, calendar: berlin) == at(berlin, 3, 5, 6),
          "an end before the start moves to the next day")
    check(EntryTimes.end(start: start, end: at(berlin, 3, 4, 23), calendar: berlin) == at(berlin, 3, 4, 23),
          "an end after the start stays on the same day")
    check(EntryTimes.end(start: start, end: start, calendar: berlin) == start,
          "equal times do not become a 24-hour entry")
    // 25 Ekim 2026'da Berlin'de saat 03:00'te bir saat geri alinir.
    let nightStart = at(berlin, 10, 24, 22), nightEnd = at(berlin, 10, 24, 6)
    let resolved = EntryTimes.end(start: nightStart, end: nightEnd, calendar: berlin)
    check(berlin.dateComponents([.day, .hour], from: resolved) == DateComponents(day: 25, hour: 6),
          "across the autumn clock change the end is still 06:00 the next day")
    check(resolved.timeIntervalSince(nightStart) == 9 * 3600,
          "and the night shift is nine real hours, not eight")
}

// Duzenlenen kaydin calisilan suresi
do {
    let start = at(berlin, 3, 4, 9), end = at(berlin, 3, 4, 12)
    let paused = WorkSession(id: UUID(), start: start, end: end, duration: 2 * 3600,
                             note: "", hourlyRate: 40, source: "Clockin")
    check(EntryTimes.workedDuration(start: start, end: end, replacing: nil) == 3 * 3600,
          "a new entry works the whole range")
    check(EntryTimes.workedDuration(start: start, end: end, replacing: paused) == 2 * 3600,
          "unchanged times keep the saved duration")
    check(EntryTimes.workedDuration(start: start, end: end.addingTimeInterval(3600), replacing: paused) == 3 * 3600,
          "moving the end keeps the one-hour break")
    check(EntryTimes.workedDuration(start: start, end: start.addingTimeInterval(1800), replacing: paused) <= 0,
          "times shorter than the break leave nothing worked")
}

MainActor.assumeIsolated {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clockin-sessions-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let calendar = Calendar.current
    @MainActor func local(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
    }
    @MainActor func store(_ name: String, _ build: (inout ClockinData) -> Void) -> ClockStore {
        var data = ClockinData()
        data.hourlyRate = 40
        data.rateRules = [RateRule(effectiveFrom: local(1, 0), hourlyRate: 40)]
        build(&data)
        let url = dir.appendingPathComponent("\(name).json")
        try! JSONEncoder().encode(data).write(to: url)
        return ClockStore(fileURL: url)
    }
    @MainActor func session(_ start: Date, _ end: Date, source: String) -> WorkSession {
        WorkSession(id: UUID(), start: start, end: end, duration: end.timeIntervalSince(start),
                    note: "", hourlyRate: 40, source: source)
    }

    // Duzenleyici ile magaza ayni sureyi kaydeder
    do {
        let paused = WorkSession(id: UUID(), start: local(4, 9), end: local(4, 12), duration: 2 * 3600,
                                 note: "", hourlyRate: 40, source: "Clockin")
        let s = store("edit") { $0.sessions = [paused] }
        let newEnd = local(4, 13)
        let preview = EntryTimes.workedDuration(start: paused.start, end: newEnd, replacing: paused)
        check(s.updateSession(id: paused.id, start: paused.start, end: newEnd, note: ""), "moving the end saves")
        check(s.sessions.first?.duration == preview, "the saved duration is the one the editor previewed")
    }

    // Calisan seans basladigi gunun ucretiyle kazanir
    do {
        let s = store("rate") {
            $0.rateRules = [RateRule(effectiveFrom: local(1, 0), hourlyRate: 40),
                            RateRule(effectiveFrom: local(5, 0), hourlyRate: 80)]
            $0.running = RunningSession(start: local(4, 23), accumulated: 0, resumedAt: local(4, 23), note: "")
        }
        let now = local(5, 1)
        check(abs(s.currentEarnings(at: now) - 80) < 0.001,
              "a session that started before a raise earns the old rate while running")
        check(s.currentRate(at: now) == 40, "the per-second rate shown matches the rate the session earns")
        let live = s.currentEarnings(at: now)
        let saved = s.clockOut(at: now).map(s.earnings(for:)) ?? -1
        check(abs(live - saved) < 0.001, "clocking out does not change what the session earned")
    }

    // Ayni kayda eslesen iki satir: onizleme ve aktarma ayni seyi yapar
    do {
        let long = session(local(6, 9), local(6, 17), source: "Clockin")
        let afternoon = session(local(6, 12, 30), local(6, 16), source: "Clockin")
        let morningRow = session(local(6, 9), local(6, 13), source: "timecard")
        let laterRow = session(local(6, 12), local(6, 16), source: "timecard")
        let s = store("claims") { $0.sessions = [long, afternoon] }
        let preview = s.compareImportedSessions([morningRow, laterRow]).items
        check(preview.map(\.kind) == [.matched, .matched], "both rows are previewed as corrections")
        check(preview.first?.localMatch?.id == long.id && preview.last?.localMatch?.id == afternoon.id,
              "the second row falls back to the next best entry the first did not take")
        s.importSessions([morningRow, laterRow])
        check(s.sessions.count == 2, "importing corrects both entries without adding one")
        let correctedLong = s.sessions.first { $0.id == long.id }
        let correctedAfternoon = s.sessions.first { $0.id == afternoon.id }
        check(correctedLong?.start == morningRow.start && correctedLong?.end == morningRow.end
              && correctedAfternoon?.start == laterRow.start && correctedAfternoon?.end == laterRow.end,
              "each entry takes the times of the row it was previewed with")
    }

    // Dosyada ayni isin iki yazimi, ilki bir kaydi duzeltirken
    do {
        let timer = session(local(7, 9), local(7, 17), source: "Clockin")
        let first = session(local(7, 9), local(7, 17, 5), source: "timecard")
        let twin = session(local(7, 9), local(7, 17, 10), source: "timecard")
        let s = store("twins") { $0.sessions = [timer] }
        check(s.compareImportedSessions([first, twin]).items.map(\.kind) == [.matched, .duplicate],
              "the second writing of a correcting row is previewed as a duplicate")
        s.importSessions([first, twin])
        check(s.sessions.count == 1 && s.sessions.first?.end == first.end,
              "and importing does not add it as new work once the entry is taken")
    }
}

print("\(checks) session checks passed")
