# Clockin for Mac releases

The new app is the native `ClockinMac` target in `Clockin.xcodeproj`. Shipping
identity stays `com.ismailakdag.clockin`, Developer ID team `LU36PKDPT3`, macOS
14+, Apple Silicon and Intel. Installed 1.1.6 copies continue using
`https://github.com/ismailakdag/clockin/releases/download/macos-updates/appcast.xml`.
Never change that URL to `releases/latest` or replace the existing Sparkle key.

## Before the first 2.0 release

Review the licensing/source-distribution decision in `docs/mac-plan.md` with the
repository owner: the old app is MIT, this codebase is PolyForm Noncommercial.
The installer includes this repo's `LICENSE` and `NOTICE.md`, including the MIT
notice for the ported code. The release scripts neither push code nor alter
licenses. Review the draft `docs/release-notes-mac-2.0.0.md` against the final UI;
`PARITY.md` still describes several differences from before this port.

The publisher preserves the old guarantee that `macos-vVERSION` identifies the
actual build source. **The exact source commit must already exist in
`ismailakdag/clockin`.** This is a deliberate prerequisite when publishing from
a different source repository: pushing only to the new app's repository is not
enough. Agree on source distribution and arrange the destination commit before
building. The script refuses to silently tag unrelated old Mac code. It will
not mirror or push source on your behalf.

In Xcode, make sure a shared **ClockinMac** scheme exists, includes only the Mac
app for Archive, and uses Release for Archive. This checkout currently contains
only `Clockin.xcscheme` as a shared scheme; an automatically created local Mac
scheme may work, but a fresh checkout needs a shared one. Have the project owner
add/share it. Check `SKIP_INSTALL=NO` and an application install path (normally
`$(LOCAL_APPS_DIR)`) on the app target so the archive contains
`Products/Applications/Clockin.app`. Do not globally change dependency targets'
`SKIP_INSTALL`. No project or app-source changes are made by these tools.

Release already defines `PRODUCT_NAME=Clockin`, the production bundle identifier,
macOS 14.0, hardened runtime, no sandbox, and the Sparkle Info.plist. The archive
command overrides the project's ad-hoc identity and automatic signing with
Developer ID Application, team `LU36PKDPT3`, manual signing, timestamping,
`ARCHS="arm64 x86_64"`, `ONLY_ACTIVE_ARCH=NO`, and the requested version/build.
Keep Sparkle pinned to 2.10.0 in the resolved package file. This phase does not
add CloudKit entitlements or a provisioning profile; the sync phase will require
its own signing/profile work.

## Existing one-time setup

The old release documentation records this setup on the release Mac; it was
not accessed or revalidated while implementing this pipeline:

- Xcode with its license accepted and command-line developer directory selected.
- Developer ID Application certificate and private key for
  `erdem incedere (LU36PKDPT3)` in Keychain. The generic identity used by the tools
  must resolve to this team; verification rejects another team. Resolve ambiguous
  duplicate identities in the release environment before running.
- Notarytool Keychain profile **ClockinNotary**. On a new Mac, use
  `xcrun notarytool store-credentials ClockinNotary` interactively; follow its
  prompts for the account, team and app-specific password. Do not put credentials
  on a command line, in a log or in this repository.
- Sparkle Ed25519 private key in the existing Keychain item with account
  **com.ismailakdag.clockin**. Do not generate a replacement for a normal release.
  The shipped public key is `vsxEtDN88GYSuw5+GGeCk3eEvZxlDEalz1icmMBCvh8=`.
  Sparkle's tools read Keychain directly with `--account`; these scripts have no
  private-key-file/export option.
- Git's stored GitHub HTTPS credential, with release write access to
  `ismailakdag/clockin`. Python asks Git's credential helper in memory and sends
  the token only to GitHub API/upload hosts, never to anonymous downloads. No
  Netlify token or website deployment is needed.

Use Bash (including macOS's system Bash), Python 3 and the Swift compiler.
Do not run the release scripts with shell tracing (`bash -x` / `set -x`).

## Rehearse without external operations

From the repo root, all entry points accept `--dry-run`. These runs print the
commands/checks and do not invoke Xcode, signing, Keychain, Apple or GitHub. They
work before any build artifacts exist. Unlike the old script, dry-run does not
build an ad-hoc app or fetch the live feed.

```bash
Tools/mac-release/build.sh 2.0.0 11 --dry-run
Tools/mac-release/notarize.sh build/mac-release/2.0.0-11/export/Clockin.app --dry-run
Tools/mac-release/notarize.sh build/mac-release/releases/2.0.0-11/Clockin-2.0.0-11.dmg --dry-run
Tools/mac-release/package.sh 2.0.0 11 --dry-run
Tools/mac-release/publish.sh 2.0.0 --dry-run
Tools/mac-release/test-release-verification.sh --self-test
PYTHONDONTWRITEBYTECODE=1 python3 Tools/mac-release/test-publish.py
```

The self-test generates a throwaway Ed25519 key in memory and synthetic files in
`/tmp`, then removes the fixtures/compiler cache. It never touches the shipping
key. Other outputs are under ignored `build/mac-release/`.

## Prepare and publish

First review/commit the final source, project scheme and release notes, and make
that exact commit available in the destination repository as described above.
Choose a build higher than the live feed (11 follows the documented 1.1.6 build
10, but verify the live value before a real release). Never reuse a distributed
build number or change an already published versioned DMG.

```bash
Tools/mac-release/build.sh 2.0.0 11
Tools/mac-release/notarize.sh build/mac-release/2.0.0-11/export/Clockin.app
Tools/mac-release/package.sh 2.0.0 11
# Complete the installer/update rehearsal below before making the feed public.
Tools/mac-release/publish.sh 2.0.0 --dry-run
Tools/mac-release/publish.sh 2.0.0 --yes
```

`build.sh` archives and exports to `build/mac-release/2.0.0-11/`, with a dedicated
`DerivedData/SourcePackages/artifacts` directory. Package resolution uses the
checked-in lock file; missing pinned artifacts may be downloaded on the release
Mac. The checked-in `ExportOptions.plist` uses `method=developer-id`, export
rather than upload, manual signing and the same team. The exported app is the
only input for notarization and packaging. If export leaves Sparkle helpers
signed by another team or without timestamp/runtime, the script signs every
nested Mach-O and bundle inside-out, preserving entitlements, and finally
re-signs the app. It never uses `--deep` to sign. The original archive stays as
Xcode produced it; any repair applies to the exported distribution copy.

The post-export verifier checks app/Sparkle universal slices; app identifier,
version/build and minimum OS; pinned feed/public key, required feed signatures,
pre-extraction verification and zero signature expiry; deep/strict code-signing
validity; Developer ID authority, team, timestamp and hardened runtime on every
Sparkle code component and the app. It requires Updater, Autoupdate and both XPC
services, Sparkle 2.10.0, and rejects app sandbox/debugger entitlements on the
outer app while preserving Sparkle helper entitlements.

`notarize.sh` ZIPs an app with `ditto` (notarytool cannot submit a bare app), or
submits a DMG directly. It uses `ClockinNotary --wait`, saves the response under
`build/mac-release/notary/`, and requires **Accepted**, not just a successful
process exit. It staples and validates the original app/DMG and runs Gatekeeper
with the appropriate execute/open assessment. App stapling happens before DMG
creation, so the installed app retains its ticket offline.

`package.sh` requires the verified, stapled app, finds exactly one matching
`generate_appcast`/`sign_update` pair in this build's resolved artifacts, and
creates an HFS+ UDZO DMG with Clockin, an Applications shortcut and license
notices. It signs, notarizes and staples the DMG **before** Sparkle signs its
bytes. It generates one full update with embedded release notes and no deltas,
then checks the feed and archive against the exported app's public key and runs
tamper tests. The Swift verifier also binds the item to the app's version/build,
macOS 14.0 and exact versioned GitHub URL. Checksums/provenance and a `ready`
marker are placed in `build/mac-release/releases/2.0.0-11/` only after success.
Nothing in that directory may be edited after signing.

`publish.sh VERSION` requires exactly one ready directory for that version and
refuses without `--yes`. It rechecks signatures, tickets, Gatekeeper, checksums,
notes and source provenance. A dirty build can be used for local investigation,
but cannot be published: the build must record a clean checkout, and publishing
must run from that same clean commit. It then:

1. Checks destination access/source commit, saves the previous public stable
   feed and installer under `build/mac-release/publish-backup-*`, and rejects a
   build that does not increase (except an identical completed-release retry).
2. Creates the versioned release as a draft, uploads the DMG and SHA256SUMS, and
   publishes with `make_latest=false`. A pre-existing tag must match the source.
3. Downloads both version assets anonymously and compares their exact bytes.
4. Replaces the fixed `macos-updates/Clockin.dmg` used by the website, keeping
   `make_latest=false`, and verifies it anonymously.
5. Replaces the unchanged signed `appcast.xml` last; checks anonymous bytes and
   feed/archive signatures again. Existing users see the update at this point.

Stable assets upload under temporary names before the old asset is removed.
GitHub does not provide an atomic rename-over-existing API, so a short gap is
possible. A swap or validation failure attempts to restore the previous bytes
and verifies the rollback; a failed rollback is reported explicitly. A failed
feed step may leave the new fixed download available while the restored feed
still offers the previous immutable version. Release only from one machine/job
at a time; the publisher does not provide a cross-machine lock.

A matching public version can be retried without modifying its immutable assets.
An interrupted draft must be inspected and resolved manually; scripts do not
silently replace it. Old or mismatched public assets cause a stop. If packaging
fails, temporary staging is removed; retain notary JSON to investigate. If the
build directory already exists, use a fresh build number or deliberately move
an unpublished failed directory aside after reviewing it. Do not rerun
`notarize.sh` on a finalized signed DMG; stapling can change bytes.

## Required installer and update rehearsal

Back up the existing app, `~/Library/Application Support/Clockin/clockin.json`,
its `Backups/`, and preferences in `com.ismailakdag.clockin` before testing. Keep
these private backups outside any upload directory. A data reserialization may
change its hash; compare decoded sessions, rates, running state and preferences,
not only file bytes.

Mount the actual prepared DMG, check its app/Applications shortcut/licenses,
copy to Applications and test first launch with the network disconnected after
copying. Inspect the copied app with `verify-app.sh`, `stapler validate` and
Gatekeeper. Repeat startup/runtime checks on Intel as well as Apple Silicon;
checking two slices does not prove Intel execution.

Rehearse 1.1.6 → 2.0.0 discovery, download, Install and Relaunch, retained data,
preference/sound/range migration, changed levels, and subsequent “up to date”.
Use isolated test copies/accounts and a private signed test feed before changing
the public feed; keep shipping Info.plist/feed/key unchanged. After publishing,
repeat with an actual old installation against the public feed and inspect the
DMG downloaded anonymously, including the app inside it. Local checks alone do
not prove that installed Sparkle clients accept or install the release.

## What changed from the SPM pipeline

`swift build` plus hand-assembled bundles is replaced by a real Xcode archive and
Developer ID export. Versions are build-setting overrides, not edits to a
source plist. Sparkle tools come from the archive's DerivedData, not
`../clockin-main/.build`. There is no synthetic archive, Organizer upload/export
step, automatic commit/push, version bump or website deploy. Build, app
notarization, packaging (including DMG notarization), and explicitly authorized
publication are separate commands. The stable URLs, team, public key, signed
feed/archive checks and feed-last delivery order remain the same.
