import Charts
import SwiftUI

struct EarningsChartView: View {
    @Environment(\.palette) private var palette
    let snapshot: EarningsSnapshot
    let range: EarningsRange
    let currencyCode: String
    let now: Date
    let latestRate: Double?
    let loadingRates: Bool
    let hasAnySessions: Bool
    @Binding var showTRY: Bool
    @State private var selectedDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var converting: Bool { showTRY && currencyCode == "USD" }
    private var displayCode: String { converting ? "TRY" : currencyCode }
    private var selected: EarningsDay? {
        guard let selectedDate else { return nil }
        return snapshot.points.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }
    private var domain: ClosedRange<Date> {
        let interval = range.interval(at: now)
        let start = range == .all ? (snapshot.points.first?.day ?? Calendar.current.startOfDay(for: now)) : interval.start
        return start...interval.end
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
                        Text("≈ " + (snapshot.earned * latestRate).money(code: "TRY") + " · current rate")
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
                Text("DAILY EARNINGS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
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
            if snapshot.points.isEmpty {
                // Hic kaydi olmayana "daha genis bir donem sec" demek yanlis
                // yol gosteriyor: ALL zaten en genisi.
                if hasAnySessions {
                    ContentUnavailableView("No work in this period", systemImage: "chart.bar.xaxis",
                        description: Text("Choose a wider period or add a past entry."))
                } else {
                    ContentUnavailableView("No sessions yet", systemImage: "clock",
                        description: Text("Clock in or add a past entry to see it here."))
                }
            } else {
                chart
                if converting {
                    if let total = snapshot.converted {
                        Text("Historical total: \(total.money(code: "TRY"))").font(.caption.weight(.semibold))
                    } else {
                        Text(loadingRates ? "Fetching historical rates…" : "Some historical rates are unavailable. Missing days are not plotted in TRY.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Text("Uses each calendar day's USD/TRY rate, or the nearest earlier available rate.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let point = selected {
                    detail(point)
                } else if let selectedDate {
                    Text("No work on \(selectedDate.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Tap a day in the chart to inspect it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                averages
                Text("Overnight sessions count toward their start date. Active work updates every minute.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        // Donem ya da para birimi degisince sayilar yuvarlanarak, cubuklar
        // yeni yuksekliklerine kayarak gecsin; aniden degisen bir grafikte
        // neyin arttigi okunmuyor.
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: range)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: showTRY)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDate) { _, new in new != nil }
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

    private var chart: some View {
        Chart {
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
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...max(1, snapshot.points.compactMap { converting ? $0.converted : $0.earned }.max() ?? 1))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        // Secim dokunmayla yapilir, surukleyerek degil. Burada once
        // `minimumDistance: 0` olan bir DragGesture vardi; grafigin uzerinden
        // asagi kaydirmaya calisinca liste kaymiyor, parmagin gectigi gunler
        // seciliyordu. Grafik listenin basinda durdugu icin gecmisi okumanin
        // dogal yolunu kapatiyordu. Dokunma jesti kaydirmayla yarismaz:
        // parmak kayarsa listeye birakir.
        //
        // `chartXSelection` tek basina liste satiri icinde dokunmayi almiyor,
        // bu yuzden secim acikca buradan besleniyor.
        .chartXSelection(value: $selectedDate)
        .chartGesture { proxy in
            SpatialTapGesture().onEnded { proxy.selectXValue(at: $0.location.x) }
        }
        .frame(height: 190)
    }

    private func detail(_ point: EarningsDay) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(point.day.formatted(date: .complete, time: .omitted)).font(.subheadline.bold())
            Text("\(DurationText.compact(point.duration)) · \(point.earned.money(code: currencyCode))")
                .font(.subheadline).monospacedDigit()
            if currencyCode == "USD" {
                if let rate = point.rate, let converted = point.converted {
                    Text("≈ \(converted.money(code: "TRY")) · 1 USD = \(rate.formatted(.number.precision(.fractionLength(3)))) TRY")
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
