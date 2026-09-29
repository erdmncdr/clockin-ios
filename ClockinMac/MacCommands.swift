import AppKit
import SwiftUI

@MainActor
final class MacNavigation: ObservableObject {
    static let shared = MacNavigation()
    @Published var section: MacSection? = .today
    @Published var sheet: Sheet?

    enum Sheet: String, Identifiable {
        case manualStart, newEntry
        var id: String { rawValue }
    }

    func open(_ section: MacSection? = nil) {
        if let section { self.section = section }
        MenuBarController.shared.close(animated: false)
        MainWindowController.shared.show(store: SharedStore.clock, exchangeRates: SharedStore.exchangeRates)
    }

    func present(_ sheet: Sheet) {
        open(.today)
        self.sheet = sheet
    }
}

struct MacCommands: Commands {
    @State private var languages = LanguageSwitch.shared
    @ObservedObject private var store = SharedStore.clock
    @ObservedObject private var navigation = MacNavigation.shared
    @ObservedObject private var updates = UpdateChecker.shared

    var body: some Commands {
        let _ = languages.language
        CommandGroup(replacing: .appSettings) {
            Button(String(localized: "Settings…", bundle: .app)) { MacNavigation.shared.open(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(after: .appInfo) {
            Button(String(localized: "Check for Updates…", bundle: .app)) { UpdateChecker.shared.checkForUpdates() }
                .disabled(!updates.isReady)
        }
        CommandMenu(String(localized: "Clock", bundle: .app)) {
            Button(String(localized: "Clock In", bundle: .app)) { store.clockIn() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(store.running != nil)
            Button(String(localized: "Clock Out", bundle: .app)) { _ = store.clockOut() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(store.running == nil)
            Button(store.running?.isPaused == true ? String(localized: "Resume", bundle: .app) : String(localized: "Pause", bundle: .app)) {
                if store.running?.isPaused == true { store.resume() } else { store.pause() }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(store.running == nil)
            Divider()
            Button(String(localized: "Start with elapsed time…", bundle: .app)) { MacNavigation.shared.present(.manualStart) }
                .keyboardShortcut("i", modifiers: [.command, .control])
                .disabled(store.running != nil || navigation.sheet != nil)
            Button(String(localized: "New Entry…", bundle: .app)) { MacNavigation.shared.present(.newEntry) }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(navigation.sheet != nil)
        }
        CommandGroup(after: .sidebar) {
            Button(String(localized: "Desk Mode", bundle: .app)) { DeskModeWindowController.shared.show() }
                .keyboardShortcut("f", modifiers: [.control, .command])
            Divider()
            Button(String(localized: "Today", bundle: .app)) { MacNavigation.shared.open(.today) }.keyboardShortcut("1")
            Button(String(localized: "History", bundle: .app)) { MacNavigation.shared.open(.history) }.keyboardShortcut("2")
            Button(String(localized: "Progress", bundle: .app)) { MacNavigation.shared.open(.progress) }.keyboardShortcut("3")
            Button(String(localized: "Settings", bundle: .app)) { MacNavigation.shared.open(.settings) }.keyboardShortcut("4")
        }
    }
}
