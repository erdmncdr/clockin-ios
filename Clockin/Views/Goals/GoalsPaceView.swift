import Charts
import SwiftUI

struct GoalsPaceView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoal = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoal = 0.0
    @AppStorage(MonthlyWorkPlan.workdaysKey) private var workdays = 0
    @AppStorage(GoalPrompt.configuredKey) private var everConfigured = false
    @FocusState private var focusedGoal: GoalField?
    @State private var pendingDailyFocus = false
    @Binding var openGoalEditor: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let plan = MonthlyWorkPlan(daily: workByDay(at: context.date), monthlyGoalHours: monthlyGoal,
                                       dailyGoalHours: dailyGoal, workdaysPerWeek: workdays, now: context.date)
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Goals & Pace").font(.title2.bold())
                            Text("Your targets, workweek and month-end outlook.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        summary(plan)
                        todaySummary(plan, now: context.date)
                        settings.id("plan-settings")
                        if plan.isConfigured {
                            recommendation(plan)
                            forecast(plan)
                        }
                        if plan.dailyTarget > 0 || plan.monthWorked > 0 { dailyChart(plan) }
                        Text("On-device estimates. Work counts on its start date.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissDecimalKeyboard(isEditing: focusedGoal != nil) { focusedGoal = nil }
                .onChange(of: focusedGoal) { _, field in
                    if let field { scroll.scrollTo(field, anchor: .center) }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    if let field = focusedGoal { scroll.scrollTo(field, anchor: .center) }
                }
                .task(id: openGoalEditor) {
                    guard openGoalEditor else { return }
                    scroll.scrollTo("plan-settings", anchor: .top)
                    pendingDailyFocus = true
                    openGoalEditor = false
                }
            }
        }
        .background(palette.background)
        .tint(palette.accent)
        .onDisappear {
            focusedGoal = nil
            pendingDailyFocus = false
            openGoalEditor = false
        }
        .onChange(of: dailyGoal) { _, _ in markConfigured() }
        .onChange(of: monthlyGoal) { _, _ in markConfigured() }
    }

    private func workByDay(at now: Date) -> [Date: TimeInterval] {
        var result: [Date: TimeInterval] = [:]
        let calendar = Calendar.current
        for session in store.sessions where session.start <= now {
            result[calendar.startOfDay(for: session.start), default: 0] += session.duration
        }
        if let running = store.running, running.start <= now {
            result[calendar.startOfDay(for: running.start), default: 0] += running.elapsed(at: now)
        }
        return result
    }

    private func summary(_ plan: MonthlyWorkPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(plan.today.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.wide).year()).uppercased(with: .current))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(DurationText.compact(plan.monthWorked))
                .font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                .accessibilityLabel("Worked this month: \(DurationText.compact(plan.monthWorked))")
            if plan.hasGoal {
                Text("of \(DurationText.compact(plan.target)) this month")
                    .foregroundStyle(.secondary)
                SwiftUI.ProgressView(value: plan.fraction)
                    .accessibilityLabel("Monthly goal progress")
                metric("Remaining", DurationText.compact(plan.remaining))
                if plan.reached {
                    Label("Monthly goal reached. You've earned some breathing room.", systemImage: "checkmark.circle")
                        .font(.subheadline).foregroundStyle(palette.accent)
                }
            } else {
                Text("Set a monthly goal to build your plan.").foregroundStyle(.secondary)
            }
        }
        .padding(18).card(palette)
    }

    private func todaySummary(_ plan: MonthlyWorkPlan, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("TODAY")
            metric("Worked", DurationText.compact(plan.todayWorked))
            if plan.dailyTarget > 0 {
                SwiftUI.ProgressView(value: min(1, plan.todayWorked / plan.dailyTarget))
                    .accessibilityLabel("Daily goal progress")
                metric("Daily goal", DurationText.compact(plan.dailyTarget))
                let remaining = max(0, plan.dailyTarget - plan.todayWorked)
                if remaining == 0 {
                    Label("Today's goal is reached.", systemImage: "checkmark.circle")
                        .font(.subheadline).foregroundStyle(palette.accent)
                } else {
                    metric("Remaining", DurationText.compact(remaining))
                    let finish = now.addingTimeInterval(remaining).formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLanguage.formatLocale))
                    Text(store.running?.isPaused == false
                         ? "Keep working and you'll reach today's goal at \(finish)."
                         : "Start now and you'll reach today's goal at \(finish).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Set daily hours in Your plan below to track today's goal.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16).card(palette)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("YOUR PLAN")
            Picker("Workdays per week", selection: $workdays) {
                Text("Choose").tag(0)
                ForEach(1...7, id: \.self) { count in Text("\(count) days").tag(count) }
            }
            .accessibilityIdentifier("pace.workdays")
            Text("How many days do you usually work each week?")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            GoalHoursField(title: "Monthly", hours: $monthlyGoal, step: 5, maximum: 744,
                           pendingFocus: .constant(false), field: .monthly, focusedField: $focusedGoal)
                .id(GoalField.monthly)
            GoalHoursField(title: "Daily", hours: $dailyGoal, step: 0.5, maximum: 24,
                           pendingFocus: $pendingDailyFocus, field: .daily, focusedField: $focusedGoal)
                .id(GoalField.daily)
            Text("Use hours, e.g. 7.5. Zero turns a goal off.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
    }

    private func recommendation(_ plan: MonthlyWorkPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("FROM TODAY")
            metric("Estimated workdays left", "≈ \(plan.estimatedWorkdaysRemaining)")
            if let required = plan.requiredDaily, !plan.reached {
                metric("Needed per workday", DurationText.compact(required))
                metric("Worked today", DurationText.compact(plan.todayWorked))
                if let remaining = plan.todayRemaining {
                    metric("More today to match the plan", DurationText.compact(remaining))
                }
                if required > 24 * 3600 {
                    Text("Over 24h/workday needed. Adjust your plan.")
                        .font(.subheadline)
                } else if let suggestion = plan.suggestedDailyHours {
                    if plan.dailyGoalTooLow {
                        Text("Aim for \(DurationText.compact(suggestion * 3600)) per workday.")
                            .font(.subheadline)
                        Button("Set daily goal to \(DurationText.compact(suggestion * 3600))") {
                            focusedGoal = nil
                            dailyGoal = suggestion
                            everConfigured = true
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("pace.applySuggestion")
                    } else {
                        Text("Your daily goal keeps you on pace.")
                            .font(.subheadline)
                    }
                    if required > 12 * 3600 {
                        Text("A demanding pace. Consider adjusting your goal.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Monthly mission complete.").font(.subheadline)
            }
            Text("Estimates use \(plan.workdaysPerWeek) workdays/week and include today.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
    }

    private func forecast(_ plan: MonthlyWorkPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("MONTH-END OUTLOOK")
            if let projected = plan.projectedMonthEnd {
                metric("At your recent pace", DurationText.compact(projected))
                if !plan.reached {
                    Text(projected >= plan.target
                         ? "Keep this pace and you're on track to reach your monthly goal."
                         : "At this pace, you may finish \(DurationText.compact(plan.target - projected)) below your goal. The daily plan above shows how to catch up.")
                        .font(.subheadline)
                }
                if let average = plan.recentDailyAverage {
                    metric("Recent average / workday", DurationText.compact(average))
                }
            } else {
                Text("Your forecast will appear after your first full day of recorded work.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let planned = plan.plannedMonthEnd {
                metric("At your saved daily goal", DurationText.compact(planned))
            }
            outlookChart(plan)
            Text("Solid: actual total · dashed: recent pace · dotted: monthly goal")
                .font(.caption2).foregroundStyle(.secondary)
            Text(plan.sampleDays > 0
                 ? "Uses \(plan.sampleDays) completed calendar days before today, including days without work, adjusted to your \(plan.workdaysPerWeek)-day week. \(plan.sampleDays < 7 ? String(localized: "Early estimate: a full week will be more representative.", bundle: .app) + " " : "")The forecast is an estimate, not a guarantee."
                 : "Today's work counts toward progress, but an unfinished day isn't used to establish your average.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
    }

    private func outlookChart(_ plan: MonthlyWorkPlan) -> some View {
        let end = Calendar.current.date(byAdding: .day, value: -1, to: plan.month.end)!
        return Chart {
            ForEach(plan.days) { day in
                LineMark(x: .value("Day", day.date), y: .value("Hours", day.cumulative / 3600),
                         series: .value("Series", "Actual"))
                    .foregroundStyle(palette.accent).lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            PointMark(x: .value("Today", plan.today), y: .value("Hours", plan.monthWorked / 3600))
                .foregroundStyle(palette.accent)
            if let projected = plan.projectedMonthEnd {
                LineMark(x: .value("Day", plan.today), y: .value("Hours", plan.monthWorked / 3600),
                         series: .value("Series", "Forecast"))
                    .foregroundStyle(palette.secondary).lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                LineMark(x: .value("Day", end), y: .value("Hours", projected / 3600),
                         series: .value("Series", "Forecast"))
                    .foregroundStyle(palette.secondary).lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
            RuleMark(y: .value("Monthly goal", plan.target / 3600))
                .foregroundStyle(palette.accent.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }
        .chartXScale(domain: plan.month.start...max(end, plan.month.start.addingTimeInterval(1)))
        .chartYScale(domain: 0...max(1, max(plan.target, max(plan.monthWorked, plan.projectedMonthEnd ?? 0)) / 3600 * 1.08))
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day()) } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .frame(height: 190)
        .accessibilityLabel("Monthly progress and projected hours")
    }

    private func dailyChart(_ plan: MonthlyWorkPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("DAILY HOURS")
            Chart {
                ForEach(plan.days) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", day.worked / 3600))
                        .foregroundStyle(palette.accent.opacity(day.date == plan.today ? 1 : 0.55))
                }
                if plan.dailyTarget > 0 {
                    RuleMark(y: .value("Daily goal", plan.dailyTarget / 3600))
                        .foregroundStyle(palette.secondary).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
            .frame(height: 140)
            .accessibilityLabel("Daily worked hours compared with your saved daily goal")
            Text("Bars show actual hours. The dashed line is your saved daily goal. Today is still in progress.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
    }

    private func metric(_ title: LocalizedStringKey, _ value: String) -> some View {
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
        .font(.subheadline).accessibilityElement(children: .combine)
    }

    private func markConfigured() {
        if dailyGoal > 0 || monthlyGoal > 0 { everConfigured = true }
    }
}
