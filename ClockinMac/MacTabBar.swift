import SwiftUI

struct MacTabBar: View {
    static let height: CGFloat = 64
    static let clearance: CGFloat = height + 16
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: MacSection?
    @Namespace private var selectionAnimation
    @State private var hoveredSection: MacSection?

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                GlassEffectContainer(spacing: 4) {
                    tabs.glassEffect(.regular.interactive(), in: .capsule)
                }
            } else {
                tabs
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
            }
        }
        .frame(maxWidth: 320)
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            tab(.today, title: "Today", symbol: "timer")
            tab(.history, title: "History", symbol: "chart.bar.xaxis")
            tab(.progress, title: "Progress", symbol: "chart.line.uptrend.xyaxis")
        }
        .padding(6)
        .frame(height: Self.height)
    }

    private func tab(_ section: MacSection, title: LocalizedStringKey, symbol: String) -> some View {
        let selected = (selection ?? .today) == section
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { selection = section }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18, weight: .medium)).frame(height: 20)
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(selected ? palette.accent : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected {
                    if #available(macOS 26, *) {
                        Capsule().fill(.clear)
                            .glassEffect(.regular.tint(palette.accent.opacity(0.22)).interactive(), in: .capsule)
                            .glassEffectID("selection", in: selectionAnimation)
                    } else {
                        Capsule().fill(palette.accent.opacity(0.16))
                            .matchedGeometryEffect(id: "selection", in: selectionAnimation)
                    }
                }
            }
            .background {
                Capsule().fill(.primary.opacity(hoveredSection == section ? 0.06 : 0))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in hoveredSection = hovering ? section : nil }
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
