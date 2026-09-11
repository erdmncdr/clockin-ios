import SwiftUI

/// Ana ekran: sayac, bugunun toplami ve son kayitlar.
struct DashboardView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette

    let showHistory: () -> Void

    @State private var sheet: SessionSheet?
    @State private var pendingDelete: WorkSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
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
                            TodayCard(now: context.date)
                        }
                    }
                    recentSection
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(palette.background)
            .navigationTitle("Clockin")
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
    }
}

private struct TodayCard: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette

    let now: Date

    var body: some View {
        HStack(spacing: 0) {
            metric("TODAY", DurationText.compact(store.todayDuration(at: now)), icon: "clock")
            Divider().frame(height: 36)
            metric("EARNED", store.todayEarnings(at: now).money(code: store.currencyCode),
                   icon: "chart.line.uptrend.xyaxis")
        }
        .padding(.vertical, 14)
        .card(palette)
    }

    private func metric(_ title: String, _ value: String, icon: String) -> some View {
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
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
