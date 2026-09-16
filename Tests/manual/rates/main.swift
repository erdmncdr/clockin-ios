import Foundation

enum AppGroup {
    static var snapshotURL: URL { fatalError("Pass an explicit test URL") }
}

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

MainActor.assumeIsolated {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    NSTimeZone.default = calendar.timeZone
    let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
    let today = day.addingTimeInterval(3 * 86400)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clockin-rates-\(UUID())")
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    func session(_ start: Date, hours: Double = 1) -> WorkSession {
        WorkSession(id: UUID(), start: start, end: start.addingTimeInterval(hours * 3600),
                    duration: hours * 3600, note: "Rate fixture", hourlyRate: 99, source: "Clockin")
    }
    let before = session(day.addingTimeInterval(-86400))
    let boundary = session(day)
    let after = session(day.addingTimeInterval(86400))
    let overnight = session(day.addingTimeInterval(-3600), hours: 2)
    let url = directory.appendingPathComponent("rates.json")
    var data = ClockinData()
    data.hourlyRate = 25
    data.rateRules = [RateRule(effectiveFrom: day.addingTimeInterval(-10 * 86400), hourlyRate: 25)]
    data.sessions = [before, boundary, after, overnight]
    try! JSONEncoder().encode(data).write(to: url)
    let store = ClockStore(fileURL: url, calendar: calendar, now: { today })
    check(store.rateHistorySummary == .single(25), "one open rule is single")
    let original = store.rateRules
    let proposed = store.proposedRates(for: 35, from: day.addingTimeInterval(4000))!
    check(store.rateRules == original, "preview does not mutate or save")
    let impact = store.earningsImpact(ofRates: proposed)
    check(impact.sessions == 2 && impact.delta == 20, "impact counts only changed completed sessions")
    check(store.setRate(35, from: day.addingTimeInterval(4000)), "splitting saves")
    check(store.rateHistorySummary == .changed(earlier: 25, current: 35, on: day), "split summary derives all values from rules")
    check(store.hourlyRate == 35, "current setting stays synchronized")
    check(store.earnings(for: before) == 25, "before change earns earlier rate")
    check(store.earnings(for: boundary) == 35, "midnight on change day earns new rate")
    check(store.earnings(for: after) == 35, "after change earns new rate")
    check(store.earnings(for: overnight) == 50, "crossing midnight keeps start day rate")
    check(store.totalEarnings == 145, "cached totals reprice through rule lookup")
    check(store.earnings(on: day) == 35, "daily totals use new rule")
    check(store.rateRules.allSatisfy { calendar.startOfDay(for: $0.effectiveFrom) == $0.effectiveFrom
        && ($0.effectiveUntil == nil || calendar.startOfDay(for: $0.effectiveUntil!) == $0.effectiveUntil!) },
          "stored dates are start of day")
    check(store.rateRules[0].effectiveUntil == day.addingTimeInterval(-86400), "earlier end is previous day")
    for offset in -3...3 {
        let date = day.addingTimeInterval(Double(offset) * 86400)
        check(store.rateRules.filter { $0.applies(to: date, calendar: calendar) }.count == 1,
              "exactly one rate covers day \(offset)")
    }
    let reopened = ClockStore(fileURL: url, calendar: calendar, now: { today })
    check(reopened.rateRules == store.rateRules && reopened.totalEarnings == 145, "save and reload preserve periods and earnings")
    check(store.setEarlierRate(25, changedOn: day.addingTimeInterval(86400)), "moving change date saves")
    check(store.earnings(for: boundary) == 25 && store.earnings(for: after) == 35, "moving date moves boundary earnings")
    let cheaper = store.proposedRates(earlier: 20, changedOn: day.addingTimeInterval(86400))!
    let cheaperImpact = store.earningsImpact(ofRates: cheaper)
    check(cheaperImpact.sessions == 3 && cheaperImpact.delta == -20, "impact reports a signed decrease")
    check(store.setEarlierRate(20, changedOn: day.addingTimeInterval(86400)), "editing earlier rate saves")
    check(store.earnings(for: before) == 20 && store.earnings(for: after) == 35, "earlier edit keeps current period")
    check(store.setRate(40, from: nil), "always saves")
    check(store.earnings(for: boundary) == 20 && store.earnings(for: after) == 40, "always reprices only current rule coverage")
    let removal = store.proposedRates(earlier: nil, changedOn: day)!
    let removalImpact = store.earningsImpact(ofRates: removal)
    check(removalImpact.sessions == 3 && removalImpact.delta == 80, "removal impact counts earlier work and its duration")
    check(store.setEarlierRate(nil, changedOn: day), "removing split saves")
    check(store.rateHistorySummary == .single(40) && store.rateRules.count == 1, "removal leaves one open rule")
    check(store.totalEarnings == 200, "removal uses current rate for all work")
    check(store.setRate(35, from: nil) && store.totalEarnings == 175, "always reprices whole single-rule archive")
    check(store.setEarlierRate(25, changedOn: day), "toggle can create earlier history from current rate")
    check(store.setEarlierRate(25, changedOn: day.addingTimeInterval(-20 * 86400)), "change can precede original period")
    check(store.rateRules[0].effectiveFrom <= store.rateRules[0].effectiveUntil!, "very early change keeps valid earlier interval")
    let stable = store.rateRules
    check(!store.setRate(.infinity, from: day) && store.rateRules == stable, "infinite rate is rejected")
    check(!store.setEarlierRate(-1, changedOn: day) && store.rateRules == stable, "negative earlier rate is rejected")
    check(!store.setRate(50, from: today.addingTimeInterval(86400)) && store.rateRules == stable, "future change is rejected")
    check(store.setEarlierRate(25, changedOn: day), "restore fixture split")
    store.clockIn(at: today)
    check(store.setRate(45, from: today), "later raise preserves both earlier periods")
    check(store.currentRate(at: today.addingTimeInterval(3600)) == 45, "today's running session uses new rate")
    check(store.currentEarnings(at: today.addingTimeInterval(3600)) == 45, "live earnings use new rate")
    check(store.earningsImpact(ofRates: store.rateRules).sessions == 0, "unchanged rules and running sessions add no completed impact")
    check(store.rateHistorySummary == .custom && store.rateRules.count == 3, "three periods are custom")
    let custom = store.rateRules
    check(!store.setEarlierRate(nil, changedOn: day) && store.rateRules == custom, "simple toggle cannot erase custom periods")
    check(!store.setRate(99, from: day) && store.rateRules == custom, "simple rate change cannot overwrite custom schedule")
    check(!store.setRate(99, from: nil) && store.rateRules == custom, "always also protects custom schedule")
    let todaySnapshot = ClockinSnapshot(store: store, at: today.addingTimeInterval(3600))
    check(todaySnapshot.hourlyRate == 45, "widget and Live Activity receive today's raised running rate")
    store.cancelRunning()

    data.rateRules = [RateRule(effectiveFrom: day.addingTimeInterval(-86400), effectiveUntil: day, hourlyRate: 25),
                      RateRule(effectiveFrom: day.addingTimeInterval(2 * 86400), hourlyRate: 35)]
    let gapURL = directory.appendingPathComponent("gap.json")
    try! JSONEncoder().encode(data).write(to: gapURL)
    let gap = ClockStore(fileURL: gapURL, calendar: calendar, now: { today })
    check(gap.rateHistorySummary == .custom, "a gap is custom")
    check(!gap.setEarlierRate(10, changedOn: day), "simple API leaves a gap schedule untouched")
    data.rateRules = [RateRule(effectiveFrom: day.addingTimeInterval(-86400), hourlyRate: 25),
                      RateRule(effectiveFrom: day, hourlyRate: 35)]
    let overlapURL = directory.appendingPathComponent("overlap.json")
    try! JSONEncoder().encode(data).write(to: overlapURL)
    let overlap = ClockStore(fileURL: overlapURL, calendar: calendar, now: { today })
    check(overlap.rateHistorySummary == .custom, "overlapping open rules are custom")

    data.rateRules = [RateRule(effectiveFrom: day.addingTimeInterval(-86400), hourlyRate: 25)]
    data.running = RunningSession(start: day.addingTimeInterval(-3600), accumulated: 7200, resumedAt: nil, note: "Night fixture")
    let liveURL = directory.appendingPathComponent("live.json")
    try! JSONEncoder().encode(data).write(to: liveURL)
    let live = ClockStore(fileURL: liveURL, calendar: calendar, now: { today })
    check(live.setRate(35, from: day), "overnight split saves")
    check(live.currentRate(at: today) == 25 && live.currentEarnings(at: today) == 50, "running overnight work stays at earlier rate")
    let liveSnapshot = ClockinSnapshot(store: live, at: day)
    check(liveSnapshot.hourlyRate == 25, "widget and Live Activity snapshot keep overnight start rate")
    check(liveSnapshot.earnedToday == 35, "widget completed earnings use change-day rate")
    let saved = live.clockOut(at: today)!
    check(live.earnings(for: saved) == 50, "clock out keeps live earnings")
    let rollback = live.rateRules
    try! FileManager.default.removeItem(at: liveURL)
    try! FileManager.default.createDirectory(at: liveURL, withIntermediateDirectories: false)
    check(!live.setEarlierRate(10, changedOn: day), "failed save is reported")
    check(live.rateRules == rollback && live.hourlyRate == 35, "failed save rolls back rules and current rate")

    data.sessions = []
    data.running = nil
    let emptyURL = directory.appendingPathComponent("empty.json")
    try! JSONEncoder().encode(data).write(to: emptyURL)
    let empty = ClockStore(fileURL: emptyURL, calendar: calendar, now: { today })
    check(!empty.hasWorkBeforeToday, "brand-new user has no earlier work")
    check(empty.earningsImpact(ofRates: empty.proposedRates(for: 35, from: today)!).sessions == 0, "new user has no completed-session impact")
}
print("\(checks) rate checks passed")
