import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct ClockinLiveActivity: Widget {
    private let palette = ClockinThemeChoice.carbon.palette

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClockinActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state, currencyCode: context.attributes.currencyCode, palette: palette)
                .activityBackgroundTint(palette.background)
                .activitySystemActionForegroundColor(palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        statusLabel(context.state)
                            .font(.caption.weight(.semibold))
                        Text(context.state.earnedAtUpdate.money(code: context.attributes.currencyCode))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(context.state.isPaused ? .orange : palette.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context.state)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(rateText(context.state, context.attributes.currencyCode))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ActivityButtons(state: context.state, palette: palette)
                    }
                }
            } compactLeading: {
                Text(context.state.earnedAtUpdate.money(code: context.attributes.currencyCode, maxFractionDigits: 0))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(context.state.isPaused ? .orange : palette.accent)
            } compactTrailing: {
                timerText(context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(palette.accent)
            }
        }
    }
}

private func statusLabel(_ state: ClockinActivityAttributes.ContentState) -> some View {
    Label(state.isPaused ? "Paused" : "Working", systemImage: state.isPaused ? "pause.fill" : "bolt.fill")
}

@ViewBuilder
private func timerText(_ state: ClockinActivityAttributes.ContentState) -> some View {
    // Saniyesiz gosterim uc yoldan denendi, hicbiri calismadi: `.timer` ve
    // `.stopwatch` dakika hassasiyetinde "1 hour, 15 minutes" diye yaziyor;
    // saniyeli sayaci gorunmez bir yer tutucuyla kirpmak Live Activity'de
    // sayaci tamamen bos birakiyor. Duraklatildiginda `pauseTime` metni dondurur.
    Text(timerInterval: state.timerRange, pauseTime: state.pausedAt, countsDown: false, showsHours: true)
}

private func rateText(_ state: ClockinActivityAttributes.ContentState, _ currencyCode: String) -> String {
    "\(state.hourlyRate.money(code: currencyCode)) / hr"
}

private struct LockScreenActivityView: View {
    let state: ClockinActivityAttributes.ContentState
    let currencyCode: String
    let palette: ClockinPalette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                statusLabel(state)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state.isPaused ? .orange : palette.accent)
                timerText(state)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(state.earnedAtUpdate.money(code: currencyCode))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(state.isPaused ? .orange : palette.accent)
                if currencyCode == "USD", let rate = state.usdTryRate {
                    Text("≈ \((state.earnedAtUpdate * rate).money(code: "TRY"))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.6))
                }
                if !state.note.isEmpty {
                    Text(state.note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            ActivityButtons(state: state, palette: palette)
        }
        .padding(16)
    }
}

private struct ActivityButtons: View {
    let state: ClockinActivityAttributes.ContentState
    let palette: ClockinPalette

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: TogglePauseIntent()) {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel(state.isPaused ? "Resume" : "Pause")

            Button(intent: ClockOutIntent()) {
                Image(systemName: "stop.fill")
                    .frame(width: 40, height: 40)
                    .background(.red.opacity(0.2), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel("Clock out")
        }
    }
}
