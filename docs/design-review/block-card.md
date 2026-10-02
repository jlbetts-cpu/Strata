## Design Review — Block card (editing a win)
**Maturity level:** L2 (`docs/design.md`; `GridConstants`, `Typography`, `AppColors` in code)
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 4 (P0: 2, P1: 0, P2: 1, P3: 1)
**After this pass:** 1 open (P0: 1, owner's call, both paths rendered)

The block card is `AddWinSheet` in editing mode (`-strataSeedWins 8 -strataOpenSheet edit`), so the add sheet's fixes land here too and are counted once, in `add-a-win.md`, and listed below as `[cross-dim]`.

---

### What's working (≥3)
- **Deleting a win is guarded twice**: a confirmation that says what happens ("The block leaves the tower."), and a transaction that leaves the photographs on disk if the delete fails, so a failure can never orphan files.
- **The name is the strongest ink on the sheet** (`inkPrimary`, 14.31:1) and the colour row shows the win's real colour as selected with a ring on the swatch's own edge, the GUIDED selection rule.
- **The 196.7pt break** between the size control and the block is the declared floored-subject composition, and on this sheet it reads as the block standing on the page rather than as a gap.
- **The delete red inverts with the scheme**, pinned by `SlotAndDeleteInkTests`: the light label is **4.56:1** on its pill.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | Contrast 1.4.3 | A11y | `AddWinSheet.deleteButton`, dark | The Delete label is rgb(255, 92, 84) on its own pill of rgb(83, 43, 40): **3.96:1** against 4.5. Light is 4.56. The gap is already written on `destructiveTint`: `.bordered` draws label and pill from one tint, so no red clears it in dark. | S | **Not shipped: owner's call, both rendered** (`block-card-delete-paths.png`: light pill, light word, dark pill, dark word). The pill is the owner's request ("stuff like that should be native looking"). The alternative is the atomic kit's own destructive word, `destructiveInk` with `.pressWord` at 44pt: **6.42:1 light, 5.73:1 dark**, and a pill fewer on the sheet. |
| 2 | Contrast 1.4.3 `[cross-dim]` | A11y | name prompt "Name" when blank | Same `inkQuiet` prompt as the add sheet, 3.35:1. | S | **FIXED** with add-a-win #1. |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | H4 `[cross-dim]` | UX | sheet-level long-press menu | Hits hardest here, because a win being edited usually has a photograph. | S | **FIXED** with add-a-win #2. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 4 | Layout source `[cross-dim]` | DS | `photoWell` width | `UIScreen.main.bounds`. | S | **FIXED** with add-a-win #5. |

**Second pass, 2026-10-02 `[cross-dim]`:** Edit's save was `try? modelContext.save()`, so a rename that failed closed the sheet as if it had worked, and a replaced or removed photograph failed with an `NSLog`. Both now answer through add-a-win #4: "Couldn't save this win. Nothing is lost." with Save becoming Try Again, or the photo line with Cancel becoming Done. The keyboard-up fix (add-a-win #3) does not touch Edit, which opens with the keyboard down: its bands are identical before and after (196.7 break, 64 floor). Counts unchanged: the Delete pill is still the one open item, untouched, waiting on the owner.

### LOCKED items the review flagged, not changed
| Flag | Measured | Register |
|---|---|---|
| White label on the block preview's category colour (no title drawn on the card's block, but the camera glyph is white on the fill; it sits on a 0.35 ink disc for that reason) | white on red tops out at 2.78 | white-on-block-colour, LOCKED 2026-10-01 |

**Motion:** the card shares the add sheet's two animations; see `add-a-win.md`.

---
### Summary
Edit inherits the add sheet's quality and its fixes. One blocker by the skill's rubric is left on purpose: the native destructive pill fails text contrast in dark by half a point, and the only clean fix changes a control the owner asked to be native. Both are rendered for him.
