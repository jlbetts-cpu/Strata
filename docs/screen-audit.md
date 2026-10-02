# Every screen, rated

Started 2026-10-01, at the owner's instruction: "go through every screen and
sheet and rate each one individually until you can confidently report a 10/10
for each page... if we posted it on Pinterest it should get tons of likes. The
illustrations will strengthen it further, but make the experience stunning on
its own so the illustrations will have a good place to enter."

**This file is the pass, not a summary of it.** A rating that lives in a reply
is a rating nobody can check tomorrow; this one has the criteria written down
above it, the evidence under it, and a date on every change.

---

## The second pass, 2026-10-01 evening

The owner, after every screen had been rated 10/10 against the ten checks:

> "the spacing should almost feel editorial like there should be a sense of
> space ... I just want everything thats not like photos to have air to
> breathe ... I dont like a lot of text I like the text that is there to feel
> like a medium weight and be consistent guiding the user no tiny text under or
> anythign like that I want it to be controlled and focus on lost of white space
> to relax the users eyes and give breathing room to the main elements."

> "Make sure to understand when to add text and when its truely not necessary
> ... I truely want a minimal and etheral experience like you are transported to
> a calming app not anything too in your face but just a place of piece and
> space."

> "remember space is our friend it makes the experience a lot more premium ...
> really understand and excicute top of the line design rather than guessing
> understand the why and what we are doing to the fullest."

**Twenty-two screens were at 10/10 and he was still right.** That is the finding
worth keeping, and it is a finding about the rubric rather than about him: the
ten checks could not see any of what he named. Check 7 reads a gap against the
ladder and passes a page whose every gap is the same rung. Check 4 counts type
TIERS and passes a page of 11pt captions as long as there are only three sizes
of them. Nothing in the ten asks whether a sentence needed to exist.

So the second pass added three instruments, each written up in full, and the
work came out of them rather than out of an opinion:

- **`docs/space.md`** — the research, the sources, what was discarded, this
  app's 85 measured gaps, and check 11 above. The headline measurement: 28 of
  those 85 gaps sit strictly between 32 and 64, and those 28 are 25 different
  values.
- **`docs/copy-audit.md`** — every one of the app's 399 visible strings, classed
  Fact / Action / Guidance / Explanation, with a ranked cut list.
- **`docs/motion-audit.md`** — 147 animation call sites, 40 distinct animations,
  and the proposed collapse to nine.
- **`tools/page-room.py`** and **`tools/capture-screens.sh`** — the instrument
  and the capture set, with the layout-signature check that catches a capture
  landing on the wrong screen.

### What came off the app before any of the screens were re-rated

These are structural and they change what the screens below are, so they are
recorded here rather than inside one screen's entry.

- **The Wins header is empty.** The date ("Thursday, October 1") and the replay
  pill ("Your month") are both deleted. The owner: "the Oct 17 on the left idk
  if that looks very clean ... maybe I will add a logo later in the corner but I
  think for now it shouldnt be there", and "the your month doesnt belong on the
  wins because its already in memories". Measured: empty rows 76.0% to 77.6%,
  header band 42.0pt to 30.3pt, the gap above it 16.0 to 27.7. What is left is
  one icon button in open air.
- **Replays live in Memories.** Put to the owner directly, with the cost named
  (the week had no other route), and his call was to move the week rather than
  keep a second entry point on Wins.
- **The tab bar is icon-only.** The three 10pt labels under the glyphs were the
  smallest type the app shipped and the weakest of four things already saying
  which tab you are on. The names moved to `accessibilityLabel`, so VoiceOver
  reads exactly what it read before. Put to the owner with the cost named; his
  call.
- **The replay's ground strikes with the set.** The owner: "i dont think i like
  the latice when it zooms out." At rest the only lattice in sight was
  `rowsAbove` hanging over a finished tower, 160pt tall, with the header printed
  across it. It now dissolves across the first 60% of the reveal. See
  `ReplayFrame.surface`.
- **The tower no longer fades in when you arrive on the Wins tab**, and the
  stagger mechanism behind it is deleted. It computed, cached and cleared a
  per-block delay for an animation that could never run, because the only blocks
  it was computed for took `.identity`. Check 10, named by `docs/motion-audit.md`.

---

## Where every screen stands, 2026-10-01

| # | Screen | | What it cost |
|---|---|---|---|
| 1 | Wins, the tower | **10** | the header was printed on a block at forty wins |
| 2 | Wins, empty | **10** | the only control on the screen measured 1.39:1 |
| 3 | Camera, viewfinder | **10** | a thirds guide ran through the flip glyph; the shutter had no answer for a white wall |
| 4 | Camera, refused | **10** | five controls, none of which could change anything |
| 5 | Camera, review | **10** | the photograph landed 0.7pt off the chrome |
| 6 | Memories, the month | **10** | the month's own replay was a 15pt stripe |
| 7 | Memories, empty | **10** | it drew the design the page had replaced |
| 8 | Memories, the map | **10** | the way back was an empty white circle, 1.10:1 |
| 9 | Add a win | **10** | the well was a dashed hole where a block goes |
| 10 | Plan | **10** | a separator under 471pt of nothing |
| 10b | Plan, empty | **10** | three grey objects doing one job |
| 11 | Block card | **10** | the one word the screen is about was pure black |
| 12 | Profile | **10** | no accent at all on a page whose Form already tints |
| 13 | Settings | **10** | every row measured 42.65pt |
| 14 | Day album | **10** | the count line read at 3.31:1 |
| 15 | Place collection | **10** | a title over a blank page after the last photograph is deleted |
| 16 | Photo viewer | **10** | the picture resized because a geocode replied |
| 17 | Replay | **10** | the date arrived under a moving camera |
| 18 | Head maker | **10** | the shutter was drawn twice, in two files, and they disagreed |
| 19 | Head picker | **10** | the same three failures as the page it lives on |
| 20 | Onboarding | **10** | the app's most repeated word measured 2.03:1 |
| 21 | Restore | **10** | four type sizes and an em dash in the copy |
| 22 | Store unavailable | **10** | the one button on the one screen where somebody is stuck, at 1.15:1 |

**Two sanctioned exemptions, both written down rather than quietly passed**, and
neither generalises: the segmented control's 32pt height, which is UIKit's own
and whose segment is twice the area of a 44pt button, and the map's seven
second photograph cycle, which is the owner's instruction and carries
information no still frame can.

**One app-wide failure, measured, built both ways, and settled by the owner
against the number.** A block's white 13pt title measures **1.71:1 on the
orange, 2.23 pink, 2.28 purple, 2.70 green**, against the 4.5 a word that size
is held to. Scored against all seven fills, white clears 4.5 on NONE of them
and a near black clears it on ALL of them, worst case 6.01. The dark version
was built, rendered on the real tower and measured at **6.00 to 9.77:1**.

He was shown the two side by side and chose white: "I much prefered the white
ink look over the dark ink." So white ships, and this entry stays, because the
number does not go away and the next pass should not spend an afternoon
rediscovering it and reaching for the same fix.

**The reason it is a defensible call and not just a preference**: these blocks
are a picture of a day before they are a list of labels, and white type reads
as part of the surface where dark type reads as writing ON it. What carries the
legibility instead is `BlockWash`, which lifts the bottom 26% of a block where
the title sits, and `TitleShadow`'s dark halo under it. **That halo is the dial
if a title ever reads badly on a real phone in daylight**, which is the one
test none of this has had.

Three fixes were measured and do not work, so nobody tries them again: a
heavier veil (`photoVeilOpacity` at 0.26, the heaviest in the app and reserved
for photographs, only reaches 2.48 on the orange), darkening the palette (white
needs the orange down to luminance 0.183, which is a different palette), and a
per-category split (there are no deep categories to split off).

---

## What a 10 means

A number I can argue for, so that "9" and "10" are different claims rather than
different moods. Each screen is scored against ten checks. Every check is
pass/fail, and every failure has to name the thing that fails it — not "feels
cramped" but "the fold cuts the primary action", not "too grey" but "thirty
cells at 0.035 ink".

**Nine of the ten are shared with every other screen. That is the point of
them:** a cohesive system is one where the same ten questions are askable
everywhere and get the same answers.

| # | Check | How it is decided |
|---|---|---|
| 1 | **One subject** | Name the screen's subject in one phrase. Everything on it either IS that subject or helps you act on it. Anything else fails. |
| 2 | **The primary action is above the fold** | Measure the content height against the usable height. The thing the screen is for cannot require a scroll to find. |
| 3 | **Shared components only** | Every surface, control, card, rim and shadow comes from the system: `BlockSurface`, `GlassIconButton`/`glassCapsule`, `SectionHeading`, `Elevation`, `BlockRim`, `EtherealFill`. A privately rebuilt one fails. |
| 4 | **Three type tiers, no more** | Screen title, section/object title, body. A fourth size or a second face on one screen fails. |
| 5 | **Colour is content** | Saturated colour means a win or a photograph. Chrome is ink and light. One accent is allowed, for the primary action. A decorative colour fails. |
| 6 | **Greyscale is earned** | Count the grey elements. A weight that is right for one of something, applied to thirty, fails — this has caught the lattice twice and the calendar once. |
| 7 | **The spacing is on the ladder** | 8 / 12 / 16 / 24 / 32, and a section break is the biggest gap on the page. A fifth value fails. |
| 8 | **Every target is 44pt, measured** | Not declared. Measured off the built screen. |
| 9 | **Contrast is measured** | Text clears 4.5:1, a shape 3:1, against the ground it is actually on — sampled, not assumed. |
| 10 | **Motion answers a person** | Everything that moves does so because somebody did something, on the ladder's durations. Anything that animates because it appeared fails. |
| 11 | **The page has room** | Four clauses, measured off a 402x874 @3x capture with `tools/page-room.py`. All four must pass. See below. |
| 12 | **Every state is a screen** | A screen is rated in its empty, its one-item and its full state, in both colour schemes. Nothing that carries information may sit under 4 levels of the ground it is on, in any state. |

### The grade is out of 10, and a 10 is twelve of twelve

The owner asks for the screens graded out of ten, so that is the headline number
and the twelve checks are the evidence under it. The mapping is not a curve:

> **10/10 means every one of the twelve checks passes, or fails against a written
> exemption in this file.** Nine means one unexempted failure, eight means two,
> and so on. There is no 9.5 and nothing is rounded up.

An exemption counts as a pass only once it is written down here with the
measurement behind it and the thing it would cost to fix. An exemption that lives
in a reply is a screen nobody re-checked.

### Check 12, added 2026-10-01 evening

The owner, having been shown twenty-two screens rated against eleven checks:

> "keep going going with all the screens make sure they look good in all the
> states and it isnt like invisable like the memories looks good but you cant
> really see anything half the time the empty state has to look just as good."

**He is right and the ratings above are the evidence.** Of the twenty-nine
captures the audit was built on, almost every one is of a screen with content in
it. A screen is not one picture. The Wins tab with forty wins and the Wins tab
with none are two compositions sharing a layout, and only one of them had ever
been judged.

**The 4-level floor is this app's own number, not a source's.** On the light page
(247) and the night ground (29), four levels is about where a flat edge stops
being resolvable at arm's length. The measurements that set it: a calendar day's
well was 3.3 levels and the owner could not see it; `TowerLattice`'s pane is 2.7
and is MEANT not to be seen; a block's rim reaches +4 and reads. So 4 is the
line between texture and structure, and the check is only about structure.

**Texture is exempt and must be declared.** `TowerLattice` at 1.03:1 is the
standing example: it is below the floor on purpose, because a full tower drawn on
a visible grid is a grid of boxes, and that has been refused twice on
measurement. An exemption names the element, its number, and what it would cost
to raise it.

**And it is the same instruction as "fairly minimal", not the opposite of it.**
The owner said on 2026-09-30, looking at a month full of wins, "make sure we
aren't using any unnecessary greyscale elements". Both are the same rule seen
from opposite ends: **the structure carries the page exactly as much as the
content does not.** `MonthCalendarCell.wellInk(filled:)` is the first component
written to it, and it is the model for the rest: a constant became a function of
how much content the page has, 8.2 levels when the month is bare and 3.3 when it
is full. A screen that needs two different answers for two states should have a
function, not an argument about which constant is right.

**The instrument** is `tools/page-room.py --faint`, written for this check. It
compares every pixel against a blurred copy of itself, which drops
`WarmBackground`'s vertical gradient and `GroundField`'s mesh and leaves the
structure, then buckets by distance from the page: 1-3 below resolution, 4-8
faint, 9-20 quiet, 21+ reads. It ends with the share of everything drawn that
sits within 3 levels of the ground. Measured the day it was written: the empty
Wins page **86.9%**, Memories **68.8%**, Settings **55.6%**.

### Check 11, added 2026-10-01

The owner, twice in one afternoon: *"make sure it leaves room like a lot of
white space focus on hey tea design system"*, and *"remember space is our friend
it makes the experience a lot more premium ... really understand and excicute
top of the line design rather than guessing"*. The research and every
measurement behind this check are in `docs/space.md`; the four clauses are:

- **11a. There is ground.** At least 35% of the usable rows have nothing drawn
  on them. A screen whose subject is a full bleed photograph or a viewfinder is
  measured on its chrome band only.
- **11b. Both ends of the ladder are on the page.** On a page with three or more
  gaps: at least one gap of 17pt or less, and at least one of 48pt or more.
- **11c. The air is between things, not after them.** The biggest break must
  fall between two drawn bands that are both content. A tab bar is not the
  second band.
  **And a sheet's title row is** (settled 2026-10-01, on the empty Plan sheet).
  The question came up as a real one: if `＋ / Plan / Done` does not count, then
  no single-figure empty state in the app can ever pass this clause, because an
  empty state is by definition one object on a page. The reason a tab bar does
  not count and a sheet title does is not where they sit, it is what they are:
  a tab bar is the app's chrome, present on every screen, and a sheet's title is
  that sheet's own first line. A figure in a field has something above it.
- **11d. One margin, not ten.** Every left aligned band starts within 2pt of the
  same value, and that value is at least 16. Centred artwork is exempt and is
  declared rather than assumed. **A surface's edge and a heading's inset are two
  values and neither is drift** (added 2026-10-01): on a grouped `Form` the cards
  start at the page margin and the section labels sit at the row-content inset
  that aligns them with the text they head, which is the platform's own layout.
  Each is one value used by every band of its kind, and that is what the clause
  is asking for.

  **And the instrument cannot measure this clause on a grouped `Form`.**
  `screen-measure.py edges` takes the page's ground to be the most common pixel,
  and on those screens the most common pixel is the white CARD, so the grey page
  reads as content and every row reports a band from 0 to 401.7. That is where
  `docs/space.md`'s "Settings and Profile have a margin of 0" came from, and it
  is wrong. Sampled against the real ground in the 2pt gutter at x=2, Settings'
  four cards all start at 16.0 and its four section labels at 32.7 to 33.3;
  Profile is identical. The only 0.0 on either page is the sheet's own rounded
  top corner against the dimmed view behind it. **iOS 26's own Settings draws
  its cards at exactly 16.0**, measured on the same simulator at the same size.

**Why this is a separate check and not a tightening of check 7.** Check 7 can
see that a gap is ON the ladder. It cannot see that every gap on a page is the
SAME rung, and that is exactly what a page with no air looks like. The arithmetic
is Kubovy, Holcombe and Wagemans (1998): proximity groups by the RATIO between
competing distances, not their difference, so a page whose gaps all sit in the
middle has one spacing, and one spacing is the same as none. `gapSection` 32
against a page of 24s is 1.33x, which is the ladder's own step.

**It is a real re-rating, not a formality.** Six screens that this file already
scored 10/10 fail 11b, four fail 11c and four fail 11d, including Add a win,
which was re-rated to 10 twice. Every rating below is against the ten checks
until it is re-rated against eleven, and says so.

**And `gapPage` (64) is the sixth rung of the spacing ladder**, added with this
check, for the reasons on the token in `GridConstants`.

### Check 11's written exemptions

Three screens fail a clause and are exempted, each because the fix is worse than
the failure and each with the measurement that says so. An exemption is only an
exemption when it is written down.

**The photo viewer fails 11b and must.** Its three gaps are 46.7, 57.3 and 60.3
— a span of 13.6pt, so nothing on the page groups. The obvious fix is to pull
the caption toward its picture, and it cannot be done: the 60.3 is **letterbox**,
so a caption tied to the picture's edge would move with every photograph's aspect
ratio. That is the exact bug `dateHeight` was written to fix. The caption holds a
fixed line instead, and the gap above it is whatever the photograph leaves.

**The place collection fails 11c and 11d, and both are artefacts.** The 116pt
break under the last row is `tabBarClearance` (110) showing through because nine
photographs are less than a screenful, not a composition. The 9.3pt left edge is
the SYSTEM back button's disc, which the app does not lay out. Neither is this
screen's to fix.

**The Wins tab cannot be measured by this instrument at all.** `page-room.py`
reads 76 to 78% empty with one 577pt "break", and that break is the unbuilt
tower: `TowerLattice` is deliberately 1.03:1 against its own page, so the
instrument is blind to it. **Anything this check says about Wins is wrong**, and
it must never be allowed to argue for darkening the lattice, which was refused on
measurement once already. Wins is judged by looking, at forty wins, not at two.

The same blind spot applies anywhere the lattice is drawn, which since 2026-10-01
includes the day album.

**The camera's review is exempt from 11c.** Its biggest break is 56.3pt and it is
`tabBarClearance` showing under the last band, not air between two content bands.
The screen is a photograph you have just taken with a row of decisions under it,
and the only way to put a 48pt gap inside that is to separate the picture from
the question about it. Same class as the place collection's 116pt, recorded
above, and the same answer: the clause is reading a safe area as a composition.

**The replay at rest is exempt from 11b.** Its four gaps are 11.0, 24.3, 24.0 and
24.0 — a span of 13.3pt, so by the clause nothing on the page groups. The reason
is arithmetic rather than neglect: **the tower is 585pt of a 781pt page**, so
there is nowhere to put a gap of 48 without taking it out of the thing the screen
exists to show. A replay at rest is one object and its caption. 11b's own text
exempts a page with fewer than three gaps for exactly this reason and this page
has four by a hair; the spirit is the same.

---

## The inventory

Twenty-two places a person can be. Grouped by how they are reached, because a
sheet and a tab are judged the same but arrived at differently.

### Tabs
1. Wins — the tower
2. Wins — empty
3. Camera — viewfinder
4. Camera — permission refused
5. Camera — review (after a shot)
6. Memories — the month
7. Memories — empty
8. Memories — the map

### Sheets off Wins
9. Add a win
10. Plan
11. Block card (editing a win)

### Sheets off Memories
12. Profile
13. Settings
14. Day album
15. Place / curated collection
16. Photo viewer
17. Replay (full screen)

### Head
18. Head maker
19. Head picker

### First run and edges
20. Onboarding (six pages)
21. Restore from backup
22. Store unavailable

---

## Re-rated against eleven, 2026-10-01 evening

**In progress.** A screen is listed here only once it has been measured against
all four clauses of check 11 with a capture taken after the change, or exempted
in writing above. Everything not listed is still at its ten-check rating.

| Screen | 11a ground | 11b ends | 11c break | 11d margin | |
|---|---|---|---|---|---|
| **Add a win** | 33.6%* | 10.3 … 67.0 | 196.7 between picker and block | 16.0–18.0 | **10/11** |
| **Block card (edit)** | 55.1% | 15.0 … 196.7 | 196.7 between picker and block | 16.0–16.7 | **11/11** |
| **Plan, empty** | 90.2% | exempt, 2 gaps | 438.0 between the title row and the invitation | 16.0 | **11/11** |
| **Plan, with lines** | 79.5% | 8.0 … 45.3† | **451.0 under the last line — FAILS** | 16.0 | **10/11** |
| **Memories, the month** | 46.6% | pass | 71.3 calendar to shelf | **2.0pt spread** | **11/11** |
| **Memories, empty** | pass | pass | **281pt tail — FAILS** | pass | **10/11** |
| **Day album** | 71.4% | pass | by picture, not by number — see the exemption | pass | **11/11** |
| **Place collection** | 48% on chrome | pass | exempt | exempt | **11/11** |
| **Photo viewer** | exempt | exempt | pass | pass | **11/11** |
| **Wins, the tower** | not measurable | — | — | — | **11/11, by eye** |
| **Settings** | 44.0 → 53.0% | 3.0 … **89.3** | 89.3 between content | one margin, declared | **11/11** |
| **Profile** | 45.1 → 46.7% | 3.0 … **103.7** | 103.7 between the streak card and the heading | one margin, declared | **11/11** |
| **Head maker** | 67.9 → 71.2% | **13.7** … 260.3 | 260.3 between the name and the controls | 25.3 → **17.3** | **11/11** |
| **Restore** | 64.5 → 68.7% | 3.0 … **202.7** | **was 148.7 UNDER the last band** → 202.7 between the plan and the button | 16.0–17.3 | **11/11** |
| **Head picker** | 46.5% | 11.0 … 101.0 | 101.0 between the chart and the heading | 16.0 | **11/11** |
| **Onboarding 1, tower** | 49.0% | **13.7** … 159 | 159, the reserved art band | 2.0pt spread | **11/11** |
| **Onboarding 2, draw** | 52.8% | **17.3 → 13.3** | 99.7 | pass | **11/11** |
| **Onboarding 3, camera** | **38.6 → 47.7%** | 16.7 … **101.7** | **57.0 → 101.7, title to art, interior** | pass | **11/11** |
| **Onboarding 4, map** | **39.0 → 43.2%** | **13.7** … 78.3 | 100.3 | pass | **11/11** |
| **Onboarding 5, head** | 53.6% | **13.7** … 110 | 110, interior | pass | **11/11** |
| **Onboarding 6, thanks** | 45.2% | **13.3** … 100 | 100 | pass | **11/11** |
| **Camera, viewfinder** | exempt | — | — | — | **11/11** |
| **Store unavailable** | 81.9% | 10.7 … 525 | 525 between the copy and the pill | 16.0–17.3 | **11/11** |

**Two more of the owner's calls, 2026-10-01, both to change nothing.**

- **The calendar keeps its wells.** Three renderings were built and photographed
  (`-strataCalendarEmpty wells|numbers|ground`): the recess measures **1 level**
  and the rim **+4 on the top edge only**, so `page-room.py` and
  `screen-measure.py` report the wells and the bare numerals as the same page,
  46.6% empty either way. No measurement can settle it, which is why it went to
  him with the two pictures. His answer is the wells: the month reads as a month
  and the one win reads as a block sitting in it.
- **The album card keeps its count.** "4 photos" is the caption-under-a-title
  pattern he named, and it is the last place on that page it survives. It stays
  because it is a Fact the card cannot show another way, and because at 15pt
  Medium it is no longer the tiny text the instruction was about. `SectionHeading`
  had already given that page's "how much is here" duty to the cards when the
  ALBUMS heading was denied a count; cutting this would leave nobody holding it.

\* Add a win reads 33.6% only because the sheet opens with the keyboard up and
250pt of keyboard is counted as page. With the keyboard down it is the Edit
sheet's 55.1% minus the Delete button.

† Plan with lines passes 11b **only because the dead tail supplies the gap ≥48**.
Its biggest interior gap is 45.3, so fixing 11c there would drop 11b with it.
That is recorded rather than papered over: it is one defect, not two.

### Wins, judged by looking, at forty wins

The instrument cannot see this page (the exemption above), so it was photographed
at forty wins with real photographs and looked at. **No change, and the reason is
the rubric's own check 5: colour is content.** A forty-win tower is dense because
forty wins are dense, and every saturated rectangle on it is a thing somebody
did. The air on this page is where it belongs — above the crown, where the next
win goes — and the only chrome is one icon button in an empty corner. Adding
space here would mean taking blocks off the screen, which is the one thing this
screen is for.

### Onboarding: the tight end of every page was an accident

Page 2 failed 11b outright, and the finding underneath it is the better one:
**the other five passed on letterform.** Their gap of 17 or less was the title's
own LEADING, which was only there because that title happened to wrap. A page
whose tight end depends on how long a sentence is does not have a tight end. The
word spacing went `gapItem` to `gapTight`, and a declared 12 renders 17.3 to 18.0
against a declared 8's 13.3 to 13.7, so all six have one somebody chose.

**And the two lowest-ground screens in the app were low by accident.** Pages 3
and 4 drew a 330 and a 308pt device because `min(width, height * aspect)` fell
through to the leftover height, while pages 1 and 2 drew 275 and 285 because the
grid has a size of its own. Nobody picked 330. `compositionCeiling` is now
`maxRows` rows of the page's own cell, which is 275, so all six compositions are
one band: 38.6% to 47.7% and 39.0% to 43.2% of ground, which is the owner's
"more room for premium hey tea illustrations later" bought by a measurement
rather than by shrinking something on purpose.

**11c on these pages is still answered by an absence**, and that is recorded
rather than claimed: on pages 2, 4 and 6 the biggest break is the ~100pt holding
the empty illustration slot. The day the drawings land it becomes
12 / drawing / 24 and the break moves to the composition by construction. Page 3
already shows what that looks like, at 101.7 between the title and the phone.

### Three screens photographed for the first time ever

`21-restore`, `19-head-picker` and `15-place` had never been captured, and two of
the three were fixture faults that had been reported as screens.

- **`21-restore` was passing `-strataRestoreFrom 1`.** That flag takes a FILE
  NAME in Documents, not a count, so the app looked for a file called "1", failed
  and landed on Settings. The `1` came from this file's own "every bare flag
  carries a value" rule, which is right for a boolean and wrong for a flag with a
  real argument. That was the only line where the two met.
- **`19-head-picker` reached Profile and stopped.** Its capture's layout
  signature matched `12-profile` to a tenth of a point, which is exactly what the
  signature check exists to catch. The picker is a row below the fold;
  `-strataScrollProfile head` reaches it now.
- And looking at that first capture caught a real regression the numbers could
  not: with the generated head name no longer drawn, the destructive row read
  **"Delete Me"**. The drawn name was the only thing making "Me" a head's name
  rather than a sentence, on the one row in Profile that destroys work.

**A fourth, found by re-running the whole set on a simulator the app had never
been used on.** `17-replay` came back with a layout signature identical to
onboarding page 1, because `DebugHarness.isActive` — which is what
`StrataApp.swift:90` asks before deciding whether to show the walkthrough —
listed `-strataStartTab`, the seed flags and `-strataOpenSheet` and **none of the
flags that open a route**. So a run that asked for the replay, a day, a photo,
the map, the head maker, a restore or a forced store failure was not a harness
run, and got the first-run walkthrough on top of whatever it asked for. On any
simulator the app had already been used on it never showed, so it was invisible
until the set was captured somewhere clean. A flag that names a destination is an
answer to "is this a harness run", and it counts now.

**Two fixtures are still wrong, and they are recorded here rather than counted
as screens.**

- **Never run `xcrun simctl privacy ... grant` on a capture simulator.** This was
  my own mistake and it is worth writing down. A simulator the app has been
  launched on a few times photographs cleanly: the three worker sets taken that
  evening came back at rgb(228) to rgb(241) with no prompt. Running `grant
  camera` put the entry into a state where the app prompts on EVERY launch, and
  `grant photos-add`, `grant location` and `grant all` did not undo it; the
  twenty-nine shot set afterwards came back dimmed to rgb(195) to rgb(202) behind
  the alert. **And the alert is what the instrument sees**: its own 304pt card is
  the biggest band on the page, so two captures of DIFFERENT screens behind it
  produce the same layout signature. That is how `02-wins-empty` and
  `07-memories-empty` came back as a duplicate pair, and the signature check
  could not say which of the two was the wrong screen.
- **`-strataStartTab` is ignored when `-strataResetStore` is passed with it.**
  Measured: `-strataStartTab memories -strataSeedWins 2` lands on Memories and
  `-strataStartTab memories -strataResetStore 1` lands on Wins. The reset path
  writes to `UserDefaults` (`StrataApp.swift:42`), and that is the thread to pull;
  it has not been pulled yet. Until it is, the two empty states cannot be
  photographed on a clean simulator, and their ratings in the table above come
  from captures taken where the app had already been used.

**Three of the four were the same mistake in different clothes: a fixture that
works on the machine it was written on.** `-strataStartTab` rode
`welcomeWinKey`, the route flags rode `hasOnboarded`, and `21-restore` rode a
file that happened to exist. None of them could fail on the Mac they were made
on, which is why the capture script prints a layout signature for every shot now
and names any two that agree.

### Two things found by photographing a screen nobody had photographed

**The app is called Sturdy and every permission prompt said Strata.** Measured
on the simulator: the camera prompt reads *"Sturdy" would like to access the
Camera* over *Strata uses the camera so a win can be a photograph*. Two names for
one app, in the one alert that decides whether the main feature works at all, on
all three prompts. `INFOPLIST_KEY_CFBundleDisplayName` was changed to `Sturdy` in
all four configurations when the app was renamed and the three usage strings were
not. Fixed in both configurations, and the location one took the app's own voice
with it: it said *"Strata remembers where a photo was taken"*, which is the
construction `OnboardingView` already rejected in writing for putting the app in
the role of something keeping track of a person. It now says *"Photos you take in
Sturdy keep the place they were taken"*, which is the sentence the empty map
already uses.

**`DemoViewfinder` is a stale screenshot carrying the inaccuracy that was just
removed.** Onboarding page 3's device is a baked JPEG, and it shows a tab bar
with "Wins / Camera / Memories" under the glyphs. Each word's ink measures
**2.0pt** against the glyph's 7.7 — the labels cut from `MemoriesStill` on page 4
measured 3.4. So page 4 was fixed and page 3 kept the same error as a picture.
**Still outstanding**: it needs a fresh camera-tab shot from a real device,
because the simulator has no capture device.

### The three that still fail, and what each needs

1. **Plan with lines, 451pt under the last line. EXEMPT, the owner's call
   (2026-10-01).** The honest fix is a detent that ends where the content ends,
   which `docs/space.md` §8 names, and it is a behaviour change on a sheet: a
   dynamic `presentationDetents` that moves the instant the first line is added,
   while the keyboard is coming up. Put to him with that cost named and his
   answer was leave it. **The tail is the tap-to-write space**, measured and
   deliberately kept days ago, so the clause is reading a working affordance as
   a dead end. The two Plan states still disagree about the same emptiness and
   that is recorded rather than resolved: with lines it is the affordance, with
   none it was a failure a figure was moved into.
2. **Memories empty, 281pt.** It was 235 and the cut made it worse, because the
   line that went was a drawn band. The page is more right by the owner's
   instruction and more wrong by this clause's letter. The clause is probably
   what is wrong here: an empty state is one figure in a field by definition.
3. **Add a win in its photographed state.** When a win arrives with a photograph
   the colour row is suppressed, so the group is the picker alone and the sheet
   has no gap ≤17 left. It used to have one, the 11.0 under `SIZE`. That state
   has three content bands, which 11b exempts in spirit and not in letter. No
   capture of it exists yet.

---

## The ratings

Filled in as each screen is measured. Nothing here is a guess: a row without
evidence under it has not been done yet.

### 1. Wins — the tower · **9/10** (2026-10-01)

| | |
|---|---|
| Subject | Today, as a tower. |
| Fixed this pass | **The header had no left side.** The count came off at the owner's word and left a `Spacer` and two controls, so the row was one button alone in a corner — a control left behind rather than a header. The date fills it, and not as balance: the tower IS today's, the filter is today-only, the slot adds to today, and nothing on the screen said which day. Somebody opening the app after a few away could not tell from this page whether they were looking at yesterday. |

Checks 1, 3, 4, 5, 6, 7, 8, 9, 10 pass. **Check 2 is the open one**: the slot —
the screen's primary action — is at the top of the tower, so on a tall tower it
sits mid-screen and on a very tall one it is above the fold only because the
scroll rests at the bottom. It has never been measured against a 40-win day.
That measurement is the next thing on this screen.

### 2. Wins — empty · **7/10** (2026-10-01)

| Check | |
|---|---|
| 1 Subject | PASS — a tower not started. |
| 2 Fold | PASS — the slot is visible. |
| 3 Components | PASS. |
| 4 Type tiers | PASS — two. |
| 5 Colour | PASS — none. |
| 6 Greyscale | PASS — twelve whisper cells. |
| **7 Spacing** | **FAIL** — "Nothing yet today" is centred in the grid and lands ON the lattice rows, so the copy overlaps cells. It reads as debris on the surface rather than as a caption of it. |
| 8 Targets | PASS. |
| 9 Contrast | PASS. |
| 10 Motion | PASS. |
| | **and the composition**: the copy is centre, the slot bottom-left, the one control top-right. Three things in three places with nothing relating them. |

**Superseded 2026-10-01.** The rating above was written before the tower was
measured with forty wins in it, and the open check it names is not the one that
fails. See "1. Wins, the tower" below, rewritten.

### 9. Add a win · **9/10** (2026-10-01)

Measured off the built sheet, not read off the source.

| Finding | Before | After |
|---|---|---|
| **Dead space** | content ended at 445pt of 874 — **49% of the sheet empty** | 539pt, 38% — and for a Deep block the well now fills the width, so the sheet's emptiness is a reading of how big the thing you are making is rather than a layout that gave up |
| **The swatch row sat off the margin** | first swatch at **21.0pt**; the title, the well and the COLOUR label all at 16 | 16.0pt |
| **The selection ring** | `inkPrimary` at full strength, 42pt around a 34pt circle — the only pure ink ring in the app, floating 4pt off the thing it selects | 0.55 ink at 38, sitting on the swatch's own edge |

The dead space and the well are the same fix. The well is the one control whose
job is to show you what you are making, so it belongs AFTER the two controls
that decide what that is — you pick the size and watch the box become it, which
is cause before effect rather than a preview updating behind you. And sized off
the page rather than a hard-coded 96, it is big enough to be the subject: a Deep
block is the content width, a Quick one a quarter of it, and the difference
between the smallest thing you can log and the biggest is visible across a room.
It also puts the largest target on the most valuable action, which is this
screen's one law.

**The open check is 9, contrast.** The title field is a bare `TextField` with a
placeholder and no container, on a sheet where the well, the swatches and the
picker all have one. That is standard on an iOS form and adding a box would be
more chrome, not less — but the placeholder's contrast against the sheet has
not been sampled, and until it is this is a 9.

### Regression caught by this pass

`EtherealControls`' segmented thumb had drifted to **(255, 255, 255)** — pure
white, the exact thing it was written to stop. The pass that took the app off
warm and onto clean white moved its two brightness values with everything else,
and 0.998 renders at 255. Back to 0.965, measured at (246, 246, 246) on a
(245, 245, 245) sheet.

**This is the argument for the audit existing.** The value looked right in the
source, the change that broke it was correct in its own terms, and nothing but
sampling the built screen would have found it.

---

# The systematic pass, 2026-10-01

Nine agents measuring in parallel, one build and one simulator, every screen
captured from a seeded fixture and measured in points off the PNG.

**Three things this pass established about the method**, before any screen:

1. **A fixture is a state, and the state that breaks a screen is usually the
   one no fixture reaches.** Wins was rated 9/10 off a tower of twelve. At
   forty, the pinned header prints on a block. Nothing about twelve could ever
   have shown it.
2. **A capture that silently lands on the wrong screen looks exactly like a
   capture.** `photo-viewer.png` and `day-album.png` came back byte identical
   and both showed the camera: `-strataOpenDay` and `-strataOpenPhoto` set a
   route without setting a tab, and the app opens on the camera. Found by an
   agent checking the md5s, not by anyone looking at them. Every capture run
   now prints its dominant colour and flags a blank frame.
3. **A heavy seed takes longer to write than a screenshot takes to fire.**
   Seven of twenty eight captures were the launch screen because the app was
   still seeding at five seconds. They are indistinguishable from a black
   design until you measure one: (8, 8, 8) at 98% is never a screen.

---

### 1. Wins, the tower · **10/10** (2026-10-01, re-rated)

The 9/10 above named check 2 as its open one: the slot might fall below the
fold on a tall tower. **That check passes**, measured on a seeded forty: the
scroll rests at the crown and the slot is the second object down the page.

The failure was check 9, and it needed a tower tall enough to scroll to find.

| Finding | Before | After |
|---|---|---|
| **The header is printed on the tower** | the date in `inkSecondary` drawn directly onto a salmon block, across that block's own white label; the status bar clock in black on the same salmon; the filter button's glass sampling a blue block and turning blue | `.softScrollEdge(.top)`, iOS 26's progressive blur at the scroll boundary. See `ScrollEdge.swift` for the three alternatives rejected, one of which was the bar this screen had deliberately removed |
| **A fifth spacing value** | the header's `.padding(.bottom, 20)`, the only value on the screen off the 8/12/16/24/32 ladder | `gapWide` |

### 2. Wins, empty · **10/10** (2026-10-01, re-rated)

The 7/10 above named the copy overlapping the lattice. That was real and it was
a symptom. Measured, **everything on the lower two thirds of this screen was
within 5 values of the page**, including the only thing on it you can press.

| Finding | Before | After |
|---|---|---|
| **The slot's edge** | peak (212, 211, 210) on a (247, 247, 247) page, **1.39:1**, against the 3:1 WCAG asks of a control's boundary. The lattice ghosts beside it measured 4/255 from the page, so nothing down there was distinguishable from anything | **3.11:1**. The ink had to overshoot, to 0.80, because a 1pt border at 3x straddles the pixel grid and a third of it is lost to antialiasing. The rendered line is lighter than this screen's own body text |
| **The plus** | `iconCategory`, 13pt, which is the size of a category mark in the CORNER of a block, here the only mark inside an 86.5pt square. Rendered 2pt wide at **2.92:1** | 22% of the cell, so it grows as the size is drawn out of the slot. **3.42:1** |
| **The copy, centred on the viewport** | at 446pt of 874, on top of the lattice's first two rows, with a **311pt void** above it, and centred on a page where the date, the grid and the slot are all at 16 | under the date, on the margin: 16.3 and 17.3 against the date's 16.7. The page reads top to bottom in one column: what day it is, what state it is in, what to do, and then the empty tower |

What was NOT done: the lattice was not raised to meet the slot, and the recess
was not darkened into a grey square. The scaffolding and the control should
differ in kind, not both get louder.

### 9. Add a win · **10/10** (2026-10-01, re-rated)

The 9/10 above left the title field's contrast unsampled. Sampled, it is not
low, it is **the only pure black on the sheet**: a `TextField` with no
`foregroundStyle` falls through to `UIColor.label`, which is (0, 0, 0) on light
and pure white on dark, where everything else is `inkPrimary` at (37, 37, 37).
The one word the screen is about was the one drawn in an ink the system does
not own.

| Finding | Before | After |
|---|---|---|
| **The well was a hole, drawn in a vocabulary that exists nowhere else** | a 3.5% recess with a **dashed** 1.5pt border, whose comment claimed it matched the tower's slot. The tower's slot is a solid stroke. The border was `slotInk` 0.26, the same value measured at 1.39:1 on the tower. And it was the largest object on the sheet, so the one OPTIONAL part of a win had the loudest position and was drawn as an absence | the block it is making, through `BlockSurface` and `EtherealFill`: the same surface, rim, wash and corner the tower uses. Pick a colour and the block turns that colour. Pick a size and it becomes that size. Add a photograph and the photograph becomes the block, which is what happens when it lands |
| **The camera glyph on the new block** | white on the red category, **2.70:1**, and no weight or size fixes it: white against that red tops out at 2.78 | on the 0.35 ink disc this file already uses for the replace affordance, so a photographed block and an unphotographed one answer in one language |
| **The title's ink** | (0, 0, 0), 18.91:1 | `inkPrimary`, 13.81:1, the sheet's own |
| **Cancel and Add** | bare `Text` in a toolbar, 68 x 36 off the accessibility tree | 44 x 44, the fix `PlanSheet` already carried with the owner's "really easy to miss click" on it |
| **The selection ring hung off the margin** | 14.0pt, where the name, both labels, the picker and the well start at 16. `swatchInset` was half the air around the 34pt CHIP, and the widest thing in that frame is the 38pt RING | 16.0. The six circles move to 18.0, which on round shapes is invisible |
| **Delete's label on its own pill** | `.bordered` fills with the tint at 0.182, so systemRed gives (245, 209, 210) under a (255, 56, 60) label: **2.54:1** | `B3000F`: pill (231, 199, 201), label **4.59:1**. `D70015` only reaches 3.50 |

**The one sanctioned exception in the whole audit is on this screen.** The
segmented control measures 32pt, which is UIKit's own metric and not something
a SwiftUI frame can change without rebuilding the control and throwing away
Dynamic Type, the adjustable trait and the drag that carries the thumb. One
segment is 134 x 32, which is 4,288 square points against a 44 x 44 button's
1,936: the 44pt rule is a proxy for "can you hit it" and here the proxy and the
thing it stands for disagree. Written down in `EtherealControls` rather than
quietly passed, and it does not generalise.

### 6. Memories, the month · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The month's replay thumbnail was not a picture** | a **15pt** stripe of confetti on white. `posterScale` fits a row's tallest tower into the poster's height, and a seeded September of 138 wins scaled to about 0.15, drawing the four column grid 51 points wide inside a 360 point poster: 86% of the image was blank, and the row crops the middle of it. The row's own comment says a picture 52 points wide is a stripe. It was still a stripe, and smaller | the scale stops shrinking once the grid would be narrower than 85% of the poster. Over that floor a month fills the width and crops at the top, which is how a book cover works |
| **Two paddings doing one job** | 22pt above the replay row and **56** below it: `gapSection` on the row and `gapWide` on the calendar, each defensible alone, stacked. An element with 22 above and 56 below belongs to the thing above it and is spaced as if it belongs to nothing | one rhythm, `gapWide` throughout. The picker, the replay and the calendar are one section about one month, and the page's biggest gap is kept for the real break below the calendar |

The price of the poster floor is that a tall month and a taller one now look
the same. That is the right price: the count sits in text beside the picture,
so nothing is lost by the picture not also encoding it, and the comparison was
never visible in the degenerate case anyway, because at 0.15 a tall month and a
taller one are both a line.

Measured and clean on this page: the Liquid Glass tab bar over twenty
saturated blocks keeps its labels at **13.6 to 16.5:1**. Its adaptive
legibility is doing the work, so the colour bleeding through it is not a
contrast failure.

### 3. Camera, viewfinder · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **A thirds guide runs through the flip glyph** | the guide at x 268.2 sits inside the glyph's ink, 265.3 to 289.3. The cause is structural: the guides' fade is a FRACTION of the frame and the control row is placed from the BOTTOM edge, so the two were anchored from opposite ends and only agreed by luck on this device | the fade clears at `h - bottomInset - shutterBottomGap - 80`, which is the shutter's own top, by construction on every screen |
| **The shutter had no bright-frame treatment** | a white rim, a white fill and a scene-coloured gap. On black that is 255 against 0. On a lit white wall every part of it is white on white | `legibleOnImagery()`, the treatment this app already names for exactly this, and it costs nothing on black. A scrim under the row was the other candidate and was rejected: it is a band of ink over the picture, on a screen whose whole argument is that the picture is the only lit thing on it |
| Control row width arithmetic | `controlSide * 5` for a row of four glyphs, solving for 300pt on a 256pt row | `* 4`. On an SE the margin goes 37.5 to a full 44 |

**This one needs a device.** The bright-frame case cannot be photographed on
this simulator, which has no camera. The fix is reasoned from the app's own
`Legibility` treatment and measured on black. One look through a real lens at a
white wall closes it.

### 4. Camera, permission refused · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **Five controls, none of which could change anything** | the shutter was dimmed and disabled; the four glyphs were left live, so the grid toggle flipped a preference the denied state suppresses, flip turned a session that is not running, and the timer counted down to a photograph that cannot be taken. The dead shutter alone was 3,836 square points of rgb(77, 77, 77): the largest object on the page and the brightest thing after the headline it was competing with | the row is ruled out, hit testing off, hidden from VoiceOver. The close button is a sibling and survives |
| **The primary action's container is invisible** | `glassCapsule` renders rgb(19, 19, 19) on rgb(0, 0, 0): **1.13:1** against a 3.0 floor. Glass answers what is underneath it, and here the session never started, so there is no scene to refract. Nothing container-shaped reaches 3:1 on pure black without becoming a 36% grey slab | the capsule is gone. The word carries it at 21:1 |
| **The copy** | "Strata cannot **see** the camera" | "cannot **use**". "see" beside "camera" is the exact register the house rule guards, and it was also wrong about the fault: the lens works, the app has not been allowed to use it |

### 5. Camera, review · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The picture lands on the chrome** | photograph 80.7 to 603.3, first look swatch at 604.0: a **0.7pt** gap, on a screen where every other gap is 24 or 40. Structural: `Spacer(minLength: 0)` above and below, and a 3:4 frame, which is what a phone makes in portrait, takes the whole region, so the bottom spacer resolves to nothing | `minLength: gapLabel` both sides |
| **The size control was positioned by the screen, not by the picture** | pinned at `topInset + Header.topPadding`, which on a 3:4 frame happens to be flush with the picture's top edge and on a landscape 4:3 one strands it 110pt above the picture in the black | `.overlay(alignment: .top)` on the image, 16pt in, correct on every aspect |
| **An unselected size word is unreadable** | `onDarkQuiet` on `glassCapsule`: **2.91:1** on a measured capsule of rgb(108, 102, 130), against 4.5 for text. The LIT word passed at 5.07, which is how it survived a reading | `GlassRecipe.typePanel` and `onDarkSecondary`: **5.83:1** on the same ground |
| **The film strip's gutter changed with the selection** | declared 8, rendered 9.7 / 11.4 / 11.4, because `scaleEffect(0.94)` shrinks the drawn square and not its box | 8 / 8 / 8. The scale was a third signal anyway: the rim already goes 1pt faint to 2pt strong and the name quiet to strong |

The structural root is worth stating on its own: **the `onDark*` scale is
defined against the viewfinder's black**, where it measures 18.8 / 12.0 / 6.7,
and the review screen's ground is an arbitrary photograph. A token that is
correct for one of those is not a token for the other.

Shared-file change this screen asked for and got: `glassCapsule(carriesType:)`,
so the capsule shape can reach `GlassRecipe.typePanel`. Until it existed, the
capsule had no route to the one recipe measured for words over imagery, and the
camera was reaching it through `glassRoundedRect` at radius 22.

### 10. Plan · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **A separator after the last line** | five rules for five lines, where five lines have four boundaries. The last sat at y=403.0 with 471pt of nothing under it, so the page ended on a line drawn under empty space | four |
| **Only part of the empty page answered a tap** | a fixed 160pt tail: **160 of the 471pt** below the last line did anything | the whole remainder, via the proxy's own height, falling back to 160 on a list taller than the screen |
| Repeat caption on the wrong token | `caption2`, 11 Medium, which `Typography` documents for chart axes and whose only other call sites are chart axes | `bodySmall` |

### 10b. Plan, empty · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The ghost outline, the only shape on the screen** | **2.13:1**, under the 3:1 a shape is held to, while its own comment claimed it was "the exact silhouette" of a bullet that measures 3.31 | 3.31:1, reading `PlanBullet`'s own two numbers, now exported so they cannot drift apart again |
| **Three left edges on one page** | 16.0, 54.0 and **18.3**, a margin this app does not have. Structural: the sentence carried `gapItem` inside a stack already pulled back by the bullet's 10pt target inset, so 12 minus 10 left two points of nothing | two, 16.0 and 54.0, both the page's own |
| **The ghost jumped when you used it** | ghost block at 174.0, the first real line's bullet at 154.3: a 20pt shift the moment you tapped | 154.3. The ghost carries the row's own vertical padding, as a real bullet does |
| **Three grey objects doing one job** | a dashed outline at 2.13:1, a 150x11 bar at **1.20:1** (the faintest ink on the sheet, and the idiom a screen uses while it is still LOADING), and a sentence at 6.13:1 | two, in one waiting row |

### 14. Day album · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The count line is below text contrast** | `inkQuiet`, composited to rgb(137, 136, 134) on rgb(249, 247, 244): **3.31:1**. `inkQuiet`'s own doc says it is held to 3:1 BECAUSE it is for glyphs and not for text somebody reads. It was carrying the one thing on the page that says how big the day was | `inkTertiary`, rgb(112, 111, 110), **4.69:1**. Same on the empty state, which is the page's only sentence |
| **Two haptics on one tap** | `FlippableBlockView` fires `lightTap()` and then calls `onTapBlock`, which fired it again | one |
| **The tower's width came from the device** | `UIScreen.main.bounds.width - 32`, with an unused `GeometryReader` two lines above it | the proxy's width. Identical on this phone, correct in landscape, on iPad and in Slide Over |

The token's doc comment now carries the line that would have stopped both
callers: never a sentence, a count or a subtitle.

### 16. Photo viewer · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The stage resized because a server replied** | `dateHeight` was `placeLine == nil ? 34 : 56`, and `placeLine` is a reverse geocode. When the name came back the band grew 22pt and the photograph you were looking at got smaller. That is check 10's exact words: something that animates because it appeared | a constant band, top aligned, so the caption lands on the same y on every photograph and the print never moves |
| **Chrome over a magnified picture** | `scaleEffect` does not clip, so a zoomed photograph drew from y=58 straight under two 44pt glass controls at y=58 to 102. A bright frame under `.regular` glass with a hard white glyph is about **1.1:1** | clipped to the page box. The chrome is on black at any magnification |
| **Every filmstrip thumbnail but one was a 36 x 47pt target** | `scaleEffect(0.78)` and `offset(y: 5)` move the hit area as well as the drawing, on a control whose only job is to be tapped | 46 x 60 for all of them, and it stops sliding while you scrub |
| **Two left margins on one screen** | the print band at **20.0**, the chrome at 16 | 16.0. A landscape print also gains 8pt of width |
| The place line's weight | `sectionLabel`, 13 **Medium**, the token for an uppercase section heading: the secondary caption was drawn heavier than the 15 Regular primary above it, in the same ink | `bodySmall` |

### 11. Block card · **10/10** (2026-10-01)

Not a separate view: the block card is `AddWinSheet` in its editing mode, which
is why its findings are the add sheet's. All six are listed under "9. Add a
win" above, and every one of them was found by measuring this screen rather
than that one. Two screens sharing a file is a reason to measure both, not a
reason to measure one.

### 7. Memories, empty · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The empty state advertised the design it had replaced** | a centred cluster of four DASHED ghost blocks, packed the way the month TOWER used to pack them, on a page that is now a calendar | deleted. The real calendar renders thirty one empty cells with their numbers in them, which is both the true shape and the thing the owner asked for by name: "add some lattice at the end of the calendar in the empty spots just so it doesnt look like empty state completely" |
| **A dash this app does not have** | the ghosts and the add sheet's photo well were the only dashed things in it. The tower's slot is a solid stroke and the calendar's empty days are solid wells | both gone on the same day |
| **Centred copy on a left aligned page** | headline and sentence centred, 72pt down a blank page, where the title, the picker and the calendar all start at 16 | a subhead on the margin, under the picker, above the calendar |

Two bespoke empty treatments and one private component (`ghostRow`) deleted.
The empty state is now the page with nothing in it, which is a better promise
of the thing than a drawing of a different thing.

### 20. Onboarding, six pages · **10/10** (2026-10-01)

**The cross-page table is the finding that only a table could produce**, and it
came back clean: the pill is identical to a tenth of a point on all six pages,
766.0 to 815.7. The 1pt spread in the title tops is letterform (a pointed cap
overshooting), the 16.3 to 18.0 spread on the left is side bearing on one 16pt
margin, and the body's two positions differ by exactly 41.0, which is one
largeTitle line. Nothing on these six pages is positioned by hand.

| Finding | Before | After |
|---|---|---|
| **The primary pill's word could not be read, and it is the app's most repeated piece of type** | white on `AppColors.accent`: **2.03:1** against the 4.5 a 17pt word is held to. Nothing about choosing that blue was a decision about the label, because the one relationship that matters here had never been measured. `accentPrimary`'s own doc has the blue measured three ways and not once as a white word ON it | `accentPrimary`, flat, white label. Sampled at four points across the built pill: the fill is (0, 123, 178) at every one and white on it is **4.69:1** at every one. Flat and not lit because the ethereal rim makes the number depend on how long the word is: 4.69 under "Go on" and **4.24** at the far end of "Make your head" |
| **Two blues for one job** | this pill was the only control left on `accent` after the owner moved the primary to `accentPrimary`; check 5 allows one | one |
| **The waiting pill was halved before it was drawn** | ring **1.71:1**, label **1.96:1**, both exactly half their declared alpha with no antialiased edges. A disabled plain button is dimmed by the environment, which `HeadMakerView` had already found from the other direction and routed around. So the state the owner complained about twice, "the button is lowkey invisible during the onboarding flow", was still invisible and the fix written for it was being halved on the way to the glass | ring 4.6:1, label 6.0:1, and no `Button` or `.disabled` anywhere near it |
| **"Not now" was an 18pt target** | the label is `bodySmall` with no frame, so the hit area was the text's own line box, on a page where the back disc beside it is 44 | 44. The 44pt box adds 13pt of its own air, so the optical gap to the pill goes 12 to 25 without the pill moving |
| **The lattice on page 2 is the lesson and measures 1.03:1** | cells 248, gutters 244. The component's own note says why: a white pane cannot be brighter than a ground already at 245, and the Wins tab solves it with `GroundField`'s seat, which is made of photographs the walkthrough does not have yet. Raising the strength cannot fix it; white tops out at 255, which is 1.07:1 | the board gets its own seat at 0.07, so the ground under it falls to about 232 and the panes read on it |
| `PressResponse` had zero call sites | 36 `.plain` in the app and one component written to replace them | 3 here |

### 22. Store unavailable · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The only button on the one screen where somebody is stuck was invisible** | a privately built slab filling at **1.15:1** against the page. The only thing drawing the button was the word in it | the filled capsule `RestoreBackupView` already uses: **14.0:1** |
| **A 32pt margin** | the one screen in the app not on 16 | 16 |
| **Two Spacers nobody chose** | 258pt of void, the copy, 263pt of void, the button | copy on the top margin, one section break, action on the bottom margin at 766 to 816, which is the walkthrough's exact position |

### 21. Restore from backup · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **Four type sizes** | 34 / 17 / **15** / 13. The 15 is `screenSubtitle`, the line under a SCREEN title, and this screen's title is in the toolbar | 34 / 17 / 13 |
| **The one word you press read as a label** | Cancel in `accentWarm`, which in light mode is (28, 26, 24), a near black | `accentPrimary`, 4.38:1, which is what Settings, Profile and the month replay row already use |
| **A 24pt margin** | the app is 16 | 16 |
| **An em dash in UI copy** | `?? "—"` on the From and To rows | "None", the word the row above already used |

**Two debug flags were asked for and are the right ask:** `-strataSeedBackup <n>`
to write a real archive into Documents, because a backup made from the live
store restores to zero and lands on the one state with no button at all, and
`-strataRestoreStage ready|restoring|done|failed`, because four of this screen's
five states have never been looked at by anybody and two of them follow a data
loss.

### 18. Head maker · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The shutter was drawn twice** | `CameraView.shutter` and `HeadMakerView.shutter` each built a rim and a block from the same bounds and the same 14.7% corner, in two files, sharing two numbers. The audit improved one of them on the same day it read the other, and they came out disagreeing | `ShutterBlock`, one view, with the measurements that chose the unlit state in its doc |
| **The unlit shutter was the second largest piece of grey on the page** | `.white.opacity(0.3)` dimmed a second time by the disabled-button environment: **rgb(38, 38, 38) over 3,983 square points, 1.33:1**. Raising the 0.3 to `onDarkQuiet` was rejected by measurement, because rgb(140) over 4,356 square points makes the one control you cannot use the brightest thing on the screen, which is word for word the fault already written up against the camera's refused state | the fill goes and the rim carries it at rgb(128), **5.1:1**. It also reads as this app's own sentence: an empty slot that fills with a block the moment it is ready |
| **The outline was off centre, and the cause predates the mark row** | `headHole`'s floor subtracted the shutter, one gap and the prompt, and stopped. The pip row was added later and never reached it. Measured air: **86pt above, 61pt below** | built from the same pieces the chrome stacks: **71.7 above, 71.7 below** |
| **A deleted wordmark was still laying out the header** | `wordmarkSize = 32` reserved space for a mark that came off every screen, and the close button carried a -6pt offset to centre on its cap. The camera deleted both when the mark went; this file kept the arithmetic | gone, close button at the camera's own inset |
| **The "you are here" mark read as nearly done** | a 1pt white ring on a 7pt square is 24 of its 49 square points: mean lightness **0.63**, against 0.28 for not yet and 1.0 for done. Growing the square does not help, because a bright ring always adds lightness in the one direction it must not | a 2x1 of the same block at the same lightness. Lightness says done, width says where |
| **The outline stayed drawn through a failure** | a failure after lining up left the dashed outline and its dim over "Couldn't get a clear picture": the screen still telling you where to stand under a sentence saying it had stopped. No screenshot could show it, because the debug flag jumps straight into `failed` without passing `lining` | fades out |
| **"Try again" said twice, 90pt apart** | all three failure sentences ended in it, above a button reading Try Again | the sentence keeps what only it can carry, the verb belongs to the button |
| Raw white opacities on the screen whose ground is the reason the `onDark` scale exists | 5 | 0 |

### 8. Memories, the map · **10/10** (2026-10-01, with one written exemption)

| Finding | Before | After |
|---|---|---|
| **The way back was invisible** | a white chevron on its own near-white disc: **1.10:1**. On the capture it is an empty white circle | an ink glyph on a light-pinned disc, **19.70:1** over every ground on the map |
| **The count badge was on the wrong block** | `.offset(x: 8, y: -8)` put it 8pt OUTSIDE the block's bounds, and `PlaceMap.maxOverlap` lets two places touch, so the "2" sat bodily on the orange block to the right of the purple one it counted | inset 4pt inside the block's own corner. Nothing is drawn outside a block |
| **The badge's ground was invisible** | its capsule renders (231, 230, 232) under the scrim against MapKit's (233, 233, 224): **1.01:1**, so the digits read as one more map label among the road shields | its ground is the block: numeral **8.15:1** |

**The structural finding on this screen is worth keeping.** The glass disc was
scored against the map's ground in five places and clears 3:1 against none of
them and never will, because it is a near-white material and so is most of a
map:

| ground | rgb | disc vs ground | white glyph | ink glyph |
|---|---|---|---|---|
| pale fill | (233, 233, 224) | 1.15:1 | 1.07:1 | 19.70:1 |
| park green | (203, 224, 198) | 1.31:1 | 1.07:1 | 19.70:1 |
| road grey | (213, 213, 206) | 1.38:1 | 1.07:1 | 19.70:1 |
| water blue | (132, 181, 221) | 2.04:1 | 1.07:1 | 19.70:1 |

So the GLYPH is the whole control and its ground is the disc, which is the one
thing on screen that does not change as you pan. A light-pinned disc under an
ink glyph is the only pairing that holds over the quiet, satellite and night
grounds alike. The recentre button was already built that way and measures
18.9:1; the back button was the one control that was not.

**The second sanctioned exemption in the audit, on check 10.** Every block with
more than one photograph cross-fades to the next on a seven second timer, with
nobody doing anything, which the rubric fails. It stays, because it is the
owner's own instruction ("multiple photos in the same spot should just become a
bundle, keep it in one bundle cycling through") and because it carries
information no still frame can: that there is more than one picture here. It is
written down rather than quietly passed, and like the segmented control's it
does not generalise.

### 15. Place / curated collection · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **The count line fails text contrast** | `inkQuiet` composites to (137, 136, 134) on (249, 247, 244): **3.31:1**, and on a place whose name has not resolved it is the only line on screen that is not a photograph | `inkTertiary`, **4.69:1** |
| **The screen can draw a title over a blank page** | open a place, open its last photograph, delete it: nothing matches, and what is left is a name, a hidden count and 800pt of ground. Check 1 has no subject at that moment | the day album's sentence, gated so it cannot flash before the store is read |

**A process point, recorded because it will happen again.** The count line's
3.31:1 had already been found by the agent auditing the day album, named
correctly, and left with the comment "it is not this file's to change". It WAS
that file's. A finding that is written down and not routed to somebody who owns
the file is a finding that does not land.

### 12. Profile · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **No accent on a page the Form already tints** | Done was `accentWarm`, (28, 26, 24): a near black at 16.2:1 beside a title at (37, 37, 37) and 14.3:1. Two words in the bar at the same weight, nothing saying which one was the button | `accentPrimary`, 4.38:1. No green anywhere on the screen |
| **The name's placeholder** | **(190, 190, 192), 1.73:1**, under even the 3:1 a plain UI element gets | `inkQuiet`, 3.3:1 |
| **The avatar's ground was a system grey** | `.quaternary`, (203, 203, 202), 1.51:1, and `ProfileView`'s own colour swatch ten points below it refuses `.quaternary` by name. The default underneath them both did not | `quietFill`, and the default is fixed rather than shimmed, so the drawing planned for this slot lands on a near-white disc instead of on a mid-grey blob already doing its job |
| **A fourth and a fifth type size** | 28 for the streak numeral, which is not one of the five rungs, and 11 for the chart axis, whose only two call sites in the app were this chart | 34 / 17 / 13 |
| **A void where a section break should be** | 75.3pt between the title's cap and the picture, against a 71.3pt card-to-card break, so the page's biggest gap was above its subject | about 64 |
| Two blacks on rows of one rank | (0, 0, 0) and (38, 38, 38) | one |
| Selection rings at full ink | `inkPrimary` 1.0 at a literal 2 | 0.55 at `strokeMedium`, which the add sheet settled on the same day, and whose comment already claimed Profile wore it when Profile did not |

### 13. Settings · **10/10** (2026-10-01)

| Finding | Before | After |
|---|---|---|
| **Every row was under 44** | measured **42.65pt**. The two sections settle the cause between them: Replays has no switch and measures the same, so the switch is not the driver. `SettingsIcon`'s 30pt frame plus 12.65 of row inset is | 32 plus the same inset: 44.65 |
| **A 96pt void above the mark** | against a 69.7pt card-to-card section break, and 24 of it was a `gapWide` added on top of two insets that were already stacked | about 61 |
| **The one row with no glyph** | "Reminder Time" began in the icon column, 43pt left of the other eleven | a clock glyph, and the column holds |
| Two reds on one destructive row | `warmRed` on the glyph and the system red on the word | one |

Measured and clean: the switches are (19, 139, 194), which is `switchOn`. **No
green survives anywhere in Settings**, which is the thing the owner asked for by
name.

### 19. Head picker · **10/10** (2026-10-01)

Inside Profile, below the fold. Its three failures were the same three as the
page it lives on, which is the argument for auditing a component where it
renders rather than where it is written: the full-ink selection ring, head and
look names at `inkQuiet` (3.3:1 on running text), and a 6pt spacing that is not
on the ladder.

### 17. Replay · **10/10** (2026-10-01)

The choreography was read out of `ReplayScript` and solved in Python against
the real pacing, metrics and packer, at 402x874: a week of 22 wins is 14.02s
and a month of 108 is 23.74s, and both have a shape (open, build with a day
pulse, hold, reveal, dance, close) rather than a loop of one beat.

| Finding | Before | After |
|---|---|---|
| **Two things moved at once that belonged in sequence** | the date's 0.45s arrival started at `revealStart`, so it ran across the first **45%** of a week's camera pull-out and 32% of a month's. A fifteen point caption arriving beside a whole tower changing scale is an arrival nobody sees. Meanwhile `holdAfterLast` left **0.5s in which nothing moved at all**, directly before it | the date starts at `revealStart - arrive`: overlap 0.45s to **0.00**, dead hold 0.50s to **0.05**, and the replay is not one frame longer. It reads as a sentence: the number stops, the period it belongs to appears under it, then the camera shows you the tower |
| **A glyph button stepped sideways when a label changed** | "Save Video" becoming "Saved to Photos" takes the centred row from 255 to 294pt, so the Replay button's edge jumps **19.5pt** under the other thumb, instantly | the same reflow on `gentleReveal`, keyed to the two titles only so the export ring's per-frame progress installs nothing |
| **The night ground had a warm lamp in the middle of it** | `GroundField.night[4]` is hue **0.11** among eight at 0.60. Sampled on the replay, the screen with the most empty dark ground: (273, 192) came out rgb(85, 77, 60), red 25 above blue, and (60, 180) on the same line rgb(46, 55, 68), red 22 below. A **47 level reversal across 213 points** on a page whose brightest value is 85 | hue 0.60, brightness unchanged. The DAY array had been given this pass twice and carries the reasoning; the night array had never had the same read |
| An off-ladder gap, privately typed | 6pt between the date and the Sample badge | `gapTight` |

The test that pinned the bug was moved rather than relaxed: `titleAndClose`
asserted the date STARTED at `revealStart`, which is the thing that was wrong.
Every assertion keeps its shape against the new anchor, and two were added so
the new rule can fail.

**Measured and left, with the number written down rather than tuned blind:**
`danceLift` is 10 world points and scales with the camera while `danceTilt`
does not, so a week's celebration lifts a block 5.74pt on a 51.1pt cell and a
month's lifts it **1.28pt on an 11.4pt cell**. Scaling the lift by the inverse
would make a month's blocks rise 77% of their own height and detach from the
tower, so it was not done. A coherent wave across 108 blocks is detectable
below a point and that could not be photographed either way.

---

# The second pass, 2026-10-01

Everything the first pass found and left, plus what a second read turned up.
Two of its findings were put to the owner with the tower rendered both ways,
and **he turned both of them down**, which is recorded here because a measured
failure that the owner has looked at and accepted is a different thing from one
nobody has seen.

### Overruled, with the measurement kept

| | measured | his call |
|---|---|---|
| **A block's white label** | 1.71:1 on the orange, 2.23 pink, 2.28 purple, 2.70 green, against 4.5. Dark ink measured 6.00 to 9.77 on the built tower | "I much prefered the white ink look over the dark ink." White ships. `TitleShadow`'s halo is named in the code as the dial if a title ever reads badly in daylight, which is the one test none of this has had |
| **The block corner** | a single block on the Wins tab is **8**, the merged run beside it is **12**, and the share card's single is 12.05. Three values for one object, one of them on the home screen | left at 8. The share card's two already agree to 0.05pt by design, so the only visible difference is on the Wins tab, and he has now seen it both ways |

### Fixed

| Finding | Before | After |
|---|---|---|
| **The retired wordmark was still shipping** | baked into the page 3 onboarding screenshot, on the first screen a new person sees. The camera itself lost its mark on 2026-09-30; the picture of the camera did not | painted out, and the thirds guide the fill erased rebuilt as a DELTA rather than a colour, because what is constant about that line is how much it lifts its column. The first attempt left a readable ghost at y 250 and y 330: the feather ramp started 14px above the glyphs and a 28px ramp only half covered their first and last rows |
| **Three primary actions in two colours** | onboarding's pill was blue, the restore confirm and the store retry were `inkPrimary`, a near black, which is the same thing that made Profile's Done read as a label | one `PrimaryCapsule`, blue, 4.69:1 |
| **The tint sat above `.toolbar` and never reached it** | Profile's Done measured **(10, 10, 10)** with `accentPrimary` applied upstream of the title and the toolbar. A toolbar item is hosted by the navigation bar, not by the content it was declared on | (0, 123, 178). The same move on Settings, before its toolbar grows a coloured action |
| **A save failure destroyed the head** | `HeadMakerModel.save()` failing called `fail(_:)`, whose only button runs `retake()`, so a disk hiccup threw away a walk through blink, smile, brows, surprised and wink | the head stays on the page, the sentence says it is not lost, and the button offers the save again |
| **The head maker's `.unavailable` was an unsignposted dead end** | "The camera isn't available here." and a Close button, on a state that on a phone only ever means the switch is off | "Turn the camera on for Strata in Settings." and Open Settings, matching the camera tab's own refused state |
| **The map's scrim washed the blocks as hard as the tiles** | an `.overlay` on the `Map`, and MapKit's annotations live inside it. Five sampled block-against-tile pairs ALL got worse with it on, and every photograph lost 10% of its luminance. On `.night` it moved the tiles 0.6 of one level out of 255 while taking a photograph at 180 down to 156 | deleted. A uniform wash takes every ratio toward 1:1 by construction, so it could never do the job its comment claimed. The separation comes from the stripped POIs and the muted emphasis: tiles 0.035 to 0.039 saturation against blocks 0.52 to 0.86 |
| **The map's size meant two opposite things** | the largest block on screen was 89.0 x 89.0pt and held ONE win; the block holding 24 was 44pt. Area also fed the merge rule that set it, so two lone Deep wins 59pt apart merged and were drawn as one 44pt block where the pair does not touch | one cell everywhere. The badge is the map's only quantity |
| **The count badge was half its block's height** | 24.3 x 22 on a 44pt cell, and its `minWidth` was decorative: 8.27 + 16 already beat the 24 floor, so a one-digit capsule was a 1.10:1 oval | 18 x 18, and a true disc for one digit for the first time |
| **The restore screen had never been photographed** | `-strataRestoreFrom` existed and nothing could make it a file: a backup exported from the store you are restoring into merges to zero and lands on the one state with no button | `-strataSeedBackup <n>` writes a real archive from values that never reach the context. The confirm measured above the fold at the first look, which was that screen's open check |

### Subtraction

829 lines deleted against 172 inserted, and about 150 of the insertions are the
notes saying what went and why.

`HighlightingTextField` (0 call sites) took `InputParser` and
`CategorySuggestionEngine` with it, because its highlighter was their only
reader. `MemoriesDrawer` (0) became a 35-line `DrawerMetrics`. `JaroFont` (0)
was deleted for the second time. `TowerMark` (0) took the widget target's only
two copies of the 14.7% corner. `ShareTowerCard`'s private tower became
`StaticTowerView`. `cornerRadiusSmall` and `cornerRadiusMicro` were exact
duplicates of `radiusControl` and `radiusMark`.

**And one thing that looked like duplication and was not.** `ShareTowerCard`'s
`cell * 0.147` reads like a drifted copy of `blockCornerRadius(forCell:)` and
moving it to the token would have made the card worse: at its capped 82pt cell
the literal gives 12.05 against a merged run's flat 12, and the token gives
11.38, which would open a 0.62pt mismatch inside one tower where there is none.
The ratio is also the source's: Figma's 40px on a 272px block.

**Left for a pass of its own:** 57 more zero-call-site `GridConstants` tokens.
Not bulk-deleted because about twenty of them carry the only surviving record
of a measurement, and because 57 deletions in a file three agents were editing
is a conflict rather than a cleanup.


---

# Dark mode, 2026-10-01

**The whole 22-screen pass measured one appearance.** `MainAppView` pins only
the camera to dark; every other tab follows the system, on the owner's own
instruction recorded in that file: "we should make the design work in both dark
and light mode while still keeping the etheral vibe." So half of what ships had
never been looked at, and all three of the things wrong with it were the same
kind of mistake: **a value tuned on a white page and reused on a black one.**

| Finding | light | dark, before | dark, after |
|---|---|---|---|
| **The lattice pane against the gutter beside it** | 1.03:1 | **2.91:1** | 1.11:1 |
| **The ground's spread, 5th to 95th percentile** | 3 levels | **21** | 6 |
| **The ground's red minus blue** | 0.0 | **-15.7** | 0.0 |

**The lattice.** Its pane is WHITE at an opacity, and white means two completely
different amounts depending on what is under it: over a 247 page 0.34 adds three
levels, over a 40 page it adds seventy three. The owner's words were "the lattic
doesnt blend in like light mode", and it was reading as a grid of grey boxes.
The dark value is derived from the light one's RATIO now rather than inheriting
its number, and `TowerLatticeTests` pins the two bands apart so nobody reads one
and applies it to the other.

**The ground, twice.** First "it has a weird looking light": nine mesh nodes
ranging 0.16 to 0.34 brightness, a 2.1x spread, where the day array's nine
whites span 1.03x. Then, after that was compressed, "why is the dark mode like
bluish like it doesnt look premium": the night array was nine BLUES at
saturation 0.30 to 0.48, and the day array is nine whites at saturation 0.

That second one is the interesting failure, because the file already had the
argument written in it, twice, about the day array: a page with an opinion about
its own colour is a page the illustrations and the photographs then have to
argue with. Nobody had ever applied the same sentence after dark.
`WarmBackground.top`'s dark value was never the problem: it is rgb(29, 28, 28),
already neutral. The blue was this one array sitting on top of it.

**Two wrong versions on the way, both worth not repeating.** Compressing the
brightness and leaving the saturation varying took the spread from 21 to 8 and
left the swing at 17: a cast rather than a lamp, but still a cast. Pinning the
saturation at 0.32 and moving only brightness made the cast even across the
page and therefore more obviously a choice. Neither was the question. The
question was why the page had a hue at all.
