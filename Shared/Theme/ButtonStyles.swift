import SwiftUI

/// `.plain` gibi hicbir cerceve cizmez, ama tiklama alanini etiketin
/// tamamina yayar.
///
/// SwiftUI'de `.buttonStyle(.hitTarget)` isabet bolgesini cizilen piksellere
/// indirir. Bir SF Symbol 28x28'lik cerceveye konsa bile yalnizca glifin
/// ince cizgileri tiklanabilir kalir; cercevenin bos kalan kismi tiklamayi
/// almaz. `contentShape` bunu duzeltir.
struct HitTargetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            #if os(macOS)
            .modifier(MacControlHover())
            #endif
            .pressHaptic(isPressed: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == HitTargetButtonStyle {
    static var hitTarget: HitTargetButtonStyle { HitTargetButtonStyle() }
}

#if os(macOS)
struct MacControlHover: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(.primary.opacity(hovering && isEnabled ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
    }
}
#endif
