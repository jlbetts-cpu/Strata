# Room

Written 2026-10-01, at the owner's instruction: "the spacing should almost feel
editorial like there should be a sense of space", "I just want everything thats
not like photos to have air to breathe", "focus on lots of white space to relax
the users eyes and give breathing room to the main elements", and the one that
sets the bar: "really understand and excicute top of the line design rather than
guessing understand the why and what we are doing to the fullest".

So this file is the why, with the sources on it, and the measurement of where
the app actually stands. `docs/screen-audit.md` is the pass; this is the
instrument and the argument behind a check that pass does not yet have.

**The instrument is `tools/page-room.py`.** It reads a 402x874 @3x capture, calls
a row empty when nothing is drawn across it, and reports in points: the share of
empty rows, the biggest unbroken run of them, and every drawn band with the gap
above it. `tools/screen-measure.py` supplies the horizontal edges.

---

## 0. What the captures actually are, before any number is believed

Twenty-four PNGs were taken at 402x874 @3x on 2026-10-01 into `/tmp/room/`.
**They are seventeen screens, not twenty-four**, and the failure is the one
`docs/screen-audit.md` already wrote down under "a capture that silently lands
on the wrong screen looks exactly like a capture":

| file | what it actually shows |
|---|---|
| `02-wins-empty` | the Wins tower with three blocks in it, not the empty state |
| `05-camera-review` | byte identical to `03-camera`: the blank viewfinder |
| `07-memories-empty` | the Memories month, again |
| `08-memories-map` | the Memories month, again |
| `10b-plan-empty` | byte identical to `10-plan` |
| `15-place` | the Memories month, again |
| `21-restore` | Settings, again |

Only two of those pairs are byte identical, which is why an md5 check alone
would have passed five of them. What caught the other five was that four files
of different sizes produced the same band structure to a tenth of a point. **A
second fingerprint is needed and it is cheap: the gap ladder.** Two different
screens do not have the same eleven gaps. Found twice independently, by the
person who took the captures and by this pass, from the two different
fingerprints.

**So this file ranks seventeen screens, not twenty-four.** Those seven files are
dropped outright rather than ranked, because a screen nobody has seen is not a
screen you can rate. Eight screens therefore have no measurement at all and are
named here so the gap is visible rather than implied: **Wins empty, Camera
review, Memories empty, Memories map, Place collection, Plan empty, Restore from
backup, and Replay and Head picker, which were never in the folder.** Onboarding
was captured on four of its six pages.

Three more things the set is not:

- `01-wins-tower` is a tower of **three** blocks, not forty. The screen audit's
  own lesson applies: the state that breaks a screen is usually the one no
  fixture reaches.
- **`01-wins-tower` is also already stale.** The Wins header lost the date and
  the "Your month" pill in the hour this was measured, and is now one icon
  button. Everything below reads Wins off **`/tmp/room/new-wins.png`**, which is
  the capture after that change: empty rows 76.0% to **77.6%**, header band 42.0
  to **30.3pt**, gap above it 16.0 to **27.7pt**. The 577pt break and the single
  gap are unchanged, which is the point: the header got quieter and the page's
  room did not move, because the room is below the header.
- **The tab bar is icon only now**, its three 10pt labels deleted, so the bottom
  band in every capture here is taller than the one that ships. That makes every
  measured gap above the tab bar slightly conservative. It does not change a
  ranking, because it moves every screen the same way.

Every number below is therefore the shape of the problem, not a final reading,
and the app was being edited by three other workers while it was measured.

**One blind spot in the instrument, named so nobody treats it as a finding.**
`page-room.py` calls a row empty when its left to right spread is 14 levels or
less. The Wins lattice is deliberately 1.03:1 against its page
(`docs/screen-audit.md`, onboarding page 2, and `TowerLatticeTests` pins it), so
the instrument reads the entire unbuilt tower as ground. Wins measures 76.0%
empty with a single 577pt break, and that break is not nothing: it is the
lattice. Do not let a tool that cannot see the lattice argue for darkening it.
That was refused once already.

---

## 1. The principles

Each one is phrased so a screenshot can fail it. The source is on each. Where a
number is the app's own rather than a source's, it says so.

### P1. A gap separates only by its ratio to its neighbours, not by its size

Grouping by proximity follows what Kubovy, Holcombe and Wagemans call the pure
distance law: the tendency to see one organisation rather than another is a
function of the **ratio** between the competing distances, and it is robust
under changes of scale. Doubling every gap on a page changes nothing about what
groups with what.

**Checkable:** a gap that is meant to be a section break must beat the page's
median gap by a ratio, not by a few points. The app's own ladder steps 8, 12,
16, 24, 32, which is 1.5x, 1.33x, 1.5x, 1.33x. **A gap that is 1.33x its
neighbour is one rung, not a break.** 32 against a page of 24s is 1.33: that is
why a page whose biggest gap is `gapSection` has no break on it.

Source: Kubovy, M., Holcombe, A. O., & Wagemans, J. (1998). On the lawfulness of
grouping by proximity. *Cognitive Psychology*, 35(1), 71 to 98.
https://colab.ws/articles/10.1006/cogp.1997.0673

### P2. Space and a box are alternatives, and choosing a box means the space has lost

Palmer's common region is a grouping principle of its own, and in his displays a
closed contour drawn over an unchanged set of dots **flipped** the preferred
grouping away from the one proximity produced. A box beats a gap.

**Checkable:** on any page where a divider, a card edge or a form well is doing
the grouping, the gaps around it are decorative and may be any value at all,
which is exactly how Settings ended up with fourteen gaps and ten distinct
values. If space is supposed to group, nothing else may be grouping.

Apple says the same thing in its own order: "you might use negative space,
container shapes, or separator lines to show which elements are related and
which are unrelated" (HIG, Layout). Negative space is named first and it is the
one this app has chosen, because `CLAUDE.md`'s rule is that chrome does not get
rims, frosted bands or blurred edges.

Sources: Palmer, S. E. (1992). Common region: A new principle of perceptual
grouping. *Cognitive Psychology*, 24(3), 436 to 447.
https://eric.ed.gov/?id=EJ450926 ·
Apple HIG, Layout. https://developer.apple.com/design/human-interface-guidelines/layout

### P3. White space raises perceived value, and that is a measured effect, not a mood

Pracejus, Olsen and O'Guinn traced white space in advertising specifically
because its history is documented, and summarise the prior work as: the presence
of white space enhances perceived quality, prestige and leadership. The same
paper is also where the limit of the claim lives: the effect is cultural, and
consumers in India and Hong Kong did **not** rate high white space ads more
highly, where United States consumers did.

**Checkable:** nothing, directly. This is the warrant for spending screen on
emptiness at all, which is why it is here rather than in the discarded pile. It
does not license any particular number.

Source: Pracejus, J. W., Olsen, G. D., & O'Guinn, T. C. (2006). How nothing
became something: White space, rhetoric, history, and meaning. *Journal of
Consumer Research*, 33(1), 82 to 90.
https://econpapers.repec.org/article/oupjconrs/v_3a33_3ay_3a2006_3ai_3a1_3ap_3a82-90.htm

### P4. Emptiness has a ceiling and it is measurable

Coursaris and Kripintris built three versions of one e-commerce site at 25%, 50%
and 75% white space and put them in front of 118 participants. Perceived
usability **fell** once white space passed 50%. This is the only study found
that manipulated white space as a quantity on a screen and measured the result.

**Checkable:** a page is not better for being emptier. What the number cannot do
is transfer literally, because their measure is area on a desktop commerce page
and this app's is rows on a phone. What transfers is the shape of the curve:
there is a peak and it is not at the right-hand end.

Source: Coursaris, C. K., & Kripintris, K. (2012). Web aesthetics and usability:
An empirical study of the effects of white space. *International Journal of
E-Business Research*, 8(1). https://dl.acm.org/doi/abs/10.4018/jebr.2012010103

### P5. The frame is the largest white on the page, and on a phone it is vertical

The Van de Graaf canon, which Tschichold popularised as the golden canon of book
page construction, divides page width and height into ninths and puts the text
block at 6/9 of the width: inner margin 1/9, outer 2/9, in the ratio 2:3:4:6
(inner, top, outer, bottom). The transferable claim is not the fractions, it is
that **the margin around the block is bigger than any gap inside it**, and that
the four margins are deliberately unequal.

On a 402pt screen the fractions do not transfer: 1/9 is 44.7pt a side, which
would leave 312pt of content, and a four column tower would lose 4pt off every
cell. So this app cannot buy its frame horizontally. **It has to buy it
vertically**, which is also the axis a phone has to spare, and it is the axis the
`SectionHeading` 64 already spends on.

**Checkable:** the page's biggest gap must be a vertical break between two
pieces of content, and the horizontal margin must be one value, not nine.

Source: Canons of page construction (Van de Graaf, Tschichold).
https://en.wikipedia.org/wiki/Canons_of_page_construction ·
https://retinart.net/graphic-design/secret-law-of-page-harmony/

### P6. Apple publishes no iOS content margin, so the app's 16 is its own decision

The HIG's Layout page gives safe areas and layout guides and, for numbers, gives
tvOS: "Inset primary content 60 points from the top and bottom of the screen,
and 80 points from the sides." **For iOS it gives none.** SwiftUI's `.padding()`
documents a platform and context defined amount rather than a value. The numbers
Apple does publish that bear on space:

| | value | source |
|---|---|---|
| default control size, iOS | **44x44 pt** | HIG, Accessibility |
| minimum control size, iOS | **28x28 pt** | HIG, Accessibility |
| padding between controls | "about **12 points** of padding around a control" | HIG, Accessibility |
| body leading | 17pt type on **22pt** leading | HIG, Typography |

**Checkable:** 44pt targets, already check 8. The rest is this app's to decide
and to defend, which is what section 7 below does. Anyone who says "16 is the
iOS margin" is quoting a convention, not a guideline.

Sources: https://developer.apple.com/design/human-interface-guidelines/layout ·
https://developer.apple.com/design/human-interface-guidelines/accessibility ·
https://developer.apple.com/design/human-interface-guidelines/typography ·
https://developer.apple.com/documentation/SwiftUI/View/padding(_:_:)

### P7. A page ends; it does not stop

HIG, Layout: "Order content by relative importance. People often start by viewing
content in reading order, that is, from top to bottom and from the leading to
trailing side, so place the most important items near the top and leading side."
And `docs/illustrations.md` rule 5, which is the owner's own reference: "Enormous
negative space. The figure sits small in a big empty field." A field is **around**
a figure. Space below the last thing on the page is not a field, it is the
bottom of a list of controls.

**Checkable:** the biggest break on a page must fall between two drawn bands
that are both content. If the biggest break is the one under the last band, the
page ran out rather than composed.

### P8. The spacing system needs rungs above its component rungs

Carbon's published scale is 2, 4, 8, 12, 16, 24, 32, 40, 48, 64, 80, 96, 160,
and the documentation says why it is shaped that way: it "includes both small
increments needed to create appropriate spatial relationships for detail-level
designs as well as larger increments used to control the density of a design",
and the tokens are used "inside of components for building and between
components for layout spacing". Strata's ladder stops at 32, which is a
component value. It has nothing for the page.

Source: https://carbondesignsystem.com/elements/spacing/overview/

---

## 2. What was discarded, and why

- **"White space between paragraphs and in the margins increases comprehension
  by almost 20% (Lin, 2004)."** This is the single most repeated number in
  writing about white space and it is **false**. Carl Myhill wrote to Professor
  Lin, who replied: "The said publication of mine has nothing to do with
  whitespace, not to mention the so-called increase of comprehension by 20%."
  Lin's real 2004 paper measured retention in 24 adults aged 62 to 80 across
  presentation media. The claim now recirculates attributed to Human Factors
  International and to Nielsen Norman Group as well as to Lin, and none of them
  has a study behind it. **If a brief, an audit or an agent quotes 20%, that is
  a tell that nothing underneath was checked.**
  https://www.linkedin.com/pulse/lin-2004-did-discover-margins-white-space-increase-20-carl-myhill
  · https://www.humanfactors.com/newsletters/yeah_but_can_you_give_me_a_reference.asp
- **HEYTEA's spatial specification.** There is not one. The 2025 identity work is
  published as a mark, a logotype, a packaging system and an art direction; what
  is documented about the change is that the silhouette lost its hair and its
  finger detail and gained a gradient gold. **No margin, grid or spacing spec is
  public.** So HEYTEA cannot supply a number to this app and it was never going
  to. What it supplies is the one rule `docs/illustrations.md` already wrote
  down, and that rule is about a drawing in a field, not about a layout grid.
  https://www.behance.net/gallery/246368193/HEYTEA-Branding ·
  https://designcompass.org/en/2026/01/14/heytea-subtly-younger-rebrand/
- **The F-pattern and "80% of attention falls on the left half".** Eyetracking on
  desktop web reading, repeated secondhand. Not measured on a 402pt phone and
  not about space.
- **Everything else that came back from a search for "white space premium".** It
  is the same four sentences, uncited, on twenty sites.

---

## 3. What this contradicts in the app, flagged rather than acted on

Several of the app's decisions would be "found" by a naive reading of the above.
They are settled and they stay.

| decision | what a space audit would wrongly say |
|---|---|
| **The Wins lattice at 1.03:1** | that 97% of the page's emptiness sits in one 577pt run, so the page is a void. It is the unbuilt tower. The audit explicitly refused to raise the lattice to meet the slot: "the scaffolding and the control should differ in kind, not both get louder." |
| **Store unavailable's 484pt gap** between the sentence and the pill | that no gap should be sixteen times the median. That composition is the audit's own fix and the pill's position, 766 to 816, is matched to the walkthrough's deliberately. |
| **The tower's 4pt gutter** | that it is off the ladder. `GridConstants.spacing` says why in as many words: blocks that touch read as one built object, and 4 is the wrong number for anything that is a set of separate things. **Check 11 below measures gaps between bands, never gutters inside one.** |
| **Add a win at 38% empty**, cut from 49% | that it needs more emptiness. It does not. It needs its existing emptiness moved from the bottom of the sheet into a break between two groups. |
| **The 32pt segmented control** | that air should be bought by shrinking it. It is a sanctioned exemption and it is UIKit's metric. |
| **`horizontalPadding` 16** | that the canon wants 44.7. See P5 and section 7. |

---

## 4. The measurement

402x874, @3x, usable band 781pt (59pt of status bar off the top, 34pt of home
indicator off the bottom). Gaps are between consecutive drawn bands; bands
closer than 8pt are merged, because a stack of letter rows is leading and not a
gap. "margin" is the modal left edge of the drawn bands that are not full bleed.

| screen | empty | biggest break | at y | gaps | median | max | max/med | margin | margin vs max |
|---|---|---|---|---|---|---|---|---|---|
| Wins, tower (`new-wins`) | 77.6% | 577 | 117 to 694 | 1 | 577 | 577 | 1.00 | 327 | n/a, one icon |
| Camera, viewfinder | 6.2% | 40 | 751 to 791 | 2 | 24.2 | 40.0 | 1.66 | 54 | 1:0.7 |
| Camera, refused | 79.8% | 273 | 59 to 332 | 4 | 33.7 | 254.7 | 7.56 | 70 | 1:3.6 |
| Memories, month | 55.9% | 75 | 466 to 540 | 10 | 43.5 | 74.7 | 1.72 | 22 | 1:3.4 |
| Add a win | 57.8% | 301 | 539 to 840 | 7 | 23.0 | 33.3 | **1.45** | 16 | 1:2.1 |
| Plan | 90.2% | 653 | 187 to 840 | 2 | 23.8 | 39.7 | 1.66 | 16 | 1:2.5 |
| Block card | 52.5% | 218 | 622 to 840 | 8 | 26.3 | 38.0 | **1.44** | 16 | 1:2.4 |
| Profile | 44.3% | 60 | 107 to 167 | 8 | 39.3 | 60.3 | 1.53 | 0 | n/a |
| Settings | 43.6% | 45 | 122 to 167 | 14 | 19.8 | 45.0 | 2.27 | 0 | n/a |
| Day album | 71.4% | 520 | 173 to 694 | 2 | 269.0 | 520.3 | 1.93 | 16 | 1:33 |
| Photo viewer | 21.2% | 60 | 653 to 713 | 3 | 57.3 | 60.3 | **1.05** | 16 | 1:3.8 |
| Head maker | 68.3% | 227 | 553 to 780 | 3 | 37.3 | 227.0 | 6.08 | 132 | 1:1.7 |
| Onboarding 1 | 49.1% | 159 | 59 to 218 | 4 | 50.7 | 84.3 | 1.66 | 17 | 1:5.0 |
| Onboarding 2 | 52.9% | 100 | 118 to 218 | 4 | 88.3 | 99.7 | **1.13** | 16 | 1:6.2 |
| Onboarding 3 | 38.6% | 100 | 118 to 218 | 5 | 56.0 | 100.0 | 1.79 | 16 | 1:6.3 |
| Onboarding 4 | 37.9% | 100 | 118 to 218 | 5 | 56.0 | 100.3 | 1.79 | 16 | 1:6.3 |
| Store unavailable | 78.4% | 484 | 282 to 766 | 3 | 30.0 | 483.7 | 16.12 | 16 | 1:30 |

### The full gap ladder, screen by screen, with the counts

Snapped to the nearest of 8 / 12 / 16 / 24 / 32 / 64.

| screen | measured gaps | on the rungs |
|---|---|---|
| Wins, tower (`new-wins`) | 577 | 64 x1 |
| Camera, viewfinder | 8.3, 40.0 | 8 x1, 32 x1 |
| Camera, refused | 16.3, 23.7, 43.7, 254.7 | 16 x1, 24 x1, 32 x1, 64 x1 |
| Memories, month | 11.7, 15.7, 33.7, 39.7, 40.0, 47.0, 47.0, 47.3, 68.7, 74.7 | 12 x1, 16 x1, **32 x6**, 64 x2 |
| Add a win | 10.3, 11.0, 14.0, 23.0, 26.7, 29.7, 33.3 | 12 x3, 24 x2, 32 x2 |
| Plan | 8.0, 39.7 | 8 x1, 32 x1 |
| Block card | 10.3, 11.0, 14.0, 23.0, 29.7, 31.0, 32.0, 38.0 | 12 x3, 24 x1, 32 x4 |
| Profile | 10.3, 14.3, 17.3, 36.0, 42.7, 44.0, 56.0, 60.3 | 12 x1, 16 x2, 32 x3, 64 x2 |
| Settings | 11.0, 11.0, 12.0, 12.0, 13.0, 13.0, 14.7, 25.0, 25.0, 30.3, 35.7, 39.3, 42.0, 45.0 | **12 x6**, 16 x1, 24 x2, 32 x5 |
| Day album | 17.7, 520.3 | 16 x1, 64 x1 |
| Photo viewer | 46.7, 57.3, 60.3 | 32 x1, **64 x2** |
| Head maker | 26.3, 37.3, 227.0 | 24 x1, 32 x1, 64 x1 |
| Onboarding 1 | 10.7, 18.0, 83.3, 84.3 | 12 x1, 16 x1, 64 x2 |
| Onboarding 2 | 17.7, 83.0, 93.7, 99.7 | 16 x1, **64 x3** |
| Onboarding 3 | 16.7, 17.7, 56.0, 57.0, 100.0 | 16 x2, 64 x3 |
| Onboarding 4 | 10.7, 18.0, 56.0, 56.7, 100.3 | 12 x1, 16 x1, 64 x3 |
| Store unavailable | 10.7, 30.0, 483.7 | 12 x1, 32 x1, 64 x1 |

### The three numbers that came out of the whole set

- **85 gaps across 17 screens, and 21 of them land within 1pt of a rung.** That
  is **25%**. The other 75% are not necessarily wrong in the source: a measured
  band to band gap carries each band's own ascender and descender air, so a
  declared 24 renders larger than 24. The finding is not that the source is off
  the ladder. It is that **what a reader actually sees is the measured gap**,
  and `docs/screen-audit.md` check 7 reads the source.
- **25 distinct measured values between 30 and 60pt**: 30.0, 30.3, 31.0, 32.0,
  33.3, 33.7, 35.7, 36.0, 37.3, 38.0, 39.3, 39.7, 40.0, 42.0, 42.7, 43.7, 44.0,
  45.0, 46.7, 47.0, 47.3, 56.0, 56.7, 57.0, 57.3. **This app has twenty-five
  different medium gaps.** Nobody can see the difference between 42.0 and 43.7,
  which is the whole problem: twenty-five values and one rhythm would look
  identical on any single screen and do not look identical across seventeen.
- **28 of 85 gaps, 33%, sit strictly between 32 and 64**, which is the span the
  ladder has no rung in. That is where the drift lives.

---

## 5. Ranked, most air to least

**Seventeen screens: every capture in `/tmp/room/` except the seven listed in
section 0 as unverified**, with Wins read off `new-wins.png`. The eight screens
named there as never captured are absent from this ranking and from the work
list, and nothing below should be read as a verdict on them.

Ranked on the share of empty rows, with the thing that qualifies it beside it.
**Emptiness is not air.** The right-hand column is the share of a screen's whole
empty area that sits in its single biggest run: a high number means the page has
one void rather than breathing throughout.

| | screen | empty | in one run | the qualification |
|---|---|---|---|---|
| 1 | Plan | 90.2% | **93%** | not air. One line of type and 653pt of nothing under it |
| 2 | Camera, refused | 79.8% | 44% | a black page with four objects on it. Reads as air because it is dark |
| 3 | Store unavailable | 78.4% | 79% | air, and composed: the break is between the copy and the pill, both content |
| 4 | Wins, tower | 77.6% | **95%** | the lattice, which the instrument cannot see. Needs a human look, not a number |
| 5 | Day album | 71.4% | **93%** | not air. A title, a count line, and the tab bar 520pt later |
| 6 | Head maker | 68.3% | 43% | air above the outline, then 227pt and a lone caption at the bottom |
| 7 | Add a win | 57.8% | **67%** | 301pt of it is below the last control |
| 8 | Memories, month | 55.9% | 17% | **the best distributed page in the app.** The 64 break is working |
| 9 | Onboarding 2 | 52.9% | 24% | air, but three of its four gaps are within 17% of each other |
| 10 | Block card | 52.5% | **53%** | 218pt below the Delete pill |
| 11 | Onboarding 1 | 49.1% | 42% | the 159 at the top is the page's own top margin, not a break |
| 12 | Profile | 44.3% | 17% | distributed, but no margin: the Form card is full bleed |
| 13 | Settings | 43.6% | 13% | distributed and all of it small. A drawn band every 52pt |
| 14 | Onboarding 3 | 38.6% | 33% | the artwork takes 330pt of the page |
| 15 | Onboarding 4 | 37.9% | 34% | same |
| 16 | Photo viewer | 21.2% | 36% | exempt: the photograph is the subject |
| 17 | Camera, viewfinder | 6.2% | 82% | exempt: the viewfinder is the subject |

**What makes the bottom ones tight, named:**

- **Settings and Restore** (the same capture): fourteen gaps, ten distinct
  values, six of them on the 12 rung, biggest 45. There is no gap on this page
  big enough to say the subject changed, and the grouped card runs 0 to 402pt,
  so the page has no outer margin at all: the only white on it is between rows.
- **Profile**: same full bleed card, and its biggest gap, 60.3, sits between the
  toolbar and the avatar, so the page's largest piece of white is above its
  subject rather than between its sections. The audit already cut that void from
  75.3 to about 64 and the capture still reads 60.3.
- **Onboarding 3 and 4**: the device mock is 330pt of a 781pt page, 42%, and it
  is centred at a 125pt left edge while everything else is at 16. Two left edges
  on one page.
- **Photo viewer**: three gaps, 46.7, 57.3, 60.3, a spread of 13.6pt across the
  whole page. Nothing on it is grouped with anything else. It is exempt from the
  ground clause because its subject is a photograph, but not from this.

---

## 6. Proposed check 11 for `docs/screen-audit.md`

> | 11 | **The page has room** | Four clauses, measured off a 402x874 @3x capture with `tools/page-room.py`. All four must pass. |

### 11a. There is ground

**At least 35% of the usable rows have nothing drawn on them.**

Exempt: a screen whose subject is a full bleed photograph or a viewfinder. The
camera and the photo viewer are measured on their chrome band only, because
`docs/illustrations.md` is explicit that a photograph is a picture and not
chrome.

**Nothing in the app fails this today.** The lowest non-exempt screens are
onboarding 4 at 37.9% and onboarding 3 at 38.6%. It is a ratchet, so the next
dense page fails before it ships rather than after somebody notices. The number
is the app's own distribution, not a source's, and it says so here rather than
pretending otherwise.

### 11b. Both ends of the ladder are on the page

**On a page with three or more gaps: at least one gap measuring 17pt or less,
and at least one measuring 48pt or more.**

This is the clause check 7 cannot do. Check 7 can see that a gap is on the
ladder; it cannot see that every gap on a page is the same rung, which is
exactly what a page with no air looks like. A page whose gaps all sit in the
middle has one spacing, and one spacing is the same as none: by P1 nothing on it
groups, because nothing beats its neighbours by a ratio.

Three numbers in that sentence, each with a reason:

- **48 and not 36 or 40**, from the arithmetic in P1. The ladder's own steps are
  1.33x and 1.5x, so a gap has to clear the rung above it by more than a rung to
  read as a different kind of thing. Measured, the smallest gap in the app that
  reads unambiguously as a break is Memories' 74.7, which is `gapSection * 2`
  plus the calendar cell's own bottom air. 48 is the floor at which a break is
  still a break once the type's own air is taken back out.
- **17 and not 16**, because a measured band to band gap carries each band's
  ascender and descender air, so a declared 16 renders at 16.3 to 18.0 across
  this set. 17 is 16 plus one point of rendering.
- **Three gaps**, because a page of two or three bands has nothing to group. Its
  failure, if it has one, is that it has two bands, and 11c catches that. Wins,
  the camera viewfinder, Plan and Day album are all exempt here for that reason
  and three of the four fail elsewhere.

**Fails today:** Add a win (biggest gap 33.3), Block card (38.0), Settings and
Restore (45.0), Onboarding 2 (smallest gap 17.7), Head maker (26.3), Photo
viewer (46.7, and its three gaps span 13.6pt in total).
**Passes:** Memories, Profile, Onboarding 1, 3 and 4, Store unavailable, Camera
refused.

### 11c. The air is between things, not after them

**The biggest break on the page must fall between two drawn bands that are both
content.** If the biggest break is the one under the last band, the page stopped
rather than ended.

P7, and the owner's own reference: the figure sits small in a big empty field,
and a field is around a figure. A tab bar does not count as the second band.

**Fails today:** Plan (653pt under the last line, against a biggest interior gap
of 39.7), Add a win (301pt), Block card (218pt), Day album (520pt between the
count line and the tab bar).

### 11d. One margin, not ten

**Every left aligned band starts within 2pt of the same value, and that value is
at least 16.** Centred artwork is exempt and is declared, not assumed.

**Fails today:** Memories, whose ten left aligned bands start at 6.0, 16.0,
16.7, 17.0, 18.0, 20.7, 22.3, 22.3, 22.3 and 22.7, a spread of 16.7pt on one
page. Settings and Profile, whose grouped Form card is full bleed so the page's
margin is 0. Onboarding 1, which has a band at 4.3.

### Worked example that passes: Store unavailable

| clause | measured | |
|---|---|---|
| 11a ground | 78.4% empty | PASS |
| 11b both ends | smallest gap 10.7, biggest 483.7 | PASS |
| 11c break between content | the 483.7 falls between the copy ending at y282 and the pill starting at y766; the tail under the pill is 24 | PASS |
| 11d one margin | 16.0, 16.3, 16.3, 16.0 | PASS |

This screen was rated 10/10 on the existing ten checks and it also passes the
new one, which is the result you want from a check you are adding: it does not
condemn the screens that are already right.

### Worked example that fails: Add a win

| clause | measured | |
|---|---|---|
| 11a ground | 57.8% empty | PASS |
| 11b both ends | smallest 10.3, **biggest 33.3** | **FAIL** |
| 11c break between content | **the biggest break is 301pt and it is under the last band**, at y539 to 840, against a biggest interior gap of 33.3 | **FAIL** |
| 11d one margin | 16.0, 16.7, 16.0, 16.7, 16.0, 16.0 | PASS |

This screen was also rated 10/10, twice, and re-rated after its dead space was
cut from 49% to 38%. **The emptiness was treated as the fault and it was not.**
The fault is that the sheet is seven controls at 10, 11, 14, 23, 27, 30 and 33pt
apart, which is one rhythm with no break in it, and then a third of the page
underneath doing nothing. **That is the argument for check 11 existing**: ten
checks looked at this screen and none of them could see it.

---

## 7. The ladder

### The ladder needs a top rung, and it is 64

**Add `gapPage = 64` and name it.** It already ships: `SectionHeading` sets
`.padding(.top, GridConstants.gapSection * 2)` with a comment arguing exactly
this, and that comment is right. What is missing is the token, and
`GridConstants`' own words say why that matters: "A rung that exists in practice
and not in the ladder is how a ladder rots: the next person picks 22 or 26
because nothing says otherwise." Twenty-five distinct measured values between 30
and 60pt is that rot, measured.

The argument from Part 1, not from taste:

1. **P1.** A break has to beat its neighbours by a ratio. 32 against a page of
   24s is 1.33, which is one rung and is inside the ladder's own step. 64 against
   24 is 2.67. Measured on Memories, the 64 renders as a 74.7pt break against a
   median gap of 43.5, which is 1.72x, and it is the only unambiguous break on
   any screen that is not also a dead tail.
2. **P8.** Every mature system has layout rungs above its component rungs and
   says so. Carbon's scale carries 48, 64, 80, 96 and 160 above its component
   values for exactly this, "larger increments used to control the density of a
   design". Strata's ladder stops at a component value.
3. **P5.** A phone cannot buy its frame horizontally, so it has to buy it
   vertically, and 32 is not enough to be a frame.

### What NOT to add

**Do not add 40 or 48.** The temptation is obvious: 28 of the 85 measured gaps,
33%, fall strictly between 32 and 64, and a 40 or a 48 would "capture" them. It
would do the opposite. Those 28 gaps are 25 different values, and a rung at 40
legitimises the drift instead of ending it. Every one of them should snap to 32
or to 64, and the decision of which is the decision about whether that place is
a gap or a break. **Six rungs: 8, 12, 16, 24, 32, 64.**

### The margin stays 16

Not from deference. Apple publishes no iOS content margin (P6), so this is the
app's call and it has to be argued.

- **What a bigger margin costs, measured.** Content width is 402 minus 32, which
  is 370. At four columns with the tower's three 4pt gutters, the cell is
  (370 - 12) / 4 = 89.5. At a 24pt margin it is (402 - 48 - 12) / 4 = 85.5:
  **4pt off every block in the app**. `GridConstants.blockReferenceCell` is 86.5,
  `blockCornerRadius(forCell:)` is derived from the live cell, and the share
  card's 12.05 and the merged run's 12 agree to 0.05pt deliberately. A margin
  change lands on the one object that is the app's identity, to buy 8pt a side
  on pages that are not the tower.
- **What it would buy is the wrong thing.** P5: the canon's claim is that the
  frame is bigger than any gap inside the block. On a 402pt screen that is
  unreachable horizontally at any sane margin: the canon's own 1/9 is 44.7pt a
  side. Going 16 to 24 does not approach it and does not change which white is
  biggest. The frame has to be vertical and the 64 is how it is paid for.
- **16 already clears the only horizontal rule it has to.** It exceeds every
  gutter inside a row: the gallery's 2pt hairline, the tower's 4, the chip rows'
  12. And it exceeds Apple's own "about 12 points of padding around a control"
  (P6).

**What the margin needs is not a bigger number, it is one number.** Memories
renders ten different left edges between 6.0 and 22.7 on a single page, and
Settings and Profile render none at all because the Form card is full bleed.
That is clause 11d and it is free.

---

## 8. The work list, in the order a person feels it

### 1. Add a win, and Block card, which is the same file

Fails 11b (biggest gap 33.3 and 38.0, nothing at 48) and 11c (301pt and 218pt of
nothing under the last control).

This is first because it is the screen the app is for. `docs/product-direction.md`
settles arguments with "recording a win must be the fastest thing in the app",
and the sheet that does it is seven controls at 10, 11, 14, 23, 27, 30, 33pt
apart: one undifferentiated rhythm, and then a third of the sheet empty
underneath.

**The fix is a redistribution, not more emptiness.** The sheet has two decisions
(colour, size) and one subject (the block it is making). Put a 64 between the
decisions and the subject, so the page reads as "choose, then look at what you
made", which is the cause before effect order the audit already chose when it
moved the well below the controls. Snap the label to control gaps to 8 and 16
and the control to control gaps to 24. The 300pt tail then belongs to the well,
which is the one object on the sheet whose job is to be big.

### 2. Plan

Fails 11c: a 653pt tail, 93% of the page's emptiness in one run, 16x the biggest
interior gap. Exempt from 11b with only two gaps, and that is the diagnosis, not
a let off: a page with two bands on it has nothing to space.

90.2% empty with one line of type on it. The audit already made the whole
remainder tappable, which fixed the interaction and left the composition. This
page needs either a second thing on it or a shorter page: a sheet detent that
ends where the content ends would turn 653pt of void into a sheet that is the
size of its contents, which is the subtraction answer.

### 3. Day album

Fails 11c: 520pt between the count line and the tab bar, 93% of the page's
emptiness in one run.

A day with two wins draws a date, a count, and then nothing for two thirds of
the screen. The photographs that would fill it are the page's subject and on a
light day there are none. Same answer as Plan: the page should be as tall as its
content, or the empty state should be the page with nothing in it rather than
the page with a hole in it. `docs/screen-audit.md` has already made that exact
call once, on Memories empty.

### 4. Settings, and Restore, which shares its capture

Fails 11b (biggest gap 45.0, nothing at 48) and 11d (margin 0).

The densest page in the app: fourteen gaps, ten distinct values, six on the 12
rung, a drawn band every 52pt, and a grouped card that runs 0 to 402pt so the
page has no outer margin at all. The audit already took the rows from 42.65 to
44.65 and cut a 96pt void to 61. What is left is that the page has no break of
its own: every gap on it belongs to the system Form. A 64 above each section
label, through `FormSectionLabel` rather than `SectionHeading`, is the one move,
and it is the move that makes the page's own structure visible instead of
UIKit's.

### 5. Memories, the month

Fails 11d: ten left edges between 6.0 and 22.7 on one page, a spread of 16.7pt.

Best page in the app on every other clause: 17% of its emptiness in one run,
both ends of the ladder present, the 64 break landing at 74.7 and reading. What
spoils it is horizontal. The calendar's cells start at 22.3, the title at 18.0,
the headings at 17.0, the shelf at 16.0, and the month picker's chevron box
reaches 6.0. One margin and this screen is the reference the others are measured
against.

### 6. Profile

Fails 11d (margin 0, full bleed Form card). Its biggest gap, 60.3, is above its
subject rather than between its sections, which the audit found once already and
cut from 75.3.

### 7. Onboarding 2

Fails 11b: no gap at or under 16, and three of its four gaps are 99.7, 93.7 and
83.0, within 17% of each other. Spacious and flat. Something on this page should
be tight to something else so that the big gaps mean anything.

### 8. Head maker

Fails 11b: smallest gap 26.3. A 227pt break and then a 11.7pt caption alone at
y780 with 48.3 under it, which reads as a label that fell off the bottom.

### 9. Wins, the tower

Passes every clause that can be measured, and the measurement is not trustworthy
here: the instrument reads the lattice as ground, so 95% of the page's emptiness
is in one 577pt run that is not empty. **This screen needs a look, not a
number**, and it needs one at forty wins, which no capture in this set contains.

The header change that landed while this was being written is the right
direction and the numbers say so: taking the date and the month pill off moved
the page from 76.0% to 77.6% empty and the header band from 42.0 to 30.3pt,
while the 577pt break did not move at all. **The room on this page was never in
the header.** It is the field the tower grows into, and the next thing to measure
is what that field looks like when forty blocks are standing in it.

### Not on the list

Camera viewfinder, camera refused and photo viewer, all exempt under 11a because
their subject is the picture. The photo viewer still fails 11b on its own terms
(three gaps spanning 13.6pt) and should be looked at when the exemption is next
reviewed, but it is a dark full bleed screen and the fix is not spacing.
