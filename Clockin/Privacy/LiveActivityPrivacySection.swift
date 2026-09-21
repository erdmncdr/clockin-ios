import SwiftUI

struct LiveActivityPrivacySection: View {
    let openSetup: () -> Void
    let openPolicy: () -> Void
    @AppStorage(LiveActivityPrivacy.consentKey) private var enabled = false
    @ObservedObject private var push = LiveActivityPush.shared
    @State private var showConsent = false

    var body: some View {
        Section {
            Toggle("Live earnings updates", isOn: Binding(get: { enabled }, set: { value in
                if value { showConsent = true }
                else { enabled = false; SessionMirror.shared.refresh() }
            }))
            .accessibilityIdentifier("privacy.liveUpdates")
            Button("Privacy policy", action: openPolicy)
                .accessibilityIdentifier("privacy.policy")
            Button("Live updates setup guide", action: openSetup)
                .accessibilityIdentifier("privacy.setupGuide")
            if enabled { LiveActivityConnectionView() }
            if push.deletionPending {
                Text("Server cleanup pending. Clockin will retry when connected.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Privacy & Live Activity")
        } footer: {
            Text("Optional minute updates for the Dynamic Island and Lock Screen. Pay, earnings, notes and work history stay on your device. Delivery timing depends on iOS.")
        }
        .alert("Enable live earnings updates?", isPresented: $showConsent) {
            Button("Not now", role: .cancel) {}
            Button("Enable updates") {
                enabled = true
                SessionMirror.shared.refresh()
            }
        } message: {
            Text("Clockin sends only a temporary notification address and its expiry to Netlify in the US. Apple delivers time signals; your device calculates earnings. The registration lasts up to 8 hours. You can turn this off here to stop updates and request deletion. Pay, earnings and notes are not sent to this server.")
        }
        .task { push.retryPendingDeletions() }
    }
}
