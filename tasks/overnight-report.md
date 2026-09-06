# Overnight report — 2026-09-06 → 09-07

Status: IN PROGRESS. Written as I go.

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

1. **The tier badge icon is a tofu box.** `TowerTier.icon` returns emoji
   ("🌱"), which does not render in this runtime — see the enlarged crop. It is
   also drawn at full opacity next to text at 0.2, so the one broken glyph is
   the loudest thing on the screen. Emoji also contradicts CLAUDE.md's "SF
   Symbols only".
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

