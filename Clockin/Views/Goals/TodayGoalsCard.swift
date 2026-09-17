import SwiftUI

struct TodayGoalsCard: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0

    @AppStorage(GoalPrompt.dismissedKey) private var dismissedTimestamp = 0.0
    @AppStorage(GoalPrompt.configuredKey) private var everConfigured = false

    let now: Date
    let showInsights: () -> Void
    let setGoals: () -> Void

    var body: some View {
        let daily = GoalProgress(worked: store.todayDuration(at: now), hours: dailyGoalHours)
        let monthly = GoalProgress(worked: monthWorked, hours: monthlyGoalHours)
        Group {
            if daily != nil || monthly != nil {
                Button(action: showInsights) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("GOALS", systemImage: "target")
                                .font(.caption2.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        if let daily { row("Today", daily) }
                        if let monthly { row("This month", monthly) }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 0.98))
                .card(palette)
                .accessibilityHint("Opens Insights, where goals are edited")
                .transition(.opacity)
            } else if GoalPrompt.isVisible(daily: dailyGoalHours, monthly: monthlyGoalHours,
                everConfigured: everConfigured, completedSessions: store.sessions.count,
                dismissedAt: dismissedTimestamp == 0 ? nil : Date(timeIntervalSince1970: dismissedTimestamp), now: now) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Set a daily or monthly goal to track your progress")
                        .font(.subheadline)
                    HStack {
                        Button("Set goals", action: setGoals)
                            .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Not now") { dismissedTimestamp = now.timeIntervalSince1970 }
                            .buttonStyle(.borderless)
                            .accessibilityHint("Hides this reminder for 7 days")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(14)
                .card(palette)
            }
        }
    }

    private var monthWorked: TimeInterval { store.monthDuration(at: now) }

    private func row(_ title: String, _ goal: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                RollingNumberText(DurationText.compact(goal.worked), value: goal.worked,
                                  font: .subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("/ \(DurationText.compact(goal.target))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.accent.opacity(0.15))
                    Capsule().fill(palette.accent)
                        .frame(width: max(geometry.size.width * goal.fraction, goal.worked > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
            RollingNumberText(goal.isReached ? "Goal reached" : "\(DurationText.compact(goal.remaining)) to go",
                              value: goal.remaining, font: .caption,
                              foregroundColor: goal.isReached ? palette.accent : .secondary)
                .foregroundStyle(goal.isReached ? palette.accent : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) goal")
        .accessibilityValue(goal.isReached
            ? "Reached, \(DurationText.compact(goal.worked)) of \(DurationText.compact(goal.target))"
            : "\(DurationText.compact(goal.worked)) of \(DurationText.compact(goal.target)), \(DurationText.compact(goal.remaining)) to go")
    }
}
