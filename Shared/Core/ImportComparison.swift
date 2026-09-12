import Foundation

enum ImportMatchKind: String, Identifiable {
    case new
    case matched
    case duplicate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: return "NEW"
        case .matched: return "UPDATE"
        case .duplicate: return "SKIP"
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
        case .daysInFile: "Days in file"
        case .wholeRange: "Whole range"
        }
    }

    var explanation: String {
        switch self {
        case .daysInFile: "Only days that appear in the file are reviewed."
        case .wholeRange: "Every day between the file's first and last entry is reviewed."
        }
    }
}

struct ImportComparisonSummary {
    let items: [ImportComparisonItem]
    /// Kapsama giren, ama dosyadaki hicbir satirla eslesmeyen kendi kayitlarin.
    /// Ice aktarma bunlara kendiliginden dokunmaz.
    let leftovers: [WorkSession]

    init(items: [ImportComparisonItem], leftovers: [WorkSession] = []) {
        self.items = items
        self.leftovers = leftovers
    }

    var newItems: [ImportComparisonItem] { items.filter { $0.kind == .new } }
    var matchedItems: [ImportComparisonItem] { items.filter { $0.kind == .matched } }
    var duplicateItems: [ImportComparisonItem] { items.filter { $0.kind == .duplicate } }
    var totalDuration: TimeInterval { items.reduce(0) { $0 + $1.session.duration } }
}
