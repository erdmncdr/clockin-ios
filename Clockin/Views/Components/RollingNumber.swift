import Foundation

enum RollDirection: Equatable {
    case up, down, none

    static func between(_ old: Double, _ new: Double) -> Self {
        guard old.isFinite, new.isFinite, old != new else { return .none }
        return new > old ? .up : .down
    }
}

struct RollingNumberSample: Equatable {
    let text: String
    let value: Double
}

struct RollingNumberCell: Identifiable, Equatable {
    // Sagdan kimlik, basamak eklenince birler hanesini korur.
    let id: Int
    let character: Character
    let previous: Character?

    var rolls: Bool { previous != nil }
}

struct RollingNumberUpdate: Equatable {
    let cells: [RollingNumberCell]
    let direction: RollDirection
    let lengthChanged: Bool

    init(from old: RollingNumberSample, to new: RollingNumberSample) {
        let before = Array(old.text)
        let after = Array(new.text)
        let lengthChanged = before.count != after.count
        let direction = RollDirection.between(old.value, new.value)
        self.lengthChanged = lengthChanged
        self.direction = direction
        cells = after.enumerated().map { index, character in
            let previous = lengthChanged ? nil : before[index]
            let rolls = direction != .none && previous != character
                && previous?.isNumber == true && character.isNumber
            return RollingNumberCell(id: after.count - index - 1, character: character,
                                     previous: rolls ? previous : nil)
        }
    }
}

func rollingAnimationAllowed(reduceMotion: Bool, lowPower: Bool,
                             thermalState: ProcessInfo.ThermalState,
                             contentActive: Bool, sceneActive: Bool, visible: Bool) -> Bool {
    guard !reduceMotion, !lowPower, contentActive, sceneActive, visible else { return false }
    switch thermalState {
    case .nominal, .fair: return true
    case .serious, .critical: return false
    @unknown default: return false
    }
}
