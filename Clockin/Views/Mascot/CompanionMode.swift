import Foundation

/// Maskotun sabit davranisi. `Auto` disindaki secenekler toplam calisma
/// suresiyle aciliyor.
///
/// Bu isimler once iki yerde duz metindi: ayarlardaki secici onlari yaziyor,
/// `ClockinMascotStage` okuyor. Bir taraftaki yazim degisse digeri hata
/// vermeden Auto'ya duserdi, o yuzden tek kaynak burasi.
enum CompanionMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case typing = "Typing"
    case coffee = "Coffee"
    case victory = "Victory"
    case stretch = "Stretch"
    case dance = "Dance"
    case music = "Music"

    var id: String { rawValue }

    /// Bu modun acilmasi icin gereken toplam sure. Mac ile ayni esikler.
    var requiredHours: Double {
        switch self {
        case .auto, .typing, .coffee: 0
        case .victory: 10
        case .stretch: 25
        case .dance: 50
        case .music: 100
        }
    }

    func isUnlocked(totalHours: Double) -> Bool { totalHours >= requiredHours }

    /// Kilitli bir secim Auto'ya duser. Kayitli deger taninmiyorsa da ayni:
    /// eski ya da bozuk bir tercih maskotu kirmasin.
    static func resolve(_ stored: String, totalHours: Double) -> CompanionMode {
        guard let mode = CompanionMode(rawValue: stored),
              mode.isUnlocked(totalHours: totalHours) else { return .auto }
        return mode
    }

    /// Kilitli secenek listede esigiyle birlikte gorunur, secilemez.
    func menuLabel(totalHours: Double) -> String {
        isUnlocked(totalHours: totalHours) ? rawValue : "🔒 \(rawValue) · \(Int(requiredHours))h"
    }

    /// Sabit poz gorselinin sirasi. `auto` oturumu takip ettigi icin,
    /// `typing` ve `coffee` de kareli animasyon oldugu icin pozu yok.
    var fixedPoseIndex: Int? {
        switch self {
        case .auto, .typing, .coffee: nil
        case .victory: 1
        case .stretch: 2
        case .dance: 3
        case .music: 4
        }
    }
}
