import SwiftUI

enum TodaySection: String, CaseIterable, Identifiable {
    case summary, companion, goals, momentum, recent, exchange
    var id: Self { self }
    var key: String { "Clockin.Today.Show.\(rawValue)" }
    var title: String {
        switch self {
        case .summary: "Session & Today"
        case .companion: "Companion"
        case .goals: "Goals & daily pace"
        case .momentum: "Money Momentum"
        case .recent: "Last 3 sessions"
        case .exchange: "USD / TRY rate"
        }
    }
}

enum TodayQuickLink: String, CaseIterable, Identifiable {
    case goals, history, newEntry, liveUpdates
    var id: Self { self }
    var key: String { "Clockin.Today.Link.\(rawValue)" }
    var title: String {
        switch self {
        case .goals: "Goals & Pace"
        case .history: "History"
        case .newEntry: "Add entry"
        case .liveUpdates: "Live updates"
        }
    }
    var icon: String {
        switch self {
        case .goals: "target"
        case .history: "clock.arrow.circlepath"
        case .newEntry: "plus"
        case .liveUpdates: "wave.3.right"
        }
    }
}

/// Shared by Today's sheet and the Settings customization entry.
struct TodayCustomizationSections: View {
    @EnvironmentObject private var store: ClockStore

    var body: some View {
        Section {
            ForEach(TodaySection.allCases.filter { $0 != .exchange || store.currencyCode == "USD" }) { section in
                TodayPreferenceToggle(title: section.title, key: section.key, defaultValue: true)
            }
        } header: {
            Text("Visible cards")
        } footer: {
            Text("Choose your Today cards. Your data stays saved.")
        }
        Section {
            ForEach(TodayQuickLink.allCases) { link in
                TodayPreferenceToggle(title: link.title, key: link.key, defaultValue: false)
            }
        } header: {
            Text("Quick links")
        } footer: {
            Text("Optional shortcuts.")
        }
    }
}

private struct TodayPreferenceToggle: View {
    let title: String
    let key: String
    @AppStorage private var enabled: Bool

    init(title: String, key: String, defaultValue: Bool) {
        self.title = title
        self.key = key
        _enabled = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        Toggle(title, isOn: $enabled)
            .accessibilityIdentifier(key)
    }
}

struct TodayCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            Form {
                TodayCustomizationSections()
            }
            .navigationTitle("Customize Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(palette.accent)
    }
}

struct TodayQuickLinks: View {
    let open: (TodayQuickLink) -> Void
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.Today.Link.goals") private var goals = false
    @AppStorage("Clockin.Today.Link.history") private var history = false
    @AppStorage("Clockin.Today.Link.newEntry") private var newEntry = false
    @AppStorage("Clockin.Today.Link.liveUpdates") private var liveUpdates = false

    private var links: [TodayQuickLink] {
        TodayQuickLink.allCases.filter {
            switch $0 {
            case .goals: goals
            case .history: history
            case .newEntry: newEntry
            case .liveUpdates: liveUpdates
            }
        }
    }

    var body: some View {
        if !links.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                ForEach(links) { link in
                    Button { open(link) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: link.icon).accessibilityHidden(true)
                            Text(link.title).font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .card(palette)
                    .accessibilityIdentifier("today.link.\(link.rawValue)")
                }
            }
        }
    }
}

struct TodayTotalsCard: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            column("SESSION", duration: store.elapsed(at: now), earned: store.currentEarnings(at: now))
            Rectangle().fill(palette.surfaceStroke).frame(width: 1)
            column("TODAY", duration: store.todayDuration(at: now), earned: store.todayEarnings(at: now))
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 14)
        .card(palette)
        .accessibilityIdentifier("today.sessionAndToday")
    }

    private func column(_ title: String, duration: TimeInterval, earned: Double) -> some View {
        VStack(alignment: .center, spacing: 5) {
            Text(title).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary)
            RollingNumberText(DurationText.compact(duration), value: duration, font: .headline)
                .lineLimit(1).minimumScaleFactor(0.7)
            RollingNumberText(earned.money(code: store.currencyCode), value: earned,
                              font: .subheadline.weight(.semibold), foregroundColor: palette.accent)
                .lineLimit(1).minimumScaleFactor(0.7)
            if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                Text((earned * rate).money(code: "TRY"))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

struct TodayExchangeRateStrip: View {
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.arrow.circlepath").foregroundStyle(palette.secondary)
                .accessibilityHidden(true)
            if let rate = exchangeRates.latestRate {
                Text("1 USD = \(rate.formatted(.number.precision(.fractionLength(2)))) TRY")
                    .monospacedDigit().fontWeight(.medium)
                    .lineLimit(1).minimumScaleFactor(0.8)
            } else {
                Text(exchangeRates.isLoading ? "Fetching USD / TRY…" : "USD / TRY unavailable")
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            if exchangeRates.isLoading {
                ProgressView().controlSize(.mini)
                    .accessibilityLabel("Checking exchange rate")
            } else {
                Text(status).foregroundStyle(exchangeRates.errorMessage == nil ? Color.secondary : .orange)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .card(palette)
        .accessibilityElement(children: .combine)
        .accessibilityHint(exchangeRates.errorMessage ?? "Latest available USD to TRY rate")
    }

    private var status: String {
        if exchangeRates.errorMessage != nil { return exchangeRates.latestRate == nil ? "Offline" : "Cached" }
        return exchangeRates.lastSuccessfulCheck == nil ? "Cached" : "Updated"
    }
}
