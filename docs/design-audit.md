# Where Strata's design actually stands

Written 2026-09-09, from a contact sheet of every screen in the app taken in
one pass: `tasks/screenshots/design-audit-before.png`. Ratings are against the
question actually being asked — *would this win an Apple Design Award* — not
against "is it tidy". Two screens would survive that room. Most would not, and
this says why in specifics rather than adjectives.

## The one-sentence diagnosis

**The app is beautiful exactly where it is made of blocks, and anonymous
everywhere else.** Wins and Camera are built from a real idea. Settings, the
add sheet, Memories and the album grid are built from stock iOS components
that any app could have shipped. The problem is not that the weak screens are
ugly — it is that they are *unrelated to the strong ones*.

## The screens, rated

| # | Screen | Rating | The honest reason |
|---|---|---|---|
| 02 | **Wins (full tower)** | **8.5** | The app. A packed field of colour that reads as one built object. Nothing else on iOS looks like it. |
| 03 | **Camera** | **8.0** | Black, quiet, one wordmark, five controls on one line, a block-shaped shutter. Confident. |
| 01 | Wins (nearly empty) | 7.0 | Same parts, but a third of the screen is void and the slot floats away from the blocks with nothing tying them together. |
| 09 | Plan | 6.5 | Clean and legible, but the info button repeats on every row and two thirds of the page is empty. |
| 07 | Day | 6.0 | Correct and sparse. A big title, two blocks, and a lot of nothing. |
| 06 | Add a win | 5.5 | **Contradicts the app.** Colour is a row of CIRCLES; size is a segmented control reading "Quick / Regular / Deep". This app's colours are blocks and its sizes are shapes. |
| 08 | All memories | 5.5 | A competent photos grid. Could be any app. |
| 04 | **Memories** | **5.0** | The screen you flagged. Diagnosed below. |
| 05 | **Settings** | **4.0** | A stock grouped `Form`. Grey system list, system toggles, 28pt tinted icon squares. The only Strata on it is the mark at the top. |

## Why Memories reads as boring — specifically

1. **The heaviest element on the page is a grey rectangle.** The search field
   is 370×56 of flat fill, sitting directly under the title. The first thing
   the eye lands on is a form control.
2. **The album cards are photo-app language.** A 156×254 rounded rectangle at
   radius 20 is a Photos card. Nothing about it is a block: the radius does not
   follow the block ratio, there is no rim, no frosted band, and it is
   portrait where every block is square or wider.
3. **The best thing on the page is below the fold.** The month tower — the one
   element that is unmistakably this app — starts at roughly 60% down and is
   cut off by the tab bar.
4. **No dominant element.** Title, field, label, cards, picker, tower: six
   horizontal bands of similar visual weight. Nothing says where to look.
5. **No colour above the fold** except whatever the photographs happen to be.

## The three system-level faults

These are why fixing one screen at a time would not get there.

**1. Two design languages, and the weaker one has more screens.** Blocks (rim
lit from above, frosted band, 13.9% radius, category colour) versus stock iOS
(grouped lists, segmented controls, circular swatches, system toggles). Every
screen is built from one or the other, and the seam is visible the moment you
move between tabs.

**2. There is no radius ladder — there are four unrelated radii.** Blocks are
13.9% of the side, so they scale. Everything else is a fixed number: search
fields at 12, album covers at 20, photo wells and chips at their own values. A
34pt chip and an 86pt block should be the same object at two sizes, and today
they are not.

**3. Controls have no shared vocabulary.** Within three taps you meet a glass
circle, a segmented control, a system toggle, a row of coloured dots, a plain
text button and a dashed slot. Six idioms, one app.

## What "10" would mean, concretely

One rule, applied without exception:

> **Every surface you can act on is a block, or it gets out of the way.**

Blocks carry colour, radius, rim and band. Everything else — labels, fields,
dividers, backgrounds — is quiet, warm, and shapeless. There is no third
category.

That gives a component set the whole app can be rebuilt from:

- **`BlockChip`** — a block at control size, selectable. Replaces the colour
  circles, the size segmented control, the repeat-day pills, and the category
  swatches. One radius rule via `blockCornerRadius(forCell:)`.
- **`BlockWell`** — the recess a block would sit in: the tower's own empty-slot
  treatment, at other sizes. Replaces search fields, photo wells and any other
  input container. It already exists on the tower and nowhere else.
- **Size as shape.** A 1×1, 2×1 and 2×2 drawn at true proportion, not the words
  "Quick / Regular / Deep". The slot already teaches this by drag; the sheet
  should not teach it again in a different language.
- **Settings off `Form`.** Warm ground, block-shaped icons, the app's own rows.

## The plan, in priority order

1. **The component set** (`BlockChip`, `BlockWell`, one radius rule). Nothing
   else can be consistent until this exists.
2. **Add a win** — highest traffic and the worst contradiction. Colour becomes
   blocks; size becomes shapes; the photo well becomes a ghost block.
3. **Memories** — lead with the month tower, demote the search to a well,
   rebuild the album card so it is a block holding a photograph rather than a
   photo card.
4. **Settings** — off the stock form onto the app's own rows.
5. **Plan and Day** — compose the empty space; the info button appears on the
   focused row only.

Each step is a commit, and each one is measured against the contact sheet it
started from.

## Progress, 2026-09-09

All five steps are done.

1. **Component set** — `BlockControls.swift`: `BlockChip`, `BlockWell`,
   `BlockSizePicker`, all on `blockCornerRadius(forCell:)`.
2. **Add a win** — colour is blocks, size is the three shapes at true
   proportion, the empty photo well is the tower's own dashed slot.
3. **Memories** — the month leads; the duplicate search field is gone; album
   covers are 2×2 blocks holding a photograph, sized from the grid.
4. **Settings** — every row's icon is a small block in a palette colour.
5. **Plan and Day** — the info button appears on the focused row only, and a
   past day's tower stands on the bottom of the screen like the real one
   instead of hanging from the top.

**The Wins tab's empty middle was deliberately not filled.** The audit listed
it under "empty space isn't composed", and on a second look that was the wrong
call: the gap above a short tower is the room it has left to grow into, which
is the whole idea. Filling it would contradict what the tower means. The Day
screen was a genuine fault because it anchored the same object the other way
up; that is fixed.

### What did not survive contact

`BlockControls.swift` — `BlockChip`, `BlockWell`, `BlockSizePicker` — is
**deleted**. It was step 1 of the plan above, and two things unpicked it:

- The owner preferred the add sheet's original **circles** for colour and
  **words** for size (2026-09-09), which removed both consumers of `BlockChip`
  and `BlockSizePicker`. They are right: a swatch is a property of the block
  you are describing rather than a block you are placing, and the words say
  what the geometry is *for*.
- `BlockWell`'s only consumer was `AllAlbumsView`'s search field, and that
  screen went when the month tower and the gallery made a third list of the
  same record redundant.

The rule the components existed to serve did survive, and is visible in the
Settings icons, the plan bullets, the month tower and the album covers — all
of which use `BlockSurface` directly. What the episode actually shows is that
"every surface you can act on is a block" was too strong: it is right for
things that stand FOR a block, and wrong for things that merely describe one.

### Still open

- Every rating above is against the simulator. Nothing has been judged on a
  real display.
- A day with zero wins renders a title and nothing else. It is unreachable in
  the app — you can only arrive at a day from an album or a month block, and
  both require at least one win — but `-strataOpenDay` can reach it, and if a
  route to it ever appears it needs an empty state.
- `Typography` still exposes tokens (`radiusField`, `fillTrack`) from before
  the block rule. They are not wrong, but they are a second vocabulary for
  things the block components now cover, and they should be audited before
  anything new uses them.
