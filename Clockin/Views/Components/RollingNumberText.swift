import SwiftUI
import UIKit

struct RollingNumberText: View {
    let text: String
    let value: Double
    let font: Font
    let design: Font.Design?
    let foregroundColor: Color

    @Environment(\.self) private var environment
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.clockinContentActive) private var contentActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @ObservedObject private var policy = RollingAnimationPolicy.shared

    init(_ text: String, value: Double, font: Font, design: Font.Design? = nil,
         foregroundColor: Color = .primary) {
        self.text = text
        self.value = value
        self.font = font
        self.design = design
        self.foregroundColor = foregroundColor
    }

    private var canAnimate: Bool {
        policy.allowsAnimation(reduceMotion: reduceMotion, contentActive: contentActive,
                               sceneActive: scenePhase == .active, visible: visible)
    }

    var body: some View {
        let uiFont = RollingNumberFont.resolve(font, design: design ?? palette.fontDesign,
                                               sizeCategory: environment.sizeCategory)
        let color = foregroundColor.resolve(in: environment)
        let uiColor = UIColor(red: CGFloat(color.red), green: CGFloat(color.green),
                              blue: CGFloat(color.blue), alpha: CGFloat(color.opacity))
        let layout = RollingNumberFont.layout(text, font: uiFont)
        let minimumScaleFactor = environment.minimumScaleFactor
        RollingNumberRepresentable(sample: .init(text: text, value: value), font: uiFont,
                                   color: uiColor, layout: layout, canAnimate: canAnimate,
                                   minimumScaleFactor: minimumScaleFactor)
            .alignmentGuide(.firstTextBaseline) { dimensions in
                layout.baseline(in: CGSize(width: dimensions.width, height: dimensions.height),
                                minimum: minimumScaleFactor)
            }
            .alignmentGuide(.lastTextBaseline) { dimensions in
                layout.baseline(in: CGSize(width: dimensions.width, height: dimensions.height),
                                minimum: minimumScaleFactor)
            }
            .onAppear {
                policy.refresh()
                visible = true
            }
            .onDisappear { visible = false }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { policy.refresh() }
            }
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}

private struct RollingNumberRepresentable: UIViewRepresentable {
    let sample: RollingNumberSample
    let font: UIFont
    let color: UIColor
    let layout: RollingNumberLayout
    let canAnimate: Bool
    let minimumScaleFactor: CGFloat

    func makeUIView(context: Context) -> RollingNumberUIView {
        RollingNumberUIView()
    }

    func updateUIView(_ uiView: RollingNumberUIView, context: Context) {
        uiView.update(sample: sample, font: font, color: color, layout: layout,
                      canAnimate: canAnimate, minimumScaleFactor: minimumScaleFactor)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: RollingNumberUIView,
                     context: Context) -> CGSize? {
        uiView.fittingSize(width: proposal.width)
    }

    static func dismantleUIView(_ uiView: RollingNumberUIView, coordinator: ()) {
        uiView.stopAnimations()
    }
}
