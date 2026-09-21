import SwiftUI

struct LongSessionReminderSettingsSection: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(LongSessionReminderSchedule.preferenceKey) private var hours = LongSessionReminderSchedule.defaultHours
    @ObservedObject private var chime = FocusChimeController.shared
    @ObservedObject private var reminder = LongSessionReminderController.shared

    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        Section {
            DashboardPinButton(feature: .reminder)
            Picker("Long session reminder", selection: Binding(get: { hours }, set: { value in
                let changed = hours != value
                hours = value
                if changed { selectionFeedback.send(.selection) }
                SessionMirror.shared.refresh()
                if value > 0, !chime.canNotify { requestPermission() }
            })) {
                ForEach(LongSessionReminderSchedule.choices, id: \.self) { value in
                    Text(value == 0 ? "Off" : "\(value) h").tag(value)
                }
            }
            if hours > 0 {
                if !chime.canNotify, !chime.needsSystemSettings {
                    Button("Allow notifications", action: requestPermission)
                }
                if chime.needsSystemSettings {
                    Button("Open notification settings", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                }
            }
        } header: {
            Text("Session reminder")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("A reminder after the selected hours of worked time. Breaks do not count. Clock out, set an end time, or remind yourself in one hour from the notification.")
                if hours > 0, !chime.canNotify {
                    Text(chime.needsSystemSettings ? "Notifications denied" : "Allow notifications to receive reminders.")
                }
                if let error = reminder.errorMessage { Text(error).foregroundStyle(.red) }
                if let error = chime.errorMessage { Text(error).foregroundStyle(.red) }
            }
        }
        .hapticFeedback(selectionFeedback)
        .task { await chime.refreshPermission() }
    }

    private func requestPermission() {
        Task {
            await chime.requestPermission()
        }
    }
}
