import SwiftUI

@MainActor
struct InsightsView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var editingGoals = false

    @State private var shareSnapshot: StatsShareSnapshot?

    init() {}

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let stats = InsightsSnapshot(store: store, now: context.date,
                                             dailyGoal: dailyGoalHours, monthlyGoal: monthlyGoalHours)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        goalsCard(stats, now: context.date)
                        InsightsHeatmapView(daily: stats.daily, earnings: stats.dailyEarnings,
                                            currencyCode: store.currencyCode, now: context.date)
                        totalsCard(stats)
                        reportsCard(stats)
                    }
                    .padding(16)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(palette.background)
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shareSnapshot = StatsShareSnapshot(store: store, dailyGoal: dailyGoalHours,
                                                           monthlyGoal: monthlyGoalHours)
                    } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share stats")
                }
            }
            .sheet(item: $shareSnapshot) { snapshot in
                ShareStatsView(snapshot: snapshot)
            }
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
    }

    private func goalsCard(_ stats: InsightsSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("GOALS")
            goalRow("Today", duration: stats.daily[Calendar.current.startOfDay(for: now), default: 0],
                    hours: dailyGoalHours)
            goalRow("This month", duration: stats.monthDuration, hours: monthlyGoalHours)
            ForEach(estimateLines(stats.goalEstimate), id: \.self) { line in
                Text(line).font(.caption).foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            // Acik/kapali durumu burada tutulur. Tutulmadiginda ilk hedef
            // girilince ustteki satirlar degisiyor ve bolum kendiliginden
            // kapaniyordu; ikinci dokunus baska bir yere denk geliyordu.
            DisclosureGroup("Edit goals", isExpanded: $editingGoals) {
                VStack(alignment: .leading, spacing: 14) {
                    Stepper(value: goalBinding($dailyGoalHours, maximum: 24), in: 0...24) {
                        Text("Daily: \(goalLabel(dailyGoalHours))")
                    }
                    Stepper(value: goalBinding($monthlyGoalHours, maximum: 744), in: 0...744) {
                        Text("Monthly: \(goalLabel(monthlyGoalHours))")
                    }
                    Text("Whole-hour steps. Zero turns a goal off. Goals are for tracking only and do not change your level or badges.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            }
            .font(.subheadline)
        }
        .padding(16).card(palette)
        .animation(.smooth(duration: 0.25), value: stats.goalEstimate)
        .sensoryFeedback(.selection, trigger: dailyGoalHours)
        .sensoryFeedback(.selection, trigger: monthlyGoalHours)
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

    private func estimateLines(_ estimate: InsightsGoalEstimate) -> [String] {
        var lines: [String] = []
        let time = { (date: Date) in date.formatted(date: .omitted, time: .shortened) }
        switch estimate.daily {
        case .off: break
        case .reached: lines.append("Today's goal is reached.")
        case .finish(let date): lines.append("At this pace you reach today's goal at \(time(date)).")
        case .startNow(let date): lines.append("Start now and you reach today's goal at \(time(date)).")
        }
        switch estimate.monthly {
        case .off: break
        case .reached: lines.append("This month's goal is reached.")
        case .workDays(let days, let fits):
            let amount = "\(days) \(days == 1 ? "day" : "days")"
            lines.append(fits
                ? "At your 7-day average, this month's goal is about \(amount) of work away."
                : "At your 7-day average, this month's goal needs about \(amount) of work, more than this month has left.")
        case .unavailable:
            lines.append("No work in the last 7 days to estimate this month's goal from.")
        }
        if lines.isEmpty { lines.append("Set a daily or monthly goal to get started.") }
        return lines
    }

    private func reportsCard(_ stats: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("REPORTS & RECORDS")
            metric("Average completed session", value: DurationText.compact(stats.averageSession))
            metric("Best weekday", value: stats.bestWeekday.map { Calendar.current.weekdaySymbols[$0 - 1] } ?? "No sessions")
            metric("Best start hour", value: stats.bestStartHour.map { String(format: "%02d:00", $0) } ?? "No sessions")
            metric("Average earnings / hour", value: stats.hourlyEarnings.money(code: store.currencyCode))
            metric("Last 30 days", value: DurationText.compact(stats.recentMonth))
            metric("Preceding 30 days", value: DurationText.compact(stats.previousMonth))
            metric("30-day trend", value: String(format: "%+.0f%%", stats.monthTrend * 100))
            Divider()
            metric("Best completed day", value: DurationText.compact(stats.bestDayDuration))
            if let day = stats.bestDay {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Reports use completed sessions. Earnings per hour also includes active work. Best weekday and start hour use total duration; ties choose the first calendar weekday or earliest hour. The trend compares the last 30 calendar days, today included, with the 30 before them, the same days History's 30D shows.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
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

// LevelBadge gibi mevcut cagiricilar korunur; store bagimliligi saf hesaplama dosyasina sizmaz.
extension InsightsSnapshot {
    @MainActor
    init(store: ClockStore, now: Date, dailyGoal: Double, monthlyGoal: Double) {
        let sessions = store.sessions
        self.init(sessions: sessions, running: store.running,
                  sessionEarnings: Dictionary(sessions.map { ($0.id, store.earnings(for: $0)) },
                                              uniquingKeysWith: { first, _ in first }),
                  runningEarnings: store.currentEarnings(at: now), now: now, calendar: .current,
                  dailyGoal: dailyGoal, monthlyGoal: monthlyGoal)
    }
}
