import Foundation

struct WardrobeColorRule: Codable, Sendable {
    let kind: String
    let hue: [Double]
    let saturation: [Double]
    let luminance: [Double]
    let targets: [String]
}

struct WardrobeColorway: Codable, Sendable {
    let name: String
    let identity: Bool
    let rules: [WardrobeColorRule]
}

enum WardrobePalette {
    static func rgb(_ hex: String) -> UInt32? {
        guard hex.count == 7, hex.first == "#" else { return nil }
        return UInt32(hex.dropFirst(), radix: 16)
    }

    private struct Tone {
        let h: Double, s: Double, l: Double
        init(_ r: Double, _ g: Double, _ b: Double) {
            let hi = max(r, g, b), lo = min(r, g, b), delta = hi - lo
            l = (hi + lo) / 2
            s = delta == 0 ? 0 : delta / (1 - abs(2 * l - 1))
            var angle = 0.0
            if delta > 0 {
                if hi == r { angle = (g - b) / delta }
                else if hi == g { angle = (b - r) / delta + 2 }
                else { angle = (r - g) / delta + 4 }
            }
            h = (angle * 60 + 360).truncatingRemainder(dividingBy: 360)
        }
        init(hex: UInt32) {
            self.init(Double((hex >> 16) & 255) / 255, Double((hex >> 8) & 255) / 255, Double(hex & 255) / 255)
        }
        static func channels(h: Double, s: Double, l: Double) -> [Double] {
            let c = (1 - abs(2 * l - 1)) * s
            let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
            let m = l - c / 2
            let values: [Double]
            switch h {
            case ..<60: values = [c, x, 0]
            case ..<120: values = [x, c, 0]
            case ..<180: values = [0, c, x]
            case ..<240: values = [0, x, c]
            case ..<300: values = [x, 0, c]
            default: values = [c, 0, x]
            }
            return values.map { max(0, min(1, $0 + m)) }
        }
    }

    // Duz RGBA girer; alfa ve vizor tonlari aynen kalir.
    static func recolor(_ rgba: inout [UInt8], colorway: WardrobeColorway) {
        guard !colorway.identity else { return }
        let rules = colorway.rules.compactMap { rule -> (WardrobeColorRule, Tone, Tone)? in
            guard rule.hue.count == 2, rule.saturation.count == 2, rule.luminance.count == 2,
                  (rule.hue + rule.saturation + rule.luminance).allSatisfy(\.isFinite),
                  rule.luminance[1] > rule.luminance[0], rule.targets.count == 2,
                  let a = rgb(rule.targets[0]), let b = rgb(rule.targets[1]) else { return nil }
            return (rule, Tone(hex: a), Tone(hex: b))
        }
        for i in stride(from: 0, to: rgba.count - rgba.count % 4, by: 4) where rgba[i + 3] > 0 {
            let r = Double(rgba[i]), g = Double(rgba[i + 1]), b = Double(rgba[i + 2])
            let hi = max(r, g, b), lo = min(r, g, b)
            guard hi >= 80 else { continue }
            let tone = Tone(r / 255, g / 255, b / 255)
            let saturation = (hi - lo) / hi
            let shellLuminance = (r + g + b) / 3
            for (rule, a, z) in rules {
                let luminance = ["glow", "accents"].contains(rule.kind) ? hi : shellLuminance
                let inHue = rule.hue[0] <= rule.hue[1]
                    ? (rule.hue[0]...rule.hue[1]).contains(tone.h)
                    : tone.h >= rule.hue[0] || tone.h <= rule.hue[1]
                guard inHue, saturation >= rule.saturation[0], saturation <= rule.saturation[1],
                      luminance >= rule.luminance[0], luminance <= rule.luminance[1] else { continue }
                // Pikselin aralik icindeki aydinligi hedef rampada korunur.
                let t = (luminance - rule.luminance[0]) / (rule.luminance[1] - rule.luminance[0])
                let dh = (z.h - a.h + 540).truncatingRemainder(dividingBy: 360) - 180
                let h = (a.h + dh * t + 360).truncatingRemainder(dividingBy: 360)
                let channels = Tone.channels(h: h, s: a.s + (z.s - a.s) * t, l: a.l + (z.l - a.l) * t)
                for channel in 0..<3 { rgba[i + channel] = UInt8((channels[channel] * 255).rounded()) }
                break
            }
        }
    }
}
