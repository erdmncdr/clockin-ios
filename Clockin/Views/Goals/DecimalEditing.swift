import CoreGraphics
import Foundation

enum GoalField: Hashable {
    case daily, monthly
}

struct DecimalEditingSession {
    private(set) var isEditing = false

    mutating func begin() { isEditing = true }

    mutating func end() -> Bool {
        guard isEditing else { return false }
        isEditing = false
        return true
    }

    static func shouldDismiss(isEditing: Bool, at point: CGPoint, fieldFrames: [CGRect]) -> Bool {
        isEditing && !fieldFrames.contains { $0.contains(point) }
    }
}
