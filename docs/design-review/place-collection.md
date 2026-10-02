## Design Review — Place / curated collection
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector (with the Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 4 (P0: 0, P1: 0, P2: 1, P3: 3)
**After this pass:** 4 open (P0: 0, P1: 0, P2: 1, P3: 3)

Captured 2026-10-02 on Strata-E, light and dark: `-strataStartTab memories -strataSeedHistory 30 -strataSeedPlaces 1 -strataSeedRealPhotos 1 -strataOpenCurated 0` ("Read a chapter", nine photographs). **A PLACE collection is not reachable from the harness**: it opens from a map block, behind a tap, and there is no `-strataOpenPlace`. Its one place-only behaviour (the title while the name geocodes) was reviewed from source.

---

### What's working (≥3)
- **The camera roll, not a designed grid**: edge to edge, three across, square, 2pt hairline, month headings, no captions (the owner's 2026-09-09 call), so the photographs read as photographs.
- **Count line 4.69:1** (`CountReadout`, `inkTertiary`), title Bold 34 on the 16 margin, back is the system button.
- **The empty case has a sentence**, gated on `hasLoaded` so it never flashes: deleting the last photograph from inside the viewer does not leave a title over a blank page.
- **Imagery sequencing:** grouped by month, newest first; nothing is juxtaposed except by time, which is the only story this collection claims.

### P0 / P1
None.

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | H2 copy | UX | `.place` title before the geocode: `"\(matching.count) here"` | For as long as the name takes, the page's title is "9 here", a phrase rather than a name, at 34pt. The count is hidden while it is the title (`titleIsCount`), so nothing is said twice; it is just an odd heading. | S | Not changed (cannot be photographed here). "9 photos" in the title slot, or the title band empty until the name lands. Owner's copy call. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Check 11c (exempt) | Visual | 116pt under the last row | `tabBarClearance` showing through a less-than-a-screen collection; written exemption. | — | None. |
| 3 | Rhythm | Visual | a month with one photograph | One square then a full section break: October reads as a stray. Proximity is right (16 to its heading, 68 to the next); a single item is just lonely. | — | None. |
| 4 | 4.1.2 name | A11y | grid cell label `"Photo"` | Same as `memories.md` #8. | S | Not changed. |

### Motion review
Open from the album card (system zoom); photographs open out of their thumbnails. **Motion a11y:** system transitions. **Overall:** Purposeful.

---
### Summary
The collection is the camera roll and it reads like one, with every number clearing its floor. The only finding is copy that cannot be photographed from this harness: a place's title is "9 here" until its name arrives.
