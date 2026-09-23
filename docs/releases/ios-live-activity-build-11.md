# Clockin iOS 0.2 (11): optional time-only Live Activity updates

## Status, 20 September 2026

Protocol 2 and the completed bilingual policy are **live** at
https://getclockin.netlify.app/privacy/ . Production deploy:
`6aaf2fdca66ab66fd2ad1487` (production context, APNs configured, 60-second schedule).
All 223 pre-existing website file hashes were preserved. The user explicitly
approved clearing legacy server data and stopping protocol-1 clients at the
production migration step after automatic approval review requested that scope.

At 01:02:16 UTC, read-only storage verification found two stopped markers,
**zero legacy records and zero records containing financial/session fields**.
Raw tokens and financial values were not printed. The first check immediately
after deployment preceded the next scheduled cleanup; the subsequent check
confirmed the cleanup completed.

The user supplied the public identity/contact in owner.json. The policy renderer
was corrected after browser inspection found Markdown heading markers visible;
14 section headings now render correctly. The corrected preview and exact live
policy bytes were verified before distribution.

The signed **0.2 (11)** archive upload succeeded on 20 September 2026 at
04:01:54 Istanbul time; Apple completed processing it. English/Turkish test notes were saved and
beta review submission for both existing groups succeeded. Both **Clockin
Internal** (1 tester) and **Clockin Public Beta** (7 testers) independently show
**0.2 (11): Testing**, expiring in 90 days. Build ID: `bacbc659-4795-4d80-824b-0fa8fdac7b29`. App Store privacy responses are prepared with the
three categories below, and the policy URL is saved. The final Publish dialog
is awaiting the user's action-time confirmation of Apple's accuracy/compliance
attestation. No App Store production app release was submitted.

## Implementation

- Default-off, versioned opt-in with an explanation and policy link in Settings.
- Only per-activity routing token, APNs environment, protocol and expiry leave
  the app. The token travels in Authorization over HTTPS, not a URL.
- The relay sends only time. Local ActivityKit attributes retain pay, earnings,
  timer, currency, conversion, note and theme; widget resolves ticks locally.
- Strict server field allowlist rejects the old financial payload entirely.
- SHA-256 storage lookup; APNs needs the raw temporary token. Hashing is not
  encryption. No client contains the APNs key or a shared server password.
- Eight-hour maximum lifetime, token-free stop markers and durable local
  deletion retries, including cancellation during an in-flight registration.
- Scheduled v2 cleanup scrubs old financial records. Old builds must update
  and opt in; they cannot continue registering with the new protocol.

## Source and verification

Release snapshot: `/tmp/clockin-live-activity-release-0.2-11/source`.
Prepared with `scripts/prepare-ios-live-activity-release.py` from the
`clockin-companion-art` **working tree**, including approved uncommitted UI.
327 source files have a SHA-256 manifest and provenance JSON. Main is an old UI
baseline; do not archive main or companion-art HEAD alone. The same 3D exclusions
as builds 8/10 apply. Companion refresh, wardrobe and celebration hooks survive.

- 31 iOS check groups passed, including 13 new privacy checks.
- Ten relay tests passed, including deletion racing APNs validation and
  removing legacy financial state without transmitting it.
- Signed Release archive and Debug simulator build succeeded, no warnings or
  errors; app and widget both 0.2 (11). Strict recursive signature check passed.
- Simulator app installed and launched successfully (iPhone 17 Pro / iOS 26.5).
- CUA could not access Simulator, so Settings/consent visual interaction is
  **unverified**. Physical-device v2 tick rendering and Mac mirroring are also
  **unverified**. Passing builds and APNs acceptance do not prove delivery.

## Coordinated publication

1. User completes owner.json. Review the bilingual policy and the unresolved
   provider/transfer items in `docs/privacy/privacy-policy-draft.md`.
2. Render without placeholders:
   `python3 scripts/render-privacy-policy.py --output /tmp/clockin-privacy/index.html`.
   Missing owner details fail before creating a publishable file.
3. Function bundles are prepared at `/tmp/clockin-live-functions-v2`. Create a preview with
   `python3 scripts/deploy-live-activity.py --bundle /tmp/clockin-live-functions-v2 --privacy-page /tmp/clockin-privacy/index.html`.
   Only GET health/policy for verification: preview uses the production site's
   shared Blobs store. The script preserves every other published static hash.
4. Promote with the same arguments plus `--promote`. It refuses changed bundles,
   policy bytes or production base. Verify protocol 2 health, exact policy bytes,
   scheduled cleanup and no remaining legacy content (inspect keys, not values).
5. Complete Apple privacy disclosures from the actual deployed data flow using
   `docs/privacy/app-store-disclosure-draft.md`; verify /privacy/ works in-app.
6. Recheck highest TestFlight build before uploading the prepared archive. Add
   to the existing Internal/Public Beta groups and verify their final status.
   Do not expire older builds or publish an App Store production version.
7. On a real phone verify default-off behavior, enable consent, background for
   several ticks, pause/resume, rate/theme changes, offline withdrawal/retry and
   Mac mirroring. Notifications remain subject to Apple's delivery budget.

No legal compliance certification is implied by the policy, toggle or manifest.
