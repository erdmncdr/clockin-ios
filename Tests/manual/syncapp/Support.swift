import Combine
import Foundation

// Only platform effects are substituted. ClockStore, WardrobeStore, bridge, sidecar,
// snapshot validation, observation, coordinator and debounce are the production sources.
@MainActor enum SharedStore {
    static var clock: ClockStore { fatalError("Default store factory must not run in offline checks") }
}
@MainActor final class SessionMirror {
    static let shared = SessionMirror()
    func refresh() {}
    func refreshCompanion() {}
    func refreshChimes(force: Bool = false) {}
}

