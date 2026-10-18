// The pinned timer's frame: dragging empty space moves it, the corner grip
// resizes it with the top-left corner fixed, and a frame half off-screen is
// brought back. Runs the real pieces in a borderless panel like the app's.
//
// swiftc -swift-version 6 ClockinMac/PinnedWindowChrome.swift Tests/manual/pinnedwindow/main.swift -o /tmp/clockin-pinnedwindow && /tmp/clockin-pinnedwindow
import AppKit
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

// Fitting on screen.
let visible = NSRect(x: 0, y: 0, width: 1512, height: 949)
let minimum = NSSize(width: 246, height: 72)
let halfOff = NSRect(x: 1325, y: 853, width: 320, height: 112)
let fitted = PinnedFrame.fitted(halfOff, in: visible, minimum: minimum)
check(visible.contains(fitted), "a half off-screen panel is brought inside: \(fitted)")
check(fitted.size == halfOff.size, "its size stays when it fits")
check(PinnedFrame.fitted(NSRect(x: 100, y: 100, width: 300, height: 100), in: visible, minimum: minimum) == NSRect(x: 100, y: 100, width: 300, height: 100),
      "a panel already on screen is left alone")
check(PinnedFrame.fitted(NSRect(x: -50, y: 0, width: 2000, height: 50), in: visible, minimum: minimum).width == visible.width,
      "a panel wider than the screen is narrowed to it")
let grown = PinnedFrame.resized(NSRect(x: 100, y: 500, width: 300, height: 100), dx: 40, dy: -30,
                                minimum: minimum, maximum: NSSize(width: 640, height: 500))
check(grown == NSRect(x: 100, y: 470, width: 340, height: 130), "the corner drag keeps the top-left corner: \(grown)")

// When it shows.
check(PinnedTimerVisibility.shows(pinned: true, whileClockedIn: false, clockedIn: false), "a pinned timer always shows")
check(!PinnedTimerVisibility.shows(pinned: false, whileClockedIn: false, clockedIn: true), "unpinned, it stays hidden by default")
check(PinnedTimerVisibility.shows(pinned: false, whileClockedIn: true, clockedIn: true), "with Show while clocked in, a session shows it")
check(!PinnedTimerVisibility.shows(pinned: false, whileClockedIn: true, clockedIn: false), "and clocking out hides it again")

// A borderless panel like the app's.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()
nonisolated(unsafe) var ended = 0
struct Content: View {
    var body: some View {
        VStack(alignment: .leading) { Text("Earning"); Text("$57.31").font(.title) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PinnedWindowDragArea())
            .overlay(alignment: .bottomTrailing) {
                PinnedResizeGrip(onEnd: { ended += 1 }).frame(width: 22, height: 22)
            }
    }
}
let panel = NSPanel(contentRect: NSRect(x: 300, y: 400, width: 320, height: 112),
                    styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
panel.minSize = minimum
panel.maxSize = NSSize(width: 640, height: 500)
panel.contentView = NSHostingView(rootView: Content())
panel.orderFrontRegardless()
spin(0.5)

func viewAt(_ point: NSPoint) -> NSView? { panel.contentView?.hitTest(point) }
func canMove(_ view: NSView?) -> Bool {
    var node = view
    while let current = node { if current.mouseDownCanMoveWindow { return true }; if current === panel.contentView { break }; node = current.superview }
    return false
}
check(canMove(viewAt(NSPoint(x: 40, y: 70))), "pressing on the label area moves the panel")
check(canMove(viewAt(NSPoint(x: 160, y: 30))), "pressing on empty space moves the panel")
let grip = viewAt(NSPoint(x: 310, y: 8))
check(grip is PinnedResizeGrip.GripView, "the bottom-right corner is the grip, not a drag area")

// The grip's own handlers, called directly: synthetic window events do not
// reach views inside SwiftUI's hosting view, and a test process here gets no
// real input. Real presses were checked against the running app.
let before = panel.frame
func make(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
    NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                       windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
}
let gripView = grip as! PinnedResizeGrip.GripView
check(gripView.acceptsFirstMouse(for: nil), "the grip takes the first press, as the panel is never key")
let corner = NSPoint(x: 310, y: 8)
gripView.mouseDown(with: make(.leftMouseDown, corner))
let target = panel.convertPoint(toScreen: corner).applying(CGAffineTransform(translationX: 60, y: -40))
gripView.mouseDragged(with: make(.leftMouseDragged, panel.convertPoint(fromScreen: target)))
gripView.mouseUp(with: make(.leftMouseUp, panel.convertPoint(fromScreen: target)))
check(abs(panel.frame.width - (before.width + 60)) < 1 && abs(panel.frame.height - (before.height + 40)) < 1,
      "dragging the grip resizes the panel: \(panel.frame.size)")
check(abs(panel.frame.minX - before.minX) < 1 && abs(panel.frame.maxY - before.maxY) < 1, "the top-left corner stays where it was")
check(ended == 1, "the size is saved when the drag ends")
print("\(passed) pinned window checks passed")
