# Overnight report — 2026-09-06 → 09-07

Written as I went. Bad news first.

## Step 0 — setup finding (read this first)

The local checkout was **behind origin/main by 4 commits**. `BlockChrome.swift`
existed, but `WinsView.swift`, `QuickWinService.swift`, `CLAUDE.md` and the
light-only conversion did not — they were only on the remote. Commit `952fbb7`
(the merge named in the brief for a possible revert) did not exist locally,
which is why nothing in the brief lined up at first.

Fixed by `git fetch --all` + `git merge --ff-only origin/main`. Local main is
now `709517f`. No work was lost; the local tree was clean.

(This is exactly the trap CLAUDE.md warns about, in the opposite direction:
last time the Mac was ahead of GitHub, this time it was behind.)

## Build log

**Step 0 result: main was broken. It is fixed and green.**

`HabitCategory.unlabeled` was added by the overnight session without updating
two switches over the enum:

- `PlanItemRow.swift:889` `categoryLabel(_:)` — the error the compiler reported.
- `SoundEngine.swift:44` `basePitch(for:)` — would have failed on the next pass;
  the compiler had not reached it.

Fixed in `3e2cb33`. `xcodebuild -scheme Strata -sdk iphonesimulator` now says
**BUILD SUCCEEDED**. No revert was needed, so `git revert -m 1 952fbb7` was NOT
run — everything else from the overnight session compiles.

Judgement call: unlabeled's completion tone is C4, the root of the C4–A4 scale
the six categories span. It needed *some* pitch; borrowing another category's
would have made an undescribed win sound like a Health win.

Two pre-existing warnings, left alone for now:
`MainAppView.swift:243` (`habitIDs` unused) and `PlanPageView.swift:417` (`hex`
unused).

## How screenshots are being taken

There is no accessibility permission for `osascript`, so nothing can tap the
simulator's tab bar from a script. Instead I added `Strata/Services/DebugHarness.swift`
(`#if DEBUG` only) which reads launch arguments:

    xcrun simctl launch <dev> JaydenBetts.Strata \
        -strataStartTab tower -strataSeedWins 12 -strataSeedHabits 4

It opens a named tab and seeds a deterministic fixture through the same
`QuickWinService.logWin` and `Habit.init` the app uses. It also suppresses the
HealthKit permission sheet, which is a system alert no script can dismiss and
which covered the first two screenshots I took. Onboarding is skipped from
outside the app with `simctl spawn <dev> defaults write`, so no app code knows
about it.

**Caveat when reading the screenshots:** the seeder pairs titles and categories
by index, so "Deep work" is green/Health and "Called Mum" is blue/Work. That is
my fixture being arbitrary, not a category bug. Do not chase it.

## Step 1 — the tower grid: measured, not guessed

Instrumented `towerContent` and read the real numbers off an iPhone 17 Pro
(874pt tall) with one block:

    viewportHeight=675  safeAreaTop=116  safeAreaBottom=83  gridH=89  topInset=0

`viewportHeight` comes from `geometryTracker`, a `GeometryReader` in a
`.background`. **`GeometryReader.size` already excludes the safe areas**:
874 − 116 − 83 = 675. So in

    .frame(minHeight: viewportHeight - safeAreaTop, alignment: .bottom)

`safeAreaTop` is subtracted a second time. The content box is 559pt inside a
675pt viewport, bottom-aligned — which puts 116pt of dead air under the tower.

Then `.padding(.bottom, max(safeAreaBottom, 8))` adds 83pt more. The tab bar's
inset is already applied to the scroll view by `TabView`, so that padding is
the double-count the note suspected.

**116 + 83 = 199pt.** Predicted block bottom 592pt; measured off
`06-tower-1block-before.png`, 588pt. That is the "blocks sit too high" report,
and it is arithmetic, not taste.

The note's other suspicion is also real but is a *second*, smaller bug: the
ZStack's height is `max(gridH, 1)`, while the ground plane is at `.offset(y: gridH)`,
the tier badge at `gridH + 16` and "Your first block." at `gridH + 40`. None of
them reserve space. Separately, the badge occupies roughly `gridH+16 … gridH+50`,
so **"Your first block." is drawn on top of the tier badge** for the two seconds
it is visible.

### Other defects the screenshots show, which no bug report mentioned

1. **The tier badge icon renders as a tofu box.** `TowerTier.icon` returned
   emoji ("🌱") and the simulator drew an empty-box-with-question-mark.
   **Caveat: I could not verify this on a physical device.** The iOS 26.3
   runtime ships `AppleColorEmoji-160px.ttc` but not the usual
   `System/Library/Fonts/Core/AppleColorEmoji.ttc`, so the tofu may well be
   simulator-only and emoji may render fine on your phone. I changed it anyway,
   because it is also emoji in an app whose CLAUDE.md says "SF Symbols only",
   and because it was drawn at full opacity beside text at 0.2 — a symbol takes
   `.foregroundStyle` and the emoji did not.

   **`MilestoneCelebration.tierIcon` has the same emoji set** (medals, gem,
   star) at 48pt, full screen. I have NOT changed it: unlike the tier badge it
   is not a one-glyph swap, since bronze/silver/gold would collapse onto the
   same SF Symbol and only `tierColor` would separate them. That is your call.
2. **"1 blocks".** No pluralisation.
3. **Height markers are clipped off the right edge.** They sit at
   `.offset(x: gridW + 4)`; with gridW=368, hPad=16 and a 402pt screen the text
   starts at 388 and needs ~26pt. `08-tower-30blocks-before.png` shows "30"
   with the "m" cut off.
4. **Insights' calendar is missing Thursday and Saturday headers** — see
   `05-insights-before.png`. The row reads S M T W _ F _. Classic
   `ForEach(id: \.self)` over `["S","M","T","W","T","F","S"]`: duplicate
   strings are collapsed.
5. **Plan has a hard white band across the middle** behind "Add Folder" — a
   default `List`/`Form` background on the warm ground. `04-plan-before.png`.
6. **Wins leak into Today's Unscheduled section.** Seeding 7 wins and 4 habits
   gives "UNSCHEDULED 7 habits" and "7 of 11 done". A win is already done and
   has nothing to schedule.

### Step 1 — what I changed

- `3e2cb33` the two missing `.unlabeled` switch cases (the build fix).
- `4c00345` `DebugHarness.swift`, the DEBUG launch-argument harness.
- `f968f0b` the four tower-grid faults above.
- `a7f6bcd` tier badge emoji → SF Symbol, and pluralisation.

Screenshots: `06-tower-1block-{before,after}.png`,
`07-tower-12blocks-{before,after}.png`, `08-tower-30blocks-{before,after}.png`,
`09-tower-empty-{before,after}.png`.

`09-tower-empty-before.png` is the clearest single image: the ghost blocks are
drawn up over the clock and the toolbar.

Judgement calls in Step 1:

- The empty state's ghost count went 5 → 3. At 5 the footing was 4 rows tall and
  filled most of the viewport; the invitation had nowhere to go. Three gives a
  two-row footing with the copy centred above it. Reversible in one number.
- The tier symbols are leaf / leaf.fill / tree / tree.fill / mountain.2.fill.
  Chosen to keep the seedling→forest progression legible in one glyph each.
- Bottom padding is now a flat 8pt. If the badge looks tight against the tab bar
  on a device without a home indicator, that constant is the knob.

## Step 2 — the two ports

Both are in, both built and screenshotted.

**`466a251` — `.iconSize()` (Dynamic Type).** Ported `IconStyle.swift` from the
branch essentially as written; it needed no adaptation. Applied at the call
sites where an icon sits beside flowing text, each paired with that text's
style rather than a blanket `.body`. Verified at
`accessibility-extra-large`: `10-today-dynamictype-after.png` — the category
icons now grow with the labels.

Left deliberately fixed, because the glyph is inside a container that does not
grow with it: the checkmark inside `GridConstants.checkCircleSize`; the icon
and title inside a block, which is one grid cell; the Wins counter and its
plus; `SettingsIcon`'s 28×28 badge; `CachedImageView`'s placeholder (sized as a
fraction of the image); and `SiriSnippetViews`, which render in Siri's UI. The
three views that already used `@ScaledMetric` by hand now go through the
modifier, so six stored properties are gone with no behaviour change.

**`47322ee` — `BlockGhostSurface`.** The description in the brief is right
about the chips and wrong about the rows, so trust the screenshots:

- The unscheduled chip really was mud — `Color.primary.opacity(0.08)`, darker
  than the page.
- The incomplete timeline row was *not* a grey slab on main. It was a 0.15
  category wash under a 0.10 white one — pastel, not muddy. It still wanted
  replacing, but for a different reason: no rim, no band, so it shared no
  anatomy with the block it turns into.

Both now go through `BlockGhostSurface`. `12-today-ghostchips-after.png` shows
rows and chips reading as the same object in the same state.

One follow-on change: the chip's check ring was white, invisible on a white
card, so it now takes the category colour.

## Steps 3, 4 and 5

**`65e561d` + `7ca50f5` — Step 3, the shared chrome surface.**

`SurfaceCard.swift` gives chrome the block's grammar without giving it a
block's claim: same warm ground, same radius, a hairline instead of a white
rim, and explicitly no frosted band and no blurred edge. Alongside it, a radius
ladder (20 / 12 / 8 / 4, with the field rung set to `blockCornerRadius`) and
three neutral fills.

Plan is routed through it, and that fixed both of its visible faults — the hard
white band and the muddy tiles. Compare `04-plan-before.png` with
`13-plan-after.png`.

**I did NOT rebuild Settings, and you should know why.** The brief names it,
but `14-settings-before.png` is the least broken of the screens listed: it is a
SwiftUI `Form`, and iOS 26's inset-grouped Form is already white cards on the
warm ground. Converting it means rebuilding toggles, navigation links,
destructive actions and the export sheet as hand-rolled views — a large diff
across a screen I cannot tap through to verify. Taking the smaller reversible
option, I aligned its icon-badge radius to the ladder and left the structure
alone. If you want the full conversion, it is a session of its own with a
device in hand.

Related: this codebase is **already much more tokenised than the brief assumes.**
The branch's commit message describes "around seventy hand-picked greys"; on
current main I found eight literal greys across all the chrome files, and the
straggler radii were two values (10 and 6). Those are now routed through the
tokens. The "iOS defaults with opacities sprinkled on" description was true of
the older snapshot the branch was written against.

**`bdc7575` — Step 4, the add sheet.** Seven sections on screen at once became
title, category, and two disclosure groups: "When" and "Details", each showing
what it currently holds ("Every day", "Quick, 15m"). The title takes focus on
open; arriving from a tapped time slot opens "When" expanded, since that path
has already answered it. No control changed behaviour — they were regrouped —
and two now-unreferenced helpers were deleted. The sheet was also rendering on
the cool system grouped-background grey; it has the warm ground now. See
`15-addsheet-{before,after}.png`.

**`1879ed6` — a bug found on the way.** Insights' calendar was missing Thursday
and Saturday: `ForEach(dayLabels, id: \.self)` over
`["S","M","T","W","T","F","S"]` collapses the duplicate ids. Fixed by indexing.
`05-insights-before.png` → `16-insights-after.png`.

**Step 5 — `tasks/proposal-today-plan.md`.** Research only; no app code was
touched for it. It maps what each tab owns by file and view model, isolates the
overlap (it is narrower than the framing suggests — the sharp part is that
`habit.scheduledTime` is written from two places with two interaction models),
gives three options with sizes and risks, and recommends splitting by verb
rather than merging the tabs, with the reasoning and the one question I cannot
answer for you.

## Every judgement call, in one place

1. **Did not run `git revert -m 1 952fbb7`.** The build had one real error and
   one latent one; both were three lines. Reverting the night's work would have
   been disproportionate.
2. **Added app code to enable screenshots** (`DebugHarness`, `#if DEBUG`).
   Without it nothing modal or data-dependent could be photographed, and the
   whole brief is built on screenshots. It cannot reach a shipped build, and
   the Release configuration was built to confirm that.
3. **Unlabeled's completion tone is C4**, the root of the scale the six
   categories span, rather than borrowing another category's pitch.
4. **Empty-state ghosts went 5 → 3.** At five the footing filled the viewport
   and the invitation had nowhere to sit.
5. **Tier emoji → SF Symbols; milestone emoji left alone.** The tier badge was
   a one-glyph swap. The milestone tiers are not: bronze/silver/gold would
   collapse onto one symbol and only colour would separate them. That is a
   design decision, not a bug fix.
6. **Did not scale every icon with Dynamic Type.** Glyphs inside fixed
   containers stay fixed or they burst the shape. Listed in the commit.
7. **Did not rebuild Settings.** Reasoning above.
8. **Fixed the Insights calendar** even though it was not in the brief. Two
   lines, visibly broken, no ambiguity about the right answer.

## What I could NOT verify

- **Anything on a physical device.** All of it is the iPhone 17 Pro simulator,
  iOS 26.3.
- **The emoji tofu.** It may be a quirk of this runtime's font set. The SF
  Symbol change is justified by CLAUDE.md's rule regardless, but do not take
  "emoji is broken on your phone" from me.
- **Any interaction.** No accessibility permission means nothing can tap.
  Everything here is a rendered state, not a flow. In particular: the add
  sheet's disclosure groups have never been *opened* by a person — I verified
  they compile, that the collapsed state is correct, and that the summaries
  compute, but not the expanded layout.
- **VoiceOver, and Dynamic Type past `accessibility-extra-large`.**
- **Real data.** Everything is the seeder's fixture. No photos, no HealthKit
  values, no long titles, no many-month tower.

## Known-imperfect things I am leaving

- **Wins leak into Today's Unscheduled section.** `22-final-today.png` shows
  "UNSCHEDULED (5)" where all five are completed wins. `QuickWinService.isWin`
  is the predicate and `ScheduleTimelineView.swift:92` is where it belongs. I
  left it because it interacts with the Today/Plan decision in the proposal and
  I did not want to prejudge that.
- **Dynamic Type breaks Today's layout above ~AX3** — `10-today-dynamictype-after.png`
  shows "NEXT" wrapping to "NE/XT" and "9:30" to "9:3/0". Pre-existing, and
  already on your list as "F-10: Time label column width for Dynamic Type
  (deferred)". The icon work made it more visible, not worse.
- **The tower's skeleton was still showing 6 seconds after a cold launch** and
  had settled by 15. The stagger itself is only 350ms, so this is startup cost
  somewhere else (SwiftData, Spotlight reindex, or simulator cold start). Not
  isolated.
- **`MilestoneCelebration.tierIcon`** is still emoji at 48pt, full screen.
- **Two pre-existing warnings**: `MainAppView.swift:243`, `PlanPageView.swift:417`.
- **The seeder does not delete `PlanFolder` objects**, so a stray "NEW SECTION"
  folder persists across seeded runs. Cosmetic, harness-only.

## What I would do next, in order

1. **Decide Today vs Plan** from `tasks/proposal-today-plan.md`. It gates
   several other things, including the wins-leak fix.
2. **Fix the wins leak.** Small, and it currently makes Today's counts wrong.
3. **Look at the add sheet on a device with a finger.** It is the change I am
   least able to vouch for.
4. **The app icon** — still the only Phase 1D item, still a design dependency.
5. **Settings**, if you want it converted, with a device in hand.

## State at the end

- `main` builds. **Debug and Release both `BUILD SUCCEEDED`** on
  `xcodebuild -scheme Strata -sdk iphonesimulator`.
- Everything is pushed to `main`. Nothing is parked on a branch.
- Ten commits, one coherent change each, listed above.

---

# Session 2 — header and minimalism pass

## Research done before touching anything

Four findings that changed the plan:

1. **The "old Apple" look had one root cause.** `AccentColor.colorset` was stock
   sky blue `(0.251, 0.663, 1.000)`. Every `Menu` label, the tab bar selection,
   "Show all N habits" and Plan's drop highlight inherited it — which is why
   `List ⌄` rendered blue despite `.foregroundStyle(.primary)`.
2. **The white capsules behind toolbar buttons are iOS 26's automatic glass.**
   The opt-out is `ToolbarItem { }.sharedBackgroundVisibility(.hidden)`,
   confirmed in the iOS 26.5 SDK's `SwiftUI.swiftinterface` at line 5576.
3. **It is iOS 26.0+ and this project's deployment target is iOS 18.0**, so it
   must be gated. `ToolbarContentBuilder` does implement
   `buildLimitedAvailability`, so `if #available` works inside a `@ToolbarContentBuilder`.
   Ungated, this is a compile error, not a runtime one.
4. **`mainContent` was already at the type-checker's limit.** Adding a single
   modifier to a toolbar item inside that five-`Tab` `TabView` fails with
   "unable to type-check this expression in reasonable time". The toolbars had
   to be extracted into typed `ToolbarContent` properties before any of this
   was possible. Probed and confirmed, not assumed.

Probe screenshot: `tasks/screenshots/probe-tower.png` — bare glyphs on the warm
ground, warm-black tab bar selection.

## What changed in the header pass

| Commit | Change |
|---|---|
| `b3a379f` | Accent → warm near-black; toolbar glass capsules removed; + dropped from Tower; filter is a bare glyph |
| `1dbf0b4` | One header pattern across five tabs |
| `49bcced` | The four strips, plus Settings' toggles off purple |
| `d94def4` | An unlabeled win draws no icon; `TowerHeaderView.swift` deleted |

Debug and Release both `BUILD SUCCEEDED`. Final state:
`40-final-wins.png`, `41-final-tower.png`, `42-final-today.png`,
`43-final-plan.png`, `44-final-insights.png`.

### Two regressions I caused and fixed

- Removing the week strip's track ring broke the row's alignment. The track was
  silently setting each cell's height, so a day with no completion arc collapsed
  to its numeral and the weekday letters stopped lining up. The cell reserves
  its box explicitly now.
- `TimelineHabitRow`'s leading inset was attached to the category icon, so a row
  for an unlabeled win would have started flush against the screen edge. Moved
  to the stack.

Both were caught by screenshot, not by the compiler.

### Judgement calls

1. **`iconName` became `String?` rather than returning `""`.** Nineteen render
   sites; a sentinel would have left one quietly drawing a dot. The compiler
   named all of them. Cost: three view bodies had to be extracted because the
   optional pushed them past the type-checker.
2. **Two menus over `HabitCategory.selectable` use `?? "circle"`** rather than
   `if let`. They can never see nil, and writing them to handle a case that
   cannot happen would have been dishonest about the model.
3. **The destructive row in Settings keeps its red.** That colour is semantic,
   not decoration — it is the one badge that was doing a job.
4. **`TowerTier.swift` is now unused** outside its own file. I did NOT delete
   it: unlike `TowerHeaderView` it is product content (a designed
   Seedling→Forest progression) rather than chrome, and it may want to come back
   in Insights or milestones. Sixty lines, no runtime cost. Say the word.

### Left alone, deliberately

- **Plan's `Routines / To-Dos` segmented control.** It is the most "old Apple"
  element left in the app, and replacing it is the obvious next move — but it
  was not in the design you approved, which said it stays as the first content
  row. Not doing it unasked.
- **Plan's section-tile icon circles** (green star, orange sunrise, grey inbox).
  Same species as the Settings badges I removed, so the app is now slightly
  inconsistent on this point. I left them because they are *user data* —
  `SectionEditSheet` lets you pick each section's icon and colour — so removing
  them removes a feature rather than some chrome.
- **`MilestoneCelebration.tierIcon`** is still emoji at 48pt.

### Still not verified

Everything remains simulator-only and untapped — no accessibility permission
means no interaction. Specifically unverified: how the bare toolbar glyphs feel
under a finger without their capsule hit area, and the whole thing on iOS 18,
where the `sharedBackgroundVisibility` branch never runs.

---

# Session 3 — the tower as home, and the water

## The finding that changed the plan

**SwiftUI shader effects do not update their uniforms across frames in the
iOS 26.3 simulator.** The water was written as a Metal `distortionEffect`
first, which is the right tool on paper — one GPU pass, per-pixel. It rendered
once and froze.

Established by three probes rather than assumed:

| Probe | Result |
|---|---|
| `colorEffect` forcing flat red | Applied — the band turned red, so the Metal pipeline works |
| `colorEffect` whose colour came from the `time` uniform | Byte-identical pixel on every frame |
| The same `TimelineView` clock driving a plain `.offset` in Swift | Animated normally |

So the clock ticks, the shader loads and runs, and the uniform never reaches it
again after the first frame. Motion is the entire point of that view, so it was
rebuilt in `Canvas`, where the motion is verifiable here: **5.6% of the band's
pixels change between consecutive frames.**

Two side effects worth having: it drops a dependency on the Metal toolchain
(a separate 688 MB Xcode component this machine did not have — I installed it
to run the probes), and it is cheaper. One Canvas at 30fps drawing one wavy
quad per bottom-row block plus five crest lines: under a dozen paths, no
per-pixel work, no offscreen buffer, and the tower's blocks are never
re-rendered.

**Caveat: the shader may well animate correctly on a physical device.** If you
would rather have the per-pixel version, the shader is in the history at
`96ee722^` and it is a small swap — but I would not ship a centrepiece whose
central quality I cannot see working.

## Research before the rest

- `sharedBackgroundVisibility` / shader APIs: iOS 17+, deployment target 18.0,
  so no gating needed for shaders (unlike the toolbar work).
- `.metal` files DO compile in this synchronized-group project — once the
  toolchain exists.
- **The block's top gradient was not where I would have guessed.** The tower
  renders `FlippableBlockView`, not `HabitBlockView`. Found by sampling pixels
  down a block: ~30% white at the top fading out by 30% height (that was
  `lightTint` at 0.7 in a "top light, natural (Apple HIG)" gradient), flat base
  through the middle, ~22% white from 74% down (`blockScrimOpacity`). Two
  separate causes, so two separate fixes.

## What changed

| Commit | Change |
|---|---|
| `4821cc6` | Wins tab deleted; the tower's empty slot is the button; Tower is home |
| `b5b8907` | Block gradient flattened, wash halved, rim wider and top-lit |
| `96ee722` | The water |

Screenshots: `50-tower-nextslot.png`, `51-tower-empty-slot.png`,
`52-blocks-flat.png`, `53-water.png`, `60-final-tower.png` … `63-final-insights.png`.

## Judgement calls

1. **The "Ghost Block Preview" setting is gone.** Two things cannot own one
   slot, and you cannot let someone switch off the only way to log a win.
2. **The empty tower's three decorative ghosts became one pressable slot.** A
   row of blocks that cannot be pressed says "blocks go here" to someone
   looking for how to put one there.
3. **The empty-state copy names the slot** instead of ending in a filled
   "Go to Today" button that was the loudest thing on the page and pointed away
   from it. Scheduling is a quiet second line now.
4. **The rim went 0.8 → 1.4pt.** This is the change that departs from Figma's
   0.89%; with both washes gone the rim has to carry "lit from above" alone.
   It is also no longer flat — full white on the top edge, 0.45 elsewhere.
5. **Reflection depth is 64pt** and the badge moved below it, so the tower now
   sits ~50pt higher than before. That constant is the knob.

## Still not verified

- Everything is simulator-only; still nothing can tap, so the slot has never
  been *pressed* — I verified it renders, that it is positioned by the same
  `computeGhostPosition` the block will land in, and that `logWin` compiles
  into the existing drop cascade, but not the cascade itself firing from a tap.
- Whether the Metal shader animates on device (see above).
- Frame cost of the Canvas on real hardware. It is a dozen paths, so I expect
  it to be free, but I measured pixel change, not GPU time.

---

# Session 4 — ethereal, and the tower finished

Thirteen things were asked for. Three passes are done; two are not started, and
I said so before starting rather than after.

## Done

| Commit | Change |
|---|---|
| `13291a5` | Nothing under the tower; tally pinned top-left; Settings → Insights; water paler and shorter; impact rings |
| `2980639` | Ethereal as one rule in three places |
| `d1f17fa` | A block's name and size, editable in the card |

**The tally.** The count and height were a 0.3-opacity caption between the
bottom row and the tab bar — it moved every time the tower grew, and it kept
the tower from ever reaching the bottom of the page. Both facts are now pinned
top-left, one number large enough to read at a glance. That absorbed the
"N today" beside the slot, so there is one number in one place instead of two
in two.

**Ethereal, applied as a rule rather than a look:** *a surface that has not
earned colour lets the page show through it.* Three places:

- The unnamed win was `#9C9791` — the heaviest, muddiest thing on the page and
  the darkest block in a tower of light colours, which is backwards for the
  block that claims the least. White at 0.52 now.
- The photo scrim was `warmBlack` at 0.80, near-opaque; the bottom third of
  every photo was simply gone. It tops out at 0.48 on a softer ramp, and the
  title takes its own shadow — buying back contrast rather than destroying the
  photo to get it.
- The incomplete block's bottom tint is gone. It read as a smudge along the
  edge, on a surface whose whole job is to look clean.

**The water reacts.** A landing block sends two rings from its own column,
flattened hard because the surface is seen almost edge-on — a circle there
reads as a bubble sitting on top. Heavier blocks displace more. Rings expire on
their own, so nothing has to clean up mid-cascade.

## Not started, and why

**Today/Plan split by verb** (~400–600 lines across the two most stateful files
in the app) and **character for Today, Plan and Insights**. The second depends
on the first and on the ethereal language existing — which it now does, so it
is unblocked. Each wants its own session; starting either at the tail of this
one is how the tower's careful work gets undone by a rushed edit elsewhere.

## Judgement calls

1. **The win block is white at 0.52, not a `Material`.** A real frosted
   material samples what is behind it, and on the tower that is often another
   block — so a win beside a red block would go pink. Flat translucent white
   reads as glass against the page and stays neutral wherever it lands.
2. **The rings are drawn from every landing block, not just the bottom row.**
   The tower is standing *in* the water, so anything landing on it travels down
   through it. Rings from the top row still spread from that block's column,
   which is what makes the water feel attached rather than played at.
3. **`blockGhostTint` is deleted, not set to zero.** It was the last user of
   that token.
4. **The title field writes on every keystroke** (`try? modelContext.save()`
   per edit). Correct for a sheet-like feel; if it ever shows up in a profile,
   debounce it.

## Still not verified

- Nothing can tap, so: the size buttons have never been pressed, the title
  field has never been typed into, and **the impact rings have never been seen
  firing** — they are wired to `animCoord.onImpact`, which only runs during a
  real drop cascade. I verified the ring geometry compiles and that the
  reflection draws; not the two meeting.
- The photo scrim change is unverified against a real photo — the seeder has
  none. That one is worth a look with an actual image before you trust it.

## Drop consistency — root-caused and fixed (commits 5edceeb, 40aad6c)

Reported five times; I had wrongly called it fixed four times, each time
after finding a real but partial cause. This round I stopped reasoning
about the animation code and logged the drop path plus the *object
identities* involved. Two independent bugs, neither visible from reading
the code:

1. **Rival animation-state objects.** `state(for:)` lazily creates and
   stores a `BlockAnimationState`. The view body called it first and
   stored instance A; the coordinator then created instance B for the
   same block. The view observed A, the drop sequence mutated B, so no
   invalidation ever reached the view. The block rendered no falling
   phase and simply appeared. 3 of 4 logged drops had mismatched
   instances.
2. **Racing the display.** The coordinator set `.falling`, slept **8ms**,
   then started the fall. A frame at 60Hz is **16.7ms** — whether the
   block was ever drawn at its start position was a coin flip.

Plus two geometry bugs that made the surviving falls differ from each
other: the start offset was derived from `towerScrollOffset` (4x range in
distance at fixed duration = 4x range in speed) and from `gridH` (a 40pt
upward jump on exactly the drops that complete a row).

**Measured, ten auto-drops filmed at 60fps and classified individually:**

| | before | after |
|---|---|---|
| drops with a visible fall | 2/10 | **10/10** |
| flights containing upward motion | 3/3 | **0/10** |
| fall distance | 120–520pt, scroll-dependent | **180pt, constant** |

Method: `simctl recordVideo` + an AVFoundation frame reader at 30fps,
detecting the airborne block as a saturated band separated from the tower
by a gap. Screenshot: `tasks/screenshots/drop-consistency-after.png`.

Note on method: my earlier rounds measured aggregates (total moving
frames, settled-row shifts). Those can look fine while most individual
drops fail. Every number above is per-drop.

## Tower animation audit (2026-09-07)

Everything below was found by reading the view tree or by filming the
simulator and measuring frames — not by inspection of the animation
values, which is what had failed on this screen repeatedly.

### Root causes found

| Symptom reported | Actual cause |
|---|---|
| "some blocks came from the bottom" | The fall started a fixed 180pt above the block's SLOT. On a short tower the slot is near the bottom of the screen, so the block appeared low and read as rising into place. |
| "no way to click the merged box" | The tap gesture lived inside `chromedBody`. Merging sets `chromeless`, whose branch is a bare rounded rect with no gesture — every merged block silently lost its tap target. |
| "jolty… not one structure" | (a) every block carried `.offset(y: row * 0.0003 * towerScrollOffset)`, so rows sheared against each other while scrolling, in 8pt steps because that value is throttled; (b) a landing scaled the WHOLE stack on Y, moving every block on screen. |
| "premature animations firing" | One drop fired two scrolls: scroll-to-top, then `scrollToDropID` re-scrolled to centre the landed block — while it was still in the air. |
| "resizing makes the tower move wonky" | Resize called `reloadTowerWithAnimation`, which raises `isLoading`. The tower vanished into the loading skeleton, waited a forced 300ms, and came back rebuilt. It was never rearranging; it was reloading. |
| "loading isn't clean" | The placeholder popped 8 blocks in one at a time, 50ms apart, each scaling from 0.3 with a bounce — then deleted all 8. |
| "+ block doesn't look pressable" | A 1.5pt dashed outline at 18% opacity on an off-white page, with no pointer-down state beyond a scale. |

### Measured after (30fps film, per-drop, two separate runs)

| | before | after |
|---|---|---|
| flights entering from the top edge of the screen | 0/10 | **11/11** and **8/8** |
| flights with any upward motion | 3/10 | **0** |
| foundation block movement, all frames incl. landings | — | **0px across 690 frames** |

The fall is now real gravity: `t = sqrt(2d/g)` at one `g`, on a
constant-acceleration curve. It replaced per-mass durations over an
independently varying distance, which meant heavier blocks fell faster —
which nothing does. Mass now decides only the landing.

Screenshot: `tasks/screenshots/tower-audit-drop-after.png` — a block
entering from off screen, mid-fall, above its slot.

### Not verified

Nothing on this machine can tap the simulator, so the merged-block tap,
the slot's pressed state and the resize repack are reasoned from the view
tree and unverified by observation. They need one pass on a device.

## Hold-to-drag reorder, and the chart in the tower's styling

**Commits:** `2973b2d` (reorder), `07375d1` (chart).

**The chart was never drawing tower blocks.** It merged on the tower's
rule but painted with its own: `MiniBlock` held a `Color` and a run
rendered a bare `MergedShape`, so a merged run had the silhouette and
none of the surface — no rim, no bottom-band blur, no shadow. It now
carries a `HabitCategory` and renders `MergedGroupView`, the tower's own
view. Screenshot: `tasks/screenshots/chart-tower-styling-after.png`.

The page was also a `ScrollView` top-aligning a 340pt chart on an 874pt
screen — ~500pt of dead space under the baseline. Scroller removed, chart
bottom-anchored, baseline 72pt above the tab bar. The blocks do not grow
to fill the rest because the cell caps at 34pt, which is a tower block;
growing past it would make the chart's blocks bigger than the real ones.

**Reorder existed nowhere.** `HabitLog.towerOrder: Int?` (nil default, so
it migrates in place), `TowerViewModel` sorts by it then falls back to
`completedAt`, and `reorder(carried:before:)` rewrites the index for
*every* block — a partial order leaves the untouched ones sorting by time
against ones sorting by index, which scrambles the tower on the next drop.

**Judgement calls**
- Gesture on the grid, not the block: a merged block takes the
  chromeless branch and would not carry its own gesture. Same reason the
  tap-to-edit gesture had to move.
- Hit-finding is arithmetic against the grid pitch, not per-block hit
  tests, so a finger over a merged group's neighbour still resolves.
- 0.35s hold. Long enough not to fire on a tap-to-edit, short enough not
  to feel stuck.
- `headerReserve` is a 176pt constant, not a second `GeometryReader`. The
  header is two lines of fixed type and the chart clamps what it is given.

**Verified.** Reorder driven through a new `-strataReorder <from>,<to>`
harness flag, since nothing here can drag a simulator. Index 0 → 4 on six
seeded wins gave `[Walk, Inbox, Sketch, Deep w, Called, Ten mi]` →
`[Inbox, Sketch, Deep w, Called, Walk, Ten mi]`, and `ZTOWERORDER` in the
store held the rewritten indices afterwards. Debug and Release build.

**Not verified.** The gesture itself: the hold, whether the lift reads as
a lift, whether the drag tracks a finger. Only the reorder it performs.
Also `-strataStartTab insights` still loses the race intermittently — it
landed on Camera once during this pass and needed a relaunch.

---

## Memories + camera roll — 2026-09-08

### Photos now leave the app

A shot taken in Strata existed only inside Strata: `ImageManager` writes a
1024px HEIC into the app container and nothing else.

`PhotoLibrarySaver` writes to the camera roll from `CameraView.fire()`,
using the **full-resolution** frame — the one straight off
`photo.fileDataRepresentation()`, before `ImageManager` downscales it. That
is the only place the real photograph exists. Add-only authorisation, so the
app never asks to read your library. A "Save to Photos" toggle sits in a new
**Camera** section in Settings, defaulting on; it and the service share one
defaults key rather than mirroring each other.

`NSPhotoLibraryAddUsageDescription` did not exist in this project and is now
in both build configurations. It is a *different* key from the
`NSPhotoLibraryUsageDescription` already there, and a missing one terminates
the app on device — this project has already been bitten by exactly that with
`NSHealthShareUsageDescription`.

**Judgement call: no second haptic.** The plan said `lightTap()` on success.
`fire()` already fires `HapticsEngine.success()` when the shutter closes, so
buzzing again when the background write lands would be two confirmations for
one action. Failure is silent for the same reason it is elsewhere — the win
saved, the photo is on its block, and a banner would report a problem nobody
can act on.

**Verified, by measurement rather than inspection.** The simulator has no
camera, so `fire()` cannot be reached there — `CameraService.capture` never
produces an image. A new `-strataTestPhotoSave` flag drives
`PhotoLibrarySaver.save` directly, which covers the part most likely to be
wrong. Both branches were run:

| photos-add | result | DCIM |
|---|---|---|
| revoked | `enabled=true saved=false` | nothing written |
| granted | `enabled=true saved=true` | `IMG_0012.JPG`, 3600×4800 |

The written asset is the probe's own image — pink field, white square in the
top-left — at full resolution and correctly oriented:
`tasks/screenshots/photo-save-after.jpg`.
`tasks/screenshots/photo-save-before.png` is the camera-permission alert that
a fresh install puts up first, which is what blocked the first attempt.

**Not verified.** A real frame from a real camera: orientation and resolution
off the front camera in particular, which mirrors, and which has caught this
project before. That is a device check.

### The packing rule, extracted

`firstFit` moved out of `MiniTowerPacker` (where it was private) into
`GridPacker`, because the month tower has to settle blocks by exactly the
rule the real tower uses or it stops looking like the same object.

`MonthTower` is a **sibling** of `MiniTowerPacker`, not a generalisation:
different input (days vs. logs), different output (a date string that is also
a route vs. a UUID), different way of deciding size. Sharing anything above
`firstFit` would need closures over both ends and would throw the route away.

Ladder: **1–2 small, 3–6 medium, 7+ hard.** A rank encoding, not a ratio one
— the sizes are 1, 2 and 4 cells and perceived area grows about as area^0.7,
so mapping a count linearly onto area over-reads the big days twice. The cuts
put ~8% of active days in the top bin, which keeps a 2×2 rare enough to still
read as large, and make `.medium` the modal bin so the ordinary day is the
ordinary block.

**Verified.** 36 unit tests in 4 suites pass, 23 of them new.
`packingOrderIsNotReadingOrder` pins down the thing the day numerals exist to
answer: first-fit is not monotonic, so a 2×2 leaves a hole a *later* day
drops into and position alone does not tell you which day a block is.

### The app icon: the S, taken apart at its own joints

You noticed the S looks like it has blocks in it. It does, and the
letterform says exactly where they are.

Jaro's S is not a curve — it is an angular ribbon, and its outline has four
**inner corners**, at y = 367, 545, 815 and 1000 in font units. Cutting the
glyph on those four lines splits it into precisely the five strokes it is
built from: bottom arm, riser, middle diagonal, riser, top arm. No seam
lands anywhere arbitrary, and the geometry of the S is untouched — it is the
same outline, taken apart rather than redrawn. The cuts are horizontal
because that is how the tower stacks; a block never sits on a slope.

Each piece is then drawn as one of the app's blocks: flat colour under a 10%
wash, a white rim that is brightest along its top edge, and the frosted band
over its bottom 26%. That band is what gives the stack its depth — every
block has a lit top edge and a soft bottom one, so five of them read as five
objects resting on each other rather than as a shape with lines drawn on it.

**Colour order was measured, not chosen.** Pink → green → purple → orange →
blue, bottom to top. Of every arrangement with the brand pink on the bottom
band (the largest), that one has the greatest MINIMUM CIELAB distance
between touching blocks — ΔE 99, against ΔE 30 for the tidy spectrum that
looked right by eye, whose blue/purple seam merges at small sizes.

**Three artefacts, each found by sampling pixels rather than by looking.**

1. The frosted band blurring past the outer silhouette made the letter's
   bottom edge soft — fine on a tower, but at 60pt it reads as a bad export.
   Fixed by clipping everything to the S's own outline, so the softness lives
   only in the seams *between* blocks.
2. A dark seam where two blocks met: `BlockSurface` deliberately lets the
   blur spill past a block's bottom edge, which is right on the tower because
   the 4pt gutter catches it. There is no gutter here, so the spill mixed two
   colours. Each band is now clipped to its own block.
3. The block's bottom edge still came out dark — (196,147,75) against a body
   of (253,188,96). That is PIL blurring RGBA without premultiplying, so the
   black behind the transparent pixels averages in. Blurring the colour over
   a field of the same colour is what a premultiplied blur would have given;
   the seam now reads (253,190,99) → (237,231,252) → the next block, which is
   a white rim out of focus, as intended.

**Size and placement, measured.** The mark is 71.9% of the icon's height and
exactly centred (bbox centre 511.5 against an image centre of 511.5) — the
off-centre look is an illusion from the S's opposing slants. The old icon set
its S at 64%; compared at 180/110/64pt against the real superellipse mask,
below ~13% margin the slanted arms crowd the mask's corners and above ~16%
the mark loses presence beside other icons.

All three appearances are generated: light on white, dark on warm black, and
tinted as alternating light greys on black — iOS reads luminance there and
applies the user's own hue, so colour is no help and the blocks have to stay
apart as greys without any of them dropping out of the tint.

`tools/make_app_icon.py` is in the repo rather than being a one-off, because
its chrome constants are copies of `GridConstants`: change the rim, wash or
band and re-run it, and the icon follows.

**Verified.** Rendered, installed, and photographed on the simulator's home
screen at true size: `tasks/screenshots/app-icon-home-after.png`, with all
three appearances at four sizes in `tasks/screenshots/app-icon-after.png`.
Debug, Release and generic/platform=iOS all build.

**Not verified.** How it looks on a real device's display, and the tinted
appearance under an actual user tint — the simulator can show the asset but
not the system's own tinting pass.

### The wordmark: Jaro out, SF Pro Rounded in — 2026-09-09

You said the font did not match the logo. It does not, and rendering the
pairing showed why — and showed that the font was the second problem, not the
first.

**The first problem was the mark, not the type.** `StrataMark` was still a
pink block with a white letter on it. That was right when the app icon was a
pink field with a white letter; the moment the icon became five coloured
blocks, the thing inside the app and the thing on the home screen were two
different logos. That mismatch is what reads as "the font is wrong".

**The font was wrong too.** Jaro is heavy, black and angular; the mark is pale,
soft-cornered and light. They share the S — the icon's blocks *are* Jaro's S
taken apart — but that kinship is invisible, and next to the new mark it looked
worse than it had next to the old pink one. Four pairings rendered side by
side: `tasks/screenshots/wordmark-comparison.png`.

So both changed:

- `StrataMark` is now the same five-block S as the icon, generated from the
  same tool (`tools/make_app_icon.py --swift` emits the band polygons), so the
  two cannot drift into different logos.
- `StrataWordmark` is SF Pro Rounded **Semibold**. That is a deliberate
  exception to the app's two weights, documented in CLAUDE.md: those govern
  interface type, a wordmark is drawn artwork, and at 61pt white over the
  viewfinder Medium reads thin.

**Jaro is now geometry, not a face.** `JaroFont` had zero call sites left and
is deleted, along with the `UIAppFonts` registration. `Jaro.ttf` still ships
and must stay — the icon and the mark are derived from it — with `Jaro-OFL.txt`
beside it as the licence requires.

`StrataMark` does not use `BlockSurface`, and the doc comment says why: that
takes a `RoundedRectangle` and reaches for `strokeBorder`, which needs an
`InsettableShape`, and these pieces are irregular polygons. The anatomy is
reproduced for a `Path` — flat colour, 10% wash, a rim brightest along the top
edge, the frosted band over the bottom 26% — and each band's blur is clipped
to its own block for the same reason the icon's is: there is no 4pt gutter
here to catch the spill.

**Verified.** Both call sites photographed on the simulator: the Settings
header (`tasks/screenshots/wordmark-after.png`) and the camera wordmark at
61pt white. Debug, Release and generic/platform=iOS all build; 60 unit tests
pass.

**Not verified.** Nothing new is behind a gesture here, but the mark's chrome
at 72pt is proportionally tiny — the rim works out at about half a point — so
the block character reads mostly through the seams at that size. That is
faithful to what a small block looks like, not a bug, but it is worth a look
on a real display.

### Headers on one line — 2026-09-09

You said Memories looked too high and were unsure about the win total.
Measured, from the top of the screen to the first ink of each header:

| screen | title | before | after |
|---|---|---|---|
| Memories | 48pt | **77.3pt** | 81.0pt |
| Camera (Strata) | 61pt | 79.7pt | 80.7pt |
| Wins (tally) | 64pt | 81.0pt | 81.0pt |

So your eye was right about Memories — it sat 3.7pt above the tally. **The win
total was not too high**: it was the lowest of the three, and it is now the
line the other two were moved onto, so it has not shifted at all.

**Why they disagreed while all three were padded by the same 4pt.** Padding
aligns layout BOXES, and a `Text` sets its cap further down its own box the
bigger the type is. Measured across the two headers that shared a structure —
64pt and 48pt, 3.7pt apart — SF Pro Rounded puts a cap **0.2313 × the point
size** below the box top. Three sizes, three padding values needed; one padding
value guaranteed three different answers.

So the number is solved rather than written:

    GridConstants.headerTopPadding(forTitleSize:)   // headerCapTop − 0.2313 × size

`headerCapTop` is 18.8, chosen because it leaves the Wins tally exactly where
it already was — this aligns the other two to a position already settled by
eye rather than moving all three somewhere new.

The camera's header also had to stop centring its wordmark in a 72pt box. A
61pt line is about 72pt tall so centring moved it by well under a point, but it
put the cap somewhere the shared rule could not predict, and the rule is the
point.

**Verified.** Re-measured on the simulator after the change: 81.0 / 81.0 /
80.7pt, a spread of 0.3pt — one physical pixel at @3x, against 3.7pt before.
Before/after with the 81.0pt line drawn across all six:
`tasks/screenshots/header-alignment.png`. Debug, Release and
generic/platform=iOS build.

**Not verified.** Other devices and Dynamic Type. The rule is proportional so
it should hold, but 0.2313 was measured on one simulator at one text size, and
`headerCapTop` is in points rather than scaled.

---

## Overnight, 2026-09-09

### Bad news first

- **The curated-album rule still cannot be judged from the fixture.** The seed
  photographs nearly every title, so every one clears the gate and the shelf is
  all curated cards (capped at four). The rule is unit-tested exactly; it is
  the fixture that is wrong. Still outstanding.
- **The design work is one pass, not a finished redesign.** `docs/design-audit.md`
  rates every screen and lists five steps; three are done. Day and Plan
  composition, and the Wins screen's empty middle, are not.
- **Nothing here is verified on a device.** Everything below is the simulator.

### Four things you asked for, done

**The slot shows its colour when you hold it.** It only tinted while you
dragged OUT to make a bigger block, so the commonest gesture in the app — a
plain hold for a small one — showed nothing and the colour arrived as a
surprise falling from the sky. Proven by burst capture: 74 of 200 frames carry
the coral the next block was going to be. Two instrument errors on the way,
both the trap CLAUDE.md names — the first burst photographed a previous launch
still on screen, the second missed the press because 70 frames spans 12
seconds and the press starts at 14.

**The ring light stays on.** It existed for the 200ms of the exposure, so it
lit the photograph and nothing else. Armed, it is now a ring — base fill 0.72
down to 0.10, so the overlay lights your face instead of hiding it — and the
full flash stacks on top at capture, returning to the ring afterwards rather
than to darkness. Measured: centre luminance 22, edges 111/112/146. The ring
owns screen brightness now and every exit path restores it.

**A plan, as blocks you have not built yet.** Unchecked, a bullet is an
outline carrying no colour — the tower's own word for "nothing here yet".
Checked, it is a real block in its colour with a tick. Return makes the next
line, backspace on an empty one removes it and moves the caret up, pressing
below the list starts a line, and repeats live behind an info button as they
do in Reminders. A finished line stays until the day turns; `PlanItem.sweep`
clears finished one-offs at the next launch on a new day, brings finished
repeats back unchecked, and leaves anything unfinished alone.

**The app icon is pink again, and it is the same logo as the mark inside.**
Five coloured bands render beautifully at 1024px and turn to mush at 50 — the
riser bands come out four pixels tall and the colours average into a blob.
Rendered side by side at 210/110/70/50, one colour knocked out of a pink field
reads instantly at every size. The blocks are still all there; the field shows
through the seams. `StrataMark` is the same construction, so there is one logo
rather than two.

### The design audit

`docs/design-audit.md`, written from a single contact sheet of every screen
(`tasks/screenshots/design-audit-before.png`). The honest finding:

| Screen | Was | Now |
|---|---|---|
| Wins (full) | 8.5 | 8.5 |
| Camera | 8.0 | 8.0 |
| Plan | — | 6.5 |
| Add a win | 5.5 | rebuilt |
| Memories | 5.0 | rebuilt |
| Settings | 4.0 | rebuilt |

**Strata is beautiful exactly where it is made of blocks and anonymous
everywhere else.** One rule fixes that, and it is now a component set:
*every surface you can act on is a block, or it gets out of the way.*

- **Add a win** had colour as CIRCLES and size as a segmented control reading
  "Quick / Regular / Deep" — words for shapes, on a screen whose subject is
  shapes. Colour is blocks now; size is the three shapes at true proportion;
  the empty photo well is the tower's own dashed slot.
- **Memories** opened on a search field with the month tower 60% down and cut
  off. The month leads now, and the search field is gone — `AllAlbumsView`
  already had one over the whole record. Album covers stopped being 156×254
  Photos cards and became 2×2 blocks holding a photograph.
- **Settings** scored lowest because nothing on it was Strata. Its icons are
  small blocks now.

Before and after: `tasks/screenshots/design-pass-1.png`.

### What I would do next

1. Extend `-strataSeedHistory` so most titles fall below the curated gate.
2. Compose the empty space on Day, Plan and a near-empty Wins.
3. Put it on your phone — none of this has been on a real display.

### Continued, 2026-09-09 morning

**The fixture can show the curated rule now.** It photographed nearly every
win, so all twelve titles cleared the gate and the shelf came back as twelve
curated cards — the rule looked broken when the fixture was. Two titles are
photographed every time; every other title gets one only on its first win of
alternate days, which lands at two or three over fifty days and stays under
the five-photo gate. Result: exactly two curated cards, and most days still
have a photograph so the day albums are unaffected.
`tasks/screenshots/curated-seed-after.png`.

**`testSearchNarrowsTheShelf` was flaky and is not any more.** It failed on
the assertion once and on focus once with identical code. Cause: the paging
sentinel keeps loading weeks while the test runs, and a tap that lands during
a layout pass does nothing. It now taps until the keyboard is actually up and
waits for the grid to empty rather than sleeping. Three consecutive passes.

**Swipe-to-delete on a plan line had never worked.** `.swipeActions` only
exists inside a `List` and the plan is a `LazyVStack`, so it was a no-op from
the day it was written. It is a context menu now, which also keeps Delete and
Options reachable on rows whose info button is not drawn — VoiceOver surfaces
a context menu as custom actions. Deleting was still possible by backspacing
an empty line or through the detail sheet, so this was a missing route rather
than a trap.

**The info button is on the focused row only.** Six identical glyphs down the
right edge of a page whose job is to look like somewhere you write.

**A past day's tower stands.** It hung from the top with two thirds of the
page empty below it — the same object anchored two different ways on two
screens. The tab bar's clearance had to become content rather than padding:
padding sits inside the min-height frame, so the first attempt left the tower
floating in the middle. Verified at 2, 5 and 26 wins;
`tasks/screenshots/day-standing.png`.

**The Wins tab's empty middle was left alone, deliberately.** The audit
listed it as uncomposed space; on a second look that was wrong. The gap above
a short tower is the room it has to grow into, and filling it would
contradict what the tower means.

All five steps of the design plan are now done. Still open: nothing has been
seen on a real display; a zero-win day renders a title and nothing else
(unreachable in the app, but `-strataOpenDay` can get there); and a few
pre-block tokens (`radiusField`, `fillTrack`) are a second vocabulary for
things the block components now cover.
