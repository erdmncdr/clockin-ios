import SwiftUI

@MainActor
struct InsightsAggregateHeatmapView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    let periods: [InsightsPeriod]
    let grouping: InsightsGrouping
    let currencyCode: String
    @State private var selectedStart: Date?

    var body: some View {
        let selected = periods.first { $0.start == selectedStart } ?? periods.last
        VStack(alignment: .leading, spacing: 12) {
            Text("Each cell is a whole calendar \(grouping == .week ? "week, starting Monday" : "month"). Color shows relative earnings across your archive.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                VStack(spacing: 8) {
                    HStack {
                        Button("Start") {
                            if let first = periods.first { proxy.scrollTo(first.id, anchor: .leading) }
                        }
                        Spacer()
                        Button("Today") {
                            selectedStart = periods.last?.start
                            if let last = periods.last { proxy.scrollTo(last.id, anchor: .trailing) }
                        }
                    }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 8) {
                            ForEach(periods) { period in
                                periodCell(period, selected: selected?.id == period.id).id(period.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onAppear {
                    if let last = periods.last { proxy.scrollTo(last.id, anchor: .trailing) }
                }
            }
            Text("Less earnings → More earnings")
                .font(.caption).foregroundStyle(.secondary)
            if let selected {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(title(selected)).font(.subheadline.weight(.semibold))
                    Text("\(DurationText.compact(selected.duration)) • \(selected.earnings.money(code: currencyCode))")
                        .contentTransition(.numericText())
                        .animation(.snappy, value: selected.id)
                        .font(.subheadline).monospacedDigit().foregroundStyle(palette.accent)
                    if currencyCode == "USD" {
                        if let conversion = selected.conversion(currencyCode: currencyCode,
                            startRate: exchangeRates.rate(onCalendarDay: selected.start), latestRate: exchangeRates.latestRate) {
                            Text("\(conversion.earnings.money(code: "TRY")) • 1 USD = \(conversion.rate.formatted(.number.precision(.fractionLength(3)))) TRY")
                            Text(conversion.usedLatest ? "Latest rate fallback applied to the whole period." : "Period start rate applied to the whole period.")
                        } else {
                            Text("TRY rate unavailable.")
                        }
                    }
                    if selected.duration == 0 { Text("No time logged in this period.") }
                }
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
        .hapticFeedback(.selection, trigger: selectedStart) { _, new in new != nil }
    }

    private func title(_ period: InsightsPeriod) -> String {
        if grouping == .month { return period.start.formatted(.dateTime.month(.wide).year()) }
        return "Week of \(period.start.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private func periodCell(_ period: InsightsPeriod, selected: Bool) -> some View {
        Button { selectedStart = period.start } label: {
            VStack(spacing: 6) {
                Text(grouping == .month
                     ? period.start.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
                     : period.start.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2).foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 6)
                    .fill(period.intensity > 0 ? palette.accent.opacity(period.intensity) : palette.surfaceStroke)
                    .frame(height: 52)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selected ? palette.accent : palette.surfaceStroke, lineWidth: selected ? 2 : 1)
                    }
                Text(DurationText.compact(period.duration)).font(.caption.weight(.semibold))
                Text(period.earnings.money(code: currencyCode, maxFractionDigits: 0)).font(.caption2)
            }
            .frame(width: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .buttonPressHaptic(false)
        .accessibilityLabel(title(period))
        .accessibilityValue("\(DurationText.compact(period.duration)), \(period.earnings.money(code: currencyCode))\(selected ? ", selected" : "")")
        .accessibilityHint("Shows period hours, earnings and available conversion below the grid")
    }
}
