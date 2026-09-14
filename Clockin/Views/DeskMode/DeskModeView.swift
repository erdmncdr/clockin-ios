import SwiftUI

/// Telefon yatay tutulunca acilan tam ekran sayac. Masada duran telefona
/// uzaktan bakilir: ekranin tamami sayaca ve kazanca ayrilir; bugunun toplami
/// ve kontroller kucuk, kenarlarda durur.
struct DeskModeView: View {
    let onClockOut: (WorkSession) -> Void

    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: store.running?.isPaused == false ? 1 : 60)) { context in
            let now = context.date
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
                        controls
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .background { palette.background.ignoresSafeArea() }
        .sensoryFeedback(trigger: store.running?.isPaused) { old, new in
            switch (old, new) {
            case (nil, .some): .start
            case (.some, nil): .stop
            default: .impact(weight: .light)
            }
        }
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
            Text(clock)
                .font(.system(size: 120, weight: .medium, design: palette.fontDesign))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(store.running == nil ? Color.secondary : Color.primary)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: clock)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(earnings)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: earnings)
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    Text((earned * rate).money(code: "TRY"))
                        .font(.title3)
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
                Text(DurationText.compact(duration))
                    .foregroundStyle(.secondary)
                Text(earnings.money(code: store.currencyCode))
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
                }
                roundButton(systemImage: "stop.fill", label: "Clock out",
                            foreground: .red, background: .red.opacity(0.18)) {
                    if let session = store.clockOut() { onClockOut(session) }
                }
            }
        } else {
            Button { store.clockIn() } label: {
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
