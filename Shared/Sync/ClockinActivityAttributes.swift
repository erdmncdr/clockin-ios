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
        var note: String
    }

    var currencyCode: String
}

extension ClockinActivityAttributes.ContentState {
    init(running: RunningSession, hourlyRate: Double) {
        if let resumedAt = running.resumedAt {
            timerStart = resumedAt.addingTimeInterval(-running.accumulated)
            pausedAt = nil
        } else {
            // Duraklatilmis seansta tarih secimi keyfi; baslangic sabit oldugu
            // icin ayni seans her seferinde ayni durumu uretir.
            timerStart = running.start
            pausedAt = running.start.addingTimeInterval(running.accumulated)
        }
        self.hourlyRate = hourlyRate
        note = running.note
    }

    var isPaused: Bool { pausedAt != nil }

    /// `Text(timerInterval:)` ust sinira gelince durur; bir hafta yeterince uzak.
    var timerRange: ClosedRange<Date> {
        timerStart...timerStart.addingTimeInterval(7 * 86_400)
    }
}
