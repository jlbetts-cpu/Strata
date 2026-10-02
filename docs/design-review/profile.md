## Design Review — Profile (empty / with data)
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 6 (P0: 2, P1: 0, P2: 1, P3: 3)
**After this pass:** 4 open (P0: 0, P1: 0, P2: 1, P3: 3)

Captured 2026-10-02 on Strata-E, light and dark: empty `-strataStartTab tower -strataSeedWins 0 -strataOpenSheet profile`; with data `-strataSeedHistory 6 -strataOpenSheet profile`. The head section is reviewed in `head-picker.md`.

---

### What's working (≥3)
- **The chart speaks.** `accessibilityChartDescriptor(PeriodWinsDescriptor…)` gives VoiceOver an audio graph and a summary, and the streak figures are one combined element each ("Current streak, 3 days"). This is the best accessibility work in the app; anything else that draws a chart should copy it.
- **Two weights, three sizes, held.** Tally numerals at the 34 rung in the owner's digits, the unit and label at 17/15 Medium, section labels `FormSectionLabel`. The empty chart is a sentence, not an empty axis.
- **Selection is a ring on the chosen shape's own edge** (`inkPrimary` 0.55, `strokeMedium`), with `.isSelected` on the swatch: the GUIDED selection rule, honoured.
- **Done is ink in the bar**, set on the toolbar where it reaches, and the picture control is a `Menu` labelled "Change profile picture".

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | WCAG 1.4.3 + LOCKED floor, systemic | A11y, DS | streak footer "Log a win to start one.", head footer | The same grouped-Form footer as Settings: **13pt, 3.34:1** (rgb 133 on 244). | S | **FIXED** by the shared `.formFooter()` (see `settings.md` #1). After: **15pt, 4.64:1** (rgb 109 on 244); dark 6.08 before, unchanged in kind. |
| 2 | WCAG 1.4.3 | A11y | "Your name" placeholder | `inkQuiet`, **3.32:1** (rgb 135 on 246). It is the field's only visible label. | S | **FIXED.** `inkTertiary`, still well short of the typed name's ink, so empty still reads as empty. After: **4.67:1** (rgb 110 on 246). |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | Visual hierarchy | Visual | empty state, chart section | "Your weeks will show up here." sits in a card under a three-way segmented control that has nothing to switch between yet. Three choices over no data is a control with no effect (H8). | S | Not changed: hiding the control until there is data moves the card when the first win lands (check 10's "animates because it appeared"). Recorded. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 4 | Scroll edge | Visual | chart scrolled under the sheet title | A tall bar shows through iOS 26's soft edge under "Done" for a frame. System behaviour. | — | None. |
| 5 | 1.4.11 | A11y | switches off | Same as Settings #4: the platform's own pale off track. | — | None. |
| 6 | Copy | UX | "0 days / Current" at zero | A zero streak drawn at the 34 rung is the loudest thing on an empty profile. The footer already says how to start one. | — | None; the owner's tally. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Swatch row in/out | feedback | `motionSnappy`, auto-hide 650ms after a pick | token | the auto-hide timer is a hand-tuned 650ms, not a ladder rung | P3 (folded into #6's tier, not counted) | — |
| b | Chart unit change | continuity | `motionSmooth` | token | none | — | — |
| c | Streak digits | feedback | `.numericText()` | system | none | — | — |

**Motion a11y:** Partially: no `reduceMotion` read in `ProfileView`; every animation here is a short token, and SwiftUI's own transitions honour the setting. **Overall:** Purposeful.

---
### Summary
Profile's structure and its chart are among the best work in the app. Its two failures were both text set below the line the owner drew: Form footers at 13pt and 3.34:1 and a placeholder at 3.32:1. Both are fixed, the footers by one shared modifier that Settings now uses too.
