## Design Review — Store unavailable
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker (Motion Reviewer: nothing moves)
**Total findings, before:** 2 (P0: 0, P1: 1, P2: 0, P3: 1)
**After this pass:** 2 open (P0: 0, P1: 1, P2: 0, P3: 1), the P1 in a file that is not mine

Captured 2026-10-02 on Strata-E, light and dark: `-strataFailStore both`.

---

### What's working (≥3)
- **The one screen where somebody is stuck says the one thing they fear first**: "Nothing has been deleted. Your wins are on this phone."
- **One action, the app's primary**: `PrimaryCapsule` "Try Again" at **14.0:1**, on the walkthrough's bottom line, title and body on the 16 margin (title **14.18:1**).
- **No blame and no em dash** in the copy (`docs/brand.md`).

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | H4 / H9 copy | UX | title "**Strata** could not open your wins", and "Close **Strata** from the app switcher" | The app is Sturdy: in the app switcher the card under the finger says Sturdy, so the recovery instruction names something the person cannot find. | S | **Reported, not mine**: `Strata/Services/SharedModelContainer.swift:352, 360, 363`. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Check 11 | Visual | 525pt between the copy and the pill | A stuck screen with one sentence and one button; the field is right here. | — | None. |

---
### Summary
A good failure screen: reassurance first, one action, nothing that blames. Its only defect is the app's old name in a recovery instruction, which lives in the store service rather than this view.
