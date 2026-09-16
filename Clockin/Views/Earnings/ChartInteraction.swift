import SwiftUI
import UIKit

struct ChartInteraction: UIViewRepresentable {
    let pageable: Bool
    let onTap: (CGPoint) -> Void
    let onPage: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        tap.delegate = context.coordinator
        pan.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) { context.coordinator.parent = self }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: ChartInteraction
        init(_ parent: ChartInteraction) { self.parent = parent }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return parent.pageable && EarningsSwipe.isHorizontal(x: velocity.x, y: velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Liste kaydirmasi beklemez; dikey baslayan jest sayfa degistiremez.
            gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer
        }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onTap(recognizer.location(in: recognizer.view))
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            let translation = recognizer.translation(in: recognizer.view)
            if let direction = EarningsSwipe.page(x: translation.x, y: translation.y) {
                parent.onPage(direction)
            }
        }
    }
}
