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

## 7. Parked: 17 of 29 milestones cannot fire

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

## 8. Small and true

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
