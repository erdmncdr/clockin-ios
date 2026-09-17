import SwiftUI

private struct DecimalFieldFrames: PreferenceKey {
    static var defaultValue: [CGRect] { [] }

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func decimalInputRegion(active: Bool) -> some View {
        background {
            if active {
                GeometryReader { geometry in
                    Color.clear.preference(key: DecimalFieldFrames.self,
                                           value: [geometry.frame(in: .global)])
                }
            }
        }
    }

    func dismissDecimalKeyboard(isEditing: Bool, dismiss: @escaping () -> Void) -> some View {
        modifier(DecimalKeyboardDismissal(isEditing: isEditing, dismiss: dismiss))
    }
}

private struct DecimalKeyboardDismissal: ViewModifier {
    let isEditing: Bool
    let dismiss: () -> Void
    @State private var fieldFrames: [CGRect] = []

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onPreferenceChange(DecimalFieldFrames.self) { fieldFrames = $0 }
            // Alan dokunusu odagi korur; diger kontroller kendi jestini de alir.
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
                    guard DecimalEditingSession.shouldDismiss(isEditing: isEditing,
                        at: tap.location, fieldFrames: fieldFrames) else { return }
                    dismiss()
                }, including: isEditing ? .all : .subviews
            )
    }
}
