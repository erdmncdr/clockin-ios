import Foundation
import CoreGraphics

@MainActor final class TestLoop {
    var scheduled: [@MainActor () -> Void] = []
    var value: Int?
    var writes = 0
    var reads = 0
    var inLayout = false
    func read() -> Int? { reads += 1; return value }
    func write(_ next: Int?) {
        precondition(!inLayout, "state written during layout")
        value = next
        writes += 1
    }
    func drain() {
        let work = scheduled
        scheduled.removeAll()
        for callback in work { callback() }
    }
}

var checks = 0
@MainActor func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
    print("ok \(message)")
}

let loop = TestLoop()
let delivery = MacDeferredValue<Int?> { loop.scheduled.append($0) }
loop.inLayout = true
for value in 0..<1000 { delivery.submit(value, read: loop.read, write: loop.write) }
check(loop.value == nil && loop.writes == 0 && loop.reads == 0, "no binding read or write in layout callback")
check(loop.scheduled.count == 1, "1000 callbacks schedule one delivery")
loop.inLayout = false
loop.drain()
check(loop.value == 999 && loop.writes == 1, "latest callback wins")
for _ in 0..<1000 {
    delivery.submit(999, read: loop.read, write: loop.write)
    loop.drain()
}
check(loop.writes == 1, "repeated layouts with the same value never write again")
delivery.submit(1, read: loop.read, write: loop.write)
delivery.submit(nil, read: loop.read, write: loop.write)
loop.drain()
check(loop.value == nil && loop.writes == 2, "hover exit replaces pending enter including optional nil")
delivery.submit(1, read: loop.read, write: loop.write)
delivery.submit(nil, read: loop.read, write: loop.write)
loop.drain()
check(loop.writes == 2, "enter/exit in one pass returning to current value is a no-op")
delivery.submit(2, read: loop.read, write: loop.write)
loop.value = 2
loop.drain()
check(loop.writes == 2, "comparison reads current binding at delivery time")
delivery.submit(3, read: loop.read, write: loop.write)
delivery.cancel()
delivery.submit(4, read: loop.read, write: loop.write)
loop.scheduled.removeFirst()()
check(loop.value == 2, "cancelled generation cannot deliver a new generation early")
loop.drain()
check(loop.value == 4 && loop.writes == 3, "new generation delivers normally")
var detached: MacDeferredValue<Int?>? = MacDeferredValue { loop.scheduled.append($0) }
detached?.submit(5, read: loop.read, write: loop.write)
detached = nil
loop.drain()
check(loop.value == 4, "destroyed view cannot deliver stale callback")
// A delivery may itself invalidate the layout. Its successor needs another turn.
delivery.submit(6, read: loop.read) { value in
    loop.write(value)
    delivery.submit(7, read: loop.read, write: loop.write)
}
loop.drain()
check(loop.value == 6 && loop.scheduled.count == 1, "reentrant submit waits for another turn")
loop.drain()
check(loop.value == 7, "reentrant delivery completes")

for width in [720.0, 960, 1440, 1920] {
    for ratio in [16.0 / 10, 16.0 / 9, 3.0 / 2] {
        let screen = CGSize(width: width, height: width / ratio)
        // DeskModeView's existing 24 horizontal / 16 vertical padding.
        let viewport = CGSize(width: screen.width - 48, height: screen.height - 32)
        let panel = MacDeskFraming.timerPanel(in: viewport).offsetBy(dx: 24, dy: 16)
        let scale = MacDeskFraming.roomSize(in: screen).height / 240
        let furnitureTop = 104 * scale - MacDeskFraming.topCrop(in: screen)
        check(panel.maxY < furnitureTop, "timer clears desk/companion region at \(Int(width)) / \(ratio)")
        check(CGRect(origin: .zero, size: screen).contains(panel), "timer fits viewport at \(Int(width)) / \(ratio)")
    }
}
// Exercise the production main-queue boundary too, without an NSApplication/window.
let production = MacDeferredValue<Int>()
var productionValue = 0
production.submit(1, read: { productionValue }, write: { productionValue = $0 })
check(productionValue == 0, "production scheduler never delivers inline")
DispatchQueue.main.async {
    check(productionValue == 1, "production scheduler delivers on the next main queue turn")
    print("TOTAL \(checks) FAILED 0")
    exit(0)
}
dispatchMain()
