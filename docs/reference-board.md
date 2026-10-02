# What the references actually say

**Part one** is the owner's `pretty ui` board, 89 pins, read 2026-09-30, written
down because it corrected several things built that week from a wrong reading.
**Part two**, from 2026-10-01, is four UX videos he sent, read the same way.

The rule for both is the same and it is the only thing that makes a reference
useful: **a reference is read, not applied.** Every item below is sorted into
what transfers to this app with the place it lands, what this app already does
(so nobody "adds" it twice), and what does not transfer with the reason. A
takeaway that cannot name a file is a takeaway that will be quoted in a commit
message and never built.

---

## 1. The single biggest finding: soft-3D objects, not flat panes

The dominant motif on the board, by a wide margin, is **things that look
moulded**. Ceramic discs. A water ripple in a pale surface. Glass pills with a
real specular highlight along the top. An entire sheet of "WEB UI SET · control
elements" that is puffy skeuomorphic knobs and buttons. Soft-3D app icons with
volume.

Every one of them has the same three ingredients:

1. a **bright rim or highlight along the top edge**, where the light is,
2. a **soft interior shading** that makes the surface read as curved rather than
   printed,
3. a **wide, faint occlusion shadow** underneath, close to the object.

**This is what he meant by "a physical blob of liquid glass".** He was not
describing Apple's Liquid Glass and its refraction — he was describing THESE,
which are a different tradition entirely: moulded volume, lit from above.

That is why the custom lens shader missed and why `.regular` glass missed. Both
were chasing refraction. The board wants **volume**.

## 2. Blurred colour is an OBJECT, never a wash

There are a lot of aurora gradients on this board — magenta into orange into
blue, heavily blurred, beautiful. And in almost every case the gradient is
**contained**: a circle, a blob, a card, sitting on a plain neutral field.

Nowhere on the board is a soft gradient smeared behind an entire interface.

**This is the direct correction to what I built.** The `DayGround` work put the
light behind everything as an all-over wash, which is why it kept reading as
"too strong" and "just red" no matter how it was tuned. The board's answer is the
opposite shape: a calm ground, with the light concentrated into one contained
object on it.

## 3. The ground is grey, not white

Pin after pin sits on a light neutral grey rather than white, and lets white
elements float above it. That is what gives the white things somewhere to be
bright against — the exact headroom problem the lattice ran into when the page
was lightened to 240 and the panes disappeared.

A grey ground solves it structurally rather than by tuning an opacity.

## 4. Chrome is crisp; softness lives in imagery

The soft, blurred, glowing things on this board are almost always **content**.
The controls over them are sharp: dark pill navs, crisp capsule buttons, legible
type, hard edges. Nothing is softly blurred AND a control at the same time.

## 5. Shapes: pills and generous radii

Floating pill tab bars, capsule buttons, rounded rectangles with big corners.
Strata already agrees with this.

---

## What this means, component by component

**The ground.** Stop the all-over wash. A calm neutral light grey, slightly
darker than the panes, so the tower and the lattice float on it. The sky scene
becomes either nothing or one contained element, not a full-bleed backdrop.

**The empty slot.** This is the board's signature object and currently the thing
furthest from it. It should be moulded: a bright top rim, soft interior
shading, a wide faint shadow under it. Not a refraction effect — volume.

**The blocks.** They already have a rim (`BlockChrome`). The board suggests
pushing the top-edge highlight and keeping the shadow wide and faint, which is
the direction the shadows were just taken anyway.

**The tab bar.** Already a floating pill. Correct.

**Where the light goes.** If the day's colour is to appear at all, it belongs in
one contained object — a soft orb behind the tower's foot, or nothing — rather
than tinting the page.

---

## Where this contradicts what is in the app today

Recorded plainly so the next session does not re-litigate it:

- `DayGround`'s full-bleed scene is the wrong shape for this board. It was built
  across several rounds and each round was told it was "too strong"; the reason
  is structural, not a value.
- The lattice going to a white pane is RIGHT, but it needs a grey ground under
  it to be visible without a drawn line.
- `docs/design-system-future.md` §6 allows shadow only for things standing on
  something. The board's soft-3D objects all carry one. That rule and this board
  disagree, and the owner owns both — worth asking before shadows spread.


---

# Part two: four videos, 2026-10-01

The owner: "use as many tips from the videos I want the best UI possible."

**Read before taking any of it.** Three of the four are built on e-commerce and
subscription flows — a product page, a paywall, a ride-hailing fare, a hotel
booking. Strata sells nothing, asks for nothing and has no funnel, so about half
of what is in them is advice about converting a stranger into a payer and does
not describe anything this app does. Taking it anyway is how an app ends up with
a trust badge on a page nobody doubts. What IS in them, and what the owner is
pointing at, is a way of reasoning that transfers completely: **every element is
a question the person has to answer, and the design's job is to make the answer
cheap.**

---

## 5. The frame worth keeping: an element is a question

From the paywall video, and it is the most useful sentence in the four: judge an
element by the question it puts to the person, not by what it displays.

Applied to this app, the questions its screens actually ask:

| Screen | The question it puts | Where the answer is |
|---|---|---|
| Wins, empty | "what do I do here?" | the slot, which is pressable and is the only object on the page |
| Wins, built | "what did I do?" | the tower, and nothing else is allowed to be louder |
| The slot | "how big was it?" | three sizes, and the block that appears is the answer drawn |
| Add a win | "what was it, and what kind?" | one field, six category discs, three sizes |
| Memories, a month | "how did the month go?" | colour where things happened |
| The replay | "was it a good week?" | the count rolling up and the tower building |

**The test this gives us, and it is a real one:** if a screen's elements answer a
question nobody asked, they go. That is the same instrument as
`docs/copy-audit.md`'s Explanation class, arrived at from the other side, and it
is why "COLOUR" and "SIZE" came off the add sheet: the row performs the question
and the label answers one nobody put.

## 6. What transfers, with the place it lands

**6.1 Icon contrast over an image you do not control.** (Product page video,
0:39.) Its fix is a container or an outline behind every glyph that can land on a
photograph. **This app already has the equivalent and it is better**: `Legibility`
puts a measured shadow under a glyph only where the thing underneath can be any
colour, and `BlockContentOverlay` carries the frosted band a title sits in. The
camera's review sticker and the map's badges go through the same. **Worth
re-checking rather than re-building**: `docs/consistency-audit.md` found four
different icon sizings, so the thing to verify is that every glyph drawn over a
photograph goes through `Legibility` and not that a new container is needed.

**6.2 One definitive number beats a range.** (Ride-hailing, 6:55.) A range makes
somebody negotiate with themselves. This app has one place that does it and it is
not a price: **the replay's date range, "9/28-10/4".** The owner settled the form
on 2026-09-15 and that is not reopened here. What the video does sharpen is why
his instinct was right: a range is read as two facts, and he asked for a glance.

**6.3 Total cost up front, no surprise at the end.** (Booking, 10:35.) The
app's only analogue is the **store-unavailable and restore flows**, where
something could go wrong and the person cannot see why. Both already say the
whole fact before the button: Restore says "Restoring only adds" before you press
it, and the store screen says "Nothing has been deleted" first. **This is already
done and it is worth naming so nobody adds a third statement of it** — the copy
audit cut exactly that, a third restatement inside the sheet.

**6.4 Sensory language in a header, not functional language.** (Booking, "steps
from the sand".) This one transfers and is **not** done. Strata's headers are
nouns: "Memories", "Plan", "Profile", "Settings". The one place the app already
writes the other way is the replay, which says nothing about itself at all, and
`CLAUDE.md` records the owner rejecting "Your week" for exactly that reason. So
the lesson here is bounded: **the app's voice is understatement, and a sensory
header would be the app talking about itself.** Recorded as read and declined,
with the reason, so it is not proposed again.

**6.5 Animations are feedback, not decoration.** (Premium-apps video, 0:22.) Its
distinction between no feedback and refined feedback is the same finding as
`docs/motion-audit.md` §5.1, which measured it rather than described it: **the
app had four different answers to a press and thirty-one buttons with none.**
That is now one `PressResponse` with three rungs. The video's other half — custom
gradients and motion on the feedback itself — is where `EtherealFill` and
`BlockLight` already are. **Done, and the audit is the evidence.**

**6.6 Illustrations: iterate or commission, never accept the first generation.**
(Premium-apps video, 3:02.) This is the owner's own plan already written down in
`docs/illustrations.md`: he draws them, they are one contour filled flat, and the
field they sit in is built before they arrive. The video's hybrid workflow — one
hand-drawn original as the seed for variants — is **worth adding to that doc** as
the production route once the first six exist, and it is the only genuinely new
thing in this section.

**6.7 Invisible craft.** (Premium-apps video, 9:51.) Its example is building a
custom camera rather than taking the system one. **This app already made that
call and paid for it**: `CameraView` is a custom capture surface with its own
shutter, its own zoom pill and its own film looks, and `ShutterBlock` exists
because two screens had drifted copies of the shutter. Named here because it is
the single most expensive decision in the app and it should not be relitigated by
somebody reading a video.

**6.8 Bottom bar, three to four items.** (Mobile-UI video, 0:20.) Strata has
three. **Done**, and the labels came off on 2026-10-01 at the owner's call.

**6.9 One screen, one job; content flows one direction per section.**
(Mobile-UI, 1:32.) This is check 1 of `docs/screen-audit.md` almost word for
word. The one screen that has ever failed the second half is **Memories**, which
was four stacked horizontal shelves under a vertical calendar; the 2026-10-01
redesign cut it to one. **Hold the line**: a second horizontal strip on that page
is the specific regression to refuse.

**6.10 Cards group content without needing whitespace; do not over-nest.**
(Mobile-UI, 2:13.) This one **argues against something this app chose**, and the
disagreement is worth stating. `docs/space.md` P2 reads Palmer (1992): a box and
space are alternatives, and choosing a box means the space has lost. This app
chooses space nearly everywhere and uses a card in exactly two places, both of
them the platform's grouped `Form` (Settings and Profile). The video is right
that cards are cheaper; this app is not short of room. **No change, reason
recorded.**

**6.11 Bottom sheets keep context.** (Mobile-UI, 3:30.) Every modal in this app
is already a sheet rather than a push — add, plan, the plan line, profile,
settings, restore, the head maker. **Done.**

**6.12 Dynamism: an action appears when it is needed and leaves when it is
not.** (Mobile-UI, 6:02.) The app does this in one place and it is the best
example of the pattern in it: **the replay offer exists only while its window is
open and leaves on its own, with no dismiss.** The thing to check is the
opposite failure — a control that is always there and is almost never used. The
plan button in the Wins corner is now the only chrome on that screen, which is
the test it has to keep passing.

**6.13 Always design the empty state.** (Mobile-UI, 6:02.) This is **check 12**,
added the same day from the owner's own words, and it is where most of the
evening went.

**6.14 Input method follows how often and how precisely.** (Advanced-tips video,
8:12.) Sliders for occasional and imprecise, fields for frequent and exact. The
app has one real instance: **block size**, which is a three-way segmented control
rather than a slider, and that is the right side of this rule — it is chosen on
every win and the three values are named rather than continuous.

**6.15 Smarter search.** (Advanced-tips, 2:14.) **Does not apply: this app has no
search**, and it had one and removed it. `MemoriesView`'s own header records that
the page "opened on a search field" and that it went. Nothing here argues for
bringing it back; a search field is for a corpus somebody else wrote, and this
corpus is forty blocks the person made this month.

**6.16 Personalise by journey stage: new, repeat, super user.**
(Advanced-tips, 0:26.) This is the one item in the four videos that is **both
applicable and entirely unbuilt**, and it is worth a line because it is where the
empty-state work this evening naturally leads. The app already varies by what is
on the page — `wellInk(filled:)` is literally the structure adapting to how much
content there is — but nothing varies by how long somebody has been here. The
honest shape it would take in this app is not a different screen, it is **the
first week being allowed to look different from the fiftieth**, which is a
product decision and not a layout one. Logged, not designed.

## 7. What does not transfer, and why it is written down

- **Trust signals, ratings, reviews, badges.** There is no stranger to convert
  and nothing to be sceptical about. A "cheaper" badge or a review count on any
  screen in this app would be chrome answering a question nobody asked.
- **Price transparency in the button, totals, cancellation policy.** The app
  takes no money on any screen. The monetisation docs exist and when a paywall is
  built, **the paywall video is the reference to read then, not now**, and its
  real finding is the one to bring: the screen that works asks "do you want to
  try this?" rather than "is this worth nineteen dollars", and the mechanism is a
  clear trial timeline and the word "Start" rather than "Subscribe".
- **Predefined quantities, order tracking, category screens.** No quantities, no
  orders, no categories to browse. Strata has categories but you do not shop
  them.
- **Swipe-up-to-search and swipe gestures as primary navigation.**
  (Mobile-UI, 5:11.) The app is three tabs and a slot. `CLAUDE.md` records a
  gesture manual being deleted from the empty state because it explained a rule
  that no longer existed; adding gestures to get it back would be that in
  reverse.


---

## 8. Apple's own guidelines, 2026-10-01

A fifth reference, and the only one of the five written by the people who make
the platform. `docs/apple-design.md` is the craft reference this project already
reads; what follows is what a pass specifically against the HIG's own sections
turns up, checked against the code rather than taken on faith.

**Three of its four highlighted sections do not apply.** macOS: this app is
iPhone only. Place cards on maps: the HIG's interactive card is for a map whose
pins are places somebody else published, and this map's pins are the person's own
photographs, which open a collection rather than a card about a venue. Both are
noted so nobody proposes them from the video.

### 8.1 Accessibility: done, and the evidence is tests rather than intent

- **Dynamic Type.** Every token in `Typography` is a text STYLE, never a point
  size, and `TypographyTests` fails if one becomes a size. `ReplayFrame` caps its
  own content past xxLarge because the frame's lines are fractions of the frame
  and cannot grow with the type.
- **Colour contrast.** Check 9 of `docs/screen-audit.md` is this, measured per
  element against the ground it actually sits on. It found the head maker's Save
  button at **1.04:1** the same day this was written.
- **Haptics alongside audio.** `HapticsEngine` has ten named events and
  `SoundEngine` has its own voices, and a win logged plays both. **Worth keeping
  in step**: the HIG's point is that a person who has sound off must still get
  the answer, which is why `PressResponse` was given a Reduce Motion path that
  keeps the dim rather than gating to nothing.
- **Reduce Motion.** Nineteen files honour it; twelve did not until
  `docs/motion-audit.md` counted them, including `FlippableBlockView`, which is
  what the tower renders.

### 8.2 Widgets: the gap this pass actually found

`StrataWidget` ships `.systemSmall` and `.accessoryRectangular`. Medium was built
and rejected by the owner with a reason worth keeping ("a tower is a tall object,
and a wide box either leaves half of itself empty or spreads the blocks out until
they stop reading as a stack"). Lock Screen is therefore covered by the
rectangular family.

**What is missing, in the order it is worth anything:**

1. **The widget is not interactive at all.** No `Button(intent:)`, no
   `widgetURL`, no `Link`. Since iOS 17 a widget can run an App Intent in place,
   and **this app already has the intent**: `LogWinIntent`, with
   `openAppWhenRun = false`, going through `QuickWinService.logWin`, which is the
   same path the tap in the app takes. So the app whose whole premise is that
   logging a win should be the fastest thing you do has a Home Screen widget that
   cannot log one. **The cost is not the button**: an intent run from the widget
   process needs its `@Dependency ModelContainer` registered in the extension,
   and `AppDependencyManager.add` currently happens in `StrataApp.init`, which is
   the app target. That is the real work and it is why this is a question for the
   owner rather than a change made on the way past.
2. **No `widgetURL`.** A tap opens the app wherever it opens, rather than on
   today. The deep-link plumbing exists (`deepLinkHabitID`, and the Spotlight
   handler that uses it).
3. **StandBy is unconsidered.** `TowerPhotoBackground` puts a photograph behind
   the tower, and StandBy at night renders a widget monochrome red at low
   brightness. Nobody has looked at this app in that mode. It is one capture to
   find out.
4. `accessoryCircular` and `accessoryInline` are **not** recommended here: a
   tower does not fit a circle and does not fit a line. The count would, and the
   count is deliberately not the subject of this app's own home screen, so adding
   it to the Lock Screen would say something the app does not say about itself.


---

## 9. HEYTEA's own site, measured, 2026-10-01

The owner has named HEYTEA as the target four times and `docs/illustrations.md`
was written from his description of it. This is the first time anybody opened it.
Read at heytea.com on a 560pt-wide frame, with the type pulled out of
`getComputedStyle` rather than guessed from a screenshot.

### 9.1 What it actually is

| | measured |
|---|---|
| ground | **rgb(255, 255, 255)**, pure white |
| faces | **two, both custom**: `HeyteaSans` (with a Light cut) and `JaaamForHeytea`, a hand-drawn face declared `cursive` |
| weight | **400 everywhere.** The sans has a Light; there is no bold anywhere on the page |
| ink | **three steps: rgb(0), rgb(68), rgb(118)** |
| tracking | **+0.10 em**, on everything, headings and body alike |
| leading | **exactly 1.5** |
| case | **lowercase throughout.** "who are we?", "we want...", "new style tea by inspiration" |
| chrome | a mark top left, two glyphs top right, one hairline. No fills, no shadows, no capsules. The 404's only button is a **plain rectangular outline** |

### 9.2 The correction, and it matters because he is about to draw six of these

**`docs/illustrations.md` rule 1 is wrong about the illustrations.** It says "One
contour, filled flat. Not an outline with a fill inside it. The shape is the
drawing." That describes their LOGO, which is a filled silhouette of a person
holding a cup. **Their illustration system is the opposite**: open line art, a
single near-uniform marker stroke, nothing filled, no mass at all. The tree on
the home page and the two figures with a megaphone on the next screen are
outlines with white inside them.

The rule as written would have produced six black blobs, which is the logo
repeated six times rather than the drawings this page is made of. Rule 1 is
corrected in that file with this measurement attached. **Rules 2 to 6 all hold**,
and rule 5 is confirmed hard: the figure takes about a third of the viewport and
has more empty page under it than it occupies.

### 9.3 The one place it argues with a decision made tonight

**HEYTEA's whole page is one weight.** What separates a heading from a line of
body there is the FACE (drawn against typeset) and the SIZE, never the stroke.
Tonight this app went the other way, to Semibold headings over Medium prose, on
the owner's own words: "the text reads as premium not dull a nice thicker font
for headers."

Both are defensible and his instruction governs, so nothing is changed on the
strength of this. **What it does suggest is where the app could buy the same
effect more cheaply later**: it already has a drawn face (`StrataFont`) and it
already uses it for exactly two things, the tally and the Memories title. HEYTEA
differentiates with a second FACE and tracking; this app currently differentiates
with weight and has a second face sitting mostly unused. That is the trade to put
to him when the custom typeface he mentioned arrives, and not before.

### 9.4 Two numbers worth taking now

- **Tracking +0.10 em.** This app's only tracked thing is `Typography.sectionKerning`,
  0.8pt on a 15pt label, which is **0.053 em** — half. Their tracking is on
  everything, not just labels, and it is a large part of why that page reads as
  airy at a weight no heavier than this app's body. Worth trying on the screen
  titles and measuring; worth NOT applying blind, because SF Pro at a title size
  is already loosely fitted and the two faces are not comparable.
- **Leading exactly 1.5.** `docs/apple-design.md`'s advice on size-specific
  leading is the thing to check this against, and `docs/research/` has the
  typography audit that found this app's leading "misses at both ends".

### 9.5 What does not transfer

Their lowercase. "memories", "plan", "settings" in lowercase would be a brand
decision of his, not a layout one, and the app's drawn wordmark came off in
September for reasons recorded in `CLAUDE.md`. Noted and left alone.


---

## 10. Dribbble and Mobbin on the free tier, 2026-10-01

**Mobbin is not readable this way.** The MCP needs a paid plan, and `mobbin.com`
returns **403 Forbidden** to an automated browser. Its thumbnails are visible to a
person signed in on the free tier, so the owner can browse it himself; nothing
here can.

**Dribbble is readable, and the finding is a warning rather than a source.**

Searched "minimal ios app", read the top results as images. Every one of them,
from several designers, is the same system:

- white cards on a near-white ground, radius about 20, hairline separators
- a greeting and a date at the top ("Thu 14 August / Hey Diana")
- a chart as the hero, with a legend
- rows of title plus a grey subtitle plus a right-aligned value
- uppercase grey section labels
- a saturated accent on the primary action, usually pink
- a "See all" link beside every heading

**That is tidy, and it is not minimal in the sense this app means it.** It is the
card-stack pattern, and searching Dribbble for "minimal" returns it because that
is what the word has come to mean there. Against HEYTEA's language in §9 — pure
white, one figure, enormous negative space, no fills at all — it is a different
thing entirely.

**It would pull this app backwards, specifically.** Every one of the following
has already been removed from Strata, on the owner's own instruction, and all of
them are on the first Dribbble page:

| On Dribbble's "minimal" | Removed from this app, when, why |
|---|---|
| a greeting at the top | the Wins header's greeting, "it changed four times a day and was never the reason anyone opened the app" |
| a title with a grey subtitle under it | 2026-10-01, "no tiny text under or anythign like that" |
| a saturated accent pill | 2026-10-01, "lets just do the basic", `accentPrimary` deleted |
| a chart as the hero | Profile's mood headline over its own numbers, cut 2026-10-01 |
| cards everywhere | `docs/space.md` P2, Palmer (1992): a box and space are alternatives |

**So the useful instruction is about the search term, not the site.** "Minimal"
returns dense-but-tidy. The words that return this app's actual target are
editorial, whitespace, Swiss, Muji, and the names of the brands rather than the
adjective. And the deeper limit stands however it is searched: **Dribbble is
concept work.** Nothing on it has shipped, been tested at an accessibility size,
or had to survive a photograph somebody took in the dark. That is exactly what
Mobbin is for, and it is the one that costs money.

## 11. Pinterest, 2026-10-02

Pinterest works without paying and shows the full image, which Dribbble and
Mobbin did not. Four searches: "minimal app ui white space", "heytea app ui",
"ui design do and dont mobile spacing", "line art illustration app empty
state minimal". Read at 736px, side by side. What follows is what the good
ones share and the weak ones lack, and where it lands in Sturdy. Pinterest is
a mood board, not a source of measured fact: everything here is (c),
inference from looking, unless it says otherwise.

### What the strong screens share

1. **One bold thing per screen, and everything else steps back.** "grug." (a
   journaling concept) is a white page with one hand-drawn arrow and note in
   the top two thirds and the day's thought anchored low, over the bar. Oppie
   is one huge greeting and one card. A Japanese study app is one red disc on
   grey. The dashboard concept is one 22% and one dotted ring. None of them
   has a second voice at the same volume. **For Sturdy:** the tower, the
   month and the replay already obey this; the screens that do not are the
   ones with a segmented control over nothing (Profile empty, `profile.md`
   #3).
2. **The air is placed, not left over.** In grug the empty top is where the
   drawing lives and the text is pulled down to the thumb. That is the
   difference between this and the onboarding title that sat 158pt down for
   an illustration that was not there (fixed 2026-10-01): **content can sit
   low when it is next to the action it belongs to; a title cannot float low
   with nothing above it.** Same rule as the "thumb zone" do/don't pin
   (header, sub-header and button moved together to the bottom, not split).
3. **A month of objects (the drink calendar).** A HEYTEA-style drink log
   draws the month as soft wells, each empty day carrying a readable numeral
   (about body size, not caption size), and a day with a drink shows the
   drink as a cut-out sitting in the well, numeral gone. The objects
   slightly overflow their wells, which makes the grid feel alive rather than
   tabular. **For Sturdy:** this is the strongest outside argument on owner
   decision 3 (`docs/morning.md`): a numeral in an empty well can be big
   because nothing else is there, and it leaves when the day is filled. The
   7.9pt numeral is the tabular version of the same idea. Rendered at 15 in
   `docs/design-review/memories-numeral-15.png`.
4. **Line art on white, one accent dab.** The illustrated cards (an
   "Awareness / Chill Living" home), the "Coffee to Go" walker and the empty
   state set all use a single black line weight on white, with at most one
   flat accent shape per drawing. The drawing takes the top 55 to 60% of its
   card, one Bold title under it. This is the HEYTEA register and matches
   `docs/illustrations.md` rule 1 (open line art, not filled).
5. **Empty states that are scenes, not placeholders.** The good ones (a
   flower that has grown out of a ground line with "Get started!", a figure
   by a campfire for "File is uploading", a hand with a magnifier) are one
   figure at roughly 35 to 45% of the width, standing on an implied ground,
   over ONE Bold line, one quiet line, one action. The weak one, a grey
   filing cabinet over "No data yet", is small, generic and grey and reads
   as a missing image. **For Sturdy:** the empty tower already stands on a
   ground (the lattice); when the drawings land, a figure belongs ON that
   ground beside the slot, not floating above the copy.
6. **A head picker is a portrait and a grid** (a "Humation" avatar builder):
   the chosen head large at the top on its own ground, the options in a
   3-up grid of equal wells under tabs. That is the shape Sturdy's head
   picker grows into with several heads (`head-picker.md` #2, the lone 46pt
   tile in a 340pt row).

### What the do/don't pins say, filtered to what is true

- **Distance is relationship.** The "spacing friendship" ladder (8 best
  friends, 16 friends, 24 casual, 32 to 48 acquaintances, 80 to 120
  strangers) is the same idea as Sturdy's 8/12/16/24/32/64 and the law of
  proximity pin's line, "Space is not empty. It tells users what belongs
  together." Nothing new; it confirms the ladder.
- **Dividers are not always needed.** A list separated by rhythm reads
  calmer than one separated by rules. Sturdy already removed most; the Plan
  separator under 471pt of nothing was the last loud one (deleted).
- **Overlapping saves space** (an avatar half over a cover photo) is a
  gimmick in this app's register: it puts chrome ON a photograph, which the
  owner's 2026-09-09 call forbids. Recorded as rejected.

### What makes the weak ones weak

Tiny grey labels under every number (the dashboard concept's "Current week /
Days remaining" at caption size is exactly what the owner calls "tiny text
under"), three or more type sizes in one card, cards inside cards, a blue
accent on everything so nothing is accented, and illustrations used as
decoration in a corner rather than as the subject of the screen.
