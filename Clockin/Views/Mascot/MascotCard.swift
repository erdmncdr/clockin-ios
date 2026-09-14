import SwiftUI

struct MascotCard: View {
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var nudges = NudgeController.shared
    @Environment(\.palette) private var palette

    /// Kart Insights'a gotursun. Eskiden "Tap your level..." yaziyordu ama
    /// dokunulacak sey ekranin obur ucundaki rozetti; karta basan hicbir sey
    /// olmadigini goruyordu.
    let showInsights: () -> Void

    private var state: MascotAsset {
        if store.running?.isPaused == false { return .working }
        if nudges.mood?.isAngry == true { return .angry }
        guard let running = store.running else { return .idle }
        return running.isPaused ? .paused : .working
    }

    var body: some View {
        HStack(spacing: 12) {
            // Maskotun kendi dokunusu duruslari degistiriyor, o yuzden
            // Insights'a giden dugme yalnizca metin sutunu.
            ClockinMascotStage(state: state)
                .frame(width: 62, height: 62)
            Button(action: showInsights) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FOCUS COMPANION")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        Text(store.running?.isPaused == false ? state.message : (nudges.mood?.line ?? state.message))
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("See your streak and progress")
                            .font(.caption)
                            .foregroundStyle(palette.accent)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .foregroundStyle(.primary)
            .accessibilityHint("Opens Insights")
        }
        .padding(14)
        .card(palette)
    }
}
