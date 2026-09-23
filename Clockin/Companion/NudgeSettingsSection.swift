import SwiftUI

struct NudgeSettingsSection: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(NudgePlanner.enabledKey) private var enabled = true
    @AppStorage(NudgePlanner.toneKey) private var tone = NudgeTone.grumpy.rawValue
    @ObservedObject private var chime = FocusChimeController.shared
    @ObservedObject private var nudges = NudgeController.shared

    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        Section {
            Toggle("Nudges", isOn: Binding(get: { enabled }, set: { value in
                let changed = enabled != value
                enabled = value
                if changed { selectionFeedback.send(.selection) }
                SessionMirror.shared.refresh()
                if value { requestPermission() }
            }))
            Picker("Tone", selection: $tone.hapticSelection($selectionFeedback)) {
                ForEach(NudgeTone.allCases, id: \.rawValue) { Text(LocalizedStringKey($0.rawValue)).tag($0.rawValue) }
            }
            if enabled {
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
            Text("Companion nudges")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your companion checks in about breaks, missed work and goals, at most twice a day and never at night (22:00-08:00).")
                if let error = nudges.errorMessage { Text(error).foregroundStyle(.red) }
                if let error = chime.errorMessage { Text(error).foregroundStyle(.red) }
            }
        }
        .hapticFeedback(selectionFeedback)
        .onChange(of: tone) { _, _ in SessionMirror.shared.refresh() }
        .task { await chime.refreshPermission() }
    }

    private func requestPermission() {
        Task { await chime.requestPermission() }
    }
}
