import SwiftUI

/// Telefon yatay tutulunca acilan tam ekran sayac. Masada duran telefona
/// uzaktan bakilir: sayac buyuk, kazanc her saniye, kontroller elin altinda.
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

            GeometryReader { geometry in
                let availableWidth = max(0, geometry.size.width - 24)
                HStack(spacing: 24) {
                    timerBlock(elapsed: elapsed, earned: earned,
                               day: store.runningDayIfNotToday(at: now))
                        .frame(width: availableWidth * 0.6)
                    todayCard(duration: todayDuration, earnings: todayEarnings)
                        .frame(width: availableWidth * 0.4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(16)
        }
        .background { palette.background.ignoresSafeArea() }
        .sensoryFeedback(trigger: store.running?.isPaused) { old, new in
            switch (old, new) {
            case (nil, .some): .start
            case (.some, nil): .stop
            default: .impact(weight: .light)
            }
        }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
    }

    private func timerBlock(elapsed: TimeInterval, earned: Double, day: Date?) -> some View {
        let clock = DurationText.clock(elapsed)
        let earnings = earned.money(code: store.currencyCode)
        return VStack(spacing: 8) {
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
                .font(.system(size: 96, weight: .medium, design: palette.fontDesign))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(store.running == nil ? Color.secondary : Color.primary)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: clock)
            Text(earnings)
                .font(.title.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: earnings)
            if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                Text((earned * rate).money(code: "TRY"))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
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

    private func todayCard(duration: TimeInterval, earnings: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY")
                    .font(.caption.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
                Text(DurationText.compact(duration))
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(earnings.money(code: store.currencyCode))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if let goal = GoalProgress(worked: duration, hours: dailyGoalHours) {
                goalBlock(goal)
            }
            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(palette)
    }

    private func goalBlock(_ goal: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                Capsule()
                    .fill(palette.surfaceStroke)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(palette.accent)
                            .frame(width: geometry.size.width * goal.fraction)
                    }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
            Text("\(DurationText.compact(goal.worked)) / \(DurationText.compact(goal.target))")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            Text(goal.isReached ? "Goal reached" : "\(DurationText.compact(goal.remaining)) to go")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var controls: some View {
        if let running = store.running {
            HStack(spacing: 10) {
                Button {
                    running.isPaused ? store.resume() : store.pause()
                } label: {
                    Label(running.isPaused ? "Resume" : "Pause",
                          systemImage: running.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(SecondaryActionButtonStyle(palette: palette))
                Button {
                    if let session = store.clockOut() { onClockOut(session) }
                } label: {
                    Label("Clock out", systemImage: "stop.fill")
                }
                .buttonStyle(DangerActionButtonStyle())
            }
        } else {
            Button { store.clockIn() } label: {
                Label("Clock in", systemImage: "play.fill")
            }
                .buttonStyle(PrimaryActionButtonStyle(palette: palette))
        }
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
            ? "Ready. Session \(duration), earned today \(earned.money(code: store.currencyCode))"
            : "\(store.running?.isPaused == true ? "Paused. " : "")Session \(duration), earned \(earned.money(code: store.currencyCode))"
        if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
            label += ", \((earned * rate).money(code: "TRY"))"
        }
        if let day {
            label += ". Counts toward \(day.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return label
    }
}
