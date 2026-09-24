import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct TimecardImportView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var showsFileImporter = false
    @State private var errorMessage: String?
    @State private var phase: Phase = .source
    @FocusState private var isEditingText: Bool

    /// Artik kayitlarin ayarlari. Varsayilan hicbir sey silmez; silme geri
    /// alinamadigi icin secim her zaman kullanicidan gelir.
    @State private var scope: ImportScope = .daysInFile
    @State private var leftoverAction: LeftoverAction = .keep
    @State private var chosenLeftovers: Set<UUID> = []
    @State private var showsDeleteConfirmation = false
    /// Secimden cikarilan yeni/duzeltme satirlari. Mac'teki gibi hepsi secili
    /// baslar; bos kume "hepsini al" demek, boylece yeni bir satir sessizce
    /// disarida kalmaz.
    @State private var excluded: Set<UUID> = []

    private enum LeftoverAction: String, CaseIterable, Identifiable {
        case keep, choose, deleteAll
        var id: String { rawValue }
        var title: String {
            switch self {
            case .keep: String(localized: "Keep all", bundle: .app)
            case .choose: String(localized: "Choose", bundle: .app)
            case .deleteAll: String(localized: "Delete all", bundle: .app)
            }
        }
    }

    private enum Phase {
        case source
        case review(TimecardImportReview)
        case result(String)
    }

    init() {}

    @State private var selectionFeedback = HapticSignal()

    var body: some View {
        NavigationStack {
            Form {
                switch phase {
                case .source:
                    sourceSections
                case .review(let review):
                    reviewSections(review)
                case .result(let message):
                    Section("Import result") {
                        Text(message)
                            .textSelection(.enabled)
                        Button("Done") { dismiss() }
                            .buttonStyle(PrimaryActionButtonStyle(palette: palette))
                    }
                    .listRowBackground(palette.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(palette.background)
            .navigationTitle("Import timecards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    switch phase {
                    case .source, .review:
                        Button("Cancel") { dismiss() }
                    case .result:
                        EmptyView()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    switch phase {
                    case .source:
                        Button("Review", action: reviewText)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    case .review(let review):
                        Button("Import") {
                            if removalIDs(review).isEmpty {
                                confirm(review)
                            } else {
                                showsDeleteConfirmation = true
                            }
                        }
                        .disabled(!canImport(review))
                    case .result:
                        Button("Done") { dismiss() }
                    }
                }
            }
            .celebrationBlocked(by: showsFileImporter || showsDeleteConfirmation)
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                Task { @MainActor in
                    readFile(result)
                }
            }
            .onChange(of: scope) { _, _ in rebuildReview() }
            .alert("Delete your own entries?", isPresented: $showsDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                if case .review(let review) = phase {
                    Button("Import and delete \(removalIDs(review).count)", role: .destructive) {
                        confirm(review)
                    }
                }
            } message: {
                if case .review(let review) = phase {
                    Text("\(removalIDs(review).count) Clockin entries will be removed from this period along with the import. This cannot be undone.")
                }
            }
        }
        .hapticFeedback(selectionFeedback)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
        .hapticFeedback(.destructiveConfirmation, trigger: showsDeleteConfirmation) { _, new in new }
    }

    @ViewBuilder private var sourceSections: some View {
        Section {
            Label("Review before importing", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
            Text("Choose a CSV file or paste timecards. You can review new entries, corrections, and duplicates before saving anything.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(palette.surface)

        Section {
            Button {
                errorMessage = nil
                isEditingText = false
                showsFileImporter = true
            } label: {
                Label("Choose CSV file", systemImage: "folder")
            }
        } header: {
            Text("CSV file")
        } footer: {
            Text("UTF-8 CSV with Start Time and End Time columns containing ISO 8601 dates, such as 2026-09-10T09:00:00Z. Optional columns: Duration (milliseconds), Notes, and Time Sheet Source. Invalid rows are skipped.")
        }
        .listRowBackground(palette.surface)

        Section {
            // Sistem yapistirma dugmesi. `UIPasteboard.general.string` okumak
            // iOS'ta her seferinde "yapistirmaya izin ver" sorusu cikariyordu;
            // bu dugmeye basmak zaten izin sayildigi icin soru cikmaz.
            PasteButton(payloadType: String.self) { strings in
                let pasted = strings.joined(separator: "\n")
                Task { @MainActor in
                    if pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errorMessage = String(localized: "The clipboard does not contain text.", bundle: .app)
                        Haptics.play(.validationFailed)
                    } else {
                        text = pasted
                        errorMessage = nil
                    }
                }
            }
            .buttonBorderShape(.capsule)
            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .focused($isEditingText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Pasted timecards")
                .onChange(of: text) { _, _ in errorMessage = nil }
        } header: {
            Text("Pasted text")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Copy one task or an entire timecards page with English weekday and month names, a status, source, and 24-hour start and end times. Rows may be on one line or split across lines.")
                Text("Example: Thursday September 10 Approved Project 09:00 17:00")
                Text("Include the page's date range with years when available. Otherwise, the importer infers the year from today's date. An end time before the start time ends the next day.")
            }
        }
        .listRowBackground(palette.surface)

        if let errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            .listRowBackground(palette.surface)
        }
    }

    @ViewBuilder private func reviewSections(_ review: TimecardImportReview) -> some View {
        Section {
            Text(review.sourceTitle).font(.headline)
            LabeledContent("Recognized entries", value: "\(review.sessions.count)")
            LabeledContent("Imported duration", value: DurationText.compact(review.duration))
            LabeledContent("Selected to import") {
                Text("\(selected(review).count) of \(review.summary.actionableItems.count) · \(DurationText.compact(selected(review).reduce(0) { $0 + $1.duration }))")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: excluded)
            }
            LabeledContent("New", value: "\(review.newItems.count)")
            LabeledContent("Matched • corrections", value: "\(review.matchedItems.count)")
            LabeledContent("Duplicate • skipped", value: "\(review.duplicateItems.count)")
            if let approved = review.approvedDuration {
                LabeledContent("Page Approved", value: DurationText.compact(approved))
                if abs(approved - review.duration) > 60 {
                    Label("Copied rows are partial, totals do not match.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Text("Copied rows match the page Approved total.")
                        .foregroundStyle(palette.accent)
                }
            }
        } header: {
            Text("Review import")
        } footer: {
            Text("Incoming records correct matched Clockin entries. Duplicates do not add another entry. The duration above includes all recognized rows, including duplicates.")
        }
        .listRowBackground(palette.surface)

        comparisonSection("New", items: review.newItems, selectable: true)
        comparisonSection("Matched • corrections", items: review.matchedItems, selectable: true)
        comparisonSection("Duplicate • skipped", items: review.duplicateItems, selectable: false)
        leftoverSections(review)

        Section {
            Button(importButtonTitle(review)) {
                if removalIDs(review).isEmpty {
                    confirm(review)
                } else {
                    showsDeleteConfirmation = true
                }
            }
            .buttonStyle(PrimaryActionButtonStyle(palette: palette))
            .buttonPressHaptic(false)
            .disabled(!canImport(review))
            Button("Change source") {
                phase = .source
                errorMessage = nil
            }
            .buttonStyle(SecondaryActionButtonStyle(palette: palette))
        }
        .listRowBackground(palette.surface)
    }

    /// Dosyanin kapsadigi donemde duran, dosyada karsiligi olmayan kendi
    /// kayitlarin. Sayacla tutulan kayitlar unutulup acik kalabiliyor ya da
    /// hic girilmemis olabiliyor; resmi dokum gelince bunlarin ne olacagini
    /// kullanici burada secer.
    @ViewBuilder private func leftoverSections(_ review: TimecardImportReview) -> some View {
        Section {
            Picker("Period", selection: $scope.hapticSelection($selectionFeedback)) {
                ForEach(ImportScope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if review.leftovers.isEmpty {
                Text("No Clockin entries of your own are left over in this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("These entries", selection: $leftoverAction.hapticSelection($selectionFeedback)) {
                    ForEach(LeftoverAction.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if leftoverAction == .deleteAll {
                    Label("\(review.leftovers.count) entries will be deleted. This cannot be undone.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Your own entries")
        } footer: {
            Text(scope.explanation + " " + String(localized: "Entries the file already covers are not listed here.", bundle: .app))
        }
        .listRowBackground(palette.surface)

        if !review.leftovers.isEmpty {
            Section {
                ForEach(review.leftovers) { session in
                    leftoverRow(session)
                }
            } header: {
                Text("Not in the file (\(review.leftovers.count))")
            }
            .listRowBackground(palette.surface)
        }
    }

    @ViewBuilder private func leftoverRow(_ session: WorkSession) -> some View {
        let marked = leftoverAction == .deleteAll
            || (leftoverAction == .choose && chosenLeftovers.contains(session.id))
        HStack(spacing: 12) {
            if leftoverAction == .choose {
                Image(systemName: marked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(marked ? .red : .secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(session.start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: AppLanguage.formatLocale)))
                    .font(.subheadline.weight(.medium))
                Text("\(DurationText.compact(session.duration)) · \(SessionDisplay.note(session).isEmpty ? "No note" : SessionDisplay.note(session))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if marked {
                Text("DELETE")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.red)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard leftoverAction == .choose else { return }
            selectionFeedback.send(.selection)
            if chosenLeftovers.contains(session.id) {
                chosenLeftovers.remove(session.id)
            } else {
                chosenLeftovers.insert(session.id)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(leftoverAction == .choose ? .isButton : [])
    }

    private func removalIDs(_ review: TimecardImportReview) -> Set<UUID> {
        switch leftoverAction {
        case .keep: []
        case .deleteAll: Set(review.leftovers.map(\.id))
        case .choose: chosenLeftovers.intersection(review.leftovers.map(\.id))
        }
    }

    private func importButtonTitle(_ review: TimecardImportReview) -> String {
        let count = removalIDs(review).count
        let chosen = selected(review).count
        if chosen == 0 { return count > 0 ? String(localized: "Delete \(count) without importing", bundle: .app) : String(localized: "Nothing selected", bundle: .app) }
        guard count > 0 else { return String(localized: "Import \(chosen) entries", bundle: .app) }
        return String(localized: "Import \(chosen) and delete \(count)", bundle: .app)
    }

    private func selected(_ review: TimecardImportReview) -> [WorkSession] {
        review.summary.sessionsToImport(excluding: excluded)
    }

    /// Hic secim yoksa ve silinecek bir sey de yoksa yapilacak is yok.
    private func canImport(_ review: TimecardImportReview) -> Bool {
        !selected(review).isEmpty || !removalIDs(review).isEmpty
    }

    @ViewBuilder private func comparisonSection(_ title: LocalizedStringKey, items: [ImportComparisonItem],
                                                selectable: Bool) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    if selectable {
                        selectableRow(item)
                    } else {
                        TimecardImportItemRow(item: item)
                    }
                }
            } header: {
                HStack {
                    Text(title)
                    Spacer()
                    if selectable {
                        let ids = Set(items.map(\.id))
                        let allOn = ids.isDisjoint(with: excluded)
                        Button(allOn ? "None" : "All") {
                            if allOn { excluded.formUnion(ids) } else { excluded.subtract(ids) }
                            selectionFeedback.send(.selection)
                        }
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                    }
                }
            }
            .listRowBackground(palette.surface)
        }
    }

    private func selectableRow(_ item: ImportComparisonItem) -> some View {
        let isOn = !excluded.contains(item.id)
        return Button {
            if isOn { excluded.insert(item.id) } else { excluded.remove(item.id) }
            selectionFeedback.send(.selection)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? palette.accent : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                TimecardImportItemRow(item: item)
                    .opacity(isOn ? 1 : 0.5)
                    .animation(.easeOut(duration: 0.18), value: isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isOn ? "Will be imported. Double tap to leave it out." : "Left out. Double tap to import it.")
    }

    private func reviewText() {
        isEditingText = false
        do {
            let sessions = try PastedTextImporter.parse(text, hourlyRate: store.hourlyRate)
            excluded = []
            prepareReview(sessions, sourceTitle: String(localized: "Pasted timecards", bundle: .app),
                          approvedDuration: PastedTextImporter.approvedSummaryDuration(in: text))
        } catch {
            errorMessage = error.localizedDescription
            Haptics.play(.validationFailed)
        }
    }

    private func readFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let sessions = try CSVImporter.parse(data: Data(contentsOf: url), hourlyRate: store.hourlyRate)
            excluded = []
            prepareReview(sessions, sourceTitle: url.lastPathComponent)
        } catch {
            errorMessage = error.localizedDescription
            Haptics.play(.validationFailed)
        }
    }

    private func prepareReview(_ sessions: [WorkSession], sourceTitle: String, approvedDuration: TimeInterval? = nil) {
        let summary = store.compareImportedSessions(sessions, scope: scope)
        phase = .review(TimecardImportReview(sessions: sessions, summary: summary,
                                           sourceTitle: sourceTitle, approvedDuration: approvedDuration))
        errorMessage = nil
    }

    /// Kapsam degisince artik listesi bastan hesaplanir. Secili satirlar
    /// korunur; yeni kapsamda kalmayanlar `removalIDs` icinde elenir.
    private func rebuildReview() {
        guard case .review(let review) = phase else { return }
        prepareReview(review.sessions, sourceTitle: review.sourceTitle,
                      approvedDuration: review.approvedDuration)
    }

    private func confirm(_ review: TimecardImportReview) {
        guard case .review = phase else { return }
        guard store.importSessions(selected(review), removing: removalIDs(review)) else {
            Haptics.play(.validationFailed)
            phase = .result(store.statusMessage ?? String(localized: "Could not import entries.", bundle: .app))
            return
        }
        Haptics.play(.importFinished)
        chosenLeftovers = []
        excluded = []
        leftoverAction = .keep
        // Ortak mesaj sonraki islemlerle degisebilir; bu islemin sonucunu sakla.
        phase = .result(store.statusMessage ?? String(localized: "Import finished.", bundle: .app))
    }
}

private struct TimecardImportReview {
    let sessions: [WorkSession]
    let sourceTitle: String
    let approvedDuration: TimeInterval?
    let leftovers: [WorkSession]
    let summary: ImportComparisonSummary
    var newItems: [ImportComparisonItem] = []
    var matchedItems: [ImportComparisonItem] = []
    var duplicateItems: [ImportComparisonItem] = []
    var duration: TimeInterval = 0

    init(sessions: [WorkSession], summary: ImportComparisonSummary,
         sourceTitle: String, approvedDuration: TimeInterval?) {
        self.sessions = sessions
        self.sourceTitle = sourceTitle
        self.approvedDuration = approvedDuration
        self.leftovers = summary.leftovers
        self.summary = summary
        // Gruplar ve toplam bir kez hazirlanir; satirlar tekrar taramaz.
        for item in summary.items {
            duration += item.session.duration
            switch item.kind {
            case .new: newItems.append(item)
            case .matched: matchedItems.append(item)
            case .duplicate: duplicateItems.append(item)
            }
        }
    }
}

private struct TimecardImportItemRow: View {
    let item: ImportComparisonItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(SessionDisplay.timecardEntry)
                .font(.headline)
            if let old = item.localMatch {
                times("Existing Clockin entry", session: old)
                times("Incoming correction", session: item.session)
            } else {
                times(item.kind == .duplicate ? "Skipped duplicate" : "New entry", session: item.session)
            }
            if !SessionDisplay.note(item.session).isEmpty {
                Text(SessionDisplay.note(item.session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func times(_ title: LocalizedStringKey, session: WorkSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text("Start: \(session.start.formatted(Date.FormatStyle(date: .abbreviated, time: .standard, locale: AppLanguage.formatLocale)))")
            Text("End: \(session.end.formatted(Date.FormatStyle(date: .abbreviated, time: .standard, locale: AppLanguage.formatLocale)))")
            Text("Duration: \(DurationText.clock(session.duration))")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
