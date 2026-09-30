# iOS 0.2 (48): Serious overlaps only

Repository: `erdmncdr/clockin-ios`.
Source: main at `c267c56`. Everything from 0.2 (47) (`71e3ddd`: every timecard
import is the reference for its period).

- History and the entry editor warn only about serious overlaps
  (`SessionOverlap.conflicts`): never between two timecard entries (imported,
  or a timer entry the timecard corrected), since the timecard is the record
  of the work and writes rows across midnight or a month end that way; and not
  for overlaps of up to five minutes, unless they cover half of the shorter
  entry, so two copies of a short entry are still caught. `intersects` itself
  is unchanged.
- On the user's data after the full-period CSV import (646 entries) the five
  remaining overlapping pairs were all timecard pairs; none is flagged now.

## Verification

```text
Checks: overlap 38 (8 new), import 30
Builds: iOS Simulator and Mac Debug succeeded
Archive: 0.2 (48) Production, uploaded 2026-09-30 14:38
```

## What to Test

### English

History now warns only about serious overlaps. Entries that both come from your timecard are the record of your work and are not flagged, and overlaps of a few minutes are ignored. An entry you add by hand that overlaps a timecard entry is still flagged.

### Turkish

Geçmiş artık yalnızca ciddi çakışmalar için uyarıyor. İkisi de zaman kartından gelen kayıtlar işinin resmi kaydı olduğu için işaretlenmiyor, birkaç dakikalık binmeler de sayılmıyor. Zaman kartındaki bir kaydın üstüne elle eklediğin kayıt yine işaretlenir.
