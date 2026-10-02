## Design Review — Add a win (fresh / with a photo)
**Maturity level:** L2 (`docs/design.md`; `GridConstants`, `Typography`, `AppColors` in code)
**Sub-agents run:** Visual Quality Inspector (with the imagery checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 8 (P0: 1, P1: 0, P2: 3, P3: 4)
**After this pass:** 4 open (P0: 0, P1: 0, P2: 2, P3: 2)

Captured on Strata-F, light and dark: `-strataOpenSheet add` and `-strataOpenSheet addphoto` (a placeholder gradient stands in for the photograph). The sheet opens with the keyboard up, so every capture includes it.

---

### What's working (≥3)
- **The preview is the block, not a picture of one.** The well is `BlockSurface` + `EtherealFill` at the tower's cell pitch and corner, so picking a colour or a size changes the thing you are making. Copy this.
- **The bar is one system.** Cancel `inkSecondary` **6.05:1**, Add `inkPrimary` **14.18:1**, both `.sheetAction()` at 44pt with `.pressWord`; the typed name is `inkPrimary`, not `UIColor.label`.
- **The colour row is the shared `ColourSwatchRow`**, labelled "Colour", each swatch named and `.isSelected`; colour is never the only signal because every swatch carries its glyph.
- **The segmented control is the written exemption** (32pt, 134x32 a segment); its unselected word measured **5.72:1**.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | Contrast 1.4.3 `[cross-dim]` systemic | A11y, DS | `AddWinSheet.nameField` prompt | "What did you do?" in `inkQuiet`: **3.35:1**, rgb(135) on rgb(247). The only sentence on the sheet. Dark was 5.99. | S | **FIXED.** `inkTertiary`: **4.69:1** light, **6.99:1** dark, measured off the rebuilt sheet; still a third of a typed name's 14.2, so it never reads as an answer. |

**Recurring → systemic (1 DS fix vs. 7 instance fixes).** The same token misuse is on six more text sites across this review: the plan line's prompt, the plan's repeat summary and done lines, and the replay's "wins", date and "Sample". `inkQuiet`'s own doc says "never a sentence, a count or a subtitle" and also lists "a placeholder" among its uses, and that second clause is how this happened. All seven moved to `inkTertiary`; `DesignReviewWinsSideTests.noTextInQuietInk` pins the five files. **The doc clause belongs to `CategoryColors.swift`, which this pass may not edit: it should drop "a placeholder".**

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | H4, H5 | UX | `AddWinSheet.body` `.contextMenu` | The Replace / Remove Photo menu was attached to the `NavigationStack`, so with a photograph in, a long press anywhere (the name, the colours, empty ground) lifted the whole sheet as a menu preview. | S | **FIXED.** Moved onto `photoWell`. Pinned by `photoMenuOnTheWell`. Not exercisable on this Mac (no long press), so verified in code and by the test, not on screen. |
| 3 | Visual, H1 | Visual | sheet on arrival | The preview block, the sheet's subject, is half under the keyboard when the sheet opens (fresh: block top 471pt, keyboard top about 540). The colour you pick changes a block you can only half see. | M | Not changed. The composition (subject floored, `gapPage` above) is declared, and keyboard-up is the fastest route to logging. Option for the owner: the well scrolls into view on first colour or size change. |
| 4 | H9 | UX | `AddWinSheet.save` / `attach` | Failures are silent. A new win that fails to log leaves you on the sheet with nothing said (`catch { isSaving = false }`); a photo that fails to write is dropped with an `NSLog`. | S | Not changed: it needs a sentence, and copy is the owner's ("Less text, always"). Suggest one line in the sheet and `HapticsEngine.warning()`. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 5 | Layout source | DS | `photoWell` | Cell width from `UIScreen.main.bounds`, the same fault the day album lost on 2026-10-01: wrong in landscape, iPad and Slide Over. | S | **FIXED.** The sheet's own `GeometryReader` width is passed in. |
| 6 | Motion a11y | Motion | `decisions` | The colour row's `.move(edge: .top)` transition was the sheet's one ungated movement. | S | **FIXED.** `.opacity` alone under Reduce Motion. |
| 7 | Unbound values | DS | camera disc, replace disc | `.black.opacity(0.35)` twice: a real, measured ink (it fixed 2.70:1) with no token. | S | Report: needs a name in `AppColors` (read-only here). |
| 8 | Polish | Visual | keyboard edge | The block's blurred bottom band shows through the keyboard's translucent top as a coloured haze (both schemes). | — | Report; resolves with #3. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Size change | continuity (the block grows) | `slotSnap` 0.30, ζ 1.0 | critically damped spring | none | — | — |
| b | Colour row in/out | continuity | implicit | — | #6 | P3 | fixed |

**Motion a11y:** addressed (after #6). **Overall motion quality:** Purposeful.

---
### Summary
A well-built sheet whose one real failure was the systemic one: the sheet's only sentence was set in the glyph ink. That and two cheap code faults are fixed. The open item worth the owner's eye is that the block the sheet is about arrives half hidden behind the keyboard.
