## Design Review — Wins (no wins / one win / forty wins)
**Maturity level:** L2. `docs/design.md` is the DESIGN.md; the system is in code (`GridConstants`, `Typography`, `AppColors`); the atomic-kit table is the compliance checklist.
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 5 (P0: 0, P1: 1, P2: 2, P3: 2)
**After the first pass:** 4 open (P0: 0, P1: 0, P2: 2, P3: 2)
**After the second pass (2026-10-02, below):** 3 open (P0: 0, P1: 0, P2: 1, P3: 2)

Captured 2026-10-02 on Strata-F at 402x874 @3x, light and dark: `-strataStartTab tower -strataSeedWins 0|1|40`. Text contrast is the extreme ink pixel against the modal ground of the same crop. **The forty-win fixture drew no photographs** (`-strataSeedTodayPhotos 1 -strataSeedRealPhotos 1` both tried), so forty was judged as colour blocks only.

---

### What's working (≥3)
- **One control in open air.** The header is `GlassIconButton("checklist")`, 44pt, labelled "Plan", pinned to the grid's own width so it ends on the tower's right edge. The empty corner is LOCKED and reads as intended.
- **The only control on an empty screen clears its floors.** The slot's plus measured **3.42:1** in its recess (3:1 required) and the one sentence **14.31:1**, `headerMedium` in `inkPrimary` on the 16pt margin.
- **Reduce Motion is handled at every moving part**, not with a blanket switch: the drop, the block ripple and the lattice ripple are gated (`TowerLattice` 358/488, `MainAppView` 1337/1583/2082), and `FlippableBlockView` swaps the tap squash for `crossFade` rather than dropping feedback. Copy this pattern.
- **Shadow language is single and earned**: only blocks carry a contact shade; the slot "stands on nothing, so it casts nothing" (`NextSlotButton` doc). Matches the skill's "depth grammar follows the style family".
- **Dark mode is designed, not inverted**: the lattice's dark alpha is derived from the light ratio and pinned by `TowerLatticeTests`.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | A11y 2.5.1 / 4.1.2, H7 `[cross-dim]` | A11y, UX | `NextSlotButton.swift` accessibility | VoiceOver's activation drops a Quick and that was the only non-drag path from the slot: Regular, Deep and the named win needed a drag, and the hint told a VoiceOver user to "drag out to make it bigger". | S | **FIXED.** Three `accessibilityActions` (Log a Regular win, Log a Deep win, Name it first) on the same `fire`/`onOpenMenu` a finger reaches; hint is now "Drops a block onto your tower." Pinned by `DesignReviewWinsSideTests.slotOffersEverySize`. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Proximity, H6 | Visual, UX | `MainAppView.towerEmptyStateMessage` | "Tap the slot to log your first win." sat at y 144-161; the slot it names is at y 694. **533pt** of nothing between an instruction and its target. It was placed under the date, and the date came off on 2026-10-01, so its anchor left with it. | M | **FIXED (second pass).** The sentence is an overlay on the slot's own frame, `gapLabel` above its top edge: ink y661.0 to y676.7, slot y694.0, **17.3pt** between them (was **534.0**), measured the same way off both captures in light and dark. It rides on the slot when the slot is drawn out (same `slotSnap` transaction, verified in code: nothing here can drag) and leaves on `isCascading`, before the first block exists. Burst of 70 frames on `-strataAutoWin 1`: the sentence is up in frames 13-14, gone in 15-17, the block is in the air from 18; **0 frames with both**. Ink 14.3:1 light and dark, unchanged. Pinned by `WinsSideSecondPassTests.emptyStateOnTheSlot`. |
| 3 | Motion a11y | Motion | `NextSlotButton.draw` `reduceMotion ? .small : released(value)` | Under Reduce Motion a drag always drops a Quick: the setting removes a capability (choosing a size by drag) rather than the motion. A route remains (tap, then the sheet's size control) and #1's actions now give a second. | M | Not changed: it is the primary gesture and `TowerGestureTests` covers it. Replace the growth with a crossfade between the three snapped sizes rather than disabling the choice. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 4 | Motion tokens | DS, Motion | `NextSlotButton.fire` | `.interpolatingSpring(duration: 0.34, bounce: 0.18, initialVelocity:)` is the one inline spring `docs/motion-audit.md` already lists. It needs the finger's velocity, so the token has to be a function. | S | Report: `GridConstants.slotRelease(velocity:)`, in the motion collapse. |
| 5 | Visual | Visual | 1x1 blocks at forty | "Cooked...", "Read a c...", "Ten minu..." truncate at 13pt. This is the declared exemption on `BlockContent` (the lever is the cell, not the type), recorded so it is seen, not reopened. | — | None. |

### LOCKED items the review flagged, not changed
| Flag | Measured | Register |
|---|---|---|
| White block labels | 1.71 to 2.70:1 on orange, pink, purple, green, against 4.5 | owner, 2026-10-01: "I much prefered the white ink look over the dark ink" |
| Single block corner 8 beside a merged run at 12 | three radii for one object | owner, 2026-10-01: "Leave it at 8" |
| `TowerLattice` 1.03:1 | below the 4-level structure floor | refused twice; texture by declaration |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Block fall | continuity (where the win went) | `t = sqrt(2d/g)`, 0.34-0.72s | constant acceleration | over the skill's 500ms "large" at the top of the range; physical by design and LOCKED ("All masses fall the same") | — | none |
| b | Slot press/release | feedback | `tapSquashSpring` 0.06, `elasticPop` | spring | inline release spring (#4) | P3 | token |
| c | Tenth-win dance | earned delight | `danceRise`/`danceSettle` | spring | gated off under Reduce Motion | — | none |

**Motion a11y:** prefers-reduced-motion addressed? **Partially** (#3). **Overall motion quality:** Purposeful.

**Translated, not invented:** "keyboard navigation" is VoiceOver order and Full Keyboard Access; the tower's blocks are buttons in reading order and the header button precedes them. "Skip links" (2.4.1) has no iOS meaning on a single-region tab.

---
### Summary
The Wins tab is the reference screen and it measures like one: one control, one sentence, every ratio on the page clears its floor. The real defect was not visual: the slot, the app's primary action, could only make its two bigger sizes with a drag, and that is fixed. The second pass moved the empty state's sentence from 534pt above the slot to 17pt above it, so the one sentence on the page now captions the one thing it is about, and the white space above it is the room the tower grows into rather than a gap between a caption and its subject.

---

### Second pass, 2026-10-02: re-graded

Captured on Strata-F at 402x874, light and dark, `-strataStartTab tower -strataSeedWins 0` (empty), `1` (one win), and `-strataAutoWin 1` burst-captured for the first drop. `page-room.py --signature` separates every capture in the set.

| | before | after |
|---|---|---|
| sentence ink to slot top | 534.0pt | 17.3pt |
| page bands (signature) | 27.7/30.3, 27.0/16.7, **533.3**/146.0 | 27.7/30.3, **543.7**/16.7, 16.7/146.0 |
| sentence ink | 14.3:1 | 14.3:1, light and dark |
| frames with the sentence and a falling block | n/a | 0 of 70 |

The big break is still on the page and is now above the sentence, between the header and the foot of the tower: the empty field a short tower stands under, which is the composition `docs/design.md` LOCKS ("lots of white space, and it has to be doing something").

**Re-run of the chain on the changed screen.** Visual: one column on one margin, caption on its subject; the line crosses the faint bottom of the lattice's second row, which at 1.03:1 (LOCKED) does not read as anything printed under it, checked by eye in both schemes. UX: H6 resolved. A11y: contrast unchanged; **VoiceOver reading order is now the slot, then the sentence** (an overlay follows its base), which is not verified on this Mac and is the one thing worth a listen on a phone. DS: `gapLabel`, `headerMedium`, `inkPrimary`, no literals. Motion: the sentence leaves on `.opacity` with the cascade's own transaction; no new animation. No new findings.

**Not verified:** the sentence riding up with a drawn-out slot (no drag on this Mac; it is the same frame and the same transaction, so it is code-verified only).
