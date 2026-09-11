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

struct ImportComparisonSummary {
    let items: [ImportComparisonItem]

    var newItems: [ImportComparisonItem] { items.filter { $0.kind == .new } }
    var matchedItems: [ImportComparisonItem] { items.filter { $0.kind == .matched } }
    var duplicateItems: [ImportComparisonItem] { items.filter { $0.kind == .duplicate } }
    var totalDuration: TimeInterval { items.reduce(0) { $0 + $1.session.duration } }
}
