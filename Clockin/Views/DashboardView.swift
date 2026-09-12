import SwiftUI

/// Ana ekran: sayac, bugunun toplami ve son kayitlar.
struct DashboardView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true

    let showHistory: () -> Void
    let showInsights: () -> Void

    @State private var sheet: SessionSheet?
    @State private var pendingDelete: WorkSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Baslik yerine kendi ust satirimiz: solda seviye, sagda ekleme.
                    // Arac cubugu ogesi rozeti yuvarlak zeminine kirpiyordu.
                    HStack {
                        DashboardLevelBadge(showInsights: showInsights)
                        Spacer(minLength: 8)
                        Button { sheet = .newEntry } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .frame(width: 36, height: 36)
                                .background(palette.surface, in: Circle())
                                .overlay { Circle().stroke(palette.surfaceStroke) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel("Add past entry")
                    }
                    // Iki kart ayni andan okur. Her biri kendi TimelineView'uyla
                    // farkli anlarda yenilendiginde kazanc iki kartta bir sent
                    // farkli gorunuyordu. Sayac islemiyorsa degerler degismez;
                    // dakikada bir yenileme gun donumunu yakalamaya yetiyor.
                    TimelineView(.periodic(from: .now, by: store.running?.isPaused == false ? 1 : 60)) { context in
                        VStack(spacing: 14) {
                            TimerCard(
                                now: context.date,
                                onClockOut: { sheet = .summary($0) },
                                onStartWithElapsed: { sheet = .manualStart }
                            )
                            if mascotEnabled { MascotCard(showInsights: showInsights) }
                            TodayCard(now: context.date)
                        }
                    }
                    if store.currencyCode == "USD" {
                        exchangeCard
                    }
                    recentSection
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(palette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sessionSheets($sheet)
        .deleteSessionAlert($pendingDelete)
    }

    private var exchangeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "dollarsign.arrow.circlepath")
                .foregroundStyle(palette.secondary)
                .frame(width: 28, height: 28)
                .background(palette.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text("USD / TRY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                if let rate = exchangeRates.latestRate {
                    Text(String(format: "1 USD = %.3f TRY", rate))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(rateStatusText)
                        .font(.caption)
                        .foregroundStyle(rateStatusColor)
                } else {
                    Text(exchangeRates.isLoading ? "Fetching live rate…" : "RATE UNAVAILABLE")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(exchangeRates.isLoading ? Color.secondary : Color.red)
                    if !exchangeRates.isLoading, let error = exchangeRates.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let day = exchangeRates.latestDate {
                    Text(day)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if exchangeRates.isLoading {
                ProgressView()
                    .accessibilityLabel("Checking exchange rate")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(palette)
    }

    private var rateStatusText: String {
        if exchangeRates.isLoading { return "Checking API…" }
        if let error = exchangeRates.errorMessage { return error }
        if let checked = exchangeRates.lastSuccessfulCheck {
            return "API OK • checked \(checked.formatted(date: .omitted, time: .shortened))"
        }
        return "Cached rate"
    }

    private var rateStatusColor: Color {
        if exchangeRates.errorMessage != nil { return .orange }
        return exchangeRates.isLoading ? .secondary : palette.accent
    }

    @ViewBuilder private var recentSection: some View {
        let recent = store.sessions.prefix(5)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("RECENT SESSIONS")
                Spacer()
                if !recent.isEmpty {
                    Button("See all", action: showHistory)
                        .font(.footnote.weight(.semibold))
                }
            }
            if recent.isEmpty {
                Text("Clock in or add a past entry to see it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .card(palette)
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { session in
                        Button { sheet = .edit(session) } label: {
                            SessionRow(session: session)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                        }
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 6)))
                        .buttonStyle(.hitTarget)
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { sheet = .edit(session) }
                            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = session }
                        }
                        if session.id != recent.last?.id {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .card(palette)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: recent.map(\.id))
    }
}

private struct TodayCard: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let now: Date

    var body: some View {
        HStack(spacing: 0) {
            metric("TODAY", DurationText.compact(store.todayDuration(at: now)), icon: "clock")
            Divider().frame(height: 36)
            metric("EARNED", store.todayEarnings(at: now).money(code: store.currencyCode),
                   icon: "chart.line.uptrend.xyaxis", detail: earnedTRY)
        }
        .padding(.vertical, 14)
        .card(palette)
    }

    private var earnedTRY: String? {
        guard store.currencyCode == "USD", let rate = exchangeRates.latestRate else { return nil }
        return "≈ " + (store.todayEarnings(at: now) * rate).money(code: "TRY")
    }

    private func metric(_ title: String, _ value: String, icon: String, detail: String? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(palette.accent.opacity(0.8))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(value)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: value)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let detail {
                    Text(detail)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
