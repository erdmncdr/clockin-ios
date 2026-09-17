import SwiftUI
import UIKit

@MainActor
struct DashboardLevelBadge: View {
    @Environment(\.clockinContentActive) private var contentActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false
    private var active: Bool { appeared && contentActive && scenePhase == .active }
    let showInsights: () -> Void
    @ObservedObject private var celebrations = CelebrationCenter.shared
    private var level: Int { celebrations.snapshot?.level ?? 1 }
    private var xp: Int { celebrations.snapshot?.xp ?? 0 }

    var body: some View {
        Button(action: showInsights) {
            LevelBadge(level: level, xp: xp, active: active)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Level \(level), \(xp) XP")
        .accessibilityValue("\(500 - xp % 500) XP to next level")
        .accessibilityHint("Opens your level and badges")
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

private struct LevelBadge: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: Int
    let xp: Int
    let active: Bool

    private var progress: Double { min(max(Double(xp % 500) / 500, 0), 1) }

    var body: some View {
        // Kupa yerine dolgunun yuzdesi. Kupa hicbir seye karsilik gelmiyordu;
        // rozetin anlatmak istedigi zaten bir sonraki seviyeye ne kadar
        // kaldigi ve o sayi arkadaki dolguyu da okunur kiliyor.
        HStack(spacing: 6) {
            Text("LV \(level)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.accent.opacity(0.65))
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(palette.accent.opacity(0.12))
                GeometryReader { geometry in
                    let fill = geometry.size.width * progress
                    // Isik dolgunun bittigi yerde bitsin: tarama rozetin
                    // tamamini gezerse ilerlemeyi degil rozeti anlatir.
                    //
                    // Kirpma dolgunun kendi kapsul sekliyle yapilir. Dikdortgen
                    // kirpma, yuvarlak ucun uzerinde duz bir cizgi birakiyordu.
                    Capsule(style: .continuous)
                        .fill(palette.accent.opacity(0.22))
                        .frame(width: fill)
                        .overlay {
                            if active && !reduceMotion { BadgeSweep() }
                        }
                        .clipShape(Capsule(style: .continuous))
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).stroke(palette.accent.opacity(0.26), lineWidth: 1)
            }
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
    }
}

private struct BadgeSweep: UIViewRepresentable {
    func makeUIView(context: Context) -> BadgeSweepLayerView { BadgeSweepLayerView() }
    func updateUIView(_ view: BadgeSweepLayerView, context: Context) {}
    static func dismantleUIView(_ view: BadgeSweepLayerView, coordinator: ()) { view.stop() }
}

private final class BadgeSweepLayerView: UIView {
    private let band = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        band.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.45).cgColor, UIColor.clear.cgColor]
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(band)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(6, bounds.width * 0.5)
        let frame = CGRect(x: -width, y: 0, width: width, height: bounds.height)
        if band.frame != frame {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            band.frame = frame
            CATransaction.commit()
            stop()
        }
        startIfVisible()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } else { startIfVisible() }
    }

    func stop() { band.removeAllAnimations() }

    private func startIfVisible() {
        guard window != nil, bounds.width > 0, band.animation(forKey: "sweep") == nil else { return }
        // Gradient sabit kalir; yalnizca konum render sunucusunda hareket eder.
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, 0, bounds.width + band.bounds.width]
        animation.keyTimes = [0, 0.7, 1]
        animation.duration = 6
        animation.repeatCount = .infinity
        band.add(animation, forKey: "sweep")
    }
}
