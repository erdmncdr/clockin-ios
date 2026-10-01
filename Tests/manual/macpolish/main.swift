import Foundation

var checks = 0
@MainActor func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
    checks += 1
    print("ok \(message)")
}

var gesture = MacPeriodScroll()
@MainActor func scroll(_ x: Double, _ y: Double = 0, _ phase: MacPeriodScroll.Phase = .changed,
            momentum: Bool = false, precise: Bool = true, time: Double = 1) -> (consumed: Bool, direction: Int?) {
    gesture.update(x: x, y: y, phase: phase, momentum: momentum, precise: precise, time: time)
}
check(scroll(-20, 1, .began).direction == nil, "below threshold")
check(scroll(-31).direction == 1, "left content motion advances one period")
check(scroll(-150).direction == nil, "one step for long gesture")
check(scroll(200).direction == nil, "reversal cannot add a second step")
check(scroll(-200, time: 5).direction == nil, "pause within phased gesture does not reset it")
check(scroll(-4, 0, .ended).direction == nil, "lift does not add a step")
let momentum = scroll(-200, momentum: true)
check(momentum.consumed && momentum.direction == nil, "momentum consumed without paging")
check(scroll(51, 0, .began).direction == -1, "opposite signed system delta moves back")
check(!scroll(1, 20, .began).consumed, "vertical gesture passed through")
check(!scroll(120, 0).consumed, "vertical axis remains locked")
check(scroll(20, 0, .began).direction == nil, "new gesture resets threshold")
check(!scroll(50, 0, .cancelled).consumed, "cancel does not page")
check(scroll(-100, momentum: true).direction == nil, "cancel momentum cannot page")
check(scroll(-100, 0, .began, precise: false).direction == nil, "ordinary mouse wheel ignored")
check(scroll(-55, 0, .none, time: 10).direction == 1, "phase-less precise input supported")
check(scroll(-90, 0, .none, time: 10.1).direction == nil, "phase-less burst only once")
check(scroll(55, 0, .none, time: 11).direction == -1, "phase-less new burst resets")
gesture = MacPeriodScroll()
check(!scroll(-100).consumed, "entering a region mid-gesture cannot page")

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
let october = calendar.dateInterval(of: .month, for: today)!
let future = calendar.date(byAdding: .day, value: 20, to: today)!
check(MacChartInspection.date(future, monthly: false, interval: october, now: today, calendar: calendar) == nil, "future day not inspectable")
check(MacChartInspection.date(today.addingTimeInterval(40000), monthly: false, interval: october, now: today, calendar: calendar) == today, "today can be inspected across the bar width")
check(MacChartInspection.date(future, monthly: true, interval: october, now: today, calendar: calendar) == today, "current monthly bar remains inspectable")
check(MacChartInspection.date(october.end, monthly: true, interval: october, now: today, calendar: calendar) == nil, "next month cannot be inspected")
check(MacChartInspection.date(today.addingTimeInterval(-1), monthly: false, interval: october, now: today, calendar: calendar) == nil, "outside plot domain rejected")
check(MacChartInspection.date(nil, monthly: false, interval: october, now: today, calendar: calendar) == nil, "missing chart coordinate rejected")

for ratio in [16.0 / 10, 16.0 / 9, 3.0 / 2] {
    let screen = CGSize(width: 1440, height: 1440 / ratio)
    let room = MacDeskFraming.roomSize(in: screen)
    let scale = room.height / 240
    let top = MacDeskFraming.topCrop(in: screen) / scale
    let bottom = top + screen.height / scale
    check(room.width >= screen.width && room.height >= screen.height, "room fills \(ratio) screen")
    check(top <= 30 && bottom >= 224, "window top and companion feet visible at \(ratio)")
    check(abs(room.width / room.height - 1.5) < 0.0001, "room aspect preserved at \(ratio)")
}
print("TOTAL \(checks) FAILED 0")
