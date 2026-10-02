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
