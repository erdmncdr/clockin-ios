import SwiftUI

struct FocusRadioCard: View {
    @Environment(\.palette) private var palette
    @AppStorage(DashboardShortcut.radio.storageKey) private var pinned = false
    @ObservedObject private var radio = FocusRadioController.shared

    // Laid out like the chime card beside it: icon and title with the main
    // control on the first row, details and the options menu below.
    var body: some View {
        if pinned || radio.state.showsCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: radio.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                        .foregroundStyle(palette.accent)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Focus radio").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    FocusRadioButtons(radio: radio)
                }
                HStack(spacing: 8) {
                    FocusRadioStationPicker(radio: radio)
                        .labelsHidden()
                        .tint(palette.accent)
                    Spacer(minLength: 0)
                    if pinned {
                        Menu {
                            DashboardPinButton(feature: .radio)
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Focus radio options")
                    }
                }
                if pinned {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $radio.volume, in: 0...1).accessibilityLabel("Radio volume")
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
                if radio.state == .failed {
                    Text("Could not connect. Tap play to retry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if radio.isLoading {
                    Text("Connecting…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .card(palette)
        }
    }
}

struct FocusRadioStationPicker: View {
    @ObservedObject var radio: FocusRadioController

    var body: some View {
        Picker("Station", selection: Binding(get: { radio.station.id }, set: { id in
            guard id != radio.station.id else { return }
            Haptics.play(.selection)
            radio.selectStation(id: id)
        })) {
            ForEach(RadioStation.stations) { station in
                Text(station.name).tag(station.id)
            }
        }
        .pickerStyle(.menu)
        .buttonPressHaptic(false)
        .accessibilityLabel("Radio station")
    }
}

struct FocusRadioButtons: View {
    @Environment(\.palette) private var palette
    @ObservedObject var radio: FocusRadioController

    var body: some View {
        HStack(spacing: 4) {
            Button {
                if radio.state.requestsPlayback { radio.pause() } else { radio.play() }
            } label: {
                Image(systemName: radio.state.requestsPlayback ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44)
                    .background(palette.accent.opacity(0.15), in: Circle())
            }
            .accessibilityLabel(radio.state.requestsPlayback ? "Pause radio" : "Play radio")
            if radio.state.showsCard {
                Button { radio.stop() } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Stop radio")
                .accessibilityHint("Ends playback; a pinned radio stays on Today")
            }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(palette.accent)
        .buttonStyle(.pressable)
    }
}
