## Design Review — Plan line sheet
**Maturity level:** L2 (`docs/design.md`; `GridConstants`, `Typography`, `AppColors` in code)
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 3 (P0: 1, P1: 0, P2: 1, P3: 1)
**After this pass:** 0 open

Captured on Strata-F, light and dark: `-strataSeedPlan 5 -strataOpenSheet planline` (medium detent, over the Plan sheet). The repeat days row needs Repeats on and no fixture reaches it; it was reviewed in code and by arithmetic.

---

### What's working (≥3)
- **Every row is a shared part**: `ColourSwatchRow`, `SettingsIcon`, `switchTrack`, `.sheetAction()`. Four private builds became none on 2026-10-01 and none have come back.
- **Delete is guarded and legible in both schemes**: "Delete Line" in `destructiveInk` at **5.60:1** light and **4.79:1** dark on its card, behind a dialog that says "It will not come back."
- **The day chips talk properly**: each is a 44pt button named with the full weekday, `.isSelected` when on, and on/off differs in fill, letter ink and hairline, not colour alone.
- The line's text is **12.87:1** on its card.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | Contrast 1.4.3 `[cross-dim]` systemic | A11y | `PlanItemDetailSheet` prompt | "What do you mean to do?" in `inkQuiet`, 3.35:1 on the light ground. | S | **FIXED**, `inkTertiary`. Part of the systemic fix in `add-a-win.md`. |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Reflow 1.4.10 | Visual, A11y | `PlanItemDetailSheet.days` | Seven fixed 44pt chips and six 4pt gutters are **332pt**; the Form row offers about **334** on this 402pt phone and about **307** on a 375pt SE, where the row ran ~25pt past its card. | S | **FIXED.** `frame(maxWidth: 44)` then `frame(height: 44)`: every chip is still 44 here and they share the width on a narrower phone. Arithmetic, not photographed (no fixture turns Repeats on, and the SE simulator is not this pass's). |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | DS ink | DS | `Text("Repeats")` | Unstyled, so `UIColor.label`: measured pure **(0, 0, 0)** light and **(255, 255, 255)** dark, the only pure ink on the sheet. | S | **FIXED**, `inkPrimary`: (34, 34, 34) 12.51:1 light, (238, 238, 238) 12.54:1 dark, measured after. |

### LOCKED items the review flagged, not changed
| Flag | Measured | Register |
|---|---|---|
| A selected day chip is a white letter on the line's category colour | white on the block palette is 1.71 to 2.70:1 | white-on-block-colour, LOCKED 2026-10-01. Recorded because this is a control rather than a block label, which the owner may want to look at once; not re-proposed. |

**Motion:** day chips change on `motionSnappy`; nothing else moves. No finding.

---
### Summary
A small sheet built entirely from shared parts. Its one sentence was in the glyph ink, its day row did not fit a small phone, and one word used the system's ink instead of the app's. All three are fixed.
