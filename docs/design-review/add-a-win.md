## Design Review — Add a win (fresh / with a photo)
**Maturity level:** L2 (`docs/design.md`; `GridConstants`, `Typography`, `AppColors` in code)
**Sub-agents run:** Visual Quality Inspector (with the imagery checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 8 (P0: 1, P1: 0, P2: 3, P3: 4)
**After the first pass:** 4 open (P0: 0, P1: 0, P2: 2, P3: 2)
**After the second pass (2026-10-02, below):** 2 open (P0: 0, P1: 0, P2: 0, P3: 2), one of them new

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
| 3 | Visual, H1 | Visual | sheet on arrival | The preview block, the sheet's subject, arrived with its bottom under the keyboard (fresh: block y378.7 to y559.7, keyboard top y540.0, **19.7pt hidden**, the blurred band). | M | **FIXED (second pass).** While the name has focus the keyboard is the floor: the spacer's minimum and the bottom padding both take `gapWide` instead of `gapPage`. Fresh Add: block **y339.0 to y519.7, whole, 20.3pt above the keyboard**. With a photo (no colour row) the spacer grows back: break 63.7 to **74.7**, block 25.7pt clear. Keyboard down (Edit) is unchanged, signature identical: 196.7 break, 64 floor. Pinned by `WinsSideSecondPassTests.blockClearsTheKeyboard`. |
| 4 | H9 | UX | `AddWinSheet.save` / `attach` | Failures were silent. A new win that failed to log left you on the sheet with nothing said (`catch { isSaving = false }`); a photo that failed to write was dropped with an `NSLog`; and an edit's save was `try?`, so a rename that failed closed the sheet as if it had worked. | S | **FIXED (second pass)**, as the head maker answers: one line under the name in `screenSubtitle` + `inkPrimary` (**14.3:1** light, **14.4:1** dark), `HapticsEngine.error()`, a VoiceOver announcement, and the bar's words change with what the press will now do. Three cases, `AddWinFailure`: "Couldn't save this win. Nothing is lost." (Add becomes **Try Again**); "Couldn't save the photo. The win is saved." and "Couldn't remove the photo. The win is saved." (Add becomes **Try Again**, Cancel becomes **Done**, because the win is already on the tower and closing keeps it). A retry after a photo failure finishes the win already logged, never a second one; a failed log takes back the habit and log `logWin` inserted before its save threw, so Try Again cannot write two wins (pinned by `failedInsertIsTakenBack`); a failed photo write puts the log back on its old file and deletes the new one, so a retry cannot orphan the photograph it was replacing. The line is an overlay in the 64pt break, so nothing moves. Rendered with `-strataAddWinFailure win\|photo\|removal` (DEBUG, read in `AddWinSheet.load`). Pinned by `failureCopy`, `failureWords`, `noSilentFailures` and its injection. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 5 | Layout source | DS | `photoWell` | Cell width from `UIScreen.main.bounds`, the same fault the day album lost on 2026-10-01: wrong in landscape, iPad and Slide Over. | S | **FIXED.** The sheet's own `GeometryReader` width is passed in. |
| 6 | Motion a11y | Motion | `decisions` | The colour row's `.move(edge: .top)` transition was the sheet's one ungated movement. | S | **FIXED.** `.opacity` alone under Reduce Motion. |
| 7 | Unbound values | DS | camera disc, replace disc | `.black.opacity(0.35)` twice: a real, measured ink (it fixed 2.70:1) with no token. | S | Report: needs a name in `AppColors` (read-only here). |
| 8 | Polish | Visual | keyboard edge | The block's blurred bottom band showed through the keyboard's translucent top as a coloured haze (both schemes). | — | **FIXED with #3**: nothing of the block is under the keyboard. |
| 9 | Visual, H1 (residual of #3) | Visual | Deep from the camera | A 2x2 well is 370pt; the field above a 402x874 keyboard is about 420 less the name and the size control. No spacing fits it, so a Deep that arrives from the shutter still opens partly under the keyboard and scrolls. | M | Report. The lever would be the well's scale while typing, and the well being the block at the tower's pitch is the sheet's best idea, so not touched. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Size change | continuity (the block grows) | `slotSnap` 0.30, ζ 1.0 | critically damped spring | none | — | — |
| b | Colour row in/out | continuity | implicit | — | #6 | P3 | fixed |

**Motion a11y:** addressed (after #6). **Overall motion quality:** Purposeful.

---
### Summary
A well-built sheet whose one real failure was the systemic one: the sheet's only sentence was set in the glyph ink. That and two cheap code faults are fixed. The second pass closed the other two: the block the sheet is about now arrives whole above the keyboard, and a save or a photograph that fails says so and offers the right next press.

---

### Second pass, 2026-10-02: re-graded

Captured on Strata-F at 402x874: `-strataSeedWins 0 -strataOpenSheet add`, `addphoto`, `-strataAddWinFailure win|photo|removal` (light and dark), and `-strataSeedWins 8 -strataOpenSheet edit` to prove the keyboard-down sheet did not move.

| | before | after |
|---|---|---|
| fresh Add: block bottom vs keyboard top (y540.0) | 19.7pt under | 20.3pt clear |
| with a photo: break over the block | 63.7 | 74.7 |
| Edit (keyboard down): bands | 196.7 break, 64 floor | identical |
| a failed save / photo write | nothing on screen | one line, 14.3:1; a new verb; haptic; announcement |

**Re-run of the chain.** Visual: with the keyboard up the page reads as two groups, the name and then colour, size and the block they make; the break above the block is `gapWide`, 1.6x the gap inside the group, so it still reads as a step, and it grows back wherever there is room. The failure line sits 12pt under the name and 39pt over the colour row, so it groups with the field and the bar, not with the controls. UX: H9 resolved; the words in the bar now say what each press does in every state. A11y: line 14.3:1 / 14.4:1; announced. DS: `screenSubtitle`, `inkPrimary`, `gapItem`, `gapWide`, `crossFade`; no literals. Motion: the line crossfades on `crossFade`, nothing travels. **"Try Again", not "Try Saving Again"**: the long form started 21.3pt after the centred title on this phone (about 8pt on a 375pt one); the reason is on `AddWinFailure.retry`. **Not verified:** a real disk failure (none can be caused here) and the photo-failure state with a photograph on it (the fixture opens without one, so the colour row shows; with a photograph the row hides and the line has more room, not less).
