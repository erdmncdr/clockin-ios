import SwiftUI

struct MoneyMomentumView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette

    private var sessionState: MoneyMomentum.SessionState {
        guard let running = store.running else { return .idle }
        return running.isPaused ? .paused : .working
    }

    var body: some View {
        ActiveTimeline(interval: sessionState == .working ? 1 : 60) { now in
            let momentum = MoneyMomentum(
                hourlyRate: store.currentRate(at: now),
                currentEarnings: store.currentEarnings(at: now), state: sessionState,
                currencyCode: store.currencyCode, usdTryRate: exchangeRates.latestRate
            )
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: momentum.isEarning ? "flame.fill" : "gauge.with.dots.needle.67percent")
                        .foregroundStyle(momentum.isEarning ? .orange : palette.accent)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(momentum.isEarning ? "MONEY MOMENTUM" : "YOUR EARNING POWER")
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        RollingNumberText("+\(momentum.perSecond.money(code: store.currencyCode, maxFractionDigits: 4))/sec",
                                          value: momentum.perSecond, font: .subheadline.weight(.semibold))
                            .foregroundStyle(momentum.isEarning ? palette.accent : .secondary)
                        if let rate = momentum.tryPerSecond {
                            RollingNumberText("+\(rate.money(code: "TRY", maxFractionDigits: 4))/sec",
                                              value: rate, font: .subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                }
                if let target = momentum.nextTarget,
                   let progress = momentum.progress {
                    VStack(alignment: .leading, spacing: 6) {
                        MomentumMilestoneLabels(target: target, currencyCode: store.currencyCode)
                            .equatable()
                        ProgressView(value: progress)
                            .tint(palette.accent)
                            .accessibilityLabel("Progress to next earnings milestone")
                            .id(target)
                    }
                } else if sessionState != .idle {
                    Text("Milestone unavailable for this total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(palette)
    }

}

private struct MomentumMilestoneLabels: View, Equatable {
    let target: Double
    let currencyCode: String

    var body: some View {
        // Yerlesim yalnizca hedef degisince olculur; saniyelik metin ust katmandadir.
        ViewThatFits(in: .horizontal) {
            HStack {
                targetLabel
                Spacer(minLength: 8)
                MomentumRemainingLabel(target: target, currencyCode: currencyCode, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                targetLabel
                MomentumRemainingLabel(target: target, currencyCode: currencyCode, alignment: .leading)
            }
        }
    }

    private var targetLabel: some View {
        Text("NEXT \(target.money(code: currencyCode))")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
    }
}

private struct MomentumRemainingLabel: View {
    @EnvironmentObject private var store: ClockStore
    let target: Double
    let currencyCode: String
    let alignment: Alignment

    var body: some View {
        Text("\(min(10, target).money(code: currencyCode)) to go")
            .hidden()
            .overlay(alignment: alignment) {
                ActiveTimeline(interval: store.running?.isPaused == false ? 1 : 60) { now in
                    let remaining = max(0, target - store.currentEarnings(at: now))
                    RollingNumberText("\(remaining.money(code: currencyCode)) to go",
                                      value: remaining, font: .caption.weight(.semibold))
                }
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
    }
}
