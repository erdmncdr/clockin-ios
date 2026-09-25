import SwiftUI

/// Ayarlardaki odak cani ve odak radyosu.
///
/// Ilk halinde iki koyu kart olarak cizilmisti; formun gri gruplari arasinda
/// baska bir ekranin parcasi gibi duruyordu ve tam genislikte vurgu dugmesi
/// sayfanin en dikkat ceken ogesi oluyordu. Diger bolumler gibi satir.
struct FocusSettingsSection: View {
    var only: DashboardShortcut? = nil
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @AppStorage("Clockin.ChimeEnabled") private var chimeEnabled = false
    @AppStorage("Clockin.ChimeIntervalMinutes") private var interval = 10
    @AppStorage("Clockin.ChimeSound") private var sound = FocusChimeSound.defaultSound.rawValue
    @AppStorage("Clockin.ChimeVolume") private var volume = FocusChimeVolume.defaultValue
    @ObservedObject private var chime = FocusChimeController.shared
    @ObservedObject private var radio = FocusRadioController.shared

    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        if only == nil || only == .chime {
            Section {
                FocusChimeToggle()
                if chimeEnabled {
                    Stepper(value: $interval.hapticSelection($selectionFeedback), in: 1...120) {
                        LabeledContent("Every", value: String(localized: "\(interval) min of work", bundle: .app))
                    }
                    .accessibilityValue("\(interval) minutes of work")
                    Picker("Sound", selection: Binding(get: {
                        FocusChimeSound.selected(sound).rawValue
                    }, set: { selection in
                        sound = selection
                        chime.preview(sound: selection)
                    })) {
                        ForEach(FocusChimeSound.allCases) { sound in
                            Text(sound.displayName).tag(sound.rawValue)
                        }
                    }
                    Button("Preview", systemImage: "speaker.wave.2") {
                        chime.preview(sound: sound)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Volume", value: FocusChimeVolume.clamped(volume).formatted(
                            .percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero)))
                        Slider(value: Binding(get: { FocusChimeVolume.clamped(volume) }, set: {
                            volume = FocusChimeVolume.clamped($0)
                            chime.updatePlaybackVolume()
                        }), in: FocusChimeVolume.range, step: 0.01)
                        .accessibilityLabel("Chime volume")
                        .accessibilityValue("\(Int((FocusChimeVolume.clamped(volume) * 100).rounded())) percent")
                    }
                    if chime.needsSystemSettings {
                        Button("Open notification settings", systemImage: "gear") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                }
                // The setting comes first; putting it on Today is an extra.
                DashboardPinButton(feature: .chime)
            } header: {
                if only == nil { Text("Focus chime") }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if chimeEnabled {
                        Text(chime.permissionText)
                        if let error = chime.errorMessage { Text(error).foregroundStyle(.red) }
                    }
                    Text("A chime after every interval of worked time; pauses do not count. Volume applies while Clockin is open. In the background, iOS plays notification sounds at the system volume and follows silent mode and Focus.")
                    if chimeEnabled && radio.isStarted {
                        Text("While Focus radio is playing, chimes remain audible in silent mode.")
                    }
                }
                .animation(.default, value: chimeEnabled)
            }
            .hapticFeedback(selectionFeedback)
            .task {
                sound = FocusChimeSound.migrate().rawValue
                volume = FocusChimeVolume.clamped(volume)
                interval = min(120, max(1, interval == 0 ? 10 : interval))
                await chime.refreshPermission()
            }

        }
        if only == nil || only == .radio {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: radio.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                        .font(.title3)
                        .foregroundStyle(palette.accent)
                        .frame(width: 28)
                        .contentTransition(.symbolEffect(.replace))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(radio.station.name)
                        Text(radioStatus)
                            .font(.caption)
                            .foregroundStyle(radio.errorMessage == nil ? Color.secondary : Color.red)
                            .contentTransition(.opacity)
                    }
                    Spacer()
                    FocusRadioButtons(radio: radio)
                }
                FocusRadioStationPicker(radio: radio)
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $radio.volume, in: 0...1)
                        .accessibilityLabel("Radio volume")
                        .accessibilityValue("\(Int(radio.volume * 100)) percent")
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                DashboardPinButton(feature: .radio)
            } header: {
                if only == nil { Text("Focus radio") }
            } footer: {
                Text("\(radio.station.description). Streams over the internet and keeps playing with the screen locked. Pin it to Today for station, playback and volume controls.")
            }
        }
    }

    private var radioStatus: String {
        if let error = radio.errorMessage { return error }
        if radio.isLoading { return String(localized: "Connecting…", bundle: .app) }
        if radio.state == .failed { return String(localized: "Could not connect. Tap play to retry.", bundle: .app) }
        if radio.state == .paused { return String(localized: "Paused", bundle: .app) }
        return radio.isPlaying ? String(localized: "Playing", bundle: .app) : String(localized: "Stopped", bundle: .app)
    }
}
