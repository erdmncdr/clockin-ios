// swiftc -swift-version 6 -strict-concurrency=complete -module-cache-path /tmp/clockin-momentum-module-cache Clockin/Views/Momentum/MoneyMomentum.swift Tests/manual/momentum/main.swift -o /tmp/clockin-momentum-tests && /tmp/clockin-momentum-tests
import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1; print("ok: \(name)")
}

func momentum(_ earnings: Double, rate: Double = 36,
              state: MoneyMomentum.SessionState = .working,
              currency: String = "USD", fx: Double? = 40) -> MoneyMomentum {
    MoneyMomentum(hourlyRate: rate, currentEarnings: earnings, state: state,
                  currencyCode: currency, usdTryRate: fx)
}

let zero = momentum(0)
check(zero.nextTarget == 10 && zero.remaining == 10 && zero.progress == 0, "zero earnings targets ten")
check(zero.perSecond == 0.01 && zero.tryPerSecond == 0.4 && zero.isEarning, "hourly rate converts to per-second USD and TRY")
let exact = momentum(20)
check(exact.nextTarget == 30 && exact.remaining == 10 && exact.progress == 0, "exact multiple advances to the next ten")
let below = momentum(19.999)
check(below.nextTarget == 20 && abs(below.remaining! - 0.001) < 1e-10 && abs(below.progress! - 0.9999) < 1e-10,
      "just below uses unrounded earnings")
check(momentum(20.nextDown).nextTarget == 20, "nearest representable value below target does not skip it")
check(momentum(20.nextUp).nextTarget == 30, "nearest representable value above target advances")
let free = momentum(0, rate: 0)
check(free.perSecond == 0 && free.tryPerSecond == 0 && free.progress == 0, "zero hourly rate is finite")
let paused = momentum(24, state: .paused)
check(!paused.isEarning && paused.perSecond == 0.01, "paused session shows potential earning power")
check(paused.nextTarget == 30 && paused.remaining == 6 && paused.progress == 0.4, "paused milestone uses supplied frozen earnings")
let idle = momentum(0, state: .idle)
check(!idle.isEarning && idle.perSecond == 0.01 && idle.nextTarget == nil && idle.progress == nil && idle.remaining == nil,
      "idle shows earning power without a milestone")
let large = momentum(1_000_000_000_024)
check(large.nextTarget == 1_000_000_000_030 && large.remaining == 6 && large.progress == 0.4,
      "very large totals preserve the ten-unit interval")
check(momentum(Double.greatestFiniteMagnitude).nextTarget == nil, "unrepresentable target is unavailable instead of overflowing")
check(momentum(10, fx: nil).tryPerSecond == nil, "absent TRY rate stays absent")
check(momentum(10, currency: "EUR").tryPerSecond == nil, "non-USD accounts do not convert to TRY")
check(momentum(-5, rate: -1).nextTarget == 10 && momentum(-5, rate: -1).perSecond == 0, "negative inputs are clamped")
check(momentum(.nan, rate: .infinity, fx: .nan).nextTarget == nil && momentum(.nan, rate: .infinity, fx: .nan).perSecond == 0,
      "nonfinite inputs stay out of displayed calculations")
check(momentum(0, fx: -40).tryPerSecond == nil && momentum(0, fx: 0).tryPerSecond == nil, "invalid exchange rates are omitted")
print("\(checks) momentum checks passed")
