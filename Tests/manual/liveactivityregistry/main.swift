// swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-registry-cache Shared/Sync/LiveActivityRegistry.swift Tests/manual/liveactivityregistry/main.swift -o /tmp/clockin-registry-tests && /tmp/clockin-registry-tests
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

let hour: Double = 3600
let now = Date(timeIntervalSince1970: 1_800_000_000).timeIntervalSince1970
let a = "aa01", b = "bb02", c = "cc03"

check(LiveActivityRegistry.stale(stored: [:], live: [a]).isEmpty, "no registrations means nothing to remove")
check(LiveActivityRegistry.stale(stored: [a: now + hour], live: [a]).isEmpty,
      "a registration whose activity is on screen is kept")

// Guncelleme uygulamayi oldururken etkinligi de sonlandiriyor; acilista hic
// etkinlik olmuyor ve o kayit sunucuda "canli" sayilmaya devam ediyordu.
let orphaned = LiveActivityRegistry.stale(stored: [a: now + hour], live: [])
check(orphaned == [a: now + hour], "a registration with no activity left is removed")

let mixed = LiveActivityRegistry.stale(stored: [a: now + hour, b: now + 2 * hour], live: [b])
check(mixed == [a: now + hour], "only the registration without an activity is removed")
check(LiveActivityRegistry.stale(stored: [a: now, b: now, c: now], live: [a, b, c]).isEmpty,
      "every registration accounted for leaves the queue alone")

// Etkinlik yeniden baslatildiginda token degisir; eskisi gitmeli, yenisi kalmali.
let replaced = LiveActivityRegistry.stale(stored: [a: now + hour, b: now + hour], live: [b, c])
check(replaced == [a: now + hour], "a replaced token is removed and its successor is untouched")

check(LiveActivityRegistry.merging(queue: [:], with: [a: now]) == [a: now],
      "a stale registration joins an empty queue")
check(LiveActivityRegistry.merging(queue: [b: now], with: [a: now + hour]) == [b: now, a: now + hour],
      "merging keeps what the queue already held")
// Erken bir tarih, silme denemesi tamamlanmadan kaydi kuyruktan atardi.
check(LiveActivityRegistry.merging(queue: [a: now + 2 * hour], with: [a: now]) == [a: now + 2 * hour],
      "an earlier expiry never shortens a queued removal")
check(LiveActivityRegistry.merging(queue: [a: now], with: [a: now + 2 * hour]) == [a: now + 2 * hour],
      "a later expiry extends a queued removal")
check(LiveActivityRegistry.merging(queue: [a: now], with: [:]) == [a: now],
      "nothing stale leaves the queue unchanged")

print("\(checks) live activity registry checks passed")
