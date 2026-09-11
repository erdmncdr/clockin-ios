import SwiftUI

@MainActor
struct InsightsView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0

    init() {}

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let stats = InsightsSnapshot(store: store, now: context.date,
                                             dailyGoal: dailyGoalHours, monthlyGoal: monthlyGoalHours)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        levelCard(stats)
                        goalsCard(stats, now: context.date)
                        InsightsHeatmapView(daily: stats.daily, earnings: stats.dailyEarnings,
                                            currencyCode: store.currencyCode, now: context.date)
                        totalsCard(stats)
                        milestonesCard(stats)
                    }
                    .padding(16)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(palette.background)
            .navigationTitle("Insights")
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
    }

    private func levelCard(_ stats: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Level \(stats.level)", systemImage: "trophy.fill")
                .font(.title2.bold())
                .foregroundStyle(palette.accent)
            Text("\(stats.xp.formatted()) XP")
                .font(.headline).monospacedDigit()
            SwiftUI.ProgressView(value: Double(stats.xp % 500) / 500)
                .accessibilityLabel("Progress to next level")
            Text("\(500 - stats.xp % 500) XP to level \(stats.level + 1)")
                .font(.subheadline).foregroundStyle(.secondary)
            Divider()
            metric("Current streak", value: "\(stats.currentStreak) days")
            metric("Longest streak", value: "\(stats.longestStreak) days")
            DisclosureGroup("How XP works") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("100 XP per hour: \(stats.baseXP.formatted()) XP")
                    Text("Goals: +\(stats.goalXP.formatted()) XP • Streaks: +\(stats.streakXP.formatted()) XP")
                    Text("Each daily goal adds 100 XP; reaching twice the goal adds another 250 XP. Each monthly goal adds 500 XP.")
                    Text("Streak bonuses add up: 3 days +100, 7 +250, 14 +500, 30 +1,000 and 60 +2,000 XP.")
                }
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            .font(.subheadline)
            if let running = store.running {
                Label(running.isPaused ? "Includes paused session" : "Includes running session • updates every minute",
                      systemImage: running.isPaused ? "pause.circle" : "clock")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16).card(palette)
    }

    private func goalsCard(_ stats: InsightsSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("GOALS")
            goalRow("Today", duration: stats.daily[Calendar.current.startOfDay(for: now), default: 0],
                    hours: dailyGoalHours)
            goalRow("This month", duration: stats.monthDuration, hours: monthlyGoalHours)
            DisclosureGroup("Edit goals") {
                VStack(alignment: .leading, spacing: 14) {
                    Stepper(value: goalBinding($dailyGoalHours, maximum: 24), in: 0...24) {
                        Text("Daily: \(goalLabel(dailyGoalHours))")
                    }
                    Stepper(value: goalBinding($monthlyGoalHours, maximum: 744), in: 0...744) {
                        Text("Monthly: \(goalLabel(monthlyGoalHours))")
                    }
                    Text("Whole-hour steps. Zero turns a goal off. Changing goals recalculates past goal bonuses and your level.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            }
            .font(.subheadline)
        }
        .padding(16).card(palette)
    }

    private func goalRow(_ title: String, duration: TimeInterval, hours: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            metric(title, value: DurationText.compact(duration))
            if hours > 0 {
                let target = hours * 3600
                SwiftUI.ProgressView(value: min(max(duration / target, 0), 1))
                    .accessibilityLabel("\(title) goal progress")
                Text(duration >= target ? "Goal reached • \(DurationText.compact(target)) goal" :
                        "\(DurationText.compact(max(0, target - duration))) remaining of \(DurationText.compact(target))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No goal set").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func goalBinding(_ value: Binding<Double>, maximum: Int) -> Binding<Int> {
        Binding {
            guard value.wrappedValue.isFinite else { return 0 }
            return Int(min(max(value.wrappedValue.rounded(), 0), Double(maximum)))
        } set: { value.wrappedValue = Double($0) }
    }

    private func goalLabel(_ value: Double) -> String {
        value > 0 ? "\(value.formatted(.number.precision(.fractionLength(0...2))))h" : "No goal"
    }

    private func totalsCard(_ stats: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("YOUR RHYTHM")
            metric("Last 7 days", value: DurationText.compact(stats.recentWeek))
            metric("Previous 7 days", value: DurationText.compact(stats.previousWeek))
            if stats.previousWeek > 0 {
                let change = (stats.recentWeek - stats.previousWeek) / stats.previousWeek
                metric("Change", value: change.formatted(.percent.precision(.fractionLength(0))))
            }
            Divider()
            metric("This month", value: DurationText.compact(stats.monthDuration))
            metric("Month earnings", value: stats.monthEarnings.money(code: store.currencyCode))
            metric("All time", value: DurationText.compact(stats.totalDuration))
            metric("Total earnings", value: stats.totalEarnings.money(code: store.currencyCode))
            metric("Active days", value: stats.daily.count.formatted())
            metric("Longest completed session", value: DurationText.compact(stats.longestSession))
            Text("Time and earnings belong to the day a session started, including sessions that cross midnight.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
    }

    private func milestonesCard(_ stats: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("MILESTONES")
            milestone("First session", detail: "\(stats.sessionCount) completed sessions", unlocked: stats.sessionCount > 0)
            milestone("Century", detail: "\(DurationText.compact(stats.totalDuration)) / 100h", unlocked: stats.totalDuration >= 360_000)
            milestone("Fortnight fire", detail: "\(stats.longestStreak) / 14 consecutive days", unlocked: stats.longestStreak >= 14)
            milestone("Marathon", detail: "\(DurationText.compact(stats.longestSession)) / 4h in one completed session", unlocked: stats.longestSession >= 14_400)
            milestone("Goal setter", detail: "\(stats.goalDays) daily goals reached", unlocked: stats.goalDays > 0)
            milestone("Double down", detail: "\(stats.doubleGoalDays) double-goal days", unlocked: stats.doubleGoalDays > 0)
            milestone("Month finisher", detail: "\(stats.goalMonths) monthly goals reached", unlocked: stats.goalMonths > 0)
        }
        .padding(16).card(palette)
    }

    private func milestone(_ title: String, detail: String, unlocked: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: unlocked ? "checkmark.seal.fill" : "lock")
                .foregroundStyle(unlocked ? palette.accent : palette.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(unlocked ? "Unlocked" : "Locked")
    }

    private func metric(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(value).fontWeight(.semibold).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(.secondary)
                Text(value).fontWeight(.semibold).monospacedDigit()
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
