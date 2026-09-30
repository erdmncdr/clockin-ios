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

    /// Iki zaman karti kaydinin baslangici da bitisi de bu kadar yakinsa ayni satirin iki
    /// kopyasidir. Iki cihazda ayri ayri ice aktarilan dokumler birlesince ayni is birkac
    /// dakika farkli iki kayit olarak kaliyordu (7 Agustos 11:51-21:09 ve 11:51-21:05 gibi).
    /// Kartin kendi yazdigi cakismalar (gece yarisini ya da ay sonunu asan satirlar) boyle
    /// yakin degildir ve sayilmaz.
    static let copyTolerance: TimeInterval = 15 * 60

    /// Iki kez ice aktarilmis gorunen zaman karti kayitlarinin sayisi ve fazladan sayilan sure.
    static func importedTwice(in sessions: [WorkSession]) -> (pairs: Int, extra: TimeInterval) {
        let ordered = sessions.filter(isTimecard).sorted { $0.start < $1.start }
        var parents = Array(ordered.indices)
        func root(_ index: Int) -> Int {
            var current = index
            while parents[current] != current {
                parents[current] = parents[parents[current]]
                current = parents[current]
            }
            return current
        }
        var open: [Int] = []
        for (index, session) in ordered.enumerated() {
            open.removeAll {
                ordered[$0].end <= session.start
                    || session.start.timeIntervalSince(ordered[$0].start) > copyTolerance
            }
            for other in open where abs(ordered[other].end.timeIntervalSince(session.end)) <= copyTolerance {
                // Eslesen kopyalar ayni gruba girer; uc kopya uc cift diye sayilmaz.
                let group = root(index), otherGroup = root(other)
                if group != otherGroup { parents[group] = otherGroup }
            }
            open.append(index)
        }
        var groups: [Int: (count: Int, total: TimeInterval, longest: TimeInterval)] = [:]
        for (index, session) in ordered.enumerated() {
            let key = root(index)
            let group = groups[key] ?? (count: 0, total: 0, longest: 0)
            groups[key] = (group.count + 1, group.total + session.duration, max(group.longest, session.duration))
        }
        // Molalar duvar saatine dahil olabilir; kazanci sisiren sakli calisma suresidir.
        return groups.values.reduce((pairs: 0, extra: 0)) {
            ($0.pairs + $1.count - 1, $0.extra + $1.total - $1.longest)
        }
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
