import AppKit

/// Measurements for a Clockin icon that does not show in the menu bar.
///
/// A missing icon has more than one cause and the app cannot see which: the
/// bar may be full, macOS may not allow the app in the menu bar, or one item's
/// saved state may keep it away. The probe records what macOS did with the
/// item, and a short test adds two plain items to tell "macOS places none of
/// Clockin's items" (decided for the whole app) from "only Clockin's own item
/// stays away" (something about that item, which Clockin can change).
@MainActor
enum MenuBarProbe {
    struct Snapshot: Equatable, Sendable {
        var label: String
        var exists: Bool
        var visible: Bool
        var frame: NSRect?
        var hasScreen: Bool
        var placed: Bool
        var length: CGFloat
        var buttonSize: NSSize?
        var fitting: NSSize?

        /// A hidden item the menu bar laid out has the bar's height (here
        /// 33 pt beside a notch): it was moved away for lack of room. One that
        /// keeps AppKit's default 22 pt height was never taken in by the bar.
        var neverLaidOut: Bool {
            guard exists, !placed, let frame else { return false }
            return frame.height <= NSStatusBar.system.thickness + 0.5
        }

        var state: String { placed ? "placed" : neverLaidOut ? "never laid out" : exists ? "laid out, no room" : "missing" }

        var line: String {
            let frameText = frame.map { NSStringFromRect($0) } ?? "none"
            let sizes = "button=\(buttonSize.map { NSStringFromSize($0) } ?? "none") fitting=\(fitting.map { NSStringFromSize($0) } ?? "none")"
            return "\(label): \(state) visible=\(visible) frame=\(frameText) screen=\(hasScreen) length=\(length) \(sizes)"
        }
    }

    /// Placed means macOS put the item's window in the menu bar: on a screen
    /// and against its top edge. An item macOS keeps away sits at a default
    /// frame below the screen, with no screen.
    static func isPlaced(_ window: NSWindow?) -> Bool {
        guard let window, let screen = window.screen, screen.frame.intersects(window.frame) else { return false }
        return window.frame.maxY >= screen.frame.maxY - 2
    }

    static func snapshot(_ item: NSStatusItem?, label: String) -> Snapshot {
        let window = item?.button?.window
        return Snapshot(label: label, exists: item != nil, visible: item?.isVisible ?? false, frame: window?.frame,
                        hasScreen: window?.screen != nil, placed: isPlaced(window), length: item?.length ?? 0,
                        buttonSize: item?.button?.frame.size, fitting: item?.button?.fittingSize)
    }

    // MARK: Test

    struct TestResult: Equatable, Sendable {
        var plain: Bool
        var named: Bool
        var main: Bool
        var at: Date
        /// The test items were laid out by the menu bar, then kept off it.
        var testItemsLaidOut = false
        var snapshots: [Snapshot] = []

        enum Verdict: Equatable, Sendable {
            /// Clockin's own item is in the menu bar.
            case shown
            /// New items appear but Clockin's own does not.
            case itemOnly
            /// None fit: the menu bar took the test items in but had no room.
            case noRoom
            /// macOS takes none of Clockin's items into the menu bar at all.
            case notAllowed
        }

        var verdict: Verdict {
            if main { return .shown }
            if plain || named { return .itemOnly }
            return testItemsLaidOut ? .noRoom : .notAllowed
        }
    }

    static let testAutosaveName = "ClockinStatusItemTest"
    private(set) static var lastTest: TestResult?
    private(set) static var running = false

    /// Adds a plain item and one with its own saved name for a few seconds,
    /// then removes both and forgets what macOS saved for them.
    static func runTest(main: @escaping @MainActor () -> NSStatusItem?, completion: @escaping @MainActor (TestResult) -> Void) {
        guard !running else { return }
        running = true
        let bar = NSStatusBar.system
        let plain = bar.statusItem(withLength: NSStatusItem.variableLength)
        plain.button?.title = "Clockin ✓"
        let named = bar.statusItem(withLength: NSStatusItem.squareLength)
        named.autosaveName = testAutosaveName
        named.isVisible = true
        named.button?.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Clockin")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            MainActor.assumeIsolated {
                let snapshots = [snapshot(plain, label: "test plain"), snapshot(named, label: "test named")]
                let result = TestResult(plain: snapshots[0].placed, named: snapshots[1].placed,
                                        main: isPlaced(main()?.button?.window), at: Date(),
                                        testItemsLaidOut: snapshots.contains { !$0.placed && !$0.neverLaidOut },
                                        snapshots: snapshots)
                bar.removeStatusItem(plain)
                bar.removeStatusItem(named)
                forgetSavedState(for: testAutosaveName)
                lastTest = result
                running = false
                completion(result)
            }
        }
    }

    static func forgetSavedState(for name: String) {
        for prefix in ["NSStatusItem Preferred Position", "NSStatusItem Visible", "NSStatusItem VisibleCC"] {
            UserDefaults.standard.removeObject(forKey: "\(prefix) \(name)")
        }
    }

    // MARK: Other things that differ from Mac to Mac

    /// Other running copies of Clockin. A copy launched from Downloads by an
    /// older version could wait forever on a hidden question, unseen.
    static func runningCopies() -> String {
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != me }
        guard !others.isEmpty else { return "none" }
        return others.map { "\($0.processIdentifier) \($0.bundleURL?.path(percentEncoded: false) ?? "?")" }.joined(separator: "; ")
    }

    /// The copies of this app that LaunchServices knows, grouped by where they are.
    static func registeredCopies() -> String {
        guard let id = Bundle.main.bundleIdentifier,
              let urls = LSCopyApplicationURLsForBundleIdentifier(id as CFString, nil)?.takeRetainedValue() as? [URL] else {
            return "unknown"
        }
        let paths = urls.map { $0.path(percentEncoded: false) }
        func count(_ test: (String) -> Bool) -> Int { paths.filter(test).count }
        let trash = count { $0.contains("/.Trash/") }
        let translocated = count { $0.contains("/AppTranslocation/") }
        let volumes = count { $0.hasPrefix("/Volumes/") }
        return "\(paths.count) total, trash=\(trash) translocated=\(translocated) volumes=\(volumes) other=\(paths.count - trash - translocated - volumes)"
    }
}

#if DEBUG
extension MenuBarProbe {
    /// Check fixture: `--menu-bar-probe <file>` runs the test, then a reset,
    /// and writes Copy details after each to the file.
    static func runFixtureIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--menu-bar-probe"), arguments.indices.contains(index + 1) else { return }
        let file = URL(fileURLWithPath: arguments[index + 1])
        let controller = MenuBarController.shared
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            MainActor.assumeIsolated {
                controller.testPlacement { _ in
                    controller.resetItemPosition()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        MainActor.assumeIsolated {
                            try? (controller.diagnostics() + "\n").write(to: file, atomically: true, encoding: .utf8)
                        }
                    }
                }
            }
        }
    }
}
#endif
