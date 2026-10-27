import AppKit
import Combine
import SwiftUI

/// The menu-bar item and the panel that drops down from it.
///
/// The item used to open a MenuBarExtra menu whose main entry, "Open Clockin",
/// brings up the main window on the desktop Space: in a full-screen app that
/// threw the user out to the desktop. The panel is a non-activating window
/// that joins every Space, so it opens over a full-screen app and Clockin
/// never becomes the active app. Nothing switches Spaces.
@MainActor
final class MenuBarController: NSObject {
    /// What the app provides. Kept as closures so the controller can run in a
    /// test harness without the store, Sparkle or the main window.
    struct Host {
        var status: @MainActor () -> MenuBarStatus
        var minimalMode: @MainActor () -> Bool
        /// Fires when anything shown in the menu bar may have changed.
        var changes: AnyPublisher<Void, Never>
        var content: @MainActor (_ close: @escaping @MainActor () -> Void) -> AnyView
        /// The right-click menu.
        var menu: @MainActor () -> NSMenu
    }

    static let shared = MenuBarController()

    private(set) var statusItem: NSStatusItem?
    private(set) var panel: MenuBarPanel?
    private var host: Host?
    private var hostingView: MenuBarHostingView?
    private var cancellables = Set<AnyCancellable>()
    private var clock: Timer?
    private var monitors: [Any] = []
    private var lastLabel: (icon: MenuBarIcon.State, title: String?)?
    /// Bumped on every open and close so a finished close animation cannot
    /// hide a panel that was reopened meanwhile.
    private var generation = 0
    /// What macOS did with the item after launch, a reset and a test; for
    /// Copy details.
    private(set) var history: [MenuBarProbe.Snapshot] = []

    var isOpen: Bool { panel?.isVisible == true && panel?.alphaValue ?? 0 > 0 }

    func start(_ host: Host) {
        guard statusItem == nil else { return }
        self.host = host
        makeItem()
        for delay in [1.0, 5.0, 30.0] { record("launch +\(Int(delay))s", after: delay) }

        host.changes
            // `objectWillChange` fires before the new value is stored.
            .receive(on: RunLoop.main)
            .sink { @Sendable [weak self] in Task { @MainActor in self?.refreshLabel() } }
            .store(in: &cancellables)
        let clock = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                MenuBarVisibility.shared.update(itemWindow: self.statusItem?.button?.window)
                // Idle, the label never changes; only a session counts.
                guard self.host?.status().state != .idle || self.lastLabel?.icon != .idle else { return }
                self.refreshLabel()
            }
        }
        clock.tolerance = 0.1
        RunLoop.main.add(clock, forMode: .common)
        self.clock = clock

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { @Sendable [weak self] _ in Task { @MainActor in self?.close(animated: false) } }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { @Sendable [weak self] _ in Task { @MainActor in self?.close(animated: false) } }
            .store(in: &cancellables)
    }

    /// The name macOS keeps this item's position and visibility under. A new
    /// name in 2.0.20: positions saved before by menu bar managers (or a drag
    /// out of the bar) could keep the old item hidden even with room to spare.
    static let autosaveName = "ClockinStatusItem"
    /// Set when the menu bar test found that a new item without a saved name
    /// shows but Clockin's own does not: the item then goes without one.
    static let plainItemKey = "Clockin.MenuBarPlainItem"
    static var usesPlainItem: Bool { UserDefaults.standard.bool(forKey: plainItemKey) }

    private func makeItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if !Self.usesPlainItem { item.autosaveName = Self.autosaveName }
        item.isVisible = true
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imagePosition = .imageLeading
        item.button?.setAccessibilityLabel(String(localized: "Clockin", bundle: .app))
        statusItem = item
        lastLabel = nil
        refreshLabel()
    }

    /// Forgets where macOS placed the item and adds it again at the default
    /// place, next to the other app items.
    func resetItemPosition() {
        record("before reset")
        recreateItem()
        record("after reset +2s", after: 2)
    }

    private func recreateItem() {
        close(animated: false)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
        MenuBarProbe.forgetSavedState(for: Self.autosaveName)
        MenuBarProbe.forgetSavedState(for: "Item-0")
        makeItem()
    }

    /// Adds two test items for a few seconds (see MenuBarProbe). When they
    /// show and Clockin's own item does not, the item is made again the way
    /// the plain test item was.
    func testPlacement(completion: @escaping @MainActor (MenuBarProbe.TestResult) -> Void) {
        record("before test")
        MenuBarProbe.runTest(main: { [weak self] in self?.statusItem }) { [weak self] result in
            guard let self else { return }
            self.history.append(contentsOf: result.snapshots)
            if result.verdict == .itemOnly, result.plain, !Self.usesPlainItem {
                UserDefaults.standard.set(true, forKey: Self.plainItemKey)
                self.recreateItem()
                self.record("plain item +2s", after: 2)
            }
            completion(result)
        }
    }

    private func record(_ label: String, after delay: Double = 0) {
        let take = { @MainActor [weak self] in
            guard let self else { return }
            self.history.append(MenuBarProbe.snapshot(self.statusItem, label: label))
            if self.history.count > 12 { self.history.removeFirst(self.history.count - 12) }
        }
        guard delay > 0 else { return take() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { MainActor.assumeIsolated { take() } }
    }

    /// What macOS reports about the item, to paste into a bug report.
    func diagnostics() -> String {
        let window = statusItem?.button?.window
        let screen = window?.screen ?? NSScreen.main
        let saved = UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("NSStatusItem") }.sorted()
            .map { "\($0) = \(UserDefaults.standard.object(forKey: $0) ?? "")" }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return [
            "Clockin \(version) (\(build)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "item: exists=\(statusItem != nil) visible=\(statusItem?.isVisible ?? false) autosave=\(statusItem?.autosaveName ?? "-")",
            "item window: frame=\(window.map { NSStringFromRect($0.frame) } ?? "none") onScreen=\(MenuBarVisibility.isOnScreen(window))",
            "screen: frame=\(screen.map { NSStringFromRect($0.frame) } ?? "none") notchInset=\(screen?.safeAreaInsets.top ?? 0) screens=\(NSScreen.screens.count)",
            "menu bar visible=\(NSMenu.menuBarVisible()) title length=\(statusItem?.button?.title.count ?? 0)",
            "app: \(Self.locationSummary())",
            "saved: " + (saved.isEmpty ? "none" : saved.joined(separator: "; ")),
            "plain item=\(Self.usesPlainItem) bar thickness=\(NSStatusBar.system.thickness)",
            "test: " + (MenuBarProbe.lastTest.map { "plain=\($0.plain) named=\($0.named) main=\($0.main) -> \($0.verdict)" } ?? "not run"),
            "other running copies: \(MenuBarProbe.runningCopies())",
            "registered copies: \(MenuBarProbe.registeredCopies())",
            MenuBarProbe.snapshot(statusItem, label: "now").line,
        ].joined(separator: "\n") + history.map { "\n" + $0.line }.joined()
    }

    /// Where this copy runs from: a copy left in Downloads runs translocated
    /// from a new place each launch, and macOS may not keep its menu bar item.
    private static func locationSummary() -> String {
        let location = ApplicationMover.locate(Bundle.main.bundleURL)
        return "\(location.kind) \(location.originalURL.lastPathComponent)"
    }

    // MARK: Label

    func refreshLabel() {
        guard let host, let button = statusItem?.button else { return }
        let status = host.status()
        let icon = Self.iconState(status.state)
        // While clocked in the live figures follow the icon unless Settings >
        // Menu bar > Show details is off (the host then returns no text).
        // Minimal mode only decides whether the window and the pin show.
        let title = status.text
        let spoken = switch status.state {
        case .idle: String(localized: "Not clocked in", bundle: .app)
        case .running: String(localized: "Clocked in", bundle: .app)
        case .paused: String(localized: "Paused", bundle: .app)
        }
        button.setAccessibilityValue(spoken)
        if let lastLabel, lastLabel.icon == icon, lastLabel.title == title { return }
        lastLabel = (icon, title)
        button.image = MenuBarIcon.image(icon)
        if let title {
            // Tabular digits, so the item does not change width every second.
            let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            // The leading space is the gap between the icon and the text.
            button.attributedTitle = NSAttributedString(string: " " + title, attributes: [.font: font, .baselineOffset: 0.5])
        } else {
            button.title = ""
        }
    }

    static func iconState(_ state: MenuBarStatus.State) -> MenuBarIcon.State {
        switch state {
        case .idle: .idle
        case .running: .running
        case .paused: .paused
        }
    }

    // MARK: Clicks

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            toggle()
        }
    }

    func toggle() {
        isOpen ? close() : open()
    }

    private func showMenu() {
        guard let host, let item = statusItem else { return }
        close(animated: false)
        // Setting the menu only for this click keeps a left click opening
        // the panel.
        item.menu = host.menu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: Panel

    func open() {
        guard let host else { return }
        generation += 1
        let panel = self.panel ?? makePanel()
        if hostingView == nil {
            let view = MenuBarHostingView(rootView: host.content { [weak self] in self?.close() })
            view.onSizeChange = { [weak self] in self?.fitToContent() }
            panel.contentView = view
            hostingView = view
        }
        hostingView?.layoutSubtreeIfNeeded()
        let frame = targetFrame()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !panel.isVisible || reduceMotion {
            var start = frame
            if !reduceMotion { start.origin.y += 6 }
            panel.setFrame(start, display: true)
            panel.alphaValue = 0
        }
        // Never `NSApp.activate`: activating would switch to the Space holding
        // the main window. A non-activating panel can still become key.
        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitors()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.12 : 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: { @Sendable in Task { @MainActor in panel.invalidateShadow() } })
        statusItem?.button?.highlight(true)
    }

    func close(animated: Bool = true) {
        guard let panel, panel.isVisible else { return }
        generation += 1
        let closing = generation
        removeMonitors()
        statusItem?.button?.highlight(false)
        let finish: @MainActor @Sendable () -> Void = { [weak self] in
            guard let self, self.generation == closing else { return }
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
        guard animated else { return finish() }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { @Sendable in Task { @MainActor in finish() } })
    }

    private func makePanel() -> MenuBarPanel {
        let panel = MenuBarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        // Above full-screen apps and the pinned timer (`.floating`), like a menu.
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = false
        panel.onCancel = { [weak self] in self?.close() }
        self.panel = panel
        return panel
    }

    private func fitToContent() {
        guard let panel, panel.isVisible else { return }
        let frame = targetFrame()
        guard frame.size != panel.frame.size else { return }
        panel.setFrame(frame, display: true)
        // The shadow follows the transparent window's drawn shape.
        panel.invalidateShadow()
    }

    private func targetFrame() -> NSRect {
        let size = hostingView?.fittingSize ?? NSSize(width: 320, height: 300)
        let button = statusItem?.button
        let buttonFrame = button?.window.map { $0.convertToScreen(button!.convert(button!.bounds, to: nil)) }
        let screen = button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let origin = Self.panelOrigin(
            size: size,
            below: buttonFrame,
            screenFrame: screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 875)
        )
        return NSRect(origin: origin, size: size)
    }

    /// Centred under the menu-bar item, kept on screen with an 8 pt margin.
    /// In a full-screen Space the visible frame reaches the top of the screen,
    /// so the item's own frame decides the top edge.
    static func panelOrigin(size: NSSize, below item: NSRect?, screenFrame: NSRect, visibleFrame: NSRect) -> NSPoint {
        let margin: CGFloat = 8
        let gap: CGFloat = 5
        let top: CGFloat
        let centerX: CGFloat
        if let item, screenFrame.intersects(item) {
            top = item.minY - gap
            centerX = item.midX
        } else {
            top = min(visibleFrame.maxY, screenFrame.maxY - 25) - gap
            centerX = visibleFrame.maxX - size.width / 2 - margin
        }
        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - margin - size.width
        let x = min(max(centerX - size.width / 2, minX), max(minX, maxX))
        let y = max(screenFrame.minY + margin, top - size.height)
        return NSPoint(x: x.rounded(), y: y.rounded())
    }

    // MARK: Closing on outside clicks

    private func installMonitors() {
        guard monitors.isEmpty else { return }
        let mouseDown: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // Clicks in other apps, the desktop or another menu-bar item.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouseDown, handler: { @Sendable [weak self] _ in
            Task { @MainActor in self?.close() }
        }) {
            monitors.append(global)
        }
        // Clicks in Clockin's own windows. The item's button toggles by itself,
        // and menus the panel opens sit at the pop-up level.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mouseDown, handler: { @Sendable [weak self] event in
            let window = event.window
            Task { @MainActor in
                guard let self, let window else { return }
                if window === self.panel || window === self.statusItem?.button?.window { return }
                if window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue { return }
                self.close()
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}

/// Borderless panels refuse key status by default; key status lets Esc close
/// the panel without activating the app.
final class MenuBarPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// Reports when SwiftUI content changes its ideal size, so the panel can grow
/// or shrink from its top edge (clocking in adds rows).
final class MenuBarHostingView: NSHostingView<AnyView> {
    var onSizeChange: (() -> Void)?
    private var pending = false

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        guard !pending else { return }
        pending = true
        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in
                self?.pending = false
                self?.onSizeChange?()
            }
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
