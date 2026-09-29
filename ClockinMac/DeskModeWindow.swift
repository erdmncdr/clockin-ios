import AppKit
import Combine
import IOKit.pwr_mgt
import SwiftUI

@MainActor
final class DeskModeWindowController: NSWindowController, NSWindowDelegate {
    static let shared = DeskModeWindowController()

    private var changes: AnyCancellable?
    private var enteringFullScreen = false
    private var displayAssertion: IOPMAssertionID = 0

    func show() {
        MenuBarController.shared.close(animated: false)
        if window == nil {
            let window = DeskWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
            )
            window.title = String(localized: "Desk Mode", bundle: .app)
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.fullScreenPrimary]
            window.contentMinSize = NSSize(width: 700, height: 400)
            window.delegate = self
            let host = NSHostingView(rootView: MacDeskModeContent()
                .environmentObject(SharedStore.clock)
                .environmentObject(SharedStore.exchangeRates))
            host.sizingOptions = [.minSize]
            window.contentView = host
            window.center()
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if changes == nil {
            // Published veri yeni degeri verir; store'u willChange icinde okuma.
            changes = SharedStore.clock.$data
                .map { $0.running?.isPaused == false }
                .removeDuplicates()
                .sink { [weak self] running in self?.keepDisplayAwake(running) }
        }
        if let window, !window.styleMask.contains(.fullScreen), !enteringFullScreen {
            enteringFullScreen = true
            window.toggleFullScreen(nil)
        }
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        enteringFullScreen = false
    }

    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        guard window === self.window else { return }
        enteringFullScreen = false
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        enteringFullScreen = false
        changes = nil
        keepDisplayAwake(false)
        window = nil
    }

    private func keepDisplayAwake(_ awake: Bool) {
        if awake {
            guard window != nil, displayAssertion == 0 else { return }
            var assertion: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Clockin Desk Mode active session" as CFString, &assertion
            )
            if result == kIOReturnSuccess { displayAssertion = assertion }
        } else if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
    }
}

@MainActor
private final class DeskWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        if attachedSheet == nil { performClose(sender) }
        else { super.cancelOperation(sender) }
    }
}

private struct MacDeskModeContent: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var summary: WorkSession?
    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        MacLocalizedContent {
            DeskModeView(onClockOut: { summary = $0 })
                .environment(\.clockinContentActive, summary == nil)
                .sheet(item: $summary) { session in
                    SessionSummaryView(session: session)
                        .frame(minWidth: 440, minHeight: 360)
                }
                .timerPersistenceAlert()
                .onExitCommand { DeskModeWindowController.shared.close() }
        }
        .environment(\.palette, palette)
        .formStyle(.grouped)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
        .onChange(of: themeRaw) { _, _ in SessionMirror.shared.refresh() }
    }
}
