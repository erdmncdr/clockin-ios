import SwiftUI

struct MascotCard: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette

    private var state: MascotAsset {
        guard let running = store.running else { return .idle }
        return running.isPaused ? .paused : .working
    }

    var body: some View {
        HStack(spacing: 12) {
            ClockinMascotStage(state: state)
                .frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 4) {
                Text("FOCUS COMPANION")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text(state.message)
                    .font(.subheadline.weight(.semibold))
                Text("Tap your level for streaks and progress.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .card(palette)
    }
}

