// The Mac menu-bar item: while clocked in its live text follows the icon
// whenever Show details is on, in minimal mode or not; idle, or with details
// off, it is the icon alone. Runs the real MenuBarController in a throwaway
// accessory process, which briefly adds an icon to the menu bar.
//
// swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/AppLanguage.swift ClockinMac/MacDurationText.swift ClockinMac/MenuBarController.swift ClockinMac/MenuBarStatus.swift ClockinMac/MenuBarIcon.swift ClockinMac/MenuBarVisibility.swift ClockinMac/ApplicationMover.swift ClockinMac/MenuBarProbe.swift Tests/manual/macmenubar/main.swift -o /tmp/clockin-macmenubar && /tmp/clockin-macmenubar
import AppKit
import Combine
import SwiftUI


var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
}
func spin(_ seconds: TimeInterval) { RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds)) }

@MainActor final class Model {
    var running = false
    var details = true
    var minimal = false
}
let model = Model()
let changes = PassthroughSubject<Void, Never>()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()

let controller = MenuBarController.shared
controller.start(MenuBarController.Host(
    status: {
        guard model.running else { return MenuBarStatus(state: .idle, text: nil) }
        return MenuBarStatus(state: .running, text: model.details ? "01:07 · $28" : nil)
    },
    minimalMode: { model.minimal },
    changes: changes.eraseToAnyPublisher(),
    content: { _ in AnyView(Color.clear.frame(width: 10, height: 10)) },
    menu: { NSMenu() }
))
spin(0.3)
guard let button = controller.statusItem?.button else { check(false, "the status item has a button"); exit(1) }

@MainActor func update() { changes.send(); spin(0.25) }

check(button.image != nil && button.title.isEmpty, "idle: the icon alone")
model.running = true; update()
check(button.title == " 01:07 · $28", "clocked in with default settings, the live text shows (got '\(button.title)')")
model.minimal = true; update()
check(button.title == " 01:07 · $28", "minimal mode shows the same text")
model.details = false; update()
check(button.title.isEmpty, "details off: the icon alone, even while clocked in")
model.minimal = false; update()
check(button.title.isEmpty, "details off outside minimal mode: the icon alone")
model.details = true; model.running = false; update()
check(button.title.isEmpty, "clocking out removes the text")
// A real item that fits is on screen; one too wide for any menu bar is moved
// off-screen by macOS, which is how a full menu bar hides Clockin.
check(MenuBarVisibility.isOnScreen(button.window), "the Clockin item is on screen")
let tooWide = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
tooWide.button?.title = String(repeating: "W", count: 260)
spin(1)
check(!MenuBarVisibility.isOnScreen(tooWide.button?.window), "an item that cannot fit is reported hidden")
check(MenuBarProbe.isPlaced(button.window) && !MenuBarProbe.isPlaced(tooWide.button?.window), "the probe tells a placed item from a hidden one")
check(MenuBarProbe.snapshot(tooWide, label: "too wide").state == "laid out, no room", "an item with no room was laid out by the bar")
print("an item with no room: " + MenuBarProbe.snapshot(tooWide, label: "too wide").line)
NSStatusBar.system.removeStatusItem(tooWide)
// The test's verdict: Clockin's own item decides first, then the test items.
let now = Date()
check(MenuBarProbe.TestResult(plain: true, named: true, main: true, at: now).verdict == .shown, "verdict: shown")
check(MenuBarProbe.TestResult(plain: true, named: false, main: false, at: now).verdict == .itemOnly, "verdict: only Clockin's item")
check(MenuBarProbe.TestResult(plain: false, named: false, main: false, at: now, testItemsLaidOut: true).verdict == .noRoom, "verdict: no room")
check(MenuBarProbe.TestResult(plain: false, named: false, main: false, at: now).verdict == .notAllowed, "verdict: not taken in at all")
// The two ways an item is hidden: laid out with no room, or never taken in.
let noRoom = MenuBarProbe.snapshot(nil, label: "x")
check(noRoom.state == "missing", "no item is missing")
var laidOut = noRoom; laidOut.exists = true; laidOut.frame = NSRect(x: 0, y: -33, width: 3272, height: 33)
check(laidOut.state == "laid out, no room", "an item with the bar's height was laid out")
var never = laidOut; never.frame = NSRect(x: 0, y: -22, width: 36, height: 22)
check(never.state == "never laid out", "the friend's frame was never laid out")
print("\(passed) Mac menu bar checks passed")
exit(0)
