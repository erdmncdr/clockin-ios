import SwiftUI

struct MacTabBar: View {
    static let height: CGFloat = 64
    static let clearance: CGFloat = height + 16
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: MacSection?

    private var selectionIndex: CGFloat {
        switch selection ?? .today {
        case .history: 1
        case .progress: 2
        default: 0
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            tab(.today, title: "Today", symbol: "timer")
            tab(.history, title: "History", symbol: "chart.bar.xaxis")
            tab(.progress, title: "Progress", symbol: "chart.line.uptrend.xyaxis")
        }
        .padding(6)
        .frame(height: Self.height)
        .background {
            // Tek kalici secim mercegi; olcum State'e yazilmaz, cubuk boyunu etkilemez.
            GeometryReader { geometry in
                let width = max(0, (geometry.size.width - 20) / 3)
                selectionGlass
                    .frame(width: width, height: Self.height - 12)
                    .offset(x: 6 + selectionIndex * (width + 4), y: 6)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: selectionIndex)
            }
            .allowsHitTesting(false)
        }
        .background {
            if #available(macOS 26, *) {
                Capsule().fill(.clear).glassEffect(.clear.interactive(), in: .capsule)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .frame(maxWidth: 320)
    }

    @ViewBuilder private var selectionGlass: some View {
        if #available(macOS 26, *) {
            Capsule().fill(.white.opacity(0.10))
                .glassEffect(.clear, in: .capsule)
                .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
        } else {
            Capsule().fill(.primary.opacity(0.10))
                .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
        }
    }

    private func tab(_ section: MacSection, title: LocalizedStringKey, symbol: String) -> some View {
        let selected = (selection ?? .today) == section
        return Button {
            guard selection != section else { return }
            selection = section
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18, weight: .medium)).frame(height: 20)
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(selected ? palette.accent : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .macHoverFeedback()
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
