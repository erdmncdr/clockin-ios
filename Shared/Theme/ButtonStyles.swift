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
            .modifier(MacDeferredHover(hovering: $hovering))
    }
}

extension MacDeferredValue {
    func submit(_ value: Value, to binding: Binding<Value>) {
        submit(value, read: { binding.wrappedValue }, write: { binding.wrappedValue = $0 })
    }
}

/// Boyutu degistirmeyen hover vurgulari icin ortak, ertelenmis sinir.
struct MacDeferredHover: ViewModifier {
    @Binding var hovering: Bool
    @State private var delivery = MacDeferredValue<Bool>()

    func body(content: Content) -> some View {
        content
            .onHover { delivery.submit($0, to: $hovering) }
            .onDisappear { delivery.submit(false, to: $hovering) }
    }
}

#endif
