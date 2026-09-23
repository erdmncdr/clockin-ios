import Foundation
import AVFoundation
import Accelerate
import AppKit

let sampleRate = 44_100.0
let targetPeak = pow(10.0, -3.0 / 20)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Clockin/Audio/Sounds", isDirectory: true)
let preview = URL(fileURLWithPath: "/tmp/clockin-chime-preview.png")

struct Note {
    let start: Double
    let frequency: Double
    var gain = 1.0
}
struct Voice {
    let id: String
    let duration: Double
    let notes: [Note]
    let ratios: [Double]
    let gains: [Double]
    let decay: Double
    var attack = 0.012
    var noise = 0.0
    var bend = 0.0
}
let voices: [Voice] = [
    Voice(id: "soft-bell", duration: 1.6, notes: [Note(start: 0, frequency: 440)],
          ratios: [1, 2.01, 2.72, 3.95], gains: [1, 0.28, 0.12, 0.035], decay: 0.43),
    Voice(id: "glass", duration: 1.25, notes: [Note(start: 0, frequency: 740)],
          ratios: [1, 1.48, 2.09, 2.71], gains: [1, 0.24, 0.12, 0.04], decay: 0.34),
    Voice(id: "marimba", duration: 1.3, notes: [Note(start: 0, frequency: 330), Note(start: 0.24, frequency: 440, gain: 0.85)],
          ratios: [1, 3.93, 6.1], gains: [1, 0.18, 0.035], decay: 0.27, noise: 0.06),
    Voice(id: "chime", duration: 1.8, notes: [Note(start: 0, frequency: 523.25), Note(start: 0.24, frequency: 659.25, gain: 0.85), Note(start: 0.48, frequency: 783.99, gain: 0.75)],
          ratios: [1, 2.01, 2.76], gains: [1, 0.2, 0.045], decay: 0.32),
    Voice(id: "pop", duration: 0.5, notes: [Note(start: 0, frequency: 360)],
          ratios: [1, 1.97], gains: [1, 0.1], decay: 0.14, attack: 0.01, noise: 0.1, bend: 180),
    Voice(id: "wood-block", duration: 0.65, notes: [Note(start: 0, frequency: 480)],
          ratios: [1, 1.57, 2.13], gains: [1, 0.3, 0.1], decay: 0.17, attack: 0.008, noise: 0.18),
    Voice(id: "singing-bowl", duration: 2.5, notes: [Note(start: 0, frequency: 220)],
          ratios: [1, 1.006, 2.71, 3.94], gains: [1, 0.35, 0.16, 0.055], decay: 0.8, attack: 0.025),
    Voice(id: "tiny-ping", duration: 0.4, notes: [Note(start: 0, frequency: 880)],
          ratios: [1, 2.03], gains: [1, 0.045], decay: 0.065, attack: 0.009)
]

func synthesize(_ voice: Voice) -> [Double] {
    var samples = [Double](repeating: 0, count: Int(voice.duration * sampleRate))
    var seed: UInt64 = 0xC10C_1A42
    var filteredNoise = 0.0
    let filter = 1 - exp(-2 * Double.pi * 1200 / sampleRate)
    for i in samples.indices {
        let time = Double(i) / sampleRate
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let noise = Double(seed >> 11) / Double(UInt64.max >> 11) * 2 - 1
        filteredNoise += filter * (noise - filteredNoise)
        for note in voice.notes where time >= note.start {
            let t = time - note.start
            let attack = pow(sin(min(1, t / voice.attack) * .pi / 2), 2)
            var value = 0.0
            for partial in voice.ratios.indices {
                let ratio = voice.ratios[partial]
                let phase = 2 * Double.pi * ratio * (note.frequency * t + voice.bend * 0.035 * (1 - exp(-t / 0.035)))
                let envelope = exp(-t / (voice.decay / (1 + Double(partial) * 0.45)))
                value += voice.gains[partial] * sin(phase) * envelope
            }
            value += voice.noise * filteredNoise * exp(-t / 0.025)
            samples[i] += note.gain * attack * value
        }
        // Son ornek sifir; kuyruk kesilirken tiklama olusmasin.
        let remaining = Double(samples.count - 1 - i) / sampleRate
        samples[i] *= pow(sin(min(1, remaining / 0.08) * .pi / 2), 2)
    }
    let peak = samples.map { abs($0) }.max()!
    return samples.map { $0 * targetPeak / peak }
}

func db(_ value: Double) -> Double { 20 * log10(max(value, 1e-12)) }
func spectrum(_ samples: [Double]) -> [Double] {
    let size = 2048
    let setup = vDSP_DFT_zop_CreateSetupD(nil, vDSP_Length(size), .FORWARD)!
    defer { vDSP_DFT_DestroySetupD(setup) }
    var powers = [Double](repeating: 0, count: size / 2)
    let imaginary = [Double](repeating: 0, count: size)
    var realOutput = imaginary, imaginaryOutput = imaginary
    for frame in 0..<24 {
        let start = frame * (samples.count - size) / 23
        let input = (0..<size).map { i in
            samples[start + i] * (0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(size - 1)))
        }
        vDSP_DFT_ExecuteD(setup, input, imaginary, &realOutput, &imaginaryOutput)
        for i in powers.indices { powers[i] += pow(realOutput[i], 2) + pow(imaginaryOutput[i], 2) }
    }
    return powers
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate,
    AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
var rendered: [(Voice, [Double], [Double], Double, Double)] = []
for voice in voices {
    let samples = synthesize(voice)
    let url = output.appendingPathComponent("clockin-\(voice.id).caf")
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = buffer.frameCapacity
    for i in samples.indices { buffer.floatChannelData![0][i] = Float(samples[i]) }
    do {
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }
    let file = try AVAudioFile(forReading: url)
    let read = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: read)
    let pcm = (0..<Int(read.frameLength)).map { Double(read.floatChannelData![0][$0]) }
    let duration = Double(file.length) / file.fileFormat.sampleRate
    let peak = pcm.map { abs($0) }.max()!
    let rms = sqrt(pcm.reduce(0) { $0 + $1 * $1 } / Double(pcm.count))
    let powers = spectrum(pcm)
    let brightFraction = powers.enumerated().filter { Double($0.offset) * sampleRate / 2048 > 5000 }.reduce(0) { $0 + $1.element } / powers.reduce(0, +)
    precondition(FileManager.default.fileExists(atPath: url.path) && duration >= 0.4 && duration <= 2.5 && duration < 30)
    precondition(file.fileFormat.sampleRate == sampleRate && file.fileFormat.channelCount == 1)
    precondition(peak < 1 && abs(db(peak) + 3) < 0.1)
    precondition(abs(pcm.first!) < 0.0001 && abs(pcm.last!) < 0.0001)
    precondition(brightFraction < 0.001, "Excess energy above 5 kHz: \(voice.id)")
    print(String(format: "%@.caf: %.2f s, peak %.2f dBFS, RMS %.2f dBFS, >5 kHz %.5f%%", "clockin-\(voice.id)", duration, db(peak), db(rms), brightFraction * 100))
    rendered.append((voice, pcm, powers, db(peak), db(rms)))
}
let levels = rendered.map { $0.4 }
let spread = levels.max()! - levels.min()!
print(String(format: "RMS spread: %.2f dB", spread))
precondition(spread <= 3, "Adjust decay or partial balance to keep RMS within 3 dB")

let width = 1500, height = 1540
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let context = graphics.cgContext
context.setFillColor(NSColor(calibratedWhite: 0.07, alpha: 1).cgColor)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
func label(_ text: String, _ x: Double, _ y: Double, size: Double = 14) {
    (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular), .foregroundColor: NSColor.white])
}
label("CLOCKIN / ORIGINAL FOCUS SOUNDS / 44.1 kHz mono PCM", 32, 1498, size: 22)
label("Waveform: +/-1, common 2.5 s scale. Spectrum: 0-8 kHz, relative 0 to -80 dB.", 32, 1465)
for (row, item) in rendered.enumerated() {
    let (voice, pcm, powers, peak, rms) = item
    let y = Double(1260 - row * 175)
    label(String(format: "%@   %.2fs   peak %.2f   RMS %.2f dBFS", voice.id, voice.duration, peak, rms), 32, y + 125)
    context.setStrokeColor(NSColor.gray.cgColor)
    context.setLineWidth(0.5)
    context.stroke(CGRect(x: 32, y: y, width: 860, height: 115))
    context.stroke(CGRect(x: 945, y: y, width: 520, height: 115))
    context.move(to: CGPoint(x: 32, y: y + 57.5)); context.addLine(to: CGPoint(x: 892, y: y + 57.5)); context.strokePath()
    context.setStrokeColor(NSColor.systemTeal.cgColor)
    for x in 0..<Int(860 * voice.duration / 2.5) {
        let start = Int(Double(x) * 2.5 * sampleRate / 860)
        let end = min(pcm.count, Int(Double(x + 1) * 2.5 * sampleRate / 860))
        guard start < end else { continue }
        let chunk = pcm[start..<end]
        context.move(to: CGPoint(x: Double(x + 32), y: y + 57.5 + chunk.min()! * 57.5))
        context.addLine(to: CGPoint(x: Double(x + 32), y: y + 57.5 + chunk.max()! * 57.5))
    }
    context.strokePath()
    let maxPower = powers.max()!
    context.setStrokeColor(NSColor.systemOrange.cgColor)
    for i in 0...Int(8000 * 2048 / sampleRate) {
        let x = 945 + Double(i) * sampleRate / 2048 / 8000 * 520
        let level = max(-80, 10 * log10(max(powers[i] / maxPower, 1e-12)))
        let point = CGPoint(x: x, y: y + (level + 80) / 80 * 115)
        if i == 0 { context.move(to: point) } else { context.addLine(to: point) }
    }
    context.strokePath()
    label("0 s", 32, y - 21, size: 12)
    label("1.25 s", 438, y - 21, size: 12)
    label("2.5 s", 855, y - 21, size: 12)
    label("0               2k              4k              6k              8k Hz", 945, y - 21, size: 12)
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: preview)
print("ok: \(voices.count) generated CAF files verified; preview \(preview.path)")
