import Foundation

var checks = 0
@MainActor func check(_ value: Bool, _ name: String) {
    precondition(value, name)
    checks += 1
    print("ok: \(name)")
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
@MainActor func date(_ day: Int, month: Int = 9, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}
@MainActor func session(_ day: Int, hours: Double = 1, month: Int = 9) -> WorkSession {
    WorkSession(id: UUID(), start: date(day, month: month), end: date(day, month: month).addingTimeInterval(hours * 3600),
                duration: hours * 3600, note: "Synthetic", hourlyRate: 10, source: "test")
}
let now = date(17)
let period = EarningsPeriod(range: .month, anchor: now, now: now, calendar: calendar)
let sessions = [session(16, hours: 2), session(15), session(15, hours: 0.5)]
var lookup = HistoricalRateLookup(rates: ["2026-09-14": 2, "2026-09-16": 3, "2026-09-18": 9])
check(lookup.rate(on: "2026-09-16") == 3, "exact historical rate")
check(lookup.rate(on: "2026-09-15") == 2, "missing day uses nearest earlier rate")
check(lookup.rate(on: "2026-09-17") == 3, "does not use future rate")
check(lookup.rate(on: "2026-09-13") == nil, "no earlier rate stays missing")
check(lookup.rate(on: "2026-09-13") == nil, "missing lookup remains cached")
check(lookup.rate(on: "2026-09-15") == 2, "repeated lookup remains stable")
var emptyLookup = HistoricalRateLookup(rates: [:])
check(emptyLookup.rate(on: "2026-09-17") == nil, "no rates at all")
let formatter = DateFormatter()
formatter.calendar = calendar
formatter.timeZone = calendar.timeZone
formatter.dateFormat = "yyyy-MM-dd"
@MainActor func page(_ values: [WorkSession] = sessions, period selected: EarningsPeriod? = nil,
                     rate: (Date) -> Double?) -> HistoryPage {
    HistoryPage(sessions: values, running: nil, period: selected ?? period, monthlyGoal: 160,
        now: now, calendar: calendar, earnings: { $0.earnings }, activeEarnings: 0, rate: rate)
}
let history = page { lookup.rate(on: formatter.string(from: $0)) }
check(history.snapshot.hasConvertedDays, "available rates allow TRY bars")
check(history.snapshot.earned == 35, "base total unchanged")
check(history.snapshot.converted == 90, "sum uses each session calendar day rate")
check(history.snapshot.sessionAmounts[sessions[0].id]?.converted == 60, "row amount cached")
check(history.days[0].money.converted == 60 && history.days[1].money.converted == 30, "day headers sum cached row amounts")
check(history.months[0].converted == 90, "selected month uses historical sum")
check(history.snapshot.points.first?.converted == 30, "selected day uses historical sum")
check(history.snapshot.money.value(showTRY: true) == 90, "TRY primary")
check(history.snapshot.money.value(showTRY: false) == 35, "USD primary")
check(history.snapshot.money.code(currency: "USD", showTRY: true) == "TRY", "TRY label")
check(history.snapshot.money.divided(by: 17).converted == 90.0 / 17, "calendar daily average in TRY")
check(history.performance?.money.divided(by: 2).converted == 45, "worked day average in TRY")
check(history.performance?.projectedConverted == 90 + 90.0 / 7 * 13, "TRY projection uses recent historical earnings")
check(history.performance?.projectedEarnings == 35 + 35.0 / 7 * 13, "USD projection preserved")
check(history.snapshot.duration == 3.5 * 3600 && history.snapshot.activeDays == 2, "hours and counts unchanged")
check(!history.hasMissingRates, "complete rates need no note")
let missing = page { _ in nil }
check(!missing.snapshot.hasConvertedDays, "no rates switches chart to USD")
check(missing.snapshot.converted == nil, "unavailable total does not become zero")
check(missing.snapshot.money.value(showTRY: true) == 35, "unavailable total falls back to USD")
check(missing.snapshot.money.code(currency: "USD", showTRY: true) == "USD", "fallback labeled USD")
check(missing.performance?.money.divided(by: 2).value(showTRY: true) == 17.5, "average falls back to USD")
check(missing.performance?.projectedConverted == nil, "projection unavailable without rates")
check(missing.hasMissingRates, "page flags missing rates once")
let partial = page { calendar.component(.day, from: $0) == 16 ? 3 : nil }
check(partial.snapshot.hasConvertedDays, "partial chart keeps available TRY bars")
check(partial.snapshot.converted == nil, "partial totals never mix currencies")
check(partial.days[0].money.converted == 60 && partial.days[1].money.converted == nil, "available day converts, unavailable day falls back")
check(partial.months[0].converted == nil, "incomplete month detail falls back")
let blank = page([]) { _ in nil }
check(blank.snapshot.converted == 0 && !blank.hasMissingRates, "empty page is zero without missing-rate warning")
let olderPeriod = EarningsPeriod(range: .month, anchor: date(15, month: 8), now: now, calendar: calendar)
let older = page([session(15, month: 8)], period: olderPeriod) { _ in 4 }
check(older.snapshot.converted == 40 && older.performance?.projectedConverted == nil, "past month total without projection")
for range in [EarningsRange.week, .sixMonths, .all] {
    let selected = EarningsPeriod(range: range, anchor: now, now: now, calendar: calendar)
    let result = page(period: selected) { lookup.rate(on: formatter.string(from: $0)) }
    check(result.snapshot.converted == 90 && result.performance == nil, "\(range) totals without month-only calculation")
}
let running = RunningSession(start: date(16), accumulated: 3600, resumedAt: nil, note: "Synthetic")
let active = HistoryPage(sessions: [], running: running, period: period, monthlyGoal: 0,
    now: now, calendar: calendar, earnings: { $0.earnings }, activeEarnings: 10,
    rate: { lookup.rate(on: formatter.string(from: $0)) })
check(active.snapshot.converted == 30 && active.days.isEmpty, "active work uses its start day and stays out of completed rows")
let earlyNow = date(2)
let earlyPeriod = EarningsPeriod(range: .month, anchor: earlyNow, now: earlyNow, calendar: calendar)
let early = HistoryPage(sessions: [session(31, month: 8), session(1)], running: nil, period: earlyPeriod,
    monthlyGoal: 0, now: earlyNow, calendar: calendar, earnings: { $0.earnings }, activeEarnings: 0,
    rate: { calendar.component(.month, from: $0) == 9 ? 3 : nil })
check(early.snapshot.converted == 30 && early.performance?.projectedConverted == nil && early.hasMissingRates,
      "projection warns for missing recent rate outside current page")
for contentWidth in [CGFloat(289), 321, 350] {
    for textWidth in [CGFloat(60), 90, 120, 180, 400] {
        let placement = ReadyWidgetPlacement(contentWidth: contentWidth, textWidth: textWidth)
        check(placement.centerX - placement.textWidth / 2 >= 88, "widget preserves companion spacing \(contentWidth)/\(textWidth)")
        check(placement.centerX + placement.textWidth / 2 <= contentWidth, "widget fits trailing edge \(contentWidth)/\(textWidth)")
        check(placement.centerX == max(contentWidth / 2, 88 + placement.textWidth / 2), "widget shifts only required distance \(contentWidth)/\(textWidth)")
    }
}
check(ReadyWidgetPlacement(contentWidth: 289, textWidth: 90).centerX == 144.5, "smallest widget centers normal ready group")
print("\(checks) history TRY and widget checks passed")
