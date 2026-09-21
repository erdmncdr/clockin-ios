import Foundation

struct ClockinActivityState: Codable, Hashable, Sendable {
    /// Sayacin sifir ani. Calisirken gecen sure `now - timerStart`; boylece
    /// Live Activity her saniye guncelleme istemeden kendisi sayar.
    var remoteTick: Bool = false
    var timerStart: Date
    /// Duraklatildiysa sayacin durdugu an.
    var pausedAt: Date?
    var hourlyRate: Double
    var earnedAtUpdate: Double
    /// `earnedAtUpdate`'in hesaplandigi an. Etkinlik tutari kendisi
    /// ilerletemez; hangi ana ait oldugu yanina yazilir.
    var updatedAt: Date?
    var usdTryRate: Double?
    var note: String
    var theme: ClockinThemeChoice = .carbon
}

extension ClockinActivityState {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remoteTick = try container.decodeIfPresent(Bool.self, forKey: .remoteTick) ?? false
        if remoteTick {
            timerStart = .distantPast
            pausedAt = nil
            hourlyRate = 0
            earnedAtUpdate = 0
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            usdTryRate = nil
            note = ""
            theme = .carbon
            return
        }
        timerStart = try container.decode(Date.self, forKey: .timerStart)
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        // Onceki surumun acik etkinliginde kazanc alani bulunmayabilir.
        earnedAtUpdate = try container.decodeIfPresent(Double.self, forKey: .earnedAtUpdate) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        usdTryRate = try container.decodeIfPresent(Double.self, forKey: .usdTryRate)
        note = try container.decode(String.self, forKey: .note)
        theme = try container.decodeIfPresent(ClockinThemeChoice.self, forKey: .theme) ?? .carbon
    }

    init(running: RunningSession, hourlyRate: Double, earned: Double, usdTryRate: Double? = nil,
         theme: ClockinThemeChoice = .carbon, updatedAt: Date = .now) {
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
        self.updatedAt = updatedAt
        self.usdTryRate = usdTryRate
        note = running.note
    }

    var isPaused: Bool { pausedAt != nil }

    /// An old, queued push must never overwrite a pause, rate or theme change.
    /// Those changes replace the activity (and thus invalidate its push token).
    func hasSameCalculation(as other: Self) -> Bool {
        timerStart == other.timerStart && pausedAt == other.pausedAt
            && hourlyRate == other.hourlyRate && usdTryRate == other.usdTryRate
            && note == other.note && theme == other.theme
    }

    /// Calisan seansta tutar bu andan sonra geride kalir; duraklatilmis
    /// seansin tutari degismez, eskimez.
    var staleDate: Date? {
        isPaused ? nil : (updatedAt ?? .now).addingTimeInterval(Self.freshFor)
    }

    /// Tutarin guncel sayildigi sure. Saatlik 60 dolarda bir dakika bir
    /// dolar eder; daha uzun sure sessizce eski tutar gostermek yaniltir.
    static let freshFor: TimeInterval = 60

    var timerRange: ClosedRange<Date> {
        LiveTimerRange.interval(from: timerStart)
    }
}

extension ClockinActivityState {
    /// Remote payloads carry time only. Financial/content data stays local.
    func applyingTick(_ tick: Self, expiresAt: Date?, now: Date = .now) -> Self {
        guard tick.remoteTick, !isPaused, let origin = updatedAt,
              let received = tick.updatedAt, received >= origin else { return self }
        let moment = min(received, now, expiresAt ?? now)
        guard moment >= origin else { return self }
        var result = self
        result.earnedAtUpdate = earnedAtUpdate + moment.timeIntervalSince(origin) * hourlyRate / 3600
        result.updatedAt = moment
        return result
    }
}
