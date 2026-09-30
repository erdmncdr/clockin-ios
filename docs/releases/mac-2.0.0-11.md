# Mac 2.0.0 (11): Clockin for Mac on the iPhone code base, with sync

Source: `erdmncdr/clockin-ios` main at `b5d9d5d`, target `ClockinMac`.
Published to the existing Sparkle feed in `ismailakdag/clockin`
(`macos-updates/appcast.xml`), versioned release `macos-v2.0.0`.

- Bundle `com.ismailakdag.clockin`, universal, macOS 14, Developer ID
  `LU36PKDPT3` with an Xcode-managed Developer ID profile; iCloud
  (Production) and push entitlements; widget extension sandboxed with the
  team-prefixed app group.
- App and DMG notarized and stapled; appcast signed with the existing Sparkle
  EdDSA key and verified with the shipped public key.
- Release notes: `docs/release-notes-mac-2.0.0.md`.

## Verification

```text
build.sh: archive and export succeeded; metadata, universal slices, Developer ID,
  timestamps, hardened runtime, Sparkle helpers and widget checks passed
notarize.sh: Accepted; staple validate OK; Gatekeeper: Notarized Developer ID
package.sh: DMG notarized; appcast generated and verified
publish.sh --yes: versioned DMG and SHA256SUMS public; Clockin.dmg and appcast
  swapped last and checked anonymously
Live appcast: 2.0.0 (11) -> macos-v2.0.0/Clockin-2.0.0-11.dmg (19,566,083 bytes)
```

Existing 1.1.6 users receive the update through Sparkle. Their data stays in
`~/Library/Application Support/Clockin`; first launch translates old
preferences once and does not replay old celebrations.

## Website

getclockin.netlify.app production deploy `6abcd212a1f80c626ec40ede`
(2026-09-30): only `/index.html` changed, from the site-hosted
`/downloads/Clockin-1.1.6-10.dmg` to the fixed
`macos-updates/Clockin.dmg` (now 2.0.0 (11)), matching
`clockin-main/website/dist/index.html`. The other 223 file hashes, including
`/_headers` and `/privacy/`, and the `admin`, `live-activity` and
`live-activity-tick` bundles, routes, rate limits and schedule were reused
from the previous production deploy. The draft preview was checked first;
production checks: 3 links to the fixed DMG, no 1.1.6 text, `/privacy/` 200,
relay health protocol 2 with `pushConfigured: true`. The old 1.1.6 DMG is
still hosted under `/downloads/` for existing links.
