# iOS 0.2 (55): security review fixes

Repository: `erdmncdr/clockin-ios`. Source: main at `eb01c71`. Everything from 0.2 (54).

- Export backup builds the JSON in memory (`ClockStore.exportBackup() -> Data?`); no
  temporary file in the app's tmp directory.
- `CloudKitAdapter` encode-failure log keeps the record key private.
- Review and the Mac-side fixes: `docs/codex/34-security-review*.md`,
  `docs/releases/mac-2.0.27-38.md`.
- Archive `build/ios-release/Clockin-0.2-55.xcarchive`, team LU36PKDPT3.
- Uploaded 2026-10-28 02:09 (+03); processed within the hour. Build id
  `e9f4a7ca-699c-4222-b038-dadaed7fc228`. What to Test in English and Turkish; added to
  Clockin Internal and Clockin Public Beta; beta review submitted (WAITING_FOR_REVIEW);
  internal and external state IN_BETA_TESTING; tester notification on.

Verification: iOS Debug build (simulator SDK); import suite compiling ClockStore (102);
second read-only review pass over the diff. The export path was not exercised in a
running app (CoreSimulator on the build Mac is out of date).
