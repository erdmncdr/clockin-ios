import Foundation

/// Ust uste binen kayitlari bulur.
///
/// Ayni anda iki is yapilamaz, dolayisiyla zamanlari cakisan iki kayit ya
/// ayni isin iki yazimi ya da yanlis girilmis bir saattir. Ikisi de gunu
/// sisirir: arsivde 9 Agustos 29 saat, 11 Eylul 25 saat gorunuyordu.
///
/// `addSession` yalnizca birebir ayni saatleri reddediyordu; bir dakika
/// kaydirilmis ayni is uyarisiz giriyordu.
enum SessionOverlap {
    /// Iki kaydin zamanlari kesisiyor mu.
    ///
    /// Araliklar yarim acik sayilir: biri otekinin bittigi anda basliyorsa
    /// cakisma yok. Arka arkaya iki vardiya normaldir.
    static func intersects(_ a: WorkSession, _ b: WorkSession) -> Bool {
        a.start < b.end && b.start < a.end
    }

    /// Verilen araliga degen kayitlar. Duzenleme sirasinda kaydin kendisi
    /// `excluding` ile disarida birakilir, yoksa her kayit kendisiyle cakisir.
    static func touching(start: Date, end: Date, in sessions: [WorkSession],
                         excluding id: UUID? = nil) -> [WorkSession] {
        guard end > start else { return [] }
        return sessions.filter { $0.id != id && $0.start < end && start < $0.end }
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
            if !open.isEmpty {
                conflicted.insert(session.id)
                for other in open { conflicted.insert(other.id) }
            }
            open.append(session)
        }
        return conflicted
    }
}
