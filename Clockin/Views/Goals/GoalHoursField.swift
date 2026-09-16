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

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
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
                .focused($isFocused)
                .accessibilityLabel("\(title) goal in hours")
                .onSubmit(commit)
                .task(id: pendingFocus) {
                    guard pendingFocus else { return }
                    // Odak alanin kendi yasam dongusunde, baglanti kurulduktan sonra istenir.
                    await Task.yield()
                    guard !Task.isCancelled, pendingFocus else { return }
                    isFocused = true
                    pendingFocus = false
                }
            Text("h").foregroundStyle(.secondary)
            Stepper(title,
                    onIncrement: { hours = GoalProgress.stepped(hours, by: step, maximum: maximum) },
                    onDecrement: { hours = GoalProgress.stepped(hours, by: -step, maximum: maximum) })
                .labelsHidden()
        }
        .onAppear { text = Self.format(hours) }
        .onChange(of: hours) { _, newValue in
            // Adim dugmesi ya da baska bir ekran degistirdiyse alani esitle;
            // yazarken ayni degeri tekrar yazip imleci oynatma.
            if GoalProgress.parseHours(text, maximum: maximum) != newValue {
                text = Self.format(newValue)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onDisappear {
            if isFocused { commit() }
            isFocused = false
            pendingFocus = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFocused {
                    Spacer()
                    Button("Done") { isFocused = false }
                }
            }
        }
    }

    /// Yazilan deger alan birakilinca kaydedilir, her tusta degil. Yoksa
    /// "30" yazarken once "3" kaydediliyor, sinir disi "30" reddedilince
    /// hedef sessizce 3 saat kaliyordu. Bos alan hedefi kapatir; gecersiz ya
    /// da sinir disi girdi kayitli degere doner.
    private func commit() {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            hours = 0
        } else if let parsed = GoalProgress.parseHours(text, maximum: maximum) {
            hours = parsed
        }
        text = Self.format(hours)
    }

    /// Hedef yoksa alan bos kalir ve "0" yer tutucusu gorunur; yazmadan once
    /// silinecek bir sifir olmaz.
    static func format(_ hours: Double) -> String {
        guard hours.isFinite, hours > 0 else { return "" }
        return hours.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
