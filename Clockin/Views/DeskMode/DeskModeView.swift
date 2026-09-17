import SwiftUI

/// Telefon yatay tutulunca acilan tam ekran sayac. Masada duran telefona
/// uzaktan bakilir: ekranin tamami sayaca ve kazanca ayrilir; bugunun toplami
/// ve kontroller kucuk, kenarlarda durur.
struct DeskModeView: View {
    let onClockOut: (WorkSession) -> Void

    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    @Environment(\.clockinContentActive) private var contentActive
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0

    @State private var sessionFeedback = HapticSignal()

    var body: some View {
        ActiveTimeline(interval: store.running?.isPaused == false ? 1 : 60) { now in
            let elapsed = store.running == nil ? 0 : store.elapsed(at: now)
            let todayDuration = store.todayDuration(at: now)
            let todayEarnings = store.todayEarnings(at: now)
            let earned = store.running == nil ? todayEarnings : store.currentEarnings(at: now)

            timerBlock(elapsed: elapsed, earned: earned, day: store.runningDayIfNotToday(at: now))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Bugun ve kontroller ayni alt satirda, dugmelerin ortasina hizali.
                .overlay(alignment: .bottom) {
                    HStack(alignment: .center) {
                        todaySummary(duration: todayDuration, earnings: todayEarnings)
                        Spacer(minLength: 16)
                        controls.buttonPressHaptic(false)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .background { palette.background.ignoresSafeArea() }
        .hapticFeedback(sessionFeedback)
    }

    private func timerBlock(elapsed: TimeInterval, earned: Double, day: Date?) -> some View {
        let clock = DurationText.clock(elapsed)
        let earnings = earned.money(code: store.currencyCode)
        return VStack(spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
            }
            RollingNumberText(clock, value: elapsed, font: .system(size: 120, weight: .medium),
                              design: palette.fontDesign)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(store.running == nil ? Color.secondary : Color.primary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                RollingNumberText(earnings, value: earned, font: .title.weight(.semibold))
                    .foregroundStyle(palette.accent)
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    RollingNumberText((earned * rate).money(code: "TRY"), value: earned * rate, font: .title3)
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            if let day {
                Label("Counts toward \(day.formatted(.dateTime.month(.abbreviated).day()))",
                      systemImage: "moon.stars")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timerAccessibilityLabel(elapsed: elapsed, earned: earned, day: day))
    }

    /// Bugunun toplami tek satir; hedef varsa altinda ince bir cizgi.
    private func todaySummary(duration: TimeInterval, earnings: Double) -> some View {
        let goal = GoalProgress(worked: duration, hours: dailyGoalHours)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
                RollingNumberText(DurationText.compact(duration), value: duration, font: .caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                RollingNumberText(earnings.money(code: store.currencyCode), value: earnings, font: .caption.weight(.semibold))
                    .foregroundStyle(palette.accent.opacity(0.8))
                if let goal {
                    Text("/ \(DurationText.compact(goal.target))")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            if let goal {
                GeometryReader { geometry in
                    Capsule()
                        .fill(palette.surfaceStroke)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(palette.accent)
                                .frame(width: geometry.size.width * goal.fraction)
                        }
                }
                .frame(width: 140, height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(todayAccessibilityLabel(duration: duration, earnings: earnings, goal: goal))
    }

    @ViewBuilder private var controls: some View {
        if let running = store.running {
            HStack(spacing: 10) {
                roundButton(systemImage: running.isPaused ? "play.fill" : "pause.fill",
                            label: running.isPaused ? "Resume" : "Pause",
                            foreground: .primary, background: palette.surfaceStroke) {
                    running.isPaused ? store.resume() : store.pause()
                    sendSessionFeedback(running.isPaused ? .sessionResumed : .sessionPaused)
                }
                roundButton(systemImage: "stop.fill", label: "Clock out",
                            foreground: .red, background: .red.opacity(0.18)) {
                    if let session = store.clockOut() {
                        sendSessionFeedback(.sessionEnded)
                        onClockOut(session)
                    }
                }
            }
        } else {
            Button {
                store.clockIn()
                sendSessionFeedback(.sessionStarted)
            } label: {
                Label("Clock in", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .foregroundStyle(palette.actionForeground)
                    .background(palette.accent, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
    }

    private func roundButton(systemImage: String, label: String, foreground: Color, background: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(foreground)
                .background(background, in: Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }

    private func sendSessionFeedback(_ event: HapticEvent) {
        guard contentActive, scenePhase == .active else { return }
        sessionFeedback.send(event)
    }

    private var statusColor: Color {
        guard let running = store.running else { return .secondary }
        return running.isPaused ? .orange : palette.accent
    }

    private var statusText: String {
        guard let running = store.running else { return "READY" }
        return running.isPaused ? "PAUSED" : "WORKING"
    }

    private func timerAccessibilityLabel(elapsed: TimeInterval, earned: Double, day: Date?) -> String {
        let duration = Duration.seconds(max(0, elapsed)).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide)
                .locale(Locale(identifier: "en_US"))
        )
        var label = store.running == nil
            ? "Ready. Earned today \(earned.money(code: store.currencyCode))"
            : "\(store.running?.isPaused == true ? "Paused. " : "")Session \(duration), earned \(earned.money(code: store.currencyCode))"
        if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
            label += ", \((earned * rate).money(code: "TRY"))"
        }
        if let day {
            label += ". Counts toward \(day.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return label
    }

    private func todayAccessibilityLabel(duration: TimeInterval, earnings: Double, goal: GoalProgress?) -> String {
        var label = "Today \(DurationText.compact(duration)), \(earnings.money(code: store.currencyCode))"
        if let goal {
            label += goal.isReached ? ", goal reached" : ", \(DurationText.compact(goal.remaining)) to go"
        }
        return label
    }
}
