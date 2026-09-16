import SwiftUI

/// Calisan seansi gosteren ve kontrol eden kart.
struct TimerCard: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Yenilemeyi ust gorunum yonetir; bugun karti da ayni andan okusun diye.
    let now: Date
    let onClockOut: (WorkSession) -> Void
    let onStartWithElapsed: () -> Void

    @Environment(\.clockinContentActive) private var contentActive

    @State private var confirmCancel = false

    var body: some View {
        let elapsed = DurationText.clock(store.elapsed(at: now))
        let earned = store.currentEarnings(at: now)
        let earnings = earned.money(code: store.currencyCode)
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                status
                Text(elapsed)
                    .font(.system(size: 60, weight: .medium, design: palette.fontDesign))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(earnings)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.accent)
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    let converted = (earned * rate).money(code: "TRY")
                    Text(converted)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if let day = store.runningDayIfNotToday(at: now) {
                    // Gece yarisini asan oturum bastan sona basladigi gune
                    // yaziliyor. Bunu soylemezsek "Today" sifir kalinca
                    // sayacin kaydedilmedigi saniliyor.
                    Label("Counts toward \(day.formatted(.dateTime.month(.abbreviated).day()))",
                          systemImage: "moon.stars")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            VStack {
                controls
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: store.running != nil)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .card(palette)
        .sensoryFeedback(trigger: store.running?.isPaused) { old, new in
            guard contentActive else { return nil }
            switch (old, new) {
            case (nil, .some): return .start
            case (.some, nil): return .stop
            default: return .impact(weight: .light)
            }
        }
        .alert("Cancel active session?", isPresented: $confirmCancel) {
            Button("Keep working", role: .cancel) {}
            Button("Cancel session", role: .destructive) { store.cancelRunning() }
        } message: {
            Text("The active time will be discarded and no earnings will be added.")
        }
    }

    private var status: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var controls: some View {
        if let running = store.running {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        running.isPaused ? store.resume() : store.pause()
                    } label: {
                        Label(running.isPaused ? "Resume" : "Pause",
                              systemImage: running.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle(palette: palette))

                    Button {
                        if let session = store.clockOut() { onClockOut(session) }
                    } label: {
                        Label("Clock out", systemImage: "stop.fill")
                    }
                    .buttonStyle(DangerActionButtonStyle())
                }
                Button("Cancel session", systemImage: "xmark") { confirmCancel = true }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .transition(controlTransition)
        } else {
            VStack(spacing: 12) {
                Button { store.clockIn() } label: {
                    Label("Clock in", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle(palette: palette))
                // Sayaci baslatmayi unutunca gecen sureyi kaybetmemek icin.
                Button("Start with elapsed time", systemImage: "clock.arrow.circlepath", action: onStartWithElapsed)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .transition(controlTransition)
        }
    }

    private var controlTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .offset(y: 5))
    }

    private var statusColor: Color {
        guard let running = store.running else { return .secondary }
        return running.isPaused ? .orange : palette.accent
    }

    private var statusText: String {
        guard let running = store.running else { return "READY TO FOCUS" }
        return running.isPaused ? "PAUSED" : "FOCUS SESSION"
    }
}

private struct ClockinContentActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var clockinContentActive: Bool {
        get { self[ClockinContentActiveKey.self] }
        set { self[ClockinContentActiveKey.self] = newValue }
    }
}

private struct VisibleTimelineSchedule: TimelineSchedule {
    let interval: TimeInterval
    let active: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        guard active else { return AnySequence([startDate]) }
        return AnySequence(PeriodicTimelineSchedule(from: Date(timeIntervalSinceReferenceDate: 0), by: interval)
            .entries(from: startDate, mode: mode))
    }
}

struct ActiveTimeline<Content: View>: View {
    @Environment(\.clockinContentActive) private var contentActive
    @Environment(\.scenePhase) private var scenePhase
    let interval: TimeInterval
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        TimelineView(VisibleTimelineSchedule(interval: interval, active: contentActive && scenePhase == .active)) { context in
            // Ayri kartlar ayni saniyeyi okur; kurus farki olusmaz.
            content(Date(timeIntervalSinceReferenceDate: floor(context.date.timeIntervalSinceReferenceDate)))
                // Saniyelik rakam animasyonu CPU'da blur cizdirip telefonu isitiyor.
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
        }
    }
}
