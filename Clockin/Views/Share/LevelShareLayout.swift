import Foundation

/// The image shared from the level-up card: a story for Instagram and
/// WhatsApp status, or a shorter post for a feed or a chat. Points; the image
/// is rendered at 3x, so 1080 × 1920 and 1080 × 1350.
enum LevelShareFormat: String, CaseIterable, Identifiable {
    case story = "Story", post = "Post"
    var id: Self { self }
    var title: String { String(localized: String.LocalizationValue(rawValue), bundle: .app) }
    var size: CGSize {
        switch self {
        case .story: CGSize(width: 360, height: 640)
        case .post: CGSize(width: 360, height: 450)
        }
    }
}

/// What the level-up card knew when Share was pressed. Taken at that moment,
/// so a session that goes on running does not change the image.
struct LevelShareSnapshot: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let hours: Int
    let xp: Int
    let streak: Int
    let date: Date
    /// The companion setting: it stands on the stage as on the card.
    let companion: Bool
}

enum LevelShareLayout {
    /// The companion's stage is taller; it only fits the story.
    static func showsCompanion(_ format: LevelShareFormat, enabled: Bool) -> Bool {
        enabled && format == .story
    }

    /// The stage keeps the card's own heights, so the crest is drawn as there.
    static func stageHeight(_ format: LevelShareFormat, companion: Bool) -> CGFloat {
        showsCompanion(format, enabled: companion) ? 396 : 300
    }

    /// A streak worth mentioning: two days or more.
    static func showsStreak(_ streak: Int) -> Bool { streak >= 2 }
}
