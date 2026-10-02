## Design Review — Settings (top, Camera, Data and below)
**Maturity level:** L2 (`docs/design.md`, the system in code, the atomic-kit table as the checklist).
**Sub-agents run:** Visual Quality Inspector, UX Critic, A11y Auditor, DS Compliance Checker, Motion Reviewer
**Total findings, before:** 7 (P0: 2, P1: 1, P2: 1, P3: 3)
**After this pass:** 4 open (P0: 0, P1: 0, P2: 1, P3: 3)

Captured 2026-10-02 on Strata-E, light and dark: `-strataOpenSheet settings`, plus `-strataScrollSettings camera` and `data` for the lower sections (about 1,500pt of Form; the footers under Camera, Data and Privacy are only on the lower captures).

---

### What's working (≥3)
- **One ink, one red.** Every row label `inkPrimary` (**14.84:1** on the white card), glyphs `inkSecondary`, the destructive row `AppColors.destructiveInk` on glyph and word alike. No blue anywhere, which is the LOCKED accent rule.
- **Rows measure 44.65pt**, from `SettingsIcon`'s 32pt frame, and every row has a glyph so the text column holds at one inset.
- **Section labels are `FormSectionLabel`**, one component, uppercase kerned `sectionLabel` in `inkSecondary`; cards start at 16.0 and labels at the row-content inset, which is the platform's own layout (check 11d's written note).
- **The two destructive paths say what they keep.** Restore's footer answers "will restoring wipe what I have now" before the row is pressed, and Reset has a confirmation.

### P0 — Blockers
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 1 | WCAG 1.4.3 + LOCKED 15pt floor `[cross-dim]`, **recurring → systemic** | A11y, DS | every `footer:` on Settings (4) and Profile (2) | A bare `Text` in a grouped Form's footer is `.footnote` in `.secondary`: **13pt at 3.36:1** (rgb 134 on 246, under Data). Under the owner's locked floor ("no tiny thin font anywhere") and under 4.5, on six sentences, including the one LOCKED sentence that sells the product. No capture had reached the footers until `-strataScrollSettings` existed. | S | **FIXED, one DS fix instead of six:** `FormFooterStyle` / `.formFooter()` beside `FormSectionLabel` in `SettingsView.swift`: `screenSubtitle` (15, body weight) in `inkTertiary`. After: **15pt, 4.72:1** (rgb 110 on 246) light; dark was 5.96 at 13pt and is now 15pt in the same ink family. The Data footer now wraps to four lines rather than three. |
| 2 | WCAG 1.4.3 | A11y | version plate under the mark | "1.0 (34)" in `inkQuiet`: **3.32:1** (rgb 135 on 246). It is text a person reads into a support email; `inkQuiet` is held to 3:1 because it is for glyphs. | S | **FIXED.** `inkTertiary`. After: **4.72:1**. |

### P1 — Major
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 3 | H9 recovery, H4 `[cross-dim]` copy, **recurring → systemic** | UX | 7 strings here, 14 more across the map, Restore, Privacy, the head maker and onboarding | The app is **Sturdy** on the home screen, in the Settings app and in all three permission prompts (`docs/brand.md`, 2026-09-30), and its own sentences said **Strata**. The worst one is an instruction that cannot be followed: "Location is off for **Strata** in the Settings app" sends somebody to look for an entry that is not there. Also "How Strata Works", the privacy footer's second sentence, and three error messages. | S | **FIXED in every file of mine** (21 strings, pinned by `DesignReviewMemoriesSideTests.noOldName`). Not mine and still saying Strata: `SharedModelContainer.swift:352/360/363` (the store-failure title and its recovery line), `BackupArchive.swift` 153-268 (nine backup errors, which surface on THIS screen's alerts), `BackupRestore.swift` 113/287/360, `BackupExport.swift:22` (the backup's file name, "Strata Backup …"), `ImageManager+Restore.swift:57`, `MainAppView.swift:34`, `StrataMark.swift:292` (the mark's VoiceOver label). `docs/privacy.html` (the published policy) also still says Strata. |

### P2 — Minor
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 4 | Contrast, switch off state | A11y | `SwitchTrack` off | The off track against the white card is the system's own relationship (a pale grey track, white thumb); it is 1.4.11's weakest pair on the page and the same as iOS Settings. | — | Not changed; matches the platform. |

### P3 — Cosmetic
| # | Category | Sub-Agent | Location | Issue | Effort | Fix |
|---|---|---|---|---|---|---|
| 5 | Scroll edge | Visual | section labels scrolled under the bar ("…MERA", "…TA") | A label half under the sheet's title band reads as a fragment for a frame. iOS 26's soft edge; system behaviour. | — | None. |
| 6 | DEBUG section | — | "Debug / Reset All Data" | DEBUG builds only; not shipped. | — | None. |
| 7 | H10 | UX | "How Sturdy Works" | Replays onboarding; the row's name is the only hint. Fine. | — | None. |

### LOCKED items the review flagged, not changed
| Flag | What the review would say | Register |
|---|---|---|
| "Everything you log stays on this device" | H8 / copy audit: Explanation, said again one tap away in the policy | owner, 2026-10-01: the one sentence that sells the product's spine. **Kept word for word.** Its second sentence's app name was corrected to Sturdy (#3) and it now sets at 15 (#1); neither touches the decision. |

### Motion review
| # | Animation | Purpose | Timing | Easing | Issue | Severity | Fix |
|---|---|---|---|---|---|---|---|
| a | Notification footer reveal | feedback | `gentleReveal`, none under Reduce Motion | token | none | — | — |
| b | Switches | feedback | system | system | none | — | — |

**Motion a11y:** Yes. **Overall:** Purposeful (almost none, correctly).

**Translated:** VoiceOver order is the Form's own; every glyph is decorative beside its label. "Skip links" has no meaning on a sheet.

---
### Summary
Settings is the platform's own layout done carefully, and its failures were all in the parts the audit had never captured: six footers at 13pt and 3.36:1, which one modifier now fixes everywhere, and an app that called itself by its old name, including in the one instruction that sends somebody to another app to find it. Both are fixed; the privacy sentence is unchanged.
