import SwiftUI

/// Calisan seansi gosteren ve kontrol eden kart.
struct TimerCard: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette

    /// Yenilemeyi ust gorunum yonetir; bugun karti da ayni andan okusun diye.
    let now: Date
    let onClockOut: (WorkSession) -> Void
    let onStartWithElapsed: () -> Void

    @State private var confirmCancel = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                status
                Text(DurationText.clock(store.elapsed(at: now)))
                    .font(.system(size: 60, weight: .medium, design: palette.fontDesign))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(store.currentEarnings(at: now).money(code: store.currencyCode))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.accent)
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    Text("≈ \((store.currentEarnings(at: now) * rate).money(code: "TRY"))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .card(palette)
        .sensoryFeedback(trigger: store.running?.isPaused) { old, new in
            switch (old, new) {
            case (nil, .some): .start
            case (.some, nil): .stop
            default: .impact(weight: .light)
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
        }
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
