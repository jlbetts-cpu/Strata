## Design Review — Onboarding (six pages)
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector (with the Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 6 (P0: 0, P1: 0, P2: 3, P3: 3)
**After this pass:** 4 open (P0: 0, P1: 0, P2: 2, P3: 2)

Captured 2026-10-02 on Strata-E, light and dark: `-strataShowOnboarding 1 -strataOnboardingStep 0…5`. All six layout signatures differ (`page-room.py --signature`), so no page was photographed twice.

---

### What's working (≥3)
- **One primary, identical on six pages**: `PrimaryCapsule`, ink, flat, at the same y on every page; the waiting state ("What else") is an outline at 4.6:1 rather than a dimmed fill. One verb per page: "Let me try", "Go on", "Turn on places", "One more thing", "Start".
- **One composition, six times**: title (Bold, wrapping on the margin), one sentence, a figure in a reserved band, the pill. The figure band is where the owner's illustrations land; pages 2, 4 and 6 already leave it as air.
- **Imagery on page 1 and 6 is real**: the owner's own photographs in the block grid, and his own portrait on the thank-you page with his name and role under it. Meaning, content and context are all literal; nothing stock, nothing generated.
- **Asking happens where it is explained**: page 4 says why ("Your wins land on the map where you took them") before "Turn on places".

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | H2 honesty, imagery "no fabricated product screenshots" | Visual, UX | page 4, `MemoriesStill` | The phone shows **the map as the Memories screen**, with the "Memories" title and the profile button floating on it. Since 2026-09-30 Memories is a page and the map is a button on it, pushed full screen with a back button and no title. The picture promises a screen the app no longer has. | M | Not changed: recomposing `MemoriesStill` is a figure the owner should see first. The honest picture is the map as it is now (back disc, blocks, recentre), no title. |
| 6 | Contrast inside a picture, dark scheme | Visual, A11y | page 4, `MemoriesStill` chrome | `DemoMap` is a baked capture of the PALE map, and the chrome drawn over it followed the phone: in dark mode the "Memories" title was white on the pale map, **1.25:1** (rgb 220 on 197), against **8.95:1** in light, and the tab glyphs went white on a light capsule. | S | **FIXED.** The still is pinned to the light scheme, which is what it is a picture of. After: **8.95:1** in both schemes (rgb 35 on 197). |
| 2 | H2 honesty (known, outstanding) | Visual | page 3, `DemoViewfinder` | A baked camera screenshot still shows the tab bar WITH labels (Wins / Camera / Memories), which the app removed on 2026-10-01. Recorded in `docs/screen-audit.md`; needs a fresh device shot (no capture device in the simulator). | M | Not changed. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | H2 | UX | page 5, "Find it in Profile, and on your photos." | Every head placement is off by default, so it is not on your photos until you switch it on. | S | Not changed: copy is the owner's. "and on your photos, if you like." |
| 4 | Copy | UX | page 6 accessibility label | "Jayden, who made Strata" | S | **FIXED.** Sturdy. |
| 5 | Check 11c | Visual | pages 2, 4, 6 | The biggest break is the empty illustration band; it becomes a composed break the day the drawings land. Recorded in `docs/screen-audit.md`. | — | None. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Page advance | orientation | token | spring token | none | — | — |
| b | Page 2's try-it slot | feedback | the real slot's | spring | none | — | — |
| c | Page 5 head takes | delight, earned | `headTakeHold*` | authored | Reduce Motion: face swap only | — | — |

**Motion a11y:** Yes (`reduceMotion` read in `OnboardingView`). **Overall:** Purposeful.

---
### Summary
The walkthrough is the most consistent flow in the app: one composition, one primary, one verb a page. Its open findings are both pictures that no longer tell the truth: the map page draws a Memories screen the owner replaced on 2026-09-30, and the camera page still carries tab labels the app removed. Neither was redrawn here, because both are figures he should see first.

**Last pass, 2026-10-02:** #1 FIXED (owner: "Redraw it"): `MemoriesStill` draws the map screen with its back disc and no title. #2 FIXED: the icon-only tab bar from the simulator's camera capture is set into `DemoViewfinder` at the identical rectangle; `LastFourToTenTests` reads the old label band (255 before, 69 now).
