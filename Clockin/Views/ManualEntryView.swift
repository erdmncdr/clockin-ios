import SwiftUI

/// Tamamlanmis bir kaydi elle ekler ya da duzenler.
///
/// Kurallar Mac'teki `ManualEntryView` ile ayni: gun ve saatler ayri secilir,
/// bitis baslangictan onceyse gece yarisi asilmis sayilir.
struct ManualEntryView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    /// Verilirse ekran duzenleme kipinde acilir.
    let editing: WorkSession?

    @State private var day: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var note: String
    @State private var errorMessage: String?

    /// Mac'te alanlar `onAppear` icinde dolduruluyordu. Sheet'te bu, ilk
    /// karede varsayilan saatlerin gorunup degismesine yol aciyor.
    init(editing: WorkSession? = nil) {
        let calendar = Calendar.current
        let today = Date()
        self.editing = editing
        _day = State(initialValue: editing?.start ?? today)
        _startTime = State(initialValue: editing?.start
            ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today)
        _endTime = State(initialValue: editing?.end
            ?? calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today) ?? today)
        _note = State(initialValue: editing.map(SessionDisplay.note) ?? "")
    }

    private var resolvedTimes: (start: Date, end: Date) {
        EntryTimes.editorTimes(day: day, startTime: startTime, endTime: endTime, replacing: editing)
    }
    private var resolvedStart: Date { resolvedTimes.start }
    private var resolvedEnd: Date { resolvedTimes.end }
    private var crossesMidnight: Bool { !Calendar.current.isDate(resolvedStart, inSameDayAs: resolvedEnd) }
    private var duration: TimeInterval {
        EntryTimes.workedDuration(start: resolvedStart, end: resolvedEnd, replacing: editing)
    }
    private var conflicts: [WorkSession] {
        store.overlappingSessions(start: resolvedStart, end: resolvedEnd, excluding: editing?.id)
    }
    private var earnings: Double {
        duration / 3600 * store.effectiveRate(at: resolvedStart, fallback: store.hourlyRate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                    // Its own key: "Start" on its own is the verb on the start button.
                    DatePicker(String(localized: "entry.start", defaultValue: "Start", bundle: .app),
                               selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime,
                               displayedComponents: editing == nil ? .hourAndMinute : [.date, .hourAndMinute])
                } footer: {
                    if crossesMidnight {
                        Text("Ends on \(resolvedEnd.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.formatLocale))).")
                    }
                }

                if !conflicts.isEmpty {
                    Section {
                        ForEach(conflicts) { session in
                            SessionRow(session: session, showsDay: true)
                        }
                    } header: {
                        Label("Overlaps \(conflicts.count) existing entries",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .textCase(nil)
                    } footer: {
                        Text("You can still save. Two records covering the same time are counted twice in your totals.")
                    }
                    .listRowBackground(palette.surface)
                }

                Section("Note") {
                    TextField("What were you working on?", text: $note, axis: .vertical)
                }

                Section {
                    // Money is the accent everywhere else in the app; time stays neutral.
                    LabeledContent("Duration") {
                        Text(DurationText.compact(duration)).monospacedDigit()
                    }
                    LabeledContent("Earnings") {
                        Text(earnings.money(code: store.currencyCode))
                            .monospacedDigit()
                            .foregroundStyle(palette.accent)
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            // Saatler degistikce cakisma bolumu aniden belirip kaybolmasin.
            .animation(.smooth(duration: 0.25), value: conflicts.map(\.id))
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(editing == nil ? "Add past entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Add" : "Save", action: save)
                        .disabled(duration <= 0)
                }
            }
        }
    }

    private func save() {
        let saved: Bool
        if let editing {
            saved = store.updateSession(id: editing.id, start: resolvedStart, end: resolvedEnd,
                                        note: SessionDisplay.storedNote(note, for: editing))
        } else {
            saved = store.addManualSession(start: resolvedStart, end: resolvedEnd, note: note)
        }
        // Mesaj mağazada ortak tutuluyor; yalnizca bu kayit basarisiz
        // olduysa gosterilir, onceki bir islemin mesaji degil.
        Haptics.play(saved ? .entrySaved : .validationFailed)
        if saved { dismiss() } else { errorMessage = store.statusMessage }
    }
}
