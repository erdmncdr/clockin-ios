import Combine
import Foundation

@MainActor
final class WardrobeStore: ObservableObject {
    static let shared = WardrobeStore()
    @Published private(set) var state: WardrobeState
    @Published private(set) var earned = 0
    private(set) var ledger: [WardrobePurchase]
    let didPersist = PassthroughSubject<Void, Never>()
    private let defaults: UserDefaults
    private var archive: [WorkSession]?
    private var lastGoal: Double?
    private var lastDay: Date?
    var balance: Int { WardrobeCoins.balance(earned: earned, ledger: ledger) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = WardrobeState.decode(defaults.string(forKey: WardrobeState.stateKey))
        ledger = Self.readLedger(defaults)
    }

    private static func readLedger(_ defaults: UserDefaults) -> [WardrobePurchase] {
        defaults.string(forKey: WardrobeState.ledgerKey)?.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode([WardrobePurchase].self, from: $0) } ?? []
    }

    func refresh(sessions: [WorkSession], now: Date, dailyGoal: Double) -> (first: Bool, items: [String]) {
        let saved = WardrobeState.decode(defaults.string(forKey: WardrobeState.stateKey))
        let savedLedger = Self.readLedger(defaults)
        let reloaded = saved != state || savedLedger != ledger
        if saved != state { state = saved; archive = nil }
        if savedLedger != ledger { ledger = savedLedger; archive = nil }
        let day = Calendar.current.startOfDay(for: now)
        guard archive != sessions || lastGoal != dailyGoal || lastDay != day else { return (false, []) }
        archive = sessions; lastGoal = dailyGoal; lastDay = day
        let calculation = WardrobeEarnings(sessions: sessions, dailyGoal: dailyGoal, now: now, calendar: .current)
        earned = calculation.coins
        // Mevcut arsiv ilk kez yuklenince tanitim bildirimi oynatilmaz.
        let first = !state.seeded && sessions.isEmpty
        let items = state.unlock(calculation.progress,
                                 legacy: defaults.string(forKey: CompanionAccessory.storageKey) ?? "Auto",
                                 legacyOwned: Set(defaults.stringArray(forKey: CompanionAccessory.seenKey) ?? []))
        // Satin alma kaydi sahipligin ikinci kanitidir.
        state.owned.formUnion(ledger.filter { $0.cost > 0 }.map(\.itemID))
        // Backup restore writes defaults outside this store; adoption is a persisted change too.
        persist(includingReload: reloaded)
        return (first, items)
    }

    func equip(_ item: WardrobeItem) { state.equip(item); persist(); SessionMirror.shared.refreshCompanion() }
    func clear(_ slot: WardrobeSlot) {
        if slot == .colorway { state.colorway = "classic" }
        else if WardrobeSlot.furniture.contains(slot) { state.furniture[slot.rawValue] = nil }
        else { state.equipped[slot.rawValue] = nil }
        persist(); SessionMirror.shared.refreshCompanion()
    }
    func buy(_ item: WardrobeItem) -> Bool {
        guard state.buy(item, earned: earned, ledger: &ledger, now: .now) else { return false }
        persist(); SessionMirror.shared.refresh()
        return true
    }
    func setRoomArrangement(_ draft: RoomArrangement, room: String) {
        // Merge only this room; a refresh or purchase must not be overwritten.
        state.homeArrangement.merge(room:room,from:draft)
        persist()
    }
    func setHomeLayout(_ layout: CompanionHomeLayout) { state.homeLayout = layout; persist() }
    func setHomeLamp(_ enabled: Bool) { state.homeLampOn = enabled; persist() }

    func selected(_ item: WardrobeItem) -> Bool {
        if item.slot == .colorway { return state.colorway == item.id }
        if item.slot == .room { return state.room == item.id }
        return state.equipped[item.slot.rawValue] == item.id || state.furniture[item.slot.rawValue] == item.id
    }
    struct SyncedState {
        fileprivate var state: WardrobeState
        fileprivate var ledger: [WardrobePurchase]
        fileprivate var stateJSON: String
        fileprivate var ledgerJSON: String
    }

    // Encode both values before the primary archive is changed. Seed bookkeeping stays local.
    func prepareSynced(_ incoming: WardrobeState, ledger: [WardrobePurchase]) throws -> SyncedState {
        var state = incoming
        state.seeded = self.state.seeded
        let stateJSON = String(decoding: try JSONEncoder().encode(state), as: UTF8.self)
        let ledgerJSON = String(decoding: try JSONEncoder().encode(ledger), as: UTF8.self)
        return SyncedState(state: state, ledger: ledger, stateJSON: stateJSON, ledgerJSON: ledgerJSON)
    }

    func applySynced(_ prepared: SyncedState) {
        defaults.set(prepared.ledgerJSON, forKey: WardrobeState.ledgerKey)
        defaults.set(prepared.stateJSON, forKey: WardrobeState.stateKey)
        ledger = prepared.ledger; state = prepared.state; archive = nil
        // No didPersist: the coordinator refreshes derived services after the whole apply.
    }

    private func persist(includingReload: Bool = false) {
        // Once harcama yazilir; yarim kalan kayit ledger'dan sahipligi onarabilir.
        guard let data = try? JSONEncoder().encode(ledger),
              let ledgerJSON = String(data: data, encoding: .utf8), let stateJSON = state.json else { return }
        // JSON dictionary key order can change between encodes. Diff values, not text.
        let changed = Self.readLedger(defaults) != ledger
            || WardrobeState.decode(defaults.string(forKey: WardrobeState.stateKey)) != state
        if defaults.string(forKey: WardrobeState.ledgerKey) != ledgerJSON {
            defaults.set(ledgerJSON, forKey: WardrobeState.ledgerKey)
        }
        if defaults.string(forKey: WardrobeState.stateKey) != stateJSON {
            defaults.set(stateJSON, forKey: WardrobeState.stateKey)
        }
        // Refresh often computes the same value. Only actual persistence emits a local change.
        if changed || includingReload { didPersist.send() }
    }
}
