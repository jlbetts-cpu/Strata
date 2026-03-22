# Strata — Multi-Bot Coordination

## Task Files

| File | Purpose | When to read | When to write |
|------|---------|-------------|---------------|
| `tasks/active.md` | In-progress + next up | **Start of every session** | When starting/finishing work |
| `tasks/history.md` | Completed work (Added/Changed/Fixed/Removed) | Only when curious about past decisions | When you finish a task — move it here |
| `tasks/coordination.md` | Bot assignments, shared file rules | **Before modifying shared files** | Rarely — only when ownership changes |
| `tasks/backlog.md` | Future ideas, tech debt | During planning sessions | When you discover future work |

## Bot Assignments

| Bot | Screen | Scope |
|-----|--------|-------|
| **Tower Claude** | Tower tab | TowerView, HabitBlockView, FlippableBlockView, TowerViewModel, TowerAnimationCoordinator, TowerManager, BlockDetailSheet |
| **Timeline Claude** | Today tab | ScheduleTimelineView, TimelineHabitRow, WeekProgressStrip, TimelineViewModel, DailyStoryCarousel, CompletedHabitRow |
| **Add Task Claude** | Add/manage flow | PlanPageView, PlanPageViewModel, PlanItemRow, AllItemsView, HabitEditView, MiniBlockPreview, CategorySuggestionEngine |

## Shared Files — Ownership & Rules

These files are touched by multiple bots. **Check this file before modifying shared files.**

| File | Primary Owner | Other Users | Rule |
|------|--------------|-------------|------|
| `MainAppView.swift` | Tower Claude | Timeline, Add Task | Now wrapped in NavigationStack (Add Task Claude). "+" pushes PlanPageView via `.navigationDestination`. Coordinate before editing. |
| `GridConstants.swift` | Shared | All | Additive changes only. Don't modify existing constants. |
| `CategoryColors.swift` | Shared | All | Read-only. Don't change colors or styles. |
| `Typography.swift` | Shared | All | Read-only. Don't change font definitions. |
| `Habit.swift` | Shared | All | No schema changes without coordination. |
| `HabitLog.swift` | Shared | All | No schema changes without coordination. |
| `HapticsEngine.swift` | Shared | All | Additive only. |
| `WarmBackground.swift` | Timeline Claude | Tower | Being extracted from MainAppView. Same API. |
| `BlockTimeFormatter` (in HabitBlockView.swift) | Tower Claude | Timeline | Timeline will use, not modify. |
| `NewHabitMenu.swift` | Add Task Claude | Timeline | Timeline calls via `onAddHabit` closure. If interface changes, update Timeline. |
| ~~`FloatingBottomBar.swift`~~ | DELETED | — | Replaced by native TabView. |

## Active Work

### Timeline Claude
- **Completed:** Full overhaul — architecture extraction, full-color Structured-style blocks, glazing animation, layout fixes, week progress strip, hour grid with sections, empty states
- **Current:** No active work

### Tower Claude
- **Completed:** Native TabView migration, MainAppView type-checker fix
- **Current:** No active work

### Add Task Claude (current)
- **Completed:** Notes-style PlanPageView (navigation push from +), AllItemsView polish, block time text simplification
- **Architecture change:** "+" button now pushes PlanPageView via NavigationStack (was sheet). Added `showPlanPage` state + `.navigationDestination` to MainAppView.
- **Model changes:** Added `parentHabitID`, `sortOrder` to Habit.swift. Added `miniBlockTitle`/`miniBlockIcon` to Typography.swift.

## Cross-Cutting Concerns

1. **Completion pipeline:** Timeline's `onComplete` → MainAppView's `pendingDrops` → Tower's `cascadeDropPendingBlocks`. Don't change this interface.
2. **Tab switching:** `selectedTab` in MainAppView drives which tab renders. Don't change the enum.
3. **refreshData():** Called by both timeline (after complete/skip) and tower (after filter change). Don't change signature.
4. **Image pipeline:** `ImageManager`, `CachedImageView`, `ImageMigrationRunner` — shared infrastructure. Don't modify without coordination.
