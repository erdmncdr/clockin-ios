import Foundation

struct WardrobeSkinEffects: Codable, Sendable, Equatable {
    let sheen: String
    let aura: String
    let auraColors: [String]
    let glow: String
}

struct WardrobeSkin: Codable, Sendable {
    let id: String
    let name: String
    /// Material key; design selects the independently authored silhouette.
    let hd: String?
    let design: String
    var hdStyle: ArmorHDStyle? {
        guard let hd, let shape = ArmorHDDesign.named(design) else { return nil }
        var style: ArmorHDStyle?
        if design == "paladin", let stage = Self.rankKeys.firstIndex(of: hd) { style = .rank(stage) }
        else { style = .named(hd) }
        style?.design = shape
        return style
    }
    static let rankKeys = ["spark", "orbit", "nebula", "solar", "nova", "aurora", "sovereign", "celestial", "eternal"]
    let hidesAntenna: Bool
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
}

extension WardrobeState {
    /// The colours the robot frames are drawn in: the worn skin's id, else the colorway.
    var look: String { WardrobeSkins.skin(for: self)?.id ?? colorway }
}
