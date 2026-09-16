import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct ClockinLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClockinActivityAttributes.self) { context in
            let palette = context.state.theme.palette
            LockScreenActivityView(state: context.state, currencyCode: context.attributes.currencyCode)
                .environment(\.palette, palette)
                .environment(\.colorScheme, palette.colorScheme)
                .activityBackgroundTint(palette.background)
                .activitySystemActionForegroundColor(palette.accent)
        } dynamicIsland: { context in
            let palette = context.state.theme.palette.dynamicIslandPalette
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        statusLabel(context.state)
                            .font(.caption.weight(.semibold))
                        Text(context.state.earnedAtUpdate.money(code: context.attributes.currencyCode))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        if let label = asOfText(context.state) {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(context.state.isPaused ? palette.secondary : palette.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandTimerText(context.state)
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
                        ActivityButtons(state: context.state)
                            .environment(\.palette, palette)
                            .environment(\.colorScheme, .dark)
                    }
                }
            } compactLeading: {
                // Sure solda, kisa olan tutar sagda: sag taraf genisledikce durum
                // cubugundaki Wi-Fi ve pil simgelerine yer kalmiyordu.
                // Yuz saati gecen bir oturumda "200:00" bu genislige sigmiyor
                // ve "200:..." diye kesiliyordu. Kesmek yerine kuculsun:
                // okunakli kalir ve ada genislemez.
                islandTimerText(context.state)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 50, alignment: .leading)
            } compactTrailing: {
                // Tam sayiya asagi yuvarlanir: $1,61 "$2" yaziyordu, kazanilandan
                // fazlasi. Tutar son guncellemeye ait oldugu icin zaten geride kalabilir.
                Text(context.state.earnedAtUpdate.rounded(.down).money(code: context.attributes.currencyCode, maxFractionDigits: 0))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(context.state.isPaused ? palette.secondary : palette.accent)
                    .frame(width: 32, alignment: .trailing)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(palette.accent)
                    .accessibilityLabel(context.state.isPaused ? "Paused session" : "Working session")
            }
        }
    }
}

private func statusLabel(_ state: ClockinActivityAttributes.ContentState) -> some View {
    Label(state.isPaused ? "Paused" : "Working", systemImage: state.isPaused ? "pause.fill" : "bolt.fill")
}

@ViewBuilder
private func islandTimerText(_ state: ClockinActivityAttributes.ContentState) -> some View {
    if #available(iOS 18.0, *) {
        let format = Duration.TimeFormatStyle(pattern: .hourMinute(padHourToLength: 2, roundSeconds: .down))
        if let pausedAt = state.pausedAt {
            Text(Duration.seconds(max(0, pausedAt.timeIntervalSince(state.timerStart))), format: format)
        } else {
            // Foundation's duration pattern preserves numeric HH:mm. The
            // system advances this source even while the app is suspended.
            Text(.durationOffset(to: state.timerStart), format: format)
        }
    } else {
        timerText(state)
    }
}

@ViewBuilder
private func timerText(_ state: ClockinActivityAttributes.ContentState) -> some View {
    // Kilit ekrani icin saniyeli sayac. Adadaki saniyesiz gosterim
    // `islandTimerText`'te; ondan once denenip calismayan yollar: `.timer` ve
    // `.stopwatch` dakika hassasiyetinde "1 hour, 15 minutes" diye yaziyor;
    // saniyeli sayaci gorunmez bir yer tutucuyla kirpmak Live Activity'de
    // sayaci tamamen bos birakiyor. Duraklatildiginda `pauseTime` metni dondurur.
    Text(timerInterval: state.timerRange, pauseTime: state.pausedAt, countsDown: false, showsHours: true)
}

/// Tutarin ait oldugu an. Live Activity tutari kendisi ilerletemez; uygulama
/// arka plandayken guncelleme gelmez ve sure akarken para donuk kalir.
/// Etkinlik yalnizca uygulama onde degilken gorunur, yani gorundugu her an
/// tutar en son uygulamadan cikildigi ana aittir; bu yuzden calisan seansta
/// hep yazilir. Sistemin `isStale` bayragina guvenilmedi: simulatorde eskime
/// tarihi gecse de gelmedi.
private func asOfText(_ state: ClockinActivityAttributes.ContentState) -> String? {
    guard !state.isPaused, let updatedAt = state.updatedAt else { return nil }
    return "as of " + updatedAt.formatted(date: .omitted, time: .shortened)
}

private func rateText(_ state: ClockinActivityAttributes.ContentState, _ currencyCode: String) -> String {
    "\(state.hourlyRate.money(code: currencyCode)) / hr"
}

private struct LockScreenActivityView: View {
    let state: ClockinActivityAttributes.ContentState
    let currencyCode: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                statusLabel(state)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state.isPaused ? palette.secondary : palette.accent)
                timerText(state)
                    .font(.system(size: 34, weight: .semibold, design: palette.fontDesign))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(state.earnedAtUpdate.money(code: currencyCode))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(state.isPaused ? palette.secondary : palette.accent)
                let converted = currencyCode == "USD" ? state.usdTryRate.map { (state.earnedAtUpdate * $0).money(code: "TRY") } : nil
                let asOf = asOfText(state)
                if converted != nil || asOf != nil {
                    Text([converted, asOf].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if !state.note.isEmpty {
                    Text(state.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            ActivityButtons(state: state)
        }
        .padding(16)
    }
}

private struct ActivityButtons: View {
    let state: ClockinActivityAttributes.ContentState
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: TogglePauseIntent()) {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 40, height: 40)
                    .background(palette.surfaceStroke, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
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
