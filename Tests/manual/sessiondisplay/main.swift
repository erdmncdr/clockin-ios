import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

let start = Date(timeIntervalSince1970: 1_700_000_000)
var session = WorkSession(id: UUID(), start: start, end: start.addingTimeInterval(3600),
                          duration: 3600, note: "", hourlyRate: 25, source: "Clockin")
check(SessionDisplay.subtitle(session) == "Clockin", "own entry without a note uses Clockin")
check(SessionDisplay.isClockin(session), "own entry keeps its timer icon")
session.note = "Synthetic task"
check(SessionDisplay.subtitle(session) == "Synthetic task", "own note is preserved")
for source in ["Synthetic import A", "Synthetic import B", "", "  ", "clockin"] {
    session.source = source
    session.note = ""
    session.matchedExternalSource = nil
    check(SessionDisplay.subtitle(session) == "Imported timecard", "external source is hidden")
    check(!SessionDisplay.isClockin(session), "external entry keeps its import icon")
    session.matchedExternalSource = source
    check(!SessionDisplay.isMatched(session), "self-marked import is not a correction")
    check(SessionDisplay.subtitle(session) == "Imported timecard", "self-marked import stays neutral")
    session.note = "Synthetic task"
    check(SessionDisplay.subtitle(session) == "Synthetic task", "imported note is preserved")
    session.note = " \n "
    check(SessionDisplay.subtitle(session) == "Imported timecard", "whitespace-only note uses neutral fallback")
}
session.source = "Clockin"
session.matchedExternalSource = "Synthetic import A"
check(SessionDisplay.isMatched(session), "external correction is marked")
check(SessionDisplay.subtitle(session) == "Matched timecard", "correction never exposes the matched source")
session.note = "Synthetic task"
check(SessionDisplay.subtitle(session) == "Matched timecard", "correction keeps precedence over a note")
session.source = "Synthetic import B"
check(SessionDisplay.subtitle(session) == "Matched timecard", "cross-source correction stays neutral")
let encoded = try JSONEncoder().encode(session)
let restored = try JSONDecoder().decode(WorkSession.self, from: encoded)
check(restored == session, "display helper does not alter persisted sessions")
check(restored.source == "Synthetic import B" && restored.matchedExternalSource == "Synthetic import A",
      "both raw source values survive export and import unchanged")
session.matchedExternalSource = ""
check(!SessionDisplay.isMatched(session), "empty match metadata is not a correction")
check(SessionDisplay.timecardEntry == "Timecard entry", "import review has a generic entry label")
session.source = "Synthetic import A"
session.matchedExternalSource = session.source
session.note = "Approved • Synthetic import A"
check(SessionDisplay.subtitle(session) == "Approved", "generated pasted note cannot expose the source")
for status in ["Approved", "submitted", "Draft", "UNAPPROVED", "Imported"] {
    session.note = "\(status) • Synthetic import A"
    check(SessionDisplay.note(session) == status, "generated import note retains status only")
    check(SessionDisplay.storedNote(status, for: session) == session.note,
          "saving unchanged visible note preserves raw imported text")
}
session.source = "Clockin"
session.note = "Approved • Synthetic import A"
check(SessionDisplay.note(session) == "Approved", "matched entry also hides source inside its generated note")
check(SessionDisplay.storedNote("User edited task", for: session) == "User edited task", "user note edits are saved")
check(SessionDisplay.storedNote("", for: session).isEmpty, "user can clear a generated note")
session.note = "Synthetic task • additional details"
check(SessionDisplay.note(session) == session.note, "ordinary notes with bullets are not stripped")
let unchanged = try JSONDecoder().decode(WorkSession.self, from: JSONEncoder().encode(session))
check(unchanged.note == session.note && unchanged.source == session.source
      && unchanged.matchedExternalSource == session.matchedExternalSource,
      "note display never rewrites saved metadata")
let pasted = try PastedTextImporter.parse(
    "Monday September 14 Approved Synthetic import A 09:00 10:00",
    hourlyRate: 25, now: Date(timeIntervalSince1970: 1_789_646_400))
check(pasted.count == 1 && pasted[0].source == "Synthetic import A", "real pasted parser retains synthetic source")
check(SessionDisplay.subtitle(pasted[0]) == "Approved", "real pasted entry hides source inside generated note")
let csv = "Start Time,End Time,Time Sheet Source,Notes\n2026-09-14T09:00:00Z,2026-09-14T10:00:00Z,Synthetic import B,\n"
let imported = try CSVImporter.parse(data: Data(csv.utf8), hourlyRate: 25)
check(imported.count == 1 && imported[0].source == "Synthetic import B", "real CSV parser retains synthetic source")
check(SessionDisplay.subtitle(imported[0]) == "Imported timecard", "real CSV entry uses neutral fallback")
print("\(checks) session display checks passed")
