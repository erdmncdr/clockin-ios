import Foundation

enum TimecardRowStatus: String {
    case approved, submitted, draft, unapproved
}

struct TimecardParseResult {
    let sessions: [WorkSession]
    let skippedRowCount: Int
    let statuses: [UUID: TimecardRowStatus]

    init(sessions: [WorkSession], skippedRowCount: Int, statuses: [UUID: TimecardRowStatus] = [:]) {
        self.sessions = sessions
        self.skippedRowCount = skippedRowCount
        self.statuses = statuses
    }

    // Durum nottan tekrar okunmaz; toplam, kayda yazilan sureyle hesaplanir.
    var approvedDuration: TimeInterval {
        sessions.reduce(0) { $0 + (statuses[$1.id] == .approved ? $1.duration : 0) }
    }
    var allowsDeletions: Bool { skippedRowCount == 0 }
}

enum ImportMatchKind: String, Identifiable {
    case new
    case matched
    case duplicate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: return String(localized: "NEW", bundle: .app)
        case .matched: return String(localized: "UPDATE", bundle: .app)
        case .duplicate: return String(localized: "SKIP", bundle: .app)
        }
    }
}

struct ImportComparisonItem: Identifiable {
    let id: UUID
    let session: WorkSession
    let kind: ImportMatchKind
    let localMatch: WorkSession?

    init(session: WorkSession, kind: ImportMatchKind, localMatch: WorkSession? = nil) {
        self.id = session.id
        self.session = session
        self.kind = kind
        self.localMatch = localMatch
    }
}

/// Dosyanin hangi gunlerin dogruluk kaynagi sayilacagi.
///
/// Sayacla tutulan kayitlar yaklasiktir: unutulup acik kalmis, elle duzeltilmis
/// ya da hic girilmemis olabilir. Resmi dokum geldiginde o donemdeki eski
/// kayitlarin ne olacagini kullanici secer, ama once "donem" ne demek buradan
/// belli olur.
enum ImportScope: String, CaseIterable, Identifiable, Sendable {
    /// Yalnizca dosyada satiri olan gunler. Dosyada hic gecmeyen bir gun
    /// sorulmaz bile: izin gunu de olabilir, dosyanin kapsamadigi bir is de.
    case daysInFile
    /// Dosyanin ilk ve son gunu arasindaki her gun. Dokum donemin tamamiysa
    /// dogru olan budur; aradaki bosluklarda kalmis kayitlari da yakalar.
    case wholeRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daysInFile: String(localized: "Days in file", bundle: .app)
        case .wholeRange: String(localized: "Whole range", bundle: .app)
        }
    }

    var explanation: String {
        switch self {
        case .daysInFile: String(localized: "Only days that appear in the file are reviewed.", bundle: .app)
        case .wholeRange: String(localized: "Every day between the file's first and last entry is reviewed.", bundle: .app)
        }
    }
}

struct ImportComparisonSummary {
    let items: [ImportComparisonItem]
    /// Onizlemenin hesaplandigi arsiv; duzeltme ve silme ayni degerleri esas almali.
    let reviewedSessions: [WorkSession]
    /// Kapsama giren, ama dosyadaki hicbir satirla eslesmeyen kendi kayitlarin.
    /// Ice aktarma bunlara kendiliginden dokunmaz.
    let leftovers: [WorkSession]

    init(items: [ImportComparisonItem], reviewedSessions: [WorkSession], leftovers: [WorkSession] = []) {
        self.items = items
        self.reviewedSessions = reviewedSessions
        self.leftovers = leftovers
    }

    func isCurrent(for sessions: [WorkSession]) -> Bool {
        // Sync arsivi siralayabilir; ayni kimligin her alani yine birebir eslesmeli.
        guard reviewedSessions.count == sessions.count else { return false }
        let reviewed = Dictionary(reviewedSessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard reviewed.count == reviewedSessions.count, Set(sessions.map(\.id)).count == sessions.count else { return false }
        return sessions.allSatisfy { reviewed[$0.id] == $0 }
    }

    var newItems: [ImportComparisonItem] { items.filter { $0.kind == .new } }
    var matchedItems: [ImportComparisonItem] { items.filter { $0.kind == .matched } }
    var duplicateItems: [ImportComparisonItem] { items.filter { $0.kind == .duplicate } }
    var totalDuration: TimeInterval { items.reduce(0) { $0 + $1.session.duration } }

    /// Yeni ve duzeltme satirlari: kullanicinin secebilecegi olanlar.
    var actionableItems: [ImportComparisonItem] { items.filter { $0.kind != .duplicate } }

    /// Secimden cikarilmayan yeni ve duzeltme satirlarinin kayitlari.
    ///
    /// Tekrarlar hic gonderilmez. Dosyanin kendi icindeki ikiz satir
    /// onizlemede "tekrar" diye isaretleniyor; ikizinin secimi kaldirilinca
    /// butun dosya gonderilseydi, ice aktarma o satiri bu kez yeni is sanip
    /// ekleyecekti. Kullanicinin istemedigini soyledigi is arka kapidan girerdi.
    func sessionsToImport(excluding excluded: Set<UUID>) -> [WorkSession] {
        actionableItems.filter { !excluded.contains($0.id) }.map(\.session)
    }
}

struct TimecardImportReview {
    let parsed: TimecardParseResult
    var sessions: [WorkSession] { parsed.sessions }
    let matchesApprovedTotal: Bool
    var allowsDeletions: Bool {
        parsed.allowsDeletions && matchesApprovedTotal
    }
    let sourceTitle: String
    let approvedDuration: TimeInterval?
    let leftovers: [WorkSession]
    let summary: ImportComparisonSummary
    var newItems: [ImportComparisonItem] = []
    var matchedItems: [ImportComparisonItem] = []
    var duplicateItems: [ImportComparisonItem] = []
    var duration: TimeInterval = 0

    init(parsed: TimecardParseResult, summary: ImportComparisonSummary,
         sourceTitle: String, approvedDuration: TimeInterval?) {
        self.parsed = parsed
        self.sourceTitle = sourceTitle
        self.approvedDuration = approvedDuration
        self.matchesApprovedTotal = approvedDuration.map { abs($0 - parsed.approvedDuration) <= 60 } ?? true
        self.leftovers = summary.leftovers
        self.summary = summary
        // Gruplar ve toplam bir kez hazirlanir; satirlar tekrar taramaz.
        for item in summary.items {
            duration += item.session.duration
            switch item.kind {
            case .new: newItems.append(item)
            case .matched: matchedItems.append(item)
            case .duplicate: duplicateItems.append(item)
            }
        }
    }
}
