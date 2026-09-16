import SwiftUI

// Ayarlar ve oturum ekranlari ayni sunum secimini paylasir; iki sheet yarismaz.
private enum DashboardSheet: Identifiable {
    case settings
    case newEntry
    case edit(WorkSession)
    case summary(WorkSession)
    case manualStart
    case reminderEnd(RunningSession)

    var id: String {
        switch self {
        case .settings: "settings"
        case .newEntry: "new"
        case .edit(let session): "edit-\(session.id)"
        case .summary(let session): "summary-\(session.id)"
        case .manualStart: "manual-start"
        case .reminderEnd(let running): "reminder-\(running.start.timeIntervalSinceReferenceDate)"
        }
    }
}

/// Ana ekran: sayac, bugunun toplami ve son kayitlar.
struct DashboardView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true

    let isSelected: Bool
    let showHistory: () -> Void
    /// Hedef karti hedeflerin duzenlendigi Insights'i acar.
    let showInsights: () -> Void
    let setGoals: () -> Void
    /// Seviye rozeti ve arkadas karti seriyi ve rozetleri acar.
    let showProgress: () -> Void

    @State private var appeared = false
    @State private var sheet: DashboardSheet?
    @State private var pendingDelete: WorkSession?
    @ObservedObject private var reminder = LongSessionReminderController.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ActiveTimeline(interval: store.running?.isPaused == false ? 1 : 60) { now in
                        TimerCard(
                            now: now,
                            onClockOut: { sheet = .summary($0) },
                            onStartWithElapsed: { sheet = .manualStart }
                        )
                    }
                    if mascotEnabled { MascotCard(showInsights: showProgress) }
                    ActiveTimeline(interval: store.running?.isPaused == false ? 1 : 60) { now in
                        VStack(spacing: 14) {
                            TodayCard(now: now)
                            TodayGoalsCard(now: now, showInsights: showInsights, setGoals: setGoals)
                        }
                    }
                    MoneyMomentumView()
                    if store.currencyCode == "USD" {
                        exchangeCard
                    }
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .pinnedHeader { header }
            .background(palette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.clockinContentActive, appeared && isSelected && sheet == nil && pendingDelete == nil && scenePhase == .active)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .sheet(item: $sheet, onDismiss: presentReminderEnd) { destination in
            Group {
                switch destination {
                case .settings: SettingsView()
                case .newEntry: ManualEntryView()
                case .edit(let session): ManualEntryView(editing: session)
                case .summary(let session): SessionSummaryView(session: session)
                case .manualStart: ManualStartView()
                case .reminderEnd(let running): ReminderEndTimeView(running: running)
                }
            }
            .preferredColorScheme(palette.colorScheme)
        }
        .deleteSessionAlert($pendingDelete)
        .onChange(of: reminder.pendingEndTime, initial: true) { _, _ in routeReminderEnd() }
        .onChange(of: isSelected) { _, _ in routeReminderEnd() }
        .onChange(of: scenePhase) { _, _ in routeReminderEnd() }
    }

    private func routeReminderEnd() {
        guard isSelected, scenePhase == .active, reminder.pendingEndTime != nil else { return }
        if sheet != nil { sheet = nil } else { presentReminderEnd() }
    }

    private func presentReminderEnd() {
        guard isSelected, scenePhase == .active else { return }
        guard let start = reminder.pendingEndTime else { return }
        reminder.pendingEndTime = nil
        guard let running = store.running, running.start == start else { return }
        sheet = .reminderEnd(running)
    }

    // Baslik yerine kendi ust satirimiz: solda seviye, sagda ayarlar ve ekleme.
    // Arac cubugu ogesi rozeti yuvarlak zeminine kirpiyordu. Icerikle birlikte
    // kaydiginda durum cubugunun altina giriyordu; diger sekmelerin basligi
    // gibi ustte sabit durur.
    private var header: some View {
        HStack {
            DashboardLevelBadge(showInsights: showProgress)
            Spacer(minLength: 8)
            Button { sheet = .settings } label: {
                Image(systemName: "gearshape")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(palette.surface, in: Circle())
                    .overlay { Circle().stroke(palette.surfaceStroke) }
            }
            .buttonStyle(.pressable)
            .foregroundStyle(palette.accent)
            .accessibilityLabel("Settings")
            Button { sheet = .newEntry } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(palette.surface, in: Circle())
                    .overlay { Circle().stroke(palette.surfaceStroke) }
            }
            .buttonStyle(.pressable)
            .foregroundStyle(palette.accent)
            .accessibilityLabel("Add past entry")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
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
        return (store.todayEarnings(at: now) * rate).money(code: "TRY")
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
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let detail {
                    Text(detail)
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

private extension View {
    /// Kaydirilan icerigin ustunde sabit duran bir satir. iOS 26'da gezinme
    /// cubugunun yumusak kenar efektini alir; oncesinde cubuk malzemesi.
    @ViewBuilder
    func pinnedHeader<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .top, spacing: 0, content: header)
        } else {
            safeAreaInset(edge: .top, spacing: 0) {
                header().background(.bar)
            }
        }
    }
}
