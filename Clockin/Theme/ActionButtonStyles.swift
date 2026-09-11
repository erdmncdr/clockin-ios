import SwiftUI

// Mac'teki Primary/Secondary/Danger stillerinin karsiliklari. Parmakla
// basildigi icin dikey bosluk daha genis. Mac'tekiler zemin icin sabit beyaz
// saydamlik kullaniyordu; Daylight temasinda gorunmuyordu, burada paletten
// geliyor.

struct PrimaryActionButtonStyle: ButtonStyle {
    let palette: ClockinPalette

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(palette.actionForeground)
            .background(palette.accent.opacity(configuration.isPressed ? 0.75 : 1), in: shape)
            .contentShape(shape)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    let palette: ClockinPalette

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.primary)
            .background(configuration.isPressed ? palette.surfaceStroke : palette.surface, in: shape)
            .overlay { shape.stroke(palette.surfaceStroke) }
            .contentShape(shape)
    }
}

struct DangerActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.red)
            .background(.red.opacity(configuration.isPressed ? 0.22 : 0.12), in: shape)
            .contentShape(shape)
    }
}
