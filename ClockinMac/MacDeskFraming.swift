import Foundation
import CoreGraphics

/// 360x240 oda; tavandan en fazla 26 kaynak pikseli kirpilir.
/// 16:9'da gorunen y araligi 26...228.5: pencere ve ayaklar korunur.
enum MacDeskFraming {
    static let timerSize = CGSize(width: 600, height: 260)

    /// Ust duvar bolgesi; alt kenar varsayilan masanin y=104 ustunden yukarida.
    static func timerPanel(in screen: CGSize) -> CGRect {
        let scale = max(0, min(1, (screen.width - 48) / timerSize.width,
                              screen.height * 0.28 / timerSize.height))
        let size = CGSize(width: timerSize.width * scale, height: timerSize.height * scale)
        return CGRect(x: (screen.width - size.width) / 2, y: screen.height * 0.06,
                      width: size.width, height: size.height)
    }

    static func roomSize(in screen: CGSize) -> CGSize {
        let scale = max(screen.width / 360, screen.height / 240)
        return CGSize(width: 360 * scale, height: 240 * scale)
    }

    static func topCrop(in screen: CGSize) -> CGFloat {
        let size = roomSize(in: screen)
        return min(max(0, size.height - screen.height), 26 * size.height / 240)
    }
}
