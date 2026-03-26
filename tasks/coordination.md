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
| `MainAppView.swift` | Tower Claude | Timeline, Add Task | Plan is now a dedicated tab (not a push destination). Gear icon on Tower tab opens settings sheet. Coordinate before editing. |
| `GridConstants.swift` | Shared | All | Additive changes only. Don't modify existing constants. |
| `CategoryColors.swift` | Shared | All | Read-only. Don't change colors or styles. |

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

### What's ALREADY excellent (don't touch):
- Shadow system (0.10 opacity, 4pt radius)
- Depth scaling (row-based shadow progression)
- Ground plane (animated warmth)
- Spacing (10pt), corner radius (16pt)
- Patina gold system
- Drop physics and animation orchestration

### Research basis:
- Apple HIG: vertical light, minimal chrome, restraint
- Mamassian (1998): shadow encodes position
- Tufte (2001): reduce non-data-ink
- WCAG 2.1: 4.5:1 text contrast minimum
- Gibson (1950): natural light perception

### Meridian's Plan (8 changes):

**Core thesis:** Apple's iOS 17-18 card language uses **zero visible borders** on filled surfaces. The 2.5pt gradient stroke is the single most "non-Apple" element in Strata. Remove it entirely and let shadow carry depth alone.

1. **Remove top-lit border entirely** — Delete the `.overlay(RoundedRectangle.stroke(...))` from HabitBlockView, FlippableBlockView, MiniBlockPreview, and TimelineHabitRow (proto-block border + completed fill border). Delete all `borderHighlight` computed properties.

2. **Strengthen shadows (compensate for border removal)** — New constants: `blockShadowRadius: 6`, `blockShadowY: 3`, `blockShadowOpacity: 0.12`. Dark mode: directional glow (add 2pt Y offset) at 0.20 opacity instead of omnidirectional at 0.30. Reduce depth shadow accumulation (`depthShadowScale` 0.3→0.2, `depthShadowYScale` 0.15→0.10) since stronger base shadow needs less accumulation.

3. **Soften gradient + frosted overlay** — lightTint first stop gets `.opacity(0.7)` (prevents hot spot at top-left that border was masking). Frosted white overlay reduced 0.20→0.15 across all block views and timeline fills.

4. **Fix Social color: #14D4C1 → #F97066 (warm coral)** — Health/Social hue collision (15° apart, both teal, both 91% saturation) is the ONLY broken color pair. Other 5 are well-distributed (40-119° gaps). Coral resolves collision (153° from Health), matches brand.md ("pink — connection, warmth"), is colorblind-safe (Okabe-Ito vermillion range), and ADHD-friendly (off the blue-yellow axis that ADHD retinal dopamine differences affect). Glow opacities reduced 0.30→0.20 for all 6 categories. **Other 5 colors unchanged.**

5. **Grid spacing 10→8pt** — brand.md already documents 8pt but code says 10. Aligns code to brand doc. Tighter tower feels more cohesive/built. Matches Apple Photos/Home/Shortcuts grid spacing.

6. **Perfect-day patina: border → fill** — Replace golden stroke with `.fill(patinaGold.opacity(patinaOpacity * 0.5)).blendMode(.overlay)` — warm golden surface wash instead of border.

7. **Refine chip/ghost borders** — Unscheduled chips: 1.5pt/0.6→1pt/0.4 (outline chips are fine, just thinner). Ghost calendar events: 1.5pt/0.5→1pt/0.3.

8. **Task file updates** — brand.md (Social color, remove border references), coordination.md (flag shared file changes).

### What Meridian says is ALREADY excellent (don't touch):
- Corner radius (16pt — Apple standard for medium cards)
- Category colors (except Social)
- Drop physics, animation orchestration, celebration system
- Ground plane, depth shadow concept
- Patina gold color values (just change from stroke to fill)
- Typography system
- Tower block saturation levels (blocks ARE the reward — keep vivid)

### Research basis:
- Apple iOS 17-18 card language: Weather, Health, Fitness — zero borders on filled cards
- Oxford Consumer Research (2025): low saturation = premium, BUT blocks are focal points not chrome — keep vivid (Notion approach: "reserve saturation for primary elements")
- Treisman (1980): pre-attentive processing needs 30°+ hue separation; Health/Social at 15° fails
- NIH Behavioral & Brain Functions: ADHD blue-yellow axis impairment — cyan Social is worse than coral
- Okabe-Ito colorblind-safe palette: coral/vermillion range distinguishable from teal-green in deuteranopia
- Apple HIG: shadow as sole depth cue, system colors as foundation
- brand.md: Social already described as "pink — connection, warmth" (code mismatched)
- brand.md: spacing already documented as 8pt (code had 10pt)

### Key difference from Architect's plan:
| Issue | Architect | Meridian |
|-------|-----------|----------|
| Border | Reduce (0.55→0.25, 2.5→1.5pt) | **Remove entirely** |
| Frosted overlay | Remove entirely | Reduce (0.20→0.15) |
| Shadow | Keep current (0.10, 4pt) | **Strengthen** (0.12, 6pt) |
| Dark mode glow | Replace with black shadow | Keep glow but add Y-offset + reduce opacity |
| Social color | Shift within teal (#14D4C1→#12BFB0) | **Change to coral (#F97066)** — fixes 15° collision |
| Health color | Shift (#10B77F→#0FA672) | Keep unchanged |
| Spacing | Keep 10pt | **Change to 8pt** (align to brand.md) |
| Gradient | Vertical direction, 4-stop | Keep diagonal, soften lightTint to 0.7 opacity |
| Patina | Not mentioned | Convert from border to fill overlay |
| `Typography.swift` | Shared | All | Read-only. Don't change font definitions. |
| `Habit.swift` | Shared | All | No schema changes without coordination. |
| `HabitLog.swift` | Shared | All | No schema changes without coordination. |
| `HapticsEngine.swift` | Shared | All | Additive only. |
| `WarmBackground.swift` | Timeline Claude | Tower | Being extracted from MainAppView. Same API. |
| `BlockTimeFormatter` (in HabitBlockView.swift) | Tower Claude | Timeline | Timeline will use, not modify. |
| `NewHabitMenu.swift` | Add Task Claude | Timeline | Timeline calls via `onAddHabit` closure. If interface changes, update Timeline. |
| ~~`FloatingBottomBar.swift`~~ | DELETED | — | Replaced by native TabView. |

## Active Work

### Tower Claude
- **Scope:** Tower-owned files. GridConstants additive only.
- **Grade:** A- (all 7 UX action items + 2 performance items resolved)
- **Architecture:** Block masonry grid, per-block observation isolation (`BlockAnimationState` + `TowerBlocksForEach`/`AnimatedBlockView`), `.drawingGroup()` on blur overlays, viewport culling at 30+ blocks, skeleton shimmer loading.
- **Innovations:** Momentum Ground Glow (Goal Gradient Effect), Block Patina (Endowment Effect on perfect days).
- **See history.md** for full completed work list.

### Architect Claude (promoted from Timeline Claude)
- **Scope:** Today tab, Insights tab, Settings, Onboarding, cross-screen audits, performance, competitive analysis, brand.
- **Grade:** Today A, Insights 6/10 (partially shipped), Settings 8/10 (shipped)
- **ACTIVE NOW:** Sound refinement (SoundEngine), Plan edit parity (PlanItemRow — coordinating with Add Task Claude's files), Duration slider (Habit.swift schema: adding customDurationMinutes), NewHabitMenu duration section. TOUCHING SHARED FILES: Habit.swift (additive: +customDurationMinutes), NewHabitMenu.swift, PlanItemRow.swift, SoundEngine.swift, PlanPageViewModel.swift.
- **Architecture:** ScheduleTimelineView with Day/Week toggle. Ghost blocks (cream), completed (dimmed gradient), skipped (hash overlay). Dual-color rings. All springs via GridConstants. All haptics via HapticsEngine. Full reduceMotion. InsightsView (504 lines) + InsightsViewModel (206 lines): photo calendar, streaks, drill-down. SettingsView: notifications, export, reset, tutorial, rate, legal.
- **See history.md** for full completed work list.

### Add Task Claude
- **Scope:** Plan tab files only.
- **Grade:** A+ (all UX + performance issues resolved)
- **Architecture:** Plan tab with DisclosureGroup sections, GTD smart sections (Today/Tomorrow/Inbox), inline NLP capture via HighlightingTextField, section edit sheet. All springs via GridConstants tokens. All haptics via HapticsEngine.
- **See history.md** for full completed work list.

## Cross-Cutting Concerns

1. **Completion pipeline:** Timeline's `onComplete` → MainAppView's `pendingDrops` → Tower's `cascadeDropPendingBlocks`. Don't change this interface.
2. **Tab switching:** `selectedTab` in MainAppView drives which tab renders. Enum: tower, today, plan, insights. Don't change without coordination.
3. **refreshData():** Called by both timeline (after complete/skip) and tower (after filter change). Don't change signature. `scheduleRefresh()` added as debounced wrapper (16ms) at 5 burst-prone call sites.
4. **Image pipeline:** `ImageManager`, `CachedImageView`, `ImageMigrationRunner` — shared infrastructure. Don't modify without coordination.
5. **Global Add Button:** `isNewHabitMenuOpen` state in MainAppView triggers `NewHabitMenu` sheet. "+" button in Tower and Today tab toolbars. **Do NOT create duplicate add buttons on other tabs.** Plan tab uses inline "+ Add to Section" rows (different pattern).
6. **Week View:** Linear progress bars per day. Uses `DayProgressData.completionRate` and `handledRate`. Cleveland & McGill 1984.

## UX & Psychological Principles (ADHD-Informed Architecture)

### Plan Tab — GTD Cognitive Offloading
Externalizes executive planning into persistent, manipulable structures. Smart temporal sections reduce decision load. Inline editing eliminates mode-switching cost (Monsell 2003). NLP captures habits in natural language. Research: Risko & Gilbert 2016.

### Tower Tab — Gamification & Physicality
Blocks = tangible achievement record (IKEA Effect, Norton 2012). Block Patina rewards consistency (Endowment Effect, Kahneman 1990). Momentum Ground Glow provides ambient progress (Goal Gradient Effect, Hull 1932). NO streaks, NO shame signaling — positive-only reinforcement.

### Today Tab — Time Blindness & Embodied Cognition
Timeline anchors habits in time (Barkley 2015). Hold-to-complete forces intentional motor planning. Honest Ring separates completed (green) from skipped (grey). Skip = first-class closure decision (Zeigarnik 1927). Drift Rewards leverage unexpected reward neuroscience (Schultz 2024).

## Screen Grades (2026-03-24)

| Screen | Grade | Haptics | Typography | Accessibility | Animation | Error Recovery |
|--------|-------|---------|------------|---------------|-----------|----------------|
| **Today** | **A** | 9.5/10 | 10/10 | 9/10 | 10/10 | 9/10 |
| **Tower** | **A-** | 9/10 | 10/10 | 8/10 | 10/10 | 8/10 |
| **Plan** | **A+** | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| **Insights** | **6/10** | — | — | — | — | — |
| **Settings** | **8/10** | — | — | — | — | — |

### Screen Collaboration Grade: B

**Data Flow Map:**
```
Plan → Today:    ✅ Automatic (SwiftData @Query reactivity)
Today → Tower:   ✅ Strong (pendingDrops → cascadeDropPendingBlocks)
Tower → Today:   ✅ Improved (tower block count shown on Today header)
Today → Plan:    ✅ "Edit in Plan" context menu
Plan → Today:    ✅ "View in Today" button via @Environment(\.switchTab)
Plan → Tower:    ❌ None (Tower ignores planFolders)
Tower → Plan:    ❌ None (no link or feedback)
```

## Performance Grades

| Screen | Grade | Key Optimization |
|--------|-------|-----------------|
| **Tower** | **A** | Per-block observation isolation, `.drawingGroup()`, viewport culling |
| **Today** | **B-** | `logsByDate` index, `.compositingGroup()`. Gap: VStack not LazyVStack |
| **Plan** | **A** | Debounced rebuild (16ms), pre-computed caches, List virtualization |

### Remaining Performance Issues

| Priority | Issue | Screen |
|----------|-------|--------|
| HIGH | `@Query var habits` has no tower predicate — fetches all | MainAppView |
| HIGH | VStack not LazyVStack — 50+ habits rendered at once | Today |

## Feature Completeness (2026-03-24)

### Tower Tab — 8/10
Works well: block masonry grid, cascade drop physics, filter system, patina, ground glow, scroll culling, skeleton loading, empty state.
Gaps: XP fields still in model (dead code), debug menu visible in DEBUG builds.

### Today/Timeline Tab — 9/10
Works well: hold-to-complete, swipe-to-complete/skip, undo, Day/Week toggle, Sandbox chips, drift rewards, week progress strip, NEXT badge, closure states, reduceMotion.
Gaps: Week view doesn't distinguish skipped from completed, VStack perf.

### Plan Tab — 9/10
Works well: GTD sections, custom folders, NLP capture, progressive disclosure, Timeline Glimpse, cross-tab nav, completion badges, undo, section edit.
Gaps: Grace days only in edit flow, NLP limited to today/tomorrow.

### Insights Tab — 6/10 (partially shipped)
Shipped: Photo calendar with monthly navigation, completion dots, photo badges. Streak hero with per-habit current + best streaks, grace period badges. Habit calendar drill-down. Day detail card. Empty state. 504-line view + 206-line VM.
Missing: Trends, weekly analytics, data export, sharing.

### Settings — 8/10 (shipped)
Shipped: Branded header (mini tower + version), daily reminder notification (UNCalendarNotificationTrigger, permission handling, system-denial detection), JSON data export (share sheet), destructive reset (confirmationDialog), replay tutorial, rate on App Store (requestReview), send feedback (mailto), legal links, DEBUG section.
Missing: Theme/appearance, haptic toggle, cloud sync settings.

## App-Wide Infrastructure

| Feature | Status | Impact |
|---------|--------|--------|
| **Notifications** | ✅ Daily reminder (SettingsView) | Basic coverage — contextual/location reminders still missing |
| **Onboarding** | ✅ WelcomeView + OnboardingState + contextual hints | First-run experience shipped |
| **Cloud Sync** | None (no CloudKit/iCloud) | High — device loss = total data loss |
| **Widgets** | None (no WidgetKit) | Medium — invisible when app is closed |

### Dead Code Inventory

| File/Code | Lines | Status |
|-----------|-------|--------|
| CompletedHabitRow.swift | 50 | Never imported |
| AnchorTimelineView.swift | 130 | Never integrated |
| AltimeterView.swift | ~60 | Zero references |
| MockTowerView.swift | ~40 | Only self-referential Preview |
| CategorySuggestionEngine.swift | ~80 | Zero call sites |
| ~~EventKitService / HealthKitService~~ | — | Now consumed by MainAppView, ScheduleTimelineView, SettingsView, NewHabitMenu |
| HabitLog XP fields | 4 fields | Unused since XP removal |
| HabitLog deprecated fields | 6 fields | Kept for migration |
| Habit unused fields (reminderEnabled, creationXP, timeOfDay, anchorHabitID, todoOrder) | 5 fields | Never read |
| TimelineViewModel.incompleteWithinHour | 3 | Duplicates incompleteToday |

## End-to-End Quality (2026-03-24)

### Overall App Grade: B+

| Category | Grade | Key Issue |
|----------|-------|-----------|
| Visual Design | A | Tower physics, ceramic rings, ghost blocks — premium craft |
| Core Habit Loop | A- | Create → complete → tower block. Hold gesture is best-in-class. |
| First-Use Experience | **B-** | WelcomeView + hints shipped. NLP and tower metaphor still need teaching. |
| Feature Completeness | **B** | Notifications ✅, insights partial, settings shipped. Missing: widgets, sync. |
| ADHD Support | A- | Skip-as-decision, grace days, honest rings, daily reminders. |
| Accessibility | B | reduceMotion ✅, VoiceOver mostly ✅. Gaps: FlippableBlockView, dark mode contrast. |
| Performance | B+ | logsByDate index, .compositingGroup(), viewport culling. |
| Data Integrity | A | SwiftData offline-first, real-time tab sync, undo on complete/skip. |
| Platform Integration | **B** | HealthKit auto-verify + Calendar ghost blocks + daily notifications. Missing: widgets, Watch, Siri, sync. |
| Polish & Finish | B | Insights partially shipped. Settings working. |

### Competitive Position (updated 2026-03-24)

| Category | Strata | TickTick | Structured | Habitica | Streaks | Things 3 | Todoist |
|----------|--------|----------|------------|----------|---------|-----------|---------|
| Visual Design | **9** | 6 | 9 | 4 | 8 | 10 | 7 |
| Habit Core | **6** | 9 | 5 | 7 | 8 | 3 | 5 |
| Time Mgmt | **7** | 8 | 10 | 3 | 4 | 6 | 6 |
| Gamification | **8** | 6 | 3 | 10 | 7 | 2 | 5 |
| ADHD Support | **8** | 4 | 7 | 3 | 5 | 6 | 4 |
| Platform | **6** | 9 | 8 | 5 | 9 | 8 | 8 |
| Data/Insights | **4** | 8 | 3 | 5 | 6 | 4 | 7 |
| Social | **1** | 7 | 2 | 10 | 1 | 1 | 8 |
| Onboarding | **5** | 5 | 7 | 4 | 8 | 9 | 7 |
| **Average** | **5.7** | **6.9** | **6.0** | **5.7** | **6.2** | **5.4** | **6.3** |

### Critical Gaps vs Competition

| Gap | Status | Priority |
|-----|--------|----------|
| ~~Notifications~~ | ✅ Daily reminder shipped | DONE |
| ~~Onboarding~~ | ✅ WelcomeView + hints shipped | DONE |
| Insights/statistics | Partially shipped (6/10) | HIGH — needs trends, analytics |
| Cloud sync | None | HIGH — device loss = data loss |
| Widgets | None | MEDIUM — invisible when closed |

### Top Priorities to Improve Competitive Position

| Priority | Feature | Impact |
|----------|---------|--------|
| HIGH | Complete Insights (trends, weekly patterns, export) | Matches TickTick, beats Structured/Things |
| HIGH | Widgets (progress ring + tower height) | Matches Streaks/Structured/Things |
| HIGH | Cloud sync (CloudKit) | Prevents data loss, enables multi-device |
| ~~MEDIUM~~ | ~~Calendar integration (EventKit)~~ | ✅ Shipped — ghost blocks + gap-finding |
| MEDIUM | Milestone celebrations | Out-gamifies Streaks without Habitica complexity |
