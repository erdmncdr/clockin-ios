import SwiftUI

struct CompactChimeCard: View {
    let adjust: () -> Void
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.ChimeEnabled") private var enabled = false
    @AppStorage("Clockin.ChimeIntervalMinutes") private var interval = 10
    @AppStorage("Clockin.ChimeSound") private var sound = FocusChimeSound.defaultSound.rawValue

    var body: some View {
        Group {
            #if os(macOS)
            macCard
            #else
            phoneCard
            #endif
        }
        .onAppear { interval = min(120, max(1, interval == 0 ? 10 : interval)) }
    }

    #if os(macOS)
    private var macCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge").foregroundStyle(palette.accent)
                Text("Focus chime").font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                FocusChimeToggle()
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            HStack(spacing: 8) {
                Text("Every \(interval) min")
                    .font(.subheadline).monospacedDigit()
                Stepper("Every \(interval) min", value: $interval, in: 1...120)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                    .disabled(!enabled)
                    .accessibilityValue(Text("Every \(interval) min"))
                    .accessibilityIdentifier("chime.interval")
                Text(FocusChimeSound.selected(sound).displayName)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Menu {
                    Button("Sound & volume", systemImage: "slider.horizontal.3", action: adjust)
                    DashboardPinButton(feature: .chime)
                } label: {
                    Image(systemName: "ellipsis").frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 24, height: 24)
                .accessibilityLabel("Focus chime options")
            }
        }
        // Expand the painted card, not just the space surrounding its background.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card(palette)
    }
    #else
    private var phoneCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge").foregroundStyle(palette.accent)
                FocusChimeToggle().font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 8) {
                Stepper(value: $interval, in: 1...120) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Every \(interval) min").font(.subheadline).monospacedDigit()
                        Text(FocusChimeSound.selected(sound).displayName)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .disabled(!enabled).frame(minHeight: 44)
                .accessibilityIdentifier("chime.interval")
                Menu {
                    Button("Sound & volume", systemImage: "slider.horizontal.3", action: adjust)
                    DashboardPinButton(feature: .chime)
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }.accessibilityLabel("Focus chime options")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6).card(palette)
    }
    #endif
}
