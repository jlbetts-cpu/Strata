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
| **Architect Claude** (promoted from Timeline Claude) | Today tab + Insights tab + App Architecture | ScheduleTimelineView, TimelineHabitRow, WeekProgressStrip, TimelineViewModel, InsightsView, HabitDetailSheet, WelcomeView, OnboardingState. Also: cross-screen audits, performance, competitive analysis, brand documentation. |
| **Add Task Claude** | Plan tab | PlanPageView, PlanPageViewModel, PlanItemRow, MiniBlockPreview, CategorySuggestionEngine, SectionEditSheet |

## Shared Files — Ownership & Rules

These files are touched by multiple bots. **Check this file before modifying shared files.**

| File | Primary Owner | Other Users | Rule |
|------|--------------|-------------|------|
| `MainAppView.swift` | Tower Claude | Architect, Add Task | Plan is now a dedicated tab (not a push destination). Gear icon on Tower tab opens settings sheet. Coordinate before editing. |
| `GridConstants.swift` | Shared | All | Additive changes only. Don't modify existing constants. |
| `CategoryColors.swift` | Shared | All | Read-only. Don't change colors or styles. |
| `Typography.swift` | Shared | All | Read-only. Don't change font definitions. |
| `Habit.swift` | Shared | All | No schema changes without coordination. |
| `HabitLog.swift` | Shared | All | No schema changes without coordination. |
| `HapticsEngine.swift` | Shared | All | Additive only. |
| `WarmBackground.swift` | Architect Claude | Tower | Same API. |
| `BlockTimeFormatter` (in HabitBlockView.swift) | Tower Claude | Architect | Architect will use, not modify. |
| `NewHabitMenu.swift` | Add Task Claude | Architect | Architect calls via `onAddHabit` closure. If interface changes, update Architect. |

## Cross-Cutting Concerns

1. **Completion pipeline:** Timeline's `onComplete` → MainAppView's `pendingDrops` → Tower's `cascadeDropPendingBlocks`. Don't change this interface.
2. **Tab switching:** `selectedTab` in MainAppView drives which tab renders. Enum: tower, today, plan, insights. Don't change without coordination.
3. **refreshData():** Called by both timeline (after complete/skip) and tower (after filter change). Don't change signature. `scheduleRefresh()` added as debounced wrapper (16ms) at 5 burst-prone call sites.
4. **Image pipeline:** `ImageManager`, `CachedImageView`, `ImageMigrationRunner` — shared infrastructure. Don't modify without coordination.
5. **Global Add Button:** `isNewHabitMenuOpen` state in MainAppView triggers `NewHabitMenu` sheet. "+" button in Tower and Today tab toolbars. **Do NOT create duplicate add buttons on other tabs.** Plan tab uses inline "+ Add to Section" rows (different pattern).
6. **Week View:** Linear progress bars per day. Uses `DayProgressData.completionRate` and `handledRate`. Cleveland & McGill 1984.

## Active Work

See `tasks/active.md` for in-progress items and next-up queue per bot.

**Bot grades:** Tower A-, Today A, Plan A+, Insights 7/10 (weekly chart shipped), Settings 8/10.

## ⚠️ PENDING: Tower Visual Refinement — DO NOT TOUCH YET

**Status:** Two plans exist (Architect Claude + Meridian). User will compare and merge the best approach before execution.

**DO NOT modify these files until the comparison is complete:**
- `Strata/Views/HabitBlockView.swift` — block gradient, border, frosted overlay, shadow
- `Strata/Views/FlippableBlockView.swift` — same elements
- `Strata/Models/CategoryColors.swift` — category color values

### Architect Claude's Plan (5 fixes):
1. **Gradient softening** — vertical direction, 4-stop with half-strength tint, smoother falloff
2. **Border subtlety** — top opacity 0.55→0.25, fade by 50% (not 75%), stroke 2.5→1.5pt
3. **Remove frosted overlay** — imperceptible at 0.20, either commit to 0.30+ or remove entirely
4. **Dark mode shadow** — replace colored glow with grounded black shadow (0.25 opacity)
5. **Color accessibility** — Health (#10B77F→#0FA672) and Social (#14D4C1→#12BFB0) for WCAG 4.5:1

### Meridian's Plan (8 changes):

**Core thesis:** Apple's iOS 17-18 card language uses **zero visible borders** on filled surfaces. The 2.5pt gradient stroke is the single most "non-Apple" element in Strata. Remove it entirely and let shadow carry depth alone.

1. **Remove top-lit border entirely** — Delete the `.overlay(RoundedRectangle.stroke(...))` from HabitBlockView, FlippableBlockView, MiniBlockPreview, and TimelineHabitRow.
2. **Strengthen shadows (compensate for border removal)** — New constants: `blockShadowRadius: 6`, `blockShadowY: 3`, `blockShadowOpacity: 0.12`.
3. **Soften gradient + frosted overlay** — lightTint first stop `.opacity(0.7)`. Frosted white overlay 0.20→0.15.
4. **Fix Social color: #14D4C1 → #F97066 (warm coral)** — Health/Social hue collision (15° apart). Coral resolves collision (153° from Health).
5. **Grid spacing 10→8pt** — brand.md documents 8pt but code says 10.
6. **Perfect-day patina: border → fill** — Replace golden stroke with `.fill(patinaGold.opacity(patinaOpacity * 0.5)).blendMode(.overlay)`.
7. **Refine chip/ghost borders** — Unscheduled chips: 1.5pt/0.6→1pt/0.4. Ghost calendar events: 1.5pt/0.5→1pt/0.3.
8. **Task file updates** — brand.md (Social color, remove border references), coordination.md (flag shared file changes).

### Key difference from Architect's plan:
| Issue | Architect | Meridian |
|-------|-----------|----------|
| Border | Reduce (0.55→0.25, 2.5→1.5pt) | **Remove entirely** |
| Frosted overlay | Remove entirely | Reduce (0.20→0.15) |
| Shadow | Keep current (0.10, 4pt) | **Strengthen** (0.12, 6pt) |
| Social color | Shift within teal (#14D4C1→#12BFB0) | **Change to coral (#F97066)** |
| Spacing | Keep 10pt | **Change to 8pt** |

### What's ALREADY excellent (don't touch):
- Shadow system, depth scaling, ground plane
- Corner radius (16pt), patina gold system
- Drop physics and animation orchestration
- Typography system, category colors (except Social)
