# Mac 2.0.12 (23): installer window and zipped website download

Source: `erdmncdr/clockin-ios` main at `d63ac2c`, target `ClockinMac`.
Published to `erdmncdr/clockin-macos` (`macos-updates/appcast.xml`, fixed
`macos-updates/Clockin.dmg` and `macos-updates/Clockin.zip`), versioned release
`macos-v2.0.12`. Notes: `docs/release-notes-mac-2.0.12.md`.

No app changes since 2.0.11. The DMG is built with dmgbuild: Clockin, an arrow
and Applications on a drawn background, license files hidden. The release also
carries the zipped, stapled app, which the website links to.

The first publish attempt (from `f8ad839`) stopped in `local_release` before
any upload: the zip check used its path before assigning it. Fixed in
`d63ac2c`; the never-published build 23 was deleted and rebuilt from that commit.

## Verification

```text
test-publish.py 13 OK
DMG: .DS_Store + .background.tiff, LICENSE/NOTICE hidden, spctl accepted
ZIP: unpacked app stapled and accepted by spctl
publish.sh --yes: live appcast 2.0.12 (23); anonymous Clockin.zip and
  Clockin.dmg equal the release files; exported app removed afterwards
```
