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
