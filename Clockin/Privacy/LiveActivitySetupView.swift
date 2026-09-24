import ActivityKit
import SwiftUI

/// Present once on the first foreground launch, including existing installs.
private struct LiveActivitySetupPresentation: ViewModifier {
    @AppStorage(LiveActivityPrivacy.setupSeenKey) private var seen = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showing, onDismiss: { seen = true }) {
                LiveActivitySetupView()
            }
            .celebrationBlocked(by: showing)
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active, !seen, !showing,
                      !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") || $0 == "--feedback-review" }) else { return }
                showing = true
            }
    }
}

extension View {
    func liveActivitySetup() -> some View { modifier(LiveActivitySetupPresentation()) }
}

struct LiveActivitySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(LiveActivityPrivacy.setupSeenKey) private var seen = false
    @AppStorage(LiveActivityPrivacy.consentKey) private var enabled = false
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var step = 0
    @State private var activitiesAllowed = false
    @State private var frequentAllowed = false
    @State private var settingsUnavailable = false
    @State private var showingPolicy = false

    private var palette: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var titles: [String] { [String(localized: "Keep earnings in view", bundle: .app), String(localized: "Check your iPhone settings", bundle: .app), String(localized: "Check the connection", bundle: .app)] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 6) {
                        ForEach(0..<3) { index in
                            Capsule().fill(index <= step ? palette.accent : palette.secondary.opacity(0.2))
                                .frame(height: 4)
                        }
                    }
                    .accessibilityLabel("Step \(step + 1) of 3")
                    Image(systemName: ["timer", "switch.2", "checkmark.circle"][step])
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                    Text(titles[step]).font(.largeTitle.bold())
                    if step == 0 { consentStep }
                    else if step == 1 { settingsStep }
                    else { connectionStep }
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: advance) {
                        Text(step == 0 && !enabled ? "Enable live updates" : step == 2 ? "Done" : "Continue")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(step == 1 && (!activitiesAllowed || !frequentAllowed))
                    .accessibilityIdentifier("liveSetup.continue")
                    Text("You can change this anytime in Clockin Settings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding().background(palette.background)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 { Button("Back") { step -= 1 } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(step == 2 ? "Close" : "Not now", action: finish)
                        .accessibilityIdentifier("liveSetup.skip")
                }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { refreshPermissions() }
            }
            .alert("Open Settings manually", isPresented: $settingsUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Open iPhone Settings → Apps → Clockin → Live Activities.")
            }
        }
        .tint(palette.accent)
        .preferredColorScheme(palette.colorScheme)
        .sheet(isPresented: $showingPolicy) { PrivacyPolicyBrowser() }
    }

    private var consentStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("See your earnings on the Lock Screen and Dynamic Island without reopening Clockin.")
                .font(.title3)
            Label("Your pay, earnings and notes stay on your device.", systemImage: "lock.shield")
            Text("When you enable this, Clockin sends a temporary notification address and its expiry to Netlify in the US. Apple delivers time signals so your iPhone can update the amount. Each registration lasts up to 8 hours.")
                .foregroundStyle(.secondary)
            Text("Turn it off in Clockin Settings to stop updates and request removal of the temporary server record.")
                .foregroundStyle(.secondary)
            Button("Read the privacy policy") { showingPolicy = true }
                .accessibilityIdentifier("liveSetup.policy")
            if enabled { Label("Live updates are already enabled", systemImage: "checkmark.circle.fill") }
        }
    }

    private var settingsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("In iPhone Settings → Apps → Clockin → Live Activities, turn on both options below.")
            permissionRow("Allow Live Activities", detail: "Shows your timer and earnings on the Lock Screen.", allowed: activitiesAllowed)
            permissionRow("More Frequent Updates", detail: "Lets iOS deliver live earnings updates more often.", allowed: frequentAllowed)
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url) { accepted in settingsUnavailable = !accepted }
            } label: {
                Label("Open iPhone Settings", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("liveSetup.openSettings")
            Text("Come back to Clockin after changing the settings. We'll check them again automatically. On older iOS versions, Clockin is listed directly in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Regular notification alerts are not required for Live Activity updates.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var connectionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            LiveActivityConnectionView()
            Text("Once a session is running, leave Clockin and check the amount on your Lock Screen after a minute or two.")
            Text("Apple controls delivery timing. Even with both settings on, an exact one-minute interval isn't guaranteed.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func permissionRow(_ title: LocalizedStringKey, detail: LocalizedStringKey, allowed: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(allowed ? palette.accent : palette.secondary)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(allowed ? "Enabled" : "Needs attention").font(.subheadline.weight(.medium))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func refreshPermissions() {
        let info = ActivityAuthorizationInfo()
        activitiesAllowed = info.areActivitiesEnabled
        frequentAllowed = info.frequentPushesEnabled
        SessionMirror.shared.refresh()
    }

    private func advance() {
        if step == 0 {
            enabled = true
            SessionMirror.shared.refresh()
        }
        if step < 2 { step += 1; refreshPermissions() }
        else { finish() }
    }

    private func finish() {
        seen = true
        dismiss()
    }
}

struct LiveActivityConnectionView: View {
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var push = LiveActivityPush.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.running?.isPaused == false {
                Text(push.registrationStatus.title).font(.headline)
                Text(push.registrationStatus.detail).font(.subheadline).foregroundStyle(.secondary)
                if push.registrationStatus != .registered {
                    Button("Check connection again") { SessionMirror.shared.refresh() }
                        .accessibilityIdentifier("liveSetup.retry")
                }
            } else {
                Text(store.running == nil ? "Start a session to connect" : "Resume your session to connect")
                    .font(.headline)
                Text("Clockin checks the server connection when your timer is running. No test session is needed.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("liveSetup.connection")
    }
}
