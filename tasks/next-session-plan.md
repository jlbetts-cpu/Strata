# Next up

Written 2026-09-11 while another agent held the working tree, so none of this
is started. Ordered: the first two are live bugs a tester would hit, the rest
is work we chose.

Every item carries the evidence it came from, because the reasoning is the part
that goes stale first.

---

## 1. A photo block has no colour behind it — BLOCKING

**Symptom.** Blocks with photographs render as a white-to-grey gradient with
their title on it. Seen on device on the tower, the day view and the month
tower. Photographed 2026-09-11.

**Cause, confirmed by reading `FlippableBlockView.chromedBody`:**

```swift
ZStack {
    if hasImage {
        CachedImageView(… showsPlaceholder: false)   // the only fill
        RadialGradient(…)
        if named { veil }
    } else {
        …
        style.baseColor                               // colour ONLY here
    }
}
```

The category colour is in the `else` branch. When `showsPlaceholder: false` was
added (commit "A block waiting for its photograph is just a block") the comment
claimed "the block's own colour is what shows while this decodes". That is
false for this view — nothing shows. `BlockSurface` renders an empty fill,
which is the grey gradient.

**Fix.** Draw `style.baseColor` under the photograph in BOTH branches, not
beside it. A block is then a coloured block that becomes a photograph, and
never looks like it is loading.

This also delivers a second thing the owner asked for in the same breath: every
block always has a colour, so a tower of un-photographed wins still reads as a
tower. No new colour source is needed — an uncategorised win already gets a
random one through `spontaneousCategoryRaw`.

**Check the same pattern elsewhere.** The map has `waitingFill` and the month
tower has its day colour, so both already have a fill. `FlippableBlockView` is
the only one missing it — but confirm rather than assume.

**Verification.** Seed with photographs, launch, screenshot during the first
second. No white gradient at any point.

---

## 2. Confirm the loading stall is actually gone

**Symptom.** "The photo loading is super slow and never loads in at times."

**Cause.** A `DispatchSemaphore` bounding decodes on a concurrent
`DispatchQueue`. A semaphore blocks the worker that takes it, and GCD answers a
blocked worker by spawning another; with a gallery, a map of 28 blocks and a
month of 30 asking at once, enough workers sat blocked that new work never
started. Fixed in build 26 by removing the semaphore — measured 116ms for 80
cold thumbnails, 7.25x the serial path, nothing blocking.

**What says it is fixed.** The screenshots that prompted this show NO
broken-photo glyph. `CachedImageView` draws one whenever a load returns nil, so
the loads were not failing — they were never finishing. If photographs appear
on build 26+, the diagnosis holds.

**If they still hang on 26**, the diagnosis is wrong. Instrument
`loadThumbnail` with timing rather than guessing again.

---

## 3. Prove the orphan sweep did not delete real photographs

**Why.** `pruneOrphans(referenced:)` deletes every file not in the set it is
handed. `pruneOrphanedImages` guards a THROWN fetch, but a store that came up
on the silent in-memory fallback would return zero logs without throwing, and
an empty set means "nothing is referenced".

**Evidence it is fine:** the gallery renders real photographs on device, so
files exist. That is reassuring, not proof.

**Do.** Count files in `strata-images` against the number of logs holding an
`imageFileName`. If files are FEWER than referenced names, something deleted
them. Consider hardening the guard: refuse to sweep when the referenced set is
empty but the directory is not.

---

## 4. Remove drag-to-rearrange

**Owner's call**, and the machinery is smaller than it feels:

```
TowerOrdering.swift          70 lines
TowerOrderingTests.swift    103 lines
draggable / dropDestination   4 call sites
commitRearrange / reflow      7
liftedBlockID                 7
```

**Why it is the right removal.** The tower is pinned to TODAY, so rearranging
arranges three blocks that vanish at midnight. For that we carry: a cancel
debounce standing in for an iOS 18 API that does not exist, suppression of
merged runs, block culling and milestone detection during a drag, and a fourth
instance of the `Equatable` trap (`liftedBlockID` had to be added to
`AnimatedBlockView.==` or the lift never rendered).

**What it buys back.** CLAUDE.md records that ANY gesture recogniser on a block
starves the tower's ScrollView — measured at 0.0pt of scroll for
`highPriorityGesture`, `simultaneousGesture`, a sequenced long press and a bare
`onLongPressGesture`. `.draggable` was the only thing that scrolled normally,
which is why rearranging is built the way it is. Removing it reopens the
gesture space on a block.

**Keep `towerOrder`.** `TowerViewModel` sorts by it and a stored `Int?` costs
nothing. Removing the interaction does not require removing the field, and
pulling a property out of a SwiftData model is a migration risk for no gain.

**One commit**, so it reverts in one piece.

---

## 5. Perceived speed: measure, then delete

**Owner:** the app should feel faster and more stimulating.

**Suspect, found by reading.** `MainAppView.swift:2104` draws a skeleton tower
of 8 fake blocks whenever `towerVM.isLoading` is true, and `isLoading` starts
true and is cleared only at the end of `buildTower`. If the real tower builds
in tens of milliseconds, that skeleton appears and vanishes inside three
frames. **A skeleton that flickers makes an app feel slower**, because it
announces loading and then contradicts itself — and the owner has already
called it out twice ("too much going on, not premium").

**Do, in order.**

1. Measure. Launch to tower drawn, tab switch, photo viewer open. Same shape as
   `-strataBenchImages`. "Feels slow" becomes a number.
2. If the tower builds fast, delete the skeleton outright. If it is genuinely
   slow sometimes, gate it behind ~200ms so only slow loads ever show it.
3. Fix whatever the measurement says is actually worst, not what is most
   visible.

---

## 6. One mechanic: a landing block moves its neighbours

Every tenth win gets the dance (`GridConstants.danceEvery`). The other nine
land in a still world: gravity, impact, haptic, and nothing else on screen
reacts.

A short settle in the blocks a new one touches gives every win a consequence.
This is consequence rather than decoration, which matters given the owner has
spent this project removing water, aurora, block-magic and 3D parallax. It says
the blocks are objects with weight, which is the app's whole claim.

Use a `GridConstants` spring token. Read the driving value in the grid's own
body — CLAUDE.md records that an `Equatable` view silently stops updating from
`@Observable` state, and this has broken three separate features.

---

## 7. The camera's reticle overstays

**Owner:** "after a while of clicking the exposure should go away it kinda just
sits there."

**It already self-dismisses — the window is just too generous.** `reticle`
carries `.task(id: focusShownAt)` which sleeps 4 seconds and clears
`focusPoint`. Two things keep it up longer than that:

- `focusShownAt = Date()` is set inside the exposure drag's `.onChanged`, so
  every drag event cancels and restarts the task. That is correct while you
  are adjusting — nobody wants the sun vanishing mid-drag — but it means the
  clock only starts on the LAST event.
- After a plain tap with no adjustment, the full 4 seconds still runs. Tap a
  few times in a row and it never settles.

**Why 4s was chosen** (comment at the reticle): long enough to drag the
exposure after tapping. That is the real constraint — shorten it naively and
there is no time left to start adjusting.

**Proposed shape**, which satisfies both:

- A tap that is never followed by a drag: about 2s. Enough to see where focus
  landed and to begin adjusting, not enough to sit.
- Once a drag begins: keep restarting as now, then a SHORTER tail after
  `.onEnded` — around 1.5s — because by then the person has finished and is
  looking at the picture, not the control.

That needs the tail to be driven by the drag ending rather than by the last
`.onChanged`, so `.onEnded` should set `focusShownAt` one final time and the
sleep should read a duration that depends on whether a drag happened.

**Unverifiable on the simulator.** There is no capture device, so the reticle
cannot be exercised the way a person exercises it. Judge on a phone, and expect
the numbers above to need one adjustment by eye.

---

## 8. Zoomed out, the map should answer "where", not "what"

**Owner, 2026-09-11:** "the location of where you are needs to be more
prominent than the photos, the photos shouldnt be so huge when you scroll out.
like you should know where you are before you know what pictures you took in
areas right?"

**This reverses a decision already in the code, deliberately.** `mapStyle` for
`.quiet` carries: "Far out it is nearly-blank geometry with no labels at all,
so the blocks are the only thing on the screen with anything to say." That was
the owner's earlier call after seeing both grounds side by side. It is being
changed on purpose — do not "fix" it back to the comment.

**Why it reads wrong now, and it is arithmetic rather than taste.** A cluster's
size comes from `MonthTower.size(forWinCount:)`: 1-2 small, 3-6 medium, 7+ a
2x2. Zooming OUT merges clusters, which raises each one's count, which makes
the block BIGGER. So the further you pull back — exactly when you most need to
read the map — the more of it the photographs cover.

**The shape to build.** Size should depend on zoom as well as count, and the
map's own information should arrive in the opposite order to now:

- **Far out** — geography legible. Every cluster is a small marker carrying its
  count, not a photograph at full size. The question here is "which town", and
  a photograph cannot answer it.
- **Mid** — blocks appear, still modest.
- **Close** — the current behaviour: full size by win count, labels up, scrim
  down. Here the question has become "which corner", and the photograph IS the
  answer.

**Things to get right.**

- Cap the drawn size by zoom, rather than changing `MonthTower.size`. That
  function is shared with the month tower, where the rank by count is correct
  and must not move.
- `targetBlockPitch` (116) is the distance between neighbouring cells and must
  stay larger than the biggest block drawn, or blocks overlap — see
  `Cluster.anchor`. Smaller blocks far out means more headroom, not less.
- The scrim currently sits at 0.10 far out and 0.03 close, on the reasoning
  that far out there is no type to wash. If names now matter far out, that
  inverts too: a wash over type is what makes a map look cheap.
- A small marker on a busy map needs its own contrast rather than a scrim's
  help — a ring and a shadow, the way a pin carries itself.

**Verification.** `-strataMapSweep` walks a zoom ladder; film it and check at
each step that the place names are readable and the blocks are not the largest
thing on screen until you are close.

---

## 9. Parked: 17 of 29 milestones cannot fire

Not for now — badges are a later system, and pacing the app around rewards that
do not exist yet is backwards. Recorded because it is a real defect and will
matter the moment badges are built.

`MilestoneDetector.detectNewMilestones` is passed:

```swift
totalBlocks: towerVM.placedBlocks.count,      // TODAY's blocks
towerHeightMeters: towerVM.altimeterHeight,   // TODAY's height
```

The tower is today-only, so both are daily numbers. At `metersPerBlock = 3.0`,
"Eiffel Tower" (330m) needs 110 rows in one day and "1000 blocks" needs 1000
wins between midnight and midnight. **9 towerHeight + 8 blockCount = 17 of 29**
are unreachable. The 6 streak and 6 perfect-day milestones use lifetime values
and work.

This is the same fault, in the same function call, as the one CLAUDE.md already
documents under "A feature that cannot fire is worse than one you never built"
— that section was written about `longestStreak: 0` on the line below.

Also unsurfaced: `altimeterHeight` is computed, fed to milestones and spoken to
VoiceOver, but appears in no visible text. A screen reader user knows how tall
their tower is; a sighted one does not.

---

## 10. Small and true

- **Stale comment.** `ImageManager.loadThumbnail` still describes decoding on
  "Swift's cooperative pool". It was measured (545ms vs 116ms at n=80) and
  rejected; the code uses the concurrent queue. The comment outlived the
  decision.
- **Widget photo names are doubled**: `…_seed.jpg.jpg`, because the export
  appends `.jpg` to a name that already has an extension. Harmless — both sides
  use the same string — but wrong.

---

## Outside the code

- **Automatic distribution** on the external "Friends" group is off and cannot
  be set through the API (`409 — hasAccessToAllBuilds can not be included in an
  UPDATE operation`). One toggle in TestFlight, and new builds reach testers
  without anyone assigning them.
- **When Beta App Review clears**, assign the newest build. Build 10 is what is
  submitted and it now predates most of this work. `tools/add_testers.py` picks
  the newest eligible build on its own.
