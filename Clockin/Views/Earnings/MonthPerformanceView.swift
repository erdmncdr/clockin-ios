import Charts
import SwiftUI

struct MonthPerformanceView: View {
    @Environment(\.palette) private var palette
    let performance: MonthPerformance
    let interval: DateInterval
    let currencyCode: String
    let showTRY: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(performance.isCurrent ? "THIS MONTH SO FAR" : "MONTH SUMMARY")
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            metric("Worked", DurationText.compact(performance.duration))
            metric("Earned", money(performance.money))
            if currencyCode == "USD", let converted = performance.money.converted {
                Text((showTRY ? performance.earned : converted).money(code: showTRY ? "USD" : "TRY"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            metric("Worked days", "\(performance.workedDays)")
            metric("Per worked day", DurationText.compact(performance.averageDuration))
            metric("Earnings / worked day", money(performance.money.divided(by: Double(max(1, performance.workedDays)))))
            if let projected = performance.projectedEarnings {
                metric("Projected earnings", money(HistoryAmount(earned: projected, converted: performance.projectedConverted)))
                Text("Uses the last 7 days of completed earnings at their historical rates for the days after today.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(comparison)
                .font(.caption.weight(.semibold))
                .foregroundStyle(performance.difference >= 0 ? palette.accent : .secondary)
            if performance.duration > 0 {
                ZStack {
                    cumulativeChart
                        .id(interval)
                        .transition(.opacity)
                }
                Text("Hours: daily bars and cumulative solid line.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func money(_ amount: HistoryAmount) -> String {
        amount.value(showTRY: showTRY).money(code: amount.code(currency: currencyCode, showTRY: showTRY))
    }

    private var comparison: String {
        let previous = performance.comparisonInterval
        let last = Calendar.current.date(byAdding: .day, value: -1, to: previous.end)!
        let sign = performance.difference >= 0 ? "+" : "-"
        return String(localized: "\(sign)\(DurationText.compact(abs(performance.difference))) vs \(previous.start.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.abbreviated).day())) to \(last.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.abbreviated).day().year()))", bundle: .app)
    }

    private var cumulativeChart: some View {
        Chart {
            ForEach(performance.cumulative) { point in
                BarMark(x: .value("Day", point.day, unit: .day), y: .value("Hours", point.daily / 3600))
                    .foregroundStyle(palette.accent.opacity(0.25))
                    .accessibilityLabel(point.day.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.formatLocale)))
                    .accessibilityValue("Daily work: \(DurationText.compact(point.daily))")
                LineMark(x: .value("Day", point.day, unit: .day), y: .value("Hours", point.cumulative / 3600),
                         series: .value("Series", "Cumulative"))
                    .foregroundStyle(palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .accessibilityLabel("Cumulative through \(point.day.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.formatLocale)))")
                    .accessibilityValue(DurationText.compact(point.cumulative))
            }

        }
        .chartXScale(domain: EarningsChartAxis.dateDomain(interval))
        .chartYScale(domain: 0...max(1, performance.duration / 3600))
        .chartXAxis {
            AxisMarks(values: EarningsChartAxis.dayMarks(in: interval)) { _ in
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .frame(height: 160)
        .accessibilityLabel("Monthly worked hours")
    }

    private func metric(_ title: LocalizedStringKey, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(value).fontWeight(.semibold).monospacedDigit()
                    .contentTransition(.numericText())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(.secondary)
                Text(value).fontWeight(.semibold).monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
