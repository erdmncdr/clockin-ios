import AppIntents
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: ClockinSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (ClockinSnapshot.load() ?? .empty)
        completion(TodayEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let entry = TodayEntry(date: now, snapshot: ClockinSnapshot.load() ?? .empty)
        // Sure metni kendisi sayar. Kazanc ve gun donumu icin ceyrek saatte
        // bir yenilenir; uygulama her degisiklikte ayrica yeniden yukletir.
        let next = now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's time and earnings, with the running timer.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    /// Widget uygulamanin `UserDefaults`'una erisemiyor; tema sabit.
    private let palette = ClockinThemeChoice.carbon.palette

    private var snapshot: ClockinSnapshot { entry.snapshot }
    private var running: RunningSession? { snapshot.running }
    private var isEarning: Bool { running?.isPaused == false }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: lockScreen
            default: homeScreen
            }
        }
        .containerBackground(for: .widget) { palette.background }
    }

    private var homeScreen: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                status
                Spacer(minLength: 0)
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
                todayDuration
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.white)
                Text(snapshot.todayEarnings(at: entry.date).money(code: snapshot.currencyCode))
                    .font(.headline)
                    .foregroundStyle(palette.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if family == .systemMedium {
                actionButton
            }
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(isEarning ? "Working" : "Today", systemImage: isEarning ? "bolt.fill" : "clock")
                .font(.caption.weight(.semibold))
            todayDuration
                .font(.headline)
                .monospacedDigit()
            Text(snapshot.todayEarnings(at: entry.date).money(code: snapshot.currencyCode))
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Calisirken sistem saati kendisi ilerletir; widget her saniye
    /// yenilenemedigi icin tek yol bu.
    @ViewBuilder private var todayDuration: some View {
        let total = snapshot.todayDuration(at: entry.date)
        if isEarning, snapshot.runningCountsToday(at: entry.date) {
            let start = entry.date.addingTimeInterval(-total)
            Text(timerInterval: start...start.addingTimeInterval(7 * 86_400), countsDown: false)
        } else {
            Text(DurationText.compact(total))
        }
    }

    private var status: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(running == nil ? Color.gray : (isEarning ? palette.accent : .orange))
                .frame(width: 7, height: 7)
            Text(running == nil ? "READY" : (isEarning ? "WORKING" : "PAUSED"))
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder private var actionButton: some View {
        if running == nil {
            Button(intent: ClockInIntent()) {
                Label("Clock in", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.actionForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Button(intent: ClockOutIntent()) {
                Label("Clock out", systemImage: "stop.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.red.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

extension ClockinSnapshot {
    /// Widget galerisinde gosterilen ornek.
    static let placeholder = ClockinSnapshot(
        day: Calendar.current.startOfDay(for: .now), completedToday: 3 * 3600 + 25 * 60,
        earnedToday: 85.42, running: nil, hourlyRate: 25, currencyCode: "USD"
    )
}
