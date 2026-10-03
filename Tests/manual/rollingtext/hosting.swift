import AppKit
import SwiftUI

// Match the SDK harness's explicit State-wrapper alias. Only unrelated theme
// and visibility environment boundaries are substituted; the rolling view,
// representable, font resolver, animation policy and native renderer are real.
typealias RollingTestState<Value> = SwiftUI.State<Value>
typealias PlatformColor = NSColor
struct RollingTestPalette { var fontDesign: Font.Design = .default }
private struct RollingPaletteKey: EnvironmentKey { static let defaultValue = RollingTestPalette() }
private struct RollingActiveKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var palette: RollingTestPalette {
        get { self[RollingPaletteKey.self] }
        set { self[RollingPaletteKey.self] = newValue }
    }
    var clockinContentActive: Bool {
        get { self[RollingActiveKey.self] }
        set { self[RollingActiveKey.self] = newValue }
    }
}

@main struct HostingChecks {
    @MainActor static func main() {
        var checks = 0
        func check(_ value: Bool, _ name: String) {
            guard value else { print("FAILED: \(name)"); exit(1) }
            checks += 1
        }
        func descendants(_ view: NSView) -> [RollingNumberUIView] {
            (view as? RollingNumberUIView).map { [$0] } ?? view.subviews.flatMap(descendants)
        }
        // Reproduce the old SwiftUI placeholder's actual metrics, not an assumed
        // ASCII/Unicode ratio. The native rolling font is intentionally unchanged.
        var oldSize = CGSize.zero
        ImageRenderer(content: Text(verbatim: "$10,00 kaldı")
            .font(.caption.weight(.semibold)).monospacedDigit()).render { size, _ in oldSize = size }
        let actual = RollingNumberFont.layout("$1,36 kaldı", font: RollingNumberFont.resolve(
            .caption.weight(.semibold), design: .default, sizeCategory: .large)).naturalSize
        print("Mac repro: SwiftUI placeholder \(oldSize); rolling actual \(actual)")

        for design: Font.Design in [.default, .rounded, .serif, .monospaced] {
            for alignment: Alignment in [.leading, .trailing] {
                for (reservation, text) in [
                    ("$10,00 kaldı", "$1,36 kaldı"), ("$10.00 to go", "$1.36 to go"),
                    ("$10,00 kaldı", "₺1.234.567.890,99 kaldı"),
                    ("$10.00 to go", "$1,234,567,890.99 to go")
                ] {
                    // The sizing composition used by MomentumRemainingLabel.
                    let host = NSHostingView(rootView: ZStack(alignment: alignment) {
                        RollingNumberText(reservation, value: 0, font: .caption.weight(.semibold), design: design)
                            .hidden().accessibilityHidden(true)
                        RollingNumberText(text, value: 1.36, font: .caption.weight(.semibold), design: design)
                    })
                    let font = RollingNumberFont.resolve(.caption.weight(.semibold), design: design, sizeCategory: .large)
                    let reserve = RollingNumberFont.layout(reservation, font: font).naturalSize
                    let live = RollingNumberFont.layout(text, font: font).naturalSize
                    let fitting = host.fittingSize
                    check(fitting.width >= max(reserve.width, live.width) && fitting.height >= live.height,
                          "momentum reserves the larger native size")
                    host.frame = CGRect(origin: .zero, size: fitting)
                    host.layoutSubtreeIfNeeded()
                    let rendered = descendants(host).filter { $0.accessibilityLabel() == text }
                    check(rendered.count == 1, "one live countdown representable")
                    let view = rendered[0]
                    let rect = view.convert(view.bounds, to: host)
                    check(rect.minX >= -0.01 && rect.maxX <= fitting.width + 0.01,
                          "live countdown is inside the complete reservation")
                    check(alignment == .trailing ? abs(rect.maxX - fitting.width) < 0.01 : abs(rect.minX) < 0.01,
                          "leading/trailing alignment places the full native bounds")
                }
            }
            // ViewThatFits must see the scale floor so a narrow row can stack.
            let font = RollingNumberFont.resolve(.caption, design: design, sizeCategory: .large)
            let text = "Hedefe ulaşıldı"
            let natural = RollingNumberFont.layout(text, font: font).naturalSize.width
            let host = NSHostingView(rootView: ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Color.clear.frame(width: 60, height: 10)
                    RollingNumberText(text, value: 0, font: .caption, design: design)
                }
                RollingNumberText(text, value: 0, font: .caption, design: design)
            }.frame(width: natural + 10))
            host.frame = CGRect(origin: .zero, size: host.fittingSize)
            host.layoutSubtreeIfNeeded()
            let rendered = descendants(host)
            check(rendered.count == 1, "one ViewThatFits alternative renders")
            let rect = rendered[0].convert(rendered[0].bounds, to: host)
            check(rect.minX >= -0.01 && rect.maxX <= host.bounds.width + 0.01,
                  "narrow row chooses the fitting alternative")
        }
        print("\(checks) rolling SwiftUI hosting checks passed")
    }
}
