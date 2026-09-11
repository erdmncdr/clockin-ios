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
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }
}
