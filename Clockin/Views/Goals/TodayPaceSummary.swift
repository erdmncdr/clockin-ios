import SwiftUI

/// Uses the shared minute snapshot, never rescans the archive with the live timer.
struct TodayPaceSummary: View {
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @AppStorage("Clockin.GoalMonthlyHours") private var monthly = 0.0
    @AppStorage("Clockin.GoalDailyHours") private var daily = 0.0
    @AppStorage(MonthlyWorkPlan.workdaysKey) private var workdays = 0
    @Environment(\.palette) private var palette

    var body: some View {
        if let snapshot = celebrations.snapshot, monthly > 0 {
            let plan = MonthlyWorkPlan(daily: snapshot.daily, monthlyGoalHours: monthly,
                dailyGoalHours: daily, workdaysPerWeek: workdays, now: celebrations.snapshotDate)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("This month").font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(DurationText.compact(plan.monthWorked)) / \(DurationText.compact(plan.target))")
                        .font(.caption).monospacedDigit()
                }
                ProgressView(value: plan.fraction).tint(palette.accent)
                if plan.reached {
                    Label("Monthly goal complete.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(palette.accent)
                } else if !plan.isConfigured {
                    Text("Choose workdays to see your daily pace.")
                } else if let required = plan.requiredDaily, required > 24 * 3600 {
                    Text("Over 24h/day needed. Adjust your goal.")
                } else if let hours = plan.suggestedDailyHours {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Suggested today").font(.subheadline.weight(.medium))
                        Spacer()
                        Text(DurationText.compact(hours * 3600))
                            .font(.title3.bold()).monospacedDigit().foregroundStyle(palette.accent)
                    }
                    let remaining = max(0, hours * 3600 - plan.todayWorked)
                    Text(remaining > 0 ? "\(DurationText.compact(remaining)) left today."
                         : "Today’s pace covered.")
                    if plan.dailyGoalTooLow {
                        Text("Your daily goal is below this pace.")
                    }
                    Text("~\(plan.estimatedWorkdaysRemaining) workdays left · \(workdays)/week")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
    }
}
