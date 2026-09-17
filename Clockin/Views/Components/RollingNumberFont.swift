import SwiftUI
import UIKit

// Font kapali bir tip; kullanim yerlerinin eslemeleri burada acik tutulur.
enum RollingNumberFont {
    private struct Recipe {
        let font: Font
        let style: UIFont.TextStyle?
        let size: CGFloat
        let weight: UIFont.Weight
    }

    private static let recipes: [Recipe] = [
        .init(font: .headline, style: .headline, size: 17, weight: .semibold),
        .init(font: .caption, style: .caption1, size: 12, weight: .regular),
        .init(font: .caption.weight(.semibold), style: .caption1, size: 12, weight: .semibold),
        .init(font: .subheadline.weight(.semibold), style: .subheadline, size: 15, weight: .semibold),
        .init(font: .subheadline.weight(.bold), style: .subheadline, size: 15, weight: .bold),
        .init(font: .title.weight(.semibold), style: .title1, size: 28, weight: .semibold),
        .init(font: .title3, style: .title3, size: 20, weight: .regular),
        .init(font: .title3.weight(.semibold), style: .title3, size: 20, weight: .semibold),
        .init(font: .system(size: 60, weight: .medium), style: nil, size: 60, weight: .medium),
        .init(font: .system(size: 120, weight: .medium), style: nil, size: 120, weight: .medium)
    ]

    static func resolve(_ font: Font, design: Font.Design, sizeCategory: ContentSizeCategory) -> UIFont {
        guard let recipe = recipes.first(where: { $0.font == font }) else {
            preconditionFailure("Add an explicit RollingNumberFont recipe for this font")
        }
        let uiDesign: UIFontDescriptor.SystemDesign
        switch design {
        case .rounded: uiDesign = .rounded
        case .serif: uiDesign = .serif
        case .monospaced: uiDesign = .monospaced
        default: uiDesign = .default
        }
        let base = UIFont.monospacedDigitSystemFont(ofSize: recipe.size, weight: recipe.weight)
        let descriptor = (base.fontDescriptor.withDesign(uiDesign) ?? base.fontDescriptor)
            .addingAttributes([.featureSettings: [
                [UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                 UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]
            ]])
        let designed = UIFont(descriptor: descriptor, size: recipe.size)
        // Sabit boyutlu iki sayac SwiftUI'daki gibi sabit kalir.
        guard let style = recipe.style else { return designed }
        return UIFontMetrics(forTextStyle: style).scaledFont(
            for: designed, compatibleWith: UITraitCollection(preferredContentSizeCategory: sizeCategory.uiKit))
    }

    static func layout(_ text: String, font: UIFont) -> RollingNumberLayout {
        // Ayni glif bir deger icinde bir kez olculur.
        var advances: [Character: CGFloat] = [:]
        let widths = text.map { character in
            if let width = advances[character] { return width }
            let width = (String(character) as NSString).size(withAttributes: [.font: font]).width
            advances[character] = width
            return width
        }
        return RollingNumberLayout(widths: widths, lineHeight: font.lineHeight, ascender: font.ascender)
    }
}

private extension ContentSizeCategory {
    var uiKit: UIContentSizeCategory {
        switch self {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
        case .accessibilityMedium: return .accessibilityMedium
        case .accessibilityLarge: return .accessibilityLarge
        case .accessibilityExtraLarge: return .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}
