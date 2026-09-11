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
        let snapshot = ClockinSnapshot.load() ?? .empty
        // Sure metni kendisi sayar, tutar sayamaz. Sayac islerken tutar tek bir
        // girdide donup kalıyordu: kilit ekraninda saat ilerlerken para duruyor,
        // hatta gunun toplami oturumun altinda kaliyordu. Bir saatlik girdiyi
        // pesin uretiyoruz; her biri dakikasinin tutarini yaziyor ve onceden
        // hazir olduklari icin yenileme butcesinden dusmuyorlar.
        guard snapshot.running?.isPaused == false else {
            let next = now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [TodayEntry(date: now, snapshot: snapshot)],
                                policy: .after(next)))
            return
        }
        let entries = (0..<60).map { minute in
            TodayEntry(date: now.addingTimeInterval(Double(minute) * 60), snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
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
            // Olculer ve dugmeler ortali; durum satiri da onlarla hizali olsun.
            status
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(alignment: .top, spacing: 12) {
                if let running {
                    sessionMetric(running, value: .system(.title3, design: .rounded).weight(.semibold),
                                  money: .subheadline.weight(.semibold), alignment: .center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                todayMetric(value: .system(.title3, design: .rounded).weight(.semibold),
                            money: .subheadline.weight(.semibold), alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
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

    /// Kilit ekraninda tek bir olcu sigiyor, o yuzden etiket ile sayi her
    /// zaman ayni seyi anlatmali.
    ///
    /// Once hep gunun toplamiydi. Gece yarisini asan bir oturumda o toplam
    /// sifir kaliyor, ustelik simsek "calisiyor" diyordu: sayac islerken
    /// widget sifir gosteriyordu. Boyle bir oturum varken oturumun kendisi
    /// yaziliyor; gunun toplami zaten onu icermiyor.
    private var lockScreen: some View {
        let strandedRunning = running.flatMap { snapshot.runningCountsToday(at: entry.date) ? nil : $0 }
        return VStack(alignment: .leading, spacing: 2) {
            Label(strandedRunning == nil ? "Today" : "Session",
                  systemImage: isEarning ? "bolt.fill" : "clock")
                .font(.caption.weight(.semibold))
            Group {
                if let strandedRunning {
                    liveDuration(strandedRunning.elapsed(at: entry.date), counts: isEarning)
                } else {
                    todayDuration
                }
            }
            .font(.headline)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(lockScreenEarnings(strandedRunning).money(code: snapshot.currencyCode))
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lockScreenEarnings(_ strandedRunning: RunningSession?) -> Double {
        guard let strandedRunning else { return snapshot.todayEarnings(at: entry.date) }
        return strandedRunning.elapsed(at: entry.date) / 3600 * snapshot.hourlyRate
    }

    private func sessionMetric(_ running: RunningSession, value: Font, money: Font,
                               alignment: HorizontalAlignment = .leading) -> some View {
        let elapsed = running.elapsed(at: entry.date)
        // Gece yarisini asan oturum bugune sayilmaz, o yuzden TODAY yaninda
        // donmus duruyor. Basligi hangi gune yazildigini soylesin, yoksa iki
        // sayi birbiriyle celisiyor gorunuyor.
        let title = snapshot.runningCountsToday(at: entry.date)
            ? "SESSION"
            : "SESSION · " + running.start.formatted(.dateTime.month(.abbreviated).day()).uppercased()
        return metric(title, duration: liveDuration(elapsed, counts: isEarning),
                      earnings: elapsed / 3600 * snapshot.hourlyRate, value: value, money: money,
                      alignment: alignment)
    }

    private func todayMetric(value: Font, money: Font, alignment: HorizontalAlignment = .leading) -> some View {
        metric("TODAY", duration: todayDuration,
               earnings: snapshot.todayEarnings(at: entry.date), value: value, money: money,
               alignment: alignment)
    }

    private func metric(_ title: String, duration: some View, earnings: Double, value: Font, money: Font,
                        alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white.opacity(0.6))
            duration
                .font(value)
                .monospacedDigit()
                // Sayac metni olasi en uzun deger icin genis yer ayiriyor ve
                // rakamlari o alanin soluna yaziyordu; baslik ve tutar ortadayken
                // sure sola kaymis gorunuyordu.
                .multilineTextAlignment(alignment == .center ? .center : .leading)
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
        let countsRunning = snapshot.runningCountsToday(at: entry.date)
        let active = countsRunning ? (running?.elapsed(at: entry.date) ?? 0) : 0
        // Tamamlanan kisim tam saniyeye yuvarlanir. Kayit sureleri kusuratli
        // oldugu icin iki sayacin baslangici tam saniye farkla ayrilmiyor ve
        // SESSION ile TODAY'in saniyeleri farkli anlarda degisiyordu.
        let completed = (snapshot.todayDuration(at: entry.date) - active).rounded(.down)
        return liveDuration(completed + active, counts: isEarning && countsRunning)
    }

    /// Calisirken sistem saati kendisi ilerletir; widget her saniye
    /// yenilenemedigi icin tek yol bu. Duraklatildiysa sabit yazilir.
    @ViewBuilder private func liveDuration(_ total: TimeInterval, counts: Bool) -> some View {
        if counts {
            let start = entry.date.addingTimeInterval(-total)
            Text(timerInterval: LiveTimerRange.interval(from: start, at: entry.date), countsDown: false)
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
