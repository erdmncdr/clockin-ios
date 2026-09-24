import SwiftUI

@MainActor
struct ManualStartView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var hours = 0
    @State private var minutes = 0
    @State private var note = ""

    private var elapsed: TimeInterval { TimeInterval(hours * 3600 + minutes * 60) }

    var body: some View {
        NavigationStack {
            Form {
                if store.running != nil {
                    Section {
                        Label("A session is already running. Finish or cancel it before starting another.",
                              systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(palette.surface)
                }

                Section {
                    Stepper(value: $hours, in: 0...999) {
                        LabeledContent("Hours", value: String(hours))
                            .monospacedDigit()
                    }
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                } header: {
                    Text("Elapsed time")
                } footer: {
                    Text("The timer starts from this duration and keeps counting.")
                }
                .listRowBackground(palette.surface)

                Section("Note (optional)") {
                    TextField("What are you working on?", text: $note, axis: .vertical)
                }
                .listRowBackground(palette.surface)

                Section("Preview") {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let start = context.date.addingTimeInterval(-elapsed)
                        let rate = store.effectiveRate(at: start, fallback: store.hourlyRate)
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("Start time") {
                                Text(start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: AppLanguage.formatLocale)))
                                    .multilineTextAlignment(.trailing)
                            }
                            LabeledContent("Elapsed", value: DurationText.compact(elapsed))
                            LabeledContent("Earnings so far") {
                                Text((elapsed / 3600 * rate).money(code: store.currencyCode))
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .monospacedDigit()
                    }
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Start with elapsed time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        guard elapsed > 0, store.running == nil else { return }
                        store.clockIn(elapsed: elapsed, note: note)
                        dismiss()
                    }
                    .disabled(elapsed <= 0 || store.running != nil)
                }
            }
        }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
    }
}
