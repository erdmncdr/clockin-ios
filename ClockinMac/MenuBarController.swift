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

    var isOpen: Bool { panel?.isVisible == true && panel?.alphaValue ?? 0 > 0 }

    func start(_ host: Host) {
        guard statusItem == nil else { return }
        self.host = host
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imagePosition = .imageLeading
        item.button?.setAccessibilityLabel(String(localized: "Clockin", bundle: .app))
        statusItem = item
        refreshLabel()

        host.changes
            // `objectWillChange` fires before the new value is stored.
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refreshLabel() }
            .store(in: &cancellables)
        let clock = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                // Idle, the label never changes; only a session counts.
                guard let self, self.host?.status().state != .idle || self.lastLabel?.icon != .idle else { return }
                self.refreshLabel()
            }
        }
        clock.tolerance = 0.1
        RunLoop.main.add(clock, forMode: .common)
        self.clock = clock

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.close(animated: false) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.close(animated: false) }
            .store(in: &cancellables)
    }

    // MARK: Label

    func refreshLabel() {
        guard let host, let button = statusItem?.button else { return }
        let status = host.status()
        let icon = Self.iconState(status.state)
        // Only the icon, like the system's own items; minimal mode adds the
        // live figures while clocked in.
        let title = host.minimalMode() ? status.text : nil
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
            let font = host.minimalMode()
                ? NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
                : Self.roundedFont(size: 12, weight: .semibold)
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

    private static func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
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
        }, completionHandler: { MainActor.assumeIsolated { panel.invalidateShadow() } })
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
        }, completionHandler: { MainActor.assumeIsolated { finish() } })
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
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouseDown, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) {
            monitors.append(global)
        }
        // Clicks in Clockin's own windows. The item's button toggles by itself,
        // and menus the panel opens sit at the pop-up level.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mouseDown, handler: { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let window = event.window else { return }
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
            MainActor.assumeIsolated {
                self?.pending = false
                self?.onSizeChange?()
            }
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
