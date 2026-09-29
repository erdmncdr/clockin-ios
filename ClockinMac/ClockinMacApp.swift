import AppKit
import Combine
import SwiftUI

@MainActor
final class ClockinMacAppDelegate: NSObject, NSApplicationDelegate {
    private var refreshSubscription: AnyCancellable?
    private var refreshTask: Task<Void, Never>?
    private var lastRateDates: [Date]?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if MoveToApplications.offerIfNeeded() {
            NSApp.terminate(nil)
            return
        }
        let store = SharedStore.clock
        let minimal = UserDefaults.standard.bool(forKey: "Clockin.MinimalMode")
        // Minimal modda yeniden acilis sabit pencereyi geri getirmesin.
        if minimal { store.setPinned(false) }
        UpdateChecker.shared.start()
        MenuBarController.shared.start(.clockin())
        PinnedWindowController.shared.start(store: store)
        KeyboardShortcutController.shared.start(store: store)
        refreshSubscription = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.refreshRates() }
        }
        refreshRates()
        if !minimal {
            MacNavigation.shared.open()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if !UserDefaults.standard.bool(forKey: "Clockin.MinimalMode") {
                    MacNavigation.shared.open()
                }
            }
        }
    }

    // Refresh even on a minimal launch, before any main-window view exists.
    private func refreshRates() {
        let store = SharedStore.clock
        let dates = store.sessions.map(\.start) + (store.running.map { [$0.start] } ?? [])
        let rateDates = Array(Set(dates.map { ExchangeRateStore.calendarRateDate($0) })).sorted()
        guard rateDates != lastRateDates else { return }
        lastRateDates = rateDates
        refreshTask?.cancel()
        refreshTask = Task {
            let rates = SharedStore.exchangeRates
            await rates.refresh(sessionDates: rateDates)
            guard !Task.isCancelled, !rates.liveCheckFailed, rates.latestRate != nil else { return }
            SessionMirror.shared.refresh()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MacNavigation.shared.open()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyboardShortcutController.shared.stop()
        refreshTask?.cancel()
        refreshSubscription = nil
    }
}

@main
@MainActor
struct ClockinMacApp: App {
    @NSApplicationDelegateAdaptor(ClockinMacAppDelegate.self) private var appDelegate

    init() { AppLanguage.applyToSystem() }

    var body: some Scene {
        Settings { SettingsSceneRedirect() }
            .commands { MacCommands() }
    }
}

/// macOS may open this scene itself; redirect every presentation to the sidebar.
private struct SettingsSceneRedirect: NSViewRepresentable {
    final class RedirectView: NSView {
        private var visibility: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            visibility = nil
            guard let window else { return }
            window.alphaValue = 0
            visibility = window.observe(\.isVisible, options: [.initial, .new]) { window, _ in
                DispatchQueue.main.async {
                    guard window.isVisible else { return }
                    window.orderOut(nil)
                    MacNavigation.shared.open(.settings)
                }
            }
        }
    }

    func makeNSView(context: Context) -> RedirectView { RedirectView(frame: .zero) }
    func updateNSView(_ nsView: RedirectView, context: Context) {}
}
