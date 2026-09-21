import SwiftUI
import UIKit

extension CelebrationReaction {
    var mascotReaction: MascotReaction {
        switch self {
        case .dailyGoal, .streak: .cheer
        case .moneyMilestone: .wiggle
        case .clockIn: .squash
        case .pause: .busy
        case .clockOut: .wave
        }
    }

    var mood: MascotMood {
        switch self {
        case .dailyGoal, .streak: .celebrate
        case .pause: .coffee
        case .moneyMilestone, .clockIn, .clockOut: .hello
        }
    }
}

struct CelebrationMascot: View {
    let mood: MascotMood
    let reaction: MascotReaction
    let moving: Bool
    @State private var tap: MascotTap?
    @Environment(\.clockinContentActive) private var contentActive

    var body: some View {
        ClockinMotionMascot(mood: mood, tap: tap)
            .environment(\.clockinContentActive, contentActive && moving)
            .task(id: moving) {
                guard moving else { tap = nil; return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                tap = MascotTap(id: (tap?.id ?? 0) + 1, reaction: reaction)
            }
    }
}
