import AppKit
import SwiftUI

struct MacSettingsSection: View {
    let category: MacSettingsCategory
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var updates = UpdateChecker.shared
    @ObservedObject private var shortcuts = KeyboardShortcutController.shared
    @AppStorage("Clockin.MacShowMenuBarDetails", store: .standard) private var showMenuBarDetails = true
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false
    @AppStorage("Clockin.MinimalShowHours") private var showHours = true
    @AppStorage("Clockin.MinimalShowSeconds") private var showSeconds = false
    @AppStorage("Clockin.MinimalShowEarnings") private var showEarnings = true
    @AppStorage("Clockin.MinimalShowTRY") private var showTRY = false
    @AppStorage("Clockin.MinimalShowGoal") private var showGoal = false
    @AppStorage(WardrobeState.deskKey) private var showHome = true
    @AppStorage("Clockin.PinnedMode") private var pinnedMode = "Money"
    @State private var chromePrepared = false
    @State private var chromeError: String?

    var body: some View {
        switch category {
        case .menuBar:
            Section {
                Toggle("Show details in the menu bar", isOn: $showMenuBarDetails)
                Toggle("Minimal menu bar mode", isOn: Binding(
                    get: { minimalMode },
                    set: { MenuBarPanelView.setMinimalMode($0, store: store) }
                ))
                Group {
                    Toggle("Show hours", isOn: $showHours)
                    Toggle("Show seconds", isOn: $showSeconds).disabled(!showHours)
                    Toggle("Show earnings", isOn: $showEarnings)
                    Toggle("Show TRY equivalent", isOn: $showTRY)
                    Toggle("Show goal progress", isOn: $showGoal)
                }
                .disabled(!showMenuBarDetails)
            } header: {
                Text("Menu bar")
            } footer: {
                Text("If the Clockin icon or timer doesn’t show up, the menu bar is full: macOS hides items that don’t fit beside the camera notch or the open app’s menus. Hold ⌘ and drag other icons out of the menu bar, or turn off details you don’t need.")
            }
            Section("Pinned timer") {
                Toggle("Pin timer", isOn: Binding(get: { store.pinVisible }, set: { store.setPinned($0) }))
                    .disabled(minimalMode)
                Picker("Layout", selection: $pinnedMode) {
                    Text("Money").tag("Money")
                    Text("Compact").tag("Compact")
                    Text("Goal").tag("Goal")
                    Text("All").tag("All")
                    Text("Total").tag("Total")
                }
            }
        case .general:
            Section("Desk Mode") {
                Button("Open Desk Mode") { DeskModeWindowController.shared.show() }
                Toggle("Show home in desk mode", isOn: $showHome)
            }
            Section("Global shortcuts") {
                LabeledContent("Clock in or resume", value: "⌥⌘I")
                LabeledContent("Pause or resume", value: "⌥⌘P")
                LabeledContent("Clock out", value: "⌥⌘O")
                LabeledContent("Open Clockin", value: "⌥⌘E")
                if shortcuts.registrationFailed {
                    Text("A global shortcut could not be registered. Check for conflicts with other apps.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Clockin can start and stop by itself when you press your work site’s Clock in and Clock out buttons in Chrome.")
                Button(ChromeExtensionInstaller.isInstalled || chromePrepared ? "Prepare the extension again" : "Prepare the Chrome extension") {
                    do {
                        try ChromeExtensionInstaller.prepare()
                        chromePrepared = true
                        chromeError = nil
                    } catch {
                        chromeError = error.localizedDescription
                    }
                }
                if chromePrepared {
                    Text("Done. The folder is open in Finder and its location is copied.")
                        .foregroundStyle(.secondary)
                }
                if let chromeError { Text(chromeError).foregroundStyle(.red) }
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. In Chrome, open chrome://extensions and turn on Developer mode at the top right.")
                    Text("2. Click Load unpacked, press ⌘⇧G, paste with ⌘V and click Select.")
                    Text("3. Open your work site, click the Clockin extension and choose Pick buttons. Click the button that starts work, then the one that ends it.")
                    Text("4. The first time, Chrome asks to open Clockin. Tick Always allow and click Open.")
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                Button("Copy chrome://extensions") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("chrome://extensions", forType: .string)
                }
            } header: {
                Text("Start from Chrome")
            }
        case .notifications:
            Section {
                Button("Open iPhone notification settings") { IPhoneNotificationSettings.open() }
            } header: {
                Text("iPhone notifications")
            } footer: {
                Text("Your iPhone’s Live Activity can also appear in the menu bar. Turn off “Allow Live Activities from iPhone” in iPhone Notifications to hide it.")
            }
        case .help:
            Section("Updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.setAutomaticallyChecksForUpdates($0) }
                ))
                .disabled(!updates.isReady)
                if let version = updates.pendingVersion { Text("Clockin \(version) is available") }
                Button("Check for Updates…") { updates.checkForUpdates() }.disabled(!updates.isReady || updates.isChecking)
                if let date = updates.lastChecked {
                    LabeledContent("Last checked", value: date.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened, locale: AppLanguage.formatLocale)))
                }
                if let error = updates.startupError { Text(error).foregroundStyle(.secondary) }
            }
        default:
            EmptyView()
        }
    }
}
