## Design Review — Replay (mid-build / at rest)
**Maturity level:** L2 (`docs/design.md`; `GridConstants`, `Typography`, `AppColors` in code)
**Sub-agents run:** Visual Quality Inspector (with the imagery checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 5 (P0: 1, P1: 0, P2: 1, P3: 3)
**After this pass:** 3 open (P0: 0, P1: 0, P2: 1, P3: 2)

Captured on Strata-F, light and dark: `-strataStartTab memories -strataOpenReplay sampleWeek -strataReplayAt 5.0 | 16.0`.

**A fixture finding first, because it hid the P0.** `tools/capture-screens.sh` opens the replay with `-strataOpenReplay` and no start tab, so the app starts on the camera, which pins the window dark, and the replay draws dark whatever the phone is set to. `docs/screen-audit.md` reads the two schemes coming back identical as "the `onDark` family working as designed"; it was the camera's scheme. **The light replay had not been photographed before this pass.** Add `-strataStartTab memories` to that line (the script is not this pass's to edit).

---

### What's working (≥3)
- **The whole replay is a function of time**, so pause, skip, the live player and the exported video cannot drift apart, and Reduce Motion gets a still composition from the same script rather than a second code path.
- **VoiceOver is designed, not tolerated**: the replay opens at the close, announces once ("Your week, 7 to 13 September. 31 wins."), reads the date as words while the screen shows "9/28-10/4", and skipping is an accessibility action rather than the tap gesture.
- **The count is the Wins tab's own header**, the odometer rolls only the digits that change, and the controls are `GlassIconButton`s at 44pt with labels.
- **Imagery:** photographs are the blocks, in the tower's own `BlockFace`, so the sequence reads as one day's record rather than a collage; no caption is laid over a picture except a block's own title.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | Contrast 1.4.3 `[cross-dim]` systemic | A11y, DS | `ReplayFrame.countLine`, `rangeLine` | "wins", the date and "Sample" in `inkQuiet` on the light page: **3.35, 3.32, 3.35:1**. Dark was 6.0, which with the fixture fault above is why nobody saw it. The exported video renders light, so every shared video carried it. | S | **FIXED.** `inkTertiary`: **4.69, 4.66, 4.69:1** light and **6.84 to 6.92:1** dark, measured off the rebuilt replay. |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Legibility 1.4.4, H8 | Visual, A11y | at rest, a 22-win week | Block titles are drawn at the camera's scale: "Called Mum" has a **5.3pt cap**, about **7.5pt type**, half the 15pt floor, white on colour (LOCKED white). Twenty-two labels nobody can read is texture, not text. | M | **Not shipped: owner's call, both rendered** in `replay-titles-paths.png` (second pass, below). |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | H6, H10, WCAG 2.2.2 | UX | `ReplayView.hold` | The only pause is a 0.2s hold with nothing on screen saying so. 2.2.2 is met in function (pause, skip, and VoiceOver starts at the close), but a sighted person meets an 18-28s autoplay with no visible control. | S | Report. |
| 4 | Motion token | DS | `ReplayView` loading fade | `.animation(.easeOut(duration: GridConstants.replayLoadingFade), …)` builds an animation inline from a duration token. | S | Report: a named `Animation` beside the duration. |
| 5 | DS literal | DS | `ReplayLoadingSlot` | `lineWidth: 1.5` beside a `strokeDefault` token of exactly 1.5. | S | **FIXED.** |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Falls | continuity | gravity, per block | constant acceleration | — | — | LOCKED physics |
| b | Count roll | feedback (one per landing) | 0.16s | script | — | — | — |
| c | Reveal zoom | orientation (the whole week) | script | geometric zoom | longer than 500ms; it is the replay's expressive moment and the skill allows that register | — | — |
| d | Autoplay | — | 18s week / 28s month cap | — | over 5s, paused only by an unseen hold (#3) | P3 | report |

**Motion a11y:** addressed (Reduce Motion gives a still composition). **Overall motion quality:** Purposeful.

---
### Summary
The replay is the most carefully engineered screen on this side of the app, and its one blocker was invisible only because the fixture had never shown it in light: the count's word and the date were in the glyph ink, in every exported video. That is fixed. The open question for the owner is whether twenty-two 7pt labels at rest are part of the picture or should leave with the reveal.


---

### Second pass, 2026-10-02: the titles at rest, both ways

`replay-titles-paths.png`: the sample week (22 wins) at rest, `-strataStartTab memories -strataOpenReplay sampleWeek -strataReplayAt 16.0`, light, which is the scheme the video exports in. A is the build that ships. B was rendered by setting `ReplayFrame.titleScaleFloor` to 0.60 (just above this week's 0.574 rest) for one build, and reverted; **nothing about this ships.** `page-room.py --signature` returns the same layout for both, which is correct: the titles are inside the blocks.

| | A: titles kept (ships) | B: faded at rest, as the month |
|---|---|---|
| what is on the last frame | 22 labels at about 7.5pt (5.3pt cap), white on colour; 3 truncate ("Morning..."); 10 sit on photographs | the colours and the photographs only |
| the 15pt floor | 22 sites under it, half its size | met: no text in the tower at rest |
| what a friend learns | the names, if they pause and squint; on a phone at video size they are smaller still | the names only during the build, where each lands at 17pt (checked at t=5.0: "Called Mum", "Cooked dinner" legible) |
| the 12 blocks with no photograph | named | a colour and a size, nothing else |
| consistency | a week keeps titles, a month drops them, decided by `fitScale` | week and month read alike; a light week resting above the floor would still keep them |

**What each costs.** A keeps every win's name in the frame people pause on and screenshot, and pays for it with 22 pieces of type the app's own floor says nobody can read, which on a busy week is the dust the month's comment describes. B is the premium-is-subtraction reading: the record at rest is a picture of a week, the words were read as it was built, and in the live replay a tap on a photographed block opens the photograph (not in the video); it costs the twelve colour-only blocks their identity in the one frame that stays on screen. **A third option the numbers point at, not rendered:** the honest floor for 17pt type is a scale of 0.88 (17 x 0.88 = 15), which would fade titles on almost every week at rest, so "fade like the month" and "obey the type floor" are the same rule only if the floor moves to about there. The owner's call; the replay is shared as video.

Counts for this screen unchanged by the second pass: 3 open (P0: 0, P1: 0, P2: 1, P3: 2).

**Morning pass, 2026-10-02:** #4 FIXED: `GridConstants.replayLoadingOut` names the fade as an `Animation`.
