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
        .description("The current session and today's time and earnings.")
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
            case .systemMedium: mediumLayout
            default: smallLayout
            }
        }
        .containerBackground(for: .widget) { palette.background }
    }

    /// Orta boy: olculer yan yana, dugmeler altta. Olculer ust uste ve
    /// dugmeler saga dizildiginde ortada bos bir sutun kaliyordu.
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            status
            HStack(alignment: .top, spacing: 12) {
                if let running {
                    sessionMetric(running, value: .system(.title3, design: .rounded).weight(.semibold),
                                  money: .subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                todayMetric(value: .system(.title3, design: .rounded).weight(.semibold),
                            money: .subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            actionButtons
        }
    }

    /// Kucuk boy: yan yana sigmiyor, dugme de yok; olculer ust uste.
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            status
            Spacer(minLength: 0)
            if let running {
                sessionMetric(running, value: .system(.headline, design: .rounded).weight(.semibold),
                              money: .caption.weight(.semibold))
                todayMetric(value: .system(.headline, design: .rounded).weight(.semibold),
                            money: .caption.weight(.semibold))
            } else {
                todayMetric(value: .system(.title2, design: .rounded).weight(.semibold), money: .headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func sessionMetric(_ running: RunningSession, value: Font, money: Font) -> some View {
        let elapsed = running.elapsed(at: entry.date)
        return metric("SESSION", duration: liveDuration(elapsed, counts: isEarning),
                      earnings: elapsed / 3600 * snapshot.hourlyRate, value: value, money: money)
    }

    private func todayMetric(value: Font, money: Font) -> some View {
        metric("TODAY", duration: todayDuration,
               earnings: snapshot.todayEarnings(at: entry.date), value: value, money: money)
    }

    private func metric(_ title: String, duration: some View, earnings: Double, value: Font, money: Font) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
            duration
                .font(value)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
            Text(earnings.money(code: snapshot.currencyCode))
                .font(money)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(palette.accent)
        }
    }

    /// Bugunun toplami: tamamlanan oturumlar ve bugun baslayan calisan seans.
    private var todayDuration: some View {
        liveDuration(snapshot.todayDuration(at: entry.date),
                     counts: isEarning && snapshot.runningCountsToday(at: entry.date))
    }

    /// Calisirken sistem saati kendisi ilerletir; widget her saniye
    /// yenilenemedigi icin tek yol bu. Duraklatildiysa sabit yazilir.
    @ViewBuilder private func liveDuration(_ total: TimeInterval, counts: Bool) -> some View {
        if counts {
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

    @ViewBuilder private var actionButtons: some View {
        if let running {
            HStack(spacing: 8) {
                Button(intent: TogglePauseIntent()) {
                    actionLabel(running.isPaused ? "Resume" : "Pause",
                                systemImage: running.isPaused ? "play.fill" : "pause.fill",
                                foreground: .white, background: .white.opacity(0.14))
                }
                .buttonStyle(.plain)
                Button(intent: ClockOutIntent()) {
                    actionLabel("Clock out", systemImage: "stop.fill",
                                foreground: .red, background: .red.opacity(0.15))
                }
                .buttonStyle(.plain)
            }
        } else {
            Button(intent: ClockInIntent()) {
                actionLabel("Clock in", systemImage: "play.fill",
                            foreground: palette.actionForeground, background: palette.accent)
            }
            .buttonStyle(.plain)
        }
    }

    /// Dugmeler yan yana esit genislikte; tek dugme tum genisligi kaplar.
    private func actionLabel(_ title: String, systemImage: String, foreground: Color, background: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(background, in: Capsule())
    }
}

extension ClockinSnapshot {
    /// Widget galerisinde gosterilen ornek.
    static let placeholder = ClockinSnapshot(
        day: Calendar.current.startOfDay(for: .now), completedToday: 3 * 3600 + 25 * 60,
        earnedToday: 85.42, running: nil, hourlyRate: 25, currencyCode: "USD"
    )
}
