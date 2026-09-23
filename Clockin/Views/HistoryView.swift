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

    var body: some View {
        let period = EarningsPeriod(range: range, anchor: pageAnchor, now: now)
        let history = pageCache.value(store: store, rates: exchangeRates, period: period,
                                   monthlyGoal: monthlyGoalHours, now: now)
        let snapshot = history.snapshot
        let days = history.days
        let converting = showTRY && store.currencyCode == "USD"
        let conflicts = store.conflictingSessionIDs

        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $range) {
                        ForEach(EarningsRange.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .hapticFeedback(.selection, trigger: range)
                    periodHeader(period)
                        // Sayfa degisimi elle yapilir; kaydirma ya da ok ayni tiki verir.
                        .hapticFeedback(.selection, trigger: pageAnchor)
                    EarningsChartView(snapshot: snapshot, months: history.months, range: range, currencyCode: store.currencyCode,
                        hasAnySessions: !store.sessions.isEmpty, showTRY: $showTRY,
                        onPage: { page($0, period: period) })
                    if let performance = history.performance {
                        MonthPerformanceView(performance: performance,
                            interval: period.interval, currencyCode: store.currencyCode, showTRY: converting)
                    }
                    if converting && history.hasMissingRates {
                        Text("Some rates are unavailable")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .listRowBackground(palette.surface)
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
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.sessions.map(\.id))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: showTRY)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .newEntry } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add past entry")
                }
            }
        }
        .onAppear { now = .now }
        .onReceive(refresh) { now = $0 }
        .onReceive(store.objectWillChange) { now = .now }
        .sessionSheets($sheet)
        .deleteSessionAlert($pendingDelete)
    }

    private func periodHeader(_ period: EarningsPeriod) -> some View {
        HStack(spacing: 8) {
            if range != .all {
                Button { page(-1, period: period) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
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
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(!period.canGoForward)
                .accessibilityLabel("Next period")
            }
        }
        .buttonStyle(.borderless)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: period.pageID)
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
                let labels = dayLabels(group.day)
                SectionTitle(labels.title)
                Text(labels.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
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

    /// Iki satir hicbir zaman ayni seyi tekrarlamasin: gun adi ustteyse tarih
    /// altta gunsuz yazilir, tarih ustteyse gun adi alta iner. Bir haftadan
    /// eski gunlerde "PERSEMBE" hangi persembe oldugunu soylemiyor, o yuzden
    /// orada tarih basa geciyor.
    ///
    /// Satirlardaki saatler ve tutarlar cihaz diliyle bicimleniyor; baslik da
    /// ayni dili kullanmali.
    private func dayLabels(_ day: Date) -> (title: String, subtitle: String) {
        let calendar = Calendar.current
        let full = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if calendar.isDateInToday(day) { return (String(localized: "TODAY"), full) }
        if calendar.isDateInYesterday(day) { return (String(localized: "YESTERDAY"), full) }
        let days = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: .now)).day ?? 0
        if days < 7 {
            return (day.formatted(.dateTime.weekday(.wide)).uppercased(with: .current),
                    day.formatted(.dateTime.day().month(.abbreviated)))
        }
        return (day.formatted(.dateTime.day().month(.abbreviated).year()).uppercased(with: .current),
                day.formatted(.dateTime.weekday(.wide)))
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
