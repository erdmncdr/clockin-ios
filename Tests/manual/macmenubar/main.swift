// The Mac menu-bar item: while clocked in its live text follows the icon
// whenever Show details is on, in minimal mode or not; idle, or with details
// off, it is the icon alone. Runs the real MenuBarController in a throwaway
// accessory process, which briefly adds an icon to the menu bar.
//
// swiftc -swift-version 6 Shared/Core/Models.swift Shared/Core/AppLanguage.swift ClockinMac/MacDurationText.swift ClockinMac/MenuBarController.swift ClockinMac/MenuBarStatus.swift ClockinMac/MenuBarIcon.swift ClockinMac/MenuBarVisibility.swift ClockinMac/ApplicationMover.swift Tests/manual/macmenubar/main.swift -o /tmp/clockin-macmenubar && /tmp/clockin-macmenubar
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
NSStatusBar.system.removeStatusItem(tooWide)
print("\(passed) Mac menu bar checks passed")
exit(0)
