import Foundation

struct WardrobeSkinEffects: Codable, Sendable, Equatable {
    let sheen: String
    let aura: String
    let auraColors: [String]
    let glow: String
}

struct WardrobeSkinPiece: Codable, Sendable {
    let id: String
    let anchorPoint: String
    let pivot: WardrobePoint
    let layer: String
    let poseOffsets: [String: WardrobePoint]?
    let motion: String?
    let omittedFrames: [String]?
}

struct WardrobeSkin: Codable, Sendable {
    let id: String
    let name: String
    /// Rank key for a complete HD render. Missing in legacy pixel manifests.
    let hd: String?
    var hdStyle: ArmorHDStyle? {
        guard let hd, let stage = Self.rankKeys.firstIndex(of: hd) else { return nil }
        return .rank(stage)
    }
    static let rankKeys = ["spark", "orbit", "nebula", "solar", "nova", "aurora", "sovereign", "celestial", "eternal"]
    let material: WardrobeColorway
    let hidesAntenna: Bool
    let pieces: [WardrobeSkinPiece]
    let effects: WardrobeSkinEffects
}

enum WardrobeSkins {
    private struct Manifest: Decodable, Sendable {
        let skins: [String: WardrobeSkin]
        let shoulders: [String: [String: WardrobePoint]]
    }
    private static let manifest = WardrobeArt.read(Manifest.self, "skins.json", folder: "Skins")
    static let all: [String: WardrobeSkin] = manifest?.skins ?? [:]
    static let shoulders: [String: [String: WardrobePoint]] = manifest?.shoulders ?? [:]

    static func isHD(_ outfit: WardrobeState) -> Bool { skin(for: outfit)?.hdStyle != nil }

    static func skin(for outfit: WardrobeState) -> WardrobeSkin? {
        outfit.equipped[WardrobeSlot.skin.rawValue].flatMap { all[$0] }
    }

    static func placement(_ piece: WardrobeSkinPiece, frame: String, anchors: WardrobeAnchors) -> WardrobePoint? {
        guard piece.omittedFrames?.contains(frame) != true else { return nil }
        guard ["front", "back"].contains(piece.layer) else { return nil }
        let point = piece.anchorPoint.hasPrefix("shoulder")
            ? shoulders[frame]?[piece.anchorPoint] : anchors.point(piece.anchorPoint)
        guard let point else { return nil }
        let offset = piece.poseOffsets?[frame] ?? piece.poseOffsets?[String(frame.prefix(1))] ?? .init(0, 0)
        return WardrobeGeometry.origin(pivot: piece.pivot, anchor: .init(point.x + offset.x, point.y + offset.y),
                                       degrees: piece.anchorPoint == "head" ? anchors.tilt : 0)
    }
}

extension WardrobeState {
    /// The colours the robot frames are drawn in: the worn skin's id, else the colorway.
    var look: String { WardrobeSkins.skin(for: self)?.id ?? colorway }
}
