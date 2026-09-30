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

// 13. Dosya esas alininca: iki cihazda ayri ayri ice aktarilan dokumler
//     birlesince ayni is iki kez kalmisti. Dosyada karsiligi olmayan her
//     kayit, kaynagi ne olursa olsun, silinmek uzere listelenir.
do {
    let kept = session(10, 0, 18, 00, source: "timeportal", linked: "timeportal")
    let copy = session(10, 0, 17, 58, source: "timeportal")             // ayni isin ikinci yazimi
    let stale = session(day: 5, 9, 0, 12, 0, source: "timeportal")      // dosyada artik yok
    let timer = session(day: 6, 13, 0, 14, 0, source: "Clockin")        // donem icinde, dosyada yok
    let later = session(day: 20, 9, 0, 10, 0, source: "Clockin")        // donemin disinda
    let (s, dir) = store([kept, copy, stale, timer, later]); defer { try? FileManager.default.removeItem(at: dir) }
    let rows = [session(10, 0, 18, 00, source: "timeportal"), session(day: 7, 9, 0, 17, 0, source: "timeportal")]
    let plain = s.compareImportedSessions(rows, scope: .wholeRange)
    check(Set(plain.leftovers.map(\.id)) == [timer.id], "without the reference only timer entries are offered")
    let reference = s.compareImportedSessions(rows, scope: .wholeRange, fileIsReference: true)
    check(Set(reference.leftovers.map(\.id)) == [copy.id, stale.id, timer.id],
          "with the file as reference every entry in the period that the file lacks is offered")
    s.importSessions(reference.sessionsToImport(excluding: []), removing: reference.leftovers)
    check(Set(s.sessions.map(\.id)).isSuperset(of: [kept.id, later.id]) && s.sessions.count == 3,
          "the period matches the file, entries outside it stay")
    check(abs(hours(s) - 17) < 0.01, "no doubled hours remain")
}

// Onizlemeden sonra ayni kimlik baska doneme tasinmissa silinmemeli.
do {
    let leftover = session(day: 4, 9, 0, 12, 0, source: "timeportal")
    let (s, dir) = store([leftover]); defer { try? FileManager.default.removeItem(at: dir) }
    let incoming = session(day: 4, 14, 0, 15, 0, source: "timeportal")
    let review = s.compareImportedSessions([incoming], fileIsReference: true)
    check(review.isCurrent(for: s.data.sessions), "new review matches its store snapshot")
    check(review.leftovers.map(\.id) == [leftover.id], "review contains the original removal candidate")
    check(s.updateSession(id: leftover.id, start: at(20, 9, 0), end: at(20, 12, 0), note: leftover.note),
          "the reviewed candidate moves to a different day")
    let before = s.sessions
    check(!review.isCurrent(for: s.data.sessions), "review detects a changed store snapshot")
    check(!s.importSessions([incoming], removing: review.leftovers),
          "store refuses an import whose removal candidate changed since review")
    check(s.sessions == before, "stale removal refusal also leaves incoming rows unapplied")
    check(ClockStore(fileURL: s.archiveURL).sessions == before, "stale refusal preserves the saved archive")
    check(s.importSessions([], removing: s.sessions), "unchanged reviewed values can still be deleted")
    check(s.sessions.isEmpty, "freshly reviewed deletion removes only approved records")
}

// Bozuk bir orta satir, kayit yoklugu diye yorumlanmamali.
do {
    let csv = "Start Time,End Time\n2026-03-01T09:00:00Z,2026-03-01T10:00:00Z\n2026-03-02T09:00:00Z,unreadable\n2026-03-03T09:00:00Z,2026-03-03T10:00:00Z\n"
    let parsed = try CSVImporter.parse(data: Data(csv.utf8), hourlyRate: 40)
    check(parsed.skippedRowCount == 1 && parsed.sessions.count == 2,
          "CSV reports a rejected row between valid rows")
    check(!parsed.allowsDeletions, "incomplete CSV cannot authorize reference deletions")
}

do {
    let csv = "Start Time,End Time\r\n2026-03-01T09:00:00Z,2026-03-01T10:00:00Z\r\n2026-03-02T09:00:00Z\r\n,,\r\n\r\n"
    let parsed = try CSVImporter.parse(data: Data(csv.utf8), hourlyRate: 40)
    check(parsed.sessions.count == 1 && parsed.skippedRowCount == 2,
          "CSV counts missing fields and empty data rows but not blank lines")
    let complete = try CSVImporter.parse(data: Data("Start Time,End Time,Notes\n2026-03-01T09:00:00Z,2026-03-01T10:00:00Z,\"one\ntwo\"\n".utf8), hourlyRate: 40)
    check(complete.skippedRowCount == 0 && complete.allowsDeletions && complete.sessions[0].note == "one\ntwo",
          "complete CSV with a quoted multiline field can still be a reference")
}
do {
    let text = "Mar 1, 2026 - Mar 7, 2026 Monday March 2 Approved Project 09:00 10:00 Tuesday March 3 Approved Project unreadable 10:00 Wednesday March 4 Approved Project 09:00 10:00"
    let parsed = try PastedTextImporter.parse(text, hourlyRate: 40)
    check(parsed.sessions.count == 2 && parsed.skippedRowCount == 1 && !parsed.allowsDeletions,
          "pasted timecards report an unreadable middle row and forbid deletion")
    check(parsed.sessions.map { calendar.component(.day, from: $0.start) } == [2, 4],
          "a malformed pasted row cannot consume the next row's times")
    let blocks = "Monday\nMarch 2\nProject\n09:00\n10:00\nTuesday\nMarch 3\nApproved\nProject\n25:00\n10:00\nWednesday March 4 Approved Project 11:00 12:00"
    let mixed = try PastedTextImporter.parse(blocks, hourlyRate: 40, now: at(7, 12, 0))
    check(mixed.sessions.count == 2 && mixed.skippedRowCount == 1,
          "mixed line and block formats keep readable rows and report invalid times")
    let complete = try PastedTextImporter.parse("ThursdaySeptember 10 Approved Project 09:00 17:00", hourlyRate: 40)
    check(complete.sessions.count == 1 && complete.allowsDeletions,
          "complete pasted rows with joined weekday and month remain supported")
}

do {
    let csv = "Start Time,End Time,Notes\n2026-03-01T09:00:00Z,2026-03-01T10:00:00Z,valid\n2026-03-02T09:00:00Z,2026-03-02T10:00:00Z,\"unfinished"
    let parsed = try CSVImporter.parse(data: Data(csv.utf8), hourlyRate: 40)
    check(parsed.sessions.count == 1 && parsed.skippedRowCount == 1 && !parsed.allowsDeletions,
          "unterminated CSV quoting is reported instead of making a complete reference")
}
do {
    let text = "September 1, 2026 - September 7, 2026 Monday September 1 Approved Project 09:00 10:00 September 2 Approved Project 09:00 10:00 Wednesday September 3 Approved Project 09:00 10:00"
    let parsed = try PastedTextImporter.parse(text, hourlyRate: 40)
    check(parsed.sessions.count == 2 && parsed.skippedRowCount == 1 && !parsed.allowsDeletions,
          "a pasted date row with no weekday is reported while the page range is ignored")
}

do {
    let candidate = session(9, 0, 12, 0, source: "timeportal")
    let (s, dir) = store([candidate]); defer { try? FileManager.default.removeItem(at: dir) }
    let review = s.compareImportedSessions([session(14, 0, 15, 0, source: "timeportal")], fileIsReference: true)
    check(s.updateSession(id: candidate.id, start: candidate.start, end: at(4, 12, 30), note: candidate.note),
          "the reviewed candidate changes only its end")
    check(!s.importSessions([], removing: review.leftovers) && s.sessions.count == 1,
          "store refuses deletion when only the reviewed end changed")
    let current = s.sessions[0]
    check(s.updateSession(id: current.id, start: current.start, end: current.end, note: "Edited after review"),
          "the reviewed candidate changes only its note")
    check(!s.importSessions([], removing: [current]), "store also protects edited reviewed metadata")
}

do {
    let prefix = "Start Time,End Time\n2026-03-01T09:00:00Z,2026-03-01T10:00:00Z\n"
    for suffix in ["\"", "\"\"", "\"\"\n"] {
        let parsed = try CSVImporter.parse(data: Data((prefix + suffix).utf8), hourlyRate: 40)
        check(parsed.skippedRowCount == 1 && !parsed.allowsDeletions,
              "an empty quoted data row is reported, including at end of file")
    }
}

// Kaynak adindaki gun ve ay sozcukleri yeni bir puantaj baslatmaz.
do {
    for source in ["Monday", "Monday Review", "SundayService", "September 15 Launch", "Monday September 15 Launch"] {
        for separator in [" ", "\n"] {
            let text = ["Monday", "September 14", "Approved", source, "09:00", "10:00"].joined(separator: separator)
            let parsed = try? PastedTextImporter.parse(text, hourlyRate: 40)
            check(parsed?.sessions.count == 1 && parsed?.sessions.first?.source == source
                  && parsed?.sessions.first?.note == "Approved • \(source)"
                  && parsed?.sessions.first?.duration == 3600 && parsed?.skippedRowCount == 0,
                  "weekday/date source stays intact in inline and block rows: \(source)")
        }
    }
    let good = "Monday September 14 Approved Project 09:00 10:00"
    let header = "Tuesday September 1, 2026 - Wednesday September 30, 2026"
    let withHeader = try PastedTextImporter.parse(header + "\n" + good, hourlyRate: 40)
    check(withHeader.sessions.count == 1 && withHeader.skippedRowCount == 0 && withHeader.allowsDeletions,
          "weekday-bearing date-range header is not a rejected entry")
    let three = try PastedTextImporter.parse(good + "\nTuesday September 15 Approved Monday Review 11:00 12:00\nWednesday September 16 Approved Project 09:00 10:00", hourlyRate: 40)
    check(three.sessions.map(\.source) == ["Project", "Monday Review", "Project"] && three.skippedRowCount == 0,
          "weekday source in a middle row preserves all three entries")
    let footer = try PastedTextImporter.parse(good + "\nMonday Tuesday Wednesday Thursday Friday Saturday Sunday", hourlyRate: 40)
    check(footer.sessions.count == 1 && footer.skippedRowCount == 0,
          "weekday labels outside row grammar do not count as rejected entries")
    let truncated = try PastedTextImporter.parse(good + "\nTuesday\nSeptember 15", hourlyRate: 40)
    check(truncated.sessions.count == 1 && truncated.skippedRowCount == 1 && !truncated.allowsDeletions,
          "a final block truncated after its date remains a rejected row")
}

// Approved sayfa toplami yalnizca Approved satirlari kapsar.
do {
    let text = "September 1, 2026 - September 30, 2026\n1h 00m Approved\nMonday September 14 Approved Project 09:00 10:00\nTuesday September 15 Submitted Project 09:00 10:00"
    let parsed = try PastedTextImporter.parse(text, hourlyRate: 40)
    var extra = parsed.sessions[0]
    extra.id = UUID(); extra.start += 120; extra.end += 120
    let (s, dir) = store(parsed.sessions + [extra]); defer { try? FileManager.default.removeItem(at: dir) }
    let summary = s.compareImportedSessions(parsed.sessions, fileIsReference: true)
    let review = TimecardImportReview(parsed: parsed, summary: summary, sourceTitle: "probe",
                                    approvedDuration: PastedTextImporter.approvedSummaryDuration(in: text))
    check(parsed.skippedRowCount == 0 && summary.actionableItems.isEmpty && summary.leftovers.map(\.id) == [extra.id],
          "complete mixed-status paste identifies a deletion-only cleanup")
    check(review.duration == 7200 && review.allowsDeletions,
          "Approved subtotal agrees with Approved rows while Submitted work remains importable")
    check(s.importSessions(summary.sessionsToImport(excluding: []), removing: review.leftovers)
          && s.sessions.count == 2 && !s.sessions.contains(where: { $0.id == extra.id }),
          "complete mixed-status review can remove a leftover without importing new work")
}

// Durumlar, blok bicimi ve eksik satir guvencesi birlikte korunur.
do {
    func review(_ text: String) throws -> TimecardImportReview {
        let parsed = try PastedTextImporter.parse(text, hourlyRate: 40)
        let (s, dir) = store([]); defer { try? FileManager.default.removeItem(at: dir) }
        return TimecardImportReview(parsed: parsed, summary: s.compareImportedSessions(parsed.sessions),
                                    sourceTitle: "probe", approvedDuration: PastedTextImporter.approvedSummaryDuration(in: text))
    }
    let mixed = try review("1h 00m Approved\nMonday September 14 aPpRoVeD Project 09:00 10:00\nTuesday September 15 Submitted Project 09:00 11:00\nWednesday September 16 Draft Project 09:00 12:00\nThursday September 17 Unapproved Project 09:00 13:00")
    check(mixed.sessions.map { mixed.parsed.statuses[$0.id] } == [.approved, .submitted, .draft, .unapproved],
          "all parsed row statuses survive independently of display notes and letter case")
    check(mixed.duration == 36000 && mixed.parsed.approvedDuration == 3600 && mixed.matchesApprovedTotal && mixed.allowsDeletions,
          "Submitted, Draft and Unapproved durations do not inflate the Approved subtotal")
    let zero = try review("0h 00m Approved\nMonday September 14 Unapproved Project 09:00 10:00")
    check(zero.parsed.approvedDuration == 0 && zero.allowsDeletions, "zero Approved work agrees with a zero page subtotal")
    let block = try review("1h 00m Approved\nMonday\nSeptember 14\nApproved\n09:00\n10:00")
    check(block.parsed.statuses[block.sessions[0].id] == .approved && block.allowsDeletions,
          "fallback block parser retains Approved status when the source is missing")
    let overnight = try review("1h 30m Approved\nMonday September 14 Approved Project 23:30 01:00 30 M")
    check(overnight.duration == 5400 && overnight.parsed.approvedDuration == 5400 && overnight.allowsDeletions,
          "Approved and imported totals share stored elapsed duration semantics across midnight")
    let missing = try review("2h 00m Approved\nMonday September 14 Approved Project 09:00 10:00\nTuesday September 15 Submitted Project 09:00 10:00")
    check(!missing.matchesApprovedTotal && !missing.allowsDeletions,
          "other statuses cannot mask missing Approved work even when the all-row total agrees")
    let skipped = try review("1h 00m Approved\nMonday September 14 Approved Project 09:00 10:00\nTuesday September 15 Submitted Project unreadable 10:00")
    check(skipped.matchesApprovedTotal && skipped.parsed.skippedRowCount == 1 && !skipped.allowsDeletions,
          "matching Approved subtotal never overrides the skipped-row guard")
    for (minutes, allowed) in [(1, true), (2, false)] {
        let tolerance = try review("1h 0\(minutes)m Approved\nMonday September 14 Approved Project 09:00 10:00")
        check(tolerance.allowsDeletions == allowed, "Approved subtotal retains its one-minute tolerance: \(minutes)m")
    }
    let noSummary = try review("Monday September 14 Submitted Project 09:00 10:00")
    check(noSummary.approvedDuration == nil && noSummary.allowsDeletions, "complete paste without a page subtotal remains a reference")
}

// Siralama degisebilir, fakat her kaydin butun alanlari ayni kalmali.
do {
    let first = session(9, 0, 12, 0, source: "timeportal")
    let second = session(day: 20, 14, 0, 15, 0, source: "Clockin")
    let (s, dir) = store([first, second]); defer { try? FileManager.default.removeItem(at: dir) }
    let review = s.compareImportedSessions([first], fileIsReference: true)
    check(review.isCurrent(for: [second, first]), "review remains current when only archive order changes")
    let changes: [(String, (inout WorkSession) -> Void)] = [
        ("id", { $0.id = UUID() }), ("start", { $0.start += 0.001 }),
        ("end", { $0.end += 0.001 }), ("duration", { $0.duration += 0.001 }),
        ("note", { $0.note += " edited" }), ("hourlyRate", { $0.hourlyRate += 0.001 }),
        ("source", { $0.source += " edited" }), ("matchedExternalSource", { $0.matchedExternalSource = "linked" })
    ]
    for (field, change) in changes {
        var edited = second; change(&edited)
        check(!review.isCurrent(for: [edited, first]), "review detects exact \(field) edit even outside imported days")
    }
    check(!review.isCurrent(for: [first]) && !review.isCurrent(for: [second, first, first]),
          "review rejects added or removed archive entries")
    check(!review.isCurrent(for: [first, first]), "repeated ID cannot hide a removed reviewed entry")
}

do {
    var low = session(9, 0, 12, 0, source: "Clockin")
    low.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var high = low; high.id = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    high.note = "another copy"
    let incoming = session(9, 0, 12, 5, source: "timeportal")
    let (s, dir) = store([high, low]); defer { try? FileManager.default.removeItem(at: dir) }
    let review = s.compareImportedSessions([incoming], fileIsReference: true)
    check(review.matchedItems.first?.localMatch?.id == low.id && review.leftovers.map(\.id) == [high.id],
          "equal-overlap matches use a stable ID tie-break")
    var reordered = s.data; reordered.sessions.reverse()
    check(s.applySynced(reordered) && review.isCurrent(for: s.data.sessions), "sync reordering leaves the chosen correction review valid")
    check(s.compareImportedSessions([incoming], fileIsReference: true).matchedItems.first?.localMatch?.id == low.id,
          "recomputed correction targets the same ID after reordering")
    check(s.importSessions(review.sessionsToImport(excluding: []))
          && s.sessions.first(where: { $0.id == low.id })?.end == incoming.end
          && s.sessions.first(where: { $0.id == high.id }) == high,
          "confirmation after reordering updates exactly the reviewed correction target")
    for existing in [[high, low], [low, high]] {
        let (duplicates, dir) = store(existing); defer { try? FileManager.default.removeItem(at: dir) }
        let exact = session(9, 0, 12, 0, source: "timeportal")
        let summary = duplicates.compareImportedSessions([exact], fileIsReference: true)
        check(summary.duplicateItems.count == 1 && summary.leftovers.map(\.id) == [high.id],
              "exact duplicates keep the same representative regardless of archive order")
        check(duplicates.importSessions([exact])
              && duplicates.sessions.first(where: { $0.id == low.id })?.matchedExternalSource == "timeportal"
              && duplicates.sessions.first(where: { $0.id == high.id })?.matchedExternalSource == nil,
              "duplicate import links only the stable representative")
    }
}

print("\(checks) import checks passed")
