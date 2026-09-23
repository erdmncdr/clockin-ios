import SwiftUI

struct CompanionCategoryTabs: View {
    @Binding var selection: WardrobeCategory?
    let accent: Color
    let surface: Color

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tab(nil, title: String(localized: "All"), symbol: "square.grid.2x2")
                    ForEach(WardrobeCategory.allCases) { category in
                        tab(category, title: category.title, symbol: category.symbol)
                    }
                }
            }
            .onChange(of: selection) { _, category in
                proxy.scrollTo(category?.id ?? "all", anchor: .center)
            }
        }
        .accessibilityIdentifier("companion.categories")
    }

    private func tab(_ category: WardrobeCategory?, title: String, symbol: String) -> some View {
        let selected = selection == category
        return Button { selection = category } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? accent : .primary)
                .background(selected ? accent.opacity(0.15) : surface, in: Capsule())
                .overlay { Capsule().strokeBorder(selected ? accent : .clear, lineWidth: 1.5) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("companion.category.\(category?.id ?? "all")")
        .id(category?.id ?? "all")
    }
}

/// Room cards follow the artwork's 3:2 canvas instead of letterboxing it.
struct CompanionPreviewFrame: ViewModifier {
    let isHome: Bool
    let outfitHeight: CGFloat

    func body(content: Content) -> some View {
        if isHome {
            content.aspectRatio(3.0 / 2.0, contentMode: .fit)
        } else {
            content.frame(height: outfitHeight)
        }
    }
}
