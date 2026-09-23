import SwiftUI

enum DashboardShortcut: String, CaseIterable, Identifiable {
    case chime, radio, reminder
    var id: String { rawValue }
    var storageKey: String { "Clockin.Dashboard.Pin.\(rawValue)" }
    var title: String {
        switch self { case .chime: String(localized: "Focus chime"); case .radio: String(localized: "Focus radio"); case .reminder: String(localized: "Session reminder") }
    }
    var symbol: String {
        switch self { case .chime: "bell.badge"; case .radio: "radio"; case .reminder: "clock.badge" }
    }
}

struct DashboardPinButton: View {
    let feature: DashboardShortcut
    var compact = false
    @AppStorage private var pinned: Bool
    init(feature: DashboardShortcut, compact: Bool = false) {
        self.feature = feature; self.compact = compact
        _pinned = AppStorage(wrappedValue: false, feature.storageKey)
    }
    var body: some View {
        Button {
            pinned.toggle()
            Haptics.play(.selection)
        } label: {
            Label(pinned ? "Unpin from Today" : "Pin to Today", systemImage: pinned ? "pin.slash" : "pin")
                .font(compact ? .caption : .body)
                .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("dashboard.pin.\(feature.rawValue)")
        .accessibilityValue(pinned ? "Pinned" : "Not pinned")
    }
}

struct DashboardPinOptions: View {
    var body: some View {
        Form {
            TodayCustomizationSections()
            Section {
                ForEach(DashboardShortcut.allCases) { DashboardPinToggle(feature: $0) }
            } header: {
                Text("Pinned controls")
            } footer: {
                Text("Keep your everyday controls on Today. Pinning does not turn a feature on or start playback.")
            }
        }.navigationTitle("Customize Today").navigationBarTitleDisplayMode(.inline)
    }
}

private struct DashboardPinToggle: View {
    let feature: DashboardShortcut
    @AppStorage private var pinned: Bool
    init(feature: DashboardShortcut) {
        self.feature = feature
        _pinned = AppStorage(wrappedValue: false, feature.storageKey)
    }
    var body: some View {
        Toggle(isOn: $pinned) { Label(feature.title, systemImage: feature.symbol) }
            .accessibilityIdentifier("dashboard.option.\(feature.rawValue)")
    }
}

struct DashboardCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            DashboardPinOptions()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct DashboardShortcutSheet: View {
    let feature: DashboardShortcut
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                if feature == .reminder { LongSessionReminderSettingsSection() }
                else { FocusSettingsSection(only: feature) }
            }
            .navigationTitle(feature.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct DashboardPinnedTools: View {
    let open: (DashboardShortcut) -> Void
    @AppStorage(DashboardShortcut.chime.storageKey) private var chimePinned = false
    @AppStorage(DashboardShortcut.reminder.storageKey) private var reminderPinned = false
    var body: some View {
        if chimePinned { CompactChimeCard { open(.chime) } }
        FocusRadioCard()
        if reminderPinned { DashboardReminderCard { open(.reminder) } }
    }
}

/// Shared enable action: pinning only controls visibility, never permissions.
struct FocusChimeToggle: View {
    @AppStorage("Clockin.ChimeEnabled") private var enabled = false
    var body: some View {
        Toggle("Focus chime", isOn: Binding(get: { enabled }, set: { value in
            guard value != enabled else { return }
            enabled = value
            Haptics.play(.selection)
            if value { Task { await FocusChimeController.shared.requestPermission() } }
        }))
        .accessibilityIdentifier("chime.enabled")
    }
}

private struct DashboardReminderCard: View {
    let adjust: () -> Void
    @Environment(\.palette) private var palette
    @AppStorage(LongSessionReminderSchedule.preferenceKey) private var hours = LongSessionReminderSchedule.defaultHours
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge").foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Session reminder").font(.subheadline.weight(.semibold))
                Text(hours > 0 ? "After \(hours) hours of work" : "Off").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Adjust", action: adjust).frame(minHeight: 44)
                .accessibilityIdentifier("reminder.adjust")
        }.padding(14).card(palette)
    }
}
