import SwiftUI

/// Ayarlardaki iCloud bolumu. Yalnizca iCloud yetkisi olan derlemede gorunur.
struct SyncSettingsSection: View {
    @ObservedObject private var sync = SyncCoordinator.shared

    var body: some View {
        if sync.isSupported {
            Section {
                Toggle("Sync with iCloud", isOn: Binding(
                    get: { sync.isEnabled },
                    set: { enabled in
                        sync.setSyncEnabled(enabled)
                        if enabled { SyncPlatform.registerForRemoteNotifications() }
                    }))
                if sync.isEnabled {
                    LabeledContent("Status") {
                        Text(sync.status.message).multilineTextAlignment(.trailing)
                    }
                    if let last = sync.lastSuccessfulSync {
                        LabeledContent("Last synced") {
                            Text(last, format: .relative(presentation: .named))
                        }
                    }
                    // Sayfa olarak acilir: iPhone'da Form satirina bagli sheet, durum
                    // her degistiginde satir yenilenince kendiliginden kapaniyordu.
                    if sync.pendingFirstMerge != nil {
                        NavigationLink("Review the first merge") { SyncFirstMergeView(embedded: true) }
                    }
                    let count = sync.recoveryInbox.count + sync.issues.count
                    if count > 0 {
                        NavigationLink { SyncReviewView(embedded: true) } label: {
                            LabeledContent("Sync changes") { Text(verbatim: String(count)) }
                        }
                    }
                }
            } header: {
                Text("iCloud")
            } footer: {
                Text("Your work, goals, companion and choices move between your iPhone and Mac through your private iCloud. Clockin has no server and no account.")
            }
        }
    }
}

/// Ilk kez baska bir cihazin gecmisi geldiginde birlestirmeden once sorulur.
struct SyncFirstMergeView: View {
    /// Ayarlarin gezinme yiginina itildiginde kendi yiginini kurmaz.
    var embedded = false
    @ObservedObject private var sync = SyncCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var merging = false

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
            Form {
                if let preview = sync.pendingFirstMerge {
                    Section {
                        LabeledContent("On this device") { Text(verbatim: String(preview.localCount)) }
                        LabeledContent("From your other devices") { Text(verbatim: String(preview.remoteCount)) }
                        LabeledContent("Same entry on both") { Text(verbatim: String(preview.duplicates)) }
                        LabeledContent("After merging") { Text(verbatim: String(preview.mergedCount)).bold() }
                    } header: {
                        Text("Entries")
                    } footer: {
                        Text("Entries recorded on both devices are kept once. A copy of this device's data is saved before anything changes, and nothing is merged until you choose Merge.")
                    }
                    Section {
                        Button {
                            merging = true
                            Task {
                                await sync.approveFirstMerge()
                                merging = false
                                if sync.pendingFirstMerge == nil { dismiss() }
                            }
                        } label: {
                            HStack {
                                Text("Merge")
                                if merging { Spacer(); ProgressView().controlSize(.small) }
                            }
                        }
                        .disabled(merging)
                        Button("Not now", role: .cancel) {
                            sync.postponeFirstMerge()
                            dismiss()
                        }
                        .disabled(merging)
                    }
                } else {
                    Text("There is nothing to merge.")
                }
            }
            .navigationTitle("Merge with iCloud")
            .inlineNavigationTitle()
            .tint(palette.accent)
            .interactiveDismissDisabled(merging)
    }
}

/// Senkronda yerini baskasina birakan degerler ve uygulanamayan kayitlar.
struct SyncReviewView: View {
    var embedded = false
    @ObservedObject private var sync = SyncCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ClockStore

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
            List {
                if sync.recoveryInbox.isEmpty && sync.issues.isEmpty {
                    Text("Nothing needs your attention.")
                }
                if !sync.recoveryInbox.isEmpty {
                    Section {
                        ForEach(sync.recoveryInbox) { entry in
                            SyncRecoveryRow(entry: entry, currencyCode: store.currencyCode) {
                                sync.acknowledge(entry.id)
                            }
                        }
                    } header: {
                        Text("Replaced by another device")
                    } footer: {
                        Text("These values were replaced while syncing. They are kept here so you can check them; choose OK once you have.")
                    }
                }
                if !sync.issues.isEmpty {
                    Section("Not synced") {
                        ForEach(sync.issues) { issue in
                            HStack(alignment: .firstTextBaseline) {
                                Text(issue.message).font(.subheadline)
                                Spacer(minLength: 8)
                                if issue.kind == .notice {
                                    Button("OK") { sync.acknowledge(issue.id) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sync changes")
            .inlineNavigationTitle()
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
                if !sync.recoveryInbox.isEmpty || sync.issues.contains(where: { $0.kind == .notice }) {
                    ToolbarItem(placement: embedded ? .primaryAction : .cancellationAction) {
                        Button("Clear all") { sync.acknowledgeAllRecoveries() }
                    }
                }
            }
    }
}

private struct SyncRecoveryRow: View {
    let entry: SyncRecoveryEntry
    let currencyCode: String
    let acknowledge: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.kind?.title ?? String(localized: "Record", bundle: .app)).font(.headline)
                Text(summary).font(.subheadline)
                Text(entry.message).font(.caption).foregroundStyle(.secondary)
                Text(entry.modifiedAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("OK", action: acknowledge).buttonStyle(.bordered)
        }
        .padding(.vertical, 2)
    }

    private var summary: String {
        switch entry.value {
        case .session(let session):
            let day = session.start.formatted(.dateTime.day().month().year())
            let note = SessionDisplay.note(session)
            let base = "\(day) · \(DurationText.compact(session.duration))"
            return note.isEmpty ? base : "\(base) · \(note)"
        case .rateRule(let rule):
            return "\(rule.hourlyRate.money(code: currencyCode))/h · \(rule.effectiveFrom.formatted(.dateTime.day().month().year()))"
        case .profile(let profile):
            return "\(profile.hourlyRate.money(code: profile.currencyCode))/h"
        case .running(let running):
            guard let session = running.session else { return String(localized: "Timer stopped", bundle: .app) }
            let start = session.start.formatted(.dateTime.day().month().hour().minute())
            return session.isPaused
                ? String(localized: "Paused timer started \(start)", bundle: .app)
                : String(localized: "Timer started \(start)", bundle: .app)
        case .preference(let key, let value):
            return "\(key.replacingOccurrences(of: "Clockin.", with: "")): \(Self.describe(value))"
        case .purchase(let purchase):
            return WardrobeCatalog.item(purchase.itemID)?.name ?? purchase.itemID
        case .wardrobe:
            return String(localized: "Outfit and room", bundle: .app)
        case .unavailable:
            return String(localized: "This value cannot be shown by this version of Clockin.", bundle: .app)
        }
    }

    private static func describe(_ value: SyncPreference) -> String {
        switch value {
        case .bool(let v): v ? String(localized: "On", bundle: .app) : String(localized: "Off", bundle: .app)
        case .integer(let v): String(v)
        case .double(let v): v.formatted()
        case .string(let v): v
        case .strings(let v): v.joined(separator: ", ")
        }
    }
}

/// Remote bildirim kaydi platforma gore. Yetkisiz derlemede cagrilmaz.
enum SyncPlatform {
    @MainActor
    static func registerForRemoteNotifications() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #else
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }
}

private struct SyncFirstMergePrompt: ViewModifier {
    @ObservedObject private var sync = SyncCoordinator.shared

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(
            get: { sync.pendingFirstMerge != nil && sync.status == .paused(.firstMerge) },
            set: { if !$0 && sync.status == .paused(.firstMerge) { sync.postponeFirstMerge() } }
        )) {
            SyncFirstMergeView().macSheetFrame(width: 480, height: 460)
        }
    }
}

extension View {
    /// Ilk birlestirme bekliyorsa bir kez sorar; "Not now" o oturumda tekrar sormaz.
    func syncFirstMergePrompt() -> some View { modifier(SyncFirstMergePrompt()) }
}
