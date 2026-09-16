# An optional icon on a win's block

Build-ready spec. Written against `/Users/jaydenbetts/StrataWork/owner-head`
(read only; nothing in any checkout was edited).

The owner's words: *"add another way for those that don't want to add an image
to their wins to still visualize them. I was thinking of adding an optional icon
to the blocks, styled in a way that feels part of the block styling, not some
slapped on sticker, for those that want to add more character to the styled
blocks without the need for a photograph."*

**Recommended treatment in one line:** a glyph the person chose, **debossed into
the block's own colour** — the glyph's body in `warmBlack` at 0.14, with a white
lip at 0.28 peeking 0.036 of the glyph size below it, so the mark is a recess in
the surface lit by the same light the rim is lit by, with no hue, no outline and
no elevation.

---

## 0. What could not be read, and why

`Bash` returned exit 1 on every call in this session (including `echo test`), so
there was no `grep`, no `ls` and no directory listing. Everything below comes
from reading files by absolute path. **Three files were named in the brief and
could not be located by guessing paths, and the implementer must check them
before shipping:**

- the widget's view (`TowerWidgetView`, referenced from
  `/Users/jaydenbetts/StrataWork/owner-head/StrataWidget/StrataWidget.swift:19`)
  — needed to check its cell size against the relief floors in §2.6
- the map's block/annotation view — same check
- Spotlight / App Intents indexing for a win — §5.4 states the rule; the call
  site is unverified

Files read in full and relied on:
`CLAUDE.md`,
`Strata/Views/BlockChrome.swift`,
`Strata/Views/BlockContent.swift`,
`Strata/Views/BlockFace.swift`,
`Strata/Views/FlippableBlockView.swift`,
`Strata/Views/MergedGroupView.swift`,
`Strata/Views/MonthTowerView.swift`,
`Strata/Views/AddWinSheet.swift`,
`Strata/Views/ReplayFrame.swift`,
`Strata/Views/ReplayCard.swift`,
`Strata/Views/ShareTowerCard.swift`,
`Strata/Models/GridConstants.swift`,
`Strata/Models/CategoryColors.swift`,
`Strata/Models/Habit.swift`,
`Strata/Models/HabitLog.swift`,
`Strata/Models/BlockMerge.swift`,
`Strata/Models/Replay.swift`,
`Strata/ViewModels/TowerViewModel.swift`,
`Strata/Services/QuickWinService.swift`,
`Shared/WidgetSnapshot.swift`.

---

## 1. The idea, precisely

### 1.1 How this differs from "No icon on the block"

The recorded decision is at `Strata/Views/BlockContent.swift:132-138`:

> No icon on the block. The colour already says which category it is, and the
> icon was repeating that in the one place where two same-coloured blocks are
> trying to look like one object — a corner mark halfway down a merged shape is
> the clearest possible statement that it is two.

That decision killed **a category badge**. It had four properties, and the new
thing has none of them:

| the badge that was removed | the icon being proposed |
| --- | --- |
| **Derived** from `habit.category`, so it appeared without anyone asking | **Chosen**, one at a time, default none. A block only has one because a person pressed it |
| **Redundant** — it said the same thing the colour already said | **Additive** — it says something no other property of the block says. Colour is one of six; the glyph is one of thirty-six and is the person's own word for this win |
| **Automatic**, therefore on *every* block, therefore at every cell's corner at exactly the cell pitch — which is what drew the grid through a merged shape | **Sparse and irregular.** The blocks that have one are the ones somebody chose, so there is no rhythm at the cell pitch for the eye to read as tiling |
| **A corner mark**, i.e. chrome placement, and drawn as flat ink laid on top | **A recess in the field**, i.e. surface placement, drawn as a deformation of the block's own colour with no ink of its own |

The old failure was not "a mark on a block". It was *an automatic, redundant
mark, in a corner, at the cell pitch.* Every one of those four is reversed here.

### 1.2 The unit: what an icon IS

**Per win, chosen by the person, from a curated set of 36 SF Symbols, default
none.**

- **Who chooses:** the person, and nobody else. The app never picks one. See
  §6.3 for why there is no suggestion in v1.
- **From what set:** 36 fill-variant SF Symbols, six groups of six (§4.3). No
  search, no browser, no arbitrary symbol name.
- **When:** in `AddWinSheet`, which is both the add sheet and the edit sheet
  (`editing:`), under the same condition the Colour field already uses
  (`photo == nil || isEditing`, `AddWinSheet.swift:124`). The one-tap path does
  not see it and does not gain a step.
- **What it means:** nothing to the app. It is not a category, it does not
  filter, it does not reach Siri or a Focus filter. It is a mark the person put
  on their own block. That is the whole claim it makes, and it is a claim only
  they can make, which is why the app must never write one.

### 1.3 Rejected alternatives for the unit

**Emoji instead of SF Symbols.** Rejected. An emoji is a full-colour bitmap from
a system font. It cannot be debossed (there is no glyph shape to press in, only
a picture to paste on), it drags a hue onto a block whose hue is the thing that
means something, and it renders differently on every OS version — so a tower
photographed for the App Store would not match a tower on a phone. An emoji on a
coloured square is precisely "a slapped on sticker". SF Symbols are vector paths
the app fills itself, which is what makes the relief in §2 possible at all.

**Remembered per repeated title.** Rejected as a stored rule. `QuickWinService.logWin`
creates a **new `Habit` per win** (`QuickWinService.swift:116`), so there is no
"the Ran 5k habit" to hang an icon on — a per-title memory would be a lookup by
string, and renaming one win would silently change a different one. The tower is
a record of events; a win happened once. See §6.3 for the recall convenience
this could become later, and the bar it has to clear.

**Per log rather than per habit.** Rejected. `AddWinSheet.save()` writes `title`,
`category` and `blockSize` to the **`Habit`** (`AddWinSheet.swift:619-626`); the
log carries the occurrence and its photograph. The icon is a description, so it
belongs beside the title.

---

## 2. How it is drawn so it belongs to the block

This is the heart of it, so the three candidates are worked through against how
`BlockSurface` actually builds its light, not against a mood.

### 2.0 What BlockSurface establishes

From `BlockChrome.swift` and `GridConstants.swift`, the facts the glyph has to
live inside:

- The block is **one flat colour** (`BlockFace.swift:54`), lit **from above** by
  a white rim that is full-strength on the top edge and falls to
  `blockRimFalloff` 0.45 elsewhere (`BlockChrome.swift:72-85`). A dark outline
  was measured and rejected because "it pulls the edge TOWARDS the background,
  which is the opposite of what an edge facing a light does".
- A **frosted band** over the bottom 26% (`blockBandStart` 0.74), carrying a
  white wash of `blockScrimOpacity` 0.10 — halved from Figma's 0.20 because "the
  colour stays colour all the way down".
- **Light, not heavy**: shadow 0.07 at 7pt, veil caps at 0.26.
- The block's vocabulary is exactly two non-colours: **white** (the rim, the
  band, the title) and **`warmBlack` `#403D39`** (the contact shade, the veil).

The glyph must be built from those two and nothing else. Any third colour is a
new thing on the block, and a new thing on the block is decoration.

### 2.1 Candidate A — debossed into the block's own colour · **CHOSEN**

The rim's own sentence, applied to an interior edge. Light comes from above, so
a recess pressed into the surface has its **upper inner wall in shadow** and its
**lower lip catching the light**. Construction, which is the classic letterpress
inversion (dark fill, light shadow offset *away* from the light source — see
§8 references):

```
ZStack {
    Image(systemName: symbol)                     // the lit lower lip
        .foregroundStyle(.white.opacity(blockIconLip))      // 0.28
        .offset(y: size * blockIconLipRatio)                // +0.036 · size
    Image(systemName: symbol)                     // the recess floor
        .foregroundStyle(AppColors.warmBlack.opacity(blockIconShade))  // 0.14
}
.symbolRenderingMode(.monochrome)
```

Two opaque fills, **no blur, no `.drawingGroup()`** (banned on block views,
`CLAUDE.md`), no shape of its own, no edge. It adds zero hue: on a Health block
the recess is a darker Health green and the lip is a paler Health green. It
cannot read as a sticker because a sticker has an outline and a deboss has none
— it is the surface, bent.

Fill variants throughout, and `.monochrome`: hierarchical rendering assigns
different opacities per layer, which would mean the *depth of the recess* varied
inside one glyph, which is not a thing a press does.

**Why it wins:** it is the only one of the three built from the block's existing
ingredients and the block's existing light. It also survives the merged run
unchanged (§3.2), because a dent in a wall is a property of the wall at that
point rather than an edge that says where one tile stops.

### 2.2 Candidate B — a tonal glyph in the frosted band or the field · rejected

Tonal is the right instinct and the wrong place. Three problems, in order of
severity:

1. **The band is spoken for, twice, and on a merged run it exists once.**
   `MergedGroupView` anchors one band to the bottom row of the whole shape
   (`MergedGroupView.swift:59-65`) — a member four rows up has no band under it
   at all, so a glyph placed in the band would vanish for most members of every
   run. That alone disqualifies it.
2. The band already carries the title on the tower (`BlockContent.swift:176-178`)
   and the day numeral on the month tower (`MonthTowerView.swift:91-107`). Three
   things in a 26% strip is a caption bar, which is the one thing the block has
   twice been pulled back from being.
3. In the **field** (rather than the band) a flat tonal glyph is simply the
   debossed one with the lip deleted — strictly less information for the same
   ink. It is kept, though, as the small-size fallback (§2.6): below the relief
   floor a lip of 0.8pt is not resolvable, and a flat mark is then the honest
   drawing.

### 2.3 Candidate C — a large cropped watermark behind the title · rejected

Attractive, and wrong here for four reasons:

1. **It occupies the photograph's slot.** A block is "a coloured block that
   becomes a photograph" (`BlockFace.swift:50-53`). A large mark filling the
   field is a second thing competing for the same region, and the moment a
   photograph arrives it has to be deleted rather than moved.
2. **Cropping makes the mark's silhouette a function of the block's edge**, so
   the same icon is a different shape on a 1x1, a 2x1 and a 2x2. A mark that
   changes shape with its container has stopped being a mark.
3. At an 86.5pt cell a glyph cropped to fill the field is 60 to 80pt with its
   subject running off two edges — unrecognisable. The pattern needs a card
   250pt across. **Nowhere in this app is a block that large.**
4. It reads most like decoration of the three, which is the thing that is
   explicitly out.

### 2.4 Geometry and tokens

New block in `GridConstants.swift`, after `// MARK: - Block Rim`:

```swift
// MARK: - The block's chosen icon
//
// A mark somebody pressed into their own block. Not a category badge — see
// BlockContent.swift for the decision that removed that, and why this is a
// different thing. It is drawn from the block's own two non-colours (white and
// warmBlack) in the block's own light direction, so it adds no hue, no edge and
// no elevation.

/// Glyph point size, as a fraction of the CELL (not of the block). A 2x2 is a
/// bigger wall, not a bigger mark, so it steps up once and stops.
static let blockIconRatio: CGFloat = 0.26        // 1x1 and 2x1  -> 22.5pt at 86.5
static let blockIconRatioLarge: CGFloat = 0.34   // 2x2          -> 29.4pt at 86.5

/// The recess floor: warmBlack, in the glyph's own shape.
static let blockIconShade: Double = 0.14
/// The lit lower lip of the recess. White, because the rim is white and this is
/// the same light landing on the same kind of edge.
static let blockIconLip: Double = 0.28
/// How far the lip peeks below the recess, as a fraction of the glyph size.
/// 0.81pt at a 22.5pt glyph — 2.4 device px at 3x, which renders crisp, exactly
/// as blockRimWidth is sized to.
static let blockIconLipRatio: CGFloat = 0.036

/// The glyph is centred in the block's FIELD, and the field is everything above
/// the frosted band. Derived, not chosen: half of blockBandStart.
static var blockIconCenterY: Double { blockBandStart / 2 }   // 0.37

/// Block short side below which the relief is not resolvable and the glyph is
/// drawn flat. At 56pt the lip is 0.52pt, which is 1.6 device px at 3x — the
/// last size at which it is a lit edge rather than a rounding error.
static let blockIconReliefFloor: CGFloat = 56
/// And below which no glyph is drawn at all: under 32pt the glyph is 8pt, which
/// is not a symbol, it is a speck.
static let blockIconFloor: CGFloat = 32
/// The flat fallback below the relief floor. Heavier than the shade, because it
/// is now carrying the mark on its own.
static let blockIconFlat: Double = 0.18
/// Increase Contrast: the relief is dropped and the glyph is drawn the way the
/// title is drawn, at the title's weight of voice. See the measurements.
static let blockIconContrast: Double = 0.95

static func blockIconSize(cell: CGFloat, columnSpan: Int, rowSpan: Int) -> CGFloat {
    cell * (columnSpan > 1 && rowSpan > 1 ? blockIconRatioLarge : blockIconRatio)
}
```

Placement, spelled out, at the tower's 86.5pt cell:

| block | glyph | centre y | glyph spans y | title spans y | band starts |
| --- | --- | --- | --- | --- | --- |
| 1x1 (86.5 × 86.5) | 22.5pt | 32.0 | 21 – 43 | 61 – 79 | 64 |
| 2x1 (177 × 86.5) | 22.5pt | 32.0 | 21 – 43 | 61 – 79 | 64 |
| 2x2 (177 × 177) | 29.4pt | 65.5 | 51 – 80 | 138 – 165 | 131 |

Clear of the title by 18pt on a 1x1 and clear of the band in every case, because
the centre is *defined* as the middle of the region above the band. Naming or
unnaming a win never moves the glyph: the two are anchored to opposite ends.

### 2.5 Measured contrast, on every palette colour, in both schemes

Computed, not eyeballed, per `CLAUDE.md` ("Contrast is arithmetic, so compute
it"). WCAG relative luminance, sRGB channel-wise compositing.

Base colours (`CategoryColors.swift`) and their relative luminance L:

| category | hex | L |
| --- | --- | --- |
| health | `0EAD74` | 0.3123 |
| work | `40A9FF` | 0.3669 |
| creativity | `AF9CFA` | 0.3979 |
| focus | `FDB54F` | **0.5449** (lightest) |
| social | `F97066` | 0.3269 |
| mindfulness | `EC85B4` | 0.3790 |
| unlabeled | `9C9791` | **0.3124** (darkest, with health) |

`warmBlack` `403D39` has L 0.0472.

**Shade** (warmBlack 0.14 over base), ratio against the base beside it:

| category | composite | ratio |
| --- | --- | --- |
| unlabeled | `8F8A84` | **1.18 : 1**  ← worst |
| health | `159D6C` | 1.19 : 1 |
| work | `409AE3` | 1.20 : 1 |
| social | `E76B60` | 1.21 : 1 |
| creativity | `9F8FE4` | 1.21 : 1 |
| mindfulness | `D87EA6` | 1.21 : 1 |
| focus | `E2A44C` | **1.23 : 1**  ← best |

Spread 0.05 across the whole palette. **One alpha works for all seven**, which
is the finding that makes this a single token rather than a second palette.

**Lip** (white 0.28 over base), ratio against the base:

| category | ratio |
| --- | --- |
| focus | **1.17 : 1**  ← weakest |
| creativity | 1.25 : 1 |
| mindfulness | 1.27 : 1 |
| work | 1.29 : 1 |
| social | 1.32 : 1 |
| health | 1.34 : 1 |
| unlabeled | **1.34 : 1**  ← strongest |

**The number that matters is the relief edge** — lip against shade, which is the
boundary the eye actually resolves:

| category | relief edge |
| --- | --- |
| focus | **1.44 : 1**  ← worst colour |
| creativity | 1.50 : 1 |
| mindfulness | 1.53 : 1 |
| work | 1.55 : 1 |
| social | 1.58 : 1 |
| health | 1.60 : 1 |
| unlabeled | 1.60 : 1 |

1.44 to 1.60 across seven colours. That is the intended band: comfortably above
the ~1.1 at which a 22pt shape stops being perceptible, and comfortably below
the 1.77:1 that the **white title on a Focus block already measures** — so the
mark is quieter than the words, everywhere, by construction.

**Focus yellow is the colour to look at on a frozen frame.** It is the lightest
in the palette and it is where both the lip and the relief edge are weakest. If
it fails the look, the lever is the **lip alone**: 0.28 → 0.34 takes Focus's
relief edge 1.44 → 1.49 and every other colour up by about the same. Do not
touch the shade to fix it; the shade is what "light, not heavy" is spending.

**Both schemes: the same numbers, and that is deliberate.** The category colours
are fixed hex and do not adapt. The glyph is measured against the block's fill,
which does not change with the scheme — so the glyph does not either. The rim
*does* ease in dark mode (`BlockChrome.swift:73-74`), and the reason it does is
that the rim is measured against the **page** (255 against a 26 ground). The
glyph never meets the ground. Adding a scheme branch here would be inventing a
variable, and `CLAUDE.md` is explicit that an ink and a surface are different
problems: this is neither, it is relief, and relief follows its own surface.

### 2.6 Every scale the app draws a block at

| where | cell / block side | glyph | treatment |
| --- | --- | --- | --- |
| tower, 1x1 / 2x1 | 86.5 | 22.5pt | full relief |
| tower, 2x2 | 177 short side | 29.4pt | full relief |
| month tower | 86.5 | — | **no icon at all** (§3.7) |
| share card (`ShareTowerCard`, cell capped at 82) | 82 | 21.3 / 27.9pt | full relief (82 ≥ 56) |
| map annotation | ~44pt | 11.4pt | **flat** (`blockIconFlat` 0.18, no lip); clusters draw none |
| replay, live | scales 1.0 → ~0.11 | scales with the block | relief until the block's short side crosses 56; fades on the title's own curve (§3.5) |
| replay poster on the shelf | 132pt card, tower scaled down | — | below `blockIconFloor` in practice; none |
| widget (small, accessoryRectangular) | **unverified, see §0** | per the same function | apply the floors; if the widget cell is under 32pt, none |
| picker tile in `AddWinSheet` | 44pt tile, glyph 22.5pt | 22.5pt | full relief, on the currently chosen colour |

The three rules, stated once so they are not re-derived per site:

1. block short side ≥ `blockIconReliefFloor` (56) → **shade + lip**
2. 32 ≤ short side < 56 → **flat**, `warmBlack` at `blockIconFlat` 0.18
3. short side < `blockIconFloor` (32) → **nothing**

### 2.7 Reduce Transparency and Increase Contrast

**Reduce Transparency: no change, and here is why.** The glyph uses no
`Material`, no `.blur`, no backdrop and no vibrancy — two solid fills at fixed
alphas over an opaque block. There is no translucency to reduce. (The alphas are
compositing, not translucency: the thing behind them is the block's own opaque
fill, never the page.) Writing a branch here would be a branch that changes
nothing, which is worse than none.

**Increase Contrast: drop the relief, draw flat white at 0.95.** A mark whose
whole design is "only just visible" is exactly the mark that disappears for the
person who asked the system for more contrast. Under
`\.accessibilityDarkerSystemColors`:

```
Image(systemName: symbol).foregroundStyle(.white.opacity(blockIconContrast))
```

Measured against the worst colour (Focus): **1.72 : 1**, which sits alongside the
block's existing white title at 1.77:1. The target is deliberately *the title's
own legibility*, not WCAG AA — white type on Focus yellow has never cleared AA in
this app and that is a pre-existing property of the palette, not something a new
feature should either fix or make worse. Same voice as the words beside it.

**Smart Invert:** `BlockFace` already sets
`.accessibilityIgnoresInvertColors(hasPhoto)`. The glyph is only ever drawn when
there is no photograph, so it inverts with the block, which is correct — it is
part of the surface.

---

## 3. Interaction with what exists

### 3.1 A win with both an icon and a photograph — **the photograph wins**

The glyph is **not drawn** when `hasPhoto`. The choice is **kept, never cleared**
— remove the photograph and the glyph comes back, exactly as the category colour
does (`AddWinSheet.swift:120-123`: "The category is KEPT, not cleared").

Three reasons, and they all say the same thing:

1. A deboss is a deformation of **the block's own surface**. A photograph is not
   that surface, it is a picture laid over it. Pressing a glyph into a photograph
   is not a press, it is a decal — which is the sticker the owner ruled out.
2. The app has already decided that a photographed block hides its colour, and
   hides the colour question at capture, because "a block with a picture on it
   shows the picture" (`AddWinSheet.swift:105-112`). The glyph lives in the same
   layer as the colour and inherits the same rule.
3. The photograph already gives that win its character. Giving it a second
   character mark is the same fact twice, which is the mistake the tower header
   already made once ("the filter said Day while the title said Today").

**Do not move it to the band on a photographed block.** A glyph banished to the
band on top of a picture is a badge, in a corner, with a veil under it — every
property of the thing that was removed.

Merge is unaffected: photographed blocks already never merge
(`BlockMerge.swift:78`).

### 3.2 A merged run — **the glyph travels with the label, unchanged**

`BlockMerge.groups` merges adjacent same-colour blocks, and **named blocks merge
too** now (`BlockMerge.swift:65-77`); a member draws `BlockContentOverlay` and
nothing else (`FlippableBlockView.swift:77-93`), because the run's fill, rim,
band and shadow are drawn once by `MergedGroupView`.

**Rule: the glyph is part of `BlockContentOverlay`, so it travels onto the merged
surface exactly where it would sit on its own cell. It is never suppressed, never
moved, never drawn once for the group, and never given an outline or a ground.**

Why this does not re-make the old mistake, in three parts:

- **The mark has no edge.** The old badge was flat ink laid on top; it had a
  silhouette, and a silhouette at a cell corner is a tile boundary drawn in
  miniature. A deboss has no silhouette — it is the same colour, dented. A dent
  in a wall does not tell you where the bricks are.
- **It is not at the cell pitch.** The old badge was on *every* block, at the
  *same corner offset*, so a four-block run showed four marks at exactly the cell
  pitch, which is the visual definition of a grid. A chosen icon appears on the
  blocks somebody chose, so there is no regular rhythm to read.
- **The run is guaranteed one colour.** Merging requires identical
  `displayCategory` (`BlockMerge.swift:111`), so every recess in a run is in the
  same tone. The relief cannot betray a seam because there is no tonal step to
  betray.
- **The band problem does not arise**, because the glyph is centred in the field
  and not in the band, and on a merged run the band exists only at the floor of
  the shape (§2.2).

The owner has already accepted the stronger version of this — four short titles
sitting on one green shape, "the way words sit on a wall". A glyph is quieter
than a title.

**One thing to look at and not assume:** a run of four blocks where the person
chose the *same* glyph for all four will show four identical marks at the cell
pitch. That is the one configuration that could read as tiling, and it is also a
configuration the person deliberately built. Verify it in the frozen-frame pass
(§7.4), and if it fails, the answer is **not** to suppress or reposition — it is
to accept it, because the person said those four wins were the same thing.

### 3.3 An unnamed win with an icon — **draws the glyph, and still no text**

"A block with no name shows no text at all." That rule is about *an unnamed win
claiming a name* — `BlockContent.swift:116-118`: "'Win' is not a name, it is the
absence of one". A glyph is not a name and claims nothing about what the win was
called. It is the same class of fact as the colour and the size: a property of
the block that the person chose.

This is a stronger case than the month tower's day numeral, which the codebase
already accepts as not-an-exception (`MonthTowerView.swift:79-89`) — the numeral
is app-generated, and this is person-chosen.

**And this is the icon's best case.** An unnamed, photoless block is the block
with the least to look at in the whole app, and it is exactly the block the
owner is asking to give character to. The glyph's position does not depend on
the title, so naming a win later adds words below a mark that does not move.

### 3.4 The frosted band's title

Nothing changes. The title stays bottom-left, one size, ellipsised
(`BlockContent.swift:140-165`). The glyph is above the band; the title is in it.
The 18pt gap on a 1x1 is measured in §2.4.

The one edit: `BlockContentOverlay` needs the block's `width`/`height` to place
the glyph at `blockIconCenterY`. Pass them down from `BlockFace`, which already
has both — **do not put a `GeometryReader` in a block overlay**; that is a
measurement per block per body on the tower's hot path.

### 3.5 The drop, the dance, the lift and the tap

**Nothing to do, and that is the point.** `BlockContentOverlay` is inside
`BlockFace`, which is inside `FlippableBlockView`, so every transform the block
receives carries the glyph with it:

- the fall's `.offset` and the landing squash (`FlippableBlockView.swift:219-228`)
- the dance's lift and tilt (`GridConstants.danceLift`, `danceTilt`)
- the lifted block's `.scaleEffect(1.06)` (`FlippableBlockView.swift:114`)
- the replay's `scaleEffect(x:y:)`, `rotationEffect` and `fallOffset`
  (`ReplayFrame.swift:165-168`)

The tap bounce is a **non-uniform** squash (`tapSquashX` 1.02, `tapSquashY`
0.97), so the glyph squashes with the surface. Correct: a mark pressed into a
surface deforms when the surface does. A glyph that held its shape through a
squash would prove it was floating.

**In the replay, the glyph fades on the title's own curve.**
`ReplayFrame.titleOpacity(at:)` already fades block titles across camera scale
0.55 → 0.45 (`ReplayFrame.swift:215-221`), and that curve is hand-tuned against a
real failure (a finished month reading as "a ribbon covered in dust"). Reuse it
verbatim — pass the same `overlayOpacity` the title gets. Two reasons: a replay
must never have a moment where the words are gone and the marks are not, and
reusing the curve means no new number to tune and no new way to be wrong.

### 3.6 The perfect-day patina

Nothing to do. The patina is an overlay on `chromedBody` with
`.blendMode(.overlay)` (`FlippableBlockView.swift:211-217`), applied outside
`BlockFace`, so it already passes over the title and will pass over the glyph the
same way. A gold wash over a recess is correct — the wash is light on the
surface, and the recess is in the surface.

### 3.7 The month tower — **no icons, ever**

`MonthTowerView` draws **one block per day**, not per win. A day has no icon,
because there is no answer to "whose?" — a day with four wins could have four
different marks and a day with one would have one, which would make the month
tower's blocks mean two different things depending on how busy the day was.

This is the same reason the month tower does not merge
(`CLAUDE.md`: "in a month, two touching blocks are two different days"). The
month block already carries a day numeral in the band; adding a mark above it
would put two app-drawn things on a block whose whole job is to be a tap target
for a date.

### 3.8 The map marker

- A map block with a photograph: photograph, no glyph (§3.1). Most map blocks
  are photographed — the map is populated from `latitude != nil`, which only a
  photographed win ever has (`HabitLog.swift:61-86`).
- A map block that is a **cluster** draws no glyph, for §3.7's reason.
- A single photoless win on the map at ~44pt: **flat**, `blockIconFlat` 0.18, no
  lip. At 44pt the lip would be 0.4pt — invisible work, and a relief on a busy
  map ground is effort nobody can see.

### 3.9 The widget's snapshot

`WidgetSnapshot.Block` gains `var symbol: String? = nil` (§5.2). The widget
applies the same three floors. **Unverified: the widget's own cell size** — see
§0. If the tower drawn in a small widget uses a cell under 32pt, the answer is
"no glyph", and that is fine: a home-screen widget is a glance at a shape, and
the snapshot carrying a field the widget currently ignores costs a few bytes and
means the contract is right when the widget grows.

---

## 4. Choosing one, in the app

### 4.1 Where the picker lives

**`AddWinSheet`, and only there.** It is already both the add sheet and the edit
sheet, so there is one picker to build and one to keep right.

It goes **directly under the Colour field**, inside the same condition:

```swift
if photo == nil || isEditing {
    field("Colour") { categoryControl }
    field("Icon")   { iconControl }        // new
}
field("Size") { sizeControl }
```

Same condition, same reason, stated in the comment already there: a block with a
picture on it shows the picture, so asking about what is under it at capture is
a decision that changes nothing you can see, on the screen that has to be fast.

**The one-tap path does not change.** Pressing the tower's empty slot goes
through `QuickWinService.logWin`, which never opens a sheet and leaves
`iconSymbol` nil. The camera path opens `AddWinSheet` already holding a photo, so
both Colour and Icon are hidden. **No path gains a step.**

### 4.2 How the control looks

**One tile, not a row of thirty-six.** `AddWinSheet`'s Colour control is six
34pt circles in 44pt targets; a second row of glyph chips beside it would read as
a second colour picker and double the weight of the sheet. Premium is
subtraction.

The control is a **single 44pt block**, drawn with the real `BlockSurface` at
`scale: 44 / GridConstants.blockReferenceCell`, filled with the colour currently
selected above it, carrying the chosen glyph **debossed exactly as the block will
carry it**. So the control is a picture of the outcome, which is the rule the
photo well and the size picker already follow ("the thing you are making looks
like the thing it becomes", `AddWinSheet.swift:19-21`).

- **Empty**: the same dashed recess the empty photo well and the tower's slot
  use — `slotInk` at 0.035 fill, 1.5pt dashed stroke at `slotInk` 0.26,
  `ghostBlockDashLength` 4 — with a `plus` glyph in `inkQuiet`. The app already
  says "a block goes here" this way, in two places.
- **Filled**: the block, with the glyph pressed into it.
- **Tapping** opens the sheet. `HapticsEngine.lightTap()`, as the photo well does.
- Hit target: 44 × 44 exactly, `.contentShape(RoundedRectangle(...))` — the trap
  `AddWinSheet.swift:356-370` records (an unbounded content area swallowing taps
  on the title field) applies here too.

Changing the colour above re-draws the tile live, on the same
`GridConstants.motionSmooth` transaction the swatch already uses.

### 4.3 The set: 36 glyphs, six groups of six, no search

**Precedent, for calibration** (§8): Apple Reminders ships **60** glyphs × 12
colours. Streaks 6 ships **600+** icons and 78 themes. Things 3 ships **none**.
Strata is much closer to the Things end of that line than to the Streaks end, and
600 icons behind a search field is a feature from a different app.

36 is chosen for three reasons: it is six rows of six, which echoes the six
colour swatches directly above it; six 44pt cells with `gapItem` 12 measure
6·44 + 5·12 = **324pt**, which fits a 360pt sheet inside the app's 16pt margins
(328pt available); and six screenfuls is the point past which a person stops
choosing and starts browsing.

**No search.** If it is not in six rows, the block does not need one. A search
field would also have to search *something* — names, synonyms, categories — and
every one of those is a vocabulary to write, translate and maintain for a
decoration.

Fill variants only, `.monochrome` (§2.1). Groups named by what you did, never by
a category name, so a glyph never reads as setting a category:

| group | glyphs |
| --- | --- |
| **MOVE** | `figure.run` · `figure.walk` · `dumbbell.fill` · `bicycle` · `figure.pool.swim` · `figure.yoga` |
| **MAKE** | `paintbrush.fill` · `hammer.fill` · `camera.fill` · `music.note` · `pencil.and.outline` · `scissors` |
| **THINK** | `book.fill` · `graduationcap.fill` · `lightbulb.fill` · `laptopcomputer` · `chart.line.uptrend.xyaxis` · `checklist` |
| **REST** | `heart.fill` · `leaf.fill` · `moon.fill` · `drop.fill` · `cup.and.saucer.fill` · `bed.double.fill` |
| **PEOPLE** | `person.2.fill` · `hand.wave.fill` · `bubble.left.fill` · `phone.fill` · `gift.fill` · `fork.knife` |
| **PLACES** | `airplane` · `map.fill` · `mountain.2.fill` · `house.fill` · `car.fill` · `sun.max.fill` |

**A note on the six category glyphs.** `heart.fill`, `leaf.fill`,
`paintbrush.fill` and `person.2.fill` are in this set *and* on the colour swatches
immediately above it (`Habit.swift:33-43`, `AddWinSheet.swift:473-477`). They are
included deliberately: the reason the old badge failed was that it was
**automatic and redundant**, not that those shapes are reserved. A heart somebody
pressed is not the app claiming a category; it is a person saying "this one was a
heart". Excluding the four most obvious glyphs to protect an internal
distinction would be the app being precious. `briefcase.fill` and `eye.fill` are
left out, for a different reason: nobody has ever wanted to put an eye on a
thing they did.

### 4.4 The sheet

A `.sheet` with `.presentationDetents([.medium])` — six rows of 44pt plus labels
is about 460pt, which sits inside a medium detent on every phone, so the tower
stays visible behind it and the choice reads as small.

- `.presentationBackground { WarmBackground().ignoresSafeArea() }` — the page's
  own ground, as `AddWinSheet` already does, "a frosted surface is the block's
  material, not a sheet's".
- Group labels in `Typography.sectionLabel` with `sectionKerning`, uppercase,
  `inkSecondary` — the same `field(_:)` treatment the sheet already uses.
- Each cell is 44 × 44, drawing the glyph at 22.5pt in `AppColors.inkSecondary`.
  **Flat in the picker, not debossed.** The picker is chrome, and chrome in this
  app separates with hairlines and translucency, never with material effects.
  The tile in §4.2 is where you see what it will look like.
- The chosen cell carries a 2pt `.primary.opacity(0.75)` ring in a 44pt circle,
  exactly as the selected colour swatch does — one selection indicator in the app.
- `HapticsEngine.tick()` on choosing, as the swatch does.
- **Choosing dismisses.** One tap, like a colour. There is no Done.

**Removing one:** the first cell of the sheet, above the groups, is **`None`** —
drawn as an empty 44pt dashed recess, matching the tile's own empty state. It is
selected when there is no icon. No swipe, no long press, no destructive role: a
mark is not data and removing it loses nothing.

### 4.5 Exact copy (no long dashes anywhere)

| string | text |
| --- | --- |
| field label | `Icon` (rendered uppercase by `field(_:)`) |
| tile accessibility label, empty | `Add an icon` |
| tile accessibility label, filled | `Icon, running. Choose another` (the glyph's plain name) |
| sheet navigation title | `Icon` |
| sheet cancel button | `Cancel` |
| the clear cell's label | `None` |
| the clear cell's accessibility label | `No icon` |
| group headings | `MOVE` · `MAKE` · `THINK` · `REST` · `PEOPLE` · `PLACES` |
| per-cell accessibility label | the glyph's plain name: `running`, `book`, `moon`, `coffee`, and so on |
| accessibility trait on the chosen cell | `.isSelected` |

There is no explanatory subtitle. The control is a picture of a block with a mark
on it; a sentence under it explaining that would be the app talking about itself.

**VoiceOver on the tower:** the glyph is `accessibilityHidden(true)` on the block.
The block's label already names the win, and appending "heart" to it gives a
person using VoiceOver a word they did not ask for about a decoration they cannot
see. The name is available in the picker, which is where it is a choice.

---

## 5. Storage and compatibility

### 5.1 The model

```swift
// Strata/Models/Habit.swift, beside spontaneousCategoryRaw

/// A mark somebody chose to put on this block. Nil is every win, and the
/// default.
///
/// Not a category and never read as one: it does not filter, it does not reach
/// Siri or Spotlight, and nothing in the app writes it except the person
/// pressing a glyph in the add sheet. The category badge that used to be
/// derived from `category` is a different thing and is still gone — see
/// BlockContent.swift.
///
/// Stored as an SF Symbol name, and validated against `BlockIcon.catalogue`
/// at every draw rather than at write: a name from a future build must draw
/// nothing rather than draw a question mark, and a symbol Apple renames must
/// fail to the block's plain colour.
///
/// Defaulted rather than optional-with-migration, exactly like `towerOrder`
/// and `planItemID`: SwiftData adds the column in place, and every existing
/// win keeps nil, which is the truth about them.
var iconSymbol: String? = nil
```

- **SwiftData:** a `String?` with a `nil` default is added in place. No
  `VersionedSchema`, no `SchemaMigrationPlan`, exactly as `towerOrder`,
  `planItemID` and `latitude` were added.
- **CloudKit:** the rule is that every attribute is optional or has a default.
  This is both. Nothing else in the schema changes, so no other constraint moves.

### 5.2 The values that carry it

Four more places, each a one-line addition:

| type | field | why |
| --- | --- | --- |
| `PlacedBlock.Look` | `let iconSymbol: String?` | **The most important line in this spec.** `PlacedBlock.==` compares `Look` by value, and `AnimatedBlockView.==` compares stored properties. `CLAUDE.md` records the `Equatable` trap striking **four times**, most recently on `liftedBlockID`: "Anything new that a block view reacts to must be added to `==`." Miss this and changing an icon will not render, silently, with nothing erroring. |
| `ReplayWin` | `let iconSymbol: String?`, set in `Replay.wins(from:)` | so a replay cannot drift from the tower |
| `WidgetSnapshot.Block` | `var symbol: String? = nil` | see below |
| `BlockFace` | `var iconSymbol: String? = nil` | passed through to `BlockContentOverlay` |

Note that `FlippableBlockView` should *draw* from `block.habit.iconSymbol` (it
observes the model directly, as it does for `title`); `Look` carries it purely so
the `==` can see a change. That is exactly the split the file already documents.

### 5.3 The widget snapshot, and old files

`WidgetSnapshot.Block` is `Codable`. Adding `var symbol: String? = nil`:

- **Decoding an old file works**, because Swift's synthesized `Decodable` uses
  `decodeIfPresent` for `Optional` properties — a missing `symbol` key decodes to
  `nil`. (This is only true because the property is optional. A non-optional with
  a default would *not* fall back, and would throw on an old file.)
- `Block` is `Equatable`, and `WidgetSnapshot.sameContent(as:)` compares
  `blocks`, so an icon change correctly triggers exactly one timeline reload and
  no more.
- The app writes the new field on its next snapshot write; until then the widget
  draws what it draws today.

### 5.4 Spotlight, and anywhere a win is listed

**The icon never becomes a thumbnail, and it is never debossed outside a block.**

A Spotlight thumbnail or a list-row glyph is drawn at 28 to 40pt, which is below
`blockIconReliefFloor` — the relief is a sub-point effect and is simply lost. If
a win is indexed with a `CSSearchableItemAttributeSet` thumbnail, the right image
is the win's photograph or its plain coloured block, exactly as today. If a
future list row wants to show the mark, it draws it **flat**, in `inkSecondary`,
like the picker. (Call site unverified: see §0.)

### 5.5 What an older build shows

**The block, exactly as it looks today: its colour, its title, no mark.** An
older build has no `iconSymbol` in its schema, so SwiftData's lightweight
migration drops the unknown column on read and the block draws its colour. An
older widget decodes a snapshot with an unknown `symbol` key and ignores it
(`JSONDecoder` ignores unknown keys). Nothing crashes, nothing is lost, and
returning to the newer build brings every mark back.

---

## 6. Why this stays minimal

### 6.1 The argument

Every lever in this design is set to "less":

- **The default is none.** A tower belonging to someone who never opens the Icon
  field is byte-for-byte the tower that ships today.
- **The mark adds no colour.** It is the block's own fill, dented. Zero new hue
  on a page whose entire meaning is hue.
- **It adds no edge and no elevation.** The shadow rule is untouched: the block
  still casts one shadow, at 0.07, and the mark casts none — it is a hole, not an
  object.
- **It is one glyph, in one place, at one of two sizes.** No badge, no ground, no
  ring, no count, no second mark.
- **It is mutually exclusive with the photograph**, so a block never carries two
  things competing to be its character.
- **The set is 36 and has no search**, against Reminders' 60 and Streaks' 600.
- **Nothing new animates.** The glyph moves because the block moves.

### 6.2 How busy a tower gets, in numbers

Arithmetic first, then a frozen frame (§7.4), because counting is not looking.

At the tower's 86.5pt cell, a 22.5pt fill glyph's ink covers roughly 55% of its
22.5 × 22.5 box — about **278pt²**, against a cell of **7,482pt²**. So one icon is
**3.7% of a cell's area as ink**.

A one-line 13pt title running about 60pt across is roughly **200pt²** of ink,
i.e. **2.7% of a cell**, and the tower already carries one of those on every named
block.

So, for a 12-block tower (three rows of four):

| icons on the tower | added ink | added ink as a share of one cell | compared with the titles already there |
| --- | --- | --- | --- |
| 0 | 0 | 0 | baseline |
| 3 | 834pt² | 0.11 cells | +0.4 of a title's worth per block on average |
| 6 | 1,668pt² | 0.22 cells | about half as much ink again as a fully-titled tower |
| 12 | 3,336pt² | 0.45 cells | roughly **doubles** the marks on the tower |

A fully-iconed 12-block tower carries about as much *additional* ink as it
already carries in titles. That is the honest ceiling: at 12 of 12 the tower has
twice as many things to look at as it does today, and the mark's contrast band
(1.44 to 1.60, §2.5) is what keeps that from being twice as loud.

**The thing to count on the frozen frame is not the number of icons, it is the
number of distinct glyph SHAPES.** Twelve blocks with twelve different glyphs
reads as a wall of pictograms; twelve blocks with three glyphs reads as a
pattern, which is what somebody who uses three of them every day is building on
purpose. Repetition is the risk, quantity is not.

### 6.3 Should the app ever suggest one? — **No, not in v1**

The app has a hard-won rule that it must never claim something the person did not
choose. It shows up three times in this codebase alone: `category` stays
`.unlabeled` while `spontaneousCategoryRaw` carries the colour
(`Habit.swift:185-194`); `AddWinSheet.showsSelection` refuses to ring a swatch
when the choice was not made (`AddWinSheet.swift:450-458`); and
`QuickWinService.labels(showing:chosen:)` exists solely to keep a colour from
being promoted into a category. **A glyph the app guessed is that claim, on the
block, in the middle of it.**

It would also be wrong often. A win called "Ran into an old friend" gets a
running shoe; "Booked the flight" gets an aeroplane and means the opposite of
travelling.

**The one thing that could earn its way in later**, with the bar stated so it can
be argued against rather than slipped in: if a person gives an icon to a win and
then logs another win whose **trimmed, case-insensitive title is exactly one they
themselves have already marked**, the sheet may open with that glyph
**pre-selected and visibly selected**, never applied silently, and never on the
one-tap path. That is repeating the person's own previous choice, not guessing.
Measure it before shipping it: what fraction of wins have a repeated title at
all? If it is small, the feature is a mechanism with no users.

---

## 7. Build plan

Ordered, each step testable on its own. Sizes are S (under an hour), M (a
session).

### 7.1 (S) The catalogue

`Strata/Models/BlockIcon.swift` — a `nonisolated enum` holding the 36 names in
six groups, their plain-English names for VoiceOver, and:

```swift
static func resolved(_ raw: String?) -> String?   // nil unless in the catalogue
```

Validated at **draw**, not at write (§5.1), so a name from a newer build degrades
to no mark rather than to a question mark.

**Tests:** `everySymbolResolves` (each name returns a non-nil
`UIImage(systemName:)` on the deployment target — this fails the day Apple
renames one, which is the point); `catalogueIsSixGroupsOfSix`;
`unknownSymbolResolvesToNil`.

### 7.2 (S) Storage

`Habit.iconSymbol`, `PlacedBlock.Look.iconSymbol`, `ReplayWin.iconSymbol`,
`WidgetSnapshot.Block.symbol`. Nothing draws yet.

**Tests:** `TowerBuildTests.anIconChangeMakesTheLookUnequal` — build two `Look`s
differing only in `iconSymbol` and assert `!=`. **Self-test: delete the field
from `Look` and watch this test fail.** This is the `Equatable` guard and it is
the single most likely way this feature ships broken.
`WidgetSnapshotTests.aSnapshotWithNoSymbolKeyStillDecodes` — decode a JSON
literal with no `symbol` key.

### 7.3 (M) The mark

`GridConstants` tokens per §2.4, and `BlockIconMark` — a small view taking
`symbol`, `size` and `treatment` (`.relief`, `.flat`, `.contrast`).

**Tests:** `blockIconSize` at cell 86.5 returns 22.5 for `.small` and `.medium`
and 29.4 for `.hard`; the treatment function returns `.relief` at 86.5, `.flat`
at 44, and none at 20.

### 7.4 (M) Wire it in, and **look at it**

Pass `width`/`height` and `iconSymbol` from `BlockFace` into
`BlockContentOverlay` (no `GeometryReader`, §3.4). Suppress when `hasPhoto`.
Thread `overlayOpacity` so the replay's title curve carries it.

Add a debug flag, because every otherwise-unreachable state in this app has one
and this one is unreachable without a tap:
`-strataSeedIcons <n>` gives the newest `n` seeded wins an icon from the
catalogue (cycling, so shapes repeat as they would in life), and
`-strataSeedIcons same <n>` gives them all the *same* glyph, which is the merged-run
case from §3.2.

**Verification, and this is the step that matters:**

1. **Compute the contrast, do not eyeball it.** A small `#if DEBUG` harness
   renders `BlockIconMark` over each of the seven base colours with
   `ImageRenderer` at 3x, samples the darkest pixel inside a stem and the
   brightest pixel in the lip, and prints the WCAG ratio for each. Assert every
   relief edge lands within 0.03 of the table in §2.5. **Self-test: set
   `blockIconLip` to 0 and watch the assertion fire.**
2. **Then look.** Frozen frames, via `-strataSeedWins 12 -strataSeedIcons …`,
   at: 1x1, 2x1 and 2x2; all seven colours; light and dark; 0, 3, 6 and 12 icons
   on a 12-block tower; a merged run of four with four different glyphs and with
   one glyph repeated four times; Increase Contrast on. Allow the ~16 seconds
   after launch that `CLAUDE.md` requires before screenshotting.
3. **Focus yellow is the frame to open first** (§2.5). If it fails the look, move
   the lip, never the shade.

### 7.5 (S) Accessibility branches

Increase Contrast → `.contrast`. Reduce Transparency → no branch (§2.7); write
the reason as a comment so the next session does not add one.

### 7.6 (M) The picker

`BlockIconPicker` sheet (§4.4) and the Icon field and tile in `AddWinSheet`
(§4.2), under the existing `photo == nil || isEditing`. Copy per §4.5.

**Tests:** `AddWinSheet` writes `iconSymbol` only when a glyph was pressed
(mirroring `categoryChosen`); choosing `None` writes nil; a win with a photograph
never shows the field. And a UI test asserting the tile is `isHittable`, not just
`exists` — `CLAUDE.md` records that trap.

### 7.7 (S) The other draw sites

`ReplayFrame` (pass through), `ShareTowerCard` (inherits, since it renders the
real `FlippableBlockView`), the widget's snapshot write, and the map's flat
branch. Confirm the month tower draws none.

**Tests:** `MergeTests.anIconDoesNotAffectMerging` — two adjacent same-colour
unnamed blocks with *different* icons still merge into one group.
`BlockIconTests.aPhotographedWinDrawsNoIcon`.

### 7.8 Every gate self-tests

Per `CLAUDE.md`: every contract gets a re-injection that proves it can fail. The
four that must be shown failing, because each of them is a way this ships
silently broken:

1. `Look` without `iconSymbol` → the equality test fails
2. `blockIconLip` at 0 → the contrast harness fails
3. the relief floor removed → the small-size test fails
4. the photograph suppression removed → `aPhotographedWinDrawsNoIcon` fails

---

## 8. Craft precedents and references

**The construction itself — letterpress / deboss.** The canonical inset effect is
a dark glyph with a *light* shadow offset in the direction opposite the light
source; reversing the shadow order is literally what turns an emboss into a
deboss. That is exactly the two layers in §2.1, with the light overhead and the
lip therefore below.
- <https://csstoolkit.net/blog/css-text-shadow-inset-guide/> — engraved vs
  embossed, and why "a background that closely matches the text colour" is what
  makes the inset read as a press rather than as a shadow.
- <https://www.tutorialpedia.org/blog/css-letterpress-dark-background/> — the
  same effect specifically on a coloured/dark ground, which is our case.
- <https://snowb.org/en/docs/font-design/inner-shadow-effects/> — pairing an
  inner shadow with an offset outer one to simulate one consistent light, which
  is the rule the block's rim already follows.
- <https://designtutorials.home.blog/2021/04/21/how-to-emboss-and-deboss-text-in-photoshop/>
  — emboss and deboss side by side; useful for judging how little offset it takes.

**How many glyphs, and what a picker costs.** Three shipping points on the line,
which is how §4.3 was calibrated:
- **Apple Reminders**: 60 glyphs × 12 colours. The glyph sits centred in a filled
  circle — a *badge in a list*, which works because a list row is chrome. It is
  the pattern to calibrate the *set size* against and explicitly **not** the
  pattern to copy for the drawing.
  <https://www.macrumors.com/how-to/customize-look-of-reminders-lists-ios/> ·
  <https://9to5mac.com/2019/10/17/how-to-change-icons-colors-reminders-lists-iphone-ipad-and-mac/>
- **Streaks 6**: 600+ task icons, 78 colour themes. The maximalist end, and a
  useful warning: past a few dozen, the picker becomes a browser and the app
  becomes a thing you decorate.
  <https://www.macstories.net/reviews/streaks-6-brings-habit-tracking-to-your-home-screen-with-extensively-customizable-widgets/>
- **Things 3**: no per-item icons at all; areas and projects carry a single
  structural glyph. The minimalist end, and the nearest neighbour to this app's
  taste.
  <https://culturedcode.com/things/blog/2018/04/things-3-5/>

**Rendering.** SF Symbols' four rendering modes; monochrome applies one colour to
every layer, hierarchical varies opacity per layer. Monochrome is required here
(§2.1) — a hierarchical glyph would press to different depths inside one mark.
- <https://developer.apple.com/design/human-interface-guidelines/sf-symbols>

---

## 9. Summary of decisions, for the commit message

1. **Debossed**, not badged, not watermarked: `warmBlack` 0.14 with a white 0.28
   lip offset 0.036 of the glyph size downward. No hue, no edge, no elevation.
2. **Centred in the field**, at `blockBandStart / 2` — derived, not chosen. Clear
   of the title and of the band by construction.
3. **Chosen, never derived.** Default none. The app never writes one.
4. **36 glyphs, six groups of six, no search.**
5. **The photograph wins**; the icon is kept, not cleared.
6. **On a merged run the glyph travels with the label, unchanged** — it has no
   edge and it is not at the cell pitch, which is what the old badge was.
7. **No icon on the month tower or on a map cluster** — those blocks are days and
   groups, not wins.
8. **Same numbers in both schemes**, because the block's fill is the same in both.
9. **Three floors**: relief ≥ 56pt, flat 32 to 56, nothing below 32.
10. **`Look.iconSymbol` or it will not render**, silently.
