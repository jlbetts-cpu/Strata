## Design Review — The map (empty / with places)
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector (with the Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 6 (P0: 0, P1: 2, P2: 2, P3: 2)
**After this pass:** 4 open (P0: 0, P1: 0, P2: 2, P3: 2)

Captured 2026-10-02 on Strata-E, light and dark: empty `-strataStartTab memories -strataSeedWins 0 -strataOpenMap 1`; with places `-strataSeedHistory 4 -strataSeedPlaces 1 -strataSeedRealPhotos 1 -strataOpenMap 1`. Full-bleed, so `page-room.py --signature` reads both as one band (0.0/781.0) and cannot tell them apart; they were told apart by looking.

---

### What's working (≥3)
- **The way back is an ink glyph on a light-pinned disc**, 19.70:1 over every ground the map has (`MapBackButton`), and the recentre control is the app's own `GlassIconButton`, not MapKit's blue chevron. Two controls, one vocabulary.
- **The empty state asks where the asking belongs.** "Your map starts here" (**14.30:1**) over one sentence (**6.09:1**) and a `PrimaryCapsule` "Turn On Places": the one screen that needs location is the one that requests it, with the reason first. The capsule is ink, flat, the app's one primary.
- **The ground is quiet so the blocks can be loud.** Muted emphasis, no POIs below zoom 13, every block one 44pt cell with a count badge as the only quantity: check 5 holds on a screen MapKit draws most of.
- **Imagery:** a block on the map is the person's own photograph at its place: meaning (where), content (what), context (the street it stands on) all literal. The seven-second bundle cross-fade is the written exemption.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | WCAG 4.1.2 role | A11y | `MemoriesMapView.block(for:)`, `.onTapGesture` | A block is the map's only control and VoiceOver read it as "3 wins here" with no role: nothing said it opens. | S | **FIXED.** `.accessibilityAddTraits(.isButton)` beside the tap. |
| 2 | H4 consistency, H2 `[cross-dim]` copy | UX | empty and denied sentences | "Photos you take in **Strata** keep the place…" and "**Strata** can't tell where a photo was taken." The app's name on the home screen and in every permission prompt is **Sturdy** (`INFOPLIST_KEY_CFBundleDisplayName`, `docs/brand.md` "The name is Sturdy", 2026-09-30), and the location prompt this card leads into says "Photos you take in Sturdy keep the place they were taken". Two names, one sentence apart. | S | **FIXED.** Sturdy. Systemic across my files, see `settings.md` #3. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | H6 / 4.1.2 name | A11y, UX | `PlaceBlock` label "N wins here" | Every block says the same thing apart from a number. A VoiceOver user cannot tell two places apart without opening each. | M | Not changed. The name comes from `PlaceNames` asynchronously; read it when resolved, fall back to the count. |
| 4 | Check 5, colour is content | Visual | empty state card and tab bar over water | Both are glass and take the ocean's cyan through them, so the only chrome on the screen is tinted blue (light capture, mean card ground rgb 226, 252, 238). Liquid Glass behaving as designed; the card is the one piece of chrome the app owns here. | M | Not changed. A `.regular` card is what the platform does; pinning it light like the back disc is the option if the owner reads it as blue. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 5 | Attribution | Visual | "Maps / Legal" bottom left | Required by the Apple Developer agreement; it is placed clear of the tab bar by `safeAreaPadding`. | — | None. |
| 6 | Motion 2.2.2 | Motion | bundle cross-fade, 7s | Auto-updating with no pause; Reduce Motion is the switch. Written exemption on check 10. | — | None. |

### LOCKED and settled items the review would flag, not changed
| Flag | Register |
|---|---|
| The seven-second bundle cycle animates with nobody doing anything (check 10) | owner's instruction, written exemption in `docs/screen-audit.md` |
| Every block one cell regardless of how many wins (encoding size would be "richer") | CLAUDE.md, The map: three measurements took the size exception off |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Blocks arrive | orientation (centre out) | 18ms stagger, capped 260ms | `gentleReveal` | within the skill's 30-50ms stagger guidance; capped | — | — |
| b | Badge appears | feedback | `gentleReveal`, nil under Reduce Motion | spring token | none | — | — |
| c | Bundle cross-fade | content | 7s | crossfade | #6 | P3 | — |

**Motion a11y:** Yes (`reduceMotion` read in both the map and the block). **Overall:** Purposeful.

---
### Summary
The map does the hard thing well: it makes MapKit quiet enough that the person's photographs are the subject. The two real defects were small and cheap: the blocks were invisible as buttons to VoiceOver, and the empty state called the app by the name it gave up three days ago, a sentence away from a system prompt using the new one. Both are fixed.

**Morning pass, 2026-10-02:** #3 FIXED: a block says its place's name once `PlaceNames` knows it, then the count ("Hackney, 3 wins"); the name is read, never fetched, because geocoding is rate-limited and twenty blocks would be refused.
