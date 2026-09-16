import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.HistoryRange") private var range: EarningsRange = .month
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var pageAnchor: Date?
    @State private var pageDirection = -1
    @State private var showTRY = false
    @State private var now = Date.now
    private let refresh = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sheet: SessionSheet?
    @State private var pendingDelete: WorkSession?

    var body: some View {
        let period = EarningsPeriod(range: range, anchor: pageAnchor ?? now, now: now)
        let snapshot = EarningsSnapshot(sessions: store.sessions, running: store.running,
            range: range, now: now, period: period, earnings: { store.earnings(for: $0) },
            activeEarnings: store.currentEarnings(at: now), rate: { exchangeRates.rate(onCalendarDay: $0) })
        let days = groupedDays(snapshot.sessions)
        let conflicts = store.conflictingSessionIDs

        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $range) {
                        ForEach(EarningsRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .sensoryFeedback(.selection, trigger: range)
                    periodHeader(period)
                    EarningsChartView(snapshot: snapshot, range: range, currencyCode: store.currencyCode,
                        latestRate: exchangeRates.latestRate, loadingRates: exchangeRates.isLoading,
                        hasAnySessions: !store.sessions.isEmpty, showTRY: $showTRY,
                        pageDirection: pageDirection, onPage: { page($0, period: period) })
                    if range == .month {
                        MonthPerformanceView(performance: MonthPerformance(snapshot: snapshot, period: period,
                            sessions: store.sessions, monthlyGoal: monthlyGoalHours, now: now),
                            interval: period.interval, currencyCode: store.currencyCode,
                            latestRate: exchangeRates.latestRate)
                    }
                }
                .listRowBackground(palette.surface)
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            Button { sheet = .edit(session) } label: {
                                SessionRow(session: session, showsDay: false,
                                           conflicts: conflicts.contains(session.id), showsTRY: true)
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
                        dayHeader(group, conflicts: conflicts)
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.sessions.map(\.id))
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
    }

    private func page(_ direction: Int, period: EarningsPeriod) {
        let next = period.paged(by: direction, now: now)
        guard next.interval != period.interval else { return }
        pageDirection = direction
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            pageAnchor = next.anchor
        }
    }

    /// Gun basligi: solda gun, sagda o gunun toplami.
    ///
    /// Once sure ile tutar sagda alt alta duruyordu. Her gun farkli uzunlukta
    /// oldugu icin iki sutun da tirtikli gorunuyor, basliklar da "Today" ile
    /// "Cum, 11 Eyl" arasinda gidip geliyordu. Simdi her gun ayni iskelet:
    /// ad, tarih, tek satir toplam.
    private func dayHeader(_ group: DayGroup, conflicts: Set<UUID>) -> some View {
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
                Text(group.earnings.money(code: store.currencyCode))
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
        if calendar.isDateInToday(day) { return ("TODAY", full) }
        if calendar.isDateInYesterday(day) { return ("YESTERDAY", full) }
        let days = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: .now)).day ?? 0
        if days < 7 {
            return (day.formatted(.dateTime.weekday(.wide)).uppercased(),
                    day.formatted(.dateTime.day().month(.abbreviated)))
        }
        return (day.formatted(.dateTime.day().month(.abbreviated).year()).uppercased(),
                day.formatted(.dateTime.weekday(.wide)))
    }

    private func groupedDays(_ sessions: [WorkSession]) -> [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []

        // Kayitlar zaten sirali; gruplama ve toplamlar tek geciste hesaplanir.
        for session in sessions {
            let day = calendar.startOfDay(for: session.start)
            if groups.last?.day != day {
                groups.append(DayGroup(day: day))
            }
            let index = groups.count - 1
            groups[index].sessions.append(session)
            groups[index].duration += session.duration
            groups[index].earnings += store.earnings(for: session)
        }
        return groups
    }
}

private struct DayGroup {
    let day: Date
    var sessions: [WorkSession] = []
    var duration: TimeInterval = 0
    var earnings: Double = 0
}
