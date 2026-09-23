import AVFoundation
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}
let expected: [(String, String)] = [
    ("soft-bell", "Soft Bell"), ("glass", "Glass"), ("marimba", "Marimba"),
    ("chime", "Chime"), ("pop", "Pop"), ("wood-block", "Wood Block"),
    ("singing-bowl", "Singing Bowl"), ("tiny-ping", "Tiny Ping")
]
check(FocusChimeSound.allCases.map(\.id) == expected.map(\.0), "stable catalog ids and order")
check(Set(FocusChimeSound.allCases.map(\.fileName)).count == expected.count, "unique bundled file names")
check(FocusChimeSound.defaultSound == .chime, "default is Chime")
for (id, name) in expected {
    let sound = FocusChimeSound.selected(id)
    check(sound.rawValue == id && sound.displayName == name, "catalog: \(id) has display name")
    check(sound.fileName == "clockin-\(id).caf", "catalog: \(id) has CAF file name")
}
check(FocusChimeSound.selected("Glass") == .glass, "legacy Glass maps to glass")
for legacy in ["Default notification", "Default ringtone", "Ping", "Pop", "Tink", "Funk", "Submarine", "Sosumi", "unknown", ""] {
    check(FocusChimeSound.selected(legacy) == .chime, "legacy or unknown \(legacy) maps to chime")
}
check(FocusChimeSound.selected(nil) == .chime, "missing sound defaults to chime")
check(FocusChimeVolume.clamped(nil) == 0.75, "default volume is 75 percent")
check(FocusChimeVolume.clamped(0.1) == 0.1 && FocusChimeVolume.clamped(1) == 1, "volume bounds retained")
check(FocusChimeVolume.clamped(0.42) == 0.42, "valid volume retained")
check(FocusChimeVolume.clamped(-1) == 0.1 && FocusChimeVolume.clamped(0) == 0.1, "volume lower bound")
check(FocusChimeVolume.clamped(2) == 1, "volume upper bound")
for value in [Double.nan, .infinity, -.infinity] {
    check(FocusChimeVolume.clamped(value) == 0.75, "nonfinite volume defaults safely")
}

// Gercek kullanici tercihleri yerine bellek ici alan kullanilir.
final class MemoryDefaults: UserDefaults {
    var values: [String: Any] = [:]
    override func object(forKey key: String) -> Any? { values[key] }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
}
let defaults = MemoryDefaults()
check(FocusChimeVolume.selected(in: defaults) == 0.75, "missing stored volume defaults")
check(FocusChimeSound.migrate(in: defaults) == .chime, "empty defaults migrate")
check(defaults.string(forKey: FocusChimeSound.preferenceKey) == "chime", "migration writes stable default")
defaults.set("Glass", forKey: FocusChimeSound.preferenceKey)
check(FocusChimeSound.migrate(in: defaults) == .glass, "stored legacy Glass migrates")
check(defaults.string(forKey: FocusChimeSound.preferenceKey) == "glass", "migration persists id")
check(FocusChimeSound.migrate(in: defaults) == .glass, "migration is idempotent")
defaults.set(0.25, forKey: FocusChimeVolume.preferenceKey)
check(FocusChimeVolume.selected(in: defaults) == 0.25, "Mac-compatible fractional volume")
defaults.set(0.0, forKey: FocusChimeVolume.preferenceKey)
check(FocusChimeVolume.selected(in: defaults) == 0.1, "stored zero clamps to ten percent")

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = cwd.appendingPathComponent("Clockin/Audio/Sounds")
let directory = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1]) : source
var rmsLevels: [Double] = []
for sound in FocusChimeSound.allCases {
    let url = directory.appendingPathComponent(sound.fileName)
    check(FileManager.default.fileExists(atPath: url.path), "file exists: \(sound.fileName)")
    let file = try AVAudioFile(forReading: url)
    let duration = Double(file.length) / file.fileFormat.sampleRate
    check(duration >= 0.4 && duration <= 2.5 && duration < 30, "notification duration: \(sound.id)")
    check(file.fileFormat.sampleRate == 44_100 && file.fileFormat.channelCount == 1,
          "44.1 kHz mono: \(sound.id)")
    check(file.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatLinearPCM &&
          file.fileFormat.streamDescription.pointee.mBitsPerChannel == 16, "16-bit linear PCM: \(sound.id)")
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    let samples = (0..<Int(buffer.frameLength)).map { Double(buffer.floatChannelData![0][$0]) }
    let peak = samples.map { abs($0) }.max()!
    let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Double(samples.count))
    check(peak < 1 && abs(20 * log10(peak) + 3) < 0.1, "unclipped -3 dBFS peak: \(sound.id)")
    check(samples.first == 0 && samples.last == 0, "zero endpoints: \(sound.id)")
    rmsLevels.append(20 * log10(rms))
}
check(rmsLevels.max()! - rmsLevels.min()! <= 3, "RMS levels within 3 dB")
print("\(checks) chime sound checks passed")
