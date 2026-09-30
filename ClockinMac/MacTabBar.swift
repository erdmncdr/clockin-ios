import SwiftUI

struct MacTabBar: View {
    @Environment(\.palette) private var palette
    @Binding var selection: MacSection?
    @State private var hoveredSection: MacSection?

    var body: some View {
        HStack(spacing: 4) {
            tab(.today, title: "Today", symbol: "timer")
            tab(.history, title: "History", symbol: "chart.bar.xaxis")
            tab(.progress, title: "Progress", symbol: "chart.line.uptrend.xyaxis")
            tab(.settings, title: "Settings", symbol: "gearshape")
        }
        .padding(6)
        // Leaves room for the inset's margins at the 390-point window minimum.
        .frame(maxWidth: 344)
        .modifier(MacTabBarBackground())
    }

    private func tab(_ section: MacSection, title: LocalizedStringKey, symbol: String) -> some View {
        let isSelected = (selection ?? .today) == section
        let isHovered = hoveredSection == section

        return Button {
            selection = section
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? palette.accent : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected
                          ? palette.accent.opacity(isHovered ? 0.20 : 0.12)
                          : Color.primary.opacity(isHovered ? 0.07 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredSection = section
            } else if hoveredSection == section {
                hoveredSection = nil
            }
        }
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MacTabBarBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
        }
    }
}
