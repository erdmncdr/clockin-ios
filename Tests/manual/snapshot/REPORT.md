# Snapshot manual harness

Added `Tests/manual/snapshot/main.swift` and documented its invocation under
the build commands in `HANDOFF.md`. Production sources were not modified.

Run from the `iOS` folder:

```bash
swiftc -swift-version 6 -strict-concurrency=complete Shared/Core/Models.swift Shared/Sync/ClockinSnapshot.swift Tests/manual/snapshot/main.swift -o /tmp/clockin-snapshot-tests && /tmp/clockin-snapshot-tests
```

The harness prints `ok` or `FAIL` per check, collects failures, and exits with
status 1 if an assertion or temporary-file operation fails. It compiles the
real snapshot and model files. The tiny `check(_:_:)` follows the Mac harness's
plain assertion style, with the requested per-check output and failure count.

Coverage includes completed plus active duration, accumulated and resumed time,
stale completed totals, stale snapshots with overnight sessions, overnight
sessions resumed today, paused elapsed time and totals, and earnings at 23.75
per hour. Earnings expectations use a small floating-point tolerance and
explicit independently calculated values, including a fractional cent.

Additional checks document mixed-day snapshots, future resume time clamping,
empty and idle snapshots, running/paused/idle JSON round-trips, replacement of
an existing snapshot file, and creation of a nested destination directory.
Missing optional `running` must decode as nil. Missing required `hourlyRate`
or `currencyCode`, malformed JSON, and missing files must make `load` return nil.
These expectations reflect the existing synthesized Codable implementation.

Dates use explicit Gregorian DateComponents for January 14 and 15, 2026. The
calendar uses the system time zone to match production's `Calendar.current`;
no fixture depends on the current date or time. File checks create a unique
temporary directory and remove it with `defer`, including on assertion and
I/O failures. Cleanup errors count as failures. No real App Group path is used.

## Verification limits

Source inspection only. No `swiftc`, `xcodebuild`, or test binary was run,
as explicitly required by the task. Compilation and runtime results remain
unverified and must be checked by the next agent using the command above.

The real `ClockStore` and its observation/import dependencies are excluded.
A compile-only, main-actor-isolated interface stub satisfies the unused
`ClockinSnapshot.init(store:at:)` extension. Every stub access traps to avoid
mistaking it for tested store behavior. `AppGroup` is replaced with a trapping
default URL accessor so accidental implicit file access cannot reach user data.
The harness does not test store-derived totals, rate schedules, initializer
rounding, actual App Group access, widgets, UI, or concurrency execution.
No snapshot arithmetic or elapsed-time implementation is restated.

## Potential behavior issue left unchanged

An unconditional reading of "a snapshot from yesterday returns zero today"
does not match production for a mixed-day snapshot: when `day` is yesterday
but `running.start` is today, the result retains active time and active earnings
using the snapshot's hourly rate. Only completed totals are discarded. The
harness asserts this current behavior: 5400 seconds and 35.625 earnings.
This is a possible stale-metadata concern if such a mixed state can be produced,
not a confirmed application bug. The normal initializer gives `day` the query
date. Whether a mixed state can arise in real usage was not tested.

Overnight sessions contribute no time or earnings to the new day even after
resuming today. This is explicitly documented in production and is asserted
as the current rule. No production fixes were made.
