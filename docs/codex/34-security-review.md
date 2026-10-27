# 34: Security review of three areas not covered by the timer-start audit

Review only; change nothing. Write findings to
`docs/codex/34-security-review-result.md`.

Context: brief 33 audited every way the timer can be started (intents, Control
Center, Mac hot keys, `clockin://` URLs, the Pulse native-messaging host,
iCloud sync) and the Netlify Live Activity relay. Three areas were left out.
Review them as an attacker would, then as a privacy reviewer.

## 1. The Pulse Chrome extension (`ClockinMac/ChromeExtension/`)

`manifest.json`, `background.js`, `watch.js`, `picker.js`, `popup.js`,
`popup.html`. Pair it with `ClockinMac/ChromeNativeHost.swift` and
`ClockinMac/ExternalClockCommand.swift` (receiver side). Questions:

- What can a web page do to the extension? Can page content reach
  `chrome.runtime.sendMessage`, spoof the watcher's messages, or make the
  extension send clock-in/clock-out without a user click? Check the content
  script's message plumbing, `externally_connectable`, host permissions, and
  whether `watch.js`/`picker.js` trust DOM data (selectors, text) in a way that
  lets a page trigger or suppress commands.
- What does the extension send to the native host, and is anything from the
  page (URLs, titles, text) forwarded to the Mac app or persisted? Where?
- Native messaging: the host manifest's `allowed_origins`, how the host binary
  is located, and whether another process could impersonate the host or the
  extension. Confirm the one-time pass file (`ExternalClockPass`, 0600, in the
  App Group container) cannot be read or pre-planted by another user process.
- Least privilege: permissions in `manifest.json` that are not needed.

## 2. The static website (`website/`, served from `website/dist`)

`website/dist/index.html`, `app.js`, `companion.js`, `preferences.js`,
`locale.js`, `gallery.js`, `journey.js`, `sprite.js`, `netlify.toml`, and
`website/tools/deploy`. Do not review `services/live-activity` (already done).
Questions:

- Any inline script that builds HTML from URL parameters, `location.hash`,
  `localStorage`, or fetched JSON without escaping (DOM XSS)?
- What `companion.js` and `preferences.js` store or fetch: any endpoint that
  takes user data, any token or identifier in the URL, any third-party
  script or font loaded from a CDN without integrity.
- `netlify.toml`: headers (CSP, X-Frame-Options, Referrer-Policy, HSTS),
  redirects that could be abused as open redirects, functions exposed by path.
- `tools/deploy`: how the Netlify token is read (must come from the keychain
  only; it must never be printed or written to disk), what the draft check
  verifies, and whether the deploy could overwrite the relay functions.
- The download links for the Mac app (zip/dmg, appcast): are they https, and
  is the Sparkle feed referenced correctly? Do not touch keys.

## 3. Local data at rest (both apps)

Find where the apps persist data: `AppGroup.directory` and everything written
under it (sessions, entries, `pulse-pass`, caches), `UserDefaults` suites
(standard and App Group), any Keychain use, the SwiftData/JSON stores, exports
(`Shared/Export` or wherever CSV/JSON export lives), the share images written
for the level-up card, and iOS file protection. Questions:

- Is anything secret or sensitive (sync tokens, the relay bearer token,
  CloudKit identifiers, the hourly rate and earnings) stored in plain
  `UserDefaults` or an unprotected file? Which `NSFileProtection` class do the
  files get on iOS (default is complete-until-first-unlock; note any file that
  needs stronger or that the widget needs weaker)?
- The relay bearer token: where it is generated, stored, rotated, and whether
  it ever appears in logs (`Logger`, `print`, `os_log`) or in exports.
- Logging: grep for `print(`, `os_log`, `Logger(` and list any line that logs
  earnings, rates, notes, or identifiers.
- Exports and shares: what the CSV/JSON export and the level-up share image
  include; whether a temporary file is left in a world-readable place on the
  Mac (`/tmp`, `NSTemporaryDirectory()`), and whether it is removed.
- Backup: which stores are excluded from iCloud/iTunes backup and whether that
  matches their sensitivity.
- iOS `Info.plist` / entitlements: any entitlement or usage description that
  is broader than what the code uses.

## Output

For each area: findings ranked High / Medium / Low / Note, each with file and
line, the attack or exposure in one or two sentences, and the smallest fix.
Then a short list "Checked and fine" so the owner knows what was covered. Be
concrete; no generic hardening advice without a line to point at. Do not edit
any file other than the result. No Codex/Claude names in the result's
suggested commit messages.
