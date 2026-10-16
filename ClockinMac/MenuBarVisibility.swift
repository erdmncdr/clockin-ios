import AppKit
import Combine

/// Whether macOS is showing Clockin's menu bar item. When the menu bar is too
/// full, macOS hides items that do not fit (beside the notch or the open app's
/// menus) without telling the app; the item's window then sits off-screen with
/// no screen. A user can then see neither the icon nor the timer, so Today
/// says so and offers the pinned timer.
@MainActor
final class MenuBarVisibility: ObservableObject {
    static let shared = MenuBarVisibility()

    @Published private(set) var isHidden = false
    /// Dismissed for this launch only: the menu bar may fill up again later.
    @Published private(set) var isDismissed = false

    private var hiddenChecks = 0

    var showsNotice: Bool { isHidden && !isDismissed }

    func dismiss() { isDismissed = true }

    /// Called about once a second by MenuBarController. Only judged while the
    /// menu bar itself is on screen: in full screen or with an auto-hiding menu
    /// bar every item is away, and that is not this problem.
    func update(itemWindow: NSWindow?) {
        guard NSMenu.menuBarVisible() else { return }
        if Self.isOnScreen(itemWindow) {
            hiddenChecks = 0
            if isHidden { isHidden = false }
        } else {
            hiddenChecks += 1
            // A few seconds, so a launch or a Space change does not count.
            if hiddenChecks >= 3, !isHidden { isHidden = true }
        }
    }

    static func isOnScreen(_ window: NSWindow?) -> Bool {
        guard let window, let screen = window.screen else { return false }
        return screen.frame.intersects(window.frame)
    }
}
