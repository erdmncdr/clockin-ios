import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

let expected = [
    ("rp", "Radio Paradise", "https://stream.radioparadise.com/aac-320"),
    ("rp-mellow", "Mellow Mix", "https://stream.radioparadise.com/mellow-320"),
    ("rp-global", "Global Mix", "https://stream.radioparadise.com/global-320"),
    ("rp-serenity", "Serenity", "https://stream.radioparadise.com/serenity")
]
check(RadioStation.storageKey == "Clockin.RadioStation", "shared station preference key")
check(RadioStation.stations.count == expected.count, "exactly four Paradise channels")
check(Set(RadioStation.stations.map(\.id)).count == expected.count, "station ids are unique")
for (id, name, url) in expected {
    let station = RadioStation.selected(id)
    check(station.id == id && station.name == name, "stored \(id) selects \(name)")
    check(station.url.absoluteString == url, "\(id) uses the supplied HTTPS stream")
    check(!station.description.isEmpty, "\(id) has a short description")
}
for id: String? in [nil, "", "unknown", "RP", "removed-provider"] {
    check(RadioStation.selected(id).id == "rp", "missing or invalid id \(id ?? "nil") falls back to main")
}
for state in RadioPlaybackState.allCases {
    check(state.showsCard == (state != .stopped), "\(state) card visibility")
    check(state.requestsPlayback == (state == .playing || state == .connecting), "\(state) playback request")
    check(state.keepsNowPlaying == [.playing, .connecting, .paused].contains(state), "\(state) Now Playing lifetime")
}
for reason in RadioPlaybackEnd.allCases {
    for radioOwns in [false, true] {
        for chimeNeeds in [false, true] {
            let decision = RadioCleanupDecision(reason, radioOwnsAudioSession: radioOwns,
                                                chimeNeedsAudioSession: chimeNeeds)
            let context = "\(reason), radio \(radioOwns), chime \(chimeNeeds)"
            if reason == .pause {
                check(!decision.clearNowPlaying && !decision.removeRemoteCommands, "pause keeps lock screen resume: \(context)")
                check(!decision.releasePlayer && !decision.deactivateAudioSession, "pause retains playback resources: \(context)")
                check(decision.state == .paused && decision.state.showsCard, "pause keeps Today card: \(context)")
            } else {
                check(decision.clearNowPlaying && decision.removeRemoteCommands, "terminal cleanup removes system player: \(context)")
                check(decision.releasePlayer, "terminal cleanup releases player: \(context)")
                check(decision.deactivateAudioSession == (radioOwns && !chimeNeeds), "only release unused radio session: \(context)")
                check(!decision.state.keepsNowPlaying, "terminal state cannot publish Now Playing: \(context)")
                check(decision.state == (reason == .failure ? .failed : .stopped), "failure offers retry; stop hides card: \(context)")
            }
        }
    }
}
let paused = RadioCleanupDecision(.pause, radioOwnsAudioSession: true, chimeNeedsAudioSession: false).state
let stopped = RadioCleanupDecision(.stop, radioOwnsAudioSession: true, chimeNeedsAudioSession: false).state
check(paused.showsCard && !stopped.showsCard, "play then pause then stop removes the card")
let failed = RadioCleanupDecision(.failure, radioOwnsAudioSession: true, chimeNeedsAudioSession: false).state
check(failed.showsCard && !failed.requestsPlayback && !failed.keepsNowPlaying, "failed playback offers in-app retry without remote resurrection")
print("\(checks) radio checks passed")
