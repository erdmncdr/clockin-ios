import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    precondition(condition, name); checks += 1
}
let now = Date()
let paid = WardrobeCatalog.items.filter { ($0.unlock.price ?? 0) > 0 }
let ledger = paid.map { WardrobePurchase(itemID: $0.id, cost: $0.unlock.price!, date: now) }
let all = PurchaseBadges.make(ledger: ledger)
check(all.count == 15 && all.allSatisfy(\.unlocked), "all purchase milestones are reachable with current catalog")
check(Set(all.map(\.id)).count == all.count, "purchase IDs unique")
check(PurchaseBadges.make(ledger: []).allSatisfy { !$0.unlocked }, "empty ledger earns nothing")
let first = ledger[0]
let invalid = [WardrobePurchase(itemID: "cap", cost: 100, date: now),
               WardrobePurchase(itemID: "fake", cost: 100, date: now),
               WardrobePurchase(itemID: "scarf", cost: 0, date: now)]
check(PurchaseBadges.make(ledger: invalid).allSatisfy { !$0.unlocked }, "free, unknown and zero-cost entries cannot count")
check(PurchaseBadges.make(ledger: Array(repeating: first, count: 50)).filter(\.unlocked).count == 2, "duplicate purchases count once for total and category")
for prefix in ["collection", "outfits", "home"] {
    let series = all.filter { $0.id.hasPrefix(prefix) }
    check(series.map(\.tier) == Array(BadgeTier.allCases.prefix(5)), "five collection tiers for \(prefix)")
    let candidates = prefix == "collection" ? paid : paid.filter {
        prefix == "outfits" ? WardrobeSlot.outfit.contains($0.slot) : $0.isHomeItem
    }
    for badge in series {
        let threshold = Int(badge.id.dropFirst(prefix.count))!
        func badges(_ count: Int) -> [InsightsBadge] {
            PurchaseBadges.make(ledger: candidates.prefix(count).map {
                WardrobePurchase(itemID: $0.id, cost: $0.unlock.price!, date: now)
            })
        }
        check(badges(threshold - 1).first { $0.id == badge.id }?.unlocked == false, "below \(badge.id)")
        check(badges(threshold).first { $0.id == badge.id }?.unlocked == true, "at \(badge.id)")
    }
}
let stats = InsightsSnapshot(sessions: [], sessionEarnings: [:], now: now, calendar: .current)
check(stats.badges.count == 46 && Set(stats.badges.map(\.id)).isDisjoint(with: Set(all.map(\.id))), "46 work badges preserved with no ID collisions")
check(BadgeTier.allCases.allSatisfy { tier in stats.badges.contains { $0.tier == tier } }, "work badges span all six tiers")
check(BadgeTier.forBadge("first") == .launch && BadgeTier.forBadge("titan") == .eternal, "effort extremes")
let coins = WardrobeEarnings(sessions: [], dailyGoal: 0, now: now, calendar: .current).coins
_ = PurchaseBadges.make(ledger: ledger)
check(WardrobeEarnings(sessions: [], dailyGoal: 0, now: now, calendar: .current).coins == coins, "collection badges do not award coins recursively")
print("\(checks) badge tier and purchase checks passed")

check(Set(stats.badges.filter { $0.tier == .eternal }.map(\.id)) == ["titan", "bigmonth12", "streak365", "active500"], "only four lifetime milestones enter Eternal")
check(stats.badges.allSatisfy { BadgeMission.allCases.contains($0.mission) }, "every work badge has a mission effect")
for seeded in [false, true] {
    var wardrobe = WardrobeState(); wardrobe.seeded = seeded
    _ = wardrobe.unlock(WardrobeProgress())
    check(wardrobe.owned.isSuperset(of: ["ataturk-portrait", "turkish-flag"]), "free gifts for new and existing users")
    let original = wardrobe.owned
    _ = wardrobe.unlock(WardrobeProgress())
    check(wardrobe.owned == original, "free gifts are idempotent")
    for id in ["ataturk-portrait", "turkish-flag"] {
        wardrobe.equip(WardrobeCatalog.item(id)!)
    }
    check(wardrobe.furniture["wallLeft"] == "ataturk-portrait" && wardrobe.furniture["wallRight"] == "turkish-flag", "gifts equip together")
}
check(PurchaseBadges.make(ledger:[WardrobePurchase(itemID:"ataturk-portrait",cost:50,date:now), WardrobePurchase(itemID:"turkish-flag",cost:50,date:now)]).allSatisfy { !$0.unlocked }, "gifts never count as purchases")
print("\(checks) total space tier and gift checks passed")
