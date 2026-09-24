# iOS 0.2 (26): Live Activity registration cleanup

Repository: `erdmncdr/clockin-ios`.
Source: main at `7d7a162321e83be98e9ab5ada4e6dc07149dc24b`, the commit 0.2 (25) missed.

- When an update ends a Live Activity, its push registration is retired too,
  so the server stops sending to an activity that no longer exists.

## Verification

All 30 required checks passed. The Release archive succeeded with 0 warnings
and 0 errors; the app and widget both read 0.2 (26), the signature satisfies
its Designated Requirement, and the 8 chime sounds are in the bundle.

## Release

Uploaded on 2026-09-23 at 00:12 Europe/Istanbul; processing completed.
Build ID: `fb24a687-72a1-46cd-9698-5229d66b6b91`.

Not distributed. The build was never added to a group and still reads
**Ready to Submit**. Its fix reached testers in 0.2 (28).
