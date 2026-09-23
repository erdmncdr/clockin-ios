import SwiftUI

extension EnvironmentValues {
    /// Secili tema. Kok gorunum `RootView` atar.
    @Entry var palette: ClockinPalette = ClockinThemeChoice.carbon.palette
}

extension View {
    /// Mac'teki `cardBackground` ile ayni yuzey.
    func card(_ palette: ClockinPalette, cornerRadius: CGFloat = 18) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.surfaceStroke)
                }
        }
    }
}

struct SectionTitle: View {
    let text: Text

    /// Sabit basliklar cevrilir; hesaplanan metinler (tarih gibi) oldugu gibi gorunur.
    init(_ key: LocalizedStringKey) { text = Text(key) }
    @_disfavoredOverload init<S: StringProtocol>(_ content: S) { text = Text(content) }

    var body: some View {
        text
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }
}
