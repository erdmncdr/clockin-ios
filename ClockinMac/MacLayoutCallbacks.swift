import SwiftUI

struct MacHistoryRowHover: ViewModifier {
    let accent: Color
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .listRowBackground(hovering ? accent.opacity(0.09) : Color.clear)
            .modifier(MacDeferredHover(hovering: $hovering))
    }
}
