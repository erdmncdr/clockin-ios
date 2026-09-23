import Foundation

/// Cosmetic achievements only: these never feed wardrobe coin earnings or XP.
enum PurchaseBadges {
    static func make(ledger: [WardrobePurchase]) -> [InsightsBadge] {
        let ids = Set(ledger.filter { $0.cost > 0 }.map(\.itemID))
        let bought = WardrobeCatalog.items.filter { ids.contains($0.id) && ($0.unlock.price ?? 0) > 0 }
        let outfits = bought.filter { WardrobeSlot.outfit.contains($0.slot) }.count
        let home = bought.filter(\.isHomeItem).count
        // Cumlenin tamami cevrilir: Turkcede isim ve sayi ayni kalipla eklenemez.
        func series(_ prefix: String, _ thresholds: [Int], _ count: Int, _ titles: [String],
                    _ requirement: (Int) -> String, _ icon: String) -> [InsightsBadge] {
            zip(thresholds, titles).map { threshold, title in
                InsightsBadge(id: prefix + String(threshold), title: title,
                    requirement: requirement(threshold), icon: icon,
                    unlocked: count >= threshold, progress: String(localized: "\(count) / \(threshold) purchased"))
            }
        }
        return series("collection", [1, 5, 10, 20, 40], bought.count,
                      [String(localized: "First find"), String(localized: "Small collection"), String(localized: "Curated collection"), String(localized: "Collector"), String(localized: "Grand collection")],
                      { String(localized: "Buy \($0) different companion items with earned coins") }, "bag.fill")
            + series("outfits", [1, 3, 6, 12, 20], outfits,
                     [String(localized: "New look"), String(localized: "Style starter"), String(localized: "Style collection"), String(localized: "Wardrobe curator"), String(localized: "Style icon")],
                     { String(localized: "Buy \($0) different outfit items or colors with earned coins") }, "tshirt.fill")
            + series("home", [1, 3, 6, 12, 18], home,
                     [String(localized: "First furnishing"), String(localized: "Cozy corner"), String(localized: "Room maker"), String(localized: "Home curator"), String(localized: "Dream home")],
                     { String(localized: "Buy \($0) different home items or rooms with earned coins") }, "house.fill")
    }
}
