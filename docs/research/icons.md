# Strata icons: which set matches his type

Written 2026-09-16. Read only on the app: no checkout was edited, nothing was built, no simulator ran.
Everything was measured on macOS: CoreText for type, AppKit's SVG renderer for icons (CoreSVG, the same renderer an Xcode asset catalog uses), AppKit for SF Symbols. Scripts are in `tools/` and the proofs are in `proofs/`.

## 0. The answer

**Recommendation: a small custom set, "Strata Symbols", drawn to the curvature of his font and shipped as custom SF Symbol templates.** Nothing on the market matches his joins. Every set tested draws a sharp crossing, while his + and X melt where their strokes meet. Custom glyphs built from his own radii scored **88/100** against his font. The best third-party set scored **69**.

**Until those glyphs exist, keep SF Symbols and fix the weight.** Choose each glyph's weight from the text beside it, using the rule in section 7.2. SF Symbols Bold matches his stem to within 5% (0.177 against 0.186) and scores **69**, the same as the best third-party set (Tabler at a stroke of 3.04). You also keep every SF Symbols benefit and add no licence.

Note that `research-visual-cohesion.md` §4.3 records "SF Symbols only (settled)". The owner's request reopens that decision. This recommendation keeps the SF Symbols machinery: custom symbols still get Dynamic Type, weights, scales and symbol effects. So the reasons for the old decision still hold.

Best proof: `proofs/inline-context.png`. It shows each candidate set inline in his lines ("Memories", "Your week", "Add a win") on both grounds.

---

## 1. The curvature fingerprint of his font

Measured on `/Users/jaydenbetts/StrataWork/font/Strata-Regular.ttf`, rasterised at 1700 px per em (`tools/fingerprint.py`, output `proofs/fingerprint.json`). The TTF outline is his SVG fill joined with its 2-unit outside stroke (see `font/font-report.md`), so these ratios describe the drawing he sees in Figma. Close-ups are in `proofs/font-closeup.png`.

Every radius below is a fraction of the local stroke `t`.

| Property | Where measured | Value | What it means |
|---|---|---|---|
| Stroke to size | stem / cap height (126/700; pixel check 0.186) | **0.18 to 0.186** | Heavy. SF Pro Rounded Medium is 0.153 and Regular is 0.123. |
| Stroke contrast | horizontal / vertical | 0.82 | Horizontals are slightly thinner. |
| Outer corner of a round | O, top-left | **1.19 t** (0.24 of the width) | Rounds are rounded rectangles, not circles. |
| Counter corner | inside O | **0.33 t** | The counter is nearly square. |
| Offset between the two | outer minus inner | 0.86 t | Close to concentric but not exactly: a stroked rectangle would give 1.0. |
| Squircle | O area / bbox area 0.953 | **superellipse n = 5.2** (o: 4.1) | A circle is n = 2 and a square is n = infinity. |
| Terminals | T foot, E arm, + arm | **0.83 to 0.88** of a full semicircle | Almost round, with a slightly squared end. |
| Outer square corner | E, top-left | 0.38 t | Tighter than the rounds. |
| Inside corner | L, stem meeting foot | **1.22 t** | A generous concave curve. |
| Crossing fillet | + at the centre | **0.77 t** | Concave fillets where the strokes cross. |
| Crotch notch | X, Y, M at the top centre | **1.30, 1.33, 1.36 t** | A soft U-shaped notch. Strokes melt together and never meet at a point. |
| Diagonals | V, W, X, Y, K arms | straight | Only the joins soften. The arms themselves do not curve. |
| Aperture | c, gap / x-height | 0.74 | Very open: the c is a bracket. |

**In one line:** stem 0.18 of the cap height; rounded-rectangle rounds with an outer corner of 1.19 t, a counter corner of 0.33 t and n ≈ 5; terminals at 0.85 of a semicircle; filleted and melted joins (+ 0.77 t, X/Y/M crotch 1.3 t).

The two rare properties are the **melted joins** and the **heavy stroke with small, squarish counters**. Almost every icon set uses round caps and round joins, so terminals are easy to match. No stroke-based set has concave fillets, because a stroked path cannot produce them.

---

## 2. What the app uses today

Source: `grep` of `systemName` / `systemImage` / symbol-name strings in `owner-head/Strata`. The widget uses no symbols. Custom assets are only the `S` mark, the wordmark and the `Memories` title SVG; the app has no custom glyphs. About **45 distinct symbols**, with fill twins, across about 70 call sites.

### 2.1 By screen and role

| Screen / role | Symbols | Size / weight as coded | File |
|---|---|---|---|
| **Tab bar** (system `TabView`) | `square.stack` / `.fill`, `camera` / `.fill`, `photo.stack` | system tab size | `MainAppView.swift:584-612`, `TabBarView.swift` |
| **Glass buttons** (`GlassIconButton`, 44 pt) | `xmark` (replay, photo viewer, add sheet, camera, head maker), `ellipsis`, `checklist` (Plan), `photo.on.rectangle.angled` (Memories), `location` / `location.fill` (map recentre) | 17 medium; **16** medium on the camera and head maker close | `GlassIconButton.swift:59` |
| **Camera control bar** | `rectangle.split.3x3`, `bolt.fill` / `bolt.slash.fill`, `arrow.triangle.2.circlepath`, `timer`, `sun.max.fill` | **21 regular**, white, off = 0.5 opacity; sun `headerSmall` 15 medium, yellow | `CameraView.swift:812-1006, 1368` |
| **Head maker** | `bolt.fill` / `bolt.slash.fill`, `xmark` | 21 regular, full white | `HeadMakerView.swift:200, 342` |
| **Settings rows** (`SettingsIcon`) | `bell`, `square.stack.3d.up` (x2), `speaker.wave.2`, `iphone.radiowaves.left.and.right`, `calendar`, `photo.on.rectangle.angled`, `mappin.and.ellipse`, `questionmark.circle`, `square.and.arrow.up`, `trash` (warmRed), `envelope`, `star`, `hand.raised`, `arrow.up.right` | 13 medium relative to `.footnote`, `inkSecondary`; `arrow.up.right` is `.caption` (12, regular) | `SettingsView.swift:117-398, 615` |
| **Profile rows and menu** | `face.smiling`, `person.crop.circle`, `map`, `camera` (x2), `trash`, `gearshape`, `photo.on.rectangle`, `paintpalette` | 13 medium (rows); system (menu) | `ProfileView.swift:139-588` |
| **Avatar** | `person.fill` | `side * 0.42` medium; `bodyLarge` medium | `ProfileAvatar.swift:44, 88` |
| **Add a win sheet** | `camera.fill`, `arrow.triangle.2.circlepath.camera.fill` (badge), category icons (swatches), menu `photo.on.rectangle`, `trash` | 17 medium; `caption2` 11 medium; 13 medium white | `AddWinSheet.swift:387-811` |
| **Photo viewer menu** | `square.and.arrow.up`, `square.and.arrow.down` / `checkmark`, `trash`, `mappin.and.ellipse` | system menu | `PhotoViewer.swift:296-359` |
| **Plan** | `plus` (17 medium, accentWarm), `info.circle` (bodyLarge regular), `arrow.triangle.2.circlepath` (inherits), `checkmark` (15 medium), `trash` (17 medium), bullet `checkmark` (`side * 0.52`) | mixed | `PlanSheet.swift`, `PlanItemDetailSheet.swift`, `PlanBullet.swift` |
| **Tower** | `plus` (next slot, 13 medium), `chevron.down` (month menu, **10** medium), `checkmark` (menu) | | `NextSlotButton.swift:131`, `MonthTowerView.swift:283-305` |
| **Empty or failed image** | `photo` | `side * 0.25` regular | `CachedImageView.swift:103` |
| **Categories** (App Intents, block model) | `heart.fill`, `briefcase.fill`, `paintbrush.fill`, `eye.fill`, `person.2.fill`, `leaf.fill`, `square.fill` | system surfaces | `Habit.swift:35-40`, `CategoryAppEnum.swift`, `HabitEntity.swift` |
| **Shortcuts / Focus filter** | `plus.square.fill`, `square.stack.fill`, `line.3.horizontal.decrease.circle(.fill)` | system surfaces | `StrataShortcuts.swift`, `StrataFocusFilter.swift` |
| **Block icons (planned)** | 36 SF fill glyphs, 6 groups | 22.5 pt debossed | `research-block-icons.md` §4.3 |

### 2.2 Inconsistencies

1. **Seven glyph sizes, only one of them a token.** The code uses 10, 11, 13, 15, 16, 17 and 21, plus `side * 0.25`, `* 0.42` and `* 0.52`. Of the eight `GridConstants.icon*` tokens, four have **zero call sites** (`iconSmall`, `iconMedium`, `iconEmptyState`, `iconHero`). `iconCategory` has 2, `iconToolbar` 2, `iconAction` 1 and `iconChevron` 1.
2. **Three weights with no rule.** The camera and head maker use regular, chrome uses medium, and `arrow.up.right` and `info.circle` inherit regular.
3. **Close is 17 in three places and 16 in two** (`CameraView.swift:884`, `HeadMakerView.swift:200`).
4. **Flash says "off" two ways.** The camera uses `bolt.slash.fill` **and** dims it. The head maker uses `bolt.slash.fill` at full white. The comment at `CameraView.swift:826` says off should be dimmed, not slashed.
5. **The Memories tab still never fills** (`MainAppView.swift:612` passes `StrataTab.memories.icon`). This was already flagged in `research-visual-cohesion.md` §4.3.
6. **Three photo glyphs for one idea:** `photo`, `photo.on.rectangle` and `photo.on.rectangle.angled`. There are also two flip glyphs: `arrow.triangle.2.circlepath` and `...camera.fill`.
7. **The `design:` parameter of `iconSize` does nothing to a symbol.** Measured with SwiftUI `ImageRenderer` on plus, camera, bell, gearshape, arrow.counterclockwise and checkmark: **0 pixels differ** between `.default` and `.rounded`. SF Symbols have no rounded design, so "SF Symbols with `.rounded`" is not a real option.

---

## 3. Candidates

**Source.** Glyphs came from each set's official package data, mirrored on jsDelivr: `@iconify-json/<prefix>` for most, npm packages for the first pass. Licence files are saved in `licences/`. The same 18 glyphs were compared for every set: plus, camera, flash, timer, grid, flip camera, close, back chevron, share, save, trash, settings, bell, map pin, photo, person, replay, check. Flash-off was dropped because Strata dims the flash glyph rather than slashing it. The picks are in `proofs/contact-sheet.png`, checked by eye with wrong picks corrected (`tools/overrides.json`).

**Stroke control.** "Yes" means the source is a stroked path, so the stroke width is one attribute. Those sets were also scored at the stroke that matches his stem ("matched"). "No" means filled outlines, so the weight is baked in.

**SwiftUI integration cost** is the same for every third-party set: SVG into the asset catalog as a template image (S), or conversion to custom SF Symbol templates (M to L, see §6).

| Set | Licence (commercial iOS bundling) | Coverage of the 18 | Stroke control | Terminals / corners | Fit (native → matched) |
|---|---|---|---|---|---|
| **SF Symbols** | Apple SF Symbols licence: use in apps on Apple platforms, no bundling needed | 18/18 | 9 weights, 3 scales | slightly squared caps, circular rounds (n ≈ 9) | Regular 47, Medium 57, Semibold 62, **Bold 69** |
| **Tabler** (5,900+) | MIT, yes | 18/18 | yes | round caps and joins, rect rx 2 | 51 → **69** at 3.04 |
| **Lucide** | ISC (+ MIT for Feather-derived icons), yes | 18/18 | yes | round, rx 2 | 59 → **67** at 3.04 |
| Majesticons | MIT, yes | 18/18 (pin is a push-pin) | yes | round | 59 → 67 |
| Akar | MIT, yes | 18/18 | yes | round, larger rx, n = 5.0 | 47 → 66 at 3.48 |
| Myna UI | MIT, yes | 18/18 | yes | round, very large rx | 43 → 65 at 2.66 |
| IconPark Outline | Apache 2.0 (licence + NOTICE), yes | 18/18 | yes (48 grid) | round | 60 → 60 |
| Hugeicons Stroke Rounded (free) | MIT for the free set; Pro is paid, yes | 18/18 | yes | round, squircle frames (n = 3.8, rounder than his) | 36 → 59 at 3.55 |
| Mingcute | Apache 2.0, yes | 18/18 | line style is stroked | sharp counter corners | 50 → 57 |
| Mage | Apache 2.0, yes | 18/18 | yes | very round | 37 → 56 |
| Humbleicons | MIT, yes | 18/18 | yes | round | 50 → 56 |
| Solar Linear / Broken | **CC BY 4.0, attribution required**, yes | 18/18 (grid is a widget glyph) | yes | round, sharp counters at weight | 43 → 55; Broken 35 → 49 |
| ProIcons | MIT, yes | 18/18 | yes | round | 39 → 54 |
| IconaMoon | CC BY 4.0, attribution required | 17/18 (no flip) | yes | round | 48 → 53 |
| Iconoir | MIT, yes | 18/18 | yes | round, tight rx | 43 → 53 |
| Basil | CC BY 4.0, attribution required | 18/18 | yes | very round (outer r 2.8 t) | 46 → 53 |
| Material Symbols Rounded 400 | Apache 2.0, yes | 18/18 | variable font axis, not in SVG | rounded ends, square counters (inner r 0.04 t) | 53 |
| Eva | MIT, yes | 18/18 | no | round | 58 |
| Radix | MIT, yes | 17/18 (no flip glyph) | no (15 px, 1 px stroke) | round | 51 |
| Pepicons Pop | CC BY 4.0, attribution required | 17/18 (no save) | no | round, heavy | 49 |
| Unicons | Apache 2.0, yes | 18/18 | no | round | 48 |
| Framework7 | MIT, yes | 18/18 | no | iOS-like | 48 |
| Phosphor Regular / Bold | MIT, yes | 18/18 | no (weights baked) | round | 41 / 45 |
| Fluent System Regular | MIT, yes | 18/18 | no | round | 43 |
| Teenyicons | MIT, yes | 17/18 | no (15 px) | square caps | 31 |
| Remix Line | Remix Icon License v1.0: apps allowed, no standalone redistribution | **no camera-flash bolt** | no | sharp | dropped |
| Streamline Flex / Plump / Core (free subsets) | CC BY 4.0, attribution required | **Flex 9/18, Plump 6/18, Core 6/18** | Flex is stroke-based | Plump is closest in spirit (plump, soft) | failed coverage; Pro sets are paid, not measured |
| Lets Icons | CC BY 4.0 | picks unreliable (settings, photo, replay, close) | | | dropped |
| Iconsax (Linear) | MIT (Vuesax repo) | not in the Iconify data | 1.5 stroke | round | not rendered |
| Central Icons | **paid licence** (10 free copies) | 4,000+ | adjustable stroke **and corner radius** | parametric | not measurable without a licence |
| Nucleo | paid licence | large | yes | | not rendered |
| Atlas icons, SVG Repo | per-icon or collection licences | | | | not evaluated as a system |
| Pixelarticons | excluded (brief) | | | | |

**Licence notes.**
- MIT and ISC: bundle the copyright line and permission notice, for example in an Acknowledgements screen, which Strata does not have yet.
- Apache 2.0: also include the licence text and any NOTICE file.
- CC BY 4.0: needs visible attribution in the app.
- None of these forbids a commercial iOS app.

---

## 4. Fit with the type, measured and seen

### 4.1 Method

The same raster metrics were run on his font and on every set (`tools/shape.py`, `tools/score.py`, results in `proofs/scores.json` and `proofs/score-table.md`).

| Metric | Measured on | Target (his font) | Weight |
|---|---|---|---|
| Stroke / height | plus bar / plus ink height (the plus stands in for cap height) | 0.18 | 25 |
| Terminal roundness | plus arm end | 0.85 | 20 |
| Outer corner radius / stroke | photo frame | 1.19 | 15 |
| Counter corner radius / stroke | photo frame | 0.33 | 10 |
| Squircle exponent | photo frame silhouette | 5.2 | 10 |
| Joins | plus crossing fillet (target 0.77 t) and close crotch notch (target 1.30 t) | as stated | 20 |

The radius and squircle scores fall off on a log scale (zero at a factor of 3).

For a stroke-adjustable set, the matched stroke was solved from its native plus so that stroke / height = 126/700. That lands at 3.04 on a 24 grid for Tabler, Lucide and Majesticons, 3.48 for Akar, 2.66 for Myna UI and Iconoir, and 3.55 for Hugeicons and Solar.

**Limits.**
- Frame metrics come from one glyph (photo).
- A sharp stroked crotch reads 0.27 t, not 0, in this method. That baseline is subtracted before scoring joins.
- The 20 points for joins are out of reach for any stroke set, so the third-party ceiling is about 80.

### 4.2 Scores (top rows)

| Candidate | Fit | stroke/h | terminal | outer r/t | inner r/t | n | + fillet/t | X crotch/t |
|---|---|---|---|---|---|---|---|---|
| **his font (target)** | | 0.186 | 0.85 | 1.19 | 0.33 | 5.2 | 0.77 | 1.30 |
| **Custom, drawn to the fingerprint** | **88** | 0.187 | 1.00 | 1.19 | 0.32 | 5.9 | 0.39 | 1.17 |
| SF Symbols Bold | 69 | 0.177 | 0.98 | 1.20 | 0.43 | 8.6 | 0 | sharp |
| Tabler at 3.04 | 69 | 0.177 | 0.98 | 1.49 | 0.51 | 5.6 | 0 | sharp |
| Lucide at 3.04 | 67 | 0.177 | 0.98 | 1.17 | 0.16 | 7.2 | 0 | sharp |
| Majesticons at 3.04 | 67 | 0.177 | 0.98 | 1.17 | 0.16 | 7.6 | 0 | sharp |
| Akar at 3.48 | 66 | 0.180 | 1.00 | 1.65 | 0.64 | 5.0 | 0 | sharp |
| Myna UI at 2.66 | 65 | 0.180 | 0.99 | 1.16 | 0.09 | 4.5 | 0 | sharp |
| SF Symbols Semibold | 62 | 0.152 | 1.00 | 1.30 | 0.54 | 9.0 | 0 | sharp |
| SF Symbols Medium (today) | 57 | 0.135 | 0.98 | 1.48 | 0.61 | 9.3 | 0 | sharp |
| Tabler at native 2.0 | 51 | 0.126 | 0.98 | 1.99 | 0.98 | 6.1 | 0 | sharp |

**Stroke matching SF Symbols, weight by weight** (plus bar / plus height; `proofs/measurements.tsv`):

| Weight | Ultralight | Thin | Light | Regular | Medium | Semibold | Bold | Heavy | Black |
|---|---|---|---|---|---|---|---|---|---|
| Stroke / height | 0.032 | 0.049 | 0.084 | 0.108 | 0.135 | 0.152 | **0.177** | 0.210 | 0.242 |

Text stems / cap height, for comparison:
- Strata: **0.186**, closest to Bold
- SF Pro Rounded Medium: **0.153**, closest to Semibold
- SF Pro Rounded Regular: **0.123**, between Regular (0.108) and Medium (0.135); Medium is marginally nearer

### 4.3 What the proofs show (looked at, not only counted)

**`proofs/sheet-light.png`, `proofs/sheet-dark.png`.** Seventeen variants, 18 glyphs at 24 pt and 17 pt, with "Add a win" in his face and "Photos" in SF Pro Rounded Medium.
- At native weight, every third-party set and SF Medium look **lighter** than his letters: a thin line beside a heavy word.
- At the matched stroke, Tabler, Lucide, Akar and Myna UI carry the same weight as the letters. Tabler and Akar come closest in the rounds, because their rectangles are soft and nearly concentric like his O.
- Lucide and Myna UI close their counters to sharp corners at that weight (inner r 0.16 and 0.09).
- SF Bold is as heavy, but its rounds are circles (n = 8.6 on the frame, and the camera lens and bell are true circles), so it reads "Apple", not "his".

**`proofs/inline-context.png`**, with his lines on both grounds. This is where the difference is plain.
- Next to "Memories" and "Your week" at 34, SF Medium looks like a lighter hand.
- SF Bold, Tabler 3.04 and Akar 3.48 hold the weight.
- None of them has the melted X his "X" has. The close glyph beside his text is the clearest tell: every library X is two straight bars crossing at a point.
- The custom row is the only one where the camera, replay and X read as the **same hand** as "Memories". Its X is his X.

**`proofs/custom-closeup.png`** sets his letters `+ X V O` next to the six custom glyphs at 72, then "Add a win" with custom, Tabler 3.04 and SF Bold glyphs at 34.
- The custom plus, X and chevron are indistinguishable in voice from the letters.
- **Camera and photo are denser than his O**: thick frame, small counter. The production drawing should open them up. Those two glyphs are sketches.

**Verdict.**
- **Same hand:** only the custom glyphs.
- **Same weight:** SF Symbols Bold, Tabler at 3.04 and Akar at 3.48. Tabler is marginally closer in its rounds, SF Bold in its terminals.
- **Different hand:** everything at native weight, including today's SF Medium.

---

## 5. The custom option

### 5.1 How the six proof glyphs were built

Script: `tools/strataize.py`, then `tools/soften.py`. Construction pictures: `proofs/custom-construction.png`.

- Grid: 1000-unit box, 760-unit body, stroke 140 (0.184 of the body; his stem / cap is 0.18).
- **plus**: two strokes with round caps, joins softened to a 0.39 t fillet. His + measures 0.77 t. Blur and threshold at sigma 28 was used, because a larger sigma melted the camera's shoulder.
- **close**: his own `X` outline, scaled uniformly, so the notch is his (1.17 t measured after rasterising).
- **back**: a two-segment chevron with a round join (his V apex).
- **camera**: his O as a frame (outer corner 1.19 t, counter corner 0.33 t), a solid rounded tab for the shoulder, and a solid rounded-square lens (his o, filled).
- **photo**: the same O frame, a one-peak mountain clipped to the frame, and a rounded-square sun.
- **replay**: an open rounded-rectangle loop with a chevron head.

These are raster sketches for judging the voice, not production outlines.

### 5.2 What the build taught (it changes the estimate)

1. **Library geometry cannot simply be "Strata-ized".** Tabler's skeletons re-stroked at 3.04 leave gaps of 1.4 to 3 grid units. Any join fillet larger than about 0.3 of the stroke fills them: trash, gear, pin and camera all turned into solid blobs. His fillets need glyphs drawn with his large, few counters, so each glyph is a drawing, not a filter.
2. **At his weight, counters must be at least 1.2 t.** Anything tighter reads as a filled shape at 17 pt.
3. **Custom SF Symbol templates need three weight masters** (Ultralight, Regular, Black) with compatible paths to interpolate to the named weights. A stroke-first drawing makes that easy: the same skeleton at three widths. The fillets are then adjusted per master.

### 5.3 Effort

About **34 chrome glyphs** after merging duplicates (§7.3), plus 3 fill variants (Wins tab, Memories tab, location). Allow 1 to 1.5 h each for skeleton, three masters, fillets, template export and an SF Symbols app check. That is **35 to 50 hours**. A person who knows Glyphs or Figma and his font can do it; the six proofs here set the construction rules.

The 36 block-icon pictograms (figures running and swimming, bicycle, fork and knife and so on) are harder: 1.5 to 2 h each, **55 to 70 hours**.

### 5.4 Verdict

**Build it.** It is the only option that reads as his hand, measured (88 against 69) and seen. Its cost is drawing time, not runtime or integration: templates behave like SF Symbols in SwiftUI.

---

## 6. Trade-offs specific to iOS

| Capability | SF Symbols | Custom SF Symbol templates (recommended) | Third-party SVG as template image |
|---|---|---|---|
| Dynamic Type | yes, from `.font` | **yes**, the same | only via `@ScaledMetric` frames (the `iconSize` modifier already does this) |
| Weight matches text | 9 weights | **yes, if three masters are drawn** | no; one baked weight |
| Baseline and cap alignment inside `Text` / `Label` | yes | **yes** (template guides) | no; frames only |
| Small / medium / large scale | yes | **yes** | no |
| Symbol effects (bounce, pulse, scale, replace, wiggle, rotate, breathe) | yes | **yes**; Draw On/Off (iOS 26) needs draw annotations in SF Symbols 7 | no |
| Hierarchical / palette rendering | yes | needs layer annotation (monochrome is enough for Strata) | no |
| RTL | automatic for directional symbols | **set per glyph** in the template (back, replay, share) | manual `flipsForRightToLeftLayoutDirection` |
| Accessibility label | some built in | **none**; always pass `accessibilityLabel` or hide as decorative | none |
| Future Apple updates / localised variants | yes | no (Strata uses no localised glyphs) | no |
| Licence | Apple | his own drawing | per set (§3) |

### Where the system's icons stay, and how to keep them from clashing

- **Share sheet** (`UIActivityViewController`, `ShareLink`): its app row and action glyphs are Apple's and cannot change. They are a separate sheet, so no clash inside one surface.
- **Alerts and `confirmationDialog`**: no icons.
- **System `Menu` rows**: Strata supplies the images. Use Strata Symbols in **every** row of a menu (PhotoViewer, AddWinSheet, Profile), so one menu is never half Apple, half Strata. The automatic check in a `Picker` menu (`MonthTowerView`) is Apple's; replace it with an explicit Strata check label, or leave that menu as a system picker throughout.
- **Tab bar**: `Tab("Wins", image: "strata.stack")` accepts custom symbols. Draw the selected `.fill` variants. Labels stay system text.
- **Shortcuts, Focus filters, App Intents** (`DisplayRepresentation`): these appear in Apple's UI beside other apps' SF glyphs. **Keep SF Symbols there.** It is a system surface, and consistency with neighbouring apps matters more.
- **PhotosPicker, the camera permission prompt, Settings.app**: Apple's, untouched.

---

## 7. Recommendation

### 7.1 One system

**Strata Symbols.** A custom set drawn to the fingerprint in §1, delivered as custom SF Symbol templates (`.svg` in a `.symbolset` in the asset catalog) behind a `StrataSymbol` enum.

**Interim, from today, at no cost:** keep SF Symbols and apply the weight rule below. Numerically SF Bold ties the best library, so there is no reason to adopt a third-party set as a stopgap and then migrate twice.

**If the owner declines custom drawing:**
- **SF Symbols with the weight rule** (fit 69, no licence, full system behaviour).
- Only if he specifically wants the softer rounds: **Tabler at stroke 3.0** (fit 69, MIT, his portfolio's pack). It gives up weights, baseline alignment and effects. It is the closest library to his rounds (n 5.6 against 5.2, near-concentric corners).
- Runner-up: **Lucide at 3.0** (67, ISC).

### 7.2 Weight and size rules, mapped to the reduced type scale

**Weight: an icon takes the stroke of the text it sits beside.**

| Beside | Text stem / cap | SF Symbols weight now | Strata Symbols master target |
|---|---|---|---|
| Strata (titles 34, sheet titles 17, counts), or no text (glass buttons, camera bar, map) | 0.186 | **Bold** (0.177) | Bold = 0.186 |
| SF Pro Rounded **Medium** (buttons 15, headers 17, section labels 13, caption2 11) | 0.153 | **Semibold** (0.152) | Semibold = 0.153 |
| SF Pro Rounded **Regular** (body 17, subtitles 15, rows 13) | 0.123 | **Medium** (0.135) | Medium = 0.125 |

Draw the Regular and Black masters so the interpolated Medium, Semibold and Bold land on these numbers. Call sites then keep using `.fontWeight(...)`, and one rule serves both the interim SF glyphs and the custom set.

**Size: an icon uses the text style of its role, inside the five sizes.**

| Size (style) | Icons |
|---|---|
| **34** `.largeTitle` | empty-state heroes. Delete the unused `iconEmptyState` 36 and `iconHero` 40. |
| **17** `.body` | glass buttons; the camera and head maker close moves 16 → 17; toolbar `plus` and `trash`; the Add sheet camera. **Camera control bar: 17 with `.imageScale(.large)`**, visually about 22, replacing the raw 21. Needs the owner's eye, because the camera's regular weight was a deliberate choice. |
| **15** `.subheadline` | glyphs inside 15 pt buttons (Plan check, camera sun) |
| **13** `.footnote` | Settings and Profile row glyphs, next-slot plus, category swatches |
| **11** `.caption2` | month-menu `chevron.down` (10 → 11), flip badge, `arrow.up.right` (12 → 11) |

**Outside the scale on purpose** (geometry-derived): avatar glyph `side * 0.42`, plan bullet check `side * 0.52`, image placeholder `side * 0.25`, block icon glyph (block-derived).

Also delete the unused tokens `iconSmall` and `iconMedium`, and fold `iconAction` 14 into 13 or 15.

**Fill rule** (existing): filled = selected, outline = not. Off = dimmed, never slashed.

### 7.3 Swaps per screen (SF name → Strata Symbol), with merges

| Screen | Swap |
|---|---|
| Tab bar | `square.stack(.fill)` → `strata.stack(.fill)`; `camera(.fill)` → `strata.camera(.fill)`; `photo.stack` → `strata.photos(.fill)`, and **fill it when selected** |
| Glass buttons | `xmark` → `strata.close` (his X); `ellipsis` → `strata.more`; `checklist` → `strata.plan`; `photo.on.rectangle.angled` → `strata.photo`; `location(.fill)` → `strata.location(.fill)` |
| Camera bar | `rectangle.split.3x3` → `strata.grid`; `bolt.fill` and `bolt.slash.fill` → **one** `strata.flash`, dimmed when off; `arrow.triangle.2.circlepath` → `strata.flip`; `timer` → `strata.timer`; `sun.max.fill` → `strata.sun` |
| Head maker | `bolt.slash.fill` → `strata.flash` dimmed (matches the camera); `xmark` → `strata.close` |
| Add a win | `camera.fill` → `strata.camera`; `arrow.triangle.2.circlepath.camera.fill` → `strata.flip` (**merge**); menu `photo.on.rectangle` → `strata.photo` (**merge**); `trash` → `strata.trash` |
| Photo viewer menu | `square.and.arrow.up` → `strata.share`; `square.and.arrow.down` / `checkmark` → `strata.save` / `strata.check`; `trash` → `strata.trash`; `mappin.and.ellipse` → `strata.pin` |
| Settings | `bell` → `strata.bell`; `square.stack.3d.up` → `strata.replay`; `speaker.wave.2` → `strata.sound`; `iphone.radiowaves.left.and.right` → `strata.haptics`; `calendar` → `strata.calendar`; `photo.on.rectangle.angled` → `strata.photo`; `mappin.and.ellipse` → `strata.pin`; `questionmark.circle` → `strata.help`; `square.and.arrow.up` → `strata.share`; `trash` → `strata.trash`; `envelope` → `strata.mail`; `star` → `strata.star`; `hand.raised` → `strata.privacy`; `arrow.up.right` → `strata.external` |
| Profile | `face.smiling` → `strata.head`; `person.crop.circle` and `person.fill` → `strata.person` (**merge**); `map` → `strata.map`; `camera` → `strata.camera`; `gearshape` → `strata.settings`; `paintpalette` → `strata.palette` |
| Plan | `plus` → `strata.plus`; `info.circle` → `strata.info`; `arrow.triangle.2.circlepath` → `strata.repeat`; `checkmark` → `strata.check` |
| Tower | `plus` → `strata.plus`; `chevron.down` → `strata.chevron.down`; menu check → `strata.check` |
| Image placeholder | `photo` → `strata.photo` |
| App Intents, Shortcuts, Focus filter | **keep SF Symbols** (system surface, §6) |

That is 34 glyphs plus 3 fill variants.

### 7.4 Block icons

- Block icons use **the same set, as filled pictograms in the same hand**. His letters are solid heavy shapes, and a debossed recess reads by silhouette, so fills carry his rounds and fillets better than outlines would.
- Store the **Strata name** (`strata.run`), not an SF name, in `Habit.iconSymbol`, `PlacedBlock.Look`, `ReplayWin` and `WidgetSnapshot.Block`.
- Change `research-block-icons.md`'s test `everySymbolResolves` from `UIImage(systemName:)` to `UIImage(named:)` over the bundle.
- **Do not ship block icons in SF while the chrome is custom.** A second hand on the block is the "slapped on sticker" the owner asked to avoid. Ship them together with, or after, the 36 are drawn. The relief spec in that document (shade 0.14, lip 0.28, floors 56 and 32 pt) is unchanged.

### 7.5 Licence text

- **Custom set:** his own drawing; no third-party text.
- **Interim SF Symbols:** Apple's licence; no text in the app. Do not trace SF Symbols to make the custom set. The proofs here were built from his font, not from Apple's glyphs.
- **Only if the Tabler fallback is chosen:** bundle the MIT notice, "MIT License, Copyright (c) 2020-2026 Paweł Kuna", plus the standard permission paragraph (full text in `licences/tabler.txt`), in an Acknowledgements screen or a bundled `LICENSE`.
- **Lucide:** the ISC notice plus the Feather MIT notice (`licences/lucide.txt`).
- **CC BY sets (Solar, Basil, Streamline free, IconaMoon, Pepicons):** would need visible attribution. Another reason to avoid them.

---

## 8. Build plan

| # | Step | Size | Proof it is done |
|---|---|---|---|
| 1 | **Interim weight rule on SF Symbols.** `IconStyle` gains a role API (`.icon(.chrome)`, `.icon(.row)`, `.icon(.inline(textWeight))`) that sets the weight and text style from §7.2. Close 16 → 17. One flash glyph, dimmed. Memories tab fills. Delete the 4 dead tokens. | S | Screenshot pairs, light and dark, of the tower header, Settings, camera bar and Add sheet; a unit test that maps each role to its weight and size |
| 2 | **Construction rules and six production glyphs** (plus, close, back, camera, photo, replay) in Glyphs or Figma on an SF Symbols template grid. Fingerprint numbers as guides. Three masters each. Open up the camera and photo counters. | M | Owner reviews `custom-closeup.png`-style sheets at 13, 17 and 34 on both grounds; `tools/score.py` fit ≥ 85 per glyph |
| 3 | **Remaining 28 chrome glyphs + 3 fills**, exported as templates. RTL flags for back, replay and share. Validate in the SF Symbols app (interpolation at Medium, Semibold and Bold). | L | Every glyph renders at all 9 weights; the stroke / height at Medium, Semibold and Bold measures 0.125 / 0.153 / 0.186 ±0.01 |
| 4 | **`StrataSymbol` enum and asset catalog**; `GlassIconButton`, `SettingsIcon` and `glyphButton` take it; swap all call sites (§7.3). | M | Test: every enum case resolves with `UIImage(named:)`; grep finds `systemName` only in App Intents files |
| 5 | **Accessibility pass:** every Strata Symbol has a label or `.accessibilityHidden`. | S | VoiceOver rotor walk of Tower, Memories, Settings, Camera |
| 6 | **Block icon set:** 36 filled pictograms, then the block-icon feature per `research-block-icons.md` with Strata names. | L | Relief proof at 56 and 32 pt floors; the `Look` equality test still fails when the field is removed |

---

## 9. Files

- `proofs/inline-context.png`: **best proof**; each candidate set inline in his lines, light and dark
- `proofs/custom-closeup.png`: his letters beside the custom glyphs; custom vs Tabler 3.04 vs SF Bold at 34
- `proofs/sheet-light.png`, `proofs/sheet-dark.png`: 17 variants, 18 glyphs at 24 and 17 pt
- `proofs/contact-sheet.png`: all 26 sets as downloaded, native weight, SF Medium on top
- `proofs/custom-construction.png`: custom glyphs at 200 px and 44 px
- `proofs/font-closeup.png`: O D P E L T M W X Y K c + at 300 px
- `proofs/fingerprint.json`, `proofs/scores.json`, `proofs/score-table.md`, `proofs/measurements.tsv`: numbers
- `svg/<set>/<key>.svg`: the glyphs compared; `svg/custom/`: the custom skeletons
- `licences/`: licence files as shipped by each package
- `tools/`: `resolve.py` (glyph picks; re-downloads Iconify data from jsDelivr), `score.py`, `shape.py`, `fingerprint.py`, `strataize.py`, `soften.py`, and `proofs.swift` / `contact.swift` / `export.swift` / `measure.swift` (concatenate with `common.swift` to compile)

**Measurement caveats.**
- Weights and corners were measured on single representative glyphs (plus, photo, close).
- The custom glyphs were softened on a raster; skia-pathops closing was unreliable on overlapping strokes, so production outlines must be drawn.
- SVGPathPen's implicit lineTo (`M x y x y`) is drawn wrongly by CoreSVG. Anything exported for an asset catalog should use explicit commands, which `strataize.py` does.
