# Clockin 2.0.1

- Fixes a crash that could happen while syncing, when changes arrived from your iPhone or after a brief network problem.
- If sync was tried with a development build, the first sync now asks to merge again instead of assuming the devices already match.
- Import timecards can use a file as the reference: every entry in the file's period that the file does not contain is removed after you confirm, so entries imported twice on different devices go away. Matching entries take the file's times.
