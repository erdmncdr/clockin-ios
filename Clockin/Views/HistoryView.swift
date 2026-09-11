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

    private func dayHeader(_ group: DayGroup) -> some View {
        HStack(alignment: .top, spacing: 12) {
            SectionTitle(dayTitle(group.day))
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(DurationText.compact(group.duration))
                    .foregroundStyle(.secondary)
                Text(group.earnings.money(code: store.currencyCode))
                    .foregroundStyle(palette.accent)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        // Satirlardaki saatler ve tutarlar cihaz diliyle bicimleniyor; baslik
        // da ayni dili kullanmali.
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
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
