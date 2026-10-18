# Mac 2.0.16 (27): pick Clock out after Clock in

Source: `erdmncdr/clockin-ios` main at `1e704be`. Published to `erdmncdr/clockin-macos`.
Notes: `docs/release-notes-mac-2.0.16.md`.

The tester could not pick Clock out: the picker blocked the start click, so the site never showed
it. Picking clicks now reach the site; `start-pick` registers the picker for the origin before the
first click and the first pick is written to storage at once, so a reload brings the picker back.

Verification: Tests/manual/chromeextension 39 checks (toggle, two buttons, reloading site);
README checks 53/53; publish.sh --yes; live appcast 2.0.16 (27); anonymous Clockin.zip = release.
Not verified: the real work site.
