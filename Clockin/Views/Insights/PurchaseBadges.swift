import Foundation

/// Cosmetic achievements only: these never feed wardrobe coin earnings or XP.
enum PurchaseBadges {
    static func make(ledger: [WardrobePurchase]) -> [InsightsBadge] {
        let ids = Set(ledger.filter { $0.cost > 0 }.map(\.itemID))
        let bought = WardrobeCatalog.items.filter { ids.contains($0.id) && ($0.unlock.price ?? 0) > 0 }
        let outfits = bought.filter { WardrobeSlot.outfit.contains($0.slot) }.count
        let home = bought.filter(\.isHomeItem).count
        func series(_ prefix: String, _ thresholds: [Int], _ count: Int, _ titles: [String],
                    _ kind: String, _ icon: String) -> [InsightsBadge] {
            zip(thresholds, titles).map { threshold, title in
                InsightsBadge(id: prefix + String(threshold), title: title,
                    requirement: "Buy \(threshold) different \(kind) with earned coins", icon: icon,
                    unlocked: count >= threshold, progress: "\(count) / \(threshold) purchased")
            }
        }
        return series("collection", [1, 5, 10, 20, 40], bought.count,
                      ["First find", "Small collection", "Curated collection", "Collector", "Grand collection"],
                      "companion items", "bag.fill")
            + series("outfits", [1, 3, 6, 12, 20], outfits,
                     ["New look", "Style starter", "Style collection", "Wardrobe curator", "Style icon"],
                     "outfit items or colors", "tshirt.fill")
            + series("home", [1, 3, 6, 12, 18], home,
                     ["First furnishing", "Cozy corner", "Room maker", "Home curator", "Dream home"],
                     "home items or rooms", "house.fill")
    }
}
