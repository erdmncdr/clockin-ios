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
        _note = State(initialValue: editing?.note ?? "")
    }

    /// Secilen gunun tarihini, secilen saatle birlestirir.
    private func combine(_ time: Date) -> Date {
        let calendar = Calendar.current
        let d = calendar.dateComponents([.year, .month, .day], from: day)
        let t = calendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = d.year; merged.month = d.month; merged.day = d.day
        merged.hour = t.hour; merged.minute = t.minute
        return calendar.date(from: merged) ?? day
    }

    private var resolvedStart: Date { combine(startTime) }

    /// Kesin kucukluk: esitlikte gece yarisi asilmis saymak, ayni saati iki
    /// kez secen birine sessizce 24 saatlik bir kayit yazardi.
    private var crossesMidnight: Bool { combine(endTime) < resolvedStart }

    private var resolvedEnd: Date {
        let end = combine(endTime)
        return crossesMidnight ? end.addingTimeInterval(86_400) : end
    }

    private var duration: TimeInterval { resolvedEnd.timeIntervalSince(resolvedStart) }

    /// Bu saatlerin uzerine bindigi kayitlar.
    ///
    /// Kaydetmeyi engellemiyor: iki isi ayni saatte tutan biri olabilir ve
    /// dogru olani bilen kullanici. Ama sessizce gecmemeli, cunku gun
    /// toplamlari bu yuzden 24 saati asiyordu.
    private var conflicts: [WorkSession] {
        store.overlappingSessions(start: resolvedStart, end: resolvedEnd, excluding: editing?.id)
    }
    private var earnings: Double {
        duration / 3600 * store.effectiveRate(at: resolvedStart, fallback: store.hourlyRate)
    }

    /// Kaydedilecek saatler. Seciciler saniyeyi dusurdugu icin hic dokunulmamis
    /// bir kayitta bile yeniden kurulan saat farkli cikiyor ve magaza saat
    /// degisti sanip calisilan sureyi yeniden hesapliyordu.
    private func savedTimes(for session: WorkSession) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let minute: (Date) -> Date = {
            calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)) ?? $0
        }
        if resolvedStart == minute(session.start), resolvedEnd == minute(session.end) {
            return (session.start, session.end)
        }
        return (resolvedStart, resolvedEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                } footer: {
                    if crossesMidnight { Text("Ends the next day.") }
                }

                if !conflicts.isEmpty {
                    Section {
                        ForEach(conflicts) { session in
                            SessionRow(session: session, showsDay: true)
                        }
                    } header: {
                        Label("Overlaps \(conflicts.count) existing \(conflicts.count == 1 ? "entry" : "entries")",
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
                    LabeledContent("Duration") {
                        Text(DurationText.compact(duration))
                            .monospacedDigit()
                            .foregroundStyle(palette.accent)
                    }
                    LabeledContent("Earnings", value: earnings.money(code: store.currencyCode))
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            // Saatler degistikce cakisma bolumu aniden belirip kaybolmasin.
            .animation(.smooth(duration: 0.25), value: conflicts.map(\.id))
            .sensoryFeedback(.warning, trigger: conflicts.isEmpty) { _, isEmpty in !isEmpty }
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
            let times = savedTimes(for: editing)
            saved = store.updateSession(id: editing.id, start: times.start, end: times.end, note: note)
        } else {
            saved = store.addManualSession(start: resolvedStart, end: resolvedEnd, note: note)
        }
        // Mesaj mağazada ortak tutuluyor; yalnizca bu kayit basarisiz
        // olduysa gosterilir, onceki bir islemin mesaji degil.
        if saved { dismiss() } else { errorMessage = store.statusMessage }
    }
}
