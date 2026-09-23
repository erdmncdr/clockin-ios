# Clockin iOS TestFlight, 16 September 2026

- Uploaded version: **0.1 (5)**. Archive was built with 4; Xcode's `manageAppVersionAndBuildNumber` increased it because Build 4 already existed.
- Bundle: `com.erdmncdr.clockin`; team `LU36PKDPT3`.
- Latest local feedback fixes included: chime stale settings refresh, notification sound, rate selection, overnight snapshot rate, precise overlap checking, multi-day editor preservation.
- Pre-upload verification: 557 checks passed; Debug simulator and Release device builds passed; interactive iOS 26.5 simulator checks documented in `ios-feedback-review-2026-09-16.md`.
- Signed archive: `/private/tmp/clockin-testflight-20260916/Clockin.xcarchive`; app/widget both had 0.1 (4) and privacy manifests before export. Strict deep codesign verification passed with system trust access.
- Upload: **EXPORT SUCCEEDED**, “Upload succeeded.” at 19:25:18 Europe/Istanbul.
- App Store Connect independently showed **0.1 (5), Processing, Sep 16 2026 7:25 PM**.
- Build 3 was already Testing in both Clockin Internal and Clockin Public Beta; no existing build was withdrawn or expired.
- Apple processing completed; Build 5 detail page is available. English What to Test notes saved.
- User explicitly approved both groups. Build 5 added to Clockin Internal and Clockin Public Beta. English and Turkish What to Test notes saved; Automatically notify testers remained enabled. Submit for Review completed.
- Final live verification: Build 5 **Testing** on iOS Builds and independently **Testing** in Clockin Public Beta > Builds. Both groups are assigned; no review wait remains in the observed status. Public link: https://testflight.apple.com/join/tr6kSDMN .
- Temporary logs: `/private/tmp/clockin-testflight-20260916/archive.log`, `upload.log`.
- Source SHA-256 manifest and export settings: local `dist/ios-testflight-20260916/`. No credentials exported.
