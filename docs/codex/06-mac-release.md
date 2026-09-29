# Brief 06: release pipeline for the new Mac app

Read `docs/mac-plan.md` (phase 4) and the old pipeline in the read-only
checkout `../clockin-main`: `docs/macos-releases.md`, `DISTRIBUTION_STATUS.md`,
`build-app.sh`, and everything in `scripts/` that concerns the Mac
(`release.sh`, `notarize-xcode.sh`, `package-notarized-app.sh`,
`package-dmg.sh`, `publish-mac.sh`, `publish-mac-release.py`,
`test-release-verification.sh`, `verify-release.swift`).

The old app was a Swift package built by a script. The new Mac app is the
`ClockinMac` target in `Clockin.xcodeproj` (Release: bundle id
`com.ismailakdag.clockin`, product `Clockin.app`, macOS 14, hardened runtime,
not sandboxed, Sparkle 2.10.0 via SPM, `Config/ClockinMac-Info.plist` with
the Sparkle feed and EdDSA public key, `MARKETING_VERSION` 2.0.0 /
`CURRENT_PROJECT_VERSION` 11 in build settings). The project's Release config
signs ad hoc; the pipeline must supply Developer ID signing.

Existing users update in place through the same Sparkle feed
(`https://github.com/ismailakdag/clockin/releases/download/macos-updates/appcast.xml`),
so the archive, DMG, appcast and signatures must satisfy exactly what the old
pipeline guaranteed (read `verify-release.swift`).

## Deliverables

Put the pipeline in `Tools/mac-release/` in this repo:

1. `build.sh VERSION BUILD` — `xcodebuild archive` of scheme `ClockinMac`,
   configuration Release, universal (`arm64 x86_64`, `ONLY_ACTIVE_ARCH=NO`),
   Developer ID signing passed as build-setting overrides (team `LU36PKDPT3`,
   identity `Developer ID Application`, manual style, `--timestamp`,
   hardened runtime), version/build overrides, then `-exportArchive` with an
   `ExportOptions.plist` (method `developer-id`). After export, verify:
   universal slices, bundle id, version/build, Info.plist Sparkle keys,
   hardened runtime flag, `codesign --verify --deep --strict`, and that every
   nested Sparkle component (framework, XPC services, Updater/Autoupdate) is
   signed by the same team with timestamps. If Xcode's export does not sign
   Sparkle's nested helpers correctly, port the old inside-out signing.
2. `notarize.sh APP_OR_DMG` — `notarytool submit --keychain-profile ClockinNotary --wait`,
   staple, `spctl -a -vv` / `stapler validate`. Never print credentials.
3. `package.sh VERSION BUILD` — DMG like the old one, signed; Sparkle
   `sign_update` / appcast generation using Sparkle's own tools from the
   resolved package artifacts (find them under the DerivedData
   `SourcePackages/artifacts` path the build used), the EdDSA private key from
   the existing Keychain item (account `com.ismailakdag.clockin`; never export
   or print it); verify the result with the ported `verify-release.swift`
   against the shipped public key.
4. `publish.sh VERSION` — port of the old publish flow to GitHub releases in
   `ismailakdag/clockin` (versioned release first, anonymous download check,
   then the `macos-updates` feed), refusing to run without `--yes`, with a
   `--dry-run` that prints every step. Keep `make_latest=false` behavior.
5. `docs/mac-releases.md` — the new release procedure end to end, including
   the one-time setup that already exists on this Mac (notary profile,
   Sparkle key) and what changed from the old SPM process.
6. Release notes draft `docs/release-notes-mac-2.0.0.md` (English, the old
   notes' style; read `../clockin-main/docs/release-notes-1.1.*.md`): the app
   is rebuilt on the iPhone app's code; list what is new for Mac users
   (Insights, goals and pace, companion wardrobe/coins/home, badges and
   levels, desk mode, focus radio, new chimes, Turkish, per-entry recovery
   of damaged data, etc. — read `PARITY.md` and `docs/mac-plan.md`), and the
   behavior changes they must know about: level rules (goals no longer add
   XP), history ranges now calendar-based (7D→week, 30D→month, 3M→6 months),
   old system chime sounds mapped to bundled sounds, the interface size
   setting removed (the window resizes freely), global shortcuts no longer
   need Accessibility permission.

## Rules

- Scripts are bash with `set -euo pipefail`, readable, no clever one-liners;
  Python only where the old pipeline used it. Keep secrets out of logs and
  out of the repo. Outputs go under `build/mac-release/` (already ignored).
- You cannot run xcodebuild, notarytool, network or Keychain here. Make
  every script support `--dry-run` and run the dry runs; run `bash -n` and
  `shellcheck` if available; unit-check any Python/Swift helper that can run
  offline (for example the verifier against a synthetic appcast and a
  throwaway EdDSA key you generate in `/tmp`).
- Do not touch `Clockin.xcodeproj`, app sources, or `../clockin-main`. Do not
  commit.

## Result

Write `docs/codex/06-mac-release-result.md`: what each script does, what you
could verify, what I must run and check by hand, and any project setting the
archive needs.
