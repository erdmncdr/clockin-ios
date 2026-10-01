import SwiftUI

struct MacDeskTimerPanel: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let panel = MacDeskFraming.timerPanel(in: geometry.size)
            content
                .padding(20)
                .frame(width: MacDeskFraming.timerSize.width, height: MacDeskFraming.timerSize.height)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
                .scaleEffect(panel.width / MacDeskFraming.timerSize.width)
                .position(x: panel.midX, y: panel.midY)
        }
    }
}
