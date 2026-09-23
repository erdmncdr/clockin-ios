# Live Activity delivery investigation, 20 September 2026

The user confirmed 2–3 earnings updates without reopening Clockin, followed by
a stall. This is a delivery-cadence issue, not absence of background registration.

## Evidence

- Read-only production inspection found an active production record with over
  seven hours until expiry; it was not stopped and had its token.
- Historical scheduler logs continued on the minute, with some timing jitter.
- Added aggregate-only logs to the normal scheduled function. No extra manual
  push was sent; no tokens, notes, rates or earnings were logged.
- Live logs at 00:12 and 00:13 UTC showed `processed: 2, apnsAccepted: 2,
  failed: 0, remaining: 0`. APNs accepted every attempted update on both ticks.
- APNs acceptance proves server/API success, not device delivery or rendering.

## Hypothesis and bounded change

The original `apns-priority: 5` permits grouped, delayed delivery. This matches
intermittent background updates despite successful APNs responses. The root
cause on the physical device is not conclusively measured.

Change only delivery priority to `10` for the existing minute updates, requesting
prompt delivery. Keep payload calculation, expiry, collapse ID, scheduling,
storage, credentials and the app unchanged. Builds 9 and 10 already include
`NSSupportsLiveActivitiesFrequentUpdates = true`. This server correction does
not require another app build or recreating an active registered activity.

High-priority pushes count toward Apple's budget. The person can disable
frequent updates in Settings, and the client does not yet report that setting.
No fixed 60-second on-screen guarantee is made. If this does not resolve the
stall, inspect device authorization and ActivityKit delivery/render logs before
trying another policy change.

Sources:
- https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications
- https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns

## Validation

All eight existing relay checks passed. Function bundles were rebuilt and the
preview health passed; the deployment script preserved all 223 published static
file hashes. Production deploy `6aaf2579b0540a7cbc3c18d3` is live, with configured
health and the minute schedule. Both deployed function bundles contain the
priority-10 header. The new production function's live log at 00:16 UTC showed
`processed: 2, apnsAccepted: 2, failed: 0, remaining: 0` on its automatic tick.
End-to-end cadence after the priority change still requires a phone observation.
