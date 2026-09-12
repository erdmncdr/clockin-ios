// swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-chime-module-cache iOS/Clockin/Audio/ChimeSchedule.swift iOS/Tests/manual/chime/main.swift -o /tmp/clockin-chime-tests && /tmp/clockin-chime-tests
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}
let now = Date(timeIntervalSince1970: 1_800_000_000)
func dates(_ worked: Double, interval: Int = 10, paused: Bool = false,
           enabled: Bool = true, count: Int = 20, at date: Date = now) -> [Date] {
    ChimeSchedule.fireDates(now: date, worked: worked, isPaused: paused,
        enabled: enabled, intervalMinutes: interval, count: count)
}
check(dates(0).first == now.addingTimeInterval(600), "new session starts at first interval")
check(dates(250).first == now.addingTimeInterval(350), "next fire uses worked time")
check(dates(599.5).first == now.addingTimeInterval(0.5), "fractional work keeps exact boundary")
check(dates(600).first == now.addingTimeInterval(600), "exact multiple skips current boundary")
check(dates(1200).first == now.addingTimeInterval(600), "later exact multiple is not replayed")
check(dates(250, paused: true).isEmpty, "pause cancels all upcoming chimes")
let resumed = now.addingTimeInterval(3600)
check(dates(250, at: resumed).first == resumed.addingTimeInterval(350), "one hour pause does not count as work")
check(dates(750, interval: 5).first == now.addingTimeInterval(150), "interval change resets to current Mac bucket")
check(dates(750, interval: 20).first == now.addingTimeInterval(450), "longer interval skips old baseline")
check(dates(750, enabled: false).isEmpty, "disabled chime has no schedule")
check(dates(750).first == now.addingTimeInterval(450), "enabling mid-session does not replay missed chimes")
check(dates(0, count: 100).count == 20, "request count capped at twenty")
check(dates(0, count: 3).count == 3, "available notification slots respected")
check(dates(0, count: 0).isEmpty && dates(0, count: -1).isEmpty, "no slots produce no dates")
check(dates(0).last == now.addingTimeInterval(12000), "all twenty dates are spaced by interval")
check(dates(0, interval: 0).first == now.addingTimeInterval(600), "unset preference defaults to ten minutes")
check(dates(0, interval: -1).first == now.addingTimeInterval(60), "interval lower bound is one minute")
check(dates(0, interval: 200).first == now.addingTimeInterval(7200), "interval upper bound is 120 minutes")
check(dates(.nan).isEmpty && dates(.infinity).isEmpty && dates(-1).isEmpty, "invalid work produces no notifications")
let later = now.addingTimeInterval(61)
check(dates(311, at: later).first == dates(250).first, "foreground top-up preserves the pending boundary")
print("\(checks) chime checks passed")
