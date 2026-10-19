# Mac 2.0.20 (31): native messaging, hidden menu bar recovery

Source: `erdmncdr/clockin-ios` main at `4481220`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.20.md`.

- Extension -> Clockin via native messaging (`ChromeNativeHost`, host `com.erdmncdr.clockin`, extension
  ID `iaikoicampaamoakicipdacniaaonkpc` fixed by the manifest key). The host opens `clockin://` with this
  exact bundle and confirms from the saved data. Debug host run: out/out/in confirmed on Debug data.
  Chrome check native run (throwaway profile host manifest -> Debug binary): in and out confirmed,
  page toast shown. Release binary answers host mode (`noop` -> unknown action) without a UI.
- Only `isTrusted` clicks count; label fallback only when the picked selector matches nothing.
- Status item `autosaveName = ClockinStatusItem`, `isVisible = true`; Reset position / Menu Bar settings
  / Copy details on the hidden card and in Settings. A Debug item with the new name showed in the bar.
- Found while testing: a Debug launch overwrote the shared extension folder and the Chrome host
  manifest; both were restored and Debug now uses `Clockin Debug/Chrome Extension` and writes host
  manifests only with `--native-host`.

Verification: README 54/54; publish.sh --yes; live appcast 2.0.20 (31); zip = release.
Not verified: the friend's Mac (menu bar) and the real work site.
