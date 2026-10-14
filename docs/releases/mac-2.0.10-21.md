# Mac 2.0.10 (21): updates from erdmncdr/clockin-macos

Source: `erdmncdr/clockin-ios` main at `d2b9aee`, target `ClockinMac`.
Published to the new public `erdmncdr/clockin-macos` (`macos-updates/appcast.xml`,
fixed `macos-updates/Clockin.dmg`), versioned release `macos-v2.0.10`.
Notes: `docs/release-notes-mac-2.0.10.md`.

`ismailakdag/clockin` went private (GitHub shows it updated 2026-10-11), so the
website download and the Sparkle feed of every installed copy returned 404. The
only app change is `SUFeedURL`; the bundle identifier, team and Sparkle key are
unchanged. 2.0.9 (20) was copied into the new repository first as
`macos-v2.0.9` and the seed for `macos-updates`, so the publisher had a live
feed to compare build numbers with.

## Verification

```text
test-publish.py 13 OK; test-release-verification.sh --self-test PASS
website/tools/verify.py PASS; site deployed, download buttons -> new repo (200)
build.sh / notarize.sh (accepted) / package.sh passed; exported SUFeedURL is the new feed
publish.sh --yes: live appcast 2.0.10 (21); anonymous Clockin.dmg = release DMG
  (sha256 87adf838...), spctl accepted (Notarized Developer ID), stapler valid
```

Copies on 2.0.9 or earlier cannot see this update: their feed is the private
repository. They need one manual install from the website.
