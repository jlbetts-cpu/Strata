# Should Today and Plan be one tab?

Research only. **No app code was changed for this document.** Written
2026-09-07 against `1879ed6`, from reading the source and from screenshots
taken on an iPhone 17 Pro simulator with the same build.

Screenshots referenced:
`tasks/screenshots/03-today-before.png`, `12-today-ghostchips-after.png`,
`04-plan-before.png`, `13-plan-after.png`, `15-addsheet-after.png`.

---

## 1. What each tab owns today

### Today

| | |
|---|---|
| View | `Strata/Views/ScheduleTimelineView.swift` (1,234 lines) |
| Rows | `Strata/Views/TimelineHabitRow.swift`, `TimelineGridView.swift` |
| View model | `Strata/ViewModels/TimelineViewModel.swift` (183 lines) |
| Hosted by | `MainAppView.timelineTabContent` (`MainAppView.swift:643`) |
| Persisted UI state | `@AppStorage("todayViewMode")` (list vs grid) |

Owns, and owns alone:

- **One day at a time.** `selectedDate` is a binding; the week strip changes it.
  Nothing else in the app is date-scoped this way.
- **Position in the day.** The now-line, "NEXT", `cachedNextUpID`, the
  hour grid, `calendarEvents` from EventKit drawn as ghost anchors.
- **Completion.** `onComplete` / `onSkip` / `onUndo` / `onUndoSkip`. Every path
  that turns a habit into a block runs through here or through Wins.
- **Verification.** `healthKitProgress`, `verifiedHabitIDs`.
- **Time assignment by direct manipulation** — drag a chip onto an hour, and
  `habit.scheduledTime` is written at `ScheduleTimelineView.swift:938` and
  `:1170`.

### Plan

| | |
|---|---|
| View | `Strata/Views/PlanPageView.swift` (1,065 lines) |
| Rows | `Strata/Views/PlanItemRow.swift` (922 lines) |
| View model | `Strata/ViewModels/PlanPageViewModel.swift` (580 lines) |
| Model | `Strata/Models/PlanFolder.swift` |
| Persisted UI state | `savedSortMode`, `sectionExpandedData`, `viewMode` |

Owns, and owns alone:

- **The whole corpus, undated.** Every habit regardless of when it runs.
- **Routines vs To-Dos** — the `PlanViewMode` split.
- **Folders.** `PlanFolder`, `SectionEditSheet`, drag-to-folder.
- **Inline capture.** `commitNewItem` / `commitInContext`
  (`PlanPageViewModel.swift:282`, `:315`) — a second habit-creation path that
  does not go through the add sheet at all.
- **Full editing.** `PlanItemRow`'s expanded card is the only place a habit's
  title, category, frequency, duration, subtasks and time can all be changed.
- **Buckets.** Today / Tomorrow / Next 7 Days / Inbox / In Progress / Saved,
  built by `groupedSections` (`PlanPageViewModel.swift:89`).

---

## 2. What actually overlaps

Less than the framing suggests, but the part that does overlap is the sharp
part.

**A. Two places assign `scheduledTime` to the same habit.**

- Today's Sandbox: tap a chip → `habitToSchedule` → `suggestOpenSlot(for:)`
  (`ScheduleTimelineView.swift:987`) proposes the next free slot, confirmed in a
  dialog → `habit.scheduledTime = suggestedTime` (`:308`). Or drag the chip onto
  an hour and it is written directly.
- Plan: open an item's expanded card → the "Time Hero" zone
  (`PlanItemRow.swift:252`) → time picker → same field.

Same field, same habit, two different interaction models, neither aware of the
other. **This is the real duplication.**

**B. Two places decide *which days* a habit runs.**

- Plan, by which bucket you drop it in: `defaultsForSection`
  (`PlanPageViewModel.swift:355`) maps "today" → `[DayCode.today()]`,
  "tomorrow" → tomorrow's weekday, "inbox" → every day.
- The add sheet's Schedule row, explicitly.

`applyFrequencyPreset` (`:396`) is a third spelling of the same idea.

**C. Two habit-creation paths.** `NewHabitMenu` (from the Tower, Today and
Insights toolbars) and `PlanPageViewModel.commitNewItem` (Plan's inline field).
Wins is a third, but that one is deliberate and separate.

**D. Both render an incomplete habit, differently.** Today uses
`TimelineHabitRow`; Plan uses `PlanItemRow`. Since tonight both go through
`BlockGhostSurface`, they finally agree on the *surface* — but not on the row.

### What does NOT overlap

Worth being precise, because it is what makes a straight merge expensive:

- Today is date-scoped; Plan is not. Plan's "Today" bucket is a **filter over
  all habits**, not the same object as Today's `selectedDate == today`.
- Plan owns folders and the Routines/To-Dos split. Today has no concept of
  either.
- Today owns completion and HealthKit verification. Plan has
  `completeForToday` (`PlanPageViewModel.swift:236`), but it is a shortcut, not
  the main path.
- Plan is the only full editor.

---

## 3. Three options

### Option 1 — Leave the tabs, delete one of the two scheduling routes

Today's Sandbox keeps drag-to-schedule (its native gesture). Plan's expanded
card loses its time picker and instead deep-links into Today at that habit.
The Sandbox becomes the single place a time is assigned.

- **Size:** small. ~150–250 lines. Delete the Time Hero zone from
  `PlanItemRow`, add a "Schedule…" row that calls the existing
  `switchTab` environment action plus `deepLinkHabitID`, which already exists
  and already works (`MainAppView.swift:440`).
- **Fixes:** the actual duplication (A).
- **Does not fix:** two tabs that feel unrelated; two creation paths; two row
  components.
- **Risk:** low. Nothing moves; one route is removed.
- **Cost:** Plan's expanded card is a good editor and this makes it less
  complete. Someone triaging fifteen items in Plan now bounces to Today
  fifteen times.

### Option 2 — One "Plan" tab with a date scope, Today becomes a mode of it

Merge into a single tab whose top control is a scope: **Today · Week ·
Everything**. "Today" renders the timeline; "Everything" renders the current
Plan buckets and folders. The Sandbox and Plan's Inbox become the same list
viewed at two scopes.

- **Size:** large. Realistically 900–1,400 lines touched. `PlanPageView` and
  `ScheduleTimelineView` both become children of a new container; the two view
  models either merge or a coordinator owns `selectedDate` and hands it to
  both; `TimelineHabitRow` and `PlanItemRow` should converge or the merge buys
  nothing visually.
- **Fixes:** everything in §2, and answers "the tabs should feel connected"
  literally.
- **Risk:** high, and the risk is concentrated in the two files with the most
  state in the app. `ScheduleTimelineView` alone holds ~15 `@State`
  properties plus three debounced recompute tasks; `PlanPageView` holds sort
  mode, expansion state, drop targeting and folder editing. Merging their
  lifecycles is where this goes wrong.
- **Cost:** a four-tab app (Wins · Tower · Plan · Insights) is arguably better
  than five. But the scope control is a mode switch, and mode switches are the
  thing Plan's Routines/To-Dos toggle already does — you would then have two
  mode switches stacked.

### Option 3 — Keep both tabs, make Plan the editor and Today the day

Draw the line by **verb, not by data**. Today = do (complete, skip, verify,
place in the day). Plan = decide (create, categorise, set frequency, file,
delete). Explicitly:

- Today's Sandbox stops being a scheduling surface and becomes only "these are
  today's habits with no time yet" — drag onto an hour stays, because that is
  placing within the day you are looking at.
- Plan keeps and *grows* the expanded card: it becomes the only place
  frequency, category and duration are edited, and the only creation path
  (`NewHabitMenu` opens into Plan's context rather than floating on three
  toolbars).
- Today gains one affordance: "Edit in Plan", which already exists as
  `onEditInPlan` (`ScheduleTimelineView.swift:19`) and is currently optional
  and under-used.

- **Size:** medium. ~400–600 lines. Mostly deletion in `ScheduleTimelineView`
  (the confirmation dialog, `suggestOpenSlot`, `habitToSchedule`) plus wiring
  `onEditInPlan` everywhere.
- **Fixes:** A, B and C — one place decides, one place does.
- **Does not fix:** the five-tab count, or "the tabs feel unrelated" as a
  purely visual complaint. Though that complaint may be about the *surfaces*
  rather than the structure, and tonight's `BlockGhostSurface` and
  `SurfaceCard` work addresses that directly.
- **Risk:** medium-low. Deletions concentrated, additions use an existing hook.

---

## 4. What I would pick

**Option 3**, and I would take Option 1 first as its first commit.

The reason: the complaint that generated this question is "there are two places
to schedule the same habit". That is a *duplication* problem, and Option 2 is a
*structure* answer to it. Merging the tabs would remove the duplication as a
side effect of a much larger change, and would leave you holding a merged
container built out of the two most stateful files in the codebase.

Option 3 fixes the same thing by naming what each tab is for. It also matches
how the app already talks about itself: Wins is "I did this", Tower is "what I
built", so Today being "what I do now" and Plan being "what I have decided"
is the same grammar continued, not a new idea.

And the honest read of the screenshots is that Today and Plan look unrelated
mostly because they *looked* unrelated — different card grounds, different
greys, a stray white band. `04-plan-before.png` next to `03-today-before.png`
is two design systems. `13-plan-after.png` next to `12-today-ghostchips-after.png`
is much closer to one. Before spending a thousand lines on structure, it is
worth seeing whether the surface work already bought most of the feeling you
were after.

**One caveat I cannot resolve without you:** if the goal is genuinely "four
tabs, not five" — a product decision about the shape of the app rather than
about duplication — then Option 3 does not deliver it and Option 2 is the only
honest answer. Nothing in the code tells me which of those two goals is the
real one.

---

## 5. What would break

Shared by all three options:

- **`deepLinkHabitID`.** `MainAppView.swift:440` switches to `.today` and sets
  the habit. Options 1 and 3 change what that should land on. The Siri intent
  `OpenHabitIntent` uses it, so the intent has to be re-pointed too.
- **`StrataTab`.** Removing a case (Option 2) invalidates
  `-strataStartTab`, the `switchTab` environment action's call sites, and any
  persisted tab selection.
- **`onEditInPlan`** is optional (`var onEditInPlan: ((Habit) -> Void)? = nil`).
  Making it load-bearing means it can no longer be nil, which touches every
  construction site of `ScheduleTimelineView`.

Option 2 additionally:

- `@AppStorage("todayViewMode")`, `savedSortMode` and `sectionExpandedData` are
  three independent persisted UI states that would need reconciling into one.
- `ScheduleTimelineView`'s debounced `recomputeTask` and `PlanPageView`'s
  `scheduleRebuild` are two separate debounce schemes over the same
  `@Query`. Running both inside one container is a real chance of a refresh
  loop.
- The tower's badge (`pendingDrops.count`) hangs off the Tower tab; tab
  renumbering does not break it, but it is worth checking.

Option 3 additionally:

- Removing `suggestOpenSlot` removes the "find me a free slot" behaviour
  entirely. It is genuinely useful and has no equivalent in Plan. If you take
  Option 3, that logic should move to Plan's Time Hero rather than be deleted.

---

## 6. Size summary

| | Lines touched | Files | Risk | Fixes the duplication |
|---|---|---|---|---|
| 1 — delete one route | 150–250 | 2 | Low | Yes |
| 2 — merge into one tab | 900–1,400 | 6+ | High | Yes, incidentally |
| 3 — split by verb | 400–600 | 4 | Medium-low | Yes |

---

## 7. Two things I noticed while reading, which are bugs rather than structure

1. **Wins leak into Today's Unscheduled section.** Seeding 7 wins and 4 habits
   gives "UNSCHEDULED 7 habits" and "7 of 11 done" — see
   `03-today-before.png`. A win is `isTodo` + no weekdays + already complete;
   it has nothing to schedule. `QuickWinService.isWin(_:)` already exists as the
   predicate, and `ScheduleTimelineView.swift:92` (`.filter { $0.scheduledTime == nil }`)
   is where it should be applied. This is independent of which option you pick
   and is worth fixing either way.
2. **`suggestOpenSlot` and `findNextOpenSlot` are the same algorithm twice** —
   `ScheduleTimelineView.swift:987` and `PlanPageViewModel.swift:447`. Whichever
   option wins, one of them should go.
