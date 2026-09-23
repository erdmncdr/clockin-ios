import Foundation

enum MascotAsset: String {
    case idle, working, paused, celebrate, angry, tired, proud

    static func session(running: RunningSession?, angry: Bool = false, friendly: Bool = false,
                        streakBrokenYesterday: Bool = false, quietDays: Int = 0,
                        proudUntil: Date? = nil, now: Date = .now) -> Self {
        if let proudUntil, now < proudUntil { return .proud }
        if running?.isPaused == false { return .working }
        if angry && !friendly { return .angry }
        if running == nil && (streakBrokenYesterday || quietDays >= 2) { return .tired }
        return running == nil ? .idle : .paused
    }

    static func quietDays(since lastWorkedDay: Date?, now: Date, calendar: Calendar = .current) -> Int {
        guard let lastWorkedDay else { return 0 }
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: lastWorkedDay),
                                             to: calendar.startOfDay(for: now)).day ?? 0)
    }

    var mood: MascotMood {
        switch self {
        case .idle: .hello
        case .working: .working
        case .paused: .coffee
        case .celebrate: .celebrate
        case .angry: .angry
        case .tired: .tired
        case .proud: .proud
        }
    }

    var message: String {
        switch self {
        case .angry: String(localized: "Your companion is waiting")
        case .tired: String(localized: "A little focus will wake us up")
        case .proud: String(localized: "Look how far you have come!")
        case .idle: String(localized: "Ready when you are")
        case .working: String(localized: "You are doing great, keep going!")
        case .paused: String(localized: "Taking a reset break")
        case .celebrate: String(localized: "Every focused hour makes your companion stronger.")
        }
    }
}

extension ClockinSnapshot {
    func companionState(at date: Date) -> MascotAsset {
        MascotAsset.session(running: running, angry: isAngry, friendly: companionFriendly,
                            quietDays: MascotAsset.quietDays(since: companionLastWorkedDay, now: date),
                            proudUntil: companionProudUntil, now: date)
    }
}
