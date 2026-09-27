import Foundation
import AVFoundation
import Accelerate
import AppKit

let sampleRate = 44_100.0
let hushStart = LevelUpTiming.impact - LevelUpTiming.hush
let impact = LevelUpTiming.wall(LevelUpTiming.impact)
let fadeStart = LevelUpTiming.wall(LevelUpTiming.impact + 0.35)
let fadeEnd = LevelUpTiming.wall(LevelUpTiming.impact + 1.5)
let rankTime = LevelUpTiming.wall(LevelUpTiming.rankReveal)
let peakLimit = pow(10.0, -1.05 / 20)

enum Design: String, CaseIterable {
    case a, b, c, f, g
    /// The design the app plays. The others stay here to compare against.
    static let shipped = Design.g
    /// Whether the shipped design is A's dark (minor) variant; A is rendered
    /// with both its heroic and dark weight to compare.
    static let shippedDark = false
    var name: String {
        switch self {
        case .a: "Cinematic"
        case .b: "Arcane"
        case .c: "Arcade power-up"
        case .f: "Dark, remastered"
        case .g: "Storm"
        }
    }
    var seed: UInt64 {
        switch self {
        case .a: 0xC10C_A001
        case .b: 0xC10C_B002
        case .c: 0xC10C_C003
        case .f: 0xC10C_F006
        case .g: 0xC10C_6007
        }
    }
}

struct Noise {
    var seed: UInt64
    mutating func unit() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 11) / Double(UInt64.max >> 11)
    }
    mutating func next() -> Double { unit() * 2 - 1 }
}

struct Stereo {
    var left: [Double]
    var right: [Double]
    init(seconds: Double) {
        left = .init(repeating: 0, count: Int((seconds * sampleRate).rounded()))
        right = left
    }
    var count: Int { left.count }
    var duration: Double { Double(count) / sampleRate }
    var mono: [Double] { zip(left, right).map { ($0 + $1) * 0.5 } }
    mutating func add(_ value: Double, at i: Int, pan: Double) {
        let angle = (pan + 1) * .pi / 4
        left[i] += value * cos(angle)
        right[i] += value * sin(angle)
    }
    mutating func mix(_ other: Stereo, gain: Double = 1) {
        for i in 0..<min(count, other.count) {
            left[i] += other.left[i] * gain
            right[i] += other.right[i] * gain
        }
    }
}

func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func smooth(_ x: Double) -> Double { let u = clamp(x); return u * u * (3 - 2 * u) }
func db(_ x: Double) -> Double { 20 * log10(max(x, 1e-12)) }
func gain(_ x: Double) -> Double { pow(10, x / 20) }
func envelope(_ t: Double, _ duration: Double, attack: Double = 0.002, release: Double = 0.02) -> Double {
    guard t >= 0 && t < duration else { return 0 }
    return smooth(t / attack) * smooth((duration - t) / release)
}
func light(_ time: Double) -> Double {
    smooth((time - impact) / 0.18) * (1 - smooth((time - fadeStart) / (fadeEnd - fadeStart)))
}

struct Biquad {
    var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var z1 = 0.0, z2 = 0.0
    mutating func tune(_ kind: String, _ frequency: Double, q: Double = 0.707) {
        let w = 2 * .pi * min(frequency, sampleRate * 0.45) / sampleRate
        let c = cos(w), alpha = sin(w) / (2 * q), a0 = 1 + alpha
        switch kind {
        case "high": b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0
        case "band": b0 = alpha; b1 = 0; b2 = -alpha
        default: b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0
        }
        b0 /= a0; b1 /= a0; b2 /= a0
        a1 = -2 * c / a0; a2 = (1 - alpha) / a0
    }
    mutating func tick(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}

func blep(_ phase: Double, _ step: Double) -> Double {
    if phase < step { let t = phase / step; return t + t - t * t - 1 }
    if phase > 1 - step { let t = (phase - 1) / step; return t * t + t + t + 1 }
    return 0
}
func saw(_ phase: Double, _ step: Double) -> Double { 2 * phase - 1 - blep(phase, step) }
func square(_ phase: Double, _ step: Double) -> Double {
    (phase < 0.5 ? 1.0 : -1.0) + blep(phase, step) - blep((phase + 0.5).truncatingRemainder(dividingBy: 1), step)
}
func triangle(_ phase: Double, _ frequency: Double) -> Double {
    var value = 0.0
    for n in stride(from: 1, through: 15, by: 2) where Double(n) * frequency < sampleRate * 0.45 {
        value += (n % 4 == 1 ? 1 : -1) * sin(2 * .pi * Double(n) * phase) / Double(n * n)
    }
    return value * 8 / (.pi * .pi)
}

func event(_ buffer: inout Stereo, start: Double, duration: Double, pan: Double = 0,
           render: (Double, Int) -> Double) {
    let begin = Int((start * sampleRate).rounded())
    let length = Int((duration * sampleRate).rounded())
    for j in 0..<length {
        let i = begin + j
        if i >= 0 && i < buffer.count { buffer.add(render(Double(j) / sampleRate, j), at: i, pan: pan) }
    }
}

func thump(_ buffer: inout Stereo, start: Double, strength: Double, design: Design, large: Bool = false, sub: Bool = true) {
    let duration = large ? (design == .c ? 0.65 : 1.1) : 0.145
    let high = large ? 72.0 : (design == .c ? 150.0 : (design == .b ? 78.0 : 95.0))
    let low = large ? 30.0 : (design == .c ? 45.0 : 48.0)
    let tau = large ? 0.095 : 0.022
    event(&buffer, start: start, duration: duration) { t, _ in
        let phase = 2 * .pi * (low * t + (high - low) * tau * (1 - exp(-t / tau)))
        // Finite harmonics give small speakers body without nonlinear aliasing.
        let bass = sub ? (sin(phase) + 0.32 * sin(3 * phase) + 0.13 * sin(5 * phase)) : 0
        let body = 0.8 * cos(2 * .pi * (large ? 175 : 205) * t) * exp(-t / (large ? 0.11 : 0.035))
            + 0.35 * cos(2 * .pi * 360 * t) * exp(-t / 0.028)
        let click = (design == .b ? 0.24 : 0.4) * cos(2 * .pi * (design == .b ? 650 : 1600) * t) * exp(-t / 0.003)
        return strength * envelope(t, duration, attack: 0.0008) *
            (bass * exp(-t / (large ? 0.22 : 0.046)) + body + click)
    }
}

func bell(_ buffer: inout Stereo, start: Double, frequency: Double, strength: Double,
          duration: Double = 0.6, pan: Double = 0, glass: Bool = false) {
    let ratios = glass ? [1.0, 1.413, 2.071, 2.731] : [1.0, 2.002, 3.0, 4.01]
    let levels = [1.0, 0.27, 0.1, 0.045]
    event(&buffer, start: start, duration: duration, pan: pan) { t, _ in
        var value = 0.0
        for p in ratios.indices where frequency * ratios[p] < sampleRate * 0.43 {
            value += levels[p] * sin(2 * .pi * frequency * ratios[p] * t)
                * exp(-t / (duration * 0.28 / (1 + Double(p) * 0.5)))
        }
        return value * strength * envelope(t, duration, attack: 0.003, release: 0.05)
    }
}

func charge(_ design: Design, seconds: Double) -> Stereo {
    var buffer = Stereo(seconds: seconds)
    var random = Noise(seed: design.seed)
    var phaseL = 0.0, phaseR = 0.23, subPhase = 0.0, tremolo = 0.0, vibrato = 0.0
    var lowL = Biquad(), lowR = Biquad(), riser = Biquad()
    var formantsL = [Biquad](repeating: Biquad(), count: 3), formantsR = formantsL
    for j in 0..<3 {
        formantsL[j].tune("band", [700.0, 1220, 2600][j], q: [3.0, 5, 7][j])
        formantsR[j].tune("band", [709.0, 1208, 2620][j], q: [3.0, 5, 7][j])
    }
    for i in 0..<Int(hushStart * sampleRate) {
        let t = Double(i) / sampleRate, u = clamp(t / hushStart)
        let glide = clamp((t - 0.2) / (hushStart - 0.2))
        let frequency: Double
        switch design {
        case .a: frequency = 55 * pow(2, glide)
        case .b: frequency = 110 * pow(2, glide)
        case .c: frequency = 110 * pow(8, glide)
        case .f, .g: preconditionFailure("Drawn by synthesizeRich")
        }
        tremolo += (3 + 11 * u * u) / sampleRate
        vibrato += (4 + 13 * u) / sampleRate
        let f = frequency * (1 + (design == .c ? 0.012 : 0.002) * sin(2 * .pi * vibrato))
        let stepL = f * 0.997 / sampleRate, stepR = f * 1.003 / sampleRate
        phaseL = (phaseL + stepL).truncatingRemainder(dividingBy: 1)
        phaseR = (phaseR + stepR).truncatingRemainder(dividingBy: 1)
        subPhase = (subPhase + f * 0.5 / sampleRate).truncatingRemainder(dividingBy: 1)
        if i % 32 == 0 {
            lowL.tune("low", 250 * pow(2400 / 250, glide)); lowR = copyCoefficients(lowL, to: lowR)
            riser.tune("band", 300 * pow(5000 / 300, glide), q: 0.8)
        }
        let noise = riser.tick(random.next())
        var l = 0.0, r = 0.0
        switch design {
        case .a:
            l = 0.8 * lowL.tick(saw(phaseL, stepL)); r = 0.8 * lowR.tick(saw(phaseR, stepR))
            let sub = 0.13 * sin(2 * .pi * subPhase)
            l += sub + noise * 0.65 * u; r += sub + noise * 0.55 * u
        case .b:
            let a = saw(phaseL, stepL), b = saw(phaseR, stepR)
            for j in 0..<3 {
                let weight = [2.3, 1.7, 0.95][j]
                l += formantsL[j].tick(a) * weight; r += formantsR[j].tick(b) * weight
            }
            let modulation = 0.7 + 0.3 * sin(2 * .pi * tremolo)
            l = l * modulation + 0.3 * noise; r = r * modulation - 0.23 * noise
        case .c:
            l = 0.36 * square(phaseL, stepL) + 0.5 * triangle(phaseL, f)
            r = 0.36 * square(phaseR, stepR) + 0.5 * triangle(phaseR, f)
        case .f, .g: preconditionFailure("Drawn by synthesizeRich")
        }
        // Brief anticipation dips leave each haptic pulse audible in the dense charge.
        var duck = 1.0
        for pulse in LevelUpTiming.pulses {
            let dt = t - pulse
            if dt >= -0.016 && dt < 0 { duck *= 1 - 0.94 * smooth((dt + 0.016) / 0.01) }
            if dt >= 0 && dt < 0.03 { duck *= 0.06 + 0.94 * smooth(dt / 0.03) }
            if design == .c && dt >= 0.032 && dt < 0.065 { duck *= 0.12 + 0.88 * smooth((dt - 0.032) / 0.033) }
        }
        let amplitude = gain(-28 + 25 * pow(u, 1.75)) * smooth(t / 0.08) * duck
        buffer.left[i] = l * amplitude; buffer.right[i] = r * amplitude
    }
    for (j, pulse) in LevelUpTiming.pulses.enumerated() {
        thump(&buffer, start: LevelUpTiming.wall(pulse), strength: 0.18 + Double(j) * 0.049, design: design)
        if design == .c {
            var high = Biquad(); high.tune("high", 5500)
            event(&buffer, start: pulse, duration: 0.035, pan: 0.2) { t, _ in
                0.12 * high.tick(random.next()) * envelope(t, 0.035, attack: 0.001) * exp(-t / 0.008)
            }
        }
    }
    for (j, strike) in LevelUpTiming.strikes.filter({ $0 < hushStart }).enumerated() {
        let strength = (0.026 + 0.10 * pow(strike / hushStart, 2))
        let pan = random.next() * 0.9
        switch design {
        case .a:
            // Windowed microbursts make crackle rather than discontinuous impulses.
            for _ in 0..<7 {
                let start = strike + random.unit() * 0.092
                var high = Biquad(); high.tune("high", 2500)
                event(&buffer, start: start, duration: 0.007, pan: pan) { t, _ in
                    high.tick(random.next()) * strength * envelope(t, 0.007, attack: 0.0006, release: 0.004)
                }
            }
        case .b:
            let carrier = 1200 + 1800 * random.unit()
            event(&buffer, start: strike, duration: 0.06, pan: pan) { t, _ in
                let index = 2.2 * exp(-t / 0.013)
                return strength * sin(2 * .pi * carrier * t + index * sin(2 * .pi * 347 * t))
                    * envelope(t, 0.06, attack: 0.0015) * exp(-t / 0.018)
            }
        case .c:
            var held = 0.0, low = Biquad(); low.tune("low", 7200)
            event(&buffer, start: strike, duration: 0.065, pan: pan) { t, i in
                if i % (5 + j % 5) == 0 { held = (random.next() * 7).rounded() / 7 }
                return low.tick(held) * strength * envelope(t, 0.065) * exp(-t / 0.023)
            }
        case .f, .g: preconditionFailure("Drawn by synthesizeRich")
        }
    }
    for i in buffer.left.indices {
        let t = Double(i) / sampleRate
        let stop = smooth((hushStart - t) / 0.012)
        buffer.left[i] *= stop; buffer.right[i] *= stop
    }
    if design == .b {
        var band = Biquad(); band.tune("band", 2200, q: 0.6)
        event(&buffer, start: impact - 0.15, duration: 0.15) { t, _ in
            band.tick(random.next()) * 0.36 * pow(t / 0.15, 2) * envelope(t, 0.15, attack: 0.02, release: 0.003)
        }
    }
    return buffer
}

func copyCoefficients(_ source: Biquad, to destination: Biquad) -> Biquad {
    var result = source
    result.z1 = destination.z1; result.z2 = destination.z2
    return result
}

func explosion(_ buffer: inout Stereo, at start: Double, design: Design, rank: Bool, random: inout Noise) {
    let strength = rank ? 0.46 : 0.9
    thump(&buffer, start: start, strength: strength, design: design, large: true, sub: !rank)
    var high = Biquad(); high.tune("high", 2100)
    var low = Biquad(); low.tune("low", design == .c ? 7600 : 11000)
    var held = 0.0
    event(&buffer, start: start, duration: design == .c ? 0.42 : 0.2) { t, i in
        if i % 6 == 0 { held = (random.next() * 15).rounded() / 15 }
        let noise = design == .c ? low.tick(held) : low.tick(high.tick(random.next()))
        return noise * (rank ? 0.7 : 1.35) * envelope(t, design == .c ? 0.42 : 0.2, attack: 0.001)
            * exp(-t / (design == .c ? 0.075 : 0.04))
    }
    if design != .c {
        var bandL = Biquad(), bandR = Biquad()
        let duration = rank ? 0.35 : 0.7
        event(&buffer, start: start, duration: duration, pan: -0.6) { t, i in
            if i % 32 == 0 { bandL.tune("band", 7000 * pow(0.1, t / duration), q: 0.65) }
            return bandL.tick(random.next()) * strength * 1.15 * envelope(t, duration, attack: 0.005, release: 0.18) * exp(-t / 0.25)
        }
        event(&buffer, start: start + 0.003, duration: duration, pan: 0.6) { t, i in
            if i % 32 == 0 { bandR.tune("band", 6700 * pow(0.1, t / duration), q: 0.65) }
            return bandR.tick(random.next()) * strength * envelope(t, duration, attack: 0.005, release: 0.18) * exp(-t / 0.25)
        }
    }
    if design == .b {
        for _ in 0..<28 {
            let offset = random.unit() * 0.15
            let f = 2400 + random.unit() * 7000
            let pan = random.next()
            bell(&buffer, start: start + offset, frequency: f, strength: rank ? 0.022 : 0.048,
                 duration: 0.07 + random.unit() * 0.1, pan: pan, glass: true)
        }
    }
}

func pad(_ buffer: inout Stereo, start: Double, duration: Double, notes: [Double], strength: Double,
         design: Design, followsLight: Bool, attack: Double = 0.18) {
    for (j, f) in notes.enumerated() {
        let pan = notes.count == 1 ? 0 : Double(j) / Double(notes.count - 1) * 1.5 - 0.75
        event(&buffer, start: start, duration: duration, pan: pan) { t, _ in
            let vibrato = design == .c ? 0.6 * sin(2 * .pi * 5.5 * t) : 0.0
            var value = 0.0
            for n in 1...(design == .b ? 20 : 6) where Double(n) * f * 1.003 < sampleRate * 0.43 {
                let frequency = Double(n) * f
                var weight = 1 / pow(Double(n), design == .c ? 1.7 : 2.1)
                if design == .b {
                    weight = (0.1 + 2.0 * exp(-pow((frequency - 700) / 190, 2))
                        + 1.5 * exp(-pow((frequency - 1220) / 240, 2))
                        + 0.55 * exp(-pow((frequency - 2600) / 360, 2))) / Double(n)
                }
                value += weight * (sin(2 * .pi * frequency * 0.9985 * t + vibrato)
                    + sin(2 * .pi * frequency * 1.0015 * t + vibrato)) * 0.5
            }
            let shape = followsLight ? light(start + t) : envelope(t, duration, attack: attack, release: min(0.65, duration * 0.6))
            return strength * value * shape * envelope(t, duration, attack: attack, release: 0.12)
        }
    }
}

/// A brass-like chord that lands with the weight of the strike: saws through
/// a filter that snaps open with the blow and slowly closes, three detuned
/// voices a note, softly saturated.
func braam(_ buffer: inout Stereo, start: Double, duration: Double, notes: [Double], strength: Double,
           followsLight: Bool, dark: Bool, swell: Double = 0.035) {
    for (j, f) in notes.enumerated() {
        let pan = notes.count == 1 ? 0 : Double(j) / Double(notes.count - 1) * 1.1 - 0.55
        event(&buffer, start: start, duration: duration, pan: pan) { t, _ in
            let open = (1 - exp(-t / 0.03)) * exp(-t / 0.85)
            let cutoff = (dark ? 130 : 170) + (dark ? 1300 : 2000) * open + 420 * (followsLight ? light(start + t) : exp(-t / 0.7))
            var value = 0.0
            for n in 1...48 {
                let harmonic = Double(n) * f
                guard harmonic * 1.004 < sampleRate * 0.43 else { break }
                let weight = 1 / Double(n) / sqrt(1 + pow(harmonic / cutoff, 4))
                guard weight > 0.0003 else { break }
                for d in [0.996, 1.0, 1.004] { value += weight * sin(2 * .pi * harmonic * d * t + Double(n) * d * 1.7) }
            }
            let shape = followsLight ? light(start + t) : exp(-t / 0.9)
            return strength * shape * envelope(t, duration, attack: swell, release: 0.35) * 1.4 * tanh(value / 2.2)
        }
    }
}

/// A deep gong: inharmonic partials whose upper ones bloom just after the
/// hit, the way a tam-tam swells, then ring out.
func gong(_ buffer: inout Stereo, start: Double, duration: Double, base: Double, strength: Double) {
    let ratios = [1.0, 1.51, 2.03, 2.58, 3.17, 3.91, 4.62, 5.37, 6.24, 7.33]
    for (p, ratio) in ratios.enumerated() {
        let pan = (p.isMultiple(of: 2) ? -1.0 : 1.0) * 0.4 * Double(p) / Double(ratios.count)
        event(&buffer, start: start, duration: duration, pan: pan) { t, _ in
            let bloom = p < 3 ? 1 : smooth(t / (0.08 + 0.04 * Double(p)))
            let ring = exp(-t / (1.4 / (1 + Double(p) * 0.22)))
            let beat = 1 + 0.18 * sin(2 * .pi * (0.6 + 0.35 * Double(p)) * t)
            return strength / (1 + Double(p) * 0.4) * bloom * ring * beat * sin(2 * .pi * base * ratio * t + Double(p))
                * envelope(t, duration, attack: 0.003, release: 0.45)
        }
    }
}

/// What falls after a blast: a low rumble that settles and a few dull knocks.
func rubble(_ buffer: inout Stereo, start: Double, duration: Double, strength: Double, random: inout Noise) {
    var low = Biquad()
    low.tune("low", 240)
    event(&buffer, start: start, duration: duration) { t, i in
        if i % 64 == 0 { low.tune("low", 240 - 120 * clamp(t / duration)) }
        return strength * 1.6 * low.tick(random.next()) * smooth(t / 0.05) * exp(-t / 0.55) * envelope(t, duration, release: 0.3)
    }
    for k in 0..<8 {
        let offset = 0.14 + random.unit() * 0.8
        let high = 150 + random.unit() * 70, pan = random.next() * 0.7
        let level = strength * (0.55 - 0.035 * Double(k)) * (1 - offset / 1.1)
        event(&buffer, start: start + offset, duration: 0.12, pan: pan) { t, _ in
            let phase = 2 * .pi * (70 * t + (high - 70) * 0.02 * (1 - exp(-t / 0.02)))
            return level * (sin(phase) + 0.3 * sin(2 * phase)) * exp(-t / 0.035) * envelope(t, 0.12, attack: 0.001)
        }
    }
}

func reward(_ buffer: inout Stereo, design: Design, rank: Bool, random: inout Noise, dark: Bool = false) {
    let start = rank ? 0.0 : impact
    let duration = rank ? 1.55 : fadeEnd - impact
    let c = [523.251, 659.255, 783.991, 1046.502]
    if rank {
        switch design {
        case .a:
            // The new rank lands a step higher: the chord rises a fifth, on G.
            let notes = dark ? [48.999, 97.999, 146.832, 233.082] : [48.999, 97.999, 146.832, 195.998]
            braam(&buffer, start: 0.01, duration: 1.5, notes: notes, strength: 0.2, followsLight: false, dark: dark, swell: 0.06)
            gong(&buffer, start: 0, duration: 1.5, base: 97.999, strength: dark ? 0.2 : 0.14)
            rubble(&buffer, start: 0, duration: 1.1, strength: 0.08, random: &random)
        case .b:
            let scale = [440.0, 493.883, 554.365, 659.255, 739.989, 880, 987.767, 1108.731, 1318.51, 1479.978, 1760]
            for (i, f) in scale.enumerated() {
                bell(&buffer, start: Double(i) * 0.04, frequency: f, strength: 0.18, duration: 0.65, pan: Double(i) / 10 * 1.5 - 0.75)
            }
            pad(&buffer, start: 0.25, duration: 1.3, notes: [880, 1108.731, 1318.51, 1760], strength: 0.16, design: design, followsLight: false)
        case .c:
            for (i, f) in [1046.502, 1318.51, 1567.982, 2093.005].enumerated() {
                bell(&buffer, start: Double(i) * 0.055, frequency: f, strength: 0.24, duration: 0.65, pan: Double(i) * 0.3 - 0.45)
            }
            bell(&buffer, start: 0.23, frequency: 2637.02, strength: 0.13, duration: 0.45)
            bell(&buffer, start: 0.30, frequency: 3951.066, strength: 0.10, duration: 0.4)
            pad(&buffer, start: 0.15, duration: 1.25, notes: c.map { $0 * 2 }, strength: 0.08, design: design, followsLight: false, attack: 0.03)
        case .f, .g: preconditionFailure("Drawn by synthesizeRich")
        }
    } else {
        switch design {
        case .a:
            // Weight after the blow: a low power chord, minor when dark, a
            // gong under it and the rubble settling.
            let notes = dark ? [65.406, 97.999, 130.813, 155.563, 195.998] : [65.406, 97.999, 130.813, 195.998]
            braam(&buffer, start: start + 0.015, duration: duration + 0.3, notes: notes, strength: 0.24, followsLight: true, dark: dark)
            gong(&buffer, start: start, duration: duration + 0.3, base: 65.406, strength: dark ? 0.26 : 0.17)
            rubble(&buffer, start: start, duration: 1.4, strength: 0.12, random: &random)
        case .b:
            pad(&buffer, start: start, duration: 0.54, notes: [440, 587.33, 659.255], strength: 0.30, design: design, followsLight: true, attack: 0.13)
            pad(&buffer, start: start + 0.27, duration: duration - 0.27, notes: [440, 554.365, 659.255, 880], strength: 0.28, design: design, followsLight: true, attack: 0.12)
            for (i, f) in [440.0, 554.365, 659.255, 880].enumerated() {
                bell(&buffer, start: start + 0.30 + Double(i) * 0.018, frequency: f, strength: 0.13, duration: 0.95, pan: Double(i) * 0.4 - 0.6)
            }
        case .c:
            for (i, f) in c.enumerated() {
                bell(&buffer, start: start + Double(i) * 0.07, frequency: f, strength: 0.28, duration: 0.65, pan: Double(i) * 0.3 - 0.45)
            }
            pad(&buffer, start: start + 0.20, duration: duration - 0.20, notes: c, strength: 0.15, design: design, followsLight: true, attack: 0.04)
        case .f, .g: preconditionFailure("Drawn by synthesizeRich")
        }
    }
    if design == .b {
        let notes = [1760.0, 2217.461, 2637.02, 3520]
        for _ in 0..<(rank ? 12 : 24) {
            let offset = 0.07 + random.unit() * (rank ? 0.6 : fadeStart - impact + 0.22)
            let f = notes[Int(random.unit() * Double(notes.count)) % notes.count]
            let pan = random.next() * 0.95
            bell(&buffer, start: start + offset, frequency: f, strength: 0.025 + 0.022 * random.unit(), duration: 0.28, pan: pan)
        }
    }
}

struct Comb {
    var memory: [Double]
    var index = 0
    var damped = 0.0
    let feedback: Double
    mutating func tick(_ input: Double) -> Double {
        let output = memory[index]
        damped = output * 0.62 + damped * 0.38
        memory[index] = input + feedback * damped
        index = (index + 1) % memory.count
        return output
    }
}
struct Allpass {
    var memory: [Double]
    var index = 0
    mutating func tick(_ input: Double) -> Double {
        let delayed = memory[index]
        let output = delayed - 0.5 * input
        memory[index] = input + 0.5 * output
        index = (index + 1) % memory.count
        return output
    }
}

func reverberate(_ dry: Stereo, design: Design) -> Stereo {
    var wet = Stereo(seconds: dry.duration)
    let decay = design == .c ? 0.42 : (design == .a ? 1.25 : 1.05)
    for channel in 0..<2 {
        let spread = channel * 23
        var combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map { length in
            Comb(memory: .init(repeating: 0, count: length + spread),
                 feedback: pow(0.001, Double(length + spread) / sampleRate / decay))
        }
        var diffusers = [556, 441, 341, 225].map { Allpass(memory: .init(repeating: 0, count: $0 + spread)) }
        let predelay = Int((design == .c ? 0.008 : 0.022) * sampleRate)
        for i in 0..<dry.count {
            let k = i - predelay
            let input = k >= 0 ? (dry.left[k] + dry.right[k]) * 0.15 : 0
            var value = 0.0
            for j in combs.indices { value += combs[j].tick(input) / 8 }
            for j in diffusers.indices { value = diffusers[j].tick(value) }
            if channel == 0 { wet.left[i] = value } else { wet.right[i] = value }
        }
    }
    return wet
}

func master(_ input: Stereo, design: Design, isRankBeat: Bool) -> Stereo {
    var output = input
    var highL = Biquad(), highR = Biquad()
    highL.tune("high", 25); highR.tune("high", 25)
    var detector = 0.0, compression = 1.0
    let attack = exp(-1 / (0.008 * sampleRate)), release = exp(-1 / (0.12 * sampleRate))
    for i in 0..<input.count {
        let l = highL.tick(input.left[i]), r = highR.tick(input.right[i])
        let level = max(abs(l), abs(r))
        detector = max(level, detector * release)
        let over = max(0, db(detector) + 12)
        let desired = gain(-over * (1 - 1 / 1.65))
        let coefficient = desired < compression ? attack : release
        compression = desired + coefficient * (compression - desired)
        output.left[i] = l * compression * 1.28
        output.right[i] = r * compression * 1.28
    }
    // Stereo-linked lookahead gain never advances the audio's onset.
    let lookahead = 128
    var future = [Double](repeating: 0, count: output.count)
    var deque = [Int](repeating: 0, count: output.count), head = 0, tail = 0
    for i in stride(from: output.count - 1, through: 0, by: -1) {
        while head < tail && deque[head] > i + lookahead { head += 1 }
        let p = max(abs(output.left[i]), abs(output.right[i]))
        while head < tail && max(abs(output.left[deque[tail - 1]]), abs(output.right[deque[tail - 1]])) <= p { tail -= 1 }
        deque[tail] = i; tail += 1
        future[i] = max(abs(output.left[deque[head]]), abs(output.right[deque[head]]))
    }
    var limiting = 1.0
    for i in 0..<output.count {
        let target = min(1, peakLimit / max(future[i], 1e-12))
        limiting = min(target, limiting + (1 - limiting) * 0.001)
        let t = Double(i) / sampleRate
        let remaining = Double(output.count - 1 - i) / sampleRate
        var taper = smooth(t / 0.0005) * pow(smooth(remaining / 0.20), 2)
        if !isRankBeat {
            // The charge's filter state cannot leak into the deliberate silence.
            let quietEnd = design == .b ? impact - 0.15 : impact
            if t >= hushStart && t < quietEnd { taper = 0 }
            if t >= hushStart - 0.002 && t < hushStart { taper *= smooth((hushStart - t) / 0.002) }
        }
        output.left[i] *= limiting * taper
        output.right[i] *= limiting * taper
    }
    return output
}

func synthesize(_ design: Design, dark: Bool = false) -> (Stereo, Stereo) {
    if design == .f || design == .g { return synthesizeRich(design) }
    let length = impact + 1.8
    var dry = Stereo(seconds: length)
    var random = Noise(seed: design.seed &+ 0x1234)
    explosion(&dry, at: impact, design: design, rank: false, random: &random)
    reward(&dry, design: design, rank: false, random: &random, dark: dark)
    let wet = reverberate(dry, design: design)
    dry.mix(wet, gain: design == .c ? 0.2 : 0.95)
    dry.mix(charge(design, seconds: length))
    let level = master(dry, design: design, isRankBeat: false)
    var second = Stereo(seconds: 1.8)
    random = Noise(seed: design.seed &+ 0x5678)
    explosion(&second, at: 0, design: design, rank: true, random: &random)
    reward(&second, design: design, rank: true, random: &random, dark: dark)
    second.mix(reverberate(second, design: design), gain: design == .c ? 0.16 : 0.8)
    second = master(second, design: design, isRankBeat: true)
    var rank = Stereo(seconds: rankTime + 1.8)
    rank.mix(level)
    let offset = Int((rankTime * sampleRate).rounded())
    for i in 0..<second.count where i + offset < rank.count {
        rank.left[i + offset] += second.left[i]; rank.right[i + offset] += second.right[i]
    }
    return (level, rank)
}

func writeWAV(_ audio: Stereo, to url: URL) throws {
    var data = Data()
    func word<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    func tag(_ text: String) { data.append(contentsOf: text.utf8) }
    tag("RIFF"); word(UInt32(36 + audio.count * 4)); tag("WAVEfmt ")
    word(UInt32(16)); word(UInt16(1)); word(UInt16(2)); word(UInt32(sampleRate))
    word(UInt32(sampleRate * 4)); word(UInt16(4)); word(UInt16(16))
    tag("data"); word(UInt32(audio.count * 4))
    for i in 0..<audio.count {
        precondition(abs(audio.left[i]) <= peakLimit + 1e-9 && abs(audio.right[i]) <= peakLimit + 1e-9)
        word(Int16((audio.left[i] * 32767).rounded()))
        word(Int16((audio.right[i] * 32767).rounded()))
    }
    try data.write(to: url)
}

func readWAV(_ url: URL, expectedDuration: Double) throws -> Stereo {
    let file = try AVAudioFile(forReading: url)
    let description = file.fileFormat.streamDescription.pointee
    precondition(description.mSampleRate == sampleRate && description.mChannelsPerFrame == 2)
    precondition(description.mFormatID == kAudioFormatLinearPCM && description.mBitsPerChannel == 16)
    precondition(abs(Double(file.length) / sampleRate - expectedDuration) < 1 / sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    precondition(buffer.frameLength == AVAudioFrameCount(file.length))
    var result = Stereo(seconds: expectedDuration)
    for i in 0..<result.count {
        result.left[i] = Double(buffer.floatChannelData![0][i])
        result.right[i] = Double(buffer.floatChannelData![1][i])
    }
    return result
}

func rms(_ audio: Stereo, _ start: Double, _ end: Double) -> Double {
    let begin = max(0, Int((start * sampleRate).rounded()))
    let finish = min(audio.count, Int((end * sampleRate).rounded()))
    guard finish > begin else { return 0 }
    var sum = 0.0
    for i in begin..<finish { sum += audio.left[i] * audio.left[i] + audio.right[i] * audio.right[i] }
    return sqrt(sum / Double(2 * (finish - begin)))
}

func powers(_ samples: [Double], size: Int) -> [Double] {
    let setup = vDSP_DFT_zop_CreateSetupD(nil, vDSP_Length(size), .FORWARD)!
    defer { vDSP_DFT_DestroySetupD(setup) }
    let zero = [Double](repeating: 0, count: size)
    var input = zero, real = zero, imaginary = zero
    for i in 0..<min(size, samples.count) {
        input[i] = samples[i]
    }
    vDSP_DFT_ExecuteD(setup, input, zero, &real, &imaginary)
    return (0..<size / 2).map { real[$0] * real[$0] + imaginary[$0] * imaginary[$0] }
}

func phoneFraction(_ audio: Stereo) -> Double {
    let first = Int((impact * sampleRate).rounded()), last = Int(((impact + 0.3) * sampleRate).rounded())
    let l = powers(Array(audio.left[first..<last]), size: 16384)
    let r = powers(Array(audio.right[first..<last]), size: 16384)
    var high = 0.0, total = 0.0
    for i in l.indices {
        let energy = l[i] + r[i]
        total += energy
        if Double(i) * sampleRate / 16384 > 150 { high += energy }
    }
    return high / total
}

func onset(_ audio: Stereo, near expected: Double, isolated: Bool = false) -> Double {
    // Detect a local rise in a 0.75 ms causal energy envelope from decoded PCM.
    let window = 33
    let begin = max(window, Int((expected - 0.012) * sampleRate))
    let end = min(audio.count, Int((expected + 0.014) * sampleRate))
    var energies = [Double]()
    for i in begin..<end {
        var sum = 0.0
        for k in (i - window + 1)...i { sum += audio.left[k] * audio.left[k] + audio.right[k] * audio.right[k] }
        energies.append(sqrt(sum / Double(2 * window)))
    }
    let baseline = rms(audio, expected - 0.009, expected - 0.003)
    let peak = energies.max()!
    let threshold = isolated ? max(gain(-52), peak * 0.08) : max(baseline * 2.2, peak * 0.23)
    precondition(peak > threshold, "No distinct audio onset near \(expected): baseline \(db(baseline)), peak \(db(peak))")
    var below = 0
    for i in energies.indices {
        if energies[i] < threshold {
            below += 1
        } else {
            if below >= Int(0.0025 * sampleRate) { return Double(begin + i) / sampleRate }
            below = 0
        }
    }
    preconditionFailure("No onset near \(expected)")
}

func verify(_ audio: Stereo, design: Design, dark: Bool = false, rank: Bool) -> String {
    let peak = max(audio.left.map(abs).max()!, audio.right.map(abs).max()!)
    precondition(audio.left.allSatisfy(\.isFinite) && audio.right.allSatisfy(\.isFinite))
    precondition(db(peak) <= -1, "Peak exceeds -1 dBFS")
    precondition(audio.left.first! == 0 && audio.right.first! == 0 && audio.left.last! == 0 && audio.right.last! == 0)
    let first = rms(audio, 0, hushStart / 2), second = rms(audio, hushStart / 2, hushStart)
    precondition(second > first * 1.3, "Charge must rise")
    let quietEnd = design == .b ? impact - 0.15 : impact
    let quiet = rms(audio, hushStart + 0.02, quietEnd)
    precondition(db(quiet) < -60, "Hush leaked")
    let quietSamples = Int(((hushStart + 0.02) * sampleRate).rounded())..<Int((quietEnd * sampleRate).rounded())
    precondition(quietSamples.allSatisfy { max(abs(audio.left[$0]), abs(audio.right[$0])) < gain(-60) })
    let phone = phoneFraction(audio)
    precondition(phone >= 0.40, "Insufficient impact energy above 150 Hz: \(phone)")
    var measured = [Double]()
    for pulse in LevelUpTiming.pulses {
        let detected = onset(audio, near: LevelUpTiming.wall(pulse))
        precondition(abs(detected - LevelUpTiming.wall(pulse)) <= 0.005, "Pulse missed: \(pulse) -> \(detected)")
        measured.append(detected)
    }
    let detectedImpact = onset(audio, near: impact, isolated: design != .b)
    precondition(abs(detectedImpact - impact) <= 0.005, "Impact missed")
    let tail = db(rms(audio, audio.duration - 0.05, audio.duration))
    precondition(tail < -60, "Tail has not died: \(tail)")
    let dc = (abs(audio.left.reduce(0, +)) + abs(audio.right.reduce(0, +))) / Double(2 * audio.count)
    precondition(dc < 0.001, "DC offset")
    var lines = [String(format: "levelup-%@%@-%@: %.3f s, peak %.2f dBFS, DC %.7f, tail(last 50 ms) %.2f dBFS", design.rawValue, dark ? "-dark" : "", rank ? "rank" : "level", audio.duration, db(peak), dc, tail)]
    lines.append(String(format: "  RMS dBFS: charge first %.2f / second %.2f; hush %.2f (quiet region %.2f); impact %.2f; bright %.2f; fade %.2f", db(first), db(second), db(rms(audio, hushStart, impact)), db(quiet), db(rms(audio, impact, impact + 0.3)), db(rms(audio, impact, fadeStart)), db(rms(audio, fadeStart, fadeEnd))))
    lines.append(String(format: "  Impact energy >150 Hz: %.2f%%; measured impact %.6f s (%+.2f ms)", phone * 100, detectedImpact, (detectedImpact - impact) * 1000))
    lines.append("  Measured pulse onsets s: " + measured.map { String(format: "%.6f", $0) }.joined(separator: ", "))
    lines.append("  Pulse errors ms: " + zip(measured, LevelUpTiming.pulses).map { String(format: "%+.2f", ($0 - LevelUpTiming.wall($1)) * 1000) }.joined(separator: ", "))
    if rank {
        let detected = onset(audio, near: rankTime, isolated: true)
        precondition(abs(detected - rankTime) <= 0.005)
        lines.append(String(format: "  Measured rank onset %.6f s (%+.2f ms); rank first 300 ms RMS %.2f dBFS", detected, (detected - rankTime) * 1000, db(rms(audio, rankTime, rankTime + 0.3))))
    }
    return lines.joined(separator: "\n")
}

func preview(_ audio: Stereo, design: Design, dark: Bool = false, rank: Bool, to url: URL) throws {
    let width = 1800, height = 1000
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.setFillColor(NSColor(calibratedWhite: 0.055, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    func label(_ text: String, _ x: Double, _ y: Double, size: Double = 14, color: NSColor = .white) {
        (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular), .foregroundColor: color])
    }
    label("CLOCKIN / \(design.rawValue.uppercased()) · \(design.name)\(dark ? ", dark" : "") / \(rank ? "NEW RANK" : "LEVEL")", 80, 950, size: 25)
    label("44.1 kHz · stereo · 16-bit PCM | waveform (L + R) / 2 | spectrogram: Hann 4096, log 30 Hz–12 kHz", 80, 916)
    let x0 = 100.0, plotWidth = 1620.0, waveY = 610.0, waveHeight = 185.0, specY = 85.0, specHeight = 445.0
    let mono = audio.mono
    func x(_ t: Double) -> Double { x0 + t / audio.duration * plotWidth }
    context.setStrokeColor(NSColor.systemTeal.cgColor); context.setLineWidth(1)
    for column in 0..<Int(plotWidth) {
        let a = column * audio.count / Int(plotWidth), b = min(audio.count, (column + 1) * audio.count / Int(plotWidth))
        let chunk = mono[a..<b]
        context.move(to: CGPoint(x: x0 + Double(column), y: waveY + waveHeight * (0.5 + chunk.min()! * 0.5)))
        context.addLine(to: CGPoint(x: x0 + Double(column), y: waveY + waveHeight * (0.5 + chunk.max()! * 0.5)))
    }
    context.strokePath()
    label("+1", 58, waveY + waveHeight - 8); label("0", 66, waveY + waveHeight / 2 - 8); label("−1", 58, waveY - 8)
    let fftSize = 4096, columns = 810, rows = 240
    let setup = vDSP_DFT_zop_CreateSetupD(nil, vDSP_Length(fftSize), .FORWARD)!
    defer { vDSP_DFT_DestroySetupD(setup) }
    let zero = [Double](repeating: 0, count: fftSize)
    var real = zero, imaginary = zero, input = zero
    let window = (0..<fftSize).map { 0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(fftSize - 1)) }
    for column in 0..<columns {
        let center = column * audio.count / columns
        for j in 0..<fftSize {
            let index = center + j - fftSize / 2
            input[j] = index >= 0 && index < audio.count ? mono[index] * window[j] : 0
        }
        vDSP_DFT_ExecuteD(setup, input, zero, &real, &imaginary)
        for row in 0..<rows {
            let f0 = 30 * pow(12000 / 30, Double(row) / Double(rows))
            let f1 = 30 * pow(12000 / 30, Double(row + 1) / Double(rows))
            let a = max(1, Int(f0 * Double(fftSize) / sampleRate)), b = min(fftSize / 2 - 1, max(a, Int(f1 * Double(fftSize) / sampleRate)))
            var magnitude = 0.0
            for k in a...b { magnitude = max(magnitude, hypot(real[k], imaginary[k]) * 4 / Double(fftSize)) }
            let value = clamp((db(magnitude) + 85) / 85)
            let color = NSColor(calibratedRed: min(1, pow(value, 1.7) * 1.8), green: pow(value, 2.7), blue: min(1, value * 0.7 + pow(value, 5) * 0.3), alpha: 1)
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: x0 + Double(column) * plotWidth / Double(columns), y: specY + Double(row) * specHeight / Double(rows), width: plotWidth / Double(columns) + 0.2, height: specHeight / Double(rows) + 0.2))
        }
    }
    for frequency in [30.0, 60, 150, 300, 1000, 3000, 12000] {
        let y = specY + log(frequency / 30) / log(12000 / 30) * specHeight
        label(String(format: "%g", frequency), 35, y - 7, size: 13)
        context.setStrokeColor(NSColor(white: 1, alpha: 0.14).cgColor); context.setLineWidth(0.5)
        context.move(to: CGPoint(x: x0, y: y)); context.addLine(to: CGPoint(x: x0 + plotWidth, y: y)); context.strokePath()
    }
    label("Hz", 35, specY + specHeight + 12)
    label("Spectral amplitude: black ≤ −85 dBFS, violet → orange → white 0 dBFS", 100, 554, size: 13)
    var markers: [(Double, String, Int)] = LevelUpTiming.pulses.enumerated().map { (LevelUpTiming.wall($0.element), "P\($0.offset + 1) \(String(format: "%.2f", $0.element))", $0.offset % 3) }
    markers += [(hushStart, "HUSH \(String(format: "%.2f", hushStart))", 3), (impact, "IMPACT \(String(format: "%.2f", impact))", 2),
                (LevelUpTiming.wall(LevelUpTiming.hold), "HOLD \(String(format: "%.2f", LevelUpTiming.wall(LevelUpTiming.hold)))", 0),
                (fadeStart, "FADE START \(String(format: "%.2f", fadeStart))", 1), (fadeEnd, "FADE END \(String(format: "%.2f", fadeEnd))", 0)]
    if rank { markers.append((rankTime, "RANK \(String(format: "%.2f", rankTime))", 2)) }
    for (time, name, lane) in markers {
        let color: NSColor = name.hasPrefix("P") ? .systemTeal : .systemYellow
        context.setStrokeColor(color.withAlphaComponent(0.65).cgColor); context.setLineWidth(0.7)
        context.setLineDash(phase: 0, lengths: [3, 4])
        for (y, h) in [(waveY, waveHeight), (specY, specHeight)] {
            context.move(to: CGPoint(x: x(time), y: y)); context.addLine(to: CGPoint(x: x(time), y: y + h)); context.strokePath()
        }
        context.setLineDash(phase: 0, lengths: [])
        let labelY = 812 + Double(lane) * 23
        let labelX = min(x(time) + 3, x0 + plotWidth - Double(name.count) * 8.5)
        context.move(to: CGPoint(x: x(time), y: waveY + waveHeight)); context.addLine(to: CGPoint(x: x(time), y: labelY)); context.strokePath()
        label(name, labelX, labelY, size: 12, color: color)
    }
    for t in stride(from: 0.0, through: audio.duration, by: 0.5) { label(String(format: "%.1fs", t), x(t) - 13, 53, size: 13) }
    label("All markers use LevelUpTiming wall time. Hold begins the 0.10 s scene pause.", 100, 18, size: 13)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: - Rich designs

// F and G trade the stable partials and comb reverb above for things that
// move: voices that drift, noise inside the tones, many scattered modes, a
// convolution hall and saturation that glues the layers together.

/// A slow random wander between -1 and 1: smoothed noise for drift and jitter.
struct Wander {
    var random: Noise
    var value = 0.0, target = 0.0, count = 0
    let every: Int, smoothing: Double
    init(seed: UInt64, rate: Double) {
        random = Noise(seed: seed)
        every = max(1, Int(sampleRate / rate))
        smoothing = 1 - exp(-2 * .pi * rate / sampleRate)
    }
    mutating func tick() -> Double {
        if count % every == 0 { target = random.next() }
        count += 1
        value += smoothing * (target - value)
        return value
    }
}

/// Warm, slightly asymmetric saturation: even harmonics as well as odd.
func warm(_ x: Double, _ drive: Double) -> Double {
    (tanh(drive * (x + 0.12)) - tanh(drive * 0.12)) / tanh(drive)
}

/// One note played by a stack of sawtooth voices, each drifting a little in
/// pitch and level, with breath inside the tone, a pitch scoop into the note
/// and a two-pole filter per voice, saturated after the filter.
func stack(_ buffer: inout Stereo, start: Double, duration: Double, note: Double, voices: Int, cents: Double,
           seed: UInt64, gain: Double, scoop: Double, drive: Double, breath: Double, width: Double = 0.8,
           cutoff: @escaping (Double) -> Double, level: @escaping (Double) -> Double) {
    var random = Noise(seed: seed)
    for v in 0..<voices {
        let offset = voices == 1 ? 0 : Double(v) / Double(voices - 1) * 2 - 1
        let detune = pow(2, (offset * cents + random.next() * cents * 0.15) / 1200)
        var phase = random.unit()
        var drift = Wander(seed: seed &+ UInt64(v + 1) &* 7919, rate: 0.5 + random.unit())
        var jitter = Wander(seed: seed &+ UInt64(v + 1) &* 104_729, rate: 6 + 6 * random.unit())
        var breathNoise = Noise(seed: seed &+ UInt64(v + 1) &* 31)
        var air = Biquad(); air.tune("band", 1300 + 500 * random.unit(), q: 0.7)
        var lowA = Biquad(), lowB = Biquad()
        event(&buffer, start: start, duration: duration, pan: offset * width) { t, i in
            let frequency = note * detune * (1 - scoop * exp(-t / 0.07)) * pow(2, drift.tick() * 4 / 1200)
            let step = frequency / sampleRate
            phase += step
            if phase >= 1 { phase -= 1 }
            if i % 32 == 0 {
                let c = cutoff(t)
                lowA.tune("low", c, q: 0.85); lowB.tune("low", c * 1.15, q: 0.6)
            }
            let tone = saw(phase, step)
            let x = lowB.tick(lowA.tick(tone + breath * air.tick(breathNoise.next()) * (0.7 + 0.3 * tone)))
            return gain * level(t) * (1 + 0.1 * jitter.tick()) * warm(x, drive) / Double(voices).squareRoot()
        }
    }
}

/// A struck body of many modes at scattered frequencies, each with its own
/// decay and a little bloom, so metal shimmers and rings instead of humming.
func modes(_ buffer: inout Stereo, start: Double, until end: Double, low: Double, high: Double, count: Int,
           decay: Double, gain: Double, seed: UInt64, bloom: Double = 0) {
    var random = Noise(seed: seed)
    for _ in 0..<count {
        let frequency = low * pow(high / low, pow(random.unit(), 1.25))
        let tau = decay * (0.3 + random.unit()) * pow(low / frequency, 0.3)
        let level = gain * (0.35 + random.unit()) / Double(count).squareRoot() * pow(low / frequency, 0.2)
        let pan = random.next() * 0.85, phase = random.unit() * 2 * .pi, swell = bloom * random.unit()
        let duration = min(end - start, tau * 7)
        event(&buffer, start: start, duration: duration, pan: pan) { t, _ in
            level * sin(2 * .pi * frequency * t + phase) * exp(-t / tau) * smooth(t / (0.0015 + swell))
                * envelope(t, duration, attack: 0.0008, release: min(0.3, duration * 0.4))
        }
    }
}

/// Noise through a band-pass whose centre and level follow curves: wind,
/// risers, the rip and roll of thunder.
func band(_ buffer: inout Stereo, start: Double, duration: Double, seed: UInt64, pan: Double = 0, q: Double = 0.7,
          centre: @escaping (Double) -> Double, level: @escaping (Double) -> Double) {
    var random = Noise(seed: seed)
    var filter = Biquad(), second = Biquad()
    event(&buffer, start: start, duration: duration, pan: pan) { t, i in
        if i % 32 == 0 { let c = centre(t); filter.tune("band", c, q: q); second.tune("band", c, q: q) }
        return level(t) * second.tick(filter.tick(random.next())) * 3 * envelope(t, duration, attack: 0.002, release: 0.05)
    }
}

/// FFT convolution, for the hall.
func convolve(_ signal: [Double], _ kernel: [Double]) -> [Double] {
    let length = signal.count + kernel.count - 1
    let log2n = vDSP_Length(ceil(log2(Double(length))))
    let size = 1 << Int(log2n), half = size / 2
    let setup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2))!
    defer { vDSP_destroy_fftsetupD(setup) }
    func forward(_ x: [Double]) -> ([Double], [Double]) {
        var real = [Double](repeating: 0, count: half), imag = real
        let padded = x + [Double](repeating: 0, count: size - x.count)
        real.withUnsafeMutableBufferPointer { r in
            imag.withUnsafeMutableBufferPointer { m in
                var split = DSPDoubleSplitComplex(realp: r.baseAddress!, imagp: m.baseAddress!)
                padded.withUnsafeBufferPointer { p in
                    p.baseAddress!.withMemoryRebound(to: DSPDoubleComplex.self, capacity: half) {
                        vDSP_ctozD($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zripD(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }
        return (real, imag)
    }
    var (ar, ai) = forward(signal)
    let (br, bi) = forward(kernel)
    // Bin 0 packs the DC and Nyquist terms, both real.
    ar[0] *= br[0]; ai[0] *= bi[0]
    for k in 1..<half {
        let r = ar[k] * br[k] - ai[k] * bi[k], m = ar[k] * bi[k] + ai[k] * br[k]
        ar[k] = r; ai[k] = m
    }
    var output = [Double](repeating: 0, count: size)
    ar.withUnsafeMutableBufferPointer { r in
        ai.withUnsafeMutableBufferPointer { m in
            var split = DSPDoubleSplitComplex(realp: r.baseAddress!, imagp: m.baseAddress!)
            vDSP_fft_zripD(setup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
            output.withUnsafeMutableBufferPointer { o in
                o.baseAddress!.withMemoryRebound(to: DSPDoubleComplex.self, capacity: half) {
                    vDSP_ztocD(&split, 1, $0, 2, vDSP_Length(half))
                }
            }
        }
    }
    // Two forward transforms at twice scale and an unscaled inverse.
    let scale = 1 / Double(4 * size)
    return (0..<signal.count).map { output[$0] * scale }
}

/// A hall's impulse response: early reflections, then noise that decays
/// slower in the lows than in the highs, different in each ear.
func hall(seconds: Double, low: Double, mid: Double, high: Double, seed: UInt64) -> Stereo {
    var ir = Stereo(seconds: seconds)
    for channel in 0..<2 {
        var random = Noise(seed: seed &+ UInt64(channel + 1) &* 977)
        var lows = Biquad(); lows.tune("low", 320)
        var highs = Biquad(); highs.tune("high", 3000)
        var channelIR = [Double](repeating: 0, count: ir.count)
        let predelay = 0.02
        for i in 0..<ir.count {
            let t = Double(i) / sampleRate - predelay
            let n = random.next()
            let l = lows.tick(n), h = highs.tick(n), m = n - l - h
            guard t > 0 else { continue }
            channelIR[i] = (l * exp(-t * 6.9 / low) + m * exp(-t * 6.9 / mid) + h * exp(-t * 6.9 / high)) * smooth(t / 0.04) * 0.5
        }
        for k in 0..<12 {
            let at = Int((0.006 + random.unit() * 0.07) * sampleRate)
            channelIR[at] += (random.unit() > 0.5 ? 1 : -1) * 0.5 * pow(0.82, Double(k))
        }
        let energy = sqrt(channelIR.reduce(0) { $0 + $1 * $1 })
        channelIR = channelIR.map { $0 / energy }
        if channel == 0 { ir.left = channelIR } else { ir.right = channelIR }
    }
    return ir
}

func reverbRich(_ dry: Stereo, ir: Stereo) -> Stereo {
    let mono = dry.mono
    var wet = Stereo(seconds: dry.duration)
    wet.left = convolve(mono, ir.left)
    wet.right = convolve(mono, ir.right)
    return wet
}

/// Glue for the rich designs: parallel compression, so quiet detail comes up
/// under the peaks, then tape-like saturation on the whole mix.
func glue(_ input: Stereo, drive: Double) -> Stereo {
    var output = input
    var detector = 0.0
    let attack = exp(-1 / (0.004 * sampleRate)), release = exp(-1 / (0.09 * sampleRate))
    for i in 0..<input.count {
        let level = max(abs(input.left[i]), abs(input.right[i]))
        detector = level > detector ? level + attack * (detector - level) : level + release * (detector - level)
        let over = max(0, db(detector) + 26)
        let squashed = gain(-over * 0.75)
        for channel in 0..<2 {
            let x = channel == 0 ? input.left[i] : input.right[i]
            let y = warm(x + 1.2 * x * squashed, drive) * 0.62
            if channel == 0 { output.left[i] = y } else { output.right[i] = y }
        }
    }
    return output
}

/// A thunderclap: a sharp crack, the rip of the bolt's length arriving in
/// bursts, then a roll that rumbles unevenly and dies away.
func thunder(_ buffer: inout Stereo, at start: Double, until end: Double, strength: Double, seed: UInt64) {
    var random = Noise(seed: seed)
    band(&buffer, start: start, duration: 0.09, seed: seed &+ 1, q: 0.5, centre: { 2600 - 12_000 * $0 }) { t in
        strength * 1.4 * exp(-t / 0.018) * smooth(t / 0.0006)
    }
    for k in 0..<9 {
        let offset = 0.012 + pow(random.unit(), 1.4) * 0.22
        let pan = random.next() * 0.7, top = 1800 + 1500 * random.unit()
        band(&buffer, start: start + offset, duration: 0.16, seed: seed &+ UInt64(k + 2), pan: pan, q: 0.6,
             centre: { top * exp(-$0 / 0.08) + 180 }) { t in
            strength * (0.9 - 0.07 * Double(k)) * exp(-t / 0.045) * smooth(t / 0.002)
        }
    }
    var bumps = Wander(seed: seed &+ 99, rate: 5)
    band(&buffer, start: start + 0.03, duration: end - start - 0.03, seed: seed &+ 50, q: 0.45,
         centre: { 70 + 190 * exp(-$0 / 0.9) }) { t in
        strength * 1.25 * smooth(t / 0.08) * exp(-t / 0.75) * (0.75 + 0.25 * bumps.tick())
    }
}

func strikeRich(_ buffer: inout Stereo, at start: Double, until end: Double, design: Design, rank: Bool, seed: UInt64) {
    let strength = rank ? 0.5 : 1.0
    thump(&buffer, start: start, strength: 0.95 * strength, design: .a, large: true, sub: !rank)
    if design == .g {
        thunder(&buffer, at: start, until: end, strength: strength, seed: seed)
    } else {
        // The blow itself: a dense noise burst and an air blast falling in pitch.
        band(&buffer, start: start, duration: 0.25, seed: seed &+ 3, q: 0.45, centre: { 5200 * exp(-$0 / 0.05) + 300 }) { t in
            strength * 1.3 * exp(-t / 0.05) * smooth(t / 0.0008)
        }
        band(&buffer, start: start + 0.004, duration: 0.8, seed: seed &+ 4, pan: -0.4, q: 0.6, centre: { 6500 * pow(0.1, $0 / 0.8) }) { t in
            strength * 0.55 * exp(-t / 0.28) * smooth(t / 0.004)
        }
        band(&buffer, start: start + 0.007, duration: 0.8, seed: seed &+ 5, pan: 0.4, q: 0.6, centre: { 6200 * pow(0.1, $0 / 0.8) }) { t in
            strength * 0.5 * exp(-t / 0.28) * smooth(t / 0.004)
        }
    }
    // Struck metal under the blow: a gong-like body of scattered modes.
    modes(&buffer, start: start, until: end, low: design == .g ? 55 : 62, high: 1400, count: 70,
          decay: rank ? 0.7 : 1.0, gain: (design == .g ? 0.28 : 0.42) * strength, seed: seed &+ 7, bloom: 0.12)
}

/// The weight after the blow. F: a C minor brass stack; G: a saturated wall
/// of low fifths, like overdriven guitars through big cabinets.
func weightRich(_ buffer: inout Stereo, start: Double, until end: Double, design: Design, rank: Bool, seed: UInt64) {
    let duration = end - start
    let root = rank ? 48.999 : 65.406
    let fading: (Double) -> Double = rank ? { t in exp(-t / 0.8) } : { t in light(start + t) }
    if design == .f {
        let notes = [root, root * 1.5, root * 2, root * 2.378, root * 3]
        for (k, note) in notes.enumerated() {
            stack(&buffer, start: start + 0.01, duration: duration, note: note, voices: 7, cents: 16,
                  seed: seed &+ UInt64(k) &* 131, gain: (k == 0 ? 0.3 : 0.24) * (rank ? 0.85 : 1), scoop: 0.035,
                  drive: 2.4, breath: 0.35, width: 0.7,
                  cutoff: { t in 180 + 2300 * (1 - exp(-t / 0.03)) * exp(-t / 0.8) + 520 * fading(t) },
                  level: { t in fading(t) * smooth(t / 0.03) * (1 + 0.18 * sin(2 * .pi * 34 * t) * exp(-t / 0.35)) })
        }
    } else {
        let notes = [root, root * 1.5, root * 2]
        for (k, note) in notes.enumerated() {
            stack(&buffer, start: start + 0.005, duration: duration, note: note, voices: 5, cents: 11,
                  seed: seed &+ UInt64(k) &* 173, gain: 0.3 * (rank ? 0.85 : 1), scoop: 0.02,
                  drive: 5, breath: 0.12, width: 0.9,
                  cutoff: { t in 1400 + 1800 * exp(-t / 0.25) },
                  level: { t in fading(t) * smooth(t / 0.012) })
        }
    }
    // Rubble settling, low and dull.
    band(&buffer, start: start + 0.05, duration: min(duration, 1.4), seed: seed &+ 11, q: 0.5,
         centre: { 160 - 60 * clamp($0 / 1.2) }) { t in
        (rank ? 0.3 : 0.5) * smooth(t / 0.06) * exp(-t / 0.5)
    }
}

func chargeRich(_ design: Design, seconds: Double, seed: UInt64) -> Stereo {
    var buffer = Stereo(seconds: seconds)
    let rise: (Double) -> Double = { t in pow(clamp(t / hushStart), 1.6) }
    if design == .f {
        // A dark cluster rising an octave, a stack of drifting voices per note.
        for (k, ratio) in [1.0, 1.5, 2.0].enumerated() {
            stack(&buffer, start: 0, duration: hushStart, note: 55 * ratio, voices: 7, cents: 20,
                  seed: seed &+ UInt64(k) &* 211, gain: 0.22, scoop: 0, drive: 1.8, breath: 0.5, width: 0.9,
                  cutoff: { t in 220 + 2600 * rise(t) },
                  level: { t in (0.12 + 0.88 * rise(t)) * smooth(t / 0.3) })
        }
        // The stack rises in pitch: a second, octave-gliding layer fades in over it.
        stack(&buffer, start: 0.2, duration: hushStart - 0.2, note: 110, voices: 5, cents: 25,
              seed: seed &+ 999, gain: 0.18, scoop: -0.5, drive: 2, breath: 0.4,
              cutoff: { t in 400 + 3000 * rise(t + 0.2) }, level: { t in rise(t + 0.2) })
        band(&buffer, start: 0.1, duration: hushStart - 0.1, seed: seed &+ 20, q: 0.9,
             centre: { t in 300 * pow(18, clamp(t / (hushStart - 0.1))) }) { t in 0.35 * rise(t + 0.1) }
    } else {
        // Wind that rises and gusts, and thunder far off.
        var gust = Wander(seed: seed &+ 30, rate: 1.3)
        band(&buffer, start: 0, duration: hushStart, seed: seed &+ 31, pan: -0.5, q: 1.4,
             centre: { t in 350 + 1500 * rise(t) }) { t in (0.15 + 0.6 * rise(t)) * (0.7 + 0.3 * gust.tick()) * smooth(t / 0.3) }
        var gust2 = Wander(seed: seed &+ 32, rate: 1.1)
        band(&buffer, start: 0, duration: hushStart, seed: seed &+ 33, pan: 0.5, q: 1.4,
             centre: { t in 500 + 2000 * rise(t) }) { t in (0.12 + 0.5 * rise(t)) * (0.7 + 0.3 * gust2.tick()) * smooth(t / 0.3) }
        var roll = Wander(seed: seed &+ 34, rate: 2)
        band(&buffer, start: 0, duration: hushStart, seed: seed &+ 35, q: 0.5, centre: { _ in 110 }) { t in
            0.35 * (0.3 + 0.7 * rise(t)) * max(0, roll.tick()) * smooth(t / 0.3)
        }
        // A low drone of fifths under the storm, swelling with it.
        for (k, ratio) in [1.0, 1.5].enumerated() {
            stack(&buffer, start: 0, duration: hushStart, note: 55 * ratio, voices: 5, cents: 14,
                  seed: seed &+ UInt64(k) &* 223, gain: 0.2, scoop: 0, drive: 3, breath: 0.2,
                  cutoff: { t in 200 + 1600 * rise(t) }, level: { t in rise(t) * smooth(t / 0.3) })
        }
    }
    var random = Noise(seed: seed &+ 40)
    for (j, strike) in LevelUpTiming.strikes.enumerated() where strike < hushStart {
        let strength = 0.05 + 0.2 * pow(strike / hushStart, 2)
        let pan = random.next() * 0.9
        // An electric zap: a crack falling fast in pitch, then fizz.
        band(&buffer, start: strike, duration: 0.1, seed: seed &+ UInt64(j + 100), pan: pan, q: 1.2,
             centre: { t in 5200 * exp(-t / 0.02) + 900 }) { t in strength * exp(-t / 0.03) * smooth(t / 0.0008) }
        for burst in 0..<5 {
            let at = strike + random.unit() * 0.09
            band(&buffer, start: at, duration: 0.012, seed: seed &+ UInt64(j * 10 + burst + 400), pan: pan, q: 0.8,
                 centre: { _ in 3500 }) { t in strength * 0.8 * exp(-t / 0.003) }
        }
    }
    return buffer
}

/// Overtones of the lows for small speakers, which barely play anything
/// under 150 to 200 Hz: the ear hears a missing fundamental from its
/// harmonics, so the boom, the heartbeat and the wall still land on a phone.
/// The low band is normalised by its own envelope, shaped by Chebyshev
/// polynomials into its second to fourth harmonics, put back to its level
/// and kept to the band a phone speaker plays. The deepest sub, which a
/// phone cannot play at all, is halved so it stops using up the limiter.
func phoneBass(_ input: Stereo, amount: Double) -> Stereo {
    var output = input
    var lowA = Biquad(), lowB = Biquad(), highA = Biquad(), highB = Biquad(), top = Biquad()
    var subL = Biquad(), subR = Biquad()
    subL.tune("low", 80); subR.tune("low", 80)
    lowA.tune("low", 130, q: 0.5412); lowB.tune("low", 130, q: 1.3066)
    highA.tune("high", 150, q: 0.5412); highB.tune("high", 150, q: 1.3066)
    top.tune("low", 1100)
    var envelope = 0.0
    let attack = exp(-1 / (0.004 * sampleRate)), release = exp(-1 / (0.06 * sampleRate))
    for i in 0..<input.count {
        let low = lowB.tick(lowA.tick((input.left[i] + input.right[i]) * 0.5))
        let level = abs(low)
        envelope = level > envelope ? level + attack * (envelope - level) : level + release * (envelope - level)
        let x = max(-1, min(1, low / max(envelope, 1e-5)))
        let x2 = x * x
        let shaped = 0.55 * (2 * x2 - 1) + 0.35 * (4 * x2 * x - 3 * x) + 0.2 * (8 * x2 * x2 - 8 * x2 + 1)
        let overtones = top.tick(highB.tick(highA.tick(envelope * shaped))) * amount
        output.left[i] += overtones - 0.5 * subL.tick(input.left[i])
        output.right[i] += overtones - 0.5 * subR.tick(input.right[i])
    }
    return output
}

/// The heartbeat. Each beat ducks whatever is already sounding for a moment
/// before it, the previous beat's tail included, the way a mix makes room
/// for a kick.
func pulsesRich(_ buffer: inout Stereo, seed: UInt64) {
    for (j, pulse) in LevelUpTiming.pulses.enumerated() {
        let at = LevelUpTiming.wall(pulse)
        for i in max(0, Int((at - 0.02) * sampleRate))..<min(buffer.count, Int((at + 0.03) * sampleRate)) {
            let u = Double(i) / sampleRate - at
            let duck = 1 - 0.75 * smooth((u + 0.02) / 0.012) * smooth((0.03 - u) / 0.025)
            buffer.left[i] *= duck; buffer.right[i] *= duck
        }
        let strength = 0.7 + 0.55 * Double(j) / Double(LevelUpTiming.pulses.count - 1)
        thump(&buffer, start: at, strength: strength, design: .a)
        // A drum's skin under each beat.
        band(&buffer, start: at, duration: 0.09, seed: seed &+ UInt64(j + 50), q: 0.6, centre: { _ in 180 }) { t in
            strength * 0.5 * exp(-t / 0.025) * smooth(t / 0.001)
        }
        // The thump's own second and third harmonics on its falling pitch,
        // too short for phoneBass to catch, so the beat is felt on a phone.
        event(&buffer, start: at, duration: 0.12) { t, _ in
            let phase = 2 * .pi * (48 * t + 47 * 0.022 * (1 - exp(-t / 0.022)))
            return strength * 1.5 * (0.8 * sin(2 * phase) + 0.6 * sin(3 * phase)) * exp(-t / 0.045) * envelope(t, 0.12, attack: 0.001)
        }
    }
}

func synthesizeRich(_ design: Design) -> (Stereo, Stereo) {
    let probe = convolve([1] + [Double](repeating: 0, count: 99), [0.5, -0.25, 0.125])
    precondition(abs(probe[0] - 0.5) < 1e-9 && abs(probe[1] + 0.25) < 1e-9 && abs(probe[2] - 0.125) < 1e-9, "Convolution is misscaled")
    let seed = design.seed
    let length = impact + 1.8
    let room = hall(seconds: 2.4, low: 2.4, mid: 1.7, high: 0.8, seed: seed &+ 77)
    var dry = Stereo(seconds: length)
    strikeRich(&dry, at: impact, until: length - 0.25, design: design, rank: false, seed: seed &+ 1000)
    weightRich(&dry, start: impact, until: fadeEnd + 0.1, design: design, rank: false, seed: seed &+ 2000)
    var charged = chargeRich(design, seconds: length, seed: seed &+ 3000)
    charged.mix(reverbRich(charged, ir: room), gain: 0.5)
    // The heartbeat carries its own overtones, so it joins after phoneBass
    // and keeps its full sub on headphones.
    charged = phoneBass(charged, amount: 3)
    pulsesRich(&charged, seed: seed &+ 3500)
    dry.mix(reverbRich(dry, ir: room), gain: 0.7)
    dry = phoneBass(dry, amount: 3)
    dry.mix(charged)
    let level = master(glue(dry, drive: design == .g ? 1.9 : 1.5), design: design, isRankBeat: false)
    var second = Stereo(seconds: 1.8)
    strikeRich(&second, at: 0, until: 1.55, design: design, rank: true, seed: seed &+ 4000)
    weightRich(&second, start: 0, until: 1.5, design: design, rank: true, seed: seed &+ 5000)
    second.mix(reverbRich(second, ir: room), gain: 0.6)
    second = master(glue(phoneBass(second, amount: 3), drive: design == .g ? 1.9 : 1.5), design: design, isRankBeat: true)
    var rank = Stereo(seconds: rankTime + 1.8)
    rank.mix(level)
    let offset = Int((rankTime * sampleRate).rounded())
    for i in 0..<second.count where i + offset < rank.count {
        rank.left[i + offset] += second.left[i]; rank.right[i + offset] += second.right[i]
    }
    return (level, rank)
}

/// The app's cues: the level, the level that opens a rank, and the strike
/// alone for a card that opens on its still frame (Reduce Motion, Low Power
/// Mode), which starts at the impact.
func writeResources(level: Stereo, rank: Stereo, to folder: URL) throws -> [String] {
    var still = Stereo(seconds: level.duration - impact + 0.005)
    let offset = Int(((impact - 0.005) * sampleRate).rounded())
    for i in 0..<still.count {
        // A 5 ms fade-in so the cut before the impact does not click.
        let fade = smooth(Double(i) / (0.005 * sampleRate))
        still.left[i] = level.left[i + offset] * fade
        still.right[i] = level.right[i + offset] * fade
    }
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
    var lines: [String] = []
    for (name, audio) in [("clockin-levelup", level), ("clockin-levelup-rank", rank), ("clockin-levelup-still", still)] {
        let url = folder.appendingPathComponent(name + ".caf")
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.count))!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<audio.count {
            // The WAV's 16-bit values, scaled the way the file converts floats back to them.
            buffer.floatChannelData![0][i] = Float((audio.left[i] * 32767).rounded() / 32768)
            buffer.floatChannelData![1][i] = Float((audio.right[i] * 32767).rounded() / 32768)
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            try file.write(from: buffer)
        }
        let file = try AVAudioFile(forReading: url)
        precondition(file.fileFormat.sampleRate == sampleRate && file.fileFormat.channelCount == 2)
        precondition(file.length == AVAudioFramePosition(audio.count))
        let read = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: read)
        let first = (read.floatChannelData![0][0], read.floatChannelData![1][0])
        let last = (read.floatChannelData![0][audio.count - 1], read.floatChannelData![1][audio.count - 1])
        precondition(first == (0, 0) && last == (0, 0), "\(name) must start and end on silence")
        lines.append(String(format: "%@.caf: %.3f s, stereo 16-bit PCM", name, audio.duration))
    }
    return lines
}

@main
struct MakeLevelUpSounds {
    static func main() throws {
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/levelup-sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var report = ["CLOCKIN / original synthesized level-up candidates", "RMS is per-channel energy averaged in linear power; silence prints as -240 dBFS.",
                      "Bright: impact to fade start. Phone check: stereo rectangular-window FFT, first 300 ms after impact."]
        // Design A is rendered twice: with its heroic weight and its dark one.
        let variants: [(Design, Bool)] = [(.a, false), (.a, true), (.b, false), (.c, false), (.f, false), (.g, false)]
        for (design, dark) in variants {
            let (level, rank) = synthesize(design, dark: dark)
            var decodedLevel: Stereo?
            for (isRank, audio) in [(false, level), (true, rank)] {
                let stem = "levelup-\(design.rawValue)\(dark ? "-dark" : "")-\(isRank ? "rank" : "level")"
                let wav = output.appendingPathComponent(stem + ".wav")
                try writeWAV(audio, to: wav)
                let decoded = try readWAV(wav, expectedDuration: audio.duration)
                let measurements = verify(decoded, design: design, dark: dark, rank: isRank)
                print(measurements)
                report.append(measurements)
                if let base = decodedLevel {
                    precondition(Array(decoded.left.prefix(base.count)) == base.left && Array(decoded.right.prefix(base.count)) == base.right,
                                 "Rank must preserve the entire level version")
                } else { decodedLevel = decoded }
                try preview(decoded, design: design, dark: dark, rank: isRank, to: output.appendingPathComponent(stem + ".png"))
            }
            if design == .shipped && dark == Design.shippedDark {
                let sounds = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Clockin/Audio/Sounds", isDirectory: true)
                let lines = try writeResources(level: level, rank: rank, to: sounds)
                lines.forEach { print($0) }
                report += lines
            }
        }
        let conclusion = "ok: 12 stereo PCM WAVs and 12 PNG previews; all rendered-audio preconditions passed. Output: \(output.path); design \(Design.shipped.rawValue)\(Design.shippedDark ? " (dark)" : "") written to Clockin/Audio/Sounds"
        report.append(conclusion)
        try (report.joined(separator: "\n\n") + "\n").write(to: output.appendingPathComponent("measurements.txt"), atomically: true, encoding: .utf8)
        print(conclusion)
    }
}
