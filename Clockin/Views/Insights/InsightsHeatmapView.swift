import SwiftUI

@MainActor
struct InsightsHeatmapView: View {
    @Environment(\.palette) private var palette
    let daily: [Date: TimeInterval]
    let earnings: [Date: Double]
    let currencyCode: String
    let now: Date

    @AppStorage("Clockin.InsightsHeatmapDayRange") private var range = 12
    @AppStorage("Clockin.InsightsHeatmapGrouping") private var grouping: InsightsGrouping = .day
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDay: Date?

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("WORK HEATMAP")
            Picker("Heatmap grouping", selection: $grouping) {
                ForEach(InsightsGrouping.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Group {
                if grouping == .day {
                    dayContent
                } else {
                    InsightsAggregateHeatmapView(periods: InsightsPeriods.buckets(daily: daily, earnings: earnings,
                        grouping: grouping, now: now, calendar: calendar), grouping: grouping, currencyCode: currencyCode)
                        .id(grouping)
                }
            }
            // Gorunum degisince icerik kesilip yenisi aniden belirmesin;
            // kisa bir solma, hangi modda oldugunu goz kaybetmeden gosterir.
            .transition(.opacity)
            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: grouping)
        }
        .padding(16).card(palette)
        .sensoryFeedback(.selection, trigger: grouping)
        .transaction { if reduceMotion { $0.animation = nil } }
    }

    private var dayContent: some View {
        let today = calendar.startOfDay(for: now)
        let weeks = InsightsPeriods.dayWeeks(daily: daily, now: now, range: range, calendar: calendar)
        let selected = selectedDay ?? today

        return VStack(alignment: .leading, spacing: 12) {
            Picker("Heatmap range", selection: $range) {
                Text("4 weeks").tag(4)
                Text("12 weeks").tag(12)
                Text("All").tag(0)
            }
            .pickerStyle(.segmented)
            Text("Each square is a day. Swipe across and tap a day for details.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Start") {
                            if let first = weeks.first { proxy.scrollTo(first, anchor: .leading) }
                        }
                        Spacer()
                        Button("Today") {
                            selectedDay = today
                            if let last = weeks.last { proxy.scrollTo(last, anchor: .trailing) }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    HStack(alignment: .top, spacing: 4) {
                        VStack(spacing: 0) {
                            // Genislik verilmezse bos alan yatayda yayilip satirin
                            // yarisini kapliyor, izgara sag yariya sikisiyordu.
                            Color.clear.frame(width: 30, height: 36)
                            ForEach(0..<7, id: \.self) { index in
                                Text(weekdayLabel(index))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, height: 44)
                            }
                        }
                        .accessibilityHidden(true)
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 0) {
                                ForEach(weeks, id: \.self) { week in
                                    VStack(spacing: 0) {
                                        Text(week.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption2).foregroundStyle(.secondary)
                                            .frame(width: 44, height: 36)
                                            .multilineTextAlignment(.center)
                                        ForEach(0..<7, id: \.self) { offset in
                                            if let day = calendar.date(byAdding: .day, value: offset, to: week) {
                                                dayCell(day, today: today, selected: selected)
                                            }
                                        }
                                    }
                                    .id(week)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .frame(height: 352)
                    }
                }
                .onAppear {
                    if let last = weeks.last { proxy.scrollTo(last, anchor: .trailing) }
                }
                .onChange(of: range) { _, _ in
                    selectedDay = nil
                    if let last = weeks.last { proxy.scrollTo(last, anchor: .trailing) }
                }
            }
            HStack(spacing: 5) {
                Text("0h")
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatColor(hours: [0, 0.5, 2, 4, 8][index]))
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
                Text("8h+")
            }
            .font(.caption).foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 5) {
                Text(selected.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.subheadline.weight(.semibold))
                Text("\(DurationText.compact(daily[selected, default: 0])) • \(earnings[selected, default: 0].money(code: currencyCode))")
                    .font(.subheadline).monospacedDigit().foregroundStyle(palette.accent)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: selected)
                if daily[selected, default: 0] == 0 {
                    Text("No time logged on this day.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private func dayCell(_ day: Date, today: Date, selected: Date) -> some View {
        let duration = daily[day, default: 0]
        return Button { selectedDay = day } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(day > today ? Color.clear : heatColor(hours: duration / 3600))
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(day == selected ? palette.accent : palette.surfaceStroke,
                                lineWidth: day == selected ? 2 : 1)
                }
                .overlay {
                    if day == today {
                        Circle().fill(palette.actionForeground).frame(width: 5, height: 5)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(day > today)
        .opacity(day > today ? 0 : 1)
        .accessibilityHidden(day > today)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
        .accessibilityValue("\(DurationText.compact(duration)), \(earnings[day, default: 0].money(code: currencyCode))\(day == selected ? ", selected" : "")")
        .accessibilityHint("Shows daily details below the grid")
    }

    private func heatColor(hours: Double) -> Color {
        hours > 0 ? palette.accent.opacity(InsightsPeriods.heatIntensity(hours)) : palette.surfaceStroke
    }

    private func weekdayLabel(_ index: Int) -> String {
        let symbols = calendar.shortWeekdaySymbols
        return symbols[(index + 1) % 7]
    }

}
