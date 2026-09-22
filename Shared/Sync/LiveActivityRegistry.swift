import Foundation

/// Hangi sunucu kaydinin artik bir etkinlige ait olmadigina karar verir.
///
/// Ayri durmasinin sebebi: yanlis karar yasayan bir kaydi siler ve kullanici
/// mesai suresince guncelleme alamaz. ActivityKit'e bagli olmadigi icin
/// dogrudan test edilebiliyor.
enum LiveActivityRegistry {
    /// Yasayan etkinliklerin token'larina ait olmayan kayitlar.
    ///
    /// - Parameters:
    ///   - stored: token, gecerlilik sonu (1970'ten beri saniye).
    ///   - live: su an ekranda olan etkinliklerin token'lari.
    static func stale(stored: [String: Double], live: Set<String>) -> [String: Double] {
        stored.filter { !live.contains($0.key) }
    }

    /// Silme kuyrugunun yeni hali. Kuyrukta duran bir token'in gecerlilik
    /// sonu geriye cekilmez: erken dusen bir tarih, silme denemesi
    /// tamamlanmadan kaydi kuyruktan atardi.
    static func merging(queue: [String: Double], with stale: [String: Double]) -> [String: Double] {
        var result = queue
        for (token, expiresAt) in stale {
            result[token] = max(result[token] ?? 0, expiresAt)
        }
        return result
    }
}
