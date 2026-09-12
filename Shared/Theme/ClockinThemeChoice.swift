import Foundation

enum ClockinThemeChoice: String, CaseIterable, Identifiable, Codable, Sendable {
    case carbon = "Carbon"
    case neonOrange = "Neon Orange"
    case electricBlue = "Electric Blue"
    case synthwave = "Synthwave"
    case dataDense = "Data Dense"
    case aurora = "Aurora"
    case terminalAmber = "Terminal Amber"
    case daylight = "Daylight"

    var id: String { rawValue }

    static func selected(_ rawValue: String) -> ClockinThemeChoice {
        ClockinThemeChoice(rawValue: rawValue) ?? .carbon
    }

    // Yeni bir surumun tema adi eski uzantida tum ozeti bozmasin.
    init(from decoder: any Decoder) throws {
        self = Self.selected(try decoder.singleValueContainer().decode(String.self))
    }
}
