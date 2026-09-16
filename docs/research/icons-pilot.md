# Strata Symbols pilot: 10 glyphs, built properly

2026-09-16. Nothing in the app was edited, nothing was built, no simulator ran. Everything is under `icons/pilot/`.

## Results

**Templates validated.**
- All 20 templates (10 glyphs, plus a small-size variant of each) have Ultralight, Regular and Black masters whose paths match command for command.
- `xcrun actool` compiled the `.symbolset`s for iphoneos (deployment target 18.0) and macosx with **no errors or warnings**.
- Loaded back from `Assets.car`, every symbol draws at all 9 weights and all 3 scales (`proofs/validate-compiled-weights.png`, 90 of 90 loaded).

**Import into the SF Symbols app.** The files follow the v3.0 template layout that SwiftDraw's exporter writes: an 800x600 canvas with Notes, Guides and Symbols groups, `Capline-S` / `Baseline-S`, per-weight margin guides, and `Ultralight-S` / `Regular-S` / `Black-S`. The app itself is not installed here, so the import was not tried. Xcode's own asset compiler accepting the templates is the strongest check available on this Mac.

**Weight band** (ink at 100 pt, Bold, in pt²; `validate/ink-band.tsv`):

| | Custom | SF Symbols equivalents |
|---|---|---|
| Range, all 10 | 2,323 (back) to 8,285 (photo), **3.6x** | 1,790 (chevron) to 7,197 (photo), 4.0x |
| Range, chevron excluded | **2.5x** | 3.7x |
| Mean | 5,558 | 3,887 |

The custom set is tighter than SF but **about 1.4x heavier** at the same named weight. Ink measured on the 24-unit grid gives the same order: back 62 u², plus 86, close 111, memories 120, replay 157, share 158, wins 172, settings 173, camera 193, photo 216.

**Small-size variants (11 to 15 pt).**

| Glyph | Change |
|---|---|
| camera | lens 4.4 → 3.0 |
| memories | centre dot removed |
| settings | narrower teeth, centre dot removed |
| photo | sun removed |
| plus | crossing fillet 0.77 → 0.55 w |
| close | crotch fillet 1.0 → 0.8 w |

The other four (wins, back, share, replay) needed no change. Custom symbols have no optical-size axis, so the small variants ship as separate symbols (`strata.camera.small`) and the call site picks them at 15 pt and below.

**Least sure of: wins.** A 1x1 block on a 2x1 block is his tower, but at 17 to 20 pt in the tab bar it can read as an "align left" glyph.

## How they were built (`src/geom.py`, `src/icons.py`, `src/build.py`)

**Grid.**
- 24 units, live area 2 to 22.
- Keylines: circle Ø20, square 17.5, portrait 15.5 x 20, landscape 20 x 15.5. Squares and rectangles are drawn smaller than the circle so the three shapes carry equal weight.
- The 24-unit box is 1.2x the point size, so a plus is 0.8 of the point size, like SF.

**Taken from his font** (fingerprint in `../icon-report.md` §1).

| Element | Value |
|---|---|
| Stroke | stroke / plus height = 0.186 at Bold, his stem / cap height |
| Weight ramp | Apple's own ramp x 1.05: Regular 1.81, Medium 2.27, Semibold 2.55, Bold 2.97, Black 4.07 units. So "Bold beside his font, Semibold beside SF Pro Rounded Medium, Medium beside Regular" holds for both sets. |
| Rounds | his O as a frame: outer corner rc + 0.43 w, counter corner rc - 0.43 w (0.86 w apart, as measured). 90-degree corners get 1.10x handles, so they read as continuous-curvature rounded rectangles, not circles. |
| Terminals | 0.425 w corners on every stroke end (0.85 of a semicircle) |
| Joins | concave fillet patches: + crossing 0.77 w (his +); X crotch 1.0 w (his measures 1.3; eased so Black stays valid); 0.2 to 0.5 w elsewhere |

**His letter parts.**
- **close** is his X: steep arms (width 0.8 of height), horizontal feet, melted crotches.
- **plus** is his + construction: bars with a filleted crossing.
- **back** is his V apex turned: round outside, softened inside.
- **camera lens, memories dot, settings dot and photo sun** are his o, filled.
- **wins** is his block proportion: a 1x1 on a 2x1, corner 0.14 of the side.

**Interpolation-safe.**
- Every coordinate is affine in stroke width, so a weight between masters equals a directly drawn instance.
- Every contour has a fixed segment structure.
- The builder raises an error if any corner radius overruns its edge at any weight from Ultralight to Black. None did.

**Anatomy.**
- **Optical centre:** each glyph is placed halfway between its box centre and its ink centroid, measured at Bold and applied equally to every weight.
- **Minimum gap:** 2.25 units at Bold for regular glyphs (1.24 pt at 11 pt, 2.5 px at 2x). Small variants are at least 2.9 units.

  | Gap | Regular | Small |
  |---|---|---|
  | camera lens | 2.31 | 3.01 |
  | memories dot | 2.41 | none |
  | settings dot | 2.56 | none |
  | photo sun to frame | 2.2 | none |
  | share head to tray | 2.4 | 2.4 |
  | gear teeth at the rim | about 2.5 | about 3.3 |

- **Perspective:** all flat and front-on.

**Pixel snapping** (ladder only). At each size and scale, the stroke is rounded to whole device pixels and the ink box origin is snapped to the pixel grid. That is one translation per glyph, not per-stem hinting; iOS renders symbols unhinted anyway.

**Bundle cost.** 20 symbols compile to a 109 KB iOS `Assets.car`, about 5 KB each.

## Proofs (all looked at)

| Sheet | File |
|---|---|
| (a) keyline grid, regular and small | `proofs/a-keylines.png` |
| (b) 11, 13, 15, 17, 20, 24 and 34 pt at 1x, 2x and 3x, pixel-snapped; small vs regular magnified | `proofs/b-size-ladder.png` |
| (c) inline with his font and SF Pro Rounded at 34, 17, 15, 13 and 11, light and dark | `proofs/c-inline-type-scale.png` |
| **(d) centrepiece:** custom vs weight-matched SF Symbols at 13, 17 and 24 pt, beside his font, SF Pro Rounded Medium and Regular, light and dark, plus both mockups done both ways | `proofs/d-custom-vs-sf.png` |
| (e) in-context mockups at 3x device pixels: tab bar (wins, camera, memories), glass toolbar (replay, share), glass close over a photo | `proofs/e-in-context.png` |
| compiled symbols at 9 weights and 3 scales | `proofs/validate-compiled-weights.png` |

## Self-review

| Glyph | Works | Needs the owner's eye / rule bent |
|---|---|---|
| camera | Clear silhouette; his O body; the tab melts into the body; the small lens holds at 11 pt. | Heaviest after photo (193 u²). It is wider than the landscape keyline's height allows (17 against 15.5) because of the shoulder. |
| wins | Unmistakably his block language. | **Least sure.** Solid fill breaks the "one stroke" rule on purpose, because his blocks are solid. It may read as "align left" in a tab bar, and it has no outline/fill pair for selected state. |
| memories | Distinct place mark, his rounded square on its corner with a tight tip. | A new concept: today's tab is `photo.stack`. The dot is dropped at small sizes. |
| close | His X; the most "him" of the set. | Crotch fillet eased from 1.3 w to 1.0 w. The horizontal feet are unusual for a close glyph. |
| back | Clean, balanced, optically centred (it sits 0.17 units right of box centre). | Lightest glyph (62 u²). That is normal for a chevron, and SF's chevron is lighter still. |
| share | Readable at every size; soft nooks under the head. | 19.5 units tall, past the portrait keyline. At Black the tray and arrow crowd. |
| replay | Squircle loop in his C spirit; strong at 34 pt. | The arrowhead overshoots the live area by 0.7 units. The loop is a rounded square, not a circle, which is a deliberate departure from convention. |
| plus | His + with a melted centre. | At Heavy and Black the fillet makes it read like a four-pointed star. |
| settings | Reads as a gear at 13 pt and up; the small variant is cleaner. | Teeth are constant size across weights, so at Ultralight the teeth look heavy against the thin ring. No fillets at the tooth roots. |
| photo | Classic frame, mountain and sun; the small variant still reads. | Heaviest glyph (216 u²). No fillets where the mountain meets the frame. |

## Verdict: custom vs weight-matched SF Symbols

**What the custom set gains.** In `d-custom-vs-sf.png` it is plainly the same hand as "Add a win" and "Your week": rounded-rectangle rounds, near-round ends, melted joins, and a heavier, friendlier colour (about 1.4x the ink of SF at the same weight). The tab bar gets a signature look no other app has.

**What weight-matched SF Symbols gain.**
- The same weight as his text, with finer, lighter detail.
- Zero drawing or maintenance.
- Every one of the app's ~45 glyphs and the 36 block-icon glyphs exists today.
- Built-in accessibility labels, RTL variants and the newer symbol effects (Draw) with no annotation work.
- Exact consistency with the chrome Strata cannot change: share sheet, context menus, map controls, PhotosPicker.

At 13 pt the two are nearly interchangeable. At 17 to 24 pt the difference is visible but not loud.

**Given "clean and minimal", ship weight-matched SF Symbols.** The custom set adds character, and character is the opposite of minimal. It is heavier on the page, it would need about 70 more drawings to cover the app, and on every system surface it would sit beside Apple's glyphs. The pilot proves the custom route is technically sound (valid, interpolating templates at every size). It is worth keeping as a later brand step, not as the default. Do not mix the two sets in one app.
