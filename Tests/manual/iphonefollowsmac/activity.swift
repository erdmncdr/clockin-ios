import Foundation
import Synchronization
protocol ActivityAttributes: Sendable {}
struct ActivityContent<S: Sendable>: Sendable { let state: S; let staleDate: Date? }
enum PushType { case token }
enum DismissalPolicy { case immediate }
struct ActivityAuthorizationInfo { var areActivitiesEnabled: Bool { true } }
@MainActor final class UIApplication {
 enum State { case active, inactive, background }
 static let shared = UIApplication()
 var applicationState: State = .active
}
@MainActor enum SharedStore { static let exchangeRates = Exchange(); struct Exchange { let latestRate: Double? = nil } }
@MainActor enum LiveActivityPrivacy { static var enabled = false }
@MainActor final class LiveActivityPush {
 static let shared = LiveActivityPush()
 static let endpoint: URL? = URL(string: "https://example.invalid")
 var observed = [String](); var stopped = [String](); var registrations = Set<String>()
 func observe(_ a: FakeActivity) { observed.append(a.id); registrations.insert(a.id) }
 func activityCouldNotStart() {}
 func stop(id: String, token: Data?, expiresAt: Date?) async { stopped.append(id); registrations.remove(id) }
}
struct WorldState: Sendable { var activities = [FakeActivity](); var denyRequests = false; var requests = 0; var ends = 0 }
enum World { static let state = Mutex(WorldState()) }
typealias Activity<A> = FakeActivity
final class FakeActivity: Sendable {
 let id: String
 let attributes: ClockinActivityAttributes
 let stored: Mutex<ActivityContent<ClockinActivityState>>
 var content: ActivityContent<ClockinActivityState> { stored.withLock { $0 } }
 var pushToken: Data? { nil }
 init(id: String, attributes: ClockinActivityAttributes, content: ActivityContent<ClockinActivityState>) {
  self.id=id; self.attributes=attributes; self.stored=Mutex(content)
 }
 static var activities: [FakeActivity] { World.state.withLock { $0.activities } }
 static func request(attributes: ClockinActivityAttributes, content: ActivityContent<ClockinActivityState>, pushType: PushType?) throws -> FakeActivity {
  try World.state.withLock { state in
   state.requests += 1
   if state.denyRequests { throw NSError(domain: "ActivityAuthorizationError.targetMaximumExceeded", code: 1) }
   let a = FakeActivity(id: "new-\(state.requests)", attributes: attributes, content: content)
   state.activities.append(a); return a
  }
 }
 func end(_ content: ActivityContent<ClockinActivityState>?, dismissalPolicy: DismissalPolicy) async {
  await EndGate.shared.suspendOnce()
  World.state.withLock { state in state.ends += 1; state.activities.removeAll { $0.id == id } }
 }
 func update(_ content: ActivityContent<ClockinActivityState>) async { stored.withLock { $0=content } }
}

// Ilk end sinirinda eski sureci durdur; yeni mirror ayni sistem kartlarini gorur.
@MainActor final class EndGate {
 static let shared = EndGate()
 var armed = false
 private var reached = false
 private var observer: CheckedContinuation<Void, Never>?
 private var pending: CheckedContinuation<Void, Never>?
 func suspendOnce() async {
  guard armed else { return }
  armed = false
  await withCheckedContinuation { continuation in
   pending = continuation; reached = true; observer?.resume(); observer = nil
  }
 }
 func wait() async {
  if reached { return }
  await withCheckedContinuation { observer = $0 }
 }
 func release() { pending?.resume(); pending = nil; reached = false }
}
@main struct ActivityChecks {
 @MainActor static func main() async {
  var count = 0
  func check(_ value: Bool, _ name: String) {
   precondition(value, name); count += 1; print("ok: \(name)")
  }
  let start = Date.now.addingTimeInterval(-60)
  let running = RunningSession(start: start, accumulated: 0, resumedAt: start, note: "")
  let state = ClockinActivityState(running: running, hourlyRate: 25, earned: 1)
  let content = ActivityContent(state: state, staleDate: state.staleDate)
  func card(_ id: String, _ currency: String, remote: Bool = false) -> FakeActivity {
   FakeActivity(id: id, attributes: .init(currencyCode: currency,
    remoteUpdatesUntil: remote ? .now.addingTimeInterval(3600) : nil,
    localState: remote ? state : nil), content: content)
  }
  func reset(_ cards: [FakeActivity], deny: Bool = false) {
   World.state.withLock { $0 = WorldState(activities: cards, denyRequests: deny) }
   LiveActivityPush.shared.observed = []; LiveActivityPush.shared.stopped = []
   LiveActivityPush.shared.registrations = Set(cards.map(\.id))
   UIApplication.shared.applicationState = .active
   LiveActivityPrivacy.enabled = false
  }
  func refresh(_ mirror: ExtractedMirror, currency: String = "EUR", running: RunningSession? = running) {
   mirror.syncActivity(running: running, hourlyRate: 25, earned: 2, currencyCode: currency, theme: .carbon)
  }
  let old = card("old-USD", "USD", remote: true)
  reset([old]); LiveActivityPrivacy.enabled = true
  let interrupted = ExtractedMirror()
  EndGate.shared.armed = true
  refresh(interrupted)
  await EndGate.shared.wait()
  check(FakeActivity.activities.count == 2 && World.state.withLock { $0.requests == 1 },
   "successful request reaches interruption with old and replacement cards")
  let replacement = FakeActivity.activities.first { $0.id != old.id }!
  World.state.withLock { $0.denyRequests = true }
  let relaunched = ExtractedMirror()
  for _ in 0..<3 { refresh(relaunched); await relaunched.finish() }
  check(World.state.withLock { $0.requests == 1 && $0.activities.map(\.id) == [replacement.id] },
   "foreground recovery retains matching replacement with further requests denied")
  check(LiveActivityPush.shared.registrations == [replacement.id],
   "interrupted replacement recovery removes the old relay registration")
  check(LiveActivityPush.shared.observed.contains(replacement.id) && replacement.content.state.earnedAtUpdate == 2,
   "recovered replacement is observed and updated")
  EndGate.shared.release(); await interrupted.finish()

  reset([old], deny: true)
  let mirror = ExtractedMirror()
  refresh(mirror); await mirror.finish()
  check(World.state.withLock { $0.requests == 1 && $0.ends == 0 && $0.activities.map(\.id) == [old.id] },
   "ordinary request failure preserves the only fallback card")
  reset([card("a", "USD", remote: true), card("b", "GBP", remote: true)], deny: true)
  LiveActivityPrivacy.enabled = true
  refresh(mirror); await mirror.finish()
  check(FakeActivity.activities.count == 1 && LiveActivityPush.shared.registrations.count == 1,
   "failed replacement of incompatible duplicates retains one fallback and registration")
  reset([card("a", "EUR"), card("b", "EUR")], deny: true)
  refresh(mirror); await mirror.finish()
  check(World.state.withLock { $0.requests == 0 && $0.activities.count == 1 },
   "compatible duplicates reconcile without requesting")
  let frozen = card("frozen", "EUR", remote: true)
  var staleContent = state; staleContent.hourlyRate = 50
  await frozen.update(ActivityContent(state: staleContent, staleDate: nil))
  reset([old, frozen], deny: true); LiveActivityPrivacy.enabled = true
  refresh(mirror); await mirror.finish()
  check(World.state.withLock { $0.requests == 0 && $0.activities.map(\.id) == [frozen.id] }
    && frozen.content.state.hourlyRate == 25,
   "matching uses immutable calculation even when mutable content differs")
  let staleFrozen = FakeActivity(id: "stale-frozen", attributes: .init(currencyCode: "EUR",
   remoteUpdatesUntil: .now.addingTimeInterval(3600), localState: staleContent), content: content)
  reset([staleFrozen]); LiveActivityPrivacy.enabled = true
  refresh(mirror); await mirror.finish()
  check(World.state.withLock { $0.requests == 1 && $0.activities.count == 1 && $0.activities[0].id != staleFrozen.id },
   "matching mutable content cannot hide incompatible immutable calculation")
  reset([old]); UIApplication.shared.applicationState = .background
  refresh(mirror); await mirror.finish()
  check(World.state.withLock { $0.requests == 0 && $0.activities.map(\.id) == [old.id] },
   "background immutable change preserves fallback without requesting")
  check(LiveActivityPush.shared.registrations.isEmpty, "consent off removes retained fallback registration")
  reset([old], deny: true)
  refresh(mirror); await mirror.finish()
  check(FakeActivity.activities.count == 1 && LiveActivityPush.shared.registrations.isEmpty,
   "consent off also removes fallback registration after foreground request failure")
  reset([old]); UIApplication.shared.applicationState = .background
  refresh(mirror); await mirror.finish()
  UIApplication.shared.applicationState = .active
  refresh(mirror); await mirror.finish()
  check(World.state.withLock { $0.requests == 1 && $0.ends == 1 && $0.activities.count == 1 },
   "foreground replaces the deferred card")
  reset([]); UIApplication.shared.applicationState = .background
  refresh(mirror); await mirror.finish()
  check(World.state.withLock { $0.requests == 1 && $0.activities.count == 1 },
   "empty background slot preserves intent request path")
  reset([card("a", "EUR"), old], deny: true)
  UIApplication.shared.applicationState = .background
  refresh(mirror, running: nil); await mirror.finish()
  check(FakeActivity.activities.isEmpty && LiveActivityPush.shared.registrations.isEmpty,
   "background clock-out ends all cards and registrations")
  reset([old])
  refresh(mirror)
  refresh(mirror, running: nil)
  await mirror.finish()
  check(World.state.withLock { $0.requests == 0 && $0.activities.isEmpty },
   "queued running work cannot revive an idle timer")
  let savedFont = UserDefaults.standard.object(forKey: ClockinFontChoice.preferenceKey)
  defer {
   if let savedFont { UserDefaults.standard.set(savedFont, forKey: ClockinFontChoice.preferenceKey) }
   else { UserDefaults.standard.removeObject(forKey: ClockinFontChoice.preferenceKey) }
  }
  for remote in [false, true] {
   let existing = card("font-card", "EUR", remote: remote)
   reset([existing]); LiveActivityPrivacy.enabled = remote
   for font in ClockinFontChoice.allCases {
    UserDefaults.standard.set(font.rawValue, forKey: ClockinFontChoice.preferenceKey)
    refresh(mirror); await mirror.finish()
    check(World.state.withLock { $0.requests == 0 && $0.ends == 0 && $0.activities.map(\.id) == [existing.id] }
      && existing.content.state.font == font,
      "font \(font.rawValue) updates existing activity, remote=\(remote), with no replacement")
   }
  }
  print("All \(count) Live Activity lifecycle checks passed.")
 }
}
