import Foundation

struct MoneyMomentum: Sendable {
    enum SessionState: Sendable {
        case idle, working, paused
    }

    let perSecond: Double
    let tryPerSecond: Double?
    let isEarning: Bool
    let nextTarget: Double?
    let remaining: Double?
    let progress: Double?

    init(hourlyRate: Double, currentEarnings: Double, state: SessionState,
         currencyCode: String, usdTryRate: Double?) {
        // Duraklama potansiyel hizi sifirlamaz; baslik gercek kazanc olmadigini belirtir.
        perSecond = hourlyRate.isFinite ? max(0, hourlyRate) / 3600 : 0
        isEarning = state == .working
        if currencyCode == "USD", let rate = usdTryRate, rate.isFinite, rate > 0,
           (perSecond * rate).isFinite {
            tryPerSecond = perSecond * rate
        } else {
            tryPerSecond = nil
        }

        // Temsil edilemeyen onluk hedef yerine yaniltici bir tutar gostermeyelim.
        guard state != .idle, currentEarnings.isFinite, currentEarnings.ulp <= 10 else {
            nextTarget = nil
            remaining = nil
            progress = nil
            return
        }
        let current = max(0, currentEarnings)
        let remainder = current.truncatingRemainder(dividingBy: 10)
        // Tam onlukta sonraki hedefe gecilir; gosterim yuvarlamasi hesaba karismaz.
        let target = current + (10 - remainder)
        nextTarget = target
        remaining = max(0, target - current)
        progress = min(1, max(0, remainder / 10))
    }
}
