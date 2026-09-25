import Charts
import SwiftUI

struct EarningsChartView: View {
    @Environment(\.palette) private var palette
    let snapshot: EarningsSnapshot
    let months: [EarningsMonthBar]
    let range: EarningsRange
    let currencyCode: String
    let hasAnySessions: Bool
    @Binding var showTRY: Bool
    let onPage: (Int) -> Void
    @State private var selectedDate: Date?
    @ScaledMetric(relativeTo: .caption) private var axisTopPadding = 10.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var converting: Bool { showTRY && currencyCode == "USD" }
    private var chartConverting: Bool { converting && snapshot.hasConvertedDays }
    private var displayCode: String { chartConverting ? "TRY" : currencyCode }
    private var selected: EarningsDay? {
        guard let selectedDate else { return nil }
        return snapshot.points.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }
    private var chartInterval: DateInterval {
        let interval = snapshot.interval
        let start = range == .all ? (snapshot.points.first?.day ?? Calendar.current.startOfDay(for: interval.end.addingTimeInterval(-1))) : interval.start
        return DateInterval(start: start, end: interval.end)
    }

    @State private var selectionFeedback = HapticSignal()
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // At the largest text sizes the totals stack under the earnings
            // instead of truncating both columns.
            AdaptiveTotalsStack(stacked: typeSize.isAccessibilitySize) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERIOD EARNINGS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Text(money(snapshot.money))
                        .font(.title2.bold()).monospacedDigit()
                        .contentTransition(.numericText())
                    if currencyCode == "USD", let converted = snapshot.converted {
                        Text((converting ? snapshot.earned : converted).money(code: converting ? "USD" : "TRY"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } trailing: {
                VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                    Text(DurationText.compact(snapshot.duration)).font(.headline)
                        .contentTransition(.numericText())
                    Text("\(snapshot.sessions.count) completed").font(.caption)
                        .contentTransition(.numericText())
                    if snapshot.includesActive { Text("+ active session").font(.caption2) }
                }
                .foregroundStyle(.secondary)
            }
            AdaptiveTotalsStack(stacked: typeSize.isAccessibilitySize) {
                Text(range == .sixMonths ? "MONTHLY EARNINGS" : "DAILY EARNINGS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            } trailing: {
                if currencyCode == "USD" {
                    Picker("History currency", selection: $showTRY.hapticSelection($selectionFeedback)) {
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
                .id(EarningsPeriod.PageID(range: range, interval: snapshot.interval))
                .transition(.opacity)
            }
            .clipped()
            if !snapshot.points.isEmpty {
                if converting {
                    Text("Uses each calendar day's USD/TRY rate, or the nearest earlier available rate.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if range == .sixMonths, let bar = selectedMonth {
                    Text("\(bar.day.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.wide).year())) · \(DurationText.compact(bar.duration)) · \(money(HistoryAmount(earned: bar.earned, converted: bar.converted)))")
                        .font(.caption).monospacedDigit()
                    if currencyCode == "USD", let converted = bar.converted {
                        Text((converting ? bar.earned : converted).money(code: converting ? "USD" : "TRY")).font(.caption)
                    }
                } else if let point = selected {
                    detail(point)
                } else if let selectedDate {
                    Text(range == .sixMonths
                        ? "No work in \(selectedDate.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.wide).year()))."
                        : "No work on \(selectedDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.formatLocale))).")
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
        .hapticFeedback(selectionFeedback)
        // Aralik secimi de animasyonlu; sayfalama transaction'i History'den gelir.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22),
                   value: EarningsPeriod.PageID(range: range, interval: snapshot.interval))
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: showTRY)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedDate)
        .hapticFeedback(.selection, trigger: selectedDate) { _, new in new != nil }
        .onChange(of: snapshot.interval) { _, _ in selectedDate = nil }
        .onChange(of: range) { _, _ in selectedDate = nil }
        .onChange(of: currencyCode) { _, _ in selectedDate = nil }
    }

    /// Donem ortalamalari. Takvim gunune bolunur, cunku soru "gunde ne kadar"
    /// ve calisilmayan gunler de o sorunun parcasi; calisilan gunlerin
    /// ortalamasi ayrica verilir.
    private var averages: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AVERAGES · \(snapshot.calendarDays) CALENDAR DAYS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                averageChip("Daily", DurationText.compact(snapshot.dailyAverage), money: money(snapshot.money.divided(by: Double(snapshot.calendarDays))))
                averageChip("Weekly", DurationText.compact(snapshot.weeklyAverage), money: money(snapshot.money.divided(by: Double(snapshot.calendarDays) / 7)))
                averageChip("Monthly", DurationText.compact(snapshot.monthlyAverage), money: money(snapshot.money.divided(by: Double(snapshot.calendarDays) / 30.44)))
                averageChip("Active days", "\(snapshot.activeDays)")
                averageChip("Per active day", DurationText.compact(snapshot.activeDayAverage), money: money(snapshot.money.divided(by: Double(max(1, snapshot.activeDays)))))
            }
        }
    }

    private func money(_ amount: HistoryAmount) -> String {
        amount.value(showTRY: converting).money(code: amount.code(currency: currencyCode, showTRY: converting))
    }

    private func averageChip(_ title: LocalizedStringKey, _ value: String, money: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                .contentTransition(.numericText())
            if let money {
                Text(money).font(.caption).monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7).padding(.horizontal, 9)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var selectedMonth: EarningsMonthBar? {
        guard let selectedDate else { return nil }
        return months.first { Calendar.current.isDate($0.day, equalTo: selectedDate, toGranularity: .month) }
    }

    private var chartMaximum: Double {
        let values = range == .sixMonths
            ? months.compactMap { chartConverting ? $0.converted : $0.earned }
            : snapshot.points.compactMap { chartConverting ? $0.converted : $0.earned }
        return EarningsChartAxis.earningsUpperBound(values.max() ?? 0)
    }

    private var chart: some View {
        Chart {
            if range == .sixMonths {
                ForEach(months) { bar in
                    if let value = chartConverting ? bar.converted : bar.earned {
                        BarMark(x: .value("Month", bar.day, unit: .month), y: .value(displayCode, value))
                            .foregroundStyle(palette.accent.gradient)
                            .cornerRadius(3)
                            .opacity(selectedMonth == nil || selectedMonth?.day == bar.day ? 1 : 0.45)
                            .accessibilityLabel(bar.day.formatted(.dateTime.locale(AppLanguage.formatLocale).month(.wide).year()))
                            .accessibilityValue("\(value.money(code: displayCode)), \(DurationText.compact(bar.duration))")
                    }
                }
            } else {
                ForEach(snapshot.points) { point in
                    if let value = chartConverting ? point.converted : point.earned {
                        BarMark(x: .value("Day", point.day, unit: .day), y: .value(displayCode, value))
                            .foregroundStyle(palette.accent.gradient)
                            .cornerRadius(3)
                            .opacity(selected == nil || selected?.day == point.day ? 1 : 0.45)
                            .accessibilityLabel(point.day.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: AppLanguage.formatLocale)))
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
            Text(point.day.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: AppLanguage.formatLocale))).font(.subheadline.bold())
            Text("\(DurationText.compact(point.duration)) · \(money(HistoryAmount(earned: point.earned, converted: point.converted)))")
                .font(.subheadline).monospacedDigit()
            if currencyCode == "USD", let converted = point.converted {
                Text((converting ? point.earned : converted).money(code: converting ? "USD" : "TRY"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Two columns side by side, or one under the other.
private struct AdaptiveTotalsStack<Leading: View, Trailing: View>: View {
    let stacked: Bool
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 8) { leading; trailing }
        } else {
            HStack(alignment: .top) { leading; Spacer(minLength: 4); trailing }
        }
    }
}
