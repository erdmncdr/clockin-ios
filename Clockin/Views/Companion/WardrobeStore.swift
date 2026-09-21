import Combine
import Foundation

@MainActor
final class WardrobeStore: ObservableObject {
    static let shared = WardrobeStore()
    @Published private(set) var state: WardrobeState
    @Published private(set) var earned = 0
    private(set) var ledger: [WardrobePurchase]
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
        if saved != state { state = saved; archive = nil }
        let savedLedger = Self.readLedger(defaults)
        if savedLedger != ledger { ledger = savedLedger; archive = nil }
        let day = Calendar.current.startOfDay(for: now)
        guard archive != sessions || lastGoal != dailyGoal || lastDay != day else { return (false, []) }
        archive = sessions; lastGoal = dailyGoal; lastDay = day
        let calculation = WardrobeEarnings(sessions: sessions, dailyGoal: dailyGoal, now: now, calendar: .current)
        earned = calculation.coins
        let first = !state.seeded
        let items = state.unlock(calculation.progress,
                                 legacy: defaults.string(forKey: CompanionAccessory.storageKey) ?? "Auto",
                                 legacyOwned: Set(defaults.stringArray(forKey: CompanionAccessory.seenKey) ?? []))
        // Satin alma kaydi sahipligin ikinci kanitidir.
        state.owned.formUnion(ledger.filter { $0.cost > 0 }.map(\.itemID))
        persist()
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
    private func persist() {
        // Once harcama yazilir; yarim kalan kayit ledger'dan sahipligi onarabilir.
        if let data = try? JSONEncoder().encode(ledger), let json = String(data: data, encoding: .utf8),
           defaults.string(forKey: WardrobeState.ledgerKey) != json { defaults.set(json, forKey: WardrobeState.ledgerKey) }
        if let json = state.json, defaults.string(forKey: WardrobeState.stateKey) != json {
            defaults.set(json, forKey: WardrobeState.stateKey)
        }
    }
}
