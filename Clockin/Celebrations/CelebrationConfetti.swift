import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

#if canImport(UIKit)
struct CelebrationConfetti: UIViewRepresentable {
    func makeUIView(context: Context) -> CelebrationConfettiView { CelebrationConfettiView() }
    func updateUIView(_ view: CelebrationConfettiView, context: Context) {}
    static func dismantleUIView(_ view: CelebrationConfettiView, coordinator: ()) { view.stop() }
}

#else
struct CelebrationConfetti: NSViewRepresentable {
    func makeNSView(context: Context) -> CelebrationConfettiView { CelebrationConfettiView() }
    func updateNSView(_ view: CelebrationConfettiView, context: Context) {}
    static func dismantleNSView(_ view: CelebrationConfettiView, coordinator: ()) { view.stop() }
}

#endif

#if canImport(UIKit)
typealias CelebrationConfettiViewBase = UIView
#else
typealias CelebrationConfettiViewBase = NSView
#endif

final class CelebrationConfettiView: CelebrationConfettiViewBase {
    #if os(macOS)
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    #endif

    private var renderingLayer: CALayer {
        #if canImport(UIKit)
        layer
        #else
        layer!
        #endif
    }
    private var emitter: CAEmitterLayer?
    private var cleanup: Task<Void, Never>?
    private var started = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        #if canImport(UIKit)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        #else
        wantsLayer = true
        setAccessibilityElement(false)
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { cleanup?.cancel() }

    #if canImport(UIKit)
    override func layoutSubviews() {
        super.layoutSubviews()
        startIfNeeded()
    }
    #else
    override func layout() {
        super.layout()
        startIfNeeded()
    }
    #endif

    private func startIfNeeded() {
        guard window != nil, bounds.width > 0, !started else { return }
        started = true
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.15)
        emitter.emitterSize = CGSize(width: bounds.width * 0.7, height: 1)
        emitter.birthRate = 0
        #if canImport(UIKit)
        let chip = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 9)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 6, height: 9))
        }.cgImage
        let colors = [UIColor.systemMint, .systemYellow, .systemPink, .systemBlue]
        #else
        let context = CGContext(data: nil, width: 6, height: 9, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(NSColor.white.cgColor)
        context?.fill(CGRect(x: 0, y: 0, width: 6, height: 9))
        let chip = context?.makeImage()
        let colors = [NSColor.systemMint, .systemYellow, .systemPink, .systemBlue]
        #endif
        emitter.emitterCells = colors.map { color in
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
        renderingLayer.addSublayer(emitter)
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

    #if canImport(UIKit)
    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateWindow()
    }
    #else
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateWindow()
    }
    #endif

    private func updateWindow() {
        if window == nil { stop() } else {
            #if canImport(UIKit)
            setNeedsLayout()
            #else
            needsLayout = true
            #endif
        }
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
