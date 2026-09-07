# Strata — case study material

Raw material for writing the case study. Facts, numbers and decisions with
their reasons. Nothing here is finished prose.

## The one-line idea

You complete something; it becomes a block; the blocks stack into a tower.
The tower is not a chart of your habits — it is the thing your habits built.

## The pivot that defines it

Strata began as a habit planner with a tower attached. It is becoming a record
of what you did, with planning attached. The evidence for the pivot came from
the owner's own use: he tracked habits in a plain spreadsheet rather than in
the app, because the app asked him to plan before it let him record.

The design consequence: **the tower is the home screen, and logging a win is
one tap on an empty slot at the top of it.** The action happens in the place
where its result appears. A dedicated "log a win" page was deleted — its entire
job was to hold one button.

## Design principles that actually got applied

1. **The blocks are the identity; chrome is not.** No card, sheet or form well
   gets a white rim, a frosted band or a blurred edge. Those say "you built
   this and it is standing on something", which is a block's claim to make.
2. **Colour and category are two different facts.** A win logged in one tap has
   no category — that is the point of one tap — but a colourless block does not
   belong on a page made of colour. So the block wears a colour picked as the
   least-used one, and shows no icon, because an icon would claim a category
   nobody chose.
3. **A block with no name shows no text at all.** Not the word "Win".
4. **The tower is one structure.** Anything that moves part of it independently
   of the rest is a bug, however pretty.
5. **Measure before you diagnose.** See below — this is the one that mattered
   most.

## The block, and why it is layered rather than styled

From the Figma source: a block with a solid white border on all four sides, and
a separate rect over the bottom 26% applying a 10px backdrop blur to it. The
blur eats the border, so the bottom edge is that same border out of focus — not
a strip, not a gradient.

Four wrong turns on the way there, each of which looks right in isolation:

- Compositing a blurred ring **on top of** a sharp block adds a white highlight
  inside the colour field and leaves the silhouette crisp. The source has
  neither. The sharp surface has to be replaced, not decorated.
- Crossfading the two copies **symmetrically** makes the block translucent
  through the handover: two masked opaque layers at 50% composite to 75% alpha,
  so the page shows through as a milky cast. The blurred copy must reach full
  opacity before the sharp one starts to fade.
- `.drawingGroup()` rasterises to the view's bounds, which re-clips the soft
  edge and puts the hard silhouette back.
- Scaling the blur off the rim width hazes the bottom half. They are two
  separate elements in the source: a 5px border and a 10px blur.

## The measurement method (the strongest section for a case study)

The tower's drop animation was reported broken **five times**. It was declared
fixed four times. Every one of those fixes was reasoning about the animation
code. All four were wrong or partial.

What finally worked was refusing to reason:

- `xcrun simctl io recordVideo` + an AVFoundation frame reader at 30–60fps.
- Per-frame pixel classification in Swift: a block is a run of ≥12 horizontally
  adjacent pixels with saturation > 45 and max channel > 110.
- Detect the airborne block as a saturated band separated from the tower by a
  vertical gap of background.
- **Classify every single drop**, and report the count. Never an aggregate.

The aggregate was the trap. "Total frames containing motion" looked healthy
while 8 of 10 individual drops never animated at all.

### An instrument error worth including

Twice, the measurement itself was wrong and produced a confident false negative:

- A colour detector saturated once the tower grew into its sample band.
- A "does the tower move" probe was reading the **water reflection's** edge,
  which sits just below the tower. It reported the tower dancing as
  "0px of movement across 341 frames". Measuring the tower's top edge instead
  showed a clean 22px lift settling back over 0.4s.

Lesson for the write-up: verify the instrument's resolution and its field of
view before trusting a null result. A null result from an instrument pointed at
the wrong thing is indistinguishable from success.

## Bugs found, and what made them invisible

Each of these produced a symptom the user could describe but not locate.

| Symptom | Cause |
|---|---|
| "Blocks only fall 70% of the time" | The coordinator set the falling phase, slept **8ms**, then started the fall. A frame at 60Hz is **16.7ms** — whether the block was ever *drawn* at its start position was a coin flip. |
| Same, the other half | `state(for:)` lazily created and stored the per-block animation state. The view body called it first and stored instance A; the coordinator then created instance B for the same block. The view observed A, the drop mutated B. 3 of 4 drops had mismatched instances. |
| "Some blocks come from the bottom" | The fall started a fixed distance above the block's **slot**. On a short tower the slot is near the bottom of the screen. |
| "The block flies up then drops" | `withAnimation` commits its transaction when its closure returns, so the block rendered once in its slot before being moved to the start of the fall — and that move, landing in the next transaction, was itself animated. |
| "Merged blocks go out of place" | `MergedShape` read `gridHeight` inside `path(in:)` with no `animatableData`, so it snapped to its final path in one frame while every block around it sprang. |
| "The blocks never dance" | Rotation, lift and glow were read inside an `Equatable` view whose `==` cannot see them — both sides hold the same shared reference. Nothing invalidated it. The drop phases only worked by accident, because the grid happens to read `dropPhase` for `zIndex`. |
| "No way to edit a merged block" | The tap gesture lived inside the chromed branch of the view. Merging takes the *other* branch — a bare rounded rect with no gesture at all. |
| "Resizing moves the tower wonkily" | Resize called the full reload path, which raises `isLoading`. The tower vanished into the loading skeleton, waited a forced 300ms, and came back rebuilt. It was never rearranging. |

**The pattern worth naming in the case study:** SwiftUI's `Equatable` view
optimisation and `@Observable` interact badly. A view whose `==` cannot see the
state it renders will silently stop updating — no crash, no warning, no error.
Three separate features were broken this way. The fix that generalises is to
read the driving value somewhere the framework cannot miss it, rather than
relying on observation reaching a memoised child.

## Motion decisions, with reasons

- **Gravity, not a duration.** The fall is `t = sqrt(2d/g)` at one `g`. It
  replaced per-mass durations (0.44/0.54/0.66s) over an independently varying
  distance, which meant heavier blocks fell faster — which nothing does.
- **No easing out at the end of a fall.** The old curve decelerated into the
  landing as "air resistance". A falling object does not do that. Arriving at
  peak speed is what makes the landing land.
- **Bounce is earned, not decorative.** Critically damped by default; overshoot
  only where momentum caused the motion. The one place it is earned is the
  dance, because something travelled through the stack.
- **Removed: whole-tower impact compression** (a landing scaled the entire
  stack), **the post-cascade "exhale"** (1.02 on 600pt = 12pt of lurch), the
  **first-drop 1.08 zoom**, and **per-row parallax** (rows sheared against each
  other while scrolling, in 8pt steps, because the scroll offset is throttled).

## Numbers for the before/after

| | before | after |
|---|---|---|
| Drops that visibly fall | 2/10 | 10/10, 11/11, 8/8 (three runs) |
| Flights containing upward motion | 3/3 | 0 |
| Fall distance | 120–520pt, scroll-dependent | measured, always from off screen |
| Foundation movement during landings | — | 0px across 690 frames |
| Tower dance | never fired | 22px lift, monotonic settle in 0.4s |

## Constraints worth mentioning

- No accessibility permission for `osascript` on the build machine, so **nothing
  can tap the simulator**. Anything behind a gesture is unverified by
  definition. A launch-argument harness (`DebugHarness`) seeds state and fires
  the drop cascade without a tap.
- SwiftUI Metal shader uniforms **do not update across frames** in the iOS 26.3
  simulator. Proven three ways: a flat-red `colorEffect` applied; a time-driven
  one produced byte-identical pixels every frame; the same clock driving a plain
  `.offset` animated normally. The water was rebuilt in `Canvas` because of it.
- `MainAppView.body` sits at the Swift type-checker's ceiling. Adding one
  modifier fails with "unable to type-check this expression in reasonable time".

## Open threads

- Insights has not been redesigned yet.
- Today and Plan are being replaced by one checklist. See
  `docs/product-direction.md`.
- The water reflection does not participate in the dance — the tower sways and
  its reflection sits still.
