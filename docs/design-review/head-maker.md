## Design Review — Head maker (outline / failed / preview)
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector (with the Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 5 (P0: 1, P1: 1, P2: 1, P3: 2)
**After this pass:** 3 open (P0: 0, P1: 0, P2: 1, P3: 2)

Captured 2026-10-02 on Strata-E, light and dark: `-strataStartTab tower -strataOpenSheet profile -strataOpenHeadMaker outline|failed|preview`. Capture does not run in the simulator; every state is the harness's.

---

### What's working (≥3)
- **One shutter, drawn once** (`ShutterBlock`, shared with the camera): unlit is an empty rim at 5.1:1, not a dimmed fill, so the control you cannot use is not the brightest thing on the screen.
- **The guidance is one line in the middle of the screen**: "Move a little closer" in `onDarkStrong` on the near-black ground, with the progress as five pips rather than a number.
- **A failure keeps its dignity**: "Couldn't get a clear picture. Somewhere a little brighter should do it." then one verb, "Try Again". The sentence carries the cause and the fix; the button carries the action (H9).
- **Imagery:** the preview is the person's own cut-out head on an empty field, scaled to read as a portrait at arm's length; the gaze is the subject's own (bounded eye contact is the head engine's rule). No fabricated imagery.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | WCAG 1.4.3 | A11y | preview, the suggested name ("Head 2") | `inkQuiet`, **3.35:1** (rgb 133 on 244). It is the name the head gets if nothing is typed, so it is read. | S | **FIXED.** `inkTertiary`. After: **4.64:1** light (rgb 109 on 244); dark was already 5.92 and is unchanged in kind. |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | H9 recovery | UX | `.denied` copy | "Turn the camera on for **Strata** in Settings." The Settings app lists the app as Sturdy, so the instruction names an entry that is not there. | S | **FIXED.** Sturdy. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | H4 consistency | Visual, UX | preview in light mode | The capture states are near-black (rgb 2 to 10) and the preview is the light page (rgb 231): one flow, two grounds, with the switch at the moment the result appears. Defensible (the head is shown where it will live) and jarring at the cut. | M | Not changed; owner's eye. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 4 | 2.1.2 escape | A11y | full-screen cover | No `.accessibilityAction(.escape)`. Left alone on purpose: a scrub that discards a half-made head is worse than none; the close button is labelled. | — | None. |
| 5 | Copy | UX | "Retake" grey beside "Save" ink | Retake **6.02:1**, Save **13.74:1**: the hierarchy is ink weight, not size. Correct; recorded. | — | None. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Outline fade on failure | feedback | token | ease | none | — | — |
| b | Head takes on the preview | delight, earned | `headTakeHold*` 2.6-3.4s | authored | Reduce Motion is a face swap only | — | — |

**Motion a11y:** Yes (`reduceMotion` read). **Overall:** Purposeful.

---
### Summary
The maker is a careful dark instrument with one line of guidance and one control. Its two defects were text: a suggested name at 3.35:1 and an instruction pointing at a Settings entry under the app's old name. Both are fixed.
