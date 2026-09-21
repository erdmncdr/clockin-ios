import SwiftUI
import UniformTypeIdentifiers

/// Ayarlardan acilan ekranlar; tek secim, ayri boolean bayraklar degil.
private enum SettingsSheet: String, Identifiable {
    case rateSchedule
    case importTimecards
    case companion
    case backups
    case guide
    case liveActivitySetup
    case privacyPolicy

    var id: String { rawValue }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.MascotDefault") private var mascotDefault = "Auto"
    @AppStorage(WardrobeState.deskKey) private var showHome = true
    @AppStorage(DeskMode.enabledKey) private var deskModeEnabled = true
    @AppStorage(HapticPolicy.enabledKey) private var hapticsEnabled = true
    @FocusState private var rateIsFocused: Bool
    @State private var rateText = ""
    @State private var pendingRate: RateChangeDraft?
    @State private var confirmRemoveSplit = false
    @State private var earlierRateText = ""
    @FocusState private var earlierRateIsFocused: Bool

    @State private var showImporter = false
    @State private var pendingBackupURL: URL?
    @State private var showRestoreConfirmation = false
    @State private var restoreMessage: String?
    @State private var sheet: SettingsSheet?
    @State private var exportDocument: WardrobeBackupDocument?
    @State private var showExporter = false

    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    navigationRow("How to use Clockin", systemImage: "questionmark.circle") {
                        rateIsFocused = false
                        sheet = .guide
                    }
                }
                Section("Today") {
                    NavigationLink {
                        DashboardPinOptions()
                    } label: {
                        Label("Pinned controls", systemImage: "pin")
                    }
                }
                paySection
                Section {
                    Toggle("Haptics", isOn: $hapticsEnabled.hapticSelection($selectionFeedback))
                    Toggle("Focus companion", isOn: $mascotEnabled.hapticSelection($selectionFeedback))
                    if mascotEnabled {
                        companionBehavior
                        Button("Outfits, coins and home") { sheet = .companion }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Gentle feedback for taps, selections, and completed actions.")
                }
                NudgeSettingsSection()
                Section {
                    Picker("Theme", selection: $themeRaw.hapticSelection($selectionFeedback)) {
                        ForEach(ClockinThemeChoice.allCases) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                        }
                    }
                }
                Section {
                    Toggle("Show home in desk mode", isOn: $showHome.hapticSelection($selectionFeedback))
                    Toggle("Desk mode in landscape", isOn: $deskModeEnabled.hapticSelection($selectionFeedback))
                        .onChange(of: deskModeEnabled) { _, _ in DeskMode.refreshOrientations() }
                } footer: {
                    Text("Turn sideways for a large, always-on work timer.")
                }
                FocusSettingsSection()
                LongSessionReminderSettingsSection()
                LiveActivityPrivacySection(
                    openSetup: { openPrivacySheet(.liveActivitySetup) },
                    openPolicy: { openPrivacySheet(.privacyPolicy) }
                )
                dataSection
                Section("About") {
                    LabeledContent("Version", value: versionText)
                }
            }
            .hapticFeedback(selectionFeedback)
            .dismissDecimalKeyboard(isEditing: rateIsFocused || earlierRateIsFocused) {
                rateIsFocused = false
                earlierRateIsFocused = false
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Artik Bugun ekranindan sayfa olarak aciliyor.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitEarlierRate()
                        commitRate()
                        rateIsFocused = false
                        earlierRateIsFocused = false
                        if pendingRate == nil { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if rateIsFocused || earlierRateIsFocused {
                        Spacer()
                        Button("Done") {
                            rateIsFocused = false
                            earlierRateIsFocused = false
                        }
                    }
                }
            }
            .celebrationBlocked(by: pendingRate != nil || sheet != nil || confirmRemoveSplit || showImporter || showRestoreConfirmation || showExporter)
            .sheet(item: $pendingRate, onDismiss: { syncRateText() }) { draft in
                RateChangePrompt(value: draft.value)
                    .environmentObject(store)
                    .preferredColorScheme(palette.colorScheme)
            }
            .hapticFeedback(.destructiveConfirmation, trigger: confirmRemoveSplit) { _, new in new }
            .hapticFeedback(.destructiveConfirmation, trigger: showRestoreConfirmation) { _, new in new }
            .alert("Use one rate for all work?", isPresented: $confirmRemoveSplit) {
                Button("Cancel", role: .cancel) {}
                Button("Use current rate", role: .destructive) {
                    store.setEarlierRate(nil, changedOn: changedOn)
                }
            } message: {
                Text(removeSplitMessage)
            }
            .onAppear { syncEarlierRateText() }
            .onChange(of: store.rateRules) { _, _ in
                syncEarlierRateText()
                syncRateText()
            }
            .onChange(of: earlierRateIsFocused) { _, focused in
                if !focused { commitEarlierRate() }
            }
            .onAppear { syncRateText() }
            .onChange(of: store.hourlyRate) { _, _ in syncRateText() }
            .onChange(of: rateIsFocused) { _, focused in
                if !focused { commitRate() }
            }
            .onDisappear {
                rateIsFocused = false
                earlierRateIsFocused = false
            }
            .sheet(item: $sheet) { destination in
                Group {
                    switch destination {
                    case .rateSchedule: RateScheduleView()
                    case .importTimecards: TimecardImportView()
                    case .companion: CompanionView()
                    case .backups: BackupsView()
                    case .guide: UsageGuideView()
                    case .liveActivitySetup: LiveActivitySetupView()
                    case .privacyPolicy: PrivacyPolicyBrowser()
                    }
                }
                // Sheet ayri bir sunum; renk semasi tercihi yeniden verilmeli.
                .preferredColorScheme(palette.colorScheme)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    pendingBackupURL = url
                    showRestoreConfirmation = true
                case .failure(let error):
                    Haptics.play(.validationFailed)
                    restoreMessage = "Could not open backup: \(error.localizedDescription)"
                }
            }
            .alert("Replace all data?", isPresented: $showRestoreConfirmation) {
                Button("Cancel", role: .cancel) { pendingBackupURL = nil }
                Button("Replace all data", role: .destructive) {
                    guard let url = pendingBackupURL else { return }
                    pendingBackupURL = nil
                    restoreBackup(from: url)
                }
            } message: {
                Text("This replaces every session and the running timer on this iPhone with the selected file. Your current data is kept as a backup first, so it can be restored from Automatic backups.")
            }
        }
    }

    private func openPrivacySheet(_ destination: SettingsSheet) {
        commitEarlierRate()
        commitRate()
        rateIsFocused = false
        earlierRateIsFocused = false
        if pendingRate == nil { sheet = destination }
    }

    private var paySection: some View {
        Section {
            HStack {
                Text("Hourly rate")
                TextField("Hourly rate", text: $rateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($rateIsFocused)
                    .decimalInputRegion(active: rateIsFocused || earlierRateIsFocused)
                    .onSubmit { rateIsFocused = false }
                    .disabled(store.rateHistorySummary == .custom)
            }
            if store.rateHistorySummary != .custom {
                Toggle("Earlier work had a different rate", isOn: earlierToggle)
                if hasEarlierRate {
                    DatePicker("Changed on", selection: changeDate, in: ...store.rateToday,
                               displayedComponents: .date)
                    HStack {
                        Text("Earlier rate")
                        TextField("Earlier rate", text: $earlierRateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($earlierRateIsFocused)
                            .decimalInputRegion(active: rateIsFocused || earlierRateIsFocused)
                            .onSubmit { earlierRateIsFocused = false }
                    }
                }
            }
            Picker("Currency", selection: Binding(
                get: { store.currencyCode },
                set: { store.updateCurrency($0) }
            )) {
                ForEach(currencyCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            navigationRow(store.rateHistorySummary == .custom ? "Custom rate schedule" : "Rate schedule", systemImage: "calendar") {
                rateIsFocused = false
                sheet = .rateSchedule
            }
        } header: {
            Text("Pay")
        } footer: {
            if store.rateHistorySummary != .custom {
                Text("Turn on if your hourly rate changed. Work before the date uses the earlier rate.")
            }
        }
    }

    private var companionBehavior: some View {
        // Suren oturum da toplama dahil, Mac'teki gibi. Ayarlar acikken esik
        // asilirsa secenek kendiliginden acilsin diye tazeleniyor; dakikada bir
        // yetiyor, saatlik esikler icin saniyede bir bos yere yeniden ciziyordu.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let hours = store.allDuration(at: context.date) / 3600
            VStack(alignment: .leading, spacing: 8) {
                Picker("Default behavior", selection: Binding(
                    get: { CompanionMode.resolve(mascotDefault, totalHours: hours).rawValue },
                    set: { mascotDefault = CompanionMode.resolve($0, totalHours: hours).rawValue }
                )) {
                    ForEach(CompanionMode.allCases) { mode in
                        Text(mode.menuLabel(totalHours: hours))
                            .tag(mode.rawValue)
                            .disabled(!mode.isUnlocked(totalHours: hours))
                    }
                }
                Text("Auto follows your session. Unlock Victory at 10h, Stretch at 25h, Dance at 50h, and Music at 100h of total work, including your active session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dataSection: some View {
        Section {
            navigationRow("Import timecards", systemImage: "doc.text.magnifyingglass") {
                rateIsFocused = false
                sheet = .importTimecards
            }
            Button {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("clockin-export-\(UUID().uuidString).json")
                store.exportBackup(to: url)
                if let data = try? Data(contentsOf: url) {
                    exportDocument = WardrobeBackupDocument(data: data)
                    showExporter = true
                    try? FileManager.default.removeItem(at: url)
                } else { restoreMessage = store.statusMessage; Haptics.play(.validationFailed) }
            } label: {
                Label("Export backup", systemImage: "square.and.arrow.up")
            }
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                          defaultFilename: "Clockin-backup") { result in
                if case .failure(let error) = result { restoreMessage = error.localizedDescription }
                exportDocument = nil
            }
            .disabled(!FileManager.default.fileExists(atPath: AppGroup.dataFileURL.path))
            Button {
                commitEarlierRate()
                commitRate()
                rateIsFocused = false
                earlierRateIsFocused = false
                guard pendingRate == nil else { return }
                restoreMessage = nil
                pendingBackupURL = nil
                showImporter = true
            } label: {
                Label("Restore from file…", systemImage: "square.and.arrow.down")
            }
            navigationRow("Automatic backups", systemImage: "clock.arrow.circlepath") {
                rateIsFocused = false
                sheet = .backups
            }
        } header: {
            Text("Data")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let restoreMessage { Text(restoreMessage) }
                if let latest = store.latestBackupDate {
                    Text("Last automatic backup \(latest.formatted(.relative(presentation: .named))), \(store.backupCount) saved.")
                }
                Text("Data is stored only on this iPhone. Syncing with the Mac is not set up yet.")
            }
        }
    }

    /// Sheet acan satir. Metin vurgu rengini almasin, ok isareti ile bir
    /// ekrana gidildigi belli olsun.
    private func navigationRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            commitEarlierRate()
            commitRate()
            rateIsFocused = false
            earlierRateIsFocused = false
            if pendingRate == nil { action() }
        } label: {
            HStack {
                // Ikon, ayni bolumdeki dugmelerin ikonlariyla ayni renkte kalsin.
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImage).foregroundStyle(palette.accent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }

    private var currencyCodes: [String] {
        let codes = ["USD", "EUR", "GBP", "TRY"]
        return codes.contains(store.currencyCode) ? codes : codes + [store.currencyCode]
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private func syncRateText() {
        // `String(Double)` "25.0" yaziyordu; Mac'teki alanla ayni bicim.
        rateText = String(format: "%.2f", store.hourlyRate)
    }

    private var hasEarlierRate: Bool {
        if case .changed = store.rateHistorySummary { return true }
        return false
    }

    private var changedOn: Date {
        if case let .changed(_, _, day) = store.rateHistorySummary { return day }
        return store.rateToday
    }

    private var earlierRate: Double {
        if case let .changed(earlier, _, _) = store.rateHistorySummary { return earlier }
        return store.hourlyRate
    }

    private var earlierToggle: Binding<Bool> {
        Binding(get: { hasEarlierRate }, set: { enabled in
            if enabled {
                store.setEarlierRate(store.hourlyRate, changedOn: store.rateToday)
                selectionFeedback.send(.selection)
            }
            else { confirmRemoveSplit = true }
            syncEarlierRateText()
        })
    }

    private var changeDate: Binding<Date> {
        Binding(get: { changedOn }, set: { day in
            store.setEarlierRate(earlierRate, changedOn: day)
        })
    }

    private var removeSplitMessage: String {
        let proposed = store.proposedRates(earlier: nil, changedOn: changedOn) ?? store.rateRules
        let impact = store.earningsImpact(ofRates: proposed)
        return "All work will use \(store.hourlyRate.money(code: store.currencyCode)). Earnings before \(changedOn.formatted(date: .abbreviated, time: .omitted)) change by \(impact.delta.money(code: store.currencyCode))."
    }

    private func syncEarlierRateText() {
        earlierRateText = String(format: "%.2f", earlierRate)
    }

    private func commitEarlierRate() {
        let text = earlierRateText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Double(text), value.isFinite, value >= 0, value != earlierRate {
            store.setEarlierRate(value, changedOn: changedOn)
        }
        syncEarlierRateText()
    }

    private func commitRate() {
        guard pendingRate == nil else { return }
        let text = rateText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(text), value.isFinite, value >= 0,
              abs(value - store.hourlyRate) > 0.000_001 else {
            syncRateText()
            return
        }
        if let proposed = store.proposedRates(for: value, from: store.rateToday),
           !store.hasWorkBeforeToday, store.earningsImpact(ofRates: proposed).sessions == 0 {
            store.setRate(value, from: store.rateToday)
        } else {
            pendingRate = RateChangeDraft(value: value)
        }
        syncRateText()
    }

    private func restoreBackup(from url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let restored = store.restoreBackup(from: url)
        Haptics.play(restored ? .backupRestored : .validationFailed)
        // Ortak mesaj sonradan degisse de burada bu geri yuklemenin sonucu kalir.
        restoreMessage = store.statusMessage
        syncRateText()
    }
}

private struct RateChangeDraft: Identifiable {
    let id = UUID()
    let value: Double
}

private struct RateChangePrompt: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    let value: Double
    @State private var pickingDate = false
    @State private var day = Date()
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("When did this rate start?").font(.title2.bold())
            Text("New hourly rate: \(value.money(code: store.currencyCode))")
            Text("Today: \(impact(from: store.rateToday))")
                .font(.callout).foregroundStyle(.secondary)
            Button("Today") { save(from: store.rateToday) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            Button("Pick a date…") { pickingDate = true }
            if pickingDate {
                DatePicker("Changed on", selection: $day, in: ...store.rateToday,
                           displayedComponents: .date)
                Text(impact(from: day)).font(.callout).foregroundStyle(.secondary)
                Button("Use this date") { save(from: day) }
                    .buttonStyle(.borderedProminent)
            }
            Text("Always: \(impact(from: nil))")
                .font(.callout).foregroundStyle(.secondary)
            Button("Always") { save(from: nil) }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 420)
        #endif
        .onAppear { day = store.rateToday }
    }

    private func impact(from day: Date?) -> String {
        guard let proposed = store.proposedRates(for: value, from: day) else {
            return "Edit this custom rate schedule in Rate schedule."
        }
        let impact = store.earningsImpact(ofRates: proposed)
        if impact.sessions == 0 { return "No completed sessions change." }
        return "\(impact.sessions) completed sessions change by \(impact.delta.money(code: store.currencyCode)) in total."
    }

    private func save(from day: Date?) {
        if store.setRate(value, from: day) {
            Haptics.play(.rateSaved)
            dismiss()
        } else {
            Haptics.play(.validationFailed)
            errorMessage = store.statusMessage
        }
    }
}

private struct WardrobeBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
