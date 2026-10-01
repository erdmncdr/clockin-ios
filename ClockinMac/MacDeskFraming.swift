import Foundation

/// 360x240 oda; tavandan en fazla 26 kaynak pikseli kirpilir.
/// 16:9'da gorunen y araligi 26...228.5: pencere ve ayaklar korunur.
enum MacDeskFraming {
    static func roomSize(in screen: CGSize) -> CGSize {
        let scale = max(screen.width / 360, screen.height / 240)
        return CGSize(width: 360 * scale, height: 240 * scale)
    }

    static func topCrop(in screen: CGSize) -> CGFloat {
        let size = roomSize(in: screen)
        return min(max(0, size.height - screen.height), 26 * size.height / 240)
    }
}
