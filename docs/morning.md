# Morning, 2026-10-02

Every graded screen, light and dark, is in `docs/gallery.html` (open it in a
browser; each screen sits beside its dark twin with its grade). This page is
the short version: what changed overnight, the grades, and the eight calls
that are yours.

## Not done, first

- **The widget's "log a win from the widget"** is not built. The widget
  extension cannot see the app's SwiftData schema and the app has no URL
  scheme, so it is either a schema move into `Shared/` or an App Intent. The
  cost is written on `StrataWidget/StrataWidget.swift`. It needs its own pass.
- **StandBy** was not captured: the simulator has no StandBy mode. It needs
  a phone on a charger, landscape, locked.
- **Three things only a phone can check**: VoiceOver order on the empty
  tower, a Deep block from the camera under the keyboard, and the long-press
  menu on a photograph.

## What changed overnight

- Every Memories-side screen had a full design review (`docs/design-review/`,
  one file a screen). Fixes shipped with tests; what was left is listed in
  each file under "After this pass".
- Wins second pass: the empty sentence now hangs off the slot (534pt away,
  now 17pt). Add-a-win failures say so instead of closing silently.
- The app says **Sturdy** everywhere a person reads it: backup names, error
  copy, the could-not-open screen, accessibility labels.
- VoiceOver: a photograph says its day ("Photo, 21 September", was "Photo"
  thirty times); a map block says its place once known; the month no longer
  makes you swipe through every day still to come.
- A block on a past day with no photograph no longer bounces and opens
  nothing.
- The head picker was photographed with three heads for the first time, and
  the restore sheet's three later stages (restoring, done, failed).
- Pinterest added to the reference board (`docs/reference-board.md` §11): the
  strongest finding is a drink-log calendar that is the same idea as your
  Memories month, done with big numerals in empty wells.
- Housekeeping: the Mac was down to 8.8 GB free and macOS was evicting the
  Strata repo to iCloud (299 files in `.git` alone), which is what made
  builds and searches stall. I deleted about 15 GB of my own build caches
  from `/tmp`; it is at 23 GB free now. **The repo lives on an iCloud-synced
  Desktop**, so this will happen again whenever the disk fills.

## Your calls, each rendered both ways

| # | Question | Look at |
|---|---|---|
| 1 | The edit sheet's Delete pill measures 3.96:1 in dark (needs 4.5). Keep the native pill, or switch to the kit's red word (5.73:1)? | `docs/design-review/block-card-delete-paths.png` |
| 2 | Block titles in a replay at rest are about 7.5pt. Keep them as texture, or fade them out once the week is built? | `docs/design-review/replay-titles-paths.png` |
| 3 | Calendar day numerals are 7.9pt, under the 15pt floor. Exempt them, or raise to 15? (The Pinterest drink calendar argues for bigger numerals in empty wells that leave when the day fills.) | `docs/design-review/memories-numeral-15.png` |
| 4 | Album titles truncate at 108pt ("Read a cha…"). Wrap to two lines, or keep truncating? | `docs/design-review/memories-album-options.png` |
| 5 | Onboarding page 4 still shows the map as the Memories screen, which it no longer is. Redraw the figure? | gallery, `23-onboarding-4` |
| 6 | A past day shows four rows of empty lattice above two blocks. Size it to the tower plus one row? | gallery, `12-day-album` |
| 7 | The head maker's capture is dark and its preview switches to the light page. Keep, or keep it dark through the preview? | gallery, `18-head-maker` |
| 8 | Profile's Done is the same ink as its title. Fine, or make Done the one tinted word? | gallery, `14-profile-empty` |

## Grades

Graded on this morning's captures, light and dark, against the twelve checks
in `docs/screen-audit.md`. **10 means every check passes or fails against a
written exemption.** A 9 has one open item, and the item is named. Where that
item is one of your eight calls, it goes to 10 the day you answer it, either
way.

| Screen | Grade | What keeps it from 10 |
|---|---|---|
| Wins, empty / one / forty | **10** | |
| Add a win | **9** | A Deep block opened from the camera still sits partly under the keyboard; no spacing fits a 370pt well above a keyboard. Phone check. |
| Block card (edit) | **9** | Call 1, the dark Delete pill at 3.96:1 |
| Plan, empty / lines | **10** | Empty plan was mis-captured overnight (the last run's lines persisted); seed fixed, re-shot |
| Memories, the month | **9** | Calls 3 and 4, numerals and album titles |
| Memories, empty / one | **9** | Call 3, the same numerals at their most visible |
| Map | **10** | |
| Day album | **9** | Call 6, the empty lattice above a past day |
| Place collection | **9** | "9 here" as the title until the place name arrives (your copy) |
| Photo viewer | **10** | |
| Profile | **9** | A Day/Week/Month control over a chart with no data yet |
| Settings | **10** | |
| Restore, all four stages | **10** | First capture of restoring/done/failed found a doubled exit and a format number in the copy; both fixed |
| Head maker | **9** | Call 7, dark capture into a light preview |
| Head picker | **10** | First capture with several heads |
| Replay | **9** | Call 2, titles at rest |
| Onboarding | **8** | Call 5 (page 4 draws the old Memories), and page 3's camera picture still has tab labels; needs a real device shot |
| Store unavailable | **10** | |
| Camera, viewfinder / refused / review | **10** | |

Nine of nineteen at 10. Seven of the nine 9s are waiting on one answer each
from you.
