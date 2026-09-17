import Foundation

/// The mascot's motion, shared with the website (`website/dist/sprite.js`).
///
/// The drawings give the poses; everything that moves through space is a
/// transform, so it is smooth at the display's refresh rate instead of
/// stepping in drawn frames:
/// - drawn events (blink, antenna dip, glow, key presses, a sip of coffee) are
///   short clips from `mascot-clips.json`, picked at random so the mascot never
///   repeats a fixed loop;
/// - hops use squash and stretch with a ground shadow;
/// - standing moods sway gently.
///
/// Kept free of SwiftUI so it can be checked on its own.
enum MascotMood: String, CaseIterable, Sendable {
    case hello, celebrate, coffee, working, angry, tired, proud

    /// Where the feet are, as a share of the image height from the top. Hops
    /// squash around this point and the shadow sits on it (site: `--feet`).
    var feet: Double {
        switch self {
        case .hello, .angry, .tired, .proud: 0.89
        case .celebrate: 0.82
        case .working: 0.86
        case .coffee: 0.88
        }
    }
}

struct MascotStep: Decodable, Equatable, Sendable {
    let frame: String
    /// How long the frame holds. The closing rest frame has 0.
    let milliseconds: Int

    init(_ frame: String, _ milliseconds: Int) {
        self.frame = frame
        self.milliseconds = milliseconds
    }

    /// Encoded as `["h10", 100]`.
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        frame = try container.decode(String.self)
        milliseconds = try container.decode(Int.self)
    }
}

struct MascotMoodClips: Decodable, Sendable {
    let rest: String
    let standing: Bool
    let clips: [String: [MascotStep]]
    /// Relative odds of each event. `hop` is not a clip but a transform.
    let weights: [String: Double]

    /// Typing and coffee keep a drawn cycle going between events.
    var base: [MascotStep]? { clips["base"] }

    /// Every frame this mood can show.
    var frames: Set<String> {
        Set([rest] + clips.values.flatMap { $0.map(\.frame) })
    }
}

struct MascotLibrary: Sendable {
    let moods: [MascotMood: MascotMoodClips]

    init(data: Data) throws {
        let raw = try JSONDecoder().decode([String: MascotMoodClips].self, from: data)
        var moods: [MascotMood: MascotMoodClips] = [:]
        for mood in [MascotMood.hello, .celebrate, .coffee, .working] {
            guard let clips = raw[mood.rawValue] else {
                throw DecodingError.valueNotFound(MascotMoodClips.self, .init(codingPath: [], debugDescription: "Missing mood \(mood.rawValue)"))
            }
            moods[mood] = clips
        }
        if let hello = moods[.hello] {
            for (mood, prefix) in [(MascotMood.angry, "a"), (.tired, "z"), (.proud, "p")] {
                func frameID(_ id: String) -> String { prefix + id.dropFirst() }
                var weights = hello.weights
                if mood == .tired { weights["hop"] = 0 }
                moods[mood] = MascotMoodClips(
                    rest: frameID(hello.rest), standing: hello.standing,
                    clips: hello.clips.mapValues { $0.map { MascotStep(frameID($0.frame), $0.milliseconds) } },
                    weights: weights
                )
            }
        }
        self.moods = moods
    }

    subscript(mood: MascotMood) -> MascotMoodClips { moods[mood]! }
}

enum MascotEvent: Equatable, Sendable {
    case clip(String)
    case hop(height: Double)
}

/// Picks what the mascot does next, like the site's loop.
struct MascotDirector {
    let clips: MascotMoodClips
    private(set) var last: String?
    let tired: Bool

    init(_ clips: MascotMoodClips, tired: Bool = false) {
        self.tired = tired
        self.clips = clips
    }

    /// A pause between events for moods without a drawn base cycle.
    func restDelay(using random: inout some RandomNumberGenerator) -> Double {
        Double.random(in: tired ? 3.5...6.5 : 0.7...2.1, using: &random)
    }

    /// Base moods keep their cycle and add an event only now and then.
    func skipsEvent(using random: inout some RandomNumberGenerator) -> Bool {
        clips.base != nil && Double.random(in: 0..<1, using: &random) < 0.45
    }

    /// A weighted pick that never repeats the previous event. Hops need a
    /// standing mood; weights naming a missing clip are ignored.
    mutating func next(using random: inout some RandomNumberGenerator) -> MascotEvent? {
        let options = clips.weights
            .filter { name, weight in
                weight > 0 && name != last && (name == "hop" ? clips.standing : clips.clips[name] != nil)
            }
            .sorted { $0.key < $1.key }
        guard !options.isEmpty else { return nil }
        var roll = Double.random(in: 0..<options.reduce(0) { $0 + $1.value }, using: &random)
        var chosen = options[options.count - 1].key
        for (name, weight) in options {
            roll -= weight
            if roll < 0 { chosen = name; break }
        }
        last = chosen
        return chosen == "hop" ? .hop(height: Double.random(in: 0.8...1.1, using: &random)) : .clip(chosen)
    }
}

/// What the mascot does when it is clicked. Each click picks a different one
/// than the last, so clicking again never repeats the same reaction.
enum MascotReaction: String, CaseIterable, Sendable {
    /// Hops and switches to the waving pose with a glow.
    case wave
    /// A high hop into the celebrating pose, swinging its hips.
    case cheer
    /// Two quick hops in the current pose.
    case doubleHop
    /// A shake from side to side with a blink.
    case wiggle
    /// A squash and stretch with an antenna dip.
    case squash
    /// A burst of typing, or a sip of coffee while typing.
    case busy

    enum Motion: Equatable, Sendable {
        case hop(height: Double)
        case doubleHop
        case wiggle
        case squash
    }

    var motion: Motion {
        switch self {
        case .wave, .busy: .hop(height: 0.9)
        case .cheer: .hop(height: 1.3)
        case .doubleHop: .doubleHop
        case .wiggle: .wiggle
        case .squash: .squash
        }
    }

    /// The pose to show for a moment, or nil to keep the current one.
    func mood(from current: MascotMood) -> MascotMood? {
        switch self {
        case .wave: current == .hello ? nil : .hello
        case .cheer: .celebrate
        case .busy: current == .working ? .coffee : .working
        case .doubleHop, .wiggle, .squash: nil
        }
    }

    /// The drawn clip to play right away in `mood`, if it has one.
    func clip(in mood: MascotMood, clips: MascotMoodClips, using random: inout some RandomNumberGenerator) -> String? {
        let wanted: [String]
        switch self {
        case .wave: wanted = ["glowAntennaDip", "glow"]
        case .cheer: wanted = [Bool.random(using: &random) ? "hipLeft" : "hipRight"]
        case .doubleHop: wanted = ["blinkAntennaDip", "blink"]
        case .wiggle: wanted = ["blink"]
        case .squash: wanted = ["antennaDip"]
        case .busy: wanted = mood == .coffee ? ["action"] : ["keyPress"]
        }
        return wanted.first { clips.clips[$0] != nil }
    }

    /// A random reaction other than `last`.
    static func pick(after last: MascotReaction?, using random: inout some RandomNumberGenerator) -> MascotReaction {
        allCases.filter { $0 != last }.randomElement(using: &random)!
    }
}

/// CSS `cubic-bezier(x1, y1, x2, y2)`.
struct CubicBezier: Sendable {
    let x1, y1, x2, y2: Double

    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        (self.x1, self.y1, self.x2, self.y2) = (x1, y1, x2, y2)
    }

    static let linear = CubicBezier(0, 0, 1, 1)
    static let out = CubicBezier(0.22, 1, 0.36, 1)

    func callAsFunction(_ x: Double) -> Double {
        let x = min(max(x, 0), 1)
        if x1 == y1 && x2 == y2 { return x }
        // Solve the curve's x(t) = x, Newton first, bisection as a fallback.
        var t = x
        for _ in 0..<8 {
            let error = sample(t, x1, x2) - x
            if abs(error) < 1e-6 { return sample(t, y1, y2) }
            let slope = derivative(t, x1, x2)
            if abs(slope) < 1e-6 { break }
            t -= error / slope
        }
        var low = 0.0, high = 1.0
        t = x
        for _ in 0..<40 {
            let value = sample(t, x1, x2)
            if abs(value - x) < 1e-7 { break }
            if value < x { low = t } else { high = t }
            t = (low + high) / 2
        }
        return sample(t, y1, y2)
    }

    private func sample(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t
    }

    private func derivative(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * p1 + 6 * u * t * (p2 - p1) + 3 * t * t * (1 - p2)
    }
}

/// Where the mascot is drawn at one moment. Offsets are shares of the image
/// height (negative is up); scales act around the feet.
struct MascotPose: Equatable, Sendable {
    var offsetY = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
    var rotationDegrees = 0.0
    var shadowScaleX = 1.0
    var shadowScaleY = 1.0
    var shadowOpacity = 1.0

    static let rest = MascotPose()
}

enum MascotMotion {
    private struct Keyframe {
        let offset: Double
        let values: [Double]
        let easing: CubicBezier
    }

    private static func interpolate(_ frames: [Keyframe], at progress: Double) -> [Double] {
        let progress = min(max(progress, 0), 1)
        guard let index = frames.lastIndex(where: { $0.offset <= progress }), index < frames.count - 1 else {
            return frames[frames.count - 1].values
        }
        let from = frames[index], to = frames[index + 1]
        let local = from.easing((progress - from.offset) / (to.offset - from.offset))
        return zip(from.values, to.values).map { $0 + ($1 - $0) * local }
    }

    /// Seconds a hop lasts (site: 820 + 120 × height ms).
    static func hopDuration(height: Double) -> Double { 0.82 + 0.12 * height }

    /// One hop: anticipation squash, stretched rise, hang, fall, landing squash
    /// and a small settle. About 6.5% of the mascot's height at height 1.
    static func hop(progress: Double, height: Double) -> MascotPose {
        let h = 0.065 * height
        let body = interpolate([
            Keyframe(offset: 0, values: [0, 1, 1], easing: .linear),
            Keyframe(offset: 0.16, values: [0.012, 1.07, 0.9], easing: CubicBezier(0.3, 0, 0.2, 1)),
            Keyframe(offset: 0.46, values: [-h, 0.95, 1.07], easing: CubicBezier(0.15, 0.7, 0.35, 1)),
            Keyframe(offset: 0.56, values: [-h * 1.08, 1, 1], easing: CubicBezier(0.55, 0, 0.85, 0.35)),
            Keyframe(offset: 0.8, values: [0.01, 1.09, 0.88], easing: CubicBezier(0.2, 0.9, 0.3, 1)),
            Keyframe(offset: 0.9, values: [0, 0.98, 1.03], easing: .out),
            Keyframe(offset: 1, values: [0, 1, 1], easing: .linear),
        ], at: progress)
        let shadow = interpolate([
            Keyframe(offset: 0, values: [1, 1, 1], easing: .linear),
            Keyframe(offset: 0.16, values: [1.12, 1, 1], easing: .linear),
            Keyframe(offset: 0.5, values: [0.55, 0.55, 0.35], easing: .linear),
            Keyframe(offset: 0.8, values: [1.18, 1, 1], easing: .linear),
            Keyframe(offset: 1, values: [1, 1, 1], easing: .linear),
        ], at: progress)
        return MascotPose(offsetY: body[0], scaleX: body[1], scaleY: body[2],
                          shadowScaleX: shadow[0], shadowScaleY: shadow[1], shadowOpacity: shadow[2])
    }

    /// Seconds per sway cycle (site: 5.2 s).
    static let swayPeriod = 5.2

    /// A gentle rise and rock that starts and ends at rest.
    static func sway(time: Double) -> (offsetY: Double, rotationDegrees: Double) {
        let angle = 2 * Double.pi * (time / swayPeriod).truncatingRemainder(dividingBy: 1)
        return (-0.0055 * (1 - cos(angle)), -0.8 * sin(angle))
    }

    /// Seconds the pop on a mood change lasts (site: 460 ms).
    static let popDuration = 0.46

    /// The small pop that marks a change of pose: 0.9 to 1.035 to 1.
    static func pop(progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        if progress < 0.6 {
            return 0.9 + (1.035 - 0.9) * CubicBezier.out(progress / 0.6)
        }
        return 1.035 + (1 - 1.035) * CubicBezier.out((progress - 0.6) / 0.4)
    }

    /// Seconds a click wiggle lasts.
    static let wiggleDuration = 0.7

    /// A shake that fades out: three swings, up to 9° at the start.
    static func wiggle(progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        return 9 * sin(2 * .pi * 3 * progress) * (1 - progress) * (1 - progress)
    }

    /// Seconds a click squash lasts.
    static let squashDuration = 0.62

    /// A squash and stretch that settles like a spring, around the feet.
    static func squash(progress: Double) -> (scaleX: Double, scaleY: Double) {
        let progress = min(max(progress, 0), 1)
        let wave = sin(2 * .pi * 1.75 * progress) * exp(-4.2 * progress)
        return (1 + 0.14 * wave, 1 - 0.18 * wave)
    }

    /// Evenly spaced samples of a motion for a Core Animation keyframe
    /// animation. Linear interpolation between this many samples matches the
    /// eased curves closely, and the window server then plays them at the
    /// display's refresh rate without waking the app.
    static func samples<Value>(count: Int, _ value: (Double) -> Value) -> [Value] {
        precondition(count > 1)
        return (0..<count).map { value(Double($0) / Double(count - 1)) }
    }

    /// Everything combined for one moment.
    static func pose(hopProgress: Double?, hopHeight: Double, swayTime: Double?, swayWeight: Double, popProgress: Double?) -> MascotPose {
        var pose = hopProgress.map { hop(progress: $0, height: hopHeight) } ?? .rest
        if let swayTime, swayWeight > 0 {
            let sway = sway(time: swayTime)
            pose.offsetY += sway.offsetY * swayWeight
            pose.rotationDegrees += sway.rotationDegrees * swayWeight
        }
        if let popProgress {
            let scale = pop(progress: popProgress)
            pose.scaleX *= scale
            pose.scaleY *= scale
        }
        return pose
    }
}

enum MascotAnimationRate: CaseIterable, Sendable {
    case sway, reaction

    var minimum: Float { self == .sway ? 8 : 24 }
    var maximum: Float { self == .sway ? 15 : 30 }
    var preferred: Float { self == .sway ? 12 : 30 }
}

struct MascotSwaySchedule: Equatable, Sendable {
    let active: TimeInterval
    let rest: TimeInterval
    let amplitude: Double
    var cycle: TimeInterval { active + rest }

    static func schedule(for mood: MascotMood) -> Self {
        switch mood {
        case .tired: Self(active: 7.8, rest: 12, amplitude: 0.45)
        case .angry: Self(active: 0.66, rest: 7.8, amplitude: 0.45)
        default: Self(active: MascotMotion.swayPeriod, rest: 7.8, amplitude: 1)
        }
    }

    func isMoving(at elapsed: TimeInterval) -> Bool {
        elapsed >= 0 && elapsed.truncatingRemainder(dividingBy: cycle) < active
    }
}

enum MascotFrameFallback {
    static func candidates(for id: String) -> [String] {
        var ids = [id]
        if let prefix = id.first, ["a", "z", "p"].contains(String(prefix)),
           id.dropFirst().allSatisfy(\.isNumber) {
            ids.append("h" + id.dropFirst())
        }
        if !ids.contains("h01") { ids.append("h01") }
        return ids
    }

    static func resolve(_ id: String, exists: (String) -> Bool) -> String? {
        candidates(for: id).first(where: exists)
    }
}
