import Foundation

struct RadioStation: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let url: URL

    static let storageKey = "Clockin.RadioStation"
    static let stations: [RadioStation] = [
        .init(id: "rp", name: "Radio Paradise", description: String(localized: "Main Mix: eclectic, listener-supported, commercial-free"),
              url: URL(string: "https://stream.radioparadise.com/aac-320")!),
        .init(id: "rp-mellow", name: "Mellow Mix", description: String(localized: "Relaxed and mellow music"),
              url: URL(string: "https://stream.radioparadise.com/mellow-320")!),
        .init(id: "rp-global", name: "Global Mix", description: String(localized: "Music from around the world"),
              url: URL(string: "https://stream.radioparadise.com/global-320")!),
        .init(id: "rp-serenity", name: "Serenity", description: String(localized: "Ambient music for quiet focus"),
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
