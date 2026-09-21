import ActivityKit
import Foundation

struct ClockinActivityAttributes: ActivityAttributes {
    typealias ContentState = ClockinActivityState
    var currencyCode: String
    var remoteUpdatesUntil: Date? = nil
    /// Kept in the on-device ActivityKit attributes; never sent to the relay.
    var localState: ContentState? = nil

    func displayState(_ state: ContentState) -> ContentState {
        guard state.remoteTick, let localState else { return state }
        return localState.applyingTick(state, expiresAt: remoteUpdatesUntil)
    }
}
