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
    @AppStorage(ClockinFontChoice.preferenceKey) private var fontRaw = ClockinFontChoice.system.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.MascotDefault") private var mascotDefault = "Auto"
    @AppStorage(WardrobeState.deskKey) private var showHome = true
    #if os(iOS)
    @AppStorage(DeskMode.enabledKey) private var deskModeEnabled = true
    #endif
    @AppStorage(HapticPolicy.enabledKey) private var hapticsEnabled = true
    @AppStorage(LevelUpSound.enabledKey) private var levelUpSoundEnabled = true
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
    #if os(macOS)
    @State private var category: MacSettingsCategory? = .general
    #endif

    var body: some View {
        NavigationStack {
            settingsContent
            .hapticFeedback(selectionFeedback)
            #if os(iOS)
            .dismissDecimalKeyboard(isEditing: rateIsFocused || earlierRateIsFocused) {
                rateIsFocused = false
                earlierRateIsFocused = false
            }
            .scrollDismissesKeyboard(.interactively)
            #endif
            .scrollContentBackground(.hidden)
            .background(palette.background)
            #if os(iOS)
            .navigationTitle("Settings")
            .inlineNavigationTitle()
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
            #endif
            .celebrationBlocked(by: pendingRate != nil || sheet != nil || confirmRemoveSplit || showImporter || showRestoreConfirmation || showExporter)
            .sheet(item: $pendingRate, onDismiss: { syncRateText() }) { draft in
                RateChangePrompt(value: draft.value)
                    .environmentObject(store)
                    .macSheetFrame(width: 460, height: 520)
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
                    case .liveActivitySetup:
                        #if os(iOS)
                        LiveActivitySetupView()
                        #else
                        EmptyView()
                        #endif
                    case .privacyPolicy: PrivacyPolicyBrowser()
                    }
                }
                // Mac'te boyutsuz sayfa icerigi kadar uzuyor; yuzlerce satirlik
                // bir puantaj onizlemesi pencereden ve ekrandan tasiyordu.
                .macSheetFrame()
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
                    restoreMessage = String(localized: "Could not open backup: \(error.localizedDescription)", bundle: .app)
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
                #if os(macOS)
                Text("This replaces every session and the running timer on this Mac with the selected file. Your current data is kept as a backup first, so it can be restored from Automatic backups.")
                #else
                Text("This replaces every session and the running timer on this iPhone with the selected file. Your current data is kept as a backup first, so it can be restored from Automatic backups.")
                #endif
            }
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        #if os(macOS)
        macSettings
        #else
        ScrollViewReader { scroll in
            Form {
                helpSection
                // Senkron durumu ve degisiklikleri ustte; listenin dibinde bulunmuyordu.
                SyncSettingsSection().id("sync")
                todaySection
                paySection
                appearanceSection
                NudgeSettingsSection()
                languageThemeSection
                #if os(iOS)
                Section {
                    Toggle("Show home in desk mode", isOn: $showHome.hapticSelection($selectionFeedback))
                    Toggle("Desk mode in landscape", isOn: $deskModeEnabled.hapticSelection($selectionFeedback))
                        .onChange(of: deskModeEnabled) { _, _ in DeskMode.refreshOrientations() }
                } footer: {
                    Text("Turn sideways for a large, always-on work timer.")
                }
                #endif
                FocusSettingsSection()
                LongSessionReminderSettingsSection()
                #if os(iOS)
                LiveActivityPrivacySection(
                    openSetup: { openPrivacySheet(.liveActivitySetup) },
                    openPolicy: { openPrivacySheet(.privacyPolicy) }
                )
                #endif
                dataSection
                aboutSection
            }
            #if DEBUG
            // Review fixture: `--settings-sync` scrolls to the iCloud section.
            .task {
                guard ProcessInfo.processInfo.arguments.contains("--settings-sync") else { return }
                try? await Task.sleep(for: .milliseconds(600))
                scroll.scrollTo("sync", anchor: .top)
            }
            #endif
        }
        #endif
    }

    private var helpSection: some View {
        Section {
            navigationRow(String(localized: "How to use Clockin", bundle: .app), systemImage: "questionmark.circle") {
                rateIsFocused = false
                sheet = .guide
            }
        }
    }

    private var todaySection: some View {
        Section("Today") {
            NavigationLink {
                DashboardPinOptions()
            } label: {
                // Accent icon like the other rows; a bare Label took the
                // system tint and stayed green in every theme.
                Label { Text("Pinned controls") } icon: {
                    Image(systemName: "pin").foregroundStyle(palette.accent)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            #if os(iOS)
            themeFontPickers
            Toggle("Haptics", isOn: $hapticsEnabled.hapticSelection($selectionFeedback))
            #endif
            Toggle("Level-up sound", isOn: $levelUpSoundEnabled.hapticSelection($selectionFeedback))
            Toggle("Focus companion", isOn: $mascotEnabled.hapticSelection($selectionFeedback))
            if mascotEnabled {
                companionBehavior
                Button("Outfits, coins and home") { sheet = .companion }
            }
        } header: {
            Text("Appearance")
        } footer: {
            #if os(macOS)
            Text("Gentle feedback for completed actions. The level-up sound plays while Clockin is open.")
            if mascotEnabled {
                Text("Auto follows your session. Unlock Victory at 10h, Stretch at 25h, Dance at 50h, and Music at 100h of total work, including your active session.")
            }
            #else
            Text("Gentle feedback for taps, selections, and completed actions. The level-up sound plays while Clockin is open and follows the silent switch.")
            #endif
        }
    }

    @ViewBuilder
    private var themeFontPickers: some View {
        Picker("Theme", selection: $themeRaw.hapticSelection($selectionFeedback)) {
            ForEach(ClockinThemeChoice.allCases) { theme in
                Text(LocalizedStringKey(theme.rawValue)).tag(theme.rawValue)
            }
        }
        Picker("Font", selection: $fontRaw.hapticSelection($selectionFeedback)) {
            ForEach(ClockinFontChoice.allCases) { font in
                Text(LocalizedStringKey(font.rawValue))
                    .font(.system(.body, design: font.design))
                    .tag(font.rawValue)
            }
        }
        #if os(macOS)
        .pickerStyle(.radioGroup)
        #else
        .pickerStyle(.navigationLink)
        #endif
    }

    private var languageThemeSection: some View {
        Section {
            #if os(macOS)
            themeFontPickers
            #endif
            Picker("Language", selection: languageSelection) {
                Text("Automatic").tag(AppLanguage.automatic)
                ForEach([AppLanguage.turkish, .english]) { language in
                    Text(verbatim: language.nativeName ?? language.rawValue).tag(language)
                }
            }
        } footer: {
            #if os(macOS)
            Text("Automatic follows your Mac's language.")
            #else
            Text("Automatic follows your iPhone's language. The widgets and the Live Activity change with the app.")
            #endif
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: versionText)
        }
    }

    #if os(macOS)
    private var macSettings: some View {
        HStack(spacing: 0) {
            MacSettingsSidebar(selection: $category)
                .frame(width: 190)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text(LocalizedStringKey((category ?? .general).rawValue))
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 8)
                Form {
                    switch category ?? .general {
                    case .general:
                        languageThemeSection
                        appearanceSection
                        todaySection
                        MacSettingsSection(category: .general)
                    case .timer:
                        Section {
                            Button("Goals & Pace") {
                                MacNavigation.shared.openGoals()
                            }
                        } footer: {
                            Text("Set daily and monthly hours in Progress.")
                        }
                        FocusSettingsSection()
                    case .pay:
                        paySection
                    case .menuBar:
                        MacSettingsSection(category: .menuBar)
                    case .notifications:
                        NudgeSettingsSection()
                        LongSessionReminderSettingsSection()
                        MacSettingsSection(category: .notifications)
                    case .icloud:
                        SyncSettingsSection()
                    case .data:
                        dataSection
                    case .help:
                        helpSection
                        MacSettingsSection(category: .help)
                        aboutSection
                    }
                }
                .formStyle(.grouped)
                .pickerStyle(.menu)
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .id(category)
        }
        .onAppear {
            if LanguageSwitch.shared.reopenSettings { LanguageSwitch.shared.reopenSettings = false }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done", systemImage: "chevron.left") {
                    commitEarlierRate()
                    commitRate()
                    rateIsFocused = false
                    earlierRateIsFocused = false
                    if pendingRate == nil { MacNavigation.shared.closeSettings() }
                }
            }
        }
        .onChange(of: category) { _, _ in
            commitEarlierRate()
            commitRate()
            rateIsFocused = false
            earlierRateIsFocused = false
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--settings-sync") { category = .icloud }
        }
        #endif
    }
    #endif

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
                #if os(macOS)
                Spacer()
                #endif
                TextField("Hourly rate", text: $rateText)
                    .decimalPadKeyboard()
                    .multilineTextAlignment(.trailing)
                    .macSettingsField()
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
                        #if os(macOS)
                        Spacer()
                        #endif
                        TextField("Earlier rate", text: $earlierRateText)
                            .decimalPadKeyboard()
                            .multilineTextAlignment(.trailing)
                            .macSettingsField()
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
            navigationRow(store.rateHistorySummary == .custom ? String(localized: "Custom rate schedule", bundle: .app) : String(localized: "Rate schedule", bundle: .app), systemImage: "calendar") {
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
            #if os(macOS)
            companionBehaviorPicker(hours: hours)
            #else
            VStack(alignment: .leading, spacing: 8) {
                companionBehaviorPicker(hours: hours)
                Text("Auto follows your session. Unlock Victory at 10h, Stretch at 25h, Dance at 50h, and Music at 100h of total work, including your active session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
    }

    private func companionBehaviorPicker(hours: Double) -> some View {
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
    }

    private var dataSection: some View {
        Section {
            navigationRow(String(localized: "Import timecards", bundle: .app), systemImage: "doc.text.magnifyingglass") {
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
            navigationRow(String(localized: "Automatic backups", bundle: .app), systemImage: "clock.arrow.circlepath") {
                rateIsFocused = false
                sheet = .backups
            }
        } header: {
            Text("Data")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let restoreMessage { Text(restoreMessage) }
                if let latest = store.latestBackupDate {
                    Text("Last automatic backup \(latest.formatted(.relative(presentation: .named).locale(AppLanguage.formatLocale))), \(store.backupCount) saved.")
                }
                #if os(macOS)
                Text("Data is stored only on this Mac.")
                #else
                Text("Data is stored only on this iPhone.")
                #endif
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
            #if os(macOS)
            Label(title, systemImage: systemImage)
            #else
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
            #endif
        }
        .foregroundStyle(.primary)
    }

    private var languageSelection: Binding<AppLanguage> {
        Binding(get: { LanguageSwitch.shared.language }, set: { LanguageSwitch.shared.choose($0) })
    }

    private var currencyCodes: [String] {
        let codes = ["USD", "EUR", "GBP", "TRY"]
        return codes.contains(store.currencyCode) ? codes : codes + [store.currencyCode]
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(localized: "Unknown", bundle: .app)
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? String(localized: "Unknown", bundle: .app)
        return "\(version) (\(build))"
    }

    private func syncRateText() {
        // `String(Double)` "25.0" yaziyordu; Mac'teki alanla ayni bicim.
        rateText = store.hourlyRate.rateFieldText
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
        return String(localized: "All work will use \(store.hourlyRate.money(code: store.currencyCode)). Earnings before \(changedOn.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.formatLocale))) change by \(impact.delta.money(code: store.currencyCode)).", bundle: .app)
    }

    private func syncEarlierRateText() {
        earlierRateText = earlierRate.rateFieldText
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
                    #if os(macOS)
                    .buttonStyle(.bordered)
                    #else
                    .buttonStyle(.borderedProminent)
                    #endif
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
            return String(localized: "Edit this custom rate schedule in Rate schedule.", bundle: .app)
        }
        let impact = store.earningsImpact(ofRates: proposed)
        if impact.sessions == 0 { return String(localized: "No completed sessions change.", bundle: .app) }
        return String(localized: "\(impact.sessions) completed sessions change by \(impact.delta.money(code: store.currencyCode)) in total.", bundle: .app)
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

extension Double {
    /// A rate as it is typed: two decimals with the app language's separator
    /// and no grouping. Parsing accepts either separator.
    var rateFieldText: String {
        String(format: "%.2f", self).replacingOccurrences(of: ".", with: AppLanguage.formatLocale.decimalSeparator ?? ".")
    }
}
