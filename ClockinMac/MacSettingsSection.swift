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
    @AppStorage("Clockin.MinimalShowTRY") private var showTRY = true
    @AppStorage("Clockin.MinimalShowGoal") private var showGoal = false
    @AppStorage(WardrobeState.deskKey) private var showHome = true
    @AppStorage("Clockin.PinnedMode") private var pinnedMode = "Money"

    var body: some View {
        switch category {
        case .menuBar:
            Section("Menu bar") {
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
                Button("Check for Updates…") { updates.checkForUpdates() }.disabled(!updates.isReady)
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
