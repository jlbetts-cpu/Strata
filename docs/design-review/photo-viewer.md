## Design Review — Photo viewer
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector (with the Imagery Review Checklist), UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 5 (P0: 0, P1: 1, P2: 1, P3: 3)
**After this pass:** 3 open (P0: 0, P1: 0, P2: 1, P3: 2)

### First: it has now been photographed, and why it had not been

`-strataStartTab memories -strataSeedHistory 6 -strataSeedRealPhotos 1 -strataOpenPhoto 0` landed on the viewer **five times out of five** on Strata-E (light x3, dark x2, settled 34s each, mean rgb (14, 27, 38)). The flag and the fixture are not at fault, so `DebugHarness.swift` needs no change.

What the earlier four springboards most likely were: the only `Strata` crash report on this Mac in that window (`~/Library/Logs/DiagnosticReports/Strata-2026-10-01-212403.ips`) is the **test host** aborting in `bareAudioEngineCanRun` (`StrataTests`, an AudioToolbox RPC timeout in `AVAudioEngine.mainMixerNode`). A unit-test run on the same simulator replaces and kills the app; a capture racing one comes back as the home screen. That is an inference from one report, not a reproduction, and it is written down as one. The rule it suggests: never capture on a simulator a test run is using.

Captured: `/tmp/r2/light/viewer.png`, `/tmp/r2/dark/viewer.png`. The viewer pins itself dark, so the two schemes are the same picture (the system appearance only reaches the delete dialog and share sheet).

---

### What's working (≥3)
- **The picture is a print on a field.** It fits with `aspectRatio`, inset 16 on the margin the chrome uses, and nothing is drawn on it: the title is in the black above, the caption in the black below (CLAUDE.md, the owner's 2026-09-09 call). Imagery checklist: meaning, content and context are the person's own; no text over the image; nothing to scrim.
- **Destruction is explained before it happens.** "Remove this photo?" / "The win stays on your tower. Only the photograph is deleted." This is H5 and H3 done properly: the dialog names what will NOT happen, which is the fear. Copy it anywhere a deletion has a non-obvious scope.
- **Every control clears its floors.** Caption `onDarkQuiet` **6.25:1** on black; close and actions are `GlassIconButton`s at 44pt; filmstrip targets are the unscaled 46x60 layout box (`contentShape` after the scale), not the drawn 36pt.
- **A gesture always has a single-pointer twin.** Pinch has a double tap (`PhotoViewer` 894/932), satisfying WCAG 2.5.1, and paging stops while zoomed so a pan never flicks the deck.
- **The stage never moves for data.** `dateHeight` is a constant band, so a geocode arriving does not resize the photograph.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| — | None | | | | | |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | WCAG 4.1.2 role/state | A11y | `Filmstrip` card, `.onTapGesture { select(photo) }` | Each thumbnail had a name and no role or state: VoiceOver did not say it could be pressed or which one was on the stage. | S | **FIXED.** `.isButton`, plus `.isSelected` on the current one. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 2 | Check 11b (exempt) | Visual | gaps 46.7 / 57.3 / 60.3 | Nothing on the page groups, because the 60.3 is letterbox. The written exemption in `docs/screen-audit.md` holds; recorded so it is seen. | — | None. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | H1 | UX | header title for an untitled photo | An untitled photograph's header is blank, which is correct ("a block with no name shows no text"), but the filmstrip's VoiceOver name falls back to "Photo" with no date. | S | Not changed. |
| 5 | 2.1.2 escape | A11y | `PhotoViewer` body | The two-finger scrub did nothing; the only way out under VoiceOver was finding the close button. | S | **FIXED.** `.accessibilityAction(.escape) { onClose() }`. |
| 4 | Motion | Motion | `photoTitleFade` on every page turn | The title fades between photographs on a page turn that already moves the picture; a turn is two motions on one subject. Small and purposeful (it marks the change), kept. | — | None. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Open from the thumbnail | continuity | system zoom | system | none (`navigationTransition(.zoom)`) | — | — |
| b | Page turn / strip scrub | feedback, orientation | paging + `motionSnappy` | spring token | none | — | — |
| c | Title / caption fade | orientation | `photoTitleFade`, `crossFade` | ease | #4 | P3 | — |
| d | Late full-resolution decode | continuity | preview, then the original | crossfade | none | — | — |

**Motion a11y:** Reduce Motion is the system zoom's own; nothing here loops. **Overall:** Purposeful.

**Translated:** Full Keyboard Access reaches close, actions and the strip; there is no skip link concept on one full-screen cover. WCAG 2.1.2 "no keyboard trap" maps to VoiceOver's two-finger scrub, which closes a full-screen cover everywhere else in iOS and was not wired here (#5).

---
### Summary
The viewer was never broken; it had never been photographed, and the most likely reason is a capture racing a test run on the same simulator. Looked at, it is one of the strongest screens in the app: a print on black, every ratio clear, a deletion dialog that says what it will not do. The one real defect was that the filmstrip's thumbnails were invisible as buttons to VoiceOver, and that is fixed.

**Morning pass, 2026-10-02:** #3 FIXED: the filmstrip names a photograph with its day (`GalleryPhoto.spokenName`).
