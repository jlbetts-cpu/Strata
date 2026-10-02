# What to draw, and where it goes

Written 2026-09-30, for the owner to draw. The direction is his: "we are
replacing the space-font kind of aesthetic and optimising more for this premium
glass mixed with the Hey Tea vibe."

---

## 1. The style, in drawable terms

HEYTEA's mark is a silhouette of a person holding a cup, and its 2025 rebrand
went further in one direction only: **more abstract, fewer details**. Their own
summary of the change is that finger details were simplified away. That is the
whole instruction.

Six rules, and every one of them is something to NOT do:

1. **One contour, filled flat.** Not an outline with a fill inside it. The shape
   is the drawing.
2. **No interior detail that can be left out.** A face is two marks or none. A
   hand is a mitten. If you can tell what it is at 24pt, it is finished.
3. **Hand-cut, not geometric.** Edges slightly uneven, corners generously round.
   A perfect circle reads as a UI element; a nearly-perfect one reads as drawn.
4. **One colour per illustration.** Ink by default. Colour only where the thing
   drawn IS a win's colour.
5. **Enormous negative space.** The figure sits small in a big empty field. On
   this app's page that field is already there and is clean white — do not draw
   a background, ever. A background is the thing that would kill it.
6. **No gradient, no shadow, no perspective, no outline on the outline.** The
   page supplies all the light. The glass supplies all the depth.

**Why it fits here, and this is the part that makes it not a costume.** This app
is already two materials: saturated photographic colour in the blocks, and
chrome made entirely of light. A flat ink drawing is a third thing that competes
with neither — it cannot be mistaken for a block, because a block has volume,
and it cannot be mistaken for chrome, because chrome never has a contour.

**How to make more of them once the first six exist** (added 2026-10-01, from a
video reference the owner sent; see `docs/reference-board.md` §6.6). One
hand-drawn original is the seed and everything after it is a variant of that
seed, rather than each drawing being generated from nothing. The reason is the
one the video gives and it is the right one for this app: a set generated
independently reads as a set of stock pictures, and a set grown from one hand is
a set. **The first one is drawn by the owner either way** — rule 1 above is about
a contour somebody cut, and no amount of iteration produces that from a prompt.

**Format.** SVG, single path where possible, no strokes (convert strokes to
outlines), viewBox square or 4:3, drawn at any size. Everything below is
`foregroundStyle`-tinted in code, so draw in black on transparent.

---

## 2. Per page

### Wins — the tower

The one page that must stay almost empty. It is the app.

- **The crane.** His own idea, and the best one in the list: a crane that lowers
  a block into the slot. Draw it as **arm, cable, hook** in three pieces so the
  arm can swing, the cable can pay out and the hook can open. Flat ink, drawn
  from the side, no cab and no lattice tower — a jib and a line. It lives in the
  top-right corner above the tower and only appears when a block is landing.
  *Pieces to draw: jib (1), cable (a straight line, I can draw this in code),
  hook open (1), hook closed (1).*
- **The empty tower.** Right now "Nothing yet today" is two lines of type over an
  empty grid. One small figure sitting on the ground row, waiting, with the grid
  empty above it. *1 drawing.*
- **The milestone.** Something for the tenth, twentieth, fiftieth block. A figure
  standing ON the crown of the tower, arms down, calm — not celebrating.
  *1 drawing, maybe 2 poses.*

### Camera

A dark viewfinder. Ink will not read; these are drawn WHITE.

- **Permission refused.** Currently a title, a sentence and a pill. A figure with
  a hand over the lens. *1 drawing.*
- **The shutter countdown.** Nothing — the countdown numerals are his own face
  already and they are good.

### Memories — the map

- **The empty map.** Currently a glass card with two lines. A figure holding a
  pin, or a pin with a figure's shape in the negative space. *1 drawing.*
- **A place with no photograph.** The map shows a coloured block. A tiny figure
  silhouette inside it would say "you were here" without a label. *1 drawing,
  very small — must read at 40pt.*

### Profile

- **The avatar placeholder.** The biggest single win in the app. It is currently
  SF Symbols' `person.fill` in a grey disc, which is the one piece of someone
  else's art in the whole app. His own figure, shoulders-up, flat ink.
  *1 drawing.*
- **No streak yet.** A figure asleep, or a figure at the bottom of a staircase.
  *1 drawing.*
- **The empty chart.** "Keep logging to see your trend." A figure looking up at
  nothing. *1 drawing.*

### Replays — the week and the month

The place with the most room and the most reason.

- **A cover for each window.** Week, Month, Year: three drawings that say the
  LENGTH of the thing rather than illustrating a win. A figure walking (week), a
  figure climbing (month), a figure at the top looking back (year).
  *3 drawings.*
- **The closing frame.** The replay ends on a count. One figure, seated, with the
  finished tower behind them. *1 drawing.*

### Onboarding — six pages

Each page currently shows a device frame or the real tower. Those are the
strongest argument the app has and should stay. What they are missing is a
**mark in the corner of each page** — six small drawings, one per page, that
make the six feel like a set:

1. a block
2. a hand pressing
3. a camera
4. a pin
5. a tower
6. a figure waving

*6 small drawings, each readable at 32pt.*

### The add sheet

- **The empty photo well.** Currently SF Symbols' `camera.fill` inside a dashed
  well. A tiny drawn camera instead. *1 drawing.*

### Head maker

- **The "no face found" state.** A figure holding a frame up to its own face.
  *1 drawing.* Asset name the code expects: `HeadMakerNoFace`. Black on
  transparent, template-rendered and tinted to `onDarkStrong`.
- **"The camera is off for Strata."** The Camera section's own drawing, white:
  a figure with a hand over the lens. **No new drawing.** On a phone this state
  only ever means the switch is off, which is the camera tab's refused state
  reached through a different door, and one situation should not get a
  twenty-fourth drawing. Asset name: `CameraNoAccess`.

### The app icon and the wordmark

He has said the space-font aesthetic is going. The wordmark is his own drawn
face and it is good; what changes is the Strata Neo / technical feel around it.
**This is a separate decision from the illustrations and should not be bundled
into the same pass.**

---

## 3. Totals, in drawing order

Most useful first, so a half-finished set still ships something:

| # | drawing | page |
|---|---|---|
| 1 | avatar, shoulders-up | Profile |
| 2 | crane jib | Wins |
| 3 | crane hook, open | Wins |
| 4 | crane hook, closed | Wins |
| 5 | figure waiting on the ground row | Wins, empty |
| 6 | figure with a pin | Memories, empty |
| 7 | figure looking up | Profile, empty chart |
| 8 | figure asleep | Profile, no streak |
| 9–14 | six onboarding corner marks | Onboarding |
| 15 | figure walking | Replay, week |
| 16 | figure climbing | Replay, month |
| 17 | figure at the top, looking back | Replay, year |
| 18 | figure seated with the tower behind | Replay, close |
| 19 | figure on the crown | Wins, milestone |
| 20 | hand over the lens (white) | Camera, refused · Head maker, no access |
| 21 | camera | Add sheet, photo well |
| 22 | figure holding a frame (white) | Head maker |
| 23 | figure silhouette, tiny | Memories, place pin |

**Twenty-three, and the first eight are the ones that change how the app feels.**

---

## 4. How each one moves

Nothing here loops, and nothing here is a Lottie file. Each is one SVG and a
spring, so it stays in the app's motion ladder and costs a transform:

- **The crane** is the only one with real choreography: the jib swings in on
  `--sp-settle`, the cable pays out while the block falls, the hook opens on the
  landing frame. It must be faster than it wants to be — a crane that takes a
  second to deliver a block turns logging a win into waiting.
- **The empty states** fade and rise 8pt on appear. Once. They never move again,
  because an empty state that animates is an empty state nagging you.
- **The onboarding marks** are the page transition: each slides the width of the
  gutter as the page turns, so the six read as one strip moving past.
- **The replay covers** get the slowest thing in the app — a 1.2s rise, because
  a replay is the one screen you sit and watch.
- **The avatar** does not move at all.

**And the figures never blink.** The app already has a face that blinks and
glances — the companion head — and it earns it by being a photograph of a real
person. A drawn figure that also blinks makes the real one look like a cartoon.
