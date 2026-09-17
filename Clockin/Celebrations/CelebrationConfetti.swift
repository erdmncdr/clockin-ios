import SwiftUI
import UIKit

struct CelebrationConfetti: UIViewRepresentable {
    func makeUIView(context: Context) -> CelebrationConfettiView { CelebrationConfettiView() }
    func updateUIView(_ view: CelebrationConfettiView, context: Context) {}
    static func dismantleUIView(_ view: CelebrationConfettiView, coordinator: ()) { view.stop() }
}

final class CelebrationConfettiView: UIView {
    private var emitter: CAEmitterLayer?
    private var cleanup: Task<Void, Never>?
    private var started = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { cleanup?.cancel() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard window != nil, bounds.width > 0, !started else { return }
        started = true
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.15)
        emitter.emitterSize = CGSize(width: bounds.width * 0.7, height: 1)
        emitter.birthRate = 0
        let chip = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 9)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 6, height: 9))
        }.cgImage
        emitter.emitterCells = [UIColor.systemMint, .systemYellow, .systemPink, .systemBlue].map { color in
            let cell = CAEmitterCell()
            cell.contents = chip
            cell.color = color.cgColor
            cell.birthRate = 24
            cell.lifetime = 1.3
            cell.velocity = 160
            cell.velocityRange = 65
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = .pi
            cell.yAcceleration = 230
            cell.spin = 3
            cell.spinRange = 5
            cell.scaleRange = 0.35
            cell.alphaSpeed = -0.65
            return cell
        }
        layer.addSublayer(emitter)
        self.emitter = emitter
        // Model sifirda kalir; CA yalnizca 0.8 saniye parcacik uretir.
        let burst = CABasicAnimation(keyPath: "birthRate")
        burst.fromValue = 1
        burst.toValue = 1
        burst.duration = 0.8
        emitter.add(burst, forKey: "burst")
        cleanup = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2.2)) } catch { return }
            self?.stop()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } else { setNeedsLayout() }
    }

    func stop() {
        cleanup?.cancel()
        cleanup = nil
        emitter?.removeAllAnimations()
        emitter?.emitterCells = nil
        emitter?.removeFromSuperlayer()
        emitter = nil
    }
}
