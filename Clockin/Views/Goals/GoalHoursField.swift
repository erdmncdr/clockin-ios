import SwiftUI

/// Hedef saati: yazilabilir alan ve adim dugmeleri. Mac'teki gibi 7,5 ya da
/// 7.5 yazilabilir; adimlar tam saatten daha ince hedefleri de kaybetmeden
/// ilerletir.
struct GoalHoursField: View {
    let title: String
    @Binding var hours: Double
    let step: Double
    let maximum: Double
    @Binding var pendingFocus: Bool
    let field: GoalField
    @FocusState.Binding var focusedField: GoalField?

    @State private var text = ""
    @State private var selectionFeedback = HapticSignal()
    @State private var editingSession = DecimalEditingSession()

    private var isFocused: Bool { focusedField == field }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 10) {
                Text(title)
                Spacer(minLength: 8)
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 64)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .focused($focusedField, equals: field)
                    .decimalInputRegion(active: focusedField != nil)
                    .accessibilityLabel("\(title) goal in hours")
                    .onSubmit { focusedField = nil }
                    .task(id: pendingFocus) {
                        guard pendingFocus else { return }
                        // Odak, sekme gecisi ve bolumun acilmasi bittikten sonra istenir;
                        // ust gorunumdeki FocusState daha erken atamayi yok sayiyor.
                        try? await Task.sleep(for: .milliseconds(450))
                        guard !Task.isCancelled, pendingFocus else { return }
                        focusedField = field
                        pendingFocus = false
                    }
                Text("h").foregroundStyle(.secondary)
                Stepper(title,
                        onIncrement: { setHours(GoalProgress.stepped(hours, by: step, maximum: maximum)) },
                        onDecrement: { setHours(GoalProgress.stepped(hours, by: -step, maximum: maximum)) })
                    .labelsHidden()
                    .decimalInputRegion(active: focusedField != nil)
            }
            if isFocused {
                // Klavye araci sekmede ilk odakta cikmiyordu; Done alanin altinda durur.
                Button("Done") { focusedField = nil }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .hapticFeedback(selectionFeedback)
        .onAppear { text = Self.format(hours) }
        .onChange(of: hours) { _, newValue in
            // Adim dugmesi ya da baska bir ekran degistirdiyse alani esitle;
            // yazarken ayni degeri tekrar yazip imleci oynatma.
            if GoalProgress.parseHours(text, maximum: maximum) != newValue {
                text = Self.format(newValue)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if focused { editingSession.begin() } else { finishEditing() }
        }
        .onDisappear {
            finishEditing()
            if isFocused { focusedField = nil }
            pendingFocus = false
        }
    }

    /// Yazilan deger alan birakilinca kaydedilir, her tusta degil. Yoksa
    /// "30" yazarken once "3" kaydediliyor, sinir disi "30" reddedilince
    /// hedef sessizce 3 saat kaliyordu. Bos alan hedefi kapatir; gecersiz ya
    /// da sinir disi girdi kayitli degere doner.
    private func finishEditing() {
        // Odak kaybi ve kapanis ayni duzenlemeyi iki kez kaydetmesin.
        guard editingSession.end() else { return }
        commit()
    }

    private func commit() {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            setHours(0)
        } else if let parsed = GoalProgress.parseHours(text, maximum: maximum) {
            setHours(parsed)
        } else {
            Haptics.play(.validationFailed)
        }
        text = Self.format(hours)
    }

    private func setHours(_ value: Double) {
        guard value != hours else { return }
        hours = value
        selectionFeedback.send(.selection)
    }

    /// Hedef yoksa alan bos kalir; sifir yalnizca yer tutucudur.
    static func format(_ hours: Double) -> String {
        guard hours.isFinite, hours > 0 else { return "" }
        return hours.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
