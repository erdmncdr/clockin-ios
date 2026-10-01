import SwiftUI
import Combine

struct HistoryView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.HistoryRange") private var range: EarningsRange = .month
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var pageAnchor = Date.now
    @AppStorage("Clockin.HistoryShowsTRY") private var showTRY = false
    @State private var pageCache = HistoryPageCache()
    @State private var now = Date.now
    private let refresh = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sheet: SessionSheet?
    @State private var pendingDelete: WorkSession?
    #if os(macOS)
    @AppStorage("Clockin.HistoryGroupByDay") private var groupByDay = true
    @State private var expandedDays: Set<Date> = []
    @State private var selectedSessionID: UUID?
    @State private var selectionDelivery = MacDeferredValue<UUID?>()
    #endif

    var body: some View {
        let period = EarningsPeriod(range: range, anchor: pageAnchor, now: now)
        let history = pageCache.value(store: store, rates: exchangeRates, period: period,
                                   monthlyGoal: monthlyGoalHours, now: now)
        let snapshot = history.snapshot
        let days = history.days
        let converting = showTRY && store.currencyCode == "USD"
        let conflicts = store.conflictingSessionIDs

        NavigationStack {
            sessionList {
                Section {
                    Picker("Period", selection: $range) {
                        ForEach(EarningsRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .hapticFeedback(.selection, trigger: range)
                    periodHeader(period)
                        // Sayfa degisimi elle yapilir; kaydirma ya da ok ayni tiki verir.
                        .hapticFeedback(.selection, trigger: pageAnchor)
                    EarningsChartView(snapshot: snapshot, months: history.months, range: range, currencyCode: store.currencyCode,
                        hasAnySessions: !store.sessions.isEmpty, showTRY: $showTRY,
                        onPage: { page($0, period: period) })
                    if let performance = history.performance {
                        #if os(macOS)
                        MonthPerformanceView(performance: performance,
                            interval: period.interval, currencyCode: store.currencyCode, showTRY: converting,
                            onPage: { page($0, period: period) })
                        #else
                        MonthPerformanceView(performance: performance,
                            interval: period.interval, currencyCode: store.currencyCode, showTRY: converting)
                        #endif
                    }
                    if converting && history.hasMissingRates {
                        Text("Some rates are unavailable")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                #if os(macOS)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                #else
                .listRowBackground(palette.surface)
                #endif
                #if os(macOS)
                Group {
                    if groupByDay {
                        ForEach(days, id: \.day) { group in
                            Section {
                                if expandedDays.contains(group.day) {
                                    ForEach(group.sessions) { session in
                                        macSessionRow(session, snapshot: snapshot, converting: converting, conflicts: conflicts)
                                    }
                                }
                            } header: {
                                Button {
                                    selectedSessionID = nil
                                    if !expandedDays.insert(group.day).inserted { expandedDays.remove(group.day) }
                                } label: {
                                    HStack {
                                        Image(systemName: expandedDays.contains(group.day) ? "chevron.down" : "chevron.right")
                                        dayHeader(group, conflicts: conflicts, showTRY: converting)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .accessibilityValue(expandedDays.contains(group.day) ? "Expanded" : "Collapsed")
                            }
                        }
                    } else {
                        Section {
                            ForEach(snapshot.sessions.sorted { $0.start > $1.start }) { session in
                                macSessionRow(session, snapshot: snapshot, converting: converting, conflicts: conflicts)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .animation(nil, value: period.pageID)
                #else
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            Button { sheet = .edit(session) } label: {
                                SessionRow(session: session, showsDay: false,
                                           conflicts: conflicts.contains(session.id),
                                           historyAmount: snapshot.sessionAmounts[session.id], historyShowsTRY: converting)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(palette.surface)
                            .swipeActions(edge: .trailing) {
                                // `role: .destructive` verilmiyor: List bu rolu gorunce satiri
                                // veri silinmeden kaldiriyor, onay uyarisi acikken satir
                                // kayboluyordu. Renk de koktaki tema tint'inden geliyordu,
                                // bu yuzden kirmizi acikca veriliyor.
                                Button("Delete", systemImage: "trash") {
                                    pendingDelete = session
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button("Edit", systemImage: "pencil") {
                                    sheet = .edit(session)
                                }
                                .tint(palette.accent)
                            }
                        }
                    } header: {
                        dayHeader(group, conflicts: conflicts, showTRY: converting)
                    }
                }
                // Sayfa degisince kayitlar yer degistirme animasyonu yapmasin.
                .animation(nil, value: period.pageID)
                #endif
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.sessions.map(\.id))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: showTRY)
            #if os(macOS)
            .listStyle(.plain)
            .contentMargins(.horizontal, 28, for: .scrollContent)
            .contentMargins(.top, 16, for: .scrollContent)
            .macReadableWidth(840)
            .macTabBarClearance()
            #else
            .insetGroupedList()
            #endif
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("History")
            .toolbar {
                #if os(macOS)
                ToolbarItem {
                    Picker("Session list", selection: $groupByDay) {
                        Text("By day").tag(true)
                        Text("Sessions").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                #endif
                ToolbarItem(placement: .trailingBar) {
                    Button { sheet = .newEntry } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add past entry")
                }
            }
        }
        #if os(macOS)
        .onChange(of: period.pageID) { _, _ in selectionDelivery.submit(nil, to: $selectedSessionID) }
        .onChange(of: groupByDay) { _, _ in selectionDelivery.submit(nil, to: $selectedSessionID) }
        .onChange(of: store.sessions) { _, sessions in
            if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
                selectionDelivery.submit(nil, to: $selectedSessionID)
            }
        }
        #endif
        .onAppear { now = .now }
        .onReceive(refresh) { now = $0 }
        .onReceive(store.objectWillChange) { now = .now }
        .sessionSheets($sheet)
        .deleteSessionAlert($pendingDelete)
    }

    @ViewBuilder
    private func sessionList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(macOS)
        List(selection: $selectedSessionID, content: content)
            .onDeleteCommand {
                guard let selectedSessionID else { return }
                pendingDelete = store.sessions.first { $0.id == selectedSessionID }
            }
        #else
        List(content: content)
        #endif
    }

    #if os(macOS)
    private func macSessionRow(_ session: WorkSession, snapshot: EarningsSnapshot,
                               converting: Bool, conflicts: Set<UUID>) -> some View {
        SessionRow(session: session, showsDay: !groupByDay,
                   conflicts: conflicts.contains(session.id),
                   historyAmount: snapshot.sessionAmounts[session.id], historyShowsTRY: converting)
            .tag(session.id)
            .modifier(MacHistoryRowHover(accent: palette.accent))
            .onTapGesture(count: 2) { sheet = .edit(session) }
            .contextMenu {
                Button("Edit", systemImage: "pencil") { sheet = .edit(session) }
                Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = session }
            }
    }
    #endif

    private func periodHeader(_ period: EarningsPeriod) -> some View {
        HStack(spacing: 8) {
            if range != .all {
                Button { page(-1, period: period) } label: {
                    Image(systemName: "chevron.left")
                        #if os(macOS)
                        .frame(width: 16, height: 20)
                        #else
                        .frame(width: 44, height: 44)
                        #endif
                }
                .accessibilityLabel("Previous period")
            }
            Text(period.title())
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            if range != .all {
                Button { page(1, period: period) } label: {
                    Image(systemName: "chevron.right")
                        #if os(macOS)
                        .frame(width: 16, height: 20)
                        #else
                        .frame(width: 44, height: 44)
                        #endif
                }
                .disabled(!period.canGoForward)
                .accessibilityLabel("Next period")
            }
        }
        #if os(macOS)
        .buttonStyle(.bordered).controlSize(.small)
        #else
        .buttonStyle(.borderless)
        #endif
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: period.pageID)
        // The row's first text is the centred title, and List would start the
        // separator under it, halfway across. Start it at the edge like the rest.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }

    private func page(_ direction: Int, period: EarningsPeriod) {
        let next = period.paged(by: direction, now: now)
        guard next.interval != period.interval else { return }
        // Ust bolumun kimligi sabit; yalniz satirdaki animasyon List'e ulasmaz.
        // Gun bolumleri yenilenirken List ve metinler ayni transaction'i kullanmali.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            pageAnchor = next.anchor
        }
    }

    /// Gun basligi: solda gun, sagda o gunun toplami.
    ///
    /// Once sure ile tutar sagda alt alta duruyordu. Her gun farkli uzunlukta
    /// oldugu icin iki sutun da tirtikli gorunuyor, basliklar da "Today" ile
    /// "Cum, 11 Eyl" arasinda gidip geliyordu. Simdi her gun ayni iskelet:
    /// ad, tarih, tek satir toplam.
    private func dayHeader(_ group: HistoryDayGroup, conflicts: Set<UUID>, showTRY: Bool) -> some View {
        let clashing = group.sessions.filter { conflicts.contains($0.id) }.count
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                SectionTitle(dayTitle(group.day))
                // Gunun toplami dogru gorunse bile ustuste binen kayitlar
                // sureyi iki kez sayiyor. Gun basliginda soylenmezse, satirlara
                // tek tek bakmadan fark edilmiyor.
                if clashing > 0 {
                    Label("\(clashing) entries overlap", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.leading, 2)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Text(DurationText.compact(group.duration))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.quaternary)
                Text(group.money.value(showTRY: showTRY).money(code: group.money.code(currency: store.currencyCode, showTRY: showTRY)))
                    .foregroundStyle(palette.accent)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    /// Every day reads the same way, name then date: "TODAY · 25 SEP",
    /// "MONDAY · 21 SEP". Days from another year add the year. The rows use
    /// the app's language, so the header does too.
    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        let sameYear = calendar.isDate(day, equalTo: .now, toGranularity: .year)
        let dateStyle = Date.FormatStyle.dateTime.locale(AppLanguage.formatLocale).day().month(.abbreviated)
        let date = sameYear ? day.formatted(dateStyle) : day.formatted(dateStyle.year())
        let name: String
        if calendar.isDateInToday(day) { name = String(localized: "TODAY", bundle: .app) }
        else if calendar.isDateInYesterday(day) { name = String(localized: "YESTERDAY", bundle: .app) }
        else { name = day.formatted(.dateTime.locale(AppLanguage.formatLocale).weekday(.wide)) }
        return "\(name) · \(date)".uppercased(with: AppLanguage.formatLocale)
    }

}

@MainActor
private final class HistoryPageCache {
    private struct Key: Equatable {
        let sessions: [WorkSession]
        let running: RunningSession?
        let rules: [RateRule]
        let hourlyRate: Double
        let currency: String
        let rates: [String: Double]
        let period: EarningsPeriod
        let monthlyGoal: Double
        let now: Date
        let calendar: Calendar
    }
    private var key: Key?
    private var page: HistoryPage?

    func value(store: ClockStore, rates: ExchangeRateStore, period: EarningsPeriod,
               monthlyGoal: Double, now: Date) -> HistoryPage {
        let next = Key(sessions: store.sessions, running: store.running, rules: store.rateRules,
            hourlyRate: store.hourlyRate, currency: store.currencyCode, rates: rates.ratesByDay,
            period: period, monthlyGoal: monthlyGoal, now: now, calendar: .current)
        if next == key, let page { return page }
        let result = HistoryPage(sessions: next.sessions, running: next.running, period: period,
            monthlyGoal: monthlyGoal, now: now, earnings: { store.earnings(for: $0) },
            activeEarnings: store.currentEarnings(at: now), rate: { rates.rate(onCalendarDay: $0) })
        key = next
        page = result
        return result
    }
}
