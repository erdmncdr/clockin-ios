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

    /// Bundan kisa bir ust uste binme uyari degildir: zaman kartlari dakikaya
    /// yuvarlaniyor ve arka arkaya iki satir bir iki dakika ust uste binebiliyor.
    static let minorOverlap: TimeInterval = 5 * 60

    /// Zaman kartindan gelen ya da onunla duzeltilmis kayit.
    static func isTimecard(_ session: WorkSession) -> Bool {
        session.source != "Clockin" || session.matchedExternalSource != nil
    }

    /// Kullaniciya gosterilecek bir cakisma mi.
    ///
    /// Zaman karti isin resmi kaydidir: iki kart kaydi arasindaki cakisma (gece
    /// yarisini ya da ay sonunu asan satirlar gibi) kartin kendi yazimidir,
    /// kullanicinin burada cozecegi bir sey degil. Birkac dakikalik binmeler de
    /// sayilmaz; ayni kisa kaydin iki kopyasi ise kisa olanin yarisindan fazla
    /// ortustugu icin yine yakalanir.
    static func conflicts(_ a: WorkSession, _ b: WorkSession) -> Bool {
        guard !(isTimecard(a) && isTimecard(b)), intersects(a, b) else { return false }
        let shared = min(a.end, b.end).timeIntervalSince(max(a.start, b.start))
        let shorter = min(a.end.timeIntervalSince(a.start), b.end.timeIntervalSince(b.start))
        return shared > minorOverlap || shared >= shorter / 2
    }

    /// Verilen araliga gercekten cakisan kayitlar. Duzenleme sirasinda kaydin
    /// kendisi `excluding` ile disarida birakilir, yoksa her kayit kendisiyle
    /// cakisir; duzenlenen kaydin kaynagi da ondan okunur. Yeni kayit elle
    /// girilmistir.
    static func touching(start: Date, end: Date, in sessions: [WorkSession],
                         excluding id: UUID? = nil) -> [WorkSession] {
        guard end > start else { return [] }
        let edited = id.flatMap { id in sessions.first { $0.id == id } }
        var candidate = WorkSession(id: id ?? UUID(), start: start, end: end,
                                    duration: end.timeIntervalSince(start), note: "", hourlyRate: 0,
                                    source: edited?.source ?? "Clockin")
        candidate.matchedExternalSource = edited?.matchedExternalSource
        return sessions.filter { $0.id != id && conflicts(candidate, $0) }
    }

    /// Listede baska bir kayitla gercekten cakisan her kaydin kimligi.
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
            for other in open where conflicts(session, other) {
                conflicted.insert(session.id)
                conflicted.insert(other.id)
            }
            open.append(session)
        }
        return conflicted
    }
}
