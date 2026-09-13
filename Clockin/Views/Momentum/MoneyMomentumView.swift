import SwiftUI

struct MoneyMomentumView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sessionState: MoneyMomentum.SessionState {
        guard let running = store.running else { return .idle }
        return running.isPaused ? .paused : .working
    }

    var body: some View {
        // Hizli yenileme sadece bu seritte kalir; gecmis ve gun toplami tekrar hesaplanmaz.
        // Hareketsiz durumda seyrek yenileme, tarihli ucret degisimini yine yakalar.
        TimelineView(.periodic(from: .now, by: sessionState == .working ? (reduceMotion ? 1 : 0.25) : 60)) { context in
            let momentum = MoneyMomentum(
                hourlyRate: store.currentRate(at: context.date),
                currentEarnings: store.currentEarnings(at: context.date), state: sessionState,
                currencyCode: store.currencyCode, usdTryRate: exchangeRates.latestRate
            )
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: momentum.isEarning ? "flame.fill" : "sparkles")
                        .foregroundStyle(momentum.isEarning ? .orange : palette.accent)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(momentum.isEarning ? "MONEY MOMENTUM" : "YOUR EARNING POWER")
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        Text("+\(momentum.perSecond.money(code: store.currencyCode, maxFractionDigits: 4))/sec")
                            .foregroundStyle(momentum.isEarning ? palette.accent : .secondary)
                        if let rate = momentum.tryPerSecond {
                            Text("≈ +\(rate.money(code: "TRY", maxFractionDigits: 4))/sec")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                }
                if let target = momentum.nextTarget, let remaining = momentum.remaining,
                   let progress = momentum.progress {
                    VStack(alignment: .leading, spacing: 6) {
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                targetLabel(target)
                                Spacer(minLength: 8)
                                remainingLabel(remaining)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                targetLabel(target)
                                remainingLabel(remaining)
                            }
                        }
                        ProgressView(value: progress)
                            .tint(palette.accent)
                            .accessibilityLabel("Progress to next earnings milestone")
                            // Hedef degisince geriye dogru dolum animasyonu kullanilmaz.
                            .animation(reduceMotion ? nil : .linear(duration: 0.25), value: progress)
                            .id(target)
                    }
                } else if sessionState != .idle {
                    Text("Milestone unavailable for this total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(palette)
            .transaction { if reduceMotion { $0.animation = nil } }
        }
    }

    private func targetLabel(_ target: Double) -> some View {
        Text("NEXT \(target.money(code: store.currencyCode))")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private func remainingLabel(_ remaining: Double) -> some View {
        Text("\(remaining.money(code: store.currencyCode)) to go")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
    }
}
