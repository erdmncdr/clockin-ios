import SwiftUI

struct RollingNumberText: View {
    let text: String
    let value: Double
    let font: Font
    let design: Font.Design?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.clockinContentActive) private var contentActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var update: RollingNumberUpdate
    @State private var revision: UInt64 = 0
    @ObservedObject private var policy = RollingAnimationPolicy.shared

    init(_ text: String, value: Double, font: Font, design: Font.Design? = nil) {
        self.text = text
        self.value = value
        self.font = font
        self.design = design
        let sample = RollingNumberSample(text: text, value: value)
        _update = State(initialValue: RollingNumberUpdate(from: sample, to: sample))
    }

    private var sample: RollingNumberSample { RollingNumberSample(text: text, value: value) }

    private var canAnimate: Bool {
        policy.allowsAnimation(reduceMotion: reduceMotion, contentActive: contentActive,
                               sceneActive: scenePhase == .active, visible: visible)
    }

    private var glyphs: some View {
        HStack(spacing: 0) {
            ForEach(update.cells) { cell in
                if cell.character.isNumber {
                    Text(String(cell.character))
                        .hidden()
                        .overlay {
                            GeometryReader { geometry in
                                if canAnimate, let previous = cell.previous {
                                    RollingGlyphPair(previous: previous, current: cell.character,
                                                     direction: update.direction, height: geometry.size.height)
                                        .id(revision)
                                } else {
                                    Text(String(cell.character))
                                }
                            }
                        }
                        .clipped()
                        .accessibilityHidden(true)
                } else {
                    Text(String(cell.character))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    var body: some View {
        Group {
            if let design {
                glyphs.fontDesign(design)
            } else {
                // nil fontDesign ustteki tema fontunu siler; burada miras korunur.
                glyphs
            }
        }
        .font(font)
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .onAppear {
            policy.refresh()
            snapToCurrent()
            visible = true
        }
        .onDisappear {
            visible = false
            snapToCurrent()
        }
        .onChange(of: sample) { old, new in
            guard old.text != new.text else { return }
            update = RollingNumberUpdate(from: canAnimate ? old : new, to: new)
            revision &+= 1
        }
        .onChange(of: canAnimate) { _, _ in snapToCurrent() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { policy.refresh() }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private func snapToCurrent() {
        update = RollingNumberUpdate(from: sample, to: sample)
        revision &+= 1
    }
}

private struct RollingGlyphPair: View {
    let previous: Character
    let current: Character
    let direction: RollDirection
    let height: CGFloat
    @State private var settled = false

    private var travel: CGFloat { direction == .up ? -height : height }

    var body: some View {
        // numericText/contentTransition blur'u CPU'da cizer; yalnizca konum ve alfa degisir.
        ZStack {
            Text(String(previous))
                .offset(y: settled ? travel : 0)
                .opacity(settled ? 0 : 1)
            Text(String(current))
                .offset(y: settled ? 0 : -travel)
                .opacity(settled ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.25), value: settled)
        // Timeline kapali kalir; sadece bu iki glif kendi animasyonunu acar.
        .transaction { $0.disablesAnimations = false }
        .onAppear { settled = true }
    }
}
