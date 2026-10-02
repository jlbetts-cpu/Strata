# What is settled, what has a range, and what is open

Written 2026-10-02, from a video the owner sent about keeping a `design.md` so
that an agent builds his taste rather than a competent average. Its one
structural idea is the thing this project did not have: **separate the decisions
that are final from the ones that are open to interpretation.**

Everything in this repository already records WHY. Nothing recorded **whether it
may be reopened**, and the cost of that is measurable. In one evening:

- The Plan sheet's empty state was recomposed onto the golden section, which
  moved the invitation 420pt away from where the first line lands. The owner had
  to say "it was supposed to show the bullet point."
- The heading weight was taken to Semibold and stopped there on my judgement
  after he had asked for thicker. He had to say "why no bold i mean thats what I
  asked."
- Earlier passes reopened the white block labels and the 8pt corner radius, both
  of which he had already settled, and both had to be reverted.

Each time the information needed to prevent it was in the repository, in a
comment, somewhere. **This file is the index of what cannot be changed without
asking**, so that the reasoning stays where it is and the permission does not
have to be hunted for.

---

## How to read it

| | What it means | What to do |
|---|---|---|
| **LOCKED** | The owner decided it, usually after seeing it both ways. Several were decided AGAINST a measurement. | Do not change it. Do not re-propose it. If new evidence genuinely bears on it, say so in one line and let him answer. |
| **GUIDED** | A rule with a number and a range. The number is argued; the next value inside the range is a judgement call. | Work inside it. Moving the number needs a measurement and a note at the site. |
| **OPEN** | Not decided, or waiting on something he is making. | Propose freely. Render alternatives rather than picking one. |

**A measurement does not promote a LOCKED item.** Four of the entries below are
there precisely because he overruled a measurement, and he was right about what
the measurement was for every time: the white labels measured worse and read
better; the corner radius measured inconsistent and looked right.

---

## LOCKED

Each line carries the date and, where there is one, his own words.

### The app's shape

| Decision | When | His words, or the record |
|---|---|---|
| Three tabs: Wins, Camera, Memories | settled | — |
| The app opens on the **camera** | settled | "logging a win is meant to be the fastest thing in the app" |
| The tab bar is **icons only**, no labels | 2026-10-01 | put to him against keeping them; his call |
| Profile lives on **Memories only**, never on Wins | settled | "the tower is today's record and its corner belongs to today" |
| **Replays live in Memories.** The week moved there with the month | 2026-10-01 | "the your month doesnt belong on the wins because its already in memories" |
| The Wins corner is **empty**, kept for a logo he may add | 2026-10-01 | "maybe I will add a logo later in the corner but I think for now it shouldnt be there" |
| **No search** in Memories. It had one and it went | settled | — |
| No Today tab, no checklist, no badge on a tab | settled | — |

### Settled the morning of 2026-10-02

Each chosen from two renderings in `docs/design-review/`, put to him with the
measurement beside it.

| Decision | When | His words, or the record |
|---|---|---|
| Edit sheet's Delete is the kit's **red word**, not the native pill | 2026-10-02 | "Red word"; the pill measured 3.96:1 in dark, the word 5.73:1 (`block-card-delete-paths.png`) |
| A replay's block titles **fade out by the time the week comes to rest** | 2026-10-02 | "Fade them"; at rest they drew at about 7.5pt (`replay-titles-paths.png`) |
| Calendar day numerals **never below 15pt** | 2026-10-02 | "Raise to 15"; they were 7.9pt (`memories-numeral-15.png`) |
| Album card titles **wrap to two lines** rather than truncate | 2026-10-02 | "Wrap to two lines"; one line drew "Read a cha…" (`memories-album-options.png`) |
| Onboarding's map page draws **the map as it is now**: back disc, no title | 2026-10-02 | "Redraw it"; it drew the map as the Memories tab, which it stopped being on 2026-09-30 |
| A past day's lattice is **its tower plus one row** | 2026-10-02 | "Tower plus one row"; nothing lands on a past day |
| The head maker **switches to the light page** for its preview | 2026-10-02 | "Keep the switch"; the head is shown where it will live |
| Profile's Done stays **the title's ink** | 2026-10-02 | "Leave it"; monochrome like every other sheet |
| Add and Edit **read from the top**: name, its controls, the block, air below. The block is not floored | 2026-10-02 | "why is the spacing that spaced out looks odd"; it was 64 under the name and 197 over the block |

### The blocks and the tower

| Decision | When | His words, or the record |
|---|---|---|
| **White labels on every block colour**, not dark | 2026-10-01 | "I much prefered the white ink look over the dark ink" — decided against a measurement showing dark at 6.00 to 9.77:1 and white at 1.71 to 2.70 |
| A single block's corner radius is **8**, beside a merged run at 12 | 2026-10-01 | "Leave it at 8" |
| The tower is **today only**. No week or month filter | settled | — |
| A block **falls** on a constant-acceleration curve, with no ease at the end | settled | "All masses fall the same, because they do" |
| `TowerLattice` is **1.03:1 on purpose** and is not darkened | refused twice | the instrument cannot see it; that is the point |

### Colour and type

| Decision | When | His words, or the record |
|---|---|---|
| **One accent: ink.** No blue anywhere | 2026-10-01 | "lets just do the basic"; `accentPrimary` deleted, zero call sites |
| **Headings are Bold**, prose is Medium | 2026-10-02 | "why no bold i mean thats what I asked" |
| **One face.** SF Pro, until he adds his own | settled | "I hate when there is like one type of font next to another" |
| **Nothing below 15pt**, except three sites with a measurement | 2026-10-01 | "no tiny thin font anywhere" |
| The calendar's empty days are **wells**, not bare numerals and not ground | 2026-10-01 | chosen from three renderings; no measurement could separate them |
| Saturated colour means **a win or a photograph**. Chrome is ink and light | settled | — |

### Copy and voice

| Decision | When | His words, or the record |
|---|---|---|
| **No em dash** in anything a person reads | settled | one was found in a backup alert on 2026-10-01 and fixed |
| **Nothing may read as the app watching the person** | settled | "It remembers where you were" was rejected; "Remember Places" became "Keep Places" |
| The replay says **nothing about itself**. No "Your week" over it | 2026-09-15 | "the words 'Your week' are the app talking about itself" |
| A replay's date range is **numeric**: "9/28-10/4" | 2026-09-15 | "7 to 13 September read as a sentence where a glance was wanted" |
| The album card **keeps its count** | 2026-10-01 | — |
| Settings keeps "Everything you log stays on this device" | 2026-10-01 | the one sentence that sells the product's spine |
| **Less text, always.** A component that explains itself loses its charm | 2026-10-01 | "I truely want a minimal and etheral experience ... a place of piece and space" |

### Layout

| Decision | When | His words, or the record |
|---|---|---|
| The Plan sheet's **invitation is row one**, where the first line lands | 2026-10-02 | "it was supposed to show the bullet point" |
| The Plan sheet **keeps its tail** under the list | 2026-10-01 | it is the tap-to-write space |
| **Lots of white space**, and it has to be doing something | 2026-10-02 | "the white space is an aid but make it make sense" |
| The page margin is **16** | measured | 24 takes 4pt off every block; the cell is load-bearing |

---

## GUIDED

A number, a reason, and the range it may move in.

| Rule | The number | The range | Where it lives |
|---|---|---|---|
| Spacing ladder | 8 / 12 / 16 / 24 / 32 / 64 | nothing between 32 and 64; the app had 25 distinct values in that gap | `GridConstants.gap*` |
| Type sizes | 34 / 17 / 15 | three, and a floor of 15 | `Typography.tier(_:)` |
| Type weights | Bold / Medium | two, 34.4% of stroke apart | `Typography.titleWeight`, `.bodyWeight` |
| Text contrast | 4.5:1 | against the ground it actually sits on, sampled | check 9 |
| Shape contrast | 3:1 | same | check 9 |
| **Structure ink** | 4 levels | nothing carrying information may sit under it, in any state | check 12 |
| Structure that scales with content | 8.2 levels bare, 3.3 full | crossing at 45% of the grid | `MonthCalendarCell.wellInk(filled:)` |
| Motion | 5 rungs plus 4 bounce rungs | 9 animations, against the 40 the app had | `docs/motion-audit.md` |
| Press | 3 rungs: glyph, word, surface | one component | `PressResponse` |
| Selection | **a ring on the chosen shape's own edge, and nothing moves** | two declared exemptions | `ColourSwatch` |
| Destructive ink | one red, 5.65:1 | — | `AppColors.destructiveInk` |
| Targets | 44pt, measured off the built screen | — | check 8 |

---

## OPEN

| Thing | Status |
|---|---|
| **The six illustrations** | He is drawing them. `docs/illustrations.md` has the rules, corrected 2026-10-01 after somebody finally opened heytea.com: they are **open line art, not filled silhouettes**. Rule 1 was describing their logo. |
| **A custom typeface** | He has said he will add one. `Typography.tier(_:)` and `StrataFont.relative` are the two lines it lands on. |
| **Tracking** | HEYTEA sets everything at +0.10 em; this app's only tracked token is 0.053. Worth trying on titles and measuring. Not applied. |
| **Widget interactivity** | He asked for it. The cost is the SwiftData schema in the extension, against the budget `WidgetSnapshot` exists to stay inside. Sized at `StrataWidget.swift`, not built. |
| **A URL scheme** | The app has none, so a widget tap cannot land on the tower. |
| **StandBy** | Never looked at. The widget has a photograph behind it and StandBy at night renders monochrome red. |
| **Personalisation by journey stage** | The one applicable idea from four videos that is entirely unbuilt. The honest shape here is the first week being allowed to look different from the fiftieth, which is a product decision. |
| **Lowercase headings** | HEYTEA is lowercase throughout. This app capitalises. His call, not a layout one. |

---

## The atomic kit: a rule is a type, not a paragraph

The video's second idea is that the file is worth much more when it points at the
real components. The mapping, so that "make it consistent" has an address:

| If you are about to draw | Use | Never |
|---|---|---|
| a block, or anything with a block's body | `BlockSurface`, `EtherealFill`, `BlockRim` | a `RoundedRectangle` with a gradient |
| a colour chip | `ColourSwatch`, `ColourSwatchRow` | a `Circle().fill` |
| a round glyph button | `GlassIconButton` | a glyph in a `Circle` |
| a capsule control | `glassCapsule` | a `Capsule()` |
| the primary action | `PrimaryCapsule` | a filled `Capsule` with a label |
| a press | `.buttonStyle(.press)` / `.pressWord` / `.pressSurface` | `.plain`, unless it wraps glass |
| a section heading | `SectionHeading`, `FormSectionLabel` | a `Text` with kerning |
| a sheet's confirm or cancel | `.sheetAction()` | a `Text` with a tint |
| an icon at a size | `.iconSize(_:relativeTo:)` with a `GridConstants.icon*` token | `.font(.system(size:))` |
| an empty day, slot or well | `AppColors.slotInk` at the state's ink | a grey fill |
| a count | the shared count readout | a `Text("\(n) wins")` |
| a destructive word | `AppColors.destructiveInk` | `warmRed`, which is a block's fill |
| a hairline | ink at `1 / displayScale` | `Divider` |

**The app has deleted five private re-implementations of things on this list** —
`CardPress`, `PosterPress`, `zoomGlass`, `SlotGlass`'s copy and `ColourSwatch`'s
— and `docs/consistency-audit.md` found eight more live when it was written. A
private copy is not a style choice, it is the thing this table exists to prevent.

---

## Where the rest of it is

- `CLAUDE.md` — the standards, the traps, and the long-form reasoning.
- `docs/screen-audit.md` — the twelve checks, and every screen graded out of 10.
- `docs/space.md` — the spacing research, with sources and what was discarded.
- `docs/consistency-audit.md` — eighteen drifts, and the count of how many ways
  the app says one thing.
- `docs/motion-audit.md` — 147 call sites, and the collapse to nine.
- `docs/copy-audit.md` — all 399 visible strings, classed.
- `docs/reference-board.md` — his Pinterest board, five videos, HEYTEA measured,
  and what Dribbble's "minimal" actually returns.
- `docs/illustrations.md` — what to draw and where it goes.
