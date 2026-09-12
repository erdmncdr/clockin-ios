import ActivityKit
import Foundation

struct ClockinActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// Sayacin sifir ani. Calisirken gecen sure `now - timerStart`; boylece
        /// Live Activity her saniye guncelleme istemeden kendisi sayar.
        var timerStart: Date
        /// Duraklatildiysa sayacin durdugu an.
        var pausedAt: Date?
        var hourlyRate: Double
        var earnedAtUpdate: Double
        var usdTryRate: Double?
        var note: String
        var theme: ClockinThemeChoice = .carbon
    }

    var currencyCode: String
}

extension ClockinActivityAttributes.ContentState {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timerStart = try container.decode(Date.self, forKey: .timerStart)
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        // Onceki surumun acik etkinliginde kazanc alani bulunmayabilir.
        earnedAtUpdate = try container.decodeIfPresent(Double.self, forKey: .earnedAtUpdate) ?? 0
        usdTryRate = try container.decodeIfPresent(Double.self, forKey: .usdTryRate)
        note = try container.decode(String.self, forKey: .note)
        theme = try container.decodeIfPresent(ClockinThemeChoice.self, forKey: .theme) ?? .carbon
    }

    init(running: RunningSession, hourlyRate: Double, earned: Double, usdTryRate: Double? = nil, theme: ClockinThemeChoice = .carbon) {
        if let resumedAt = running.resumedAt {
            timerStart = resumedAt.addingTimeInterval(-running.accumulated)
            pausedAt = nil
        } else {
            // Duraklatilmis seansta tarih secimi keyfi; baslangic sabit oldugu
            // icin ayni seans her seferinde ayni durumu uretir.
            timerStart = running.start
            pausedAt = running.start.addingTimeInterval(running.accumulated)
        }
        self.theme = theme
        self.hourlyRate = hourlyRate
        earnedAtUpdate = earned
        self.usdTryRate = usdTryRate
        note = running.note
    }

    var isPaused: Bool { pausedAt != nil }

    var timerRange: ClosedRange<Date> {
        LiveTimerRange.interval(from: timerStart)
    }
}
