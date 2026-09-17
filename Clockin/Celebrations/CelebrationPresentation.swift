import SwiftUI

// Tum sunumlar tek merkezde sayilir; ic ice sheet kapanisi distekini acmaz.
private struct CelebrationBlocker: ViewModifier {
    let blocked: Bool
    @StateObject private var lease = CelebrationBlockLease()

    func body(content: Content) -> some View {
        content
            .onChange(of: blocked, initial: true) { _, value in
                CelebrationCenter.shared.setBlocked(lease.id, value)
            }
            .onDisappear {
                if !blocked { CelebrationCenter.shared.setBlocked(lease.id, false) }
            }
    }
}

private final class CelebrationBlockLease: ObservableObject {
    let id = UUID()

    deinit {
        let id = id
        Task { @MainActor in CelebrationCenter.shared.setBlocked(id, false) }
    }
}

extension View {
    func celebrationBlocked(by value: Bool) -> some View {
        modifier(CelebrationBlocker(blocked: value))
    }
}

struct CelebrationVisibilityProbe: UIViewRepresentable {
    let id: UUID
    let enabled: Bool

    func makeUIView(context: Context) -> CelebrationVisibilityView {
        let view = CelebrationVisibilityView()
        CelebrationCenter.shared.setCompanion(id, view: view)
        return view
    }
    func updateUIView(_ view: CelebrationVisibilityView, context: Context) { view.enabled = enabled }
    func makeCoordinator() -> UUID { id }
    static func dismantleUIView(_ view: CelebrationVisibilityView, coordinator: UUID) {
        CelebrationCenter.shared.setCompanion(coordinator, view: nil)
    }
}

final class CelebrationVisibilityView: UIView {
    var enabled = false
    var isCompanionVisible: Bool {
        guard enabled, let window, !isHidden, alpha > 0 else { return false }
        var visible = convert(bounds, to: window).intersection(window.bounds)
        var ancestor = superview
        while let view = ancestor {
            if view.isHidden || view.alpha == 0 { return false }
            if view.clipsToBounds { visible = visible.intersection(view.convert(view.bounds, to: window)) }
            ancestor = view.superview
        }
        return !visible.isEmpty
    }
}

struct CelebrationWindowProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> CelebrationWindowView { CelebrationWindowView() }
    func updateUIView(_ view: CelebrationWindowView, context: Context) {}
}

final class CelebrationWindowView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        CelebrationCenter.shared.window = window
        CelebrationCenter.shared.screenAttached()
    }
}
