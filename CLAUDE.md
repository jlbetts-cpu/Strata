# Working on Strata

Read this first. It carries decisions and traps that have already cost real
hours, so that a new session does not repeat them.

## What this is

A SwiftUI + SwiftData iOS **win tracker**. You log something you already did;
it becomes a 2.5D block, and the blocks stack into a tower. Three tabs:

**Wins** (the tower — the record, and the home tab) · **Camera** ·
**Memories** (albums, the month tower, and Settings)

Habits, repeating tasks, the Today timeline and the Plan tab are all gone. So
is Insights, which History replaced, and History itself, which Memories
replaced. If you find code or a doc that talks about any of them, it is stale
— though `-strataStartTab` still answers to `history` and `insights`, because
every screenshot script written before the renames says one of those.

The tower header carries the win count and a share button. Logging a win is the
empty slot at the top of the tower: press it, a block drops in; drag it out
first to draw a bigger one. The slot sits at
`TowerViewModel.computeGhostPosition`, so it is always exactly where the block
will land.

## Rule zero: build it

**You are running on the owner's Mac, so you can compile and run this app. Do
it before claiming anything works.**

Some of the design work in `BlockChrome.swift` and the light-only conversion
was written by an agent in a Linux container that could not compile, could not
run a simulator, and could not render SwiftUI. It was reviewed line by line and
pushed unverified — and it did not compile: two switches over `HabitCategory`
were missing a case. If something old looks broken, suspect that first.

"It renders correctly", "it compiles" and "I ran it" are three different claims.
Only make the one you actually earned.

## Traps that have each cost hours

**Verify the local checkout matches the remote before diagnosing anything.** A
whole session was lost to "nothing looks updated": the owner's Mac had 84
uncommitted changes and a dozen files that had never been pushed, so the running
app was newer than GitHub, not older. The giveaway was a string on screen
(`Seedling`) that existed in no committed file.

**`main` and a feature branch can share an ancestor and still be unmergeable in
practice.** In September 2026 two versions grew from `b189dae` in parallel — the
owner's real app (Siri Intents, sound engine, milestones, onboarding) and an
agent's design work. `MainAppView` differed by 1,000 lines. The design work was
re-applied by hand rather than merged, and the parallel Insights implementation
was dropped outright because the owner's was already wired in.

**The blocks are the identity; chrome is not.** Do not give cards, sheets or
form wells a white rim, a frosted band or a blurred edge. Those say "you built
this and it is standing on something", which is a block's claim.

## The block, and why it is built the way it is

From Figma "Apollo" (`248:14`). The effect is LAYERED, not styled: a block with
a solid white border on all four sides, and a separate rect over the bottom 26%
applying `backdrop-blur(10px)` to it. The blur eats the border, so the bottom
edge is that same border out of focus — not a strip, not a gradient.

`BlockSurface` reproduces this by drawing the surface twice and masking. Four
things were got wrong on the way there; do not redo any of them:

- **Do not composite a blurred ring on top of a sharp block.** That adds a white
  highlight inside the colour field and leaves the silhouette crisp. The source
  has neither. The sharp surface must be replaced, not decorated.
- **Do not crossfade the two copies symmetrically.** Two masked opaque layers at
  50% each composite to 75% alpha, so the block goes translucent through the
  handover and the page shows through as a milky cast. The blurred copy reaches
  full opacity BEFORE the sharp one starts to fade.
- **Do not add `.drawingGroup()` to a block view.** It rasterises to the view's
  bounds, which re-clips the soft edge and puts the hard silhouette back.
- **Do not scale the blur off the rim width.** In the source these are two
  separate elements (a 5px border, a 10px blur). Blur is 1.78% of block width;
  at 4pt the bottom half hazes over.

Proportions come from the source: radius 14.7% of the side, blur 1.78%, band
the bottom 26%. **Two have since been changed deliberately, by the owner, and
are not drift:** the rim is 1.4pt rather than Figma's 0.89%, and it is a
gradient (full white on the top edge, `blockRimFalloff` elsewhere) rather than
flat; the wash is 0.10 rather than 0.20. Both because the block was washing out
at top and bottom and the rim had to carry "lit from above" on its own.

## The tower screen is the reference

Every other screen is meant to end up looking like it, so when the two
disagree, the tower is right. Its anatomy:

- **Header**: block count as a large numeral, the period and qualifiers under
  it, the filter on the right. No navigation bar — the filter said "Day" while
  the title said "Today", which is the same fact twice.
- **Nothing sits under the tower.** It stands on its reflection with the tab
  bar directly beneath. Counts live in the header, never below the blocks.
- **The water** is a `Canvas`, not a shader (see below). Paler than feels right
  in isolation: a reflection you notice reads as content and invites a scroll
  to something that is not there.
- **Blocks are one flat colour** with a rim that is brightest along the top
  edge. No vertical gradient — the block is lit from above by its rim, not by a
  wash at both ends.

## Traps in the rendering stack

**`MainAppView.body` and `mainContent` are at the type-checker's ceiling.**
Adding one modifier to either fails with "unable to type-check this expression
in reasonable time". Extract into a typed `ToolbarContent` property or a
`ViewModifier` instead — there are several already, and that is why.

**SwiftUI shader effects do not update their uniforms across frames in the iOS
26.3 simulator.** They render once and freeze. Verified three ways: a
`colorEffect` forcing flat red DID apply; a `colorEffect` reading the time
uniform gave a byte-identical pixel every frame; the same clock driving a plain
`.offset` in Swift animated normally. So anything animated cannot be verified
here as a shader. The water is a `Canvas` for exactly this reason. (Metal
itself works, and the toolchain is installed — it is a 688 MB Xcode component,
`xcodebuild -downloadComponent MetalToolchain`.)

**An `Equatable` View will silently stop updating from `@Observable` state.**
This has now broken three separate features and it never errors, warns or
crashes — the animation runs to completion and nothing moves.

`AnimatedBlockView` is `View, Equatable`. Its `==` compares stored properties,
and the per-block animation state is a shared reference: both sides hold the
SAME object, so any value on it is always "equal". SwiftUI then has no reason
to re-evaluate the child, and observation does not reliably reach it.

- The drop phases work only by accident: the grid reads `dropPhase` for
  `zIndex`, which re-renders the row.
- The jubilation wave did NOT work. The coordinator set `jubilationLift = -10`
  on every block and no body ever saw a non-zero value.

**The rule: read the driving value where the framework cannot miss it** — in
the grid's own body, not inside a memoised child, and not only inside a
`ForEach` closure (reads in there are not a dependency you can rely on). The
dance reads `animCoord.danceTick` at the top of the grid body for exactly this
reason. Same family of bug: `state(for:)` creates on demand, so a view body
calling it can create a rival instance the coordinator never mutates —
`ensureStates(for:)` now seeds them all before anything renders.

**Verify what your instrument is pointed at before trusting a null result.**
A "does the tower move" probe reported the dance as 0px of movement across 341
frames. It was measuring the water reflection's edge, which sits just below the
tower and does not participate. Measuring the tower's TOP edge showed a clean
22px lift. A null result from an instrument aimed at the wrong thing looks
exactly like success. Two other measurement errors this session: a colour
detector that saturated once the tower grew into its sample band, and an
aggregate frame count that looked healthy while 8 of 10 individual drops never
animated. **Classify every event and report the count, never an aggregate.**

**The tower renders `FlippableBlockView`, not `HabitBlockView`.** Both exist.
If a block looks wrong on the tower, that is the file.

**Measure before you diagnose a colour.** The "top light" gradient nobody could
find was located by sampling pixels down a screenshot, not by reading code.

## The drop, and the dance

The fall starts **off screen**, always. Its start offset is measured from the
grid's real position in the window (`TowerGeometryProbe`) and captured ONCE
when the drop is queued, so nothing in flight can move it. Three earlier
versions derived it live — from `towerScrollOffset` (stale; republished only in
8pt steps), from `gridH` (jerked up a row-pitch on drops that completed a row),
and as a fixed distance above the slot (started low on a short tower, which
read as blocks rising from the bottom). Do not reintroduce any of those.

The fall is gravity: `t = sqrt(2d/g)` at one `g`, on a constant-acceleration
curve. All masses fall the same, because they do. Mass decides the landing
only. Do not add easing-out at the end — a falling object does not decelerate
into the ground, and arriving at peak speed is what makes the landing land.

**The tower dances every tenth win** (`GridConstants.danceEvery`). One wave,
two phases, delays taken from each block's row. It refuses to start while
anything is dropping. Known gap: the water reflection does not participate, so
the tower sways and its reflection sits still.

## Product direction

`docs/product-direction.md` — the pivot: Strata visualises the wins in your
day. Four tabs (Tower, Today-as-checklist, Calendar, Insights), and the rule
that settles arguments: **recording a win must be the fastest thing in the
app.** Today and Plan are being replaced by one checklist.

`docs/case-study.md` — collected material for the write-up: the measurement
method, every bug and what made it invisible, and the before/after numbers.

## Settled — do not reopen

- **SF Pro Rounded, two weights.** The Figma specifies Familjen Grotesk; the
  owner chose the native face on 2026-09-06. Shape, colour and the rim carry the
  block's identity, not the letterforms. The **wordmark** is the one exception:
  it is Rounded *Semibold*, because a wordmark is drawn artwork rather than
  interface type and at 61pt white over a viewfinder Medium reads thin. Do not
  spread Semibold into the UI.
- **The mark is `StrataMarkShape`, not a letter in a font** (2026-09-09).
  A blocky S built from two bars and a slash, cut from a rounded square whose
  corners take `BlockSurface`'s own 14.7% radius, with every interior angle a
  straight cut. It is DRAWN — the geometry is generated by
  `tools/make_logo.py`, which writes `brand/strata-mark*.svg` for anything
  outside the app and `--swift` re-emits the constants. Do not hand-edit them
  and do not ship a bitmap of it. The slash is 0.50 of the width: rendered at
  0.36/0.43/0.50/0.57 side by side, below 0.43 it reads as two bars joined by
  a hairline and above 0.50 the counters close.
  The shape family is a common lettering idea, but the specific Pinterest
  drawing that prompted it is somebody's work — the block radius, the
  proportions and the slope are deliberately not it.
- **Jaro is the wordmark, and nothing else.** Removed on
  2026-09-09 and restored the same day, both on the owner's call. The removal's
  argument — a heavy angular slab fighting the pale mark beside it — was true
  of the FIVE-COLOUR block-S it was standing next to, and that mark is gone.
  Against one pink block with a white letter on it, Jaro is the letter. The
  icon, `StrataMark` and `StrataWordmark` are one construction: pink field,
  white Jaro S. `UIAppFonts` in Info.plist is what registers it — without that
  `Font.custom` falls back to the system face silently, which looks exactly
  like the font not loading. `tools/make_app_icon.py` sets the glyph with the
  real font. `Jaro-OFL.txt` ships beside the `.ttf`, as the licence requires.
  **Do not put Jaro on numbers** — it was briefly on the tally and made the one
  number on each screen read as part of the logo rather than as a count.
- **Do not stack translucent copies of a block.** Album covers fanned three
  prints, rotated and dropped to half opacity, after a photo-album Figma. A
  block is a single flat lit plane; overlapping ghosts of it are clutter
  dressed as depth. One photograph, fading in on `gentleReveal`.
  (2026-09-09, owner's call.)
- **Light, not heavy.** The block shadow is 0.07 at a 7pt radius (was 0.12 at
  5) and the photo block's caption veil tops out at 0.26 (was 0.48, and 0.80
  before that). The direction has only ever gone one way and it is always the
  owner's: a block is a lit plane, and anything dark on or under it reads as
  weight the design does not want. The look being aimed at is "clean but
  structured" — the block itself is the reference.
- **Accent is `AppColors.accentWarm`** (`AccentColor.colorset`). It was stock
  sky blue, which is where every "this looks like default iOS" complaint came
  from — tab bar, menu labels, links all inherit it.
- **Toolbar items drop their iOS 26 glass capsule** with
  `sharedBackgroundVisibility(.hidden)`, gated to iOS 26 (deployment target is
  18.0).
- **Colour and category are two different facts on a block.** A win logged in
  one tap has no category — that is the point of one tap — but a colourless
  block does not belong on a page made of colour. So `category` stays
  `.unlabeled` (which is what suppresses the icon, since
  `HabitCategory.unlabeled.iconName` is nil) and `spontaneousCategoryRaw`
  carries a colour picked at random. **Draw with `habit.displayCategory`; take
  the icon from `habit.category`.** Getting this backwards puts an icon on a
  block whose category nobody chose, which claims something untrue.
  Earlier attempts — neutral grey, then translucent white — both made the block
  that claims the least the only one that did not belong to the page.
- **A block with no name shows no text at all.** Not the word "Win".

## Deliberate pairs — do not "fix" these

(`WeekProgressStrip`'s future/past ring track used to be listed here. The owner
asked for it removed on 2026-09-06; the completion and skip arcs stayed, since
those are data. The cell now reserves its box explicitly — without the track
setting the height, a day with no arc collapsed to its numeral.)

- `checkmark.circle.fill` (green, "All done!") vs `checkmark.circle` (grey, "All
  cleared"). Fill means fully completed; outline means closed with skips.

(The mini-block preview used to be listed here as "intentionally smaller-scaled
chrome, not a bug". The owner overrode that on 2026-09-07: it had drifted to a
diagonal gradient with no rim and no band, which is the styling the tower left
behind. `MiniBlockPreview` is deleted and `StrataMark` — built on the real
`BlockSurface` — took its one remaining call site.)

## Gestures CAN be tested — use `StrataUITests`

The line below about nothing being able to tap the simulator is true of
`osascript` and false of XCUITest, which drives the simulator through the test
runner and needs no macOS accessibility permission. `StrataUITests/TowerGestureTests.swift`
presses, holds, drags and swipes for real. It is slow — 30s to 200s per test,
and the whole file is 10+ minutes — so run it in the background and never
build while it is running: rebuilding the products mid-run makes every test in
the run fail, which looks exactly like a regression.

Read results from the xcresult, not stdout (test `print` does not reach the
xcodebuild log):

    xcrun xcresulttool get test-results tests --path <newest .xcresult>

**What XCUITest cannot do here:** synthesise the lift that begins a UIKit drag
session. `press(forDuration:thenDragTo:)` drives a `DragGesture` fine and does
NOT trigger `.draggable`. So drag-and-drop reordering is verifiable up to the
drop and no further; that is why the ordering rule lives in `TowerOrdering` as
a plain function with unit tests.

**Any recogniser on a block starves the tower's ScrollView.** Measured, by
swiping a 44-block tower and fingerprinting every label's position:
`highPriorityGesture(drag)`, `simultaneousGesture(drag)`,
`LongPressGesture.sequenced(before: DragGesture)` and a bare
`.onLongPressGesture` all give **0.0pt** of scroll. A `TapGesture` is the one
exception. `.draggable`/`.dropDestination` also scroll normally, which is why
rearranging uses them. Do not reintroduce a gesture-based reorder.

`.gesture(cond ? someGesture : nil)` still installs a recogniser for the nil
case. Make the MODIFIER conditional, not the gesture.

**Two settling traps.** A seeded tower runs a drop cascade per block; swiping
before it finishes reports no scroll. Allow ~16s. And a tower reuses titles, so
"the first Walk" is a different element before and after a scroll — assert on
the whole set of label positions, never one match.

## Rearranging, and the rules that fall out of it

Dragging a block does not pick it up. The block leaves its slot, the tower
reflows live to show where it would land, and letting go keeps that
arrangement. **Nothing is written to SwiftData until the drop** — an unrelated
`context.save()` would otherwise persist a preview the user never released.

**There is no drag-cancellation callback on iOS 18.** `.draggable` has no
completion, `DropDelegate` has no session-end, and `DragConfiguration` /
`DragSession` / `.onDragSessionUpdated` are iOS 26. So the cancel is a debounce
on `isTargeted:false`, and `commitRearrange` cancels it first thing, which
makes delivery ordering irrelevant.

**Never call `repackTower()` during a drag.** It goes through `refreshData()`,
and `enqueueArrivals` in there does not merely queue animations — it CONSUMES
`awaitingDropIDs`, so one reflow during a pending drop silently eats that
block's fall. `reflowTowerOrder()` calls `buildTower` and nothing else, and
refuses to run while anything is animating (a reflow makes `newlyDroppedIDs`
empty, which would clear a drop still in the air).

**`buildTower(preserveOrder:)`** exists because the proposal lives in an array
of ids, and the default sort by `towerOrder` would throw it away.

While rearranging, three things are suppressed: merged runs (a `MergeGroup`'s
id is its lowest member's UUID, so it re-keys on every reflow and hard-cuts),
block culling (rows shift, so culled blocks pop), and milestone detection.

**The `Equatable` trap struck a fourth time here.** `AnimatedBlockView.==`
compared nineteen properties and `liftedBlockID` was not one of them, so the
lift had never rendered at all. Anything new that a block view reacts to must
be added to `==`.

## Memories, and why it does not use `@Query`

`@Query` has no fetch limit, materialises its whole result, and re-runs on
every context save — and this app saves constantly. `MemoriesViewModel` uses
explicit `FetchDescriptor`s over lexicographic ranges on `dateString`, with
`#Index<HabitLog>([\.dateString])` keeping them off a table scan: one trailing
180-day window for the shelf, one month at a time for the month tower (cached
by `"yyyy-MM"`), and the full record paged eight weeks at a time behind the
shelf's tail card.

**The month is fetched, never derived from `sections`.** Those are paged eight
weeks deep, so deriving an older month from them would silently show a partial
one — wrong rather than slow.

**`MainAppView`'s own query stays narrowed to the current month.** That is
load-bearing, not a bug: `refreshData()` walks every log it holds, on a hot
path.

**A past day is built with a SECOND `TowerViewModel`.** `buildTower` mutates
its instance and schedules a cleanup task, so running it for a past day on the
live one leaves the Wins tab showing yesterday. `StaticTowerView` draws the
result, and the caller must hand in `\.towerFilterMode` and
`\.perfectDayDates` by name — the block views read both and there is nothing
to inherit outside the tower tab.

**The month tower does NOT merge adjacent same-colour blocks.**
`MergedGroupView` fuses touching cells of one colour, and on the real tower
that is true — they are one object. In a month, two touching blocks are two
different days, and fusing them destroys both the tap target and the meaning.

**Month blocks carry a day numeral**, which looks like an exception to "a
block with no name shows no text" and is not: that rule is about an unnamed
win claiming a name, and a day number is the block's coordinate. It is needed
because `GridPacker.firstFit` is **not monotonic** — a 2×2 leaves a hole beside
it that a *later* day drops into, so position alone does not say which day a
block is, and every block is a destination.

**The grouping is pure, and `WinRecord` is what makes that true.** `Album`'s
statics are value functions over value types; only `Album.records(from:)`
touches `@Model`. That is why `AlbumTests` runs on struct literals with no
container.

`QuickWinService.logWin` takes an `on date:` so a fixture can span weeks —
without it the app can only ever create today, and nothing in History could be
measured. `-strataSeedHistory <days>` uses it. Its seeded photos are written
**synchronously** straight to the image directory: bridging `ImageManager`'s
async save back with a semaphore deadlocks the main actor during launch and the
app comes up blank. Measured, once.

## Screenshots without a tap

There is no accessibility permission for `osascript` on this machine, so
nothing can tap the simulator. `Strata/Services/DebugHarness.swift` (`#if DEBUG`)
takes launch arguments instead:

    xcrun simctl launch <dev> JaydenBetts.Strata \
        -strataStartTab tower -strataSeedWins 12 -strataSeedHabits 4 \
        -strataSeedUnlabeled 2 -strataOpenSheet settings|add|block

It seeds through the same `QuickWinService.logWin` and `Habit.init` the app
uses, and suppresses the HealthKit sheet (a system alert no script can dismiss).
Onboarding is skipped from outside with `simctl spawn <dev> defaults write`.

`-strataAutoWin n` presses the next slot n times, two seconds apart, so the
drop cascade can be watched without a tap.

**To judge an animation, burst-capture and count.** `simctl io screenshot`
samples at roughly 3Hz, so: run with `-strataAutoWin 8`, take ~70 screenshots
back to back, and count how many catch the thing mid-flight. That is how the
"blocks stopped falling" report was resolved — they were falling, and exactly
one frame in seventy caught one, which is the same thing as not falling as far
as anyone watching is concerned. It is a coarse instrument: use it to tell
"never" from "sometimes", not to measure a duration.

**Allow ~16 seconds after launch before screenshotting.** A shorter delay
catches the loading skeleton and has repeatedly been mistaken for a bug.

Because nothing can tap, anything behind a gesture is unverified by definition.
Say so rather than implying otherwise.

## Where the design is written down

**`docs/design-system.md`** — 542 lines, and the file a session is most likely
to miss. Colour tokens, type scale, spacing, the radius ladder, the shadow
system, and a complete motion spec: drop physics, tap feedback, semantic
motion, Today-screen motion, card motion, celebration timings. Read section 5
before writing any animation.

`tasks/brand.md` carries the intent behind those numbers.

**`docs/apple-design.md`** — the owner's reference for how Apple-grade motion
behaves, copied into the repo on 2026-09-07 (it was in `~/Downloads`). Read it
before designing any gesture. The rules that bite hardest here:

- **Respond on pointer-DOWN, and continuously during the gesture** — not on
  release.
- **Springs, not durations**, for anything a finger touches.
- **Critically damped (`dampingFraction` 1.0) by default.** Bounce is only
  earned when momentum caused the motion — a flick, a throw, a drag release.
  Overshoot on something that merely repositioned reads as indecision.
- **Interruptible always**: animate from the presentation value, never the
  target.
- **Project momentum on release** rather than snapping from the release point.
- **Rubber-band at boundaries**, never hard-stop.

Between the two files: `apple-design.md` is the behaviour, `design-system.md`
section 5 is this app's numbers.

**Motion goes through `GridConstants` tokens, never an inline `.spring(...)`.**
This is stated below as a convention and is widely violated in older code
(`TowerAnimationCoordinator`, `TimelineHabitRow`, parts of `MainAppView`).
Do not add to it; fixing the existing ones is a worthwhile separate pass.

## Conventions

- Task state lives in `tasks/`: `active.md` first, then `coordination.md` before
  touching shared files. `history.md` is append-only.
- Motion uses `GridConstants` spring tokens. No inline `.spring(...)`.
- Haptics via `HapticsEngine`. Never instantiate a feedback generator inline.
- Icon sizes come from `GridConstants.icon*` tokens.
- Stage your own paths: `git commit -- <paths>`. Never `-a`, never `add -A` —
  that is how two simulator recording folders ended up committed.
- The owner builds from `main`. Work parked on a branch is invisible to him.

## Running on a real device

Signing is automatic, team `W34J6358L7`, bundle `JaydenBetts.Strata`, and both
entitlement files are **empty** — nothing beyond a plain development profile is
needed. Keep them that way unless a capability is genuinely used: HealthKit's
entitlements were the first thing to fail provisioning.

**An empty usage-description string is a device crash, not a warning.**
`INFOPLIST_KEY_NSHealthShareUsageDescription` was `""` and iOS terminated the
app the moment `setup()` asked for HealthKit. It never appeared on the
simulator, where HealthKit is unavailable and the call short-circuits. Anything
new that touches a protected resource needs a real string before it is called.

To check the code is device-ready without a profile:

    xcodebuild -scheme Strata -destination 'generic/platform=iOS' \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

## Safety

- `HabitLog.imageFileName` points at real user photos. Never delete or rewrite
  image files on a code path that only meant to read them.
- Adding a case to `HabitCategory` is safe for SwiftData, but it must be kept out
  of pickers — use `HabitCategory.selectable`, not `allCases`.
