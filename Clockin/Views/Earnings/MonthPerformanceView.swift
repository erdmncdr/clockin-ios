import Charts
import SwiftUI

struct MonthPerformanceView: View {
    @Environment(\.palette) private var palette
    let performance: MonthPerformance
    let interval: DateInterval
    let currencyCode: String
    let latestRate: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(performance.isCurrent ? "THIS MONTH SO FAR" : "MONTH SUMMARY")
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            metric("Worked", DurationText.compact(performance.duration))
            metric("Earned", performance.earned.money(code: currencyCode))
            if currencyCode == "USD", let latestRate {
                Text("\((performance.earned * latestRate).money(code: "TRY")) · current rate")
                    .font(.caption).foregroundStyle(.secondary)
            }
            metric("Worked days", "\(performance.workedDays)")
            metric("Per worked day", DurationText.compact(performance.averageDuration))
            metric("Earnings / worked day", performance.averageEarnings.money(code: currencyCode))
            if let goal = performance.goal {
                Divider()
                metric("Monthly goal", (goal.worked / goal.target).formatted(.percent.precision(.fractionLength(0))))
                SwiftUI.ProgressView(value: goal.fraction)
                    .accessibilityLabel("Monthly goal progress")
                Text("\(DurationText.compact(goal.remaining)) remaining of \(DurationText.compact(goal.target))")
                    .font(.caption).foregroundStyle(.secondary)
                if performance.isCurrent {
                    if let projected = performance.projectedDuration {
                        metric("Projected month end", DurationText.compact(projected))
                        Text("Uses the last 7 days of completed work, averaged over 7 days, for the days after today.")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("No completed work in the last 7 days to project from.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !performance.isCurrent {
                    Text("Compared with your current monthly goal.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(comparison)
                .font(.caption.weight(.semibold))
                .foregroundStyle(performance.difference >= 0 ? palette.accent : .secondary)
            if performance.duration > 0 || performance.goal != nil {
                cumulativeChart
                Text("Hours: daily bars, cumulative solid line\(performance.goal == nil ? "." : ", monthly goal dashed line.")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var comparison: String {
        let previous = performance.comparisonInterval
        let last = Calendar.current.date(byAdding: .day, value: -1, to: previous.end)!
        let sign = performance.difference >= 0 ? "+" : "-"
        return "\(sign)\(DurationText.compact(abs(performance.difference))) vs \(previous.start.formatted(.dateTime.month(.abbreviated).day())) to \(last.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private var cumulativeChart: some View {
        Chart {
            ForEach(performance.cumulative) { point in
                BarMark(x: .value("Day", point.day, unit: .day), y: .value("Hours", point.daily / 3600))
                    .foregroundStyle(palette.accent.opacity(0.25))
                    .accessibilityLabel(point.day.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("Daily work: \(DurationText.compact(point.daily))")
                LineMark(x: .value("Day", point.day, unit: .day), y: .value("Hours", point.cumulative / 3600),
                         series: .value("Series", "Cumulative"))
                    .foregroundStyle(palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .accessibilityLabel("Cumulative through \(point.day.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityValue(DurationText.compact(point.cumulative))
            }
            ForEach(performance.target) { point in
                LineMark(x: .value("Day", point.day, unit: .day), y: .value("Hours", point.duration / 3600),
                         series: .value("Series", "Goal"))
                    .foregroundStyle(palette.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .accessibilityLabel("Goal pace on \(point.day.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityValue(DurationText.compact(point.duration))
            }
        }
        .chartXScale(domain: interval.start...interval.end)
        .chartYScale(domain: 0...max(1, max(performance.duration, performance.goal?.target ?? 0) / 3600))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day()) } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .frame(height: 160)
        .accessibilityLabel("Monthly hours and goal pace")
    }

    private func metric(_ title: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
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
