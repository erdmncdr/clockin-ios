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
            .pressHaptic(isPressed: configuration.isPressed)
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
            .pressHaptic(isPressed: configuration.isPressed)
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
            .pressHaptic(isPressed: configuration.isPressed)
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

/// Kendi zeminini ciziyor olan dugmeler icin yalnizca basma geri bildirimi:
/// ust cubuktaki yuvarlak dugmeler, rozet karolari, secilebilir satirlar.
///
/// `.plain` basildigini hic gostermiyordu; parmak kalkana kadar dokunusun
/// alinip alinmadigi belli olmuyordu. Hafif kuculme ve soluklasma yeter, daha
/// fazlasi bu kadar sik dokunulan ogelerde goz yorar.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pressHaptic(isPressed: configuration.isPressed)
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.22, bounce: 0.35), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}
