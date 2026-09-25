import SwiftUI

// Ayarlar ve oturum ekranlari ayni sunum secimini paylasir; iki sheet yarismaz.
private enum DashboardSheet: Identifiable {
    case companion
    case customize
    case liveActivitySetup
    case shortcut(DashboardShortcut)
    case settings
    case newEntry
    case edit(WorkSession)
    case summary(WorkSession)
    case manualStart
    case reminderEnd(RunningSession)

    var id: String {
        switch self {
        case .companion: "companion"
        case .customize: "customize"
        case .liveActivitySetup: "live-activity-setup"
        case .shortcut(let feature): "shortcut-\(feature.rawValue)"
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

    @AppStorage("Clockin.Today.Show.summary") private var showSummary = true
    @AppStorage("Clockin.Today.Show.companion") private var showCompanionCard = true
    @AppStorage("Clockin.Today.Show.goals") private var showGoals = true
    @AppStorage("Clockin.Today.Show.momentum") private var showMomentum = true
    @AppStorage("Clockin.Today.Show.recent") private var showRecent = true
    @AppStorage("Clockin.Today.Show.exchange") private var showExchange = true

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
                    DashboardPinnedTools(open: { sheet = .shortcut($0) })
                    TodayQuickLinks(open: openQuickLink)
                    if mascotEnabled && showCompanionCard { MascotCard(showInsights: showInsights, showCompanion: { sheet = .companion }) }
                    ActiveTimeline(interval: store.running?.isPaused == false ? 1 : 60) { now in
                        VStack(spacing: 14) {
                            if showSummary { TodayTotalsCard(now: now) }
                            if showGoals { TodayGoalsCard(now: now, showInsights: showInsights, setGoals: setGoals) }
                        }
                    }
                    if showMomentum { MoneyMomentumView() }
                    if showRecent { recentSection }
                    if store.currencyCode == "USD" && showExchange { exchangeCard }
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
        .onAppear {
            appeared = true
            #if DEBUG
            // Review fixture: `--open-sheet settings|customize|entry|companion|start`.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--open-sheet"), args.indices.contains(i + 1) {
                switch args[i + 1] {
                case "settings": sheet = .settings
                case "customize": sheet = .customize
                case "entry": sheet = .newEntry
                case "companion": sheet = .companion
                case "start": sheet = .manualStart
                default: break
                }
            }
            #endif
            if LanguageSwitch.shared.reopenSettings {
                // Back in the new language: Settings reappears in place, no slide.
                LanguageSwitch.shared.reopenSettings = false
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { sheet = .settings }
            }
        }
        .onDisappear { appeared = false }
        .celebrationBlocked(by: sheet != nil)
        .sheet(item: $sheet, onDismiss: presentReminderEnd) { destination in
            Group {
                switch destination {
                case .companion: CompanionView()
                case .settings: SettingsView()
                case .customize: DashboardCustomizationView()
                case .liveActivitySetup: LiveActivitySetupView()
                case .shortcut(let feature): DashboardShortcutSheet(feature: feature)
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

    private func openQuickLink(_ link: TodayQuickLink) {
        switch link {
        case .goals: showInsights()
        case .history: showHistory()
        case .newEntry: sheet = .newEntry
        case .liveUpdates: sheet = .liveActivitySetup
        }
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
            Button { sheet = .customize } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(palette.surface, in: Circle())
                    .overlay { Circle().stroke(palette.surfaceStroke) }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .foregroundStyle(palette.accent)
            .accessibilityLabel("Customize Today")
            .accessibilityIdentifier("dashboard.customize")
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
        // The soft scroll edge alone left card text legible right under the
        // badge. The screen's own colour fades out below the row instead.
        .background {
            LinearGradient(stops: [.init(color: palette.background, location: 0),
                                   .init(color: palette.background, location: 0.7),
                                   .init(color: palette.background.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -18)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    private var exchangeCard: some View { TodayExchangeRateStrip() }

    @ViewBuilder private var recentSection: some View {
        let recent = store.sessions.prefix(3)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("LAST 3 SESSIONS")
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
