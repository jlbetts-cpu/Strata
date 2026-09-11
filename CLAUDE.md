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
- **Nothing sits under the tower.** The tab bar is directly beneath it.
  Counts live in the header, never below the blocks.
- **There is no water.** The tower used to stand on a reflection drawn in a
  `Canvas`; it is gone (2026-09-10, owner: "remove all the water references
  like the splash, we dont have that anymore"). The code went first and the
  comments outlived it by some months — a dangling doc comment for a deleted
  function reads exactly like a feature you cannot find. If you meet a
  reference to water, a splash or a reflection anywhere, it is stale.
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
- **The numbers are the owner's own digits, as a real FONT**
  (`Strata/Resources/StrataNumerals.ttf`, generated by
  `tools/make_numeral_font.py` from a 362x28 Figma strip). Metrically
  compatible with SF Pro Rounded — 2048 upem, ascent 1980, descent -432, cap
  1443, all copied from `SFNSRounded.ttf` — so a `Text` in it has the same
  layout box as one in the system face, mixes on a line with it, and lands on
  the same header rule. Digits are TABULAR, so a count that changes does not
  reflow the word beside it. Use `Typography.tally` and
  `Typography.numeral(_:)`; it has ten glyphs and a space, so a `Text` in it
  containing a letter renders `.notdef`.
- **Build that font as TrueType, never CFF.** As an `.otf` with CFF
  outlines, `.contentTransition(.numericText())` CLIPPED every glyph — about
  0.08 em off the bottom, a hard horizontal cut with the baseline below it.
  The same outlines as `glyf` render whole. Verified both ways on the
  simulator; the font's own `head`, `hhea`, `OS/2` and `FontBBox` were
  correct in both.
- **The mark and the wordmark are the owner's own letterforms** (2026-09-09).
  Both are SVGs in the asset catalogue with `preserves-vector-representation`
  and template rendering, so they are the drawings rather than bitmaps of them
  and tint like type. `StrataSMark` is the mark and the app icon;
  `StrataWordmark` is the word. They are the same letterform, which is the
  point — the icon, the Settings header and the camera all show one `S`.
  Originals live in `brand/strata-S-owner.svg` and
  `brand/strata-wordmark-owner.svg`.
- **A drawn header is not type, in three ways that each cost a measurement.**
  1. Use `GridConstants.headerArtworkTopPadding`, not
     `headerTopPadding(forTitleSize:)`. A `Text` sets its cap below its own
     layout box and the function corrects for that; artwork's frame top IS
     its cap top, so the correction pushes it up by the whole amount —
     measured, the camera's wordmark landed at 71.7pt against the 81.0pt line
     every other header sits on.
  2. **`size` on a drawn title is CAP HEIGHT; `Font.system(size:)` is an em.**
     Handing a drawing the 34 sets it 41% taller than the type it replaced —
     "Memories" came out with a 33.3pt cap against the tally's 23.3pt.
     `Typography.screenTitleCap` is the number to hand it.
  3. **Do not baseline-align a drawn title against a 44pt icon button.** A
     `Text` and the button are within a few points of each other, so a
     baseline rule puts both near the row's top; a drawing is only as tall as
     its cap, so the row's top becomes the BUTTON's top and the title falls
     7.6pt below the line. Align the row to `.top` and offset the button onto
     the cap by hand, as `MemoriesView.titleRow` does.
- **The camera's wordmark is deliberately bigger than a page title** (32
  against 23.96) and that is not drift. Every other screen is a title over a
  page of content; the camera is a wordmark over an empty viewfinder with
  nothing in the top two thirds to hold the other end of it. Its size is also
  bounded by the composition guides: at 40 the word ran to 276pt and crossed
  the SECOND vertical at 268, which is a title covering the grid rather than
  sitting in it. At 32 it measures 16 to 219 — through the first vertical,
  which is broken for it, and 49pt short of the second.
- **`Header.height` on the camera IS the wordmark's cap height.** The break in
  the first vertical is cut to the word, so the word is centred in it by
  construction rather than by a second number that has to be kept in step.
- **The wordmark is 6.5:1**, against Jaro's 2.4:1. Sizes tuned for Jaro will
  overflow: the camera's 61pt ran the word 396pt across a 370pt page and
  clipped the final `a`. See the camera entry above for where it landed.
- **The tower header's word stays SF Pro Rounded at a subheadline size.** It
  was drawn on the numeral's own 28-unit body for one build — one face, one
  size, baselines agreeing to 0.00pt — and the owner's call is the smaller
  type. The reasoning holds: the count is the fact and the word is a caption
  for it, so the word being quieter AND smaller is the header saying which of
  the two you are meant to read. Matched in size it stopped being a caption
  and became half of a two-word title. The drawings survive in
  `brand/wins-owner.svg` and `brand/win-owner.svg`; the imagesets and the
  `WinsWord` view are gone.
- **The mark is the owner's `S`, white on warm black** (2026-09-10). The icon
  and `StrataMark` are the same drawing on the same ground. It replaced a
  three-block ziggurat, which had replaced a thinner `S`; the ziggurat was
  argued from research (a single-letter monogram carries no meaning of its own
  and works only by accumulating recognition), and the redrawn letter meets
  that on its own terms — it is a bold angled mark, not the light monoline the
  argument was about, and it holds at 60pt. `render_mark` and
  `StrataMarkShape` stay in the tree, generated and free.
- **`tools/flatten_svg.py` has two traps, both of which draw a mark HOLLOW.**
  An open `<path>` with a `fill` is filled as if closed — that is the SVG spec
  — but `pathops` leaves it open, so union it with its own stroke and the
  contours oppose. And skia's stroker emits a ribbon whose contours can be
  wound against each other: the union came out at 494 square units against 523
  for the fill alone. **Close every contour, and `simplify()` the stroke before
  unioning.** Verify by rendering against the original export — the bar is
  under 0.01% of differing pixels.
- (Superseded) **The mark was LAYERS for a day.** Three of the app's blocks,
  pink on warm black. `StrataMark` draws the real `BlockSurface` so it cannot
  drift from the blocks it is a mark for; `tools/make_app_icon.py` mirrors
  those constants for the tile and is the copy to keep in step.
  The case against the `S` it replaced: a single-letter monogram carries no
  meaning of its own and works only by accumulating recognition, marks that
  depict what a thing does outperform abstract ones, and at tile size a home
  screen is already a wall of squircles with letters on them. Strata owns an
  object; a letter is camouflage. Composition and colour were settled by
  rendering seventeen candidates at 1024 and at 62pt: one block reads as a
  colour swatch, six turn to mush, a multicoloured stack reads as a generic
  squares icon, every asymmetric arrangement is less legible than the centred
  one, and pink beats white because in this app colour is what a block IS.
- **`StrataMarkShape` is kept but unused.** It is the constructed blocky S,
  generated by `tools/make_logo.py`. The owner's call is that the logo is the
  new `S`; the shape stays because it is generated, costs nothing, and the
  question it answered — a light monoline may not hold at 50pt on a home
  screen — is real and may come back.
- **The Memories gallery is the camera roll**, not a grid of blocks. Edge to
  edge, three across, square, a 2pt hairline, no corner, no rim, no caption,
  month headings pinned (2026-09-09, owner's call, from a phone). It had all
  of those and each was defensible; together they made a photo grid that
  looked designed rather than like photographs. The titles moved onto the
  photograph in the viewer, which is where anybody actually reads one.
- **A photo viewer FITS, and its caption is in the BLACK, not on the
  picture** (2026-09-09, owner's call — it was on the picture for one build).
  Use `aspectRatio(_:contentMode:)`, not `scaledToFit()`, wherever anything
  has to be measured against the picture: they look identical and are not —
  `scaledToFit` leaves the view filling its frame with the image drawn inside
  it, so an overlay lands in the letterbox. Given the image's own ratio the
  view's bounds ARE the picture.
- **The photo deck is a paging `ScrollView`, not a `TabView`.** `TabView`'s
  page style owns its horizontal gesture and there is no way to switch it off,
  so panning a zoomed-in photograph flicked to the next one. A scroll view can
  be told to stop. It is also keyed by identity rather than index, so deleting
  a photograph does not renumber the deck behind it.
- **A photo opens out of its thumbnail**, via `matchedTransitionSource` +
  `.navigationTransition(.zoom(sourceID:in:))`. Not a sheet sliding up.
- **A crossfade must never reveal what is under it.** `.transition(.opacity)`
  on one slot fades both copies through partial alpha at once, the pair
  composites to less than opaque, and the substrate shows through the middle
  of the handover — a block's flat colour, in the month tower's case. Hold the
  outgoing layer at full opacity underneath and bring the incoming one up on
  top, then swap. Same mistake `BlockSurface` documents about its own two
  masked copies.
- **Deleting a photo removes the PHOTOGRAPH, never the win.** `PhotoRemoval`
  clears `imageFileName`, saves, and only then deletes the file. A delete
  button inside a photo viewer that silently shortened your tower would be the
  worst thing this app could do, so the confirmation says so out loud.
- **Month blocks show that day's photographs**, cycling on a per-block phase
  taken from the day number — thirty blocks on one clock is a wall that
  blinks, and the eye reads a blink as an alert. Five seconds a picture,
  off under Reduce Motion. **The fixture cannot judge this**: seeded photos
  are flat gradients coloured by category, so a block showing its photograph
  looks almost exactly like a block showing its colour. Verify by sampling a
  column for a vertical gradient, not by eye.
- **Dump the accessibility tree before theorising about a UI test failure.**
  `XCTFail(app.debugDescription)` puts the whole tree, with frames, into the
  xcodebuild output — and it is the only thing that reaches you, since test
  `print` does not. It settled two long-running failures in minutes after
  hours of guessing, and it disproved a claim I had already written down
  (`.disabled(true)` does NOT drop a button from the tree; the element is there
  and marked `Disabled`).
- **`exists` is not evidence a control is on screen.** An off-screen element
  stays in the accessibility tree — the month picker measured
  `exists=true hittable=false frame=(18, -1974, 44, 44)`. Assert `isHittable`.
- **A block's HIT area is bigger than what it draws.** The month tower places
  blocks with `.offset`, which moves the drawing and not the layout, so the top
  block's frame reaches up over the month picker and swallowed its taps —
  pressing `‹` opened a day instead of changing the month. Anything drawn above
  a tower needs `.zIndex`.
- **`pinnedViews: [.sectionHeaders]` does nothing for a `Section` inside a
  conditional.** Memories' month section sits in the `else` of the empty-state
  branch, so it never pins however it is decorated.
- **A MapKit `Map` cannot live in the Memories `LazyVStack`.** Put one in and
  the whole body stops re-evaluating: the page keeps rendering its EMPTY state
  while the view model holds forty pins, and nothing errors, nothing crashes
  and the app stays alive. Bisected — a plain `Color` in the same slot renders,
  a plain rectangle as the annotation does not help, and constraining the map
  in a fixed overlay box does not help. It is now moot: **the map IS the
  Memories tab** (2026-09-10, owner's call — "the map feature I want to be the
  most important add and the biggest focus"), full-bleed and resting
  undivided. Everything the tab used to be is `MemoriesDrawer`, which rests
  HIDDEN and is raised by the button in the title row.
- **The drawer is not a `.sheet`.** A sheet presented from inside a `Tab` sits
  on the window's presenting controller, and at a small detent it occupies
  exactly the band the floating tab bar lives in — the bar is neither resized
  nor raised, and `presentationBackgroundInteraction` restores interaction with
  content BEHIND the sheet, not with chrome it is sitting on. iOS 26's
  `tabViewBottomAccessory` is the native answer and the target is 18.0.
- **`DrawerDetent` is a top-level enum, not nested in the drawer.** Nested it
  would be `MemoriesDrawer<Content>.Detent`, so the `@State` holding it must
  name a `Content` — which pins the drawer to that guess and rejects the real
  content type. Related: **static stored properties are not allowed in a
  generic type at all** (`DrawerMetrics` exists for that reason).
- **Hold the map's clusters, never compute them.** As a computed property the
  content depends on `zoom`, `onMapCameraChange` writes `zoom`, and
  `.automatic` frames the camera from the content — a loop with no settling
  point. Recompute only when the integer zoom changes, and never assign
  `camera = .automatic` from inside the view.
- **MapKit cannot be recoloured**, so the ground was chosen by measuring, not
  arguing: standard-muted-no-POIs came out at mean luminance 232 — BRIGHTER
  than the 207 page it was meant to fix — against imagery at 117, and
  `pointsOfInterest: .excludingAll` drops the pins but NOT the place names and
  road shields. The scrim is the only lever left after POIs and emphasis.
  **The owner's call on 2026-09-10 is the PALE ground**, imagery behind
  `-strataMapStyle satellite`, and the earlier measurement is not contradicted
  — it was scored on an EMPTY map, where a dark textured ground was the only
  thing carrying the screen. With blocks on it the argument inverts: the blocks
  are the saturated objects and the ground's job is to be quiet under them.
- **The map earns its labels as you arrive.** Below zoom 13, no points of
  interest and a muted emphasis. At and above it the emphasis comes up and a
  curated set appears, and the scrim lifts (0.10 -> 0.03) because a wash over
  type is the one thing that makes a map feel cheap. **Landmarks only.** The
  first list included cafés and restaurants: photographed over Trafalgar Square
  that was about twenty-five orange pins against two blocks — the map named
  every sandwich shop in central London and buried the only thing on screen
  that was the user's.
- **Blocks are drawn on the CELL CENTRE, not on their members' centroid**
  (`PlaceMap.Cluster.anchor`). A centroid can sit anywhere in its cell, so two
  clusters in neighbouring cells could be drawn a few points apart while each
  is 90pt wide — measured, that is two blocks overlapping. Anchoring to the
  cell makes the separation exactly one pitch by construction.
  `targetBlockPitch` is therefore the distance between neighbours and must stay
  larger than a 2x2 (116 against ~90).
- **Thinning a crowded map means going COARSER.** `PlaceMap.cluster`'s density
  loop stepped zoom UP for one build, which splits clusters — so an over-full
  map got fuller, the loop ran to zoom 20 where a cell is under ten metres, and
  every pin became its own block piled on its neighbours.
- **Apple's map attribution cannot be removed** — displaying it is a condition
  of the Apple Developer Program License Agreement, and no API hides it. No API
  positions it either, but it is laid out inside the map's safe area, so
  `.safeAreaPadding` moves it clear of the tab bar.
- **The recentre control is the app's own `GlassIconButton`, not
  `MapUserLocationButton`.** The native one is styled and placed by MapKit and
  draws a blue system chevron in a system capsule.
- **One thumbnail width for every block on the map**, whatever size it draws
  at. `CachedImageView` keys its cache on the requested width, so asking for 88
  at one zoom and 176 at the next decodes the same photograph twice and
  re-decodes it on every zoom step.
- **`WinRecord.place` is `var`, not `let`.** Every other property there is
  `let`, and a `let` with a default value is omitted from the synthesized
  memberwise initializer entirely — it would compile and then be unsettable
  from `records(from:)`.
- **Location: `NSLocationWhenInUseUsageDescription` in BOTH build
  configurations.** The keys are duplicated in the project file; one is a
  Release-only device crash found six weeks later. Read it back out of both
  built Info.plists rather than assuming. `LocationService` is a singleton and
  pre-warms with the camera — a service recreated per appearance never gets
  warm, and warm is the whole point. **No photograph taken before this shipped
  has a place and none ever will**: every path into `ImageManager` re-encodes a
  resized `UIImage` with no metadata container.
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

## Removed on 2026-09-10 — do not bring back

The owner's call, in his words: "there is no block magic or aurora so remove
those", "lets remove the 3d Paradox i feel like it kinda sucks", "remove the
animations previews section from the settings", "remove all the water
references like the splash".

- **The water.** The tower stood on a reflection drawn in a `Canvas`. The code
  went months ago and the COMMENTS outlived it — a dangling doc comment for a
  deleted function reads exactly like a feature you cannot find, which is how
  this survived so long. If you meet water, a splash or a reflection anywhere,
  it is stale.
- **Tower Aurora.** A once-a-week overlay gated on three perfect days. It was
  wired and, in practice, never seen.
- **First-block magic.** A haptic choreography and a 120ms pause on the very
  first drop.
- **3D Parallax.** The tower tilted with the phone via `DeviceMotionCoordinator`
  and two `rotation3DEffect`s. Both the coordinator and
  `NSMotionUsageDescription` are gone — **the app no longer touches CoreMotion
  at all**, so do not re-add the key without re-adding a real use.
- **Settings' "Animation Previews" and "Reset Triggers"** debug sections.

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

## The camera's gestures

Pinch to zoom, double tap to flip, tap to focus, drag to expose — all four on
ONE transparent layer over the viewfinder and under the chrome, because the
guards between them only work if they can see each other. A pinch also
produces a drag translation, so the drag's guard has to check the pinch's own
state or the exposure swings every time you zoom. The double tap is
`exclusively(before:)` the single one, which costs the single tap a
recognition delay; that is unavoidable and the native camera has it too.

**Every device write locks and unlocks in one function.** A lock left open
makes every later configuration change fail silently. **Check
`isFocusModeSupported` / `isExposurePointOfInterestSupported` before setting**
— a front camera usually has fixed focus and refuses outright, and an
unguarded throw takes the exposure change down with it.

**None of it runs on the simulator**, which has no capture device: `canZoom`
is false and the pill is not drawn. Photograph it by forcing the flags on in a
throwaway build. The one thing the simulator CAN answer is whether the new
gesture layer stole the controls' taps —
`testGridToggleTurnsOffAndBackOn` is that test.

The zoom pill is not drawn at 1x. At the lens's own field there is nothing to
report and nothing to undo. Its height is reserved anyway: a control that
appears by pushing the shutter down moves the one thing on this screen that
must not move.

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

`-strataOpenMap`, `-strataMapStyle [quiet|satellite]`, `-strataSeedPlaces`,
`-strataOpenDrawer [half|full]`, `-strataMapSweep`,
`-strataOpenReview [small|medium|hard]`, `-strataTestLocation` and
`-strataReportStore` all exist for the same reason as the flags below them:
the screen or the fact is otherwise unreachable here. `-strataSeedPlaces` puts
60% of seeded wins into three tight clusters and spreads the rest, because an
even scatter never merges and would make a broken clusterer look fine.

`-strataOpenPhoto <i>` opens the photo viewer on the i-th gallery photograph.
Anything behind a tap needs a flag like this: photographing the viewer by
racing a UI test with a screenshot loop caught it in one frame out of thirty,
and missed it entirely on the first attempt.

**To judge an animation, burst-capture and count.** `simctl io screenshot`
samples at roughly 3Hz, so: run with `-strataAutoWin 8`, take ~70 screenshots
back to back, and count how many catch the thing mid-flight. That is how the
"blocks stopped falling" report was resolved — they were falling, and exactly
one frame in seventy caught one, which is the same thing as not falling as far
as anyone watching is concerned. It is a coarse instrument: use it to tell
"never" from "sometimes", not to measure a duration.

**Allow ~16 seconds after launch before screenshotting.** A shorter delay
catches the loading skeleton and has repeatedly been mistaken for a bug.

**Start the capture BEFORE the thing you are capturing.** A burst aimed at the
map's merge returned 46 byte-identical frames, because the sweep had finished
during the fixed `sleep` that preceded the loop. It looks exactly like "nothing
moved". Launch, then capture straight through — do not sleep first when the
subject is a one-shot animation that starts on its own.

**A bare `.task` captures the view value it had at appear.** The map sweep
probe reported `blocks=0 wins=0 of 0` at every zoom while the map on screen was
full of them: the task ran before the fetch landed and held that empty `pins`
for ever. `.task(id: pins.count)` re-runs with a fresh value. This is the
fourth confident false negative in this project from an instrument aimed at the
wrong thing.

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

## What the app CLAIMS about itself must be true

Three documents tell users what Strata does with their data, and on
2026-09-10 all three said things that were false. They are the cheapest bugs
in the app to write and the most expensive to be caught with.

- **`PrivacyInfo.xcprivacy` declared HealthAndFitness and PhotosOrVideos as
  COLLECTED.** Apple builds the App Store privacy label from that file, so the
  product page told people Strata takes their health data and their
  photographs. It takes neither, and there is no HealthKit code in the app at
  all. Apple's definition is the test: *"Collect refers to transmitting data
  off the device... Data that is processed only on device is not 'collected'
  and does not need to be disclosed."* Strata transmits nothing — no
  `URLSession`, no third-party packages, no analytics — so
  `NSPrivacyCollectedDataTypes` is EMPTY and must stay empty until a server
  exists.
- **`PrivacyPolicyView` had a section on "Apple Health and Calendar"** — how
  Strata reads them, that it never writes to them. It imports neither
  EventKit nor HealthKit. A privacy policy is a legal document and that
  section described a product that does not exist.
- **`NSPhotoLibraryUsageDescription` and `NSMotionUsageDescription` were
  declared and unused.** The picker is `PHPickerViewController` (no permission)
  and saving is add-only; CoreMotion left with 3D Parallax. Asking for access
  you never use is asking under false pretences.

**The rule: when you add or remove anything that touches user data, the
manifest, the policy and the usage strings are part of the change.** Check
the BUILT `Info.plist` in BOTH configurations, not the source — the keys are
duplicated in the project file.

## A feature that cannot fire is worse than one you never built

`MilestoneDetector` was handed `longestStreak: 0, // TODO: compute from
streaks`. Six milestones read that number — "Week Strong", "Fortnight",
"Monthly", "Habit Formed", "Triple Digits", "Year One" — so all six were
defined, listed in the app, and unreachable. Somebody could use Strata every
day for a year and never be given the one called "Year One".

`Streaks` computes it now (pure, over `yyyy-MM-dd` keys, 14 tests). Two
things it must keep doing: consecutive days go through `Calendar`, never by
adding one to the string — a day is not always 86,400 seconds long, and a
streak that silently breaks every spring is the worst kind of bug to be told
about. And the CURRENT streak counts yesterday, because a run is not broken
until a day passes with nothing in it.

It is cached behind a signature (`distinct day count | newest day`) because
`refreshData()` is a hot path and the streak needs a 400-day window, while
`MainAppView`'s own query is deliberately narrowed to the current month.

## An ink is not a surface

**This exact mistake was made four times in one session**, in four files, by
reaching for the nearest-looking colour token instead of asking what the colour
is FOR. Every time it passed review and failed on a device.

- `warmBlack` at 0.22 under the plan's checkboxes. A fixed dark ink, so on the
  dark ground it was dark on dark: **1.08:1**, which is not low contrast, it is
  none.
- `warmBlack` at 0.55 behind the settings glyphs. Same fault, **1.24:1**
  against the dark ground.
- `accentWarm` on the switches. Correctly adaptive — and adaptive to a warm
  near-WHITE in dark mode, which is also the colour of a switch's thumb.
  **1.07:1** between the track and the knob.
- `inkQuiet` under a map block waiting for its photograph. An ink meant for
  text, so it inverts: 45% black in light and **55% white** in dark, and every
  block flashed pale on a dark map before its picture arrived.

The rule that would have caught all four:

- **An INK is for text and glyphs.** It inverts with the scheme, because type
  must stay legible on whatever is behind it. `inkSecondary`, `inkTertiary`,
  `inkQuiet`, `slotInk`.
- **A SURFACE is a thing you put ink ON.** It does not automatically invert,
  because what must stay constant is its contrast with the CONTENT on top —
  a white glyph needs a mid-tone behind it in both schemes, not a fill that
  goes pale when the page does. `switchOn`, the map's `waitingFill`.
- **Ask what the contrast is against**, and measure it. A switch track is
  measured against its white thumb, not against the page. A checkbox outline
  is measured against the page, because an empty checkbox IS its outline.
  3:1 for anything that is a control, 4.5:1 for text.

Contrast is arithmetic, so compute it rather than looking: the four above were
all found by computing WCAG ratios from the token's real RGB over the real
ground, and all four were invisible to the eye on the simulator in the scheme
they were authored in.

## Safety

- `HabitLog.imageFileName` points at real user photos. Never delete or rewrite
  image files on a code path that only meant to read them.
- Adding a case to `HabitCategory` is safe for SwiftData, but it must be kept out
  of pickers — use `HabitCategory.selectable`, not `allCases`.
