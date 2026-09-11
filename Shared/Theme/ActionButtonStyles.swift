import SwiftUI

// Mac'teki Primary/Secondary/Danger stillerinin karsiliklari. Parmakla
// basildigi icin dikey bosluk daha genis. Mac'tekiler zemin icin sabit beyaz
// saydamlik kullaniyordu; Daylight temasinda gorunmuyordu, burada paletten
// geliyor.

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct DangerActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.red)
            .background(.red.opacity(configuration.isPressed ? 0.22 : 0.12), in: shape)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
