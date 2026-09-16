# Strata-Regular: the owner's alphabet as a font

Built 2026-09-16. Nothing in any repo checkout was touched and no simulator was run.

## Result

- `Strata-Regular.ttf` (10,928 bytes, TrueType `glyf`) and `Strata-Regular.otf` (12,508 bytes, CFF). Family "Strata", style "Regular", full name "Strata Regular", PostScript "Strata-Regular", version 1.000, OS/2 weight 400, width 5.
- **Validated.** `ttx` dump and recompile of both files: 0 warnings, 0 outline differences across all 89 glyphs. Winding checked per contour: TTF outer contours clockwise, CFF counter-clockwise. Overlaps removed with skia-pathops; a re-union of every glyph changes no area. Font bbox is -201 to 786, inside the 967/-211 line box, so nothing clips.
- **Ship the TTF, not the OTF.** The owner-head CLAUDE.md records that a CFF `.otf` gets clipped about 0.08 em off the bottom by `.contentTransition(.numericText())`. The OTF is here because it was asked for.
- 89 glyphs: A-Z, a-z, 0-9, the 22 drawn symbols, space, no-break space, figure space (U+2007, same width as a digit), `/` (placeholder), `.notdef`.

## How it was built

Scripts: `build.py`, `tools/outlines.py`, `tools/spacing.py`, `tools/placeholders.py`, `tools/render.swift` (a CoreText PNG renderer, so the proofs shape text the way iOS does, GPOS kerning included), `proof_*.py`, `measure_sf.py`.

**Glyph mapping was checked against the geometry, not the path order.** The SVG has 222 `<path>`s: 74 in the mask, 74 fills, 74 strokes, with identical `d`s. Assigned by row band (vertical centre) and then by x. The rows have 26, 26 and 22 glyphs, and a labelled sheet (`proofs/glyph-sheet.png`) confirms every character. Glyphs with several contours are kept whole: i and j (dot), ! (dot), = (2 bars), % (5 contours), B (3), and so on.

**One change from the brief, on purpose: the outlines include the outside stroke.** Figma draws an outside stroke as fill plus a 2-unit stroke masked to the outside, so the letter the owner sees is the fill grown 1 unit outward. Using the bare `d` fill would make every stem about 28% thinner than his drawing (5.1 vs 7.1 drawing units). Each glyph is the fill unioned with a round-joined 2-unit stroke. That is the same construction `tools/make_numeral_font.py` used for his digits, so the letters and digits are built the same way.

### Metrics (units per em 1000)

| | value | source |
|---|---|---|
| Cap height | **700** | E F H T tops, scale 17.37 font units per drawing unit |
| x-height | **536** (0.766 of cap) | a c e m n o r s u v w x z are all exactly 536; the drawing has no overshoot |
| Ascender | **748** | b d h k l |
| Descender | **-192** (j -199) | g j p q y |
| Vertical stem | **126** | I 128, l 124, n 124, o 124 |
| Horizontal stroke | 105 (E bar 108, o 102) | contrast 0.82 |
| hhea / typo / win | ascent 967, descent -211, gap 0; USE_TYPO_METRICS set | SF Pro Rounded's 1980/-432 at 2048 upem, scaled |
| **Line height ratio** | **1.178** | the same as SF Pro Rounded, so a `Text` in either face gets the same line box and `headerTopPadding(forTitleSize:)` still works |
| Space | 338 (half the n advance) | a wide face gets a wide space |
| Digits | tabular, advance **906** (0.906 em), mean LSB 71 | widest digit plus two figure bearings, each digit centred |

### Spacing: one number per side class

Bearings are fractions of the 126-unit stem. No glyph is spaced by eye.

| Class | Fraction | Units | Sides |
|---|---|---|---|
| H straight | 0.72 | 91 | H I M N U, left of B D E F K L P R, right of J |
| O round | 0.56 | 71 | O Q G S, left of C, right of B D P R |
| A diagonal | 0.08 | 10 | A V W X Y, right of K |
| T open | 0.14 | 18 | T, right of L |
| E arms | 0.30 | 38 | right of C E F, left of J |
| Z bar ends | 0.34 | 43 | Z |
| n straight | 0.64 | 81 | h i m n u, left of b k l p r f t, right of a d g j q |
| o round | 0.50 | 63 | o e s, left of a c d g q, right of b p |
| v diagonal | 0.08 | 10 | v w x y, right of k |
| r open | 0.22 | 28 | right of f r t |
| c terminal | 0.28 | 35 | right of c l, left of j |
| z bar ends | 0.30 | 38 | z |
| symbols / tight / figure | 0.40 / 0.20 / 0.48 | 50 / 25 / 60 | punctuation, brackets' inner side, digits |

The round classes sit close to the straight ones (0.78 of them) because his rounds are rounded rectangles: the outer contour of o fills 0.93 of its bounding box, against 0.81 for SF Pro Rounded. One adjustment was made after looking at the proof: open lowercase started at 0.12 and the f and t arms nearly touched the next n, so it went to 0.22. `proofs/spacing.png` shows HOHOHOH, HIHIH, nonononon, nnonn, oo, both alphabets, H-and-n-framed sequences, and every kerning pair with kerning off and on.

### Kerning: 39 GPOS pairs, measured

The values come from margin profiles, not typed numbers. For each pair, the gap between the two glyphs is sampled every 10 units up the zone they share (the cap zone for two capitals, the x-height zone otherwise). Each sample is capped at the straight-pair gap plus one stem, since white deeper than that is not seen as gap. The kern closes 70% of the difference between the mean gap and the gap between two straight stems. Largest: T with lowercase -90, LT -90, AT/TA/LV/LY/Ya -85. Smallest: aw -15, ov/oy -15. `ow` measured 0, so it was left out. The period and quote pairs were dropped along with the punctuation (see scope below).

## Numerals merge

The digits 0-9 come from `owner-head/Shared/StrataNumerals.ttf` (the brief said `Strata/`; the file lives in `Shared/`). They are scaled by 700/1443 so the cap and baseline match the capitals exactly, and they stay tabular.

Two things to know before this font replaces StrataNumerals:
1. **The advance changes from 0.947 em to 0.906 em, and the mean left bearing from 0.0892 to 0.071 em.** `StrataNumerals.opticalInset` and `GridConstants.tallyOpticalInset` would need the new number. The cap is 0.700 em against StrataNumerals' 0.7046, 0.5% lower.
2. **The digits are 47% heavier than the letters.** Stem 185 units against 126. The strip was drawn at a 28-unit cap and the letters at 38, both with the same 2-unit stroke, and the digits are drawn heavier to begin with. You can see it in "128 wins" and "9/14-9/20". It is his drawing, so it was not thinned. If he wants one colour of type, the fix is redrawing the digits on the alphabet's 40-unit body.

## Scope change and placeholders

Mid-task the owner narrowed the job: this face sets only the brand places, and everything else stays in one SF variant. The punctuation work was cut down to what those places need.

**Placeholders for the owner to redraw (1):**
- `/` U+002F: his `\` mirrored left to right. It is needed only if dates use this face. Proof: `proofs/placeholder-slash.png`. It is lighter than the digits beside it, and it drops a little below the baseline the way his backslash does.

**Not built, and what happens when they appear:** `. , ' " ? : ;` `< >`, curly quotes ’ “ ”, ellipsis …, and every accented letter. On iOS a missing glyph falls back glyph by glyph to the system font (SF Pro, not Rounded) at the same point size. `proofs/places.png` row "Café Réveille" shows it: the é is visibly lighter, narrower and shorter than the letters around it, and reads as a patch. **Do not rely on per-glyph fallback.** Check coverage with a `covers(_:)` test against the cmap, as research §2.5 already requires, and set the whole string in SF when it fails.

## Proofs (all rendered with CoreText; looked at)

- `proofs/glyph-sheet.png`: every glyph labelled with its code point.
- `proofs/spacing.png`: spacing strings, both alphabets, kerning off and on.
- `proofs/places.png`: every brand string at its real size, in this face and in SF Pro Rounded, on the light ground (#F6F7F9, `WarmBackground.top`) and the dark one (#211F1E), in `inkPrimary` and `inkQuiet`. `proofs/places-small-crop.png` is the 17pt-and-below rows at 2x. Widths are in `proofs/places-widths.tsv`.
- `proofs/sf-variants.png`: the same UI strings in this face, SF Pro Rounded Medium, SF Pro Medium and SF Compact Rounded Medium.
- `proofs/placeholder-slash.png`.

### Measured widths (CoreText, points)

| String | size | Strata | SF Pro Rounded Medium | ratio |
|---|---|---|---|---|
| Memories | 34 | 178.4 | 149.1 | 1.20 |
| Your week | 34 | 186.9 | 158.3 | 1.18 |
| Saturday 5 September | 34 | **414.8** | 337.9 | 1.23 |
| 128 (tally) | 34 | 92.4 | 57.4 | 1.61 |
| Add a win | 17 | 88.0 | 75.0 | 1.17 |
| 9/14-9/20 | 15 | 101.6 | 71.3 | 1.42 |

Across the alphabet, the average advance is 0.658 em against SF Pro Rounded's 0.552: **19% wider**. On the brand strings it runs 17-23% wider for words and 42-61% wider for numbers.

### Where it reads well

- **Screen titles at 34** (Memories, Your week, Profile). This is the face at its best, on both grounds: distinctive, even colour, legible at a glance.
- **Counts on their own** (tally at 34, streak figure at 28, badge at 13). The heavy tabular digits are the strongest thing in the proof and hold up down to 13.
- **Sheet titles at 17** ("Add a win", "Edit"). The single-storey geometric a and the flat terminals still read cleanly at 17.

### Where it struggles

- **D reads as O, and B reads as 8.** At 15, "Done" reads "Oone". "ALBUMS" and "SEPTEMBER" read "AL8UMS" and "SEPTEM8ER" at 13 and 11. S and 5 are near twins as well ("Saturday 5 September"). His D, O, B and 8 are all rounded rectangles that differ only in small corner details, and those details vanish below about 17pt. This is the deciding finding for buttons and section labels.
- **Long dynamic titles overflow.** "Saturday 5 September" at 34 is 415pt against a 370pt text column.
- **Dates:** "9/14-9/20" is legible at 15, but the heavy digits, the light placeholder slash and the lighter hyphen give the line an uneven colour, and it is 42% wider than SF.
- **11pt and below:** the M in "Memories" clots into a blob at 10, and caps-only labels hit the B/8 problem again.

## Recommendation

### (a) The places this face should set

Grounded in `research-visual-cohesion.md` §2.1-2.6 and in the proofs above.

**Set in Strata:**
1. **Screen titles, 34pt relative to `.largeTitle`:** Memories, Profile, Settings, Plan, Your week, Your month (research §2.5 phase 1, §2.3 "Screen title"). One per screen (§2.6 rule 1). This replaces the plan for per-word SVGs: the font is real text for VoiceOver, scales with Dynamic Type, and needs no imageset per word.
2. **Dynamic titles** (the day album "Saturday 5 September", place collection names): **only behind a coverage check and a width check.** Fall back to SF for the whole string when a glyph is missing, and allow `minimumScaleFactor` (about 0.85) or a shorter date format. At full width "Saturday 5 September" does not fit.
3. **Counts, the digits alone** (research §2.1 numeral table): tower tally, replay close count, replay running day number, profile streak figures, month block day numeral, map cluster badge, camera countdown, widget counts. They already use his digits; this font can replace StrataNumerals once the inset constant is updated (see Numerals merge). The word beside a count stays SF, as already settled.
4. **Sheet titles at 17:** "Add a win", "Edit" (research §2.5 items 4-5).

**Keep in SF for now, with the reason:**
- **Buttons (Done, Cancel, Save, Add) and short uppercase section labels.** In the proof "Done" reads "Oone" and "ALBUMS" reads "AL8UMS". This matches research §2.2, which puts buttons and section labels in SF. **It unlocks if the owner redraws D (a flat left stem with a visibly rounder bowl than O) and B (a waist notch that 8 lacks).** Then only the brief words (Done, Save, Add, Cancel) should move, at 17, not 15.
- **Dates.** Legible, but not yet good. Move them when the owner draws a `/` and `-` at the digits' weight, and only for the standalone replay range under "Your week". Dates inside sentences stay SF.
- **Anything at 13 or below that contains letters,** tab labels, sentences, form rows and captions (research §2.6 rule 4, and the 11pt and 10pt rows in the proof).

### (b) The one SF variant for everything else: **SF Pro Rounded**, at Regular and Medium

Measured against the owner's face (`measure_sf.py`, `proofs/sf-measure.json`), with the Medium cut shown for each:

| Face | x/cap | stem/em | contrast (h/v) | l terminal (1.0 = square cut) | o squareness | avg advance/em |
|---|---|---|---|---|---|---|
| **Strata (owner)** | 0.766 | 0.125 | 0.82 | 0.65 | 0.929 | 0.622 |
| **SF Pro Rounded Medium** | 0.734 | 0.108 | 0.81 | 0.63 | 0.811 | 0.505 |
| SF Pro Medium (Text opsz 17 / Display 34) | 0.753 / 0.729 | 0.109 | 0.82 / 0.81 | 1.00 | 0.815 / 0.811 | 0.558 / 0.505 |
| SF Compact Rounded Medium | 0.771 | 0.102 | 0.79 | 0.64 | 0.836 | 0.502 |

SF Pro Rounded matches the two things you notice first: **round terminals** (0.63 against 0.65; SF Pro and SF Compact are square-cut at 1.00) and **stroke contrast** (0.81 against 0.82). Its Medium stem is also the closest to his weight. SF Compact Rounded matches the x-height a little better and its o is a little squarer, but it is a watchOS system face. It is not available as a design on iOS, and Apple's SF licence does not allow bundling it, so it cannot ship. SF Pro Text/Display has the right x-height at 17 but square terminals, which fight his rounded ends in the proof. SF Pro Rounded is also what the app already uses, so choosing it moves nothing.

### (c) The reduced type scale: 5 sizes, 2 weights

Sizes are Dynamic Type defaults, and each stays a text style so accessibility scaling still works. Weights are **Regular 400** (SF Pro Rounded Regular, and Strata's single drawn cut) and **Medium 500** (SF Pro Rounded Medium). Semibold goes. The owner's face has one cut, and its heavy drawn stem already does the job of emphasis.

| Size (style) | Strata sets | SF Pro Rounded Medium sets | SF Pro Rounded Regular sets |
|---|---|---|---|
| **34** (`.largeTitle`) | screen titles, tally, replay count | - | - |
| **17** (`.body` / `.headline`) | sheet titles | `headerMedium`; **merged in:** `headerLarge` (20), `blockTitle` (16) | `bodyLarge`; **merged in:** `bodyMedium` (16) |
| **15** (`.subheadline`) | - | `headerSmall` (buttons); **merged in:** raw 15 semibold (widget "wins") | `screenSubtitle`, dates |
| **13** (`.footnote`) | map badge digits | `sectionLabel` (+0.8 tracking); **merged in:** `photoCaption` (12), raw 13 semibold and 13 medium, raw 12 medium | `bodySmall`; **merged in:** `caption` (12) |
| **11** (`.caption2`) | - | `caption2` (chart axis, tiny labels); **merged in:** raw 10 and 9 medium | - |

Token merges, in short:
- `headerLarge` 20 → 17 Medium
- `blockTitle` 16 → 17 Medium
- `bodyMedium` 16 → 17 Regular
- `caption` 12 → 13 Regular
- `photoCaption` 12 → 13 Medium
- the widget's 13 and 15 Semibold → Medium at the same size
- delete the eight tokens with zero call sites (counted by grep): `brandLogo`, `brandHeader`, `brandSubheader`, `brandHeroDate`, `brandCardTitle`, `appTitle`, `miniBlockTitle`, `miniBlockIcon`. Research §6 item 17 flags the same dead tokens.

**Outside the scale on purpose:** sizes derived from geometry rather than chosen, which are the month block's `cell * 0.16` numeral, the camera countdown at 96, the widget's 30 and 16 counts, and SF Symbol glyph sizes. The system tab bar's 10pt labels are also outside it, because the system owns them.

The biggest visual change in this scale is `headerLarge` dropping from 20 to 17 in onboarding, Profile and the head maker. If those headings look too quiet at 17, the alternative is to set them in Strata at 17, not to keep a sixth size.
