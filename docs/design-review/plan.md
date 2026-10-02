## Design Review — Plan (empty / one line / five lines)
**Maturity level:** L2 (`docs/design.md`; `GridConstants`, `Typography`, `AppColors` in code)
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 5 (P0: 1, P1: 0, P2: 1, P3: 3)
**After this pass:** 4 open (P0: 0, P1: 0, P2: 1, P3: 3)

Captured on Strata-F, light and dark: `-strataResetStore 1 -strataOpenSheet plan`, `-strataSeedPlan 1`, `-strataSeedPlan 5`.

---

### What's working (≥3)
- **The invitation is row one, exactly where the first line lands** (LOCKED 2026-10-02): the ghost bullet **3.31:1** reads `PlanBullet`'s own two numbers, the sentence **6.05:1**, and a written line **14.31:1**.
- **Structure is counted, not decorated**: n lines get n-1 hairlines at `1 / displayScale`; the one 451pt tail under five lines is the tap-to-write space (LOCKED), and the whole of it answers a tap and is a labelled button for VoiceOver.
- **Every target is 44**: the bullet's box, the info button, the + ("Add a line"). The info button appears only on the line you are on, the way Reminders does it, so six identical glyphs never stack down the right.
- **Bullets speak**: "Log Run the loop as a win", or "…, done".

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | Contrast 1.4.3 `[cross-dim]` systemic | A11y, DS | `PlanSheet.row` repeat summary; `PlanTextField` done line | The repeat summary ("Every weekday") and a done line's text were both `inkQuiet`: **3.35:1** on this ground (same ink, same rgb(247) page, measured on the add sheet). | S | **FIXED.** Both `inkTertiary`, 4.69:1. A done line stays a third of an open line's 14.3 so "done" still reads at a glance. Part of the systemic fix in `add-a-win.md`. |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Missing state (governance) | DS | `DebugHarness` `-strataSeedPlan` | No fixture can reach a repeating line or a done line: the seed writes five plain lines. So #1 was fixed by arithmetic and **neither state has ever been photographed**. | S | Report to the `DebugHarness` owner: seed lines 2 and 4 with `repeatDays` and mark line 3 done. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | DS literal | DS | `PlanSheet.row` | `.alignmentGuide(.firstTextBaseline) { $0[.bottom] - 27 }`: a literal that ties the bullet to a 17pt line's baseline and moves with nothing. | S | Report: derive from the bullet's side and the body line's metrics. |
| 4 | DS token | DS | `PlanBullet` tick | `.font(.system(size: side * 0.52))` where the kit says `.iconSize(_:relativeTo:)`. Sized to the bullet on purpose, so it is a family exemption like the block numeral, and is unwritten. | S | Report: write the exemption at the site or route it through `iconSize`. |
| 5 | Vocabulary | Visual | ghost bullet | One of only two dashed strokes left in the app (with `ReplayLoadingSlot`) after the audit deleted the others for being "a dash this app does not have". It is the bullet the owner asked to see, so it is recorded, not reopened. | — | None. |

**Motion:** a new line arrives on `motionSmooth`, the info button fades on `motionSnappy`; both short, both answer a tap. Under Reduce Motion they are opacity and a short reflow. No finding.

---
### Summary
Plan is quiet and correct in every state the fixture can reach. The defect was in the two states it cannot: a repeating line's summary and a done line were in the glyph ink. Both are fixed; the fixture gap that hid them is the open item.
