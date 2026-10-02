## Design Review — Camera (viewfinder / permission refused / review)
**Maturity level:** L2 (`docs/design.md`; `GridConstants`, `Typography`, `AppColors` in code)
**Sub-agents run:** Visual Quality Inspector (with the art-direction imagery checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 3 (P0: 0, P1: 0, P2: 0, P3: 3)
**After this pass:** 3 open (P0: 0, P1: 0, P2: 0, P3: 3)

Captured on Strata-F, light and dark: `-strataStartTab camera`, `-strataCameraDenied 1`, `-strataOpenReview medium`. The camera pins the window dark, so both schemes are the same layout (`page-room.py --signature` agrees, which here is correct rather than a capture fault). **The simulator has no capture device**: the live viewfinder, the bright-frame shutter, pinch, double tap and drag-to-expose are unverified and not claimed.

---

### What's working (≥3)
- **The refused state cannot be mistaken for a working camera.** The control row is ruled out and hidden from VoiceOver; the copy measures **11.42:1** on black, the title is the one 34 Bold, and "Open Settings" is a 44pt target that does the only thing that can help.
- **Every glyph control is the shared one.** `ShutterBlock` (shared with the head maker), `GlassIconButton` with labels ("Close camera", "Take photo", "Lens, 1x"), and the countdown announces "3 seconds" rather than "3".
- **The review's chrome carries its state in more than colour.** The size picker and `FilmLookStrip` both set `.isSelected`; an unselected look name is **6.25:1**, Retake **11.42:1**, and the chosen look adds a 2pt rim as well as a brighter word.
- **Gestures have single-pointer equivalents** (WCAG 2.5.1): pinch has the lens button, double tap has the flip button.
- **Imagery checklist:** the photograph is the only saturated object on the page; chrome is ink on black; text over the picture (the size capsule) goes through `GlassRecipe.typePanel`, the recipe measured for words over imagery.

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
| — | None | | | | | |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | Alignment (11d) | Visual | `CameraView.reviewLayer` | Three left edges on the review: the photograph at **18.7** (a 3:4 frame fitted by height, 364.3 wide), Retake's ink at **25.0** (`padding(.horizontal, gapWide)`), the film strip centred from 73. The app's margin is 16. | S | Report. Moving the action row to 16 still leaves 2.7pt against the picture, and tying it to the picture makes it move with every aspect ratio. |
| 2 | H4 consistency | UX | `CameraView.accessRefused` | The one page of centred copy left in the app. Wins empty, Memories empty and Store unavailable all moved their copy to the leading margin on 2026-10-01 for "two alignment systems on one screen". | S | Report: brand-visible, and a centred figure on pure black is defensible. Owner's eye. |
| 3 | DS literal | DS | `CameraView` Retake / Use Photo | `minWidth: 88` is a literal: two 44pt targets, unnamed. | S | Report. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Shutter press | feedback | `shutterPress` 0.08 / `shutterRelease` | ease-out / spring | none | — | — |
| b | Capture flash | feedback | `screenFlashOut` 0.22 | ease-out | one flash per capture, nowhere near 3 a second | — | — |
| c | Page fade-in, controls | continuity | `mapFade`, `gentleReveal` | — | both nil under Reduce Motion (lines 343, 1072) | — | — |

**Motion a11y:** addressed. **Overall motion quality:** Purposeful.

**Translated, not invented:** "focus visible" is VoiceOver's own cursor here; there is no custom focus ring to style. 2.4.1 skip links has no iOS meaning.

---
### Summary
The strongest screen on this side of the app: every measured pair passes, the refused state is honest, and the shared shutter and glass buttons hold. Three cosmetic notes, none of them worth a change without the owner looking, and the whole live-camera half of the screen still needs one look through a real lens.
