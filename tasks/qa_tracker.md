# Strata — QA Tracker (Plan Screen)

> Audited by: Add Task Claude | Domain: UI/Perf | Date: 2026-03-22

## Issues

| # | Severity | Domain | File | Line(s) | Issue | Proposed Fix |
|---|----------|--------|------|---------|-------|-------------|
| 1 | CRITICAL | Race | PlanPageView | 158-167 | `justCreatedID` pulse: rapid Return creates concurrent Task.sleep chains that overlap, causing animation flicker | Store Task in `@State var pulseTask`, cancel previous before creating new |
| 2 | HIGH | Perf | PlanPageView | 38 | `groupedSections(from:)` called in body — O(n²) filters/sorts on every render | Memoize in ViewModel; recompute only on allHabits count change or sortMode change |
| 3 | HIGH | Perf | PlanPageViewModel | 36-46 | `suggestedCategory`/`effectiveCategory`/`suggestedColor` recompute on every keystroke render | Cache in @State, update via onChange(of: newItemText) |
| 4 | HIGH | Race | PlanPageView | 202-208 | Rapid expand/collapse taps fire overlapping scroll animations + haptics | Add 100ms debounce guard on expand toggle |
| 5 | HIGH | Perf | PlanPageView | 8 | `@Query var allHabits` refires on ANY Habit property change, triggering full list rebuild | Accept as SwiftData limitation; mitigate via #2 memoization |
| 6 | HIGH | UI | PlanItemRow | 108-162 | Expanded options: 8-10 depth levels, 51+ views per expanded row (6 categories + 3 pills + 7 days + DatePicker) | Extract categoryPicker/dayPicker/effortPicker to separate View structs |
| 7 | MEDIUM | Perf | PlanItemRow | 268-290 | DatePicker Binding.get parses time string on every render frame | Cache parsed Date in @State, update via onChange(of: scheduledTime) |
| 8 | MEDIUM | Perf | PlanPageView | 152-155 | Every keystroke triggers full body re-render + 3 category suggestion scans | Debounce suggestion engine to 200ms after last keystroke |
| 9 | MEDIUM | Race | PlanPageView | Multiple | HapticsEngine calls not debounced — rapid taps queue 4+ haptics in <100ms | Add minimum 50ms interval guard in HapticsEngine (shared file — coordinate) |
| 10 | MEDIUM | Perf | PlanPageViewModel | 5-9 | PlanItem lacks Equatable — ForEach recreates row views even when data unchanged | Add Equatable conformance comparing id + indentLevel |
| 11 | LOW | Perf | MiniBlockPreview | 17-88 | GeometryReader + double .frame() forces 3x layout passes for empty state previews | Remove outer frame(maxWidth/maxHeight) — redundant after inner frame |
| 12 | LOW | UI | PlanPageView | 331-336 | Section expansion state not persisted — resets to all-expanded on app relaunch | Persist collapsed section IDs to @AppStorage |
| 13 | LOW | UI | PlanPageView | 248-254 | SwipeActions on every row adds gesture recognizers (20+ simultaneously) | Acceptable — monitor if scroll lag appears |

---

## Today Screen Issues [Domain: Logic/Data]

> Audited by: Timeline Claude | Date: 2026-03-22

| # | Severity | Domain | File | Line(s) | Issue | Proposed Fix |
|---|----------|--------|------|---------|-------|-------------|
| T1 | CRASH | Array | WeekProgressStrip | 58-59 | `isStreakStart` accesses `weekData[index]` without bounds check. If `index >= weekData.count`, fatal crash. | Add `guard index < weekData.count else { return false }` |
| T2 | CRASH | Array | WeekProgressStrip | 64-69 | `isStreakEnd` checks `index < weekData.count - 1` but if `weekData.isEmpty`, `.count - 1` underflows. `weekData[index]` at line 67 accessed before guard protects it. | Add `guard !weekData.isEmpty, index < weekData.count` at top |
| T3 | CRASH | Parse | TimelineViewModel | 135 | `effectiveHour` does `parts[0]` after `timeStr.split(":")` without checking `parts.isEmpty`. Empty string or ":" crashes. | Add `guard !parts.isEmpty` before `parts[0]` access |
| T4 | CRASH | Concurrency | TimelineHabitRow | 299-320 | `Task { @MainActor in }` with `Task.sleep` — no cancellation. If view teardown occurs mid-sleep, `onComplete(habit)` fires on dead view. Drift reward sleep (lines 312-316) compounds this. | Store Task in `@State var completionTask: Task<Void, Never>?`, cancel in `.onDisappear` |
| T5 | HIGH | Race | TimelineHabitRow | 210-220 | `DispatchQueue.main.asyncAfter` closures mutate `@State` (`isSwiped`, `beginCompletion()`) without cancellation. If view disappears before deadline, state mutates on deallocated view. | Replace with `Task { try? await Task.sleep; ... }` and store for cancellation |
| T6 | HIGH | Data | ScheduleTimelineView | 383-390 | `habitToSchedule` captures Habit reference. If habit is deleted from SwiftData before user confirms dialog, accessing `habit.scheduledTime` on deleted object crashes. | Check `modelContext.registeredObjects` contains habit before accessing, or use habit ID lookup |
| T7 | HIGH | Data | TimelineHabitRow | 47-61 | `onChange(of: isAlreadyCompleted)` can conflict with gesture handler mutations. If parent toggles `isAlreadyCompleted` during active swipe, state becomes inconsistent. | Add `guard state != .filling` check inside onChange |
| T8 | HIGH | Perf | TimelineViewModel | 68, 93, 116 | `context.fetch(descriptor)` called synchronously on main thread in `completeHabit`, `skipHabit`, `undoCompletion`. With large datasets, freezes UI. | Move to `Task { @MainActor in }` or use `@ModelActor` for background context |
| T9 | MEDIUM | Perf | ScheduleTimelineView | 32-43 | `scheduledHabits` and `unscheduledHabits` computed properties filter+sort on every render. Not cached. | Cache in `@State`, recompute in `onChange(of: allHabits)` |
| T10 | MEDIUM | Data | ScheduleTimelineView | 21-24 | `showScheduleSuggestion`, `suggestedTime`, `habitToSchedule` persist across date changes. Old suggestion could show for wrong date. | Reset these in `onChange(of: selectedDate)` |
| T11 | MEDIUM | Identity | DayProgressData | 4 | `let id = UUID()` creates new ID every time struct is initialized. When parent recomputes weekData, all 7 DayProgressData get new IDs, breaking ForEach identity and causing unnecessary view recreations. | Use stable ID: `"\(dayNumber)-\(dayLabel)"` or hash of date |
| T12 | MEDIUM | Layout | TimelineHabitRow | 70-174 | GeometryReader wraps entire block content but only uses `geo.size.width` at line 103 for fill mask. Causes unnecessary layout passes. | Use `.frame(maxWidth: .infinity)` + `containerRelativeFrame` or pass width from parent |

## Status

### Plan Screen (Add Task Claude)
- [x] **#1 CRITICAL:** Pulse race condition — added `pulseTask` with cancel + isCancelled guards
- [x] **#4 HIGH:** Expand/collapse debounce — added 100ms `lastExpandTime` guard
- [x] **#10 MEDIUM:** PlanItem Equatable — added conformance with id + indentLevel comparison
- [x] **#2 HIGH:** Memoize groupedSections — moved to @State cachedSections, recompute only on allHabits.count or sortMode change
- [x] **#3 HIGH:** Cache category suggestion — debounced 200ms via Task, cachedCategory in ViewModel
- [x] **#2b:** Pre-computed schedule strings in PlanItem (eliminates per-row per-render date parsing)
- [ ] #5 HIGH: @Query refire (SwiftData limitation — mitigated by #2 when implemented)
- [ ] #6 HIGH: View hierarchy depth (extract subviews — lower priority, no visible lag yet)
- [ ] #7-#12: Remaining MEDIUM/LOW items

### Today Screen (Timeline Claude)
- [x] **T1 CRASH:** WeekProgressStrip bounds — added `index < weekData.count` guard
- [x] **T2 CRASH:** WeekProgressStrip empty array — added `!weekData.isEmpty` guard
- [x] **T3 CRASH:** TimelineViewModel string split — added `!parts.isEmpty` guard
- [x] **T4 CRASH:** Task.sleep cancellation — stored in `@State completionTask`, cancel in `.onDisappear`, `Task.isCancelled` guards
- [x] **T5 HIGH:** DispatchQueue races — replaced with cancellable `Task { @MainActor in }`
- [x] **T6 HIGH:** habitToSchedule deleted object — added `!habit.isDeleted` guard
- [x] **T7 HIGH:** onChange vs gesture conflict — added `state != .filling` guard
- [x] **T10 MEDIUM:** Stale suggestion on date change — reset state in `onChange(of: selectedDate)`
- [ ] T8 HIGH: SwiftData fetch on main thread (deferred — requires ModelActor refactor)
- [ ] T9 MEDIUM: Computed property caching (deferred — optimization)
- [ ] T11 MEDIUM: DayProgressData UUID identity (deferred — needs MainAppView coordination)
- [ ] T12 MEDIUM: GeometryReader optimization (deferred — low priority)

### Build Note
- XPEngine.swift, GamificationViewModel.swift, LevelUpOverlay.swift, XPBarView.swift — missing files causing build errors. Tower Claude's domain (deleted during brand sync but Xcode project still references them). Need Xcode project file cleanup.
