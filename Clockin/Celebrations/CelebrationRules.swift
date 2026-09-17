import Foundation

struct CelebrationBadge: Equatable, Sendable {
    let id: String
    let title: String
    let icon: String
}

enum CelebrationReaction: String, CaseIterable, Sendable {
    case dailyGoal, moneyMilestone, streak, clockIn, pause, clockOut
}

enum CelebrationEvent: Equatable, Sendable {
    case levelUp(level: Int, hours: Int)
    case badge(CelebrationBadge)
    case moreBadges([String])
    case reaction(CelebrationReaction)

    var badgeIDs: Set<String> {
        switch self {
        case .badge(let badge): [badge.id]
        case .moreBadges(let ids): Set(ids)
        default: []
        }
    }
}

struct CelebrationState: Equatable, Sendable {
    var level = 1
    var focusHours = 0
    var badges: [CelebrationBadge] = []
    var day = Date.distantPast
    var dailyHours = 0.0
    var dailyGoal = 0.0
    var streak = 0
    var sessionStart: Date?
    var paused = false
    var earnings = 0.0
    var nextMoneyTarget: Double?
    var currency = "USD"
    var savedPreviousSession = false
}

struct CelebrationPresentation: Equatable {
    let companion: Bool
    let motion: Bool
    let confetti: Bool

    init(reduceMotion: Bool, companionEnabled: Bool) {
        companion = companionEnabled
        motion = companionEnabled && !reduceMotion
        confetti = companionEnabled && !reduceMotion
    }
}

enum CelebrationRules {
    static let levelKey = "Clockin.LastCelebratedLevel"
    static let badgesKey = "Clockin.SeenBadgeIDs"
    static let reactionInterval: TimeInterval = 20

    static func levelUp(from shownOrQueuedLevel: Int, to state: CelebrationState) -> CelebrationEvent? {
        state.level > shownOrQueuedLevel ? .levelUp(level: state.level, hours: state.focusHours) : nil
    }

    static func unseenBadges(in state: CelebrationState, seen: Set<String>, reserved: Set<String>) -> [CelebrationBadge] {
        state.badges.filter { !seen.contains($0.id) && !reserved.contains($0.id) }
    }

    static func reactions(from old: CelebrationState?, to new: CelebrationState) -> [CelebrationReaction] {
        guard let old else { return [] }
        var result: [CelebrationReaction] = []
        if old.sessionStart == nil, new.sessionStart != nil { result.append(.clockIn) }
        if old.sessionStart != nil, new.sessionStart == nil, new.savedPreviousSession { result.append(.clockOut) }
        if old.sessionStart != nil, old.sessionStart == new.sessionStart, !old.paused, new.paused {
            result.append(.pause)
        }
        if old.day == new.day, new.dailyGoal > 0, old.dailyGoal == new.dailyGoal,
           old.dailyHours < new.dailyGoal, new.dailyHours >= new.dailyGoal { result.append(.dailyGoal) }
        if old.sessionStart != nil, old.sessionStart == new.sessionStart, old.currency == new.currency,
           let target = old.nextMoneyTarget, old.earnings < target, new.earnings >= target {
            result.append(.moneyMilestone)
        }
        if [3, 7, 14, 30, 60].contains(where: { old.streak < $0 && new.streak >= $0 }) {
            result.append(.streak)
        }
        return result
    }
}

// Kuyruk ve kalicilik kararlari UIKit olmadan ayni kodla sinanir.
struct CelebrationQueue {
    private(set) var lastLevel: Int?
    private(set) var seenBadgeIDs: Set<String>?
    private(set) var pending: [CelebrationEvent] = []
    private(set) var current: CelebrationEvent?
    private(set) var previous: CelebrationState?
    private(set) var lastReactionAt: TimeInterval?
    private var badgesPresented = 0

    init(lastLevel: Int? = nil, seenBadgeIDs: Set<String>? = nil) {
        self.lastLevel = lastLevel
        self.seenBadgeIDs = seenBadgeIDs
    }

    mutating func ingest(_ state: CelebrationState, now: TimeInterval, canReact: Bool) {
        defer { previous = state }
        if lastLevel == nil { lastLevel = state.level }
        if seenBadgeIDs == nil { seenBadgeIDs = Set(state.badges.map(\.id)) }
        let queuedLevel = pending.compactMap { event -> Int? in
            if case .levelUp(let level, _) = event { return level }; return nil
        }.max() ?? 0
        if let level = CelebrationRules.levelUp(from: max(lastLevel ?? 1, queuedLevel), to: state) {
            pending.removeAll { if case .levelUp = $0 { return true }; return false }
            pending.insert(level, at: 0)
        }
        let reserved = pending.reduce(current?.badgeIDs ?? []) { $0.union($1.badgeIDs) }
        let unseen = CelebrationRules.unseenBadges(in: state, seen: seenBadgeIDs ?? [], reserved: reserved)
        let queuedBadges = pending.filter { if case .badge = $0 { return true }; return false }.count
        let available = max(0, 3 - badgesPresented - queuedBadges)
        pending += unseen.prefix(available).map(CelebrationEvent.badge)
        let overflow = unseen.dropFirst(available).map(\.id)
        if !overflow.isEmpty {
            if let index = pending.firstIndex(where: { if case .moreBadges = $0 { return true }; return false }),
               case .moreBadges(let ids) = pending[index] {
                pending[index] = .moreBadges(ids + overflow)
            } else { pending.append(.moreBadges(overflow)) }
        }
        // Canli tepkiler beklemez; kapali ekranin olayi sonra oynatilmaz.
        if canReact, current == nil, pending.isEmpty,
           let reaction = CelebrationRules.reactions(from: previous, to: state).first,
           lastReactionAt.map({ now - $0 >= CelebrationRules.reactionInterval }) ?? true {
            pending.append(.reaction(reaction))
        }
    }

    mutating func presentNext(active: Bool, blocked: Bool, companionVisible: Bool, now: TimeInterval) {
        guard active, !blocked else {
            pending.removeAll { if case .reaction = $0 { return true }; return false }
            return
        }
        guard current == nil else { return }
        while !pending.isEmpty {
            let event = pending.removeFirst()
            if case .reaction = event {
                guard companionVisible,
                      lastReactionAt.map({ now - $0 >= CelebrationRules.reactionInterval }) ?? true else { continue }
                lastReactionAt = now
            }
            current = event
            switch event {
            case .levelUp(let level, _): lastLevel = max(lastLevel ?? 1, level)
            case .badge:
                if !(seenBadgeIDs ?? []).isSuperset(of: event.badgeIDs) { badgesPresented += 1 }
                seenBadgeIDs?.formUnion(event.badgeIDs)
            case .moreBadges: seenBadgeIDs?.formUnion(event.badgeIDs)
            case .reaction: break
            }
            return
        }
        badgesPresented = 0
    }

    mutating func finish() {
        current = nil
        if pending.isEmpty { badgesPresented = 0 }
    }

    mutating func suspend() {
        if let current {
            switch current {
            case .reaction: break
            case .levelUp(let level, _):
                let hasNewer = pending.contains { event in
                    if case .levelUp(let queued, _) = event { return queued > level }
                    return false
                }
                if !hasNewer { pending.insert(current, at: 0) }
            default: pending.insert(current, at: 0)
            }
        }
        current = nil
        pending.removeAll { if case .reaction = $0 { return true }; return false }
    }

    mutating func reserveTap(now: TimeInterval) -> Bool {
        guard current == nil, pending.isEmpty,
              lastReactionAt.map({ now - $0 >= CelebrationRules.reactionInterval }) ?? true else { return false }
        lastReactionAt = now
        return true
    }
}
