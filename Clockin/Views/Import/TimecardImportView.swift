import Foundation
import SwiftUI
import UIKit
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

    private enum Phase {
        case source
        case review(TimecardImportReview)
        case result(String)
    }

    init() {}

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
                        Button("Import") { confirm(review) }
                    case .result:
                        Button("Done") { dismiss() }
                    }
                }
            }
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                Task { @MainActor in
                    readFile(result)
                }
            }
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
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
            Button("Paste", systemImage: "doc.on.clipboard") {
                if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                    text = pasted
                    errorMessage = nil
                } else {
                    errorMessage = "The clipboard does not contain text."
                }
            }
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

        comparisonSection("New", items: review.newItems)
        comparisonSection("Matched • corrections", items: review.matchedItems)
        comparisonSection("Duplicate • skipped", items: review.duplicateItems)

        Section {
            Button("Import timecards") { confirm(review) }
                .buttonStyle(PrimaryActionButtonStyle(palette: palette))
            Button("Change source") {
                phase = .source
                errorMessage = nil
            }
            .buttonStyle(SecondaryActionButtonStyle(palette: palette))
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder private func comparisonSection(_ title: String, items: [ImportComparisonItem]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    TimecardImportItemRow(item: item)
                }
            }
            .listRowBackground(palette.surface)
        }
    }

    private func reviewText() {
        isEditingText = false
        do {
            let sessions = try PastedTextImporter.parse(text, hourlyRate: store.hourlyRate)
            prepareReview(sessions, sourceTitle: "Pasted timecards",
                          approvedDuration: PastedTextImporter.approvedSummaryDuration(in: text))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func readFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let sessions = try CSVImporter.parse(data: Data(contentsOf: url), hourlyRate: store.hourlyRate)
            prepareReview(sessions, sourceTitle: url.lastPathComponent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareReview(_ sessions: [WorkSession], sourceTitle: String, approvedDuration: TimeInterval? = nil) {
        let summary = store.compareImportedSessions(sessions)
        phase = .review(TimecardImportReview(sessions: sessions, summary: summary,
                                           sourceTitle: sourceTitle, approvedDuration: approvedDuration))
        errorMessage = nil
    }

    private func confirm(_ review: TimecardImportReview) {
        guard case .review = phase else { return }
        store.importSessions(review.sessions)
        // Ortak mesaj sonraki islemlerle degisebilir; bu islemin sonucunu sakla.
        phase = .result(store.statusMessage ?? "Import finished.")
    }
}

private struct TimecardImportReview {
    let sessions: [WorkSession]
    let sourceTitle: String
    let approvedDuration: TimeInterval?
    var newItems: [ImportComparisonItem] = []
    var matchedItems: [ImportComparisonItem] = []
    var duplicateItems: [ImportComparisonItem] = []
    var duration: TimeInterval = 0

    init(sessions: [WorkSession], summary: ImportComparisonSummary,
         sourceTitle: String, approvedDuration: TimeInterval?) {
        self.sessions = sessions
        self.sourceTitle = sourceTitle
        self.approvedDuration = approvedDuration
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
            Text(item.session.source.isEmpty ? "Imported timecard" : item.session.source)
                .font(.headline)
            if let old = item.localMatch {
                times("Existing Clockin entry", session: old)
                times("Incoming correction", session: item.session)
            } else {
                times(item.kind == .duplicate ? "Skipped duplicate" : "New entry", session: item.session)
            }
            if !item.session.note.isEmpty {
                Text(item.session.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func times(_ title: String, session: WorkSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text("Start: \(session.start.formatted(date: .abbreviated, time: .standard))")
            Text("End: \(session.end.formatted(date: .abbreviated, time: .standard))")
            Text("Duration: \(DurationText.clock(session.duration))")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
