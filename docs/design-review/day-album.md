## Design Review — Day album (a past day / today)
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector (with the Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 5 (P0: 0, P1: 0, P2: 2, P3: 3)
**After this pass:** 5 open (P0: 0, P1: 0, P2: 2, P3: 3)

Captured 2026-10-02 on Strata-E, light and dark: `-strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1 -strataOpenDay 1` (yesterday, five wins with photographs) and `-strataOpenDay 0` (today, two wins, none photographed: the fixture leaves today bare on purpose).

---

### What's working (≥3)
- **The day is the app's own tower**, drawn by `StaticTowerView` on a second `TowerViewModel`, so a past day cannot drift from the Wins tab. Blocks keep the size the finger chose; photographs sit inside them on the block's own crop.
- **The count reads.** "5 wins" `CountReadout` in `inkTertiary`: **4.70:1** (rgb 110 on 246), exactly where `docs/screen-audit.md` left it.
- **It opens out of its own calendar cell** (`navigationTransition(.zoom)`), which is what makes the month and the day one place.
- **Imagery:** the photographs are the person's, at block size, with the block's title in the frosted band rather than over the picture's middle: text over imagery has the band as its scrim, which is the art-direction checklist's "consistent contrast" item answered structurally.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | H1 visibility | UX | `onTapBlock`, a block with no photograph | Pressing an unphotographed block plays the press and the haptic and then nothing opens. The block answered and did nothing, which reads as a fault. | M | Not changed: the press is `FlippableBlockView`'s (not mine). Either drop the press for a block with nothing behind it, or open the block card read-only. |
| 2 | White space that has to do something (LOCKED rule) | Visual | today, two wins | Two blocks under four rows of empty lattice: about 450pt of panes above the day. On the Wins tab that room is where the next win lands; on a past day nothing will land, so the room does no work. | M | Not changed: the lattice and its height are `StaticTowerView`'s and the Wins tab's shape. Option: size a past day's lattice to its tower plus one row. Owner's eye. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | Spacing ladder | DS | `header`, `VStack(spacing: 2)` | 2pt between the title and its count is off the 8/12/16 ladder. It is optical (a title's descender box), and the same 2 is in `PhotoCollectionView`'s header, so it is one decision in two places. | S | Not changed; name it as a token if it stays. |
| 4 | Localisation | UX | `title`, `dateFormat = "EEEE d MMMM"` | A fixed pattern, so a US reader gets "Thursday 1 October" rather than "Thursday, October 1". | S | Not changed. `setLocalizedDateFormatFromTemplate("EEEEdMMMM")`. |
| 5 | LOCKED white labels | — | "Read a c…", "Cooked…" | Block titles truncate at 13pt in a 1x1; the declared `BlockContent` exemption. | — | None. |

### LOCKED and settled items the review would flag, not changed
| Flag | Register |
|---|---|
| White titles on block colour (1.71 to 2.70:1) | owner, 2026-10-01 |
| Lattice at 1.03:1 under the day | refused twice; texture by declaration |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Zoom from the calendar cell | continuity | system | system | none | — | — |
| b | Block press | feedback | `FlippableBlockView` | token | #1 | P2 | — |

**Motion a11y:** Yes (system transition; blocks gate their own). **Overall:** Purposeful.

---
### Summary
A clean, honest screen: the real tower, a count that reads, a transition that says where you came from. Nothing on it fails a floor. The two open items are behaviour and composition (a block that answers a press with nothing, and a past day carrying the Wins tab's room to grow) and both live in components that are not this file's.

**Morning pass, 2026-10-02:** #1 FIXED: `StaticTowerView.canTapBlock`; a block with no photograph gets no `onTap`, and `FlippableBlockView` stops answering the tap (`including: .subviews`), so it neither squashes nor ticks. #2 is in `docs/morning.md` as the owner's call 6.
