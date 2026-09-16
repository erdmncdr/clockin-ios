import Foundation

// Ayni dokumun ikinci kez ice aktarilmasi kayit cogaltmamali.
//
// Hata: ayni is iki kayit halinde kalabiliyordu, baslangiclari ayni,
// bitisleri birkac dakika farkli. Dokum duzeltilmis bitislerle yeniden
// alindiginda isaretsiz eski kayit hicbir satirla eslesmiyor ve gun iki
// katina cikiyordu. Tarih, saat ve notlar uydurmadir.

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = .current
@MainActor func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
}
@MainActor func session(day: Int = 4, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int,
                        source: String, linked: String? = nil) -> WorkSession {
    let start = at(day, sh, sm), end = at(day, eh, em)
    var s = WorkSession(id: UUID(), start: start, end: end, duration: end.timeIntervalSince(start),
                        note: "Sample project", hourlyRate: 40, source: source)
    s.matchedExternalSource = linked
    return s
}

/// Verilen kayitlarla dolu, dosyaya yazilmis bir store.
@MainActor func store(_ existing: [WorkSession]) -> (ClockStore, URL) {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("clockin.json")
    let data = ClockinData(hourlyRate: 40, currencyCode: "USD", running: nil, sessions: existing)
    try! JSONEncoder().encode(data).write(to: url)
    return (ClockStore(fileURL: url), dir)
}
@MainActor func hours(_ s: ClockStore) -> Double { s.sessions.reduce(0.0) { $0 + $1.duration } / 3600 }

// 1. Asil hata: isaretsiz, daha once ice aktarilmis bir kaydin uzerine
//    duzeltilmis bitisle gelen ayni satir.
do {
    let legacy = session(10, 0, 18, 00, source: "timeportal")          // isaret yok
    let (s, dir) = store([legacy]); defer { try? FileManager.default.removeItem(at: dir) }
    let incoming = session(10, 0, 18, 05, source: "timeportal")
    check(s.compareImportedSessions([incoming]).items.first?.kind == .matched,
          "an updated timecard row is previewed as an update, not as new work")
    check(s.importSessions([incoming]), "successful import reports success for feedback")
    check(s.sessions.count == 1, "re-importing a corrected row does not append a second copy")
    check(abs(hours(s) - 8.08) < 0.01, "the day keeps one session's worth of hours")
    check(s.sessions.first?.matchedExternalSource == "timeportal",
          "the healed record is linked, so the next import matches it too")
}

// 2. Isaretli kayit zaten calisiyordu, bozulmamali.
do {
    let linked = session(10, 0, 18, 00, source: "timeportal", linked: "timeportal")
    let (s, dir) = store([linked]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(10, 0, 18, 05, source: "timeportal")])
    check(s.sessions.count == 1, "an already linked record still updates in place")
}

// 3. Sayac kaydi da eskisi gibi eslesmeli.
do {
    let timer = session(10, 0, 18, 00, source: "Clockin")
    let (s, dir) = store([timer]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(10, 0, 18, 05, source: "timeportal")])
    check(s.sessions.count == 1, "a timer entry is still corrected by the official row")
}

// 4. Fazla eslestirmeme: ayni gunun ayri, cakismayan isleri birlesmemeli.
do {
    let morning = session(9, 0, 11, 0, source: "timeportal")
    let (s, dir) = store([morning]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(14, 0, 18, 0, source: "timeportal")])
    check(s.sessions.count == 2, "two separate shifts on one day stay separate")
}

// 5. Az ortusen isler de ayri kalmali (esik kisa olanin yarisi).
do {
    let first = session(9, 0, 13, 0, source: "timeportal")             // 4 saat
    let (s, dir) = store([first]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(12, 30, 16, 30, source: "timeportal")])  // 30 dk ortusuyor
    check(s.sessions.count == 2, "a brief overlap is not treated as the same work")
}

// 6. Baska bir kaynak, isaretsiz bir kaydi sahiplenmemeli.
do {
    let other = session(10, 0, 18, 00, source: "timeportal")
    let (s, dir) = store([other]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(10, 0, 18, 05, source: "acme")])
    check(s.sessions.count == 2, "a different employer's timecard does not absorb another's record")
}

// 7. Farkli gun, ayni saatler: gun siniri korunmali.
do {
    let fourth = session(day: 4, 10, 0, 18, 00, source: "timeportal")
    let (s, dir) = store([fourth]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(day: 5, 10, 0, 18, 05, source: "timeportal")])
    check(s.sessions.count == 2, "the same hours on the next day are a different session")
}

// 8. Birebir ayni satir yine atlanmali.
do {
    let existing = session(10, 0, 18, 00, source: "timeportal")
    let (s, dir) = store([existing]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(10, 0, 18, 00, source: "timeportal")])
    check(s.sessions.count == 1, "an identical row is still skipped")
}

// 9. Iki ikiz birden varken tek satir yalnizca birini sahiplenir.
do {
    let twinA = session(10, 0, 18, 00, source: "timeportal")
    let twinB = session(10, 0, 18, 05, source: "timeportal")
    let (s, dir) = store([twinA, twinB]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(10, 0, 18, 10, source: "timeportal")])
    check(s.sessions.count == 2, "an existing duplicate pair is not grown by a third copy")
}

// 10. Bir dosyada ayni isin iki satiri varsa ikisi birden eklenmemeli.
do {
    let (s, dir) = store([]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(10, 0, 18, 00, source: "timeportal"),
                      session(10, 0, 18, 05, source: "timeportal")])
    check(s.sessions.count == 1, "two near-identical rows in one file import as one session")
}

// 11. Arsivdeki ikizleri doguran gercek sira: once dokum alinir, sonra
//     duzeltilmis hali ayri bir aktarmada gelir.
do {
    let (s, dir) = store([]); defer { try? FileManager.default.removeItem(at: dir) }
    s.importSessions([session(10, 0, 18, 00, source: "timeportal")])
    check(s.sessions.count == 1, "the first import of a timecard adds the row")
    s.importSessions([session(10, 0, 18, 05, source: "timeportal")])
    check(s.sessions.count == 1, "a later import of the corrected row updates it instead of doubling the day")
    check(abs(hours(s) - 8.08) < 0.01, "the day still holds one shift")
    s.importSessions([session(10, 0, 18, 10, source: "timeportal")])
    check(s.sessions.count == 1, "a third correction still updates in place")
}

// 12. Satir satir secim.
do {
    let timer = session(10, 0, 18, 00, source: "Clockin")
    let (s, dir) = store([timer]); defer { try? FileManager.default.removeItem(at: dir) }
    let correction = session(10, 0, 18, 05, source: "timeportal")
    let fresh = session(day: 5, 9, 0, 12, 0, source: "timeportal")
    let summary = s.compareImportedSessions([correction, fresh])
    check(summary.actionableItems.count == 2, "new rows and corrections are both selectable")
    check(summary.sessionsToImport(excluding: []).count == 2, "everything selectable is selected by default")

    s.importSessions(summary.sessionsToImport(excluding: [correction.id]))
    check(s.sessions.count == 2, "leaving out a correction still imports the selected new row")
    check(s.sessions.contains { $0.id == timer.id && abs($0.duration - 8 * 3600) < 60 },
          "a correction that was left out does not touch the timer entry")
}
do {
    let (s, dir) = store([]); defer { try? FileManager.default.removeItem(at: dir) }
    let fresh = session(day: 5, 9, 0, 12, 0, source: "timeportal")
    s.importSessions(s.compareImportedSessions([fresh]).sessionsToImport(excluding: [fresh.id]))
    check(s.sessions.isEmpty, "a new row that was left out is not added")
}
do {
    // Dosyada ayni isin iki yazimi: ikincisi tekrar sayilir. Ilki secimden
    // cikarilinca ikincisi yeni is diye iceri girmemeli.
    let (s, dir) = store([]); defer { try? FileManager.default.removeItem(at: dir) }
    let first = session(10, 0, 18, 00, source: "timeportal")
    let twin = session(10, 0, 18, 05, source: "timeportal")
    let summary = s.compareImportedSessions([first, twin])
    check(summary.items.map(\.kind) == [.new, .duplicate], "the in-file twin is previewed as a duplicate")
    let chosen = summary.sessionsToImport(excluding: [first.id])
    check(chosen.isEmpty, "leaving out a row does not let its duplicate through instead")
    s.importSessions(chosen)
    check(s.sessions.isEmpty, "nothing is imported when the only real row was left out")
}

print("\(checks) import checks passed")
