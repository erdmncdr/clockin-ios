import SwiftUI

/// Ayarlardaki odak cani ve odak radyosu.
///
/// Ilk halinde iki koyu kart olarak cizilmisti; formun gri gruplari arasinda
/// baska bir ekranin parcasi gibi duruyordu ve tam genislikte vurgu dugmesi
/// sayfanin en dikkat ceken ogesi oluyordu. Diger bolumler gibi satir.
struct FocusSettingsSection: View {
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @AppStorage("Clockin.ChimeEnabled") private var chimeEnabled = false
    @AppStorage("Clockin.ChimeIntervalMinutes") private var interval = 10
    @AppStorage("Clockin.ChimeSound") private var sound = FocusChimeSound.notification.rawValue
    @ObservedObject private var chime = FocusChimeController.shared
    @ObservedObject private var radio = FocusRadioController.shared

    var body: some View {
        Section {
            Toggle("Focus chime", isOn: Binding(get: { chimeEnabled }, set: { enabled in
                chimeEnabled = enabled
                if enabled { Task { await chime.requestPermission() } }
            }))
            if chimeEnabled {
                Stepper(value: $interval, in: 1...120) {
                    LabeledContent("Every", value: "\(interval) min of work")
                }
                .accessibilityValue("\(interval) minutes of work")
                LabeledContent("Sound", value: "Default notification")
                Button("Preview chime", systemImage: "speaker.wave.2") {
                    Task { await chime.preview(sound: sound) }
                }
                .disabled(!chime.canNotify)
                if chime.needsSystemSettings {
                    Button("Open notification settings", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                }
            }
        } header: {
            Text("Focus chime")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if chimeEnabled {
                    Text(chime.permissionText)
                    if let error = chime.errorMessage { Text(error).foregroundStyle(.red) }
                }
                Text("A notification sound after every interval of worked time; pauses do not count. iOS sets the volume and follows silent mode and Focus.")
            }
            .animation(.default, value: chimeEnabled)
        }
        .task {
            // Mac'ten gelen bir ses adi iOS'ta yok; desteklenen varsayilana don.
            if FocusChimeSound(rawValue: sound) == nil { sound = FocusChimeSound.notification.rawValue }
            interval = min(120, max(1, interval == 0 ? 10 : interval))
            await chime.refreshPermission()
        }

        Section {
            HStack(spacing: 12) {
                Image(systemName: radio.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Radio Paradise")
                    Text(radioStatus)
                        .font(.caption)
                        .foregroundStyle(radio.errorMessage == nil ? Color.secondary : Color.red)
                        .contentTransition(.opacity)
                }
                Spacer()
                if radio.isLoading {
                    ProgressView()
                } else {
                    Button {
                        if radio.isStarted { radio.stop() } else { radio.play() }
                    } label: {
                        Image(systemName: radio.isStarted ? "stop.fill" : "play.fill")
                            .font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(palette.accent.opacity(0.15), in: Circle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(palette.accent)
                    .accessibilityLabel(radio.isStarted ? "Stop Radio Paradise" : "Play Radio Paradise")
                }
            }
            .animation(.snappy, value: radio.isPlaying)
            .animation(.snappy, value: radio.isLoading)
            HStack(spacing: 10) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $radio.volume, in: 0...1)
                    .accessibilityLabel("Radio volume")
                    .accessibilityValue("\(Int(radio.volume * 100)) percent")
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
        } header: {
            Text("Focus radio")
        } footer: {
            Text("Eclectic, listener-supported, commercial-free. Streams over the internet and keeps playing with the screen locked.")
        }
    }

    private var radioStatus: String {
        if let error = radio.errorMessage { return error }
        if radio.isLoading { return "Connecting…" }
        return radio.isPlaying ? "Playing" : "Stopped"
    }
}
