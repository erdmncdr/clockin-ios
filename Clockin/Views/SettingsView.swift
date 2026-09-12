import SwiftUI
import UniformTypeIdentifiers

/// Ayarlardan acilan ekranlar; tek secim, ayri boolean bayraklar degil.
private enum SettingsSheet: String, Identifiable {
    case rateSchedule
    case importTimecards

    var id: String { rawValue }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.MascotDefault") private var mascotDefault = "Auto"
    @FocusState private var rateIsFocused: Bool
    @State private var rateText = ""
    @State private var showImporter = false
    @State private var pendingBackupURL: URL?
    @State private var showRestoreConfirmation = false
    @State private var restoreMessage: String?
    @State private var sheet: SettingsSheet?

    var body: some View {
        NavigationStack {
            Form {
                paySection
                Section("Appearance") {
                    Toggle("Focus companion", isOn: $mascotEnabled)
                    if mascotEnabled {
                        companionBehavior
                    }
                    Picker("Theme", selection: $themeRaw) {
                        ForEach(ClockinThemeChoice.allCases) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                        }
                    }
                }
                dataSection
                Section("About") {
                    LabeledContent("Version", value: versionText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if rateIsFocused {
                        Spacer()
                        Button("Done") { rateIsFocused = false }
                    }
                }
            }
            .onAppear { syncRateText() }
            .onChange(of: store.hourlyRate) { _, _ in syncRateText() }
            .onChange(of: rateIsFocused) { _, focused in
                if !focused { commitRate() }
            }
            .onDisappear { rateIsFocused = false }
            .sheet(item: $sheet) { destination in
                Group {
                    switch destination {
                    case .rateSchedule: RateScheduleView()
                    case .importTimecards: TimecardImportView()
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
                Text("This overwrites every session and the running timer on this iPhone with the selected backup. This cannot be undone.")
            }
        }
    }

    private var paySection: some View {
        Section {
            HStack {
                Text("Hourly rate")
                TextField("Hourly rate", text: $rateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($rateIsFocused)
            }
            Picker("Currency", selection: Binding(
                get: { store.currencyCode },
                set: { store.updateCurrency($0) }
            )) {
                ForEach(currencyCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            navigationRow("Rate schedule", systemImage: "calendar") {
                rateIsFocused = false
                sheet = .rateSchedule
            }
        } header: {
            Text("Pay")
        } footer: {
            if let date = store.currentRateEffectiveFrom {
                Text("Current rate applies from \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
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
            ShareLink(item: AppGroup.dataFileURL) {
                Label("Export backup", systemImage: "square.and.arrow.up")
            }
            .disabled(!FileManager.default.fileExists(atPath: AppGroup.dataFileURL.path))
            Button {
                rateIsFocused = false
                restoreMessage = nil
                pendingBackupURL = nil
                showImporter = true
            } label: {
                Label("Restore from backup…", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Data")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let restoreMessage { Text(restoreMessage) }
                Text("Data is stored only on this iPhone. Syncing with the Mac is not set up yet.")
            }
        }
    }

    /// Sheet acan satir. Metin vurgu rengini almasin, ok isareti ile bir
    /// ekrana gidildigi belli olsun.
    private func navigationRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

    private func commitRate() {
        let normalized = rateText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        // Ara degerleri diske yazmamak icin yalnizca odak kaybinda kaydet.
        if let value = Double(normalized), value.isFinite, value >= 0,
           value != store.hourlyRate {
            store.updateRate(value)
        }
        syncRateText()
    }

    private func restoreBackup(from url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        store.importBackup(from: url)
        // Ortak mesaj sonradan degisse de burada bu geri yuklemenin sonucu kalir.
        restoreMessage = store.statusMessage
        syncRateText()
    }
}
