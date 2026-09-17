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

struct RollingNumberRenderState {
    private(set) var sample: RollingNumberSample?
    private(set) var allowsAnimation = false

    mutating func update(to new: RollingNumberSample, allowsAnimation allowed: Bool,
                         reset: Bool = false) -> RollingNumberUpdate? {
        let old = sample
        let snap = reset || allowed != allowsAnimation || old == nil || !allowed
        let needsUpdate = reset || allowed != allowsAnimation || old?.text != new.text
        // Metin ayni kalsa da sonraki yon icin sayisal deger guncellenir.
        sample = new
        allowsAnimation = allowed
        guard needsUpdate else { return nil }
        return RollingNumberUpdate(from: snap ? new : (old ?? new), to: new)
    }
}

struct RollingNumberLayout {
    let widths: [CGFloat]
    let lineHeight: CGFloat
    let ascender: CGFloat

    var naturalSize: CGSize {
        CGSize(width: ceil(widths.reduce(0, +)), height: widths.isEmpty ? 0 : ceil(lineHeight))
    }

    func scale(width: CGFloat, minimum: CGFloat) -> CGFloat {
        guard naturalSize.width > 0 else { return 1 }
        return max(minimum, min(1, width / naturalSize.width))
    }

    func baseline(in size: CGSize, minimum: CGFloat) -> CGFloat {
        guard !widths.isEmpty else { return 0 }
        let scale = scale(width: size.width, minimum: minimum)
        return (size.height - lineHeight * scale) / 2 + ascender * scale
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
