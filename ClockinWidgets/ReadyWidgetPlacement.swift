import Foundation

struct ReadyWidgetPlacement {
    static let companionWidth: CGFloat = 80
    static let spacing: CGFloat = 8
    let textWidth: CGFloat
    let centerX: CGFloat

    init(contentWidth: CGFloat, textWidth: CGFloat) {
        let leading = Self.companionWidth + Self.spacing
        self.textWidth = min(max(0, textWidth), max(0, contentWidth - leading))
        // Ortayi koru; yalniz gorselle cakisan miktar kadar saga kaydir.
        centerX = max(contentWidth / 2, leading + self.textWidth / 2)
    }
}
