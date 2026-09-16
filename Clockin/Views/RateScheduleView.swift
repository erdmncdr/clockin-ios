import SwiftUI

@MainActor
struct RateScheduleView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var editor: RateEditorDestination?
    @State private var pendingDelete: RateRule?

    var body: some View {
        let rules = Array(store.rateRules.reversed())
        let currentID = store.effectiveRateRule(at: .now)?.id

        NavigationStack {
            List {
                Section {
                    ForEach(rules) { rule in
                        Button { editor = RateEditorDestination(rule: rule) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(rule.hourlyRate.money(code: store.currencyCode)) / hr")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text(periodText(rule))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if rule.id == currentID {
                                    Label("Current rate", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(palette.accent)
                                }
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(palette.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash") { pendingDelete = rule }
                                .tint(.red)
                                .disabled(rules.count <= 1)
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") {
                                editor = RateEditorDestination(rule: rule)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDelete = rule
                            }
                            .disabled(rules.count <= 1)
                        }
                    }
                } header: {
                    Text("Rate periods")
                } footer: {
                    Text("Each period sets the hourly rate for work that starts within it. The newest period that covers a day wins.")
                }

                Section {
                    Button("Add rate period", systemImage: "plus") {
                        editor = RateEditorDestination(rule: nil)
                    }
                    .listRowBackground(palette.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Rate schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editor) { destination in
                RatePeriodEditor(editing: destination.rule)
                    // Ic ice sheet ayri bir sunum; renk semasi kendiliginden gecmiyor.
                    .preferredColorScheme(palette.colorScheme)
            }
            .alert("Delete rate period?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), presenting: pendingDelete) { rule in
                Button("Cancel", role: .cancel) { pendingDelete = nil }
                Button("Delete", role: .destructive) {
                    store.deleteRateRule(id: rule.id)
                    pendingDelete = nil
                }
                .disabled(store.rateRules.count <= 1)
            } message: { rule in
                // `periodText` bir liste satiri icin yazildi ("From ... · No end date");
                // cumle icinde bozuk okunuyordu.
                Text("Delete the \(rule.hourlyRate.money(code: store.currencyCode))/hr period starting \(rule.effectiveFrom.formatted(date: .abbreviated, time: .omitted))? Earnings for sessions in this period will be recalculated using the remaining rules.")
            }
        }
        .hapticFeedback(.destructiveConfirmation, trigger: pendingDelete?.id) { _, new in new != nil }
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
        .preferredColorScheme(palette.colorScheme)
    }

    private func periodText(_ rule: RateRule) -> String {
        let start = rule.effectiveFrom.formatted(date: .abbreviated, time: .omitted)
        if let end = rule.effectiveUntil {
            return "\(start) – \(end.formatted(date: .abbreviated, time: .omitted))"
        }
        return "From \(start) · No end date"
    }
}

private struct RateEditorDestination: Identifiable {
    let id = UUID()
    let rule: RateRule?
}

@MainActor
private struct RatePeriodEditor: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var selectionFeedback = HapticSignal()

    let editing: RateRule?
    @State private var effectiveFrom: Date
    @State private var effectiveUntil: Date
    @State private var hasEndDate: Bool
    @State private var rateText: String
    @State private var errorMessage: String?

    init(editing: RateRule?) {
        self.editing = editing
        let start = editing?.effectiveFrom ?? Calendar.autoupdatingCurrent.startOfDay(for: .now)
        _effectiveFrom = State(initialValue: start)
        _effectiveUntil = State(initialValue: editing?.effectiveUntil ?? start)
        _hasEndDate = State(initialValue: editing?.effectiveUntil != nil)
        // `String(Double)` "25.0" yaziyordu; Ayarlar'daki alanla ayni bicim.
        _rateText = State(initialValue: editing.map { String(format: "%.2f", $0.hourlyRate) } ?? "")
    }

    private var parsedRate: Double? {
        let normalized = rateText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Effective from", selection: $effectiveFrom, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate.hapticSelection($selectionFeedback))
                    if hasEndDate {
                        DatePicker("Effective until", selection: $effectiveUntil, displayedComponents: .date)
                    }
                } footer: {
                    Text("The end date is included in the period.")
                }
                .listRowBackground(palette.surface)

                Section {
                    TextField("Hourly rate (\(store.currencyCode))", text: $rateText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Hourly rate")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        Text("Enter a nonnegative amount using a comma or decimal point.")
                    }
                }
                .listRowBackground(palette.surface)
            }
            .hapticFeedback(selectionFeedback)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(editing == nil ? "Add rate period" : "Edit rate period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Add" : "Save", action: save)
                        .disabled(parsedRate == nil)
                }
            }
        }
    }

    private func save() {
        guard let rate = parsedRate else { return }
        let before = store.rateRules
        // Ortak mesaj once temizlenir; eski bir hatayi bu isleme tasimayiz.
        store.statusMessage = nil
        if let editing {
            store.updateRateRule(id: editing.id, effectiveFrom: effectiveFrom,
                                 effectiveUntil: hasEndDate ? effectiveUntil : nil, hourlyRate: rate)
        } else {
            store.addRateRule(effectiveFrom: effectiveFrom,
                              effectiveUntil: hasEndDate ? effectiveUntil : nil, hourlyRate: rate)
        }
        let after = store.rateRules
        // Degismeyen gecerli bir duzenleme de basarilidir; hata mesaji onceliklidir.
        let unchangedEdit = editing.map { original in
            let calendar = Calendar.autoupdatingCurrent
            return after.contains {
                $0.id == original.id && $0.hourlyRate == rate
                    && $0.effectiveFrom == calendar.startOfDay(for: effectiveFrom)
                    && $0.effectiveUntil == (hasEndDate ? calendar.startOfDay(for: effectiveUntil) : nil)
            }
        } ?? false
        if store.statusMessage == nil && (before != after || unchangedEdit) {
            Haptics.play(.rateSaved)
            dismiss()
        } else {
            Haptics.play(.validationFailed)
            errorMessage = store.statusMessage ?? "Could not save this rate period. Please try again."
        }
    }
}
