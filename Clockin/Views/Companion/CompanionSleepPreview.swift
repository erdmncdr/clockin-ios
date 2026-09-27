#if DEBUG
import SwiftUI

/// The companion asleep in its bed, in both room layouts and each room, at
/// night and by day. Launch with `--companion-sleep-preview`.
struct CompanionSleepPreview: View {
    private func state(room: String, layout: CompanionHomeLayout) -> WardrobeState {
        var state = WardrobeState()
        state.room = room
        state.homeLayout = layout
        state.furniture = ["floorRight": "companion-bed", "floorLeft": "coffee-machine", "desk": "desk-monitor",
                           "wallLeft": "poster", "wallRight": "wall-clock"]
        return state
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(["night", "cozy", "studio"], id: \.self) { room in
                    ForEach([CompanionHomeLayout.deskLeft, .deskRight], id: \.self) { layout in
                        CompanionHomeView(stateOverride: state(room: room, layout: layout), activityOverride: .sleeping,
                                          lightOverride: room == "cozy" ? .day : .night)
                            .aspectRatio(360 / 240, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(12)
        }
        .background(Color.black)
    }
}
#endif
