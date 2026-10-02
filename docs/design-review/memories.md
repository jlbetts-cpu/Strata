## Design Review — Memories (no wins / one win / this month / half full / full / scrolled)
**Maturity level:** L2. `docs/design.md` is the DESIGN.md; the system is in code (`GridConstants`, `Typography`, `AppColors`); the atomic-kit table is the compliance checklist.
**Sub-agents run:** Visual Quality Inspector (with `art-direction.md`'s Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 9 (P0: 1, P1: 2, P2: 3, P3: 3)
**After this pass:** 7 open (P0: 0, P1: 1, P2: 3, P3: 3), and the open P1 and the first P2 are the owner's calls

Captured 2026-10-02 on Strata-E (iPhone, 402x874 @3x), light and dark, through `tools/settle-shot.py` (which refuses a springboard):

| state | flags |
|---|---|
| no wins | `-strataStartTab memories -strataSeedWins 0` |
| one win | `-strataSeedWins 1` |
| this month (October, two days in) | `-strataSeedHistory 6 -strataSeedRealPhotos 1` |
| half full (September) | `-strataSeedHistory 16 -strataSeedRealPhotos 1 -strataOpenMonth 1` |
| full (September) | `-strataSeedHistory 34 -strataSeedRealPhotos 1 -strataOpenMonth 1` |
| scrolled to the shelf and the roll | `-strataSeedHistory 34 -strataSeedRealPhotos 1 -strataScrollMemories shelf` |

Text contrast below is the extreme ink pixel of a glyph against the median ground of the same crop. The full month never settles (the day slideshows turn every 5s, as designed) and its light frame is the last of sixty; the dark full month was not captured for that reason, and half full stands in for it.

---

### What's working (≥3)
- **The page has one accent and it is ink.** The replay row's play disc is `inkPrimary` at 17pt of glyph inside a 30pt disc, so on a page of thirty photographs the only saturated things are wins and pictures (check 5). Other screens should copy the derivation written at `ReplayRow.playDisc`.
- **Proximity carries the grouping, measured.** Month heading to its grid 16pt, grid to the next month's heading 68pt, calendar to the shelf `gapPage`: a 4.25x ratio between "belongs together" and "next thing", which is what Kubovy's ratio rule asks for. The shelf's break survived its heading being cut.
- **The counts read.** Album caption `inkTertiary` **4.67:1** off the tab bar, album title **14.1:1**, page title **14.9:1** dark. Every count on the page is the shared `CountReadout`.
- **Motion knows when nobody is looking.** Day slideshows hold still under a photograph, a replay or a pushed page (`memoriesDrawerVisible`) and stop under Reduce Motion (`MonthTowerView` 184). The month swap is a cross-fade because the month is replaced, not moved.
- **Imagery:** every photograph on this page is one of the person's own, cropped square by the same rule in three places (calendar, album card, roll), with no captions on pictures and no stock. Meaning (a day), content (what was done), context (its date cell) all hold. The fixture's photographs are generated noise and say nothing about grading; that was not judged.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | WCAG 1.4.3 `[cross-dim]` DS ink | A11y, DS | `MonthCalendarView` empty day numeral, `inkTertiary.opacity(0.75)` | A day's number is text. Light **2.91:1** (rgb 141 on a 240 well), dark **4.42:1** (rgb 134 on 33), on 31 cells of every month. It had been signed off at 3:1 as "a mark"; a numeral is text by WCAG. | S | **FIXED.** Full `inkTertiary`, the ink `CountReadout` reads at on this page. After: light **4.63:1** (rgb 107 on 239, empty month) and **4.61:1** (half month), dark **6.69:1** and **6.75:1** (rgb 167 on 33). |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | H1 visibility | UX, Visual | `ReplayRow.thumbnail` | **The replay row settled as a blank well**: the September row on the this-month state, light and dark, on 8 launches of 8 (std 1.1 levels across the thumbnail), while the same row at 30 days of history showed its tower (std 58). It was handed over as a race. **It was geometry, and deterministic**: the console said `cards drawn 1, empty renders 0`, so the poster existed; the thumbnail crops the poster's MIDDLE, and a poster stands its tower on its base line, so a short period's tower sat entirely below the band the thumbnail shows. | S | **FIXED.** Cropped from the bottom (`alignment: .bottom`), so the base sits the poster's own 7.7pt margin above the edge, like its sides. After: std **78** at 6 days and **58** at 30, 3 of 3 launches each (`memories-replay-thumb.png`: before, after at 6 days, after at 30). Two things done on the way that were NOT the cause, kept because each closes a real hole: the poster is read in the body's pass rather than inside the `ForEach` closure (CLAUDE.md's rule), and a nil render is retried twice in-pass instead of "left for the next reload", which this page never makes. Pinned by `DesignReviewMemoriesSideTests.thumbnailCropsFromTheBase`. |
| 3 | DS type floor (LOCKED rule) | DS, Visual | `MonthCalendarCell.numberSize = side * 0.16` | The day numerals are **7.9pt** (49.3pt cell, a 17px glyph), under "Nothing below 15pt, except three sites with a measurement". `docs/type-pass.md` lists three exempt sites and this is not one; it is mentioned only as the family the block title belongs to. | M | **Not changed: owner's call.** It changes how the calendar looks. Rendered at 15 for him (`-strataCalendarNumeral floor`, DEBUG): `docs/design-review/memories-numeral-15.png`. What it looks like at 15: the numbers become the first thing you read in each cell, white on the photographed days as much as grey on the empty ones, and the month starts to read as a calendar app's grid rather than a tower of days. The two paths: exempt it in the register as a fourth site, with this measurement, or raise it. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 4 | H6 recognition, truncation | UX, Visual | `AlbumCard` title at 108pt | "Read a chapter" draws **"Read a cha…"**. The card cannot widen (108 is what puts three and a bit on screen) and `minimumScaleFactor` would cross the 15pt floor. | S | **Not changed: owner's call, brand-visible.** Both other paths rendered (`-strataAlbumTitle wrap|small`, DEBUG), side by side in `memories-album-options.png`. **The 15 rung does not fix it**: "Read a chap…" still truncates, one letter later. Two lines does ("Read a / chapter"), at the cost of one card in the row being a line taller than its neighbours and its count dropping 21pt. Ships truncated until he picks; the honest choice is wrap or a shorter title. |
| 5 | VoiceOver focus order | A11y | `MonthCalendarCell` empty days | Every empty day is a stop: a VoiceOver user swipes through "3, to come", "4, to come"... up to 31 stops before the shelf. A sighted person skips the whole grid in one glance. | M | Not changed. Group the empty run into one element per week ("3 to 9, nothing yet"), or `.accessibilityHidden` the future days. |
| 6 | Dynamic Type 1.4.4 | A11y | `MonthCalendarCell.number`, `StrataFont.size(points)` | The numeral is sized off the cell, not relative to a text style, so it does not grow with the reader's text size at all. Same root as #3. | M | Not changed; it moves with #3. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 7 | Contrast at the tab bar | A11y | album caption at rest | Directly above the tab bar the caption measures **4.16:1**: iOS 26's scroll edge under the floating bar fades the last band of content. Scrolled clear it is 4.67. System behaviour. | — | None. |
| 8 | 4.1.2 name | A11y | `PhotoGalleryGrid` cell label `photo.title ?? "Photo"` | An untitled photograph is announced as "Photo", with no date, in a grid of many. | S | Not changed. "Photo, 21 September". |
| 9 | WCAG 2.2.2 pause | Motion | `DayPhotoSlideshow` 5s dwell | Auto-advancing for as long as the page is open, with no per-screen pause; Reduce Motion is the off switch. | — | None; Reduce Motion is the platform's answer. |

### LOCKED items the review flagged, not changed
| Flag | What the review would say | Measured | Register |
|---|---|---|---|
| The calendar's empty days are **wells** | Check 6 / greyscale is earned: 31 grey squares | well 1 level recess, +4 rim | owner, 2026-10-01: chosen from three renderings |
| The album card **keeps its count** | H8: "5 photos" is a caption under a title | 4.67:1, 15pt Medium | owner, 2026-10-01 |
| White numerals on photographed days | text on a photograph, contrast varies with the picture | not re-measured, per the register | the white-label decision covers the day block |
| `-strataResetStore` empty page fails 11c | 281pt tail under the month | — | written exemption in `MemoriesView.emptyState` |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Month swap | continuity | `crossFade` | ease | none: a replacement, not a move | — | — |
| b | Day slideshow | content (the day's pictures) | 5s dwell, per-day phase | crossfade, outgoing held under | #9 | P3 | — |
| c | Count roll | feedback | `.numericText()` | system | none | — | — |
| d | Press on day / row / card | feedback | `pressSurface` (`tapScaleY`) | spring token | none | — | — |

**Motion a11y:** prefers-reduced-motion addressed? **Yes.** **Overall motion quality:** Purposeful.

**Translated, not invented:** "keyboard navigation" is VoiceOver order and Full Keyboard Access: header (title, Map, Profile), month picker, replay row, calendar in reading order, shelf, roll. "Skip links" (2.4.1) has no iOS meaning on one scroll; #5 is the nearest real problem. "Page titled" (2.4.2) is the large "Memories" text.

---
### Summary
Memories is a well-composed page whose failures were in the instruments rather than the layout: thirty-one numerals at 2.91:1 that had been graded as marks, and a replay thumbnail that cropped the middle of a poster whose tower stands at the bottom, so every short period showed an empty well. That one was handed over as a race and was geometry; both are fixed. What is left is the owner's: the calendar numerals are 7.9pt under a floor he locked, and the album card's titles truncate; both were rendered the other way and neither shipped.
