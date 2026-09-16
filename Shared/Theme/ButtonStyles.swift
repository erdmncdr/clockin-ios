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
            .pressHaptic(isPressed: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == HitTargetButtonStyle {
    static var hitTarget: HitTargetButtonStyle { HitTargetButtonStyle() }
}
