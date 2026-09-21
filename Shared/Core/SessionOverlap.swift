import Foundation

/// Ust uste binen kayitlari bulur.
///
/// Ayni anda iki is yapilamaz, dolayisiyla zamanlari cakisan iki kayit ya
/// ayni isin iki yazimi ya da yanlis girilmis bir saattir. Ikisi de gunu
/// sisirir; bir gun 24 saatten fazla gorunebilir.
///
/// `addSession` yalnizca birebir ayni saatleri reddediyordu; bir dakika
/// kaydirilmis ayni is uyarisiz giriyordu.
enum SessionOverlap {
    /// Iki kaydin zamanlari kesisiyor mu.
    ///
    /// Araliklar yarim acik sayilir. Ayrica dakika hassasiyetindeki arayuzde
    /// bir kaydin bitisiyle sonraki kaydin baslangici ayni dakikadaysa,
    /// yalnizca bu sinirdaki saniye farki bir devir olarak kabul edilir.
    static func intersects(_ a: WorkSession, _ b: WorkSession) -> Bool {
        intersects(start: a.start, end: a.end, otherStart: b.start, otherEnd: b.end)
    }

    private static func intersects(start: Date, end: Date, otherStart: Date, otherEnd: Date) -> Bool {
        guard start < end, otherStart < otherEnd,
              start < otherEnd, otherStart < end else { return false }
        // Both records must extend beyond the handoff minute. Duplicates,
        // contained entries and overlapping short records remain conflicts.
        func minute(_ date: Date) -> Double {
            floor(date.timeIntervalSinceReferenceDate / 60)
        }
        func isHandoff(_ earlierStart: Date, _ earlierEnd: Date, _ laterStart: Date, _ laterEnd: Date) -> Bool {
            minute(earlierStart) < minute(laterStart)
                && minute(earlierEnd) == minute(laterStart)
                && minute(earlierEnd) < minute(laterEnd)
        }
        return !isHandoff(start, end, otherStart, otherEnd)
            && !isHandoff(otherStart, otherEnd, start, end)
    }

    /// Verilen araliga degen kayitlar. Duzenleme sirasinda kaydin kendisi
    /// `excluding` ile disarida birakilir, yoksa her kayit kendisiyle cakisir.
    static func touching(start: Date, end: Date, in sessions: [WorkSession],
                         excluding id: UUID? = nil) -> [WorkSession] {
        guard end > start else { return [] }
        return sessions.filter {
            $0.id != id && intersects(start: start, end: end, otherStart: $0.start, otherEnd: $0.end)
        }
    }

    /// Listede baska bir kayitla cakisan her kaydin kimligi.
    ///
    /// Kayitlar baslangica gore siralanip tek gecise indirgeniyor: 600 kayitta
    /// her cifti denemek yuz seksen bin karsilastirma demek, bu ise gecmis
    /// ekrani her ciziminde calisiyor.
    static func conflicting(in sessions: [WorkSession]) -> Set<UUID> {
        let ordered = sessions.sorted { $0.start < $1.start }
        var conflicted = Set<UUID>()
        // O ana kadar gorulen en gec bitis. Yeni kayit bundan once basliyorsa
        // mutlaka birisiyle cakisiyordur.
        var open: [WorkSession] = []
        for session in ordered {
            open.removeAll { $0.end <= session.start }
            for other in open where intersects(session, other) {
                conflicted.insert(session.id)
                conflicted.insert(other.id)
            }
            open.append(session)
        }
        return conflicted
    }
}
