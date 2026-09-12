import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1; print("ok: \(name)")
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = .current
@MainActor func s(_ day: Int, _ sh: Int, _ sm: Int, _ eh: Int, _ em: Int, id: UUID = UUID()) -> WorkSession {
    let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: sh, minute: sm))!
    var end = calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: eh, minute: em))!
    if end < start { end = end.addingTimeInterval(86_400) }
    return WorkSession(id: id, start: start, end: end, duration: end.timeIntervalSince(start),
                       note: "", hourlyRate: 40, source: "Clockin")
}

// Temel kesisme
check(SessionOverlap.intersects(s(11, 9, 0, 12, 0), s(11, 11, 0, 13, 0)), "partly overlapping shifts intersect")
check(!SessionOverlap.intersects(s(11, 9, 0, 12, 0), s(11, 13, 0, 15, 0)), "a gap between shifts is not an overlap")
check(!SessionOverlap.intersects(s(11, 9, 0, 12, 0), s(11, 12, 0, 15, 0)), "back to back shifts do not overlap")
check(SessionOverlap.intersects(s(11, 9, 0, 17, 0), s(11, 10, 0, 11, 0)), "a shift fully inside another intersects")
check(SessionOverlap.intersects(s(11, 9, 0, 12, 0), s(11, 9, 0, 12, 0)), "identical times intersect")
check(!SessionOverlap.intersects(s(11, 9, 0, 12, 0), s(12, 9, 0, 12, 0)), "the same hours on another day do not overlap")
check(SessionOverlap.intersects(s(11, 22, 0, 2, 0), s(12, 0, 30, 1, 0)), "an overnight shift overlaps the next morning")

// touching
do {
    let a = s(11, 9, 0, 12, 0), b = s(11, 14, 0, 18, 0)
    let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 10))!
    let one = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 11))!
    let hits = SessionOverlap.touching(start: noon, end: one, in: [a, b])
    check(hits.count == 1 && hits.first?.id == a.id, "touching finds only the records a range reaches")
    let wide = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 15))!
    check(SessionOverlap.touching(start: noon, end: wide, in: [a, b]).count == 2,
          "a range spanning both records reports both")
    check(SessionOverlap.touching(start: a.start, end: a.end, in: [a, b], excluding: a.id).isEmpty,
          "a record being edited does not clash with itself")
    check(SessionOverlap.touching(start: a.end, end: a.start, in: [a, b]).isEmpty,
          "a backwards range reports nothing instead of matching everything")
    // Ters araligi bastan elemezsek, araligi tumuyle kapsayan uzun bir kayit
    // yarim acik kontrolden geciyor ve cakisma diye raporlaniyor.
    check(SessionOverlap.touching(start: a.end, end: a.start, in: [s(11, 8, 0, 20, 0)]).isEmpty,
          "a record spanning a backwards range is not reported either")
    check(SessionOverlap.touching(start: a.start, end: a.start, in: [a, b]).isEmpty,
          "an empty range touches nothing")
}

// conflicting: zincir halinde ust uste binen alti kayit, biri gece yarisini asiyor
do {
    let pile = [s(11, 9, 0, 12, 0), s(11, 11, 30, 14, 0), s(11, 13, 0, 17, 0),
                s(11, 16, 30, 20, 0), s(11, 19, 30, 1, 0), s(11, 23, 0, 2, 0)]
    let bad = SessionOverlap.conflicting(in: pile)
    check(bad.count == 6, "every record in an overlapping pile is flagged")
}
do {
    let clean = [s(11, 9, 0, 12, 0), s(11, 13, 0, 15, 0), s(11, 16, 0, 18, 0)]
    check(SessionOverlap.conflicting(in: clean).isEmpty, "a tidy day flags nothing")
}
do {
    let a = s(11, 9, 0, 12, 0), b = s(11, 11, 0, 13, 0), c = s(11, 15, 0, 16, 0)
    let bad = SessionOverlap.conflicting(in: [a, b, c])
    check(bad == [a.id, b.id], "only the clashing pair is flagged, not the innocent record")
}
do {
    // Siralama sonucu degistirmemeli.
    let a = s(11, 9, 0, 12, 0), b = s(11, 11, 0, 13, 0), c = s(11, 15, 0, 16, 0)
    check(SessionOverlap.conflicting(in: [c, b, a]) == SessionOverlap.conflicting(in: [a, b, c]),
          "the answer does not depend on input order")
}
do {
    // Uzun bir kayit, sonraki birbirinden uzak iki kaydi da yakalamali.
    let long = s(11, 8, 0, 20, 0), x = s(11, 9, 0, 10, 0), y = s(11, 18, 0, 19, 0)
    check(SessionOverlap.conflicting(in: [long, x, y]).count == 3,
          "a long record still clashes with a later one after an unrelated gap")
}
check(SessionOverlap.conflicting(in: []).isEmpty, "no records, no conflicts")
check(SessionOverlap.conflicting(in: [s(11, 9, 0, 12, 0)]).isEmpty, "a lone record does not clash with itself")

print("\(checks) overlap checks passed")
