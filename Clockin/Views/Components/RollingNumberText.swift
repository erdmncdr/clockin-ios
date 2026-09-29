import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct RollingNumberText: View {
    let text: String
    let value: Double
    let font: Font
    let design: Font.Design?
    let foregroundColor: Color
    #if os(macOS)
    /// Menu cubugu ve sabit sayac serbest boyut kullanir; tarif tablosu
    /// yalnizca paylasilan ekranlarin yazi tiplerini bilir.
    var explicit: (size: CGFloat, weight: Font.Weight)? = nil
    #endif

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
        #if os(macOS)
        let uiFont = explicit.map { RollingNumberFont.resolve(size: $0.size, weight: $0.weight, design: design ?? palette.fontDesign) }
            ?? RollingNumberFont.resolve(font, design: design ?? palette.fontDesign, sizeCategory: environment.sizeCategory)
        #else
        let uiFont = RollingNumberFont.resolve(font, design: design ?? palette.fontDesign,
                                               sizeCategory: environment.sizeCategory)
        #endif
        let color = foregroundColor.resolve(in: environment)
        let uiColor = PlatformColor(red: CGFloat(color.red), green: CGFloat(color.green),
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

#if canImport(UIKit)
private struct RollingNumberRepresentable: UIViewRepresentable {
    let sample: RollingNumberSample
    let font: UIFont
    let color: PlatformColor
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
#else
private struct RollingNumberRepresentable: NSViewRepresentable {
    let sample: RollingNumberSample
    let font: NSFont
    let color: PlatformColor
    let layout: RollingNumberLayout
    let canAnimate: Bool
    let minimumScaleFactor: CGFloat

    func makeNSView(context: Context) -> RollingNumberUIView {
        RollingNumberUIView()
    }

    func updateNSView(_ nsView: RollingNumberUIView, context: Context) {
        nsView.update(sample: sample, font: font, color: color, layout: layout,
                      canAnimate: canAnimate, minimumScaleFactor: minimumScaleFactor)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: RollingNumberUIView,
                     context: Context) -> CGSize? {
        nsView.fittingSize(width: proposal.width)
    }

    static func dismantleNSView(_ nsView: RollingNumberUIView, coordinator: ()) {
        nsView.stopAnimations()
    }
}
#endif
