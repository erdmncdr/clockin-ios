import SwiftUI

enum ClockinThemeChoice: String, CaseIterable, Identifiable {
    case carbon = "Carbon"
    case neonOrange = "Neon Orange"
    case electricBlue = "Electric Blue"
    case synthwave = "Synthwave"
    case dataDense = "Data Dense"
    case aurora = "Aurora"
    case terminalAmber = "Terminal Amber"
    case daylight = "Daylight"

    var id: String { rawValue }

    var palette: ClockinPalette {
        switch self {
        case .carbon:
            ClockinPalette(background: Color(red: 0.055, green: 0.065, blue: 0.08), accent: Color(red: 0.35, green: 0.95, blue: 0.58), secondary: .cyan, fontDesign: .rounded)
        case .neonOrange:
            ClockinPalette(background: Color(red: 0.075, green: 0.045, blue: 0.025), accent: Color(red: 1.0, green: 0.43, blue: 0.08), secondary: Color(red: 1.0, green: 0.78, blue: 0.16), fontDesign: .monospaced)
        case .electricBlue:
            ClockinPalette(background: Color(red: 0.025, green: 0.055, blue: 0.105), accent: Color(red: 0.15, green: 0.68, blue: 1.0), secondary: Color(red: 0.26, green: 0.94, blue: 1.0), fontDesign: .default)
        case .synthwave:
            ClockinPalette(background: Color(red: 0.075, green: 0.025, blue: 0.105), accent: Color(red: 1.0, green: 0.24, blue: 0.72), secondary: Color(red: 0.2, green: 0.95, blue: 1.0), fontDesign: .serif)
        case .dataDense:
            ClockinPalette(background: Color(red: 0.015, green: 0.02, blue: 0.018), accent: Color(red: 0.72, green: 1.0, blue: 0.18), secondary: Color(red: 0.72, green: 0.78, blue: 0.74), fontDesign: .monospaced)
        case .aurora:
            ClockinPalette(background: Color(red: 0.025, green: 0.075, blue: 0.08), accent: Color(red: 0.28, green: 1.0, blue: 0.82), secondary: Color(red: 0.42, green: 0.78, blue: 1.0), fontDesign: .rounded)
        case .terminalAmber:
            ClockinPalette(background: Color(red: 0.055, green: 0.045, blue: 0.018), accent: Color(red: 1.0, green: 0.78, blue: 0.2), secondary: Color(red: 1.0, green: 0.47, blue: 0.16), fontDesign: .monospaced)
        case .daylight:
            ClockinPalette(background: Color(red: 0.94, green: 0.955, blue: 0.98), accent: Color(red: 0.12, green: 0.34, blue: 0.78), secondary: Color(red: 0.38, green: 0.25, blue: 0.7), fontDesign: .rounded, actionForeground: .white, colorScheme: .light)
        }
    }

    static func selected(_ rawValue: String) -> ClockinThemeChoice {
        ClockinThemeChoice(rawValue: rawValue) ?? .carbon
    }
}

struct ClockinPalette {
    let background: Color
    let accent: Color
    let secondary: Color
    let fontDesign: Font.Design
    let actionForeground: Color
    let colorScheme: ColorScheme

    var surface: Color { colorScheme == .light ? .black.opacity(0.055) : .white.opacity(0.045) }
    var surfaceStroke: Color { colorScheme == .light ? .black.opacity(0.12) : .white.opacity(0.07) }

    init(background: Color, accent: Color, secondary: Color, fontDesign: Font.Design,
         actionForeground: Color = .black, colorScheme: ColorScheme = .dark) {
        self.background = background
        self.accent = accent
        self.secondary = secondary
        self.fontDesign = fontDesign
        self.actionForeground = actionForeground
        self.colorScheme = colorScheme
    }
}

struct ClockinAccentButtonStyle: ButtonStyle {
    let palette: ClockinPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(palette.actionForeground)
            .background(palette.accent.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2)))
    }
}
