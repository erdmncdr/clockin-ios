import Foundation

// `calendarRateDate` cihazin kendi saat dilimini kullanir, disaridan dilim
// verilemez. Bu yuzden ayni kontroller surecin TZ'si degistirilerek iki kez
// calistirilir: README'deki komut hem UTC+3 hem UTC-7 icin cagirir.
//
// Kontrol edilen sey su: yerel takvim gunu, kurun okundugu UTC anahtariyla ayni
// kalmali. Yerel gece yarisini duz cevirmek UTC'nin ilerisinde bir onceki gunun
// kurunu sorduruyordu.
@MainActor func key(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: ExchangeRateStore.calendarRateDate(date))
}

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1; print("ok: \(name)") }

@MainActor func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

let zone = TimeZone.current.identifier
print("timezone under test: \(zone)")

check(key(for: local(2026, 9, 12)) == "2026-09-12", "local midnight keeps its own calendar day")
check(key(for: local(2026, 9, 12, 23, 59)) == "2026-09-12", "the last minute of a local day stays on that day")
check(key(for: local(2026, 9, 12, 12)) == "2026-09-12", "local noon is unambiguous")
check(key(for: local(2026, 1, 1)) == "2026-01-01", "a new year's local midnight stays in the new year")
check(key(for: local(2025, 12, 31, 23, 59)) == "2025-12-31", "the last minute of a year stays in it")
check(key(for: local(2026, 3, 29)) == "2026-03-29", "a daylight saving transition day keeps its date")
check(key(for: local(2026, 2, 28)) == "2026-02-28", "end of February is unaffected")

// Ardisik gunler birbirine karismamali.
let days = (1...28).map { key(for: local(2026, 4, $0)) }
check(Set(days).count == 28, "28 consecutive local days map to 28 distinct rate keys")
check(days == days.sorted(), "rate keys stay in calendar order")

print("\(checks) rate-date checks passed in \(zone)")
