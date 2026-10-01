# Clockin 2.0.7

- Fixes a crash that could close Clockin right after launch while iCloud was updating your account information.
- Uses far less disk and battery: sync no longer rewrites its multi-megabyte state file on every check, only when something changed. The desktop widget also does much less work while a timer runs.
- More crash fixes for unusual data, such as duplicated entries, very large pasted totals and dates far in the past or future.
- Seeing two timers in the menu bar? When your iPhone's Live Activity is mirrored into the Mac menu bar, Clockin shows a small card once that opens the iPhone notification settings, where you can turn off "Allow Live Activities from iPhone". The same button is in Settings > Menu bar.
- Sheets opened from Settings (timecard import, rate schedule, backups, guide, privacy) now fit the window instead of growing taller than the screen.
- With iPhone Clockin 0.2 (52), a timer you start on the Mac reaches your iPhone sooner: the iPhone shows a notification "Clocked in on your Mac" and the timer as soon as you open it.
