import Foundation

struct RadioStation: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Looked up on each use, so a language change in Settings applies at once.
    private let descriptionKey: String.LocalizationValue
    let url: URL
    var description: String { String(localized: descriptionKey, bundle: .app) }

    init(id: String, name: String, description: String.LocalizationValue, url: URL) {
        self.id = id; self.name = name; descriptionKey = description; self.url = url
    }

    // Stations are unique by id; the description key is not Hashable.
    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let storageKey = "Clockin.RadioStation"
    static let stations: [RadioStation] = [
        .init(id: "rp", name: "Radio Paradise", description: "Main Mix: eclectic, listener-supported, commercial-free",
              url: URL(string: "https://stream.radioparadise.com/aac-320")!),
        .init(id: "rp-mellow", name: "Mellow Mix", description: "Relaxed and mellow music",
              url: URL(string: "https://stream.radioparadise.com/mellow-320")!),
        .init(id: "rp-global", name: "Global Mix", description: "Music from around the world",
              url: URL(string: "https://stream.radioparadise.com/global-320")!),
        .init(id: "rp-serenity", name: "Serenity", description: "Ambient music for quiet focus",
              url: URL(string: "https://stream.radioparadise.com/serenity")!)
    ]

    static func selected(_ storedID: String?) -> RadioStation {
        stations.first { $0.id == storedID } ?? stations[0]
    }
}

enum RadioPlaybackState: CaseIterable, Sendable {
    case stopped, connecting, playing, paused, failed

    var showsCard: Bool { self != .stopped }
    var requestsPlayback: Bool { self == .connecting || self == .playing }
    var keepsNowPlaying: Bool { requestsPlayback || self == .paused }
}

enum RadioPlaybackEnd: CaseIterable {
    case pause, stop, failure, interruption
}

struct RadioCleanupDecision {
    let state: RadioPlaybackState
    let clearNowPlaying: Bool
    let removeRemoteCommands: Bool
    let releasePlayer: Bool
    let deactivateAudioSession: Bool

    init(_ reason: RadioPlaybackEnd, radioOwnsAudioSession: Bool, chimeNeedsAudioSession: Bool) {
        let endsPlayback = reason != .pause
        switch reason {
        case .pause: state = .paused
        case .failure: state = .failed
        case .stop, .interruption: state = .stopped
        }
        clearNowPlaying = endsPlayback
        removeRemoteCommands = endsPlayback
        releasePlayer = endsPlayback
        deactivateAudioSession = endsPlayback && radioOwnsAudioSession && !chimeNeedsAudioSession
    }
}
