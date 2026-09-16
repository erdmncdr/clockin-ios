import Charts
import SwiftUI

struct EarningsChartView: View {
    @Environment(\.palette) private var palette
    let snapshot: EarningsSnapshot
    let range: EarningsRange
    let currencyCode: String
    let latestRate: Double?
    let loadingRates: Bool
    let hasAnySessions: Bool
    @Binding var showTRY: Bool
    let pageDirection: Int
    let onPage: (Int) -> Void
    @State private var selectedDate: Date?
    @ScaledMetric(relativeTo: .caption) private var axisTopPadding = 10.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var converting: Bool { showTRY && currencyCode == "USD" }
    private var displayCode: String { converting ? "TRY" : currencyCode }
    private var selected: EarningsDay? {
        guard let selectedDate else { return nil }
        return snapshot.points.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }
    private var chartInterval: DateInterval {
        let interval = snapshot.interval
        let start = range == .all ? (snapshot.points.first?.day ?? Calendar.current.startOfDay(for: interval.end.addingTimeInterval(-1))) : interval.start
        return DateInterval(start: start, end: interval.end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERIOD EARNINGS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Text(snapshot.earned.money(code: currencyCode))
                        .font(.title2.bold()).monospacedDigit()
                        .contentTransition(.numericText())
                    if currencyCode == "USD", let latestRate {
                        Text((snapshot.earned * latestRate).money(code: "TRY") + " · current rate")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(DurationText.compact(snapshot.duration)).font(.headline)
                        .contentTransition(.numericText())
                    Text("\(snapshot.sessions.count) completed").font(.caption)
                        .contentTransition(.numericText())
                    if snapshot.includesActive { Text("+ active session").font(.caption2) }
                }
                .foregroundStyle(.secondary)
            }
            HStack {
                Text(range == .sixMonths ? "MONTHLY EARNINGS" : "DAILY EARNINGS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                if currencyCode == "USD" {
                    Picker("Chart currency", selection: $showTRY) {
                        Text("USD").tag(false)
                        Text("TRY").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                } else {
                    Text(currencyCode).font(.caption.bold())
                }
            }
            ZStack {
                Group {
                    if snapshot.points.isEmpty {
                        Text(hasAnySessions ? "No work in this period." : "No sessions yet. Clock in or add a past entry.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .overlay {
                                ChartInteraction(pageable: range != .all, onTap: { _ in }, onPage: onPage)
                                    .accessibilityHidden(true)
                            }
                    } else {
                        chart
                    }
                }
                .id(snapshot.interval.start)
                .transition(.asymmetric(insertion: .move(edge: pageDirection < 0 ? .leading : .trailing),
                                        removal: .move(edge: pageDirection < 0 ? .trailing : .leading)))
            }
            .clipped()
            if !snapshot.points.isEmpty {
                if converting {
                    if let total = snapshot.converted {
                        Text("Historical total: \(total.money(code: "TRY"))").font(.caption.weight(.semibold))
                    } else {
                        Text(loadingRates ? "Fetching historical rates…" : (range == .sixMonths
                            ? "Some historical rates are unavailable. Months with missing rates are not plotted in TRY."
                            : "Some historical rates are unavailable. Missing days are not plotted in TRY."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Text("Uses each calendar day's USD/TRY rate, or the nearest earlier available rate.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if range == .sixMonths, let bar = selectedMonth {
                    Text("\(bar.day.formatted(.dateTime.month(.wide).year())) · \(DurationText.compact(bar.duration)) · \(bar.earned.money(code: currencyCode))")
                        .font(.caption).monospacedDigit()
                    if currencyCode == "USD", let converted = bar.converted {
                        Text("Historical total: \(converted.money(code: "TRY"))").font(.caption)
                    }
                } else if let point = selected {
                    detail(point)
                } else if let selectedDate {
                    Text(range == .sixMonths
                        ? "No work in \(selectedDate.formatted(.dateTime.month(.wide).year()))."
                        : "No work on \(selectedDate.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(range == .sixMonths ? "Tap a month in the chart to inspect it." : "Tap a day in the chart to inspect it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if range != .month { averages }
                Text("Overnight sessions count toward their start date. Active work updates every minute.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: range)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: showTRY)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDate) { _, new in new != nil }
        .onChange(of: snapshot.interval) { _, _ in selectedDate = nil }
        .onChange(of: range) { _, _ in selectedDate = nil }
        .onChange(of: currencyCode) { _, _ in selectedDate = nil }
    }

    /// Donem ortalamalari. Takvim gunune bolunur, cunku soru "gunde ne kadar"
    /// ve calisilmayan gunler de o sorunun parcasi; calisilan gunlerin
    /// ortalamasi ayrica verilir.
    private var averages: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AVERAGES · \(snapshot.calendarDays) CALENDAR \(snapshot.calendarDays == 1 ? "DAY" : "DAYS")")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                averageChip("Daily", DurationText.compact(snapshot.dailyAverage))
                averageChip("Weekly", DurationText.compact(snapshot.weeklyAverage))
                averageChip("Monthly", DurationText.compact(snapshot.monthlyAverage))
                averageChip("Active days", "\(snapshot.activeDays)")
                averageChip("Per active day", DurationText.compact(snapshot.activeDayAverage))
            }
        }
    }

    private func averageChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7).padding(.horizontal, 9)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var selectedMonth: EarningsMonthBar? {
        guard let selectedDate else { return nil }
        return snapshot.monthlyBars().first { Calendar.current.isDate($0.day, equalTo: selectedDate, toGranularity: .month) }
    }

    private var chartMaximum: Double {
        let values = range == .sixMonths
            ? snapshot.monthlyBars().compactMap { converting ? $0.converted : $0.earned }
            : snapshot.points.compactMap { converting ? $0.converted : $0.earned }
        return EarningsChartAxis.earningsUpperBound(values.max() ?? 0)
    }

    private var chart: some View {
        Chart {
            if range == .sixMonths {
                ForEach(snapshot.monthlyBars()) { bar in
                    if let value = converting ? bar.converted : bar.earned {
                        BarMark(x: .value("Month", bar.day, unit: .month), y: .value(displayCode, value))
                            .foregroundStyle(palette.accent.gradient)
                            .cornerRadius(3)
                            .opacity(selectedMonth == nil || selectedMonth?.day == bar.day ? 1 : 0.45)
                            .accessibilityLabel(bar.day.formatted(.dateTime.month(.wide).year()))
                            .accessibilityValue("\(value.money(code: displayCode)), \(DurationText.compact(bar.duration))")
                    }
                }
            } else {
                ForEach(snapshot.points) { point in
                    if let value = converting ? point.converted : point.earned {
                        BarMark(x: .value("Day", point.day, unit: .day), y: .value(displayCode, value))
                            .foregroundStyle(palette.accent.gradient)
                            .cornerRadius(3)
                            .opacity(selected == nil || selected?.day == point.day ? 1 : 0.45)
                            .accessibilityLabel(point.day.formatted(date: .complete, time: .omitted))
                            .accessibilityValue("\(value.money(code: displayCode)), \(DurationText.compact(point.duration))")
                    }
                }
                if let selected {
                    RuleMark(x: .value("Selected day", selected.day, unit: .day))
                        .foregroundStyle(palette.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
        }
        .chartXScale(domain: EarningsChartAxis.dateDomain(chartInterval))
        .chartYScale(domain: 0...chartMaximum)
        .chartXAxis {
            if range == .sixMonths {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            } else {
                AxisMarks(values: EarningsChartAxis.dayMarks(in: chartInterval)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let frame = geometry[anchor]
                    ChartInteraction(pageable: range != .all, onTap: { location in
                        guard frame.contains(location) else { return }
                        selectedDate = proxy.value(atX: location.x - frame.minX, as: Date.self)
                    }, onPage: onPage)
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(height: 190)
        // Sayfa kirpmasi ust eksen etiketine degmesin.
        .padding(.top, axisTopPadding)
    }

    private func detail(_ point: EarningsDay) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(point.day.formatted(date: .complete, time: .omitted)).font(.subheadline.bold())
            Text("\(DurationText.compact(point.duration)) · \(point.earned.money(code: currencyCode))")
                .font(.subheadline).monospacedDigit()
            if currencyCode == "USD" {
                if let rate = point.rate, let converted = point.converted {
                    Text("\(converted.money(code: "TRY")) · 1 USD = \(rate.formatted(.number.precision(.fractionLength(3)))) TRY")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Historical rate unavailable").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
