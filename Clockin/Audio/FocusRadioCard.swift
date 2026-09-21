import SwiftUI

struct FocusRadioCard: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(DashboardShortcut.radio.storageKey) private var pinned = false
    @ObservedObject private var radio = FocusRadioController.shared

    var body: some View {
        if pinned || radio.state.showsCard {
            VStack(alignment: .leading, spacing: 8) {
                if typeSize.isAccessibilitySize {
                    stationMenu
                    FocusRadioButtons(radio: radio)
                } else {
                    HStack(spacing: 8) {
                        stationMenu
                        Spacer(minLength: 0)
                        FocusRadioButtons(radio: radio)
                    }
                }
                if pinned {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $radio.volume, in: 0...1).accessibilityLabel("Radio volume")
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                    DashboardPinButton(feature: .radio, compact: true)
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
            .padding(14)
            .card(palette)
        }
    }

    private var stationMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("FOCUS RADIO", systemImage: "radio")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            FocusRadioStationPicker(radio: radio)
                .labelsHidden()
                .tint(palette.accent)
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
