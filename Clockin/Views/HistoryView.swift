import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sheet: SessionSheet?
    @State private var pendingDelete: WorkSession?

    var body: some View {
        let days = groupedDays()

        NavigationStack {
            List {
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            Button { sheet = .edit(session) } label: {
                                SessionRow(session: session, showsDay: false)
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
                        dayHeader(group)
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.sessions.map(\.id))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .overlay {
                if days.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "clock",
                        description: Text("Clock in or add a past entry to see it here.")
                    )
                }
            }
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
        .sessionSheets($sheet)
        .deleteSessionAlert($pendingDelete)
    }

    /// Gun basligi: solda gun, sagda o gunun toplami.
    ///
    /// Once sure ile tutar sagda alt alta duruyordu. Her gun farkli uzunlukta
    /// oldugu icin iki sutun da tirtikli gorunuyor, basliklar da "Today" ile
    /// "Cum, 11 Eyl" arasinda gidip geliyordu. Simdi her gun ayni iskelet:
    /// ad, tarih, tek satir toplam.
    private func dayHeader(_ group: DayGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                let labels = dayLabels(group.day)
                SectionTitle(labels.title)
                Text(labels.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
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

    private func groupedDays() -> [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []

        // Kayitlar zaten sirali; gruplama ve toplamlar tek geciste hesaplanir.
        for session in store.sessions {
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
