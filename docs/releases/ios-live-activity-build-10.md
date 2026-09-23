# Clockin iOS 0.2 (10): restore current UI with Live Activity updates

Build 9 incorrectly used old main (`c871b11`) as its UI baseline. Build 8 used
the `clockin-companion-art` working tree, including approved changes not yet
committed. Build 10 restores that working-tree UI and merges the build-9
Live Activity integration into it.

## Reproducible source preparation

Run `scripts/prepare-ios-live-activity-release.py` with explicit `--ui-source`
and a new `--output` directory. Never prepare this release from main alone or
from `git archive` of companion-art HEAD: both omit approved working changes.

Current snapshot: `/tmp/clockin-live-activity-release-0.2-10/source`.
UI source: `/Users/erdemincedere/Clockin/clockin-companion-art`, HEAD `37acc79`
plus its working tree. The source has 324 files with a SHA-256 manifest and
provenance JSON next to the snapshot.

317 files are byte-identical to the current companion-art UI source. The seven
differences are the five Live Activity integration files and the same two 3D
presentation/launch-route exclusions documented for build 8. Experimental
Prototype sources are excluded, as in build 8. Originals are untouched.

The three-way SessionMirror merge preserves celebration subscriptions,
`refreshCompanion`, wardrobe data, companion accessories, mood and proud state.
It also retains token observation, background registration and replacement of
activities when calculation state changes. The server is unchanged.

## Validation

- All 30 existing iOS check groups passed against the snapshot.
- Signed Release archive succeeded with zero warnings/errors.
- App and widget both report 0.2 (10); recursive strict signature check passed.
- Eight CAF sounds, no GLB/USDZ assets in the archive.
- Production relay URL, Live Activities and frequent updates enabled.
- Source hashes unchanged after archive.
- These checks do not establish physical-device rendering or delivery cadence.

The user confirmed 2–3 earnings updates without reopening the app, followed by
a stall. At upload time the service used APNs priority 5; the subsequent
server-only priority correction is documented in `ios-live-activity-delivery.md`.
The service sends once per minute; that is not a guaranteed on-screen interval.

## Distribution

Archive and upload log: `/tmp/clockin-live-activity-release-0.2-10/`.
TestFlight upload/export succeeded on 20 September 2026 at 03:03 Istanbul time.
Processing completed. English and Turkish test notes were saved, and TestFlight
beta review submission completed with automatic notifications enabled.
Both **Clockin Internal** and **Clockin Public Beta** independently show
**0.2 (10): Testing**, with 90 days remaining. Existing builds remain active.

Build ID: `f18931f9-8839-4010-8b38-f1e1f97678b9`.
Public beta: https://testflight.apple.com/join/tr6kSDMN .
