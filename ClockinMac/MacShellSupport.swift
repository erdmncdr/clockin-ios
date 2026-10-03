import SwiftUI

/// Keeps the port's typography while using the shared rolling renderer.
struct MacRollingText: View {
    let text: String
    let value: Double
    let size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    var color: Color = .primary

    init(_ text: String, value: Double, size: CGFloat, weight: Font.Weight = .regular,
         design: Font.Design = .default, color: Color = .primary) {
        self.text = text
        self.value = value
        self.size = size
        self.weight = weight
        self.design = design
        self.color = color
    }

    var body: some View {
        var rolling = RollingNumberText(text, value: value, font: .system(size: size, weight: weight, design: design),
                                        design: design, foregroundColor: color)
        rolling.explicit = (size, weight)
        return rolling
    }
}

/// AppKit-hosted surfaces also rebuild when the language changes.
struct MacLocalizedContent<Content: View>: View {
    @State private var languages = LanguageSwitch.shared
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .id(languages.language)
            .environment(\.locale, AppLanguage.locale)
    }
}

struct MacMainContent: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage(ClockinFontChoice.preferenceKey) private var fontRaw = ClockinFontChoice.system.rawValue

    var body: some View {
        MacLocalizedContent { MacRootView().timerPersistenceAlert(store: store) }
            .onChange(of: fontRaw) { _, _ in SessionMirror.shared.refresh() }
            .onChange(of: themeRaw) { _, _ in SessionMirror.shared.refresh() }
    }
}
