import SwiftUI

@MainActor
struct InsightsView: View {
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var shareSnapshot: StatsShareSnapshot?

    var body: some View {
        Group {
            if let stats = celebrations.snapshot {
                reportsContent(stats, now: celebrations.snapshotDate)
            }
        }
        .background(palette.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareSnapshot = StatsShareSnapshot(store: store, dailyGoal: dailyGoalHours,
                                                       monthlyGoal: monthlyGoalHours)
                } label: { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Share stats")
            }
        }
        .celebrationBlocked(by: shareSnapshot != nil)
        .sheet(item: $shareSnapshot) { snapshot in
            ShareStatsView(snapshot: snapshot)
        }
    }

    private func reportsContent(_ stats: InsightsSnapshot, now: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InsightsHeatmapView(daily: stats.daily, earnings: stats.dailyEarnings,
                                    currencyCode: store.currencyCode, now: now)
                totalsCard(stats)
                reportsCard(stats)
            }
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func totalsCard(_ stats: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("YOUR RHYTHM")
            metric("Last 7 days", value: DurationText.compact(stats.recentWeek))
            metric("Previous 7 days", value: DurationText.compact(stats.previousWeek))
            if stats.previousWeek > 0 {
                let change = (stats.recentWeek - stats.previousWeek) / stats.previousWeek
                metric("Change", value: change.formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.formatLocale)))
            }
            Divider()
            metric("This month", value: DurationText.compact(stats.monthDuration))
            metric("Month earnings", value: stats.monthEarnings.money(code: store.currencyCode))
            metric("All time", value: DurationText.compact(stats.totalDuration))
            metric("Total earnings", value: stats.totalEarnings.money(code: store.currencyCode))
            metric("Active days", value: stats.daily.count.formatted(.number.locale(AppLanguage.formatLocale)))
            metric("Longest completed session", value: DurationText.compact(stats.longestSession))
            Text("Time and earnings belong to the day a session started, including sessions that cross midnight.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
    }

    private func reportsCard(_ stats: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("REPORTS & RECORDS")
            metric("Average completed session", value: DurationText.compact(stats.averageSession))
            metric("Best weekday", value: stats.bestWeekday.map { AppLanguage.calendar.weekdaySymbols[$0 - 1] } ?? String(localized: "No sessions", bundle: .app))
            metric("Best start hour", value: stats.bestStartHour.map { String(format: "%02d:00", $0) } ?? String(localized: "No sessions", bundle: .app))
            metric("Average earnings / hour", value: stats.hourlyEarnings.money(code: store.currencyCode))
            metric("Last 30 days", value: DurationText.compact(stats.recentMonth))
            metric("Preceding 30 days", value: DurationText.compact(stats.previousMonth))
            metric("30-day trend", value: String(format: "%+.0f%%", stats.monthTrend * 100))
            Divider()
            metric("Best completed day", value: DurationText.compact(stats.bestDayDuration))
            if let day = stats.bestDay {
                Text(day.formatted(.dateTime.locale(AppLanguage.formatLocale).weekday(.wide).month(.wide).day().year()))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Reports use completed sessions. Earnings per hour also includes active work. Best weekday and start hour use total duration; ties choose the first calendar weekday or earliest hour. The trend compares the last 30 calendar days, today included, with the 30 before them.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).card(palette)
    }

    private func metric(_ title: LocalizedStringKey, value: String) -> some View {
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
        collectionBadges = PurchaseBadges.make(ledger: WardrobeStore.shared.ledger)
    }
}
