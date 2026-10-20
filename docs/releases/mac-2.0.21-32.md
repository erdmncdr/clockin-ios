# Mac 2.0.21 (32): extension button matching, small picker bar

Source: `erdmncdr/clockin-ios` main at `6153b6a`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.21.md`. Extension manifest 1.2; same extension ID.

- watch.js scores each clicked element against both picks: selector 3, id 5, test id 5, tag 1,
  aria 2, half the classes 2, label +3 / -3 (digits and punctuation ignored). A press counts at 5
  (4 for picks saved by 2.0.20, which have no id/classes); a tie counts as neither. Toggle sites:
  label ignored in the score, it only decides in or out. Also decided at pointerdown, for sites that
  replace the button before the click lands.
- Cause of "Clock out does not count": with 2.0.20 a site whose buttons moved put the Clock in
  selector on another button. New check `shift.html` (a notice button in front of both): 2.0.20's
  watcher sent clock-out for Clock in and missed Clock out; 2.0.21 passes.
- Presses labelled like a pick that do not count are stored as `lastMiss` and shown in the popup.
- Picker bar: bottom corner, 12 px, max 300 px; hops corners when a hovered button is under it.

Verification: Chrome checks 97 ok, twice (logic toggle/two/reload/div/shift, link, native against a
fresh Debug build: in and out confirmed). Swift unchanged, so the Swift suites were not rerun.
publish.sh --yes; live appcast 2.0.21 (32); website zip = release zip (18353189 bytes).
Not verified: the friends' real work site.
