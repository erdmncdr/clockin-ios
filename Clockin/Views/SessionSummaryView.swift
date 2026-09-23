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
                    Text(SessionDisplay.note(session).isEmpty ? String(localized: "Focus session") : SessionDisplay.note(session))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    metric("TIME", DurationText.compact(session.duration))
                    Divider().frame(height: 36)
                    metric("EARNED", store.earnings(for: session).money(code: store.currencyCode))
                    Divider().frame(height: 36)
                    SummaryXP(value: xp)
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

    private func metric(_ title: LocalizedStringKey, _ value: String) -> some View {
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
            .scaleEffect(appeared || reduceMotion ? 1 : 0.65)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -10))
            .opacity(appeared || reduceMotion ? 1 : 0)
            .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.65, bounce: 0.3)) {
                    appeared = true
                }
            }
    }
}

@MainActor
private struct SummaryXP: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Int
    @State private var displayed = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("XP")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text("+\(reduceMotion ? value : displayed)")
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) XP earned")
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .task(id: CountTarget(value: value, reduceMotion: reduceMotion)) {
            guard !reduceMotion, value > 0 else {
                displayed = value
                return
            }
            displayed = 0
            // Adim sayisi XP'den bagimsiz; yalniz bu metin yenilenir.
            let steps = min(value, 24)
            for step in 1...steps {
                do { try await Task.sleep(for: .milliseconds(30)) }
                catch { return }
                let progress = Double(step) / Double(steps)
                let next = step == steps ? value : Int(Double(value) * (1 - pow(1 - progress, 3)))
                withAnimation(.easeOut(duration: 0.09)) {
                    displayed = next
                }
            }
        }
    }

    private struct CountTarget: Equatable {
        let value: Int
        let reduceMotion: Bool
    }
}
