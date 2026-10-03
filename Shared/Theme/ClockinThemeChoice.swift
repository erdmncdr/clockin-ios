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

/// Typography is independent of the color theme. No legacy theme migration.
enum ClockinFontChoice: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case rounded = "Rounded"
    case serif = "Serif"
    case monospaced = "Monospaced"

    static let preferenceKey = "Clockin.Font"
    var id: String { rawValue }

    static func selected(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .system
    }

    init(from decoder: any Decoder) throws {
        self = Self.selected(try decoder.singleValueContainer().decode(String.self))
    }
}
