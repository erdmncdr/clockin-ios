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
            default: homeScreen
            }
        }
        .containerBackground(for: .widget) { palette.background }
    }

    private var homeScreen: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                status
                Spacer(minLength: 0)
                if let running {
                    // Seans calisirken iki blok ayni yere sigmali; yazilar kuculur.
                    metric("SESSION", duration: liveDuration(running.elapsed(at: entry.date), counts: isEarning),
                           earnings: running.elapsed(at: entry.date) / 3600 * snapshot.hourlyRate, compact: true)
                    metric("TODAY", duration: todayDuration,
                           earnings: snapshot.todayEarnings(at: entry.date), compact: true)
                } else {
                    metric("TODAY", duration: todayDuration,
                           earnings: snapshot.todayEarnings(at: entry.date), compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if family == .systemMedium {
                actionButtons
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

    private func metric(_ title: String, duration: some View, earnings: Double, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
            duration
                .font(compact ? .system(.headline, design: .rounded).weight(.semibold)
                              : .system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
            Text(earnings.money(code: snapshot.currencyCode))
                .font(compact ? .caption.weight(.semibold) : .headline)
                .monospacedDigit()
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
            VStack(spacing: 8) {
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
            .fixedSize()
        } else {
            Button(intent: ClockInIntent()) {
                actionLabel("Clock in", systemImage: "play.fill",
                            foreground: palette.actionForeground, background: palette.accent)
            }
            .buttonStyle(.plain)
        }
    }

    /// Iki dugme ust uste durdugu icin ayni genislikte olmali.
    private func actionLabel(_ title: String, systemImage: String, foreground: Color, background: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(foreground)
            .frame(width: 124)
            .padding(.vertical, 10)
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
