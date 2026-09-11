import SwiftUI

/// Clock out sonrasi gosterilen ozet.
struct SessionSummaryView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true

    let session: WorkSession

    private var xp: Int { Int(session.duration / 3600 * 100) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if mascotEnabled { SessionCelebration() }
                VStack(spacing: 6) {
                    Text("SESSION COMPLETE")
                        .font(.caption.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text("Nice work!")
                        .font(.largeTitle.weight(.black))
                    Text(session.note.isEmpty ? "Focus session" : session.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    metric("TIME", DurationText.compact(session.duration))
                    Divider().frame(height: 36)
                    metric("EARNED", store.earnings(for: session).money(code: store.currencyCode))
                    Divider().frame(height: 36)
                    metric("XP", "+\(xp)")
                }
                .padding(.vertical, 14)
                .card(palette)

                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryActionButtonStyle(palette: palette))
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(palette.background)
        .presentationDetents([.medium])
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SessionCelebration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ClockinMascotStage(state: .celebrate)
            .frame(width: 64, height: 64)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
    }
}
