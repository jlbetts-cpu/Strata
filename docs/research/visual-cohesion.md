# Strata: one object, spoken in the owner's type

Research and build plan, 2026-09-16. Read against
`/Users/jaydenbetts/StrataWork/owner-head` at `b252e01` (clean worktree).
Nothing was edited, built or run. Line numbers are from that commit.

The owner's words this answers:

> "how we can make the app feel more visually cohesive. I think our camera is
> very strong looking, the app is very clean and nice, yet I feel like a couple
> things should be added to elevate the app to become more unified and pretty."

and, re-centring it:

> "center it around the text we have, the custom text, that's the
> differentiator of our brand. Making everything more clean: the shadows, the
> identity. Making every page feel like a premium experience, keeping UX in
> mind and pushing the limits of what we can do with this concept, making it
> the most stunning experience someone could find on their phone, running at
> lightspeed speed and performance."

---

## Summary (ten lines)

1. The camera is strong because it has **one ground, one ink scale, one drawn word, one object (the shutter is a block) and nothing else**: every other screen speaks through SF Pro in places where the owner's own lettering could.
2. The owner's type is the spine. Today it appears in **6 places as drawn words** (camera, head maker, onboarding, Memories map, Memories page, Settings) and **9 places as numerals**; **6 titles** (Profile, Settings, Plan, Add a win, Line, Privacy) and **the tab bar** still fall back to system SF Pro *Semibold*, which is a second family and a third weight.
3. Rule: **drawn lettering names things, the owner's numerals state counts, SF Pro Rounded says everything else.** One drawn word per screen, on the header line, in ink, never on a photograph without the wash.
4. The fonts can only do so much: `StrataNumerals.ttf` has **10 digits and a space** (2,220 bytes); the drawings cover **10 lowercase letters and 2 capitals**. Commission 7 words now as SVGs; decide on a full display alphabet after seeing them.
5. Shadow rule: **a shadow means a block is standing on something; everything else separates by hairline, translucency or a veil.** 27 shadow sites audited: 5 stay, 9 unify into one halo token, 13 go or change.
6. The biggest hidden shadow is **Liquid Glass on the flat page**, which draws its own soft shadow in light mode and a hairline in dark (measured on `owner-shots/v4`): chrome looks like two materials depending on the phone's setting.
7. Additions, ranked: (1) the type spine finished, (2) the count lands with the block, (3) one ghost-block empty state, (4) the launch opens on the ground, (5) the shutter wears the block's lit rim.
8. Rejected as decoration or cost: grain, time-of-day colour, a tab-switch transition, custom tab glyphs, a mascot.
9. Seventeen inconsistencies ranked, the top four: system-font titles, glass shadow on flat ground, cool system form rows on the warm dark ground, and a second depth shadow on tower blocks only.
10. Speed: delete the unused 145,616-byte `Jaro.ttf`, remove one offscreen shadow pass per tower block, cap glass at 3 per screen, and add nothing that draws per frame.

---

## 1. Why the camera feels strongest

### 1.1 Its visual language, element by element

| Quality | What the camera does | Where |
|---|---|---|
| **Ground** | One fixed near-black, `(8,8,8)`, whatever the phone is set to. The window is pinned dark on this tab so the tab bar goes white with it. | `CameraView.swift:261`, `MainAppView.swift:299-301` |
| **The photograph is the hero** | The preview fills the screen edge to edge; the only shape is its rounded bottom where it stops above the tab bar (radius 34). Review shows the shot edge to edge, not as an inset card. | `CameraView.swift:178`, `:262-274`, `:362-378` |
| **Contrast and ink** | Three white inks and a hairline, and nothing else: `onDarkStrong 0.95`, `onDarkSecondary 0.75`, `onDarkQuiet 0.55`, `onDarkFaint 0.14`. Selected size word is strong, the others quiet. | `CategoryColors.swift:243-246`, `CameraView.swift:491` |
| **Type** | One drawn word, the owner's `Strata`, at cap 32, sitting inside a break cut exactly to its height in the first composition line. The countdown is the owner's numerals at 96. The review's two actions are plain words. | `CameraView.swift:128-176`, `:236`, `:414-446` |
| **Composition** | 1pt integer guides at true thirds, one colour, faded out before they reach the tab bar. The wordmark is sized so it crosses the first vertical and stops 44pt short of the second. | `CameraView.swift:98-121`, `:731-741` |
| **Iconography** | Bare glyphs, 21pt regular, no containers. Off is *dimmed*, not slashed, the same way for grid, flash and timer. | `CameraView.swift:995-1022` |
| **The one object** | The shutter is a block: the block's 14.7% corner, a rim and a fill, and it *becomes* the 2x1 or 2x2 you drag out. The four settings step out of the way while you draw. | `CameraView.swift:1042-1083`, `:860` |
| **Material** | Glass appears only where it is a control over an image: the size chooser on review, the zoom pill. | `CameraView.swift:505`, `:935`, `:1391` |
| **Motion** | Shutter press 0.08s ease-out to 0.86, spring back 0.28/0.6; the reticle contracts onto the point; the zoom pill grows out of the shutter's line. | `CameraView.swift:1248-1251`, `:658`, `:939` |
| **Light** | The front flash is a warm 3400K ring, not white, and it owns screen brightness while armed. | `WarmRingLight.swift:12-41`, `CameraView.swift:1181-1195` |
| **Haptics** | tick on focus and every setting, snap on fire and flip, success when the frame arrives. | `CameraView.swift:606`, `:672`, `:1246`, `:1283` |
| **Sound** | None of its own. The system capture sound is the only sound (no cue in `SoundEngine.Cue` is camera related). | `SoundEngine.swift:69-74` |

### 1.2 The principle underneath

The camera is strong for a reason that is about *count*, not style: **it has one of
each thing.** One ground. One ink family. One drawn word. One object. One
material, used only where it earns it. Its composition lines exist to hold the
word. Nothing on it is there to separate one piece of chrome from another,
because there is almost no chrome to separate.

### 1.3 What the rest of the app dilutes

| Camera quality | Where it is diluted | Evidence |
|---|---|---|
| One family of type, owner-drawn at the top | Six screens title themselves in system SF Pro Semibold through `navigationTitle`, and the tab bar labels are SF Pro. No `UINavigationBarAppearance` or tab item font is set anywhere. | `AddWinSheet.swift:143`, `ProfileView.swift:62`, `SettingsView.swift:413`, `PlanSheet.swift:49`, `PlanItemDetailSheet.swift:64`, `PrivacyPolicyView.swift:37`; grep for `UINavigationBarAppearance` returns nothing |
| One ground | Form screens put system `secondarySystemGroupedBackground` rows (cool `#1C1C1E` in dark) on a warm charcoal ground that runs `#21201E` to `#181716`, so the rows are darker than the page at the top and lighter at the bottom. | `WarmBackground.swift:47-59`; no `listRowBackground` except two clear header rows (`SettingsView.swift:107`, `ProfileView.swift:125`) |
| One material, only over images | Glass capsules and circles sit on the flat page (tower header, Memories page header, replay), where there is nothing to refract, so Liquid Glass draws a soft shadow instead. | `MainAppView.swift:882`, `:896`; `MemoriesView.swift:531`; `ReplayView.swift:108`, `:303`, `:499`; visible in `owner-shots/v4/d-wk-light.png` |
| One object | The tower's blocks carry two shadows; month, replay and map blocks carry one. | `BlockChrome.swift:129` plus `MainAppView.swift:3007-3012` |
| One glyph voice | Camera glyphs are 21 regular; glass buttons 17 medium; Settings 13 medium; profile glyph body medium. | `CameraView.swift:1006`, `GlassIconButton.swift:60`, `SettingsView.swift:616`, `ProfileAvatar.swift:89` |

---

## 2. The typographic identity (the spine)

### 2.1 Inventory: every piece of the owner's lettering, and where it is

**The fonts and drawings that exist**

| Asset | What it is | Glyphs | Ships? | Size |
|---|---|---|---|---|
| `Shared/StrataNumerals.ttf` | The owner's digits as a TrueType font, metrically matched to SF Pro Rounded (2048 upem, cap 1443), tabular, advance 0.947 em | `0-9` and space. Nothing else: no `.` `,` `:` `/` `-` `x` `%` | Yes, app and widget (`Info.plist` `UIAppFonts`, `WidgetSupport/Info.plist`) | 2,220 bytes |
| `StrataWordmark.imageset/Strata.svg` | `Strata`, 182x28 | S t r a | Yes | vector |
| `MemoriesTitle.imageset/Memories.svg` | `Memories`, 216x28 | M e m o r i s | Yes | vector |
| `StrataSMark.imageset/StrataS.svg` | The `S` mark, 38x40 | S | Yes (and the app icon) | vector |
| `brand/wins-owner.svg`, `brand/win-owner.svg` | `wins`, `win` on the 28-unit body | w i n s | **No** (settled: the header word stays SF, CLAUDE.md "The tower header's word") | vector |
| `Strata/Resources/Jaro.ttf` | Jaro display face | 1,043 glyphs | **Registered at launch and used nowhere** (`JaroFont` has zero call sites) | **145,616 bytes** |

Letters the owner has already drawn, across every drawing: lowercase
**a e i m n o r s t w** (10 of 26), capitals **S M**. Enough for no new screen
title: `Profile` needs P f l, `Settings` needs g, `Plan` needs P l.

**Where the drawn words appear**

| Screen | Drawn word | File:line |
|---|---|---|
| Camera | `Strata`, white, cap 32, in the guide break | `CameraView.swift:758` |
| Head maker | `Strata`, white, cap 32 | `HeadMakerView.swift:197` |
| Onboarding, every page but the camera | `Strata`, cap 32, ink or white | `OnboardingView.swift:60` |
| Memories map | `Memories`, ink on the pale map, white on imagery | `MemoriesView.swift:445` |
| Memories page (drawer) | `Memories`, ink | `MemoriesView.swift:513` |
| Settings header | S mark 72 + `Strata` cap 30 | `SettingsView.swift:93-95` |

**Where the numerals appear**

| Place | Size | File:line |
|---|---|---|
| Tower tally | 34 relative to largeTitle, rolls with `.numericText()` | `MainAppView.swift:820-828` |
| Replay close count | tally | `ReplayFrame.swift:250` |
| Replay running label (month: the day number) | 34 | `ReplayFrame.swift:131` |
| Month tower day numeral | `cell * 0.16` | `MonthTowerView.swift:96` |
| Map cluster badge | 13 | `MemoriesMapView.swift:1086` |
| Profile streak figures | 28 relative to title, rolls | `ProfileView.swift:260-262` |
| Camera countdown | 96 | `CameraView.swift:236` |
| Camera timer digit | 10 | `CameraView.swift:971` |
| Widget, home and lock screen | 30 and 16 | `Shared/TowerWidgetView.swift:130`, `:167` |

**Where the brand could speak and SF Pro speaks instead**

| Place | Today | Could be |
|---|---|---|
| Sheet and pushed titles: Profile, Settings, Plan, Add a win / Edit, Line, Privacy | System inline title: SF Pro **Semibold** 17 | Drawn word (phase 1 list below), or at minimum SF Pro Rounded Medium |
| Tab bar labels Wins, Camera, Memories | SF Pro (system) | SF Pro Rounded Medium via `UITabBarItem` appearance. Not drawn: 10pt labels are below the drawing's working size |
| Day album title, e.g. "Saturday 5 September" | SF Rounded 34 medium | Drawn only with a full alphabet (dynamic string) |
| Place collection title (a place name) | SF Rounded 34 medium | Drawn only with an alphabet that covers the name; fall back otherwise |
| Replay header "Your week 9/14-9/20" | SF Rounded | `Your week` / `Your month` drawn; the dates need `/` and `-` in the numerals |
| Zoom pill "2.4x" | SF monospaced digits | Numerals, once `.` and `x` exist |
| Widget word "wins" | SF Rounded **Semibold** 13 and 15 (`TowerWidgetView.swift:133`, `:169`) | SF Rounded Medium: a third weight today |
| Profile chart axis and headline | SF Rounded | Stay SF: numbers inside a sentence, and 11pt axis labels at a 0.947 em advance would not fit |
| Share still (`ShareTowerCard`) | No type at all, deliberately | Stay: no watermark is a settled, argued decision (`ShareTowerCard.swift:25-28`) |
| Notifications | System | Cannot carry custom fonts; nothing to do |

### 2.2 The system: three voices and who gets which

**Voice 1: drawn lettering. It NAMES.** The product (`Strata`) and the screen
you are on. Never a caption, a button, a sentence or a count. This is the same
line the owner already drew when he kept "wins" in SF: the count is the fact,
the word beside it is a caption, and captions are not drawn.

**Voice 2: the owner's numerals. They STATE.** Any number that stands alone as
a fact about your record or a coordinate: counts, streaks, day numbers,
badges, the countdown. Not a number inside a sentence ("12 wins this week"
stays SF), not a unit, not an axis label.

**Voice 3: SF Pro Rounded, regular and medium. It SAYS everything else.**
Body, captions, buttons, section labels, sentences, form rows.

### 2.3 Hierarchy and scale

Everything below is already true somewhere in the app; the table only makes
it the rule.

| Rung | Voice | Size | Ink | Where |
|---|---|---|---|---|
| Cover wordmark | drawn | cap **32** | white on image, `inkPrimary` on page | Camera, head maker, onboarding |
| Screen title | drawn (SF fallback) | cap **23.96** = `Typography.screenTitleCap`, the cap of SF 34 | `inkPrimary` | Memories, and every title in §2.5 |
| Tally | numerals | **34** em, same cap line as the title | `inkPrimary` | Tower, replay close |
| Figure | numerals | **28** relative to `.title` | `inkPrimary` | Profile streaks |
| Subtitle / caption word | SF Rounded regular | 15 (`screenSubtitle`) | `inkQuiet` | "wins", dates under titles |
| Section label | SF Rounded medium, uppercase, +0.8 | 13 (`sectionLabel`) | `inkSecondary` | `SectionHeading` |
| Coordinate / badge | numerals | 13 to `cell * 0.16`, **floor 10** | white 0.9 on block, `warmBlack` on badge | Month blocks, map badge, timer |

**Tracking and leading.** Drawn words have none to set: spacing is in the
drawing, and it must never be scaled on one axis. Numerals are tabular and
must never be kerned or given `.monospacedDigit()` (they already are; the map
badge's `.monospacedDigit()` at `MemoriesMapView.swift:1099` does nothing to a
custom face and can go). SF keeps the system's size-specific tracking except
the section label's +0.8.

**Alignment.** Numerals start at `-tallyOpticalInset` so their ink meets the
margin (`GridConstants.swift:132`); drawn titles use
`headerArtworkTopPadding`, top alignment, and a hand offset for the 44pt
button beside them (CLAUDE.md, "A drawn header is not type"). Both are solved
problems; new titles copy `MemoriesView.titleRow`.

### 2.4 The numerals in motion

The digits are the one piece of the brand that moves, so their motion is a
signature and should be one behaviour:

- **A count changes on the event, not on the tap.** The tally should roll on
  the frame the block lands, the frame `SoundEngine.blockImpact` and
  `HapticsEngine.squish` fire (`MainAppView.swift:1715`). Type, sound and touch
  on one frame is `apple-design.md` §13's harmony rule, and it turns the three
  into one event. See addition 2.
- **Roll, never crossfade.** `.contentTransition(.numericText())` everywhere a
  standalone count changes (tower, profile already do). It works on this font
  because it is TrueType; do not rebuild it as CFF (CLAUDE.md records the clip).
- **In a replay the count is a function of `t`.** No `withAnimation`: the close
  count, if it counts, is `ReplayScript` state, so the video matches.
- **The countdown scales out, 1.25 to 1, on opacity.** Already the case
  (`CameraView.swift:239`); it is the one place a numeral may scale.
- **Reduce Motion:** the digit swaps with no roll.

### 2.5 What to commission from the owner

**Phase 1: seven words as SVGs, same pipeline as `Memories`**
(`tools/flatten_svg.py`, template imageset, `preserves-vector-representation`,
a `DrawnLettering` wrapper):

1. `Profile`
2. `Settings`
3. `Plan`
4. `Add a win`
5. `Edit`
6. `Your week`
7. `Your month`

New letterforms needed for those, beyond the 12 already drawn: **P f l g d
Y u k h A E c** (12 glyphs), which is about half an alphabet. Sheets keep their
toolbar (Done, Cancel) and hide only the inline title, drawing the word on the
header line instead, so the screen still has one title line
(`research-screen-control.md` §2.2 rule 1). Needs the owner's eye: this changes
what every sheet looks like.

**Phase 2, only if phase 1 lands: a display alphabet as a font,
`StrataDisplay.ttf`**, generated the way `make_numeral_font.py` builds the
numerals. It is what makes the most-read titles possible, because they are
dynamic: a day ("Saturday 5 September"), a month in the picker, a place name.

- Glyphs: A-Z, a-z, the ten existing digits, space, `. , ' - / : & ( )`,
  about 70. Add the Latin-1 accented letters (about 60 more) before any place
  name uses it, or `Café` renders a `.notdef` box.
- **A coverage check is mandatory**, `StrataDisplay.covers(_ string:) -> Bool`
  against the font's cmap, falling back to `Typography.screenTitle` for any
  string it cannot set. Same failure the numerals already guard with
  `StrataNumerals.digits(_:)`.
- A font is better than more SVGs once there are more than about ten words:
  it is real text to VoiceOver, it scales with Dynamic Type through
  `relativeTo:`, it can roll, and one file replaces an imageset per word.

**Glyphs worth adding to the numerals now**, because each unlocks a number the
app already states in SF: `.` and `x` (zoom pill), `/` and `-` (replay dates),
`:` (the reminder time, if ever shown large). Keep `%` and `+` out until
something needs them.

### 2.6 The rules that stop it becoming decoration

1. **One drawn word per screen.** The camera is the proof: one word, and the
   composition holds it. Settings is the only screen with mark + wordmark, and
   that is its purpose.
2. **Drawn lettering is ink.** `inkPrimary`, or white where the ground is an
   image. Never a category colour: pink is a block's claim (the owner's own
   reasoning for the black tally, `MainAppView.swift:822-826`).
3. **Never on a photograph without the wash.** The Memories title over imagery
   gets its 0.28 `warmBlack` gradient (`MemoriesView.swift:124-137`); the camera
   is the one halo exception because its ground is live.
4. **Not below cap 17** for drawn words. The monoline closes up; the tab bar
   and toolbar buttons stay SF. Verify the floor with one shot per phase 1 word
   at xSmall Dynamic Type.
5. **Numerals: floor 10pt**, and only where the number is alone.
6. **No drawn word inside a scroll that moves under chrome.** Titles are on the
   header line, which does not scroll away mid-read.

### 2.7 UX checks for the spine

| Check | Rule | Status today |
|---|---|---|
| **VoiceOver** | Drawn words carry `accessibilityLabel` and `.isHeader`. | Label yes (`StrataMark.swift:146`); **header trait missing** on `MemoriesTitle` and any drawn title. One-line fix in `DrawnLettering`. |
| **Dynamic Type** | Drawings use `@ScaledMetric` relative to `.largeTitle`; numerals use `relativeTo:`. | Yes (`StrataMark.swift:108-117`, `Typography.swift:100`). Camera, head maker and onboarding clamp to 32 by design. |
| **Bold Text** | A drawing cannot thicken. Accept for titles (already large, already medium weight); do not extend drawn words to anything under 17 cap. | n/a |
| **Increase Contrast** | Ink tokens already meet 4.5:1; drawn words take `inkPrimary` (14.3:1 light, 13.9:1 dark). | Yes |
| **Localisation** | Drawn words are English-only; the app is English-only. A phase 2 font must fall back per string. | n/a |
| **Legibility over images** | Wash or veil, never a bare drawn word. | Yes |

### 2.8 Performance of the spine

| Asset | Cost | Budget |
|---|---|---|
| Numerals font | 2,220 bytes, CoreText glyph cache, same cost as system text | stays |
| Drawn SVG word | Rasterised once per size by UIKit and cached; a 216x28 word at 3x is about 648x84px, 0.2 MB RGBA | at most **8 SVG words** before moving to a font |
| `StrataDisplay.ttf` (phase 2) | Estimated 15 to 30 KB for 130 glyphs of this simplicity (the 10-glyph numeral font is 2.2 KB) | **64 KB for all custom fonts** |
| `Jaro.ttf` | 145,616 bytes, registered at every launch, drawn nowhere | **delete** it, `JaroFont`, and the `UIAppFonts` entry |
| Animating a drawn word | Animate `scaleEffect`/`opacity`, never its frame, or it re-rasterises every frame | rule |
| `.numericText()` | Per glyph, cheap; apply to the count `Text` only, not the header stack | rule |

---

## 3. Shadows and depth: one rule

> **A shadow says a block is standing on something. Blocks, a lifted block,
> a falling block and the head's contact shadow cast one; everything else
> separates by hairline, translucency or a veil.**

Type over a *live* image (camera, head maker) is the one place a halo is
allowed, as a single token, because nothing else can guarantee legibility on
a viewfinder. `research-motion-layering.md` #9 proposes replacing those halos
with glass; that remains the owner's call with a pair of frames.

### 3.1 Every shadow in the code, and its verdict

| # | File:line | What | Values | Verdict |
|---|---|---|---|---|
| 1 | `BlockChrome.swift:129` | Every `BlockSurface` | 0.07, r7, y2 | **Stays.** Note `blockShadowOpacityDark` 0.20 (`GridConstants.swift:651`) is defined, documented in `design-system.md` as the dark value, and unused. Measure dark mode with and without, then either use it or delete it. |
| 2 | `MergedGroupView.swift:89` | Merged run | same, scaled | **Stays.** |
| 3 | `MainAppView.swift:3007-3012` | A *second* "depth" shadow on every tower block, growing with row | 0.04, r4+row*0.2, y2+row*0.1 | **Goes.** No other block surface has it, so the tower's blocks are heavier than the same block in a month, replay or on the map, and it costs one offscreen pass per block. Measure first (§8). |
| 4 | `MainAppView.swift:3064` | Landing shadow while a block drops | adaptive 0.12 | **Stays.** Information: in flight. |
| 5 | `FlippableBlockView.swift:115` | Lifted block | 0.22, r16, y10 | **Stays.** Information: off the surface. |
| 6 | `HeadMarker.swift:35-40` | Head's contact ellipse on the map | 0.26 blurred | **Stays.** The head standing on the map. |
| 7 | `MainAppView.swift:3265` | `FlyawayBlockView` mini block | 0.15 r4 | **Goes, with the view.** `flyawayActive` is never set true anywhere; it is a Today-tab bridge to a tab that no longer exists. |
| 8 | `MemoriesDrawer.swift:90-91` | The drawer panel | `shadowOpacity` 0.10, r12, y-2 | **Changes** to a 0.5pt `fillHairline` along the top edge. The drawer is ground sliding over ground; its own comment says "a shadow is not a rim", but it is still elevation on chrome. |
| 9 | `OnboardingView.swift:384` | Creator portrait circle | 0.10, r14, y6 | **Goes.** The 1pt hairline stroke on the line above already separates it. |
| 10 | Liquid Glass on the flat page: `MainAppView.swift:882` (replay pill), `:896` (Plan), `MemoriesView.swift:531` (Done), `ReplayView.swift:108`, `:303`, `:499` | Glass draws its own shadow when nothing is behind it | visible halo in `owner-shots/v4/d-wk-light.png`; a hairline, no halo, in `d-wk-dark.png` | **Changes** (§4.2). |
| 11 | `BlockContent.swift:99` | Title on a photo block | 0.55, r3, y1 | **Measure, then change.** The veil (0.26) is the rule for type on photographs. Keep this only if the veil alone fails 4.5:1 on the 95th-percentile bright photo; if kept, it becomes the halo token. |
| 12 | `MonthTowerView.swift:105` | Day numeral on a photo | 0.45, r3, y1 | Same as #11. |
| 13 | `Shared/TowerWidgetView.swift:136` | Widget count on a photo | 0.35, r4, y1 | **Changes** to a bottom veil gradient at `photoVeilOpacity`, the block's own rule. |
| 14-18 | `CameraView.swift:238` (countdown 0.35 r14), `:760` (wordmark 0.40 r10), `:973` (timer digit 0.35 r4), `:1014` (glyphs 0.35 r6), `:1373` (sun 0.35 r3) | Halos over the live viewfinder | five values | **Unify** into one token, `GridConstants.liveHalo`: black 0.35, radius `0.3 * cap height`, y1. Same look, one number. Owner's eye because it touches the camera. |
| 19-22 | `HeadMakerView.swift:198`, `:217`, `:284`, `:345` | Same, head maker | 0.35 to 0.40 | **Unify** with 14-18. |
| - | `NextSlotButton.swift:139-142` | White glow under the pressed slot | blur 6*glow | Not a shadow: press light. Stays. |
| - | `WarmRingLight.swift:82` | Ring light blur | 28 | Light, not depth. Stays. |

Count, 27 sites: **5 stay, 9 unify to a token, 13 change or go** (rows 3, 7, 8, 9, the six glass sites of row 10, 11, 12, 13).

### 3.2 Depth without shadows

- **Hairline:** `fillHairline` (primary 0.08) at 0.5pt, `GridConstants.headerDividerHeight`. The one line weight for chrome edges.
- **Translucency:** glass, only over an image (§4.2).
- **Veil:** `photoVeilOpacity` 0.26 under type on a photograph.
- **The rim's light belongs to blocks.** A top-lit white edge says "you built this"; chrome never gets it (CLAUDE.md, "The blocks are the identity; chrome is not").

---

## 4. The unifying system

Five shared elements. Each is a rule, where it applies, what changes, and why
it adds unity without adding things.

### 4.1 One ground

**Rule.** Two grounds and only two. The **page**: `WarmBackground` (cool
`#F6F7F9` to `#F1F4F6` light; warm `#21201E` to `#181716` dark). The **image**:
the viewfinder `(8,8,8)`, the viewer's black, the map. Every surface in the
app is one of them, and anything placed ON the page takes a surface token
derived from it, not a system colour.

**Changes.**
- Form rows (Settings, Profile, Add a win, Plan detail): `listRowBackground(AppColors.rowFill)`, a new *surface* token: light `#FFFFFF`, dark `WarmBackground.top` lifted about 6 units (`rgb(0.165, 0.160, 0.152)`). Replaces system `secondarySystemGroupedBackground`, which is cool and sits darker than the top of the dark page. Measure (§8) before choosing the dark value.
- The viewfinder black is written twice as a literal (`CameraView.swift:261`, `HeadMakerView.swift:30`). Name it `AppColors.imageGround`.
- Launch screen colour (addition 4).

**Why it unifies.** A warm dark page with cool dark cards on it is two apps.
One family of greys is most of what makes Things or Flighty feel like one object.

### 4.2 One material for floating chrome

**Rule.** *Glass over an image, a hairline capsule on the page.*
- Over the viewfinder, the map, a photograph or the replay's tower: `glassCircle()` / `glassCapsule()`, unchanged.
- On the flat page (tower header, drawer header, sheets): the same 44pt shape with `quietFill` and a 0.5pt `fillHairline` border. No glass, so no glass shadow, and it looks the same in light and dark.

**Changes.**
- `GlassIconButton` and `glassCapsule()` gain a `ground: .image | .page` parameter, default `.image`. Page callers: `MainAppView.swift:882`, `:896`; `MemoriesView.swift:531`. The replay (`ReplayView.swift:108`, `:303`, `:499`) is a page with a tower on it; measure both there.
- Collapse the two private copies, `zoomGlass()` (`CameraView.swift:1391`) and `mapPrimeGlass()` (`MemoriesMapView.swift:1117`), into `glassCapsule()`; their pre-26 fallback lacks the 0.5pt hairline the shared one has.
- The map's permission button puts a white filled capsule *inside* glass (`MemoriesMapView.swift:552-557`): two materials on one control. Keep the fill, drop the glass.
- Budget: **at most 3 glass elements per screen**, wrapped in one `GlassEffectContainer` where they sit together. The map header already has 3 (title row buttons 2, recentre 1).

**Why.** This is subtraction: it removes a shadow the app never chose and
makes chrome one thing in both appearances. Needs the owner's eye: the tower's
Plan button stops being glass.

### 4.3 One glyph voice

**Rule.** SF Symbols only (settled). **Medium weight next to medium type,
regular only on the camera family**, three sizes by role:

| Role | Size | Weight | Tint |
|---|---|---|---|
| Control bar over an image (camera, head maker) | 21 | regular | white, dimmed 0.55 when off |
| Chrome button (44pt target) | 17 | medium | ink |
| Row glyph (Settings, forms) | 13 | medium | `inkSecondary` |

Filled = selected, outline = not, everywhere.

**Changes.**
- **The Memories tab never fills.** Wins and Camera switch to `.fill` when selected; Memories passes the hollow `StrataTab.memories.icon` in both states (`MainAppView.swift:612`). Use `selectedTab == .memories ? "photo.stack.fill" : "photo.stack"`.
- The camera's dimmed glyph is white 0.5 (`CameraView.swift:1013`), a fifth white outside the `onDark*` scale. Use `onDarkQuiet` (0.55).
- Tab bar labels to SF Pro Rounded Medium (one `UITabBarItem.appearance()` call).

**Why.** The camera's regular weight is part of what makes it feel like a
camera (iOS Camera is regular), so it keeps it as a family exception; the rest
of the app speaks medium, like its type.

### 4.4 One signature detail, repeated with restraint

**The block.** It already is the signature, and it has three echoes, each
earned: the shutter (the button that makes one), the mark (`StrataMark` draws
a real `BlockSurface`), and the empty slot. Two more exist and should be
recognised rather than added:

- **The owner's `0` is a rounded square.** In `owner-shots/sheet-loading-dark.png` the empty tower's tally reads as a block beside "wins". An empty count is literally an empty block. That is the ghost-block empty state (addition 3) already drawn by the owner.
- **The `S` mark and the icon should be the same object.** Today the icon is the S on flat `#1C1A18` with no rim (`tools/make_app_icon.py:58`) and `StrataMark` is the S on `warmBlack #403D39` with the white rim (`StrataMark.swift:232`), about 2.3x lighter. The code comment says "the same drawing on the same ground"; it is not. Pick one ground (the icon's darker one reads better on a home screen) and set `StrataMark` to it.

Do **not** add more echoes: no rim on cards, no block-shaped buttons, no
stacked ghosts (CLAUDE.md, "Do not stack translucent copies of a block").

### 4.5 One sound, one touch, one frame

**Rule.** The app has exactly one sound of its own: **a block landing**
(`SoundEngine.blockImpact`, pentatonic, mass and column shaped). The replay's
video carries the same buffers. Keep it that way. The other cues
(`completionTone`, `allClearChime`, `milestoneJingle`) have no call sites; delete
them or leave them silent, but do not attach UI clicks, tab sounds or a
shutter cue. The camera keeps the system capture sound.

Haptics already have a vocabulary (tick 31 sites, lightTap 40, snap 8,
success 10). The one rule to add: **the landing's sound, squish and the tally's
roll happen on one frame** (addition 2).

### 4.6 Transitions

Deliberately deferred to `research-motion-layering.md`, which already owns
press behaviour (`StrataPress`), the crossfade rule and layering bands. The one
cohesion point to add: **no tab-switch animation** (its V5, deferred until
capture C3). A tab switch that animates fights `TabView` and the pinned
colour-scheme swap, which is measured as instant on purpose
(`MainAppView.swift:620-647`).

---

## 5. What to add: five, ranked

Each is argued against "premium is subtraction". Every one replaces or removes
something.

### 1. Finish the type spine

**What.** Phase 1 drawn titles (§2.5) on the header line of Profile, Settings,
Plan, Add a win/Edit and the replay header, SF Pro Rounded Medium for the tab
bar and every remaining system title, `.isHeader` on drawn words, and
`.`/`x`/`/`/`-` in the numerals.

**Looks like.** Profile opens with `Profile` in the owner's hand, cap 23.96,
`inkPrimary`, at 18.8pt below the safe area, with `Done` as bare `headerSmall`
text centred on the cap. Same line and size as `Memories`. The sheet's
navigation bar is hidden; its toolbar item is not.

**Replaces.** Six system Semibold titles (a second family and a third weight),
the unused Jaro font (145.6 KB), the dead `brandLogo`/`brandHeader`/
`brandSubheader`/`brandHeroDate`/`brandCardTitle`/`appTitle`/`miniBlock*` tokens
(`Typography.swift:9-29`, zero call sites).

**Against subtraction.** It adds no element: every screen already has a title.
It changes whose voice the title is in. **Owner's eye: yes** (he draws it).

### 2. The count lands with the block

**What.** The tally's digit rolls on the landing frame, not on the tap. The
replay's close count is script-driven and reaches its number as the last block
lands. The map badge and profile streak roll the same way when they change.

**Looks like.** Hold the slot, let go: the block falls (0.34 to 0.72s by
gravity), hits, squishes, the impact tone plays, and "12" rolls to "13" in the
owner's digits on that frame.

**Replaces.** A count that changes before the thing it counts has arrived, a
small untruth about causality that `apple-design.md` §13 names.

**Against subtraction.** Zero new pixels; it moves an existing change to the
right moment. **Owner's eye: a film, not a still.**

### 3. One empty state, built from ghost blocks and the owner's zero

**What.** One `GhostBlocks` view: dashed `slotInk` 0.16 outlines on `slotInk`
0.035, packed as the month tower packs (`MemoriesView.swift:641-665` is the
reference), one medium line, one regular line. Used by: the Memories page
(already), the empty month (already, `ghostRow`), the map's no-places state
(today a `warmBlack` 0.55 scrim with text, `MemoriesMapView.swift:520-566`), the
widget's empty state (today a 30pt dashed square with radius 4,
`TowerWidgetView.swift:146-150`), and any empty replay shelf.

**Replaces.** Three designs for "nothing here yet" with one.

**Against subtraction.** Removes two bespoke empty states. It is the owner's
existing idea ("show the shape of what is missing") applied where it has not
reached. **Owner's eye: the map version**, because it puts outlines on imagery.

### 4. The launch opens on the ground

**What.** `UILaunchScreen` with `UIColorName` set to a new `Ground` colour
asset (light `#F6F7F9`, dark `#21201E`), no image. Today it is generated
(`project.pbxproj:571`, `:610`), which is system white or black; the
`sheet-loading-dark` frames show pure black before the charcoal page arrives.

**Looks like.** Nothing, which is the point: the icon zooms open onto the
exact colour the tower will stand on, and the tally arrives without a flash.

**Replaces.** A black-to-charcoal (or white-to-cool-grey) jump on every cold
launch. Apple's guidance is a launch screen that looks like the first screen,
not a splash, so no logo.

**Against subtraction.** A colour, no asset, zero runtime cost.
**Owner's eye: no.**

### 5. The shutter wears the block's lit rim

**What.** The shutter's rim (`CameraView.swift:1059-1061`, flat white 1pt)
takes `BlockSurface`'s rim gradient: white 1.0 along the top, `blockRimFalloff`
0.45 below 55%, same 1.4pt weight scaled to the shutter.

**Looks like.** The one block on the camera lit from above like the ones it
makes; at 80pt on black the top edge reads brighter than the sides, nothing
else changes.

**Replaces.** The last flat-rimmed block in the app.

**Against subtraction.** It is the camera, which the owner already loves, so
it ranks last and ships only with a side-by-side. **Owner's eye: yes.**

### Considered and rejected

| Idea | Why not |
|---|---|
| Grain or noise on the ground | Decoration for its own sake; a full-screen `Canvas` noise re-renders under scrolling; the ground's job is "make the blocks look clean and disappear" (`WarmBackground.swift:21-24`). |
| Colour temperature by time of day | The ground was chosen by rendering six candidates against the palette; shifting it moves every block's apparent colour, and colour is what a block IS. |
| A signature tab transition (the drop echoed) | Fights `TabView` and the instant scheme swap; a block dropping when you did not log a win claims something untrue. |
| Custom tab glyphs from the S or a block | SF Symbols only is settled; a second icon language on the one bar every screen shares. |
| Mascot (brand.md's "Ponorca") | The owner's head already is the character, optional and his; brand.md is stale on this and more (see §6 #17). |

---

## 6. Inconsistencies that break unity today, ranked

Checked against the code at `b252e01`; items settled in CLAUDE.md and items
already fixed are excluded.

| # | Where | What disagrees | Smallest fix |
|---|---|---|---|
| 1 | `AddWinSheet.swift:143`, `ProfileView.swift:62`, `SettingsView.swift:413`, `PlanSheet.swift:49`, `PlanItemDetailSheet.swift:64`, `PrivacyPolicyView.swift:37`; tab bar | Titles and tab labels in SF Pro Semibold: second family, third weight. | One `UINavigationBarAppearance` + `UITabBarItem.appearance()` with SF Rounded Medium at app start. Then addition 1. |
| 2 | `MainAppView.swift:882`, `:896`; `MemoriesView.swift:531`; `ReplayView.swift:108`, `:303`, `:499` | Glass on the flat page: a shadow in light mode, a hairline in dark. Measured on `owner-shots/v4`. | §4.2 `ground: .page`. |
| 3 | Form rows in Settings, Profile, Add a win, Plan detail | System `secondarySystemGroupedBackground`, cool, darker than the warm dark page at its top. | `listRowBackground(AppColors.rowFill)`. Measure first. |
| 4 | `MainAppView.swift:3007-3012` | Tower blocks cast two shadows; every other block one. | Delete the depth shadow. |
| 5 | `MemoriesDrawer.swift:90`; `OnboardingView.swift:384` | Shadows on chrome. | Hairline; delete. |
| 6 | `MemoriesView.swift:517-531` vs `SettingsView.swift:453`, `ProfileView.swift:613`, `AddWinSheet.swift:299` | "Done" is a glass capsule in `headerMedium` in one place and bare `headerSmall` accent text in three. | Bare `headerSmall` everywhere; the drawer is a full-screen page like a sheet. |
| 7 | `MainAppView.swift:612` | Memories tab icon never fills. | Switch on selection. |
| 8 | `StrataMark.swift:232` vs `tools/make_app_icon.py:58` | Mark ground `#403D39` with rim, icon ground `#1C1A18` flat; the comment says they match. | Set `StrataMark` to the icon's ground; decide the rim with a pair. |
| 9 | `project.pbxproj:571`, `:610` | Generated launch screen: system white/black before the page. | Addition 4. |
| 10 | `Assets.xcassets/AccentColor.colorset` | One value, `#403D39`, no dark appearance. Anything UIKit tints from the global accent (the pushed Settings back chevron, dialog buttons, `DatePicker`) can render warm black on the dark page, about 1.3:1. | Add a dark appearance equal to `accentWarm`'s (`0.98, 0.97, 0.96`). Screenshot the back chevron in dark first. |
| 11 | `Shared/TowerWidgetView.swift:133`, `:136`, `:169` | Widget type in Semibold (a third weight) and a text shadow. | Medium; veil (§3.1 #13). |
| 12 | `CameraView.swift:1391`, `MemoriesMapView.swift:1117` | Private glass copies without the shared fallback hairline. | `glassCapsule()`. |
| 13 | `CameraView.swift:1006`, `HeadMakerView.swift:343` vs `GlassIconButton.swift:60`, `ProfileAvatar.swift:89` | Glyph weights regular vs medium with no rule. | §4.3 table; no code change for the camera. |
| 14 | `ProfileView.swift:261`, `:432`, `:439` | `.primary.opacity(0.85)` / `0.1`: the pattern CLAUDE.md says is not a colour. | `inkPrimary`; `fillHairline`. |
| 15 | `CameraView.swift:1013` | Fifth white (0.5) outside the `onDark*` scale. | `onDarkQuiet`. |
| 16 | `MemoriesMapView.swift:552-557` | White filled capsule inside glass. | Keep the fill, drop the glass. |
| 17 | `Strata/Resources/Jaro.ttf`, `Info.plist:7`, `Typography.swift:9-29`, `:107-144`; `MemoriesView.swift:440-442`; `tasks/brand.md` | Dead identity: an unused registered font, seven unused type tokens, a comment saying the tally "takes the brand colour" (it is ink), and a brand doc that still describes Space Grotesk, a habit tracker and a mascot. | Delete the font, tokens and comment; mark brand.md superseded the way design-system.md sections 1 to 5 are. |

---

## 7. Precedents

Tagged (a) sourced, (b) observed in a shipping product, (c) my inference.

| App | What unifies it | Lesson for Strata | Link |
|---|---|---|---|
| **Halide Mark II** (Lux) | (a) Three custom typefaces "designed from scratch" after the etched type on camera bodies and lenses, used throughout the UI. | The closest precedent: a camera whose identity is its lettering. Strata's camera already works this way; the lesson is to carry it past the camera. | [lux.camera](https://www.lux.camera/pro-camera-action-introducing-halide-mark-ii/) |
| **Duolingo** | (a) Feather Bold, a bespoke face for the logotype and brand, drawn from the owl's shapes; DIN Next Rounded for in-app body copy. | Exactly the split proposed here: the owned face names and headlines, a rounded workhorse carries the reading. | [Monotype](https://www.monotype.com/studio/portfolio/duolingo), [Creative Bloq](https://www.creativebloq.com/news/feather-bold) |
| **Airbnb Cereal** | (a) Commissioned to make the identity cohesive across every platform, and because a shared stock face had lost distinctiveness. | Why a drawn alphabet (phase 2) is worth it once titles are dynamic. | [Creative Review](https://www.creativereview.co.uk/airbnb-introduces-custom-typeface-cereal/), [Adweek](https://www.adweek.com/brand-marketing/airbnb-designed-its-own-playful-font-to-unify-its-look-across-all-platforms/) |
| **Cash App** | (a, secondary source) Cash Sans, a customised Söhne whose rounded punctuation carries the warmth, used for all display, body and buttons, never swapping family for emphasis. | Distinctiveness can live in a few glyphs; do not reach for a second family to shout. | [KEYLAY](https://www.keylaydesign.com/cash-apps-new-brand-portal/) |
| **Flighty** (ADA 2023) | (a) Built on airport-board convention, "one line per flight"; "we want Flighty to work so well that it feels almost boringly obvious". | Cohesion from one borrowed convention applied everywhere, the way the tower is Strata's. | [Apple Developer](https://developer.apple.com/news/?id=970ncww4) |
| **(Not Boring) Weather** (ADA) | (a) An ADA winner that visualises the day in one striking interface. (c) Its identity is bold rendered type and materials rather than chrome. | A single-author app can own a look with very few elements. | [notbor.ing](https://notbor.ing/product/weather) |
| **Crouton** (ADA 2024, Interaction) | (a) A clean interface whose interactions keep attention on the counter, not the screen. | Craft in behaviour counts as much as pixels: addition 2. | [Apple Newsroom](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/) |
| **Things 3** (ADA 2017) | (a) Two ADAs; (b) one quiet ground, one accent, hairlines rather than cards. | The model for §4.1 and §4.2: separation without elevation. | [Cultured Code](https://culturedcode.com/things/blog/2017/06/back-from-wwdc/) |
| **Apple, SF Symbols HIG** | (a) Symbol weights correspond to font weights for precise matching with adjacent text. | §4.3: glyph weight follows the type beside it. | [HIG: SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols), [WWDC20 UI typography](https://developer.apple.com/videos/play/wwdc2020/10175/) |

---

## 8. Implementation plan

Ordered so that deletions and measurements land before anything visible.

| # | Task | Size | Verify with | Owner's eye |
|---|---|---|---|---|
| 1 | Delete `Jaro.ttf`, its `UIAppFonts` entry, `JaroFont`, the seven dead type tokens, `FlyawayBlockView` and its state, the stale "brand colour" comments; mark `tasks/brand.md` superseded. | S | Build; grep shows zero references; app size drops about 146 KB. | No |
| 2 | Measure before deciding: (a) dark-mode form rows vs page, ratio and luminance at top and bottom; (b) tower scroll with and without the depth shadow, 200 blocks, Instruments hitches and offscreen passes; (c) AccentColor dark: the Settings back chevron; (d) photo-title contrast with the veil alone on the 10 brightest seeded photos. | M | Numbers in a table; frames listed in the appendix. | No |
| 3 | Rounded Medium for nav titles and tab labels; `.isHeader` in `DrawnLettering`; Memories tab fills; `onDarkQuiet` for the dimmed glyph; `inkPrimary`/`fillHairline` in Profile; widget Medium. | S | Screenshot pairs light/dark of every sheet title and the tab bar; VoiceOver rotor lists `Memories` as a heading. | No |
| 4 | AccentColor dark appearance (if 2c confirms). | S | Chevron and dialog buttons 4.5:1 on the dark page. | No |
| 5 | Launch colour asset. | S | Cold launch film, light and dark: no black or white frame before the page. | No |
| 6 | Shadows: delete depth shadow (if 2b agrees), drawer hairline, onboarding portrait, widget veil, `liveHalo` token for camera and head maker. | S | Before/after at 3x crops; camera frames pixel-compared with a tolerance, since the token keeps the look. | **Camera halo token: yes** |
| 7 | `rowFill` surface token on form rows. | S | Contrast table from 2a; Settings light/dark pair. | Yes (dark value) |
| 8 | Chrome material: `ground: .page` hairline capsule; collapse private glass copies; map prime drops glass; "Done" as bare `headerSmall` in the drawer. | M | `v4`-style crops of Share/Save/close in light and dark look identical in shape and edge; no halo pixels beyond the capsule (sample 6pt outside the edge equals the ground). | **Yes** |
| 9 | `StrataMark` onto the icon's ground. | S | Mark at 72pt next to the icon at 60pt, one image. | Yes |
| 10 | Numerals: add `. x / -`; zoom pill and replay dates in numerals. | M | Font renders all glyphs (render every string the app sets); `.numericText()` does not clip (TrueType). | Yes (he draws the glyphs) |
| 11 | Count lands with the block (addition 2). | M | 240fps film: the digit's first changed frame is within one frame of the impact haptic log line; replay video frame at the last landing shows the final count. | Film |
| 12 | `GhostBlocks` empty state for the map and widget (addition 3). | M | Empty map light/dark, empty widget small/medium. | Yes (map) |
| 13 | Phase 1 drawn titles (seven SVGs). | L (owner drawing) + M (code) | Each title's cap on 18.8pt measured off a frame, at default and AX3; VoiceOver reads the word; drawn word at xSmall is legible. | **Yes** |
| 14 | Shutter lit rim (addition 5). | S | Side-by-side at 3x on the viewfinder. | **Yes** |
| 15 | Decide on phase 2 `StrataDisplay.ttf` after 13 has been lived with. | L | Coverage check fallback test with `Café`, `Zürich`, a 40-character place name. | Yes |

### Performance budget (the "lightspeed" bar)

| Metric | Budget | How |
|---|---|---|
| Custom fonts registered at launch | ≤ 64 KB total (today 147.8 KB, after task 1: 2.2 KB) | file sizes |
| Drawn SVG words shipped | ≤ 8 | asset count |
| Glass elements visible per screen | ≤ 3 | code review |
| Shadows per block | exactly 1 at rest | code review |
| Tower scroll, 200 blocks, iPhone 13-class | hitch ratio < 5 ms/s, no regression after any task | Instruments Animation Hitches |
| Cold launch to first tower frame | no regression beyond ±20 ms | `os_signpost` in `setup()` |
| Per-frame work added by this plan | none: no `Canvas`, no blur, no timers | code review |

---

## Appendix: shots needed

The earlier full-app screenshots were wiped; the ones used here are
`owner-shots/v4/d-wk-light.png`, `d-wk-dark.png`, `owner-shots/sheet-loading-dark.png`
and the app icon PNGs. These are needed to close the measurements, all on
iPhone 16 Pro (402x874) unless stated:

| # | Flags | Scheme | What it decides |
|---|---|---|---|
| S1 | `-strataOpenSheet settings` | dark and light | Form row vs page luminance at top and bottom (task 2a, inconsistency 3); back chevron colour (2c) |
| S2 | `-strataOpenSheet profile` | dark and light | Row fill; title font; `Done` treatment |
| S3 | `-strataStartTab tower -strataSeedHistory 60` | light and dark | Plan button halo on the page (inconsistency 2); tally on its line |
| S4 | `-strataStartTab memories`, drawer raised | light and dark | `Done` capsule halo; drawer top edge shadow |
| S5 | `-strataStartTab memories -strataMapStyle satellite` with no places | dark | Map empty state before addition 3 |
| S6 | `-strataStartTab camera` with guides on, flags forced on in a throwaway build | dark | Halo values before the token; shutter rim before addition 5 |
| S7 | Cold launch, film | light and dark | Launch flash (inconsistency 9) |
| S8 | `-strataOpenReplay sampleWeek -strataReplayAt 20` | light | Share and Save capsules after task 8 |
| S9 | `-strataOpenSheet settings` at AX3, and xSmall | light | Drawn title floor (rule 4) |
| S10 | iPhone SE (375x667), S3 and S2 | light | Title line and tab bar on the small screen |
| S11 | Widget gallery, small and medium, empty and with photos | light and dark | Widget weight and veil |
