## Design Review — Restore from a backup
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 4 (P0: 0, P1: 1, P2: 1, P3: 2)
**After this pass:** 3 open (P0: 0, P1: 0, P2: 1, P3: 2)

Captured 2026-10-02 on Strata-E, light and dark: `-strataSeedBackup 40 -strataRestoreFrom strata-debug-backup.zip -strataOpenSheet settings` (the ready state). The restoring, done and failed stages were reviewed from source; `-strataRestoreStage` was asked for in the last pass and does not exist.

---

### What's working (≥3)
- **The decision is a fact sheet**: 40 at the tally rung, "wins in this backup", six facts on hairlines (`1 / displayScale`), then one sentence saying what will happen ("40 wins will be added.") and one `PrimaryCapsule` saying it again as the verb. Recognition over recall: nothing has to be remembered from Settings.
- **Every label clears its floor**: Cancel **6.02:1**, fact labels **6.09:1**, the tally and values ink.
- **Failure copy ends in what did not happen**: "Nothing has been changed." on every failure path, which is the fear a restore carries.
- **Notes are ink, not red**: colour means a win; none of these is a destruction (the file's own rule, held).

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | H4 copy | UX | "Made by Strata", two failure messages | The app is Sturdy (`settings.md` #3). | S | **FIXED.** Sturdy. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | H2 / H1 | UX | "Made by Sturdy · debug" | In a DEBUG build the version reads "debug", so the row says "Made by Sturdy debug". Release shows the version. | — | None in Release. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | Coverage | — | stages restoring / done / failed | Never photographed. `-strataRestoreStage ready|restoring|done|failed` (DebugHarness, not mine) is still the ask. | M | Report. |
| 4 | Check 11c | Visual | 202.7pt between the plan and the button | The button sits on the walkthrough's bottom line by design; the gap is the field, not dead space. | — | None. |

### Motion review
Stage changes swap content; no decorative motion. **Overall:** Purposeful.

---
### Summary
Restore does what a screen in front of a data operation should: it states the facts, says what will happen in one sentence, and offers one verb. The only defect was the app's old name, fixed.

**Morning pass, 2026-10-02:** #3 FIXED: `-strataRestoreStage restoring|done|failed` holds the sheet on each stage; all three are in the morning capture (`17-restore-<stage>`).
