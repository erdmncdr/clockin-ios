# Brief 06 result: Mac release pipeline

Implemented in `Tools/mac-release/`. No Xcode project, app source, old checkout,
Git commits or release services were changed. The existing untracked brief
`docs/codex/06-mac-release.md` was left untouched. Phase 4 remains incomplete
until the real archive, notarization and 1.1.6 update rehearsal are done.

## Deliverables

| File | Behavior |
|---|---|
| `build.sh VERSION BUILD` | Real `ClockinMac` Release archive and Developer ID export; universal/version/signing overrides; per-build DerivedData and source provenance; conditional inside-out Sparkle repair; post-export verification. |
| `ExportOptions.plist` | `developer-id`, local export, manual signing, Developer ID Application, team `LU36PKDPT3`. |
| `verify-app.sh APP VERSION BUILD` | Bundle/version/minimum OS/Sparkle policy checks, universal app and nested binaries, deep/strict signatures, matching team/timestamps/runtime; requires Sparkle 2.10.0 and its helpers; rejects outer-app sandbox/debug entitlements. |
| `notarize.sh APP_OR_DMG` | App ZIP or direct DMG submission using `ClockinNotary --wait`; requires JSON status Accepted; staples, validates and assesses Gatekeeper; keeps submission JSON under the output root. |
| `package.sh VERSION BUILD` | Requires stapled app; signed HFS+ compressed DMG with Applications link and current license/notices; notarizes/staples DMG before signing update bytes; finds Sparkle tools only in this archive's artifacts; Keychain account signing; signed feed verification, tamper tests, checksums, ready marker. |
| `verify-release.swift` | Ports the old public-key Ed25519 feed and enclosure verification, including verifying the feed before parsing XML. Additionally binds one full update to the app version/build, macOS 14.0 and exact versioned GitHub URL. |
| `publish.sh VERSION` / `publish-release.py` | Requires `--yes`; checks local artifacts and source provenance, destination source commit, monotonic live build; immutable versioned release → anonymous byte checks → stable download → signed feed last, all with `make_latest=false`. Stable replacement/validation failures attempt verified rollback. |
| `common.sh` | Shared constants, arguments, paths, nested component enumeration and signature checks. |
| `test-release-verification.sh` / `test-fixtures.swift` | Production tamper checks and offline self-test with a throwaway in-memory key and disposable `/tmp` fixtures. |
| `test-publish.py` | Offline mocked publication, authorization, rollback, credential destination and build-number checks. |
| `docs/mac-releases.md` | Setup, dry runs, end-to-end commands, recovery, project requirements, licensing/source destination prerequisite and actual-device/update rehearsal. |
| `docs/release-notes-mac-2.0.0.md` | English draft in the old bullet style: shared iPhone code, Mac additions, recovery, and all required behavior changes; explicitly says device sync is still pending. |

All script entry points support `--dry-run`; it performs no build, signing,
Keychain or network action. No shipping private key is exported or printed.
Python is confined to the old publisher/test-byte-edit roles. Outputs live in
ignored `build/mac-release/`; the throwaway crypto self-test uses `/tmp`.

## Offline verification

- `bash -n` passed for all seven Bash files with the system Bash.
- Ran dry runs for build, app notarization, DMG notarization, package, publish,
  app verifier, tamper test, shared library and both Python/Swift helper entry
  points. Main command transcripts are in `build/mac-release/checks/`.
- Compiled the Swift verifier and ran the synthetic suite: one valid signed
  release accepted; ten invalid variants rejected (edited feed length,
  same-length archive corruption, same-length feed edit, unsigned feed, wrong
  public key, wrong archive length, HTTP enclosure, wrong build, wrong release
  URL, malformed signature block).
- Thirteen Python tests passed with HTTP, credentials and external process
  operations mocked: no-I/O dry run, required `--yes`, input rejection,
  credential host/redirect guards, upload-before-delete, upload failure,
  verified feed rollback and rollback failure, anonymous byte retry, release
  ordering/`make_latest=false`, downgrade/same-build rejection and missing live
  build rejection.
- `plutil -lint Tools/mac-release/ExportOptions.plist` passed.
- Confirmed `publish.sh` refuses without `--yes` and invalid version arguments
  are rejected before external work.
- `shellcheck` is not installed; it was not downloaded or run.
- Whitespace/scope review completed; protected project/app files are untouched.

No `xcodebuild`, notarytool, Keychain or network command was run. Thus these are
implementation/offline-test results, not proof of a signed archive, Apple
acceptance, Sparkle compatibility in a running old client, or public delivery.

## Project and release-Mac work still required

1. **Share/verify the ClockinMac scheme.** The only checked-in shared scheme is
   `Clockin.xcscheme`. Ensure a `ClockinMac` scheme is available to CLI on a clean
   checkout, archives the Mac app with Release, and the app target uses
   `SKIP_INSTALL=NO` and its normal application install path. This brief forbids
   project edits, so no scheme was added. The Release settings otherwise match
   the brief; the script overrides ad-hoc signing. This phase needs no iOS or
   CloudKit provisioning changes.
2. Review the final Mac UI and draft notes, including the still-open room-editor
   and menu-bar checks in the plan. Confirm the licensing/source distribution
   decision with the old repository owner. The publisher requires the exact
   source commit to exist in `ismailakdag/clockin` before creating its version
   tag; it will not tag unrelated old code or push the new repo automatically.
3. Confirm the existing Developer ID identity, `ClockinNotary` profile, Sparkle
   Keychain item and destination GitHub permission on the release Mac. Setup
   existence is documented by the old pipeline, not verified in this run.
4. Commit the reviewed source/tooling/scheme/notes yourself, arrange the agreed
   destination source commit, then choose an unused, increasing build. Run:

   ```bash
   Tools/mac-release/build.sh 2.0.0 11
   Tools/mac-release/notarize.sh build/mac-release/2.0.0-11/export/Clockin.app
   Tools/mac-release/package.sh 2.0.0 11
   ```

   Replace 11 if the live feed has advanced. Inspect the actual archive/export,
   universal binaries, helper entitlements, Xcode export signing/repair path,
   app/DMG Accepted responses, tickets and Gatekeeper results. Confirm the
   resolved Sparkle tools generate the expected signed feed. Offline fixtures
   validate the verifier, not Sparkle's real tool invocation.
5. Back up the old installation/data/preferences privately. Mount the real DMG,
   inspect its layout and notices, install/copy and launch offline; test Apple
   Silicon and Intel. Rehearse old 1.1.6 → 2.0.0 Install and Relaunch in isolation,
   including data preservation, preference/range/sound migrations and level
   changes. See the procedure for public post-release checks.
6. After those checks, preview and explicitly publish:

   ```bash
   Tools/mac-release/publish.sh 2.0.0 --dry-run
   Tools/mac-release/publish.sh 2.0.0 --yes
   ```

   Do not run concurrent publishers. Reinspect anonymous public artifacts and
   the app inside the downloaded DMG, then verify a real old app updates through
   the unchanged feed and subsequently reports up to date. Failed drafts need
   manual inspection; failed stable swaps retain local backup bytes and report
   whether rollback succeeded.
