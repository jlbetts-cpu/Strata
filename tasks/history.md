# Strata — Completed Work

## Added

- **Image pipeline architecture** — Production-ready local image storage: `ImageManager` singleton (resize, JPEG compress, NSCache thumbnails), `CachedImageView` (async loading, shimmer placeholder), `ImageMigrationRunner` (one-time blob→file migration). `HabitLog` updated with `imageFileName`.
- **Slack-style side menu & multi-tower support** — Tower model + TowerManager + SideMenuView + TowerHeaderBar; tower switching with skeleton build-up; active tower persistence via UserDefaults.
- **Skeleton shimmer loading** — Premium loading feel: skeleton placeholder blocks with shimmer sweep; off-screen breathing stops in `.onDisappear`; cached `filteredLogs`/`weekData`.
- **Tower filter pill (Day/Week/Month)** — Apple Photos-style segmented picker. Day=time labels, Week=date labels, Month=date labels.
- **Squishy Silicone Block Animations** — Squash/stretch drop phases, silicone press, breathe idle, soft haptics.
- **TowerAnimationCoordinator extraction** — Moved animation state out of MainAppView into dedicated coordinator.
- **Dynamic block drop offset** — Blocks fall from top of visible screen instead of hardcoded -600pt.
- **Timeline zoom persistence** — `@AppStorage` for pixelsPerMinute.
- **Native Liquid Glass tab bar** — Separated "+" button, renamed Journal → Insights.
- **Native TabView migration** — Replaced custom FloatingBottomBar with native SwiftUI TabView. 4 tabs with Liquid Glass, `.tabBarMinimizeBehavior(.onScrollDown)`. Floating + button as ZStack overlay.
- **Research-backed "Habits & Tasks" management screen** (Add Screen Claude) — AllItemsView with MiniBlockPreview, CategorySuggestionEngine, quick-add, effort pills, HabitEditView. Research-backed cuts (no streaks, no fresh start, no identity hint).
- **Timeline architecture extraction** (Timeline Claude) — ScheduleTimelineView.swift, WarmBackground.swift, DayProgressData.swift extracted from MainAppView.
- **Notes-style PlanPageView** (Add Screen Claude) — Full-page document experience via NavigationStack push from "+" button. Type habit names → Return → created with smart defaults (daily, small, auto-category). Inline expandable options per item (category, effort, days, type toggle). Sub-task support via `parentHabitID`. Large title "Habits" collapses on scroll.
- **PlanPageViewModel** (Add Screen Claude) — Lean state: commitNewItem with smart defaults, orderedItems with parent-child interleaving, indent/outdent, inline update methods.
- **PlanItemRow** (Add Screen Claude) — Inline editable row: category dot + title + schedule + expandable inline options (category circles, effort pills, day picker, type toggle, delete).
- **WeekProgressStrip** (Timeline Claude) — Animated rings, streak connector, progress summary, today pulse.
- **Timeline empty states** (Timeline Claude) — Full empty, all-done, past, future states with Add Habit CTA.
- **Timeline zoom snap feedback** (Timeline Claude) — 1x/2x/4x snap with transient pill + haptic tick.

## Changed

- **Tower block design pass** — Softer shadows, matte ceramic bevels, warm background, 16pt squircle corners.
- **Block Figma matching (4 rounds)** — Progressive refinement: gradient fill → border glow → top-lit glow → two-overlay progressive border glow + 20% frosted overlay.
- **Warm grey color pass** — Replaced all blacks (#000) with warm grey (#403D39), updated AccentColor.
- **Warm color palette refinements** — Updated CategoryColors, Typography scale adjustments.
- **Premium block polish** — SF Pro Rounded 17pt, category icon badges, shared BlockContentOverlay, 8pt grid alignment across 15 files.
- **Photo overlay polish** — Warm dark gradient, lighter opacity, gentler fade, radial vignette.
- **Block animation material alignment** — Tightened springs to polished resin/glazed tile (0.60–0.78 damping). Linear scaling. Rigid haptics.
- **Footer & timeline design pass** — Sheet chrome, week strip, timeline rows, hour grid brought up to tower standard.
- **Tab bar minimization & tighter grid** — `.tabBarMinimizeBehavior(.onScrollDown)`, 8→4pt block spacing.
- **Filled/hollow tab icons** — Selected=filled, unselected=outlined.
- **Selected tab accent color** — Work blue (#40A9FF) for selected tabs.
- **Default UX polish** — Text readability, touch targets, HEIC encoding, off-main-thread decode, unified shimmer clock, faster loading, stagger block reveal, `.compositingGroup()`.
- **Timeline full-color blocks** (Timeline Claude) — Switched from desaturated 12% tint to Structured-style full category gradient. Matte→glazed ceramic completion.
- **Timeline glazing animation** (Timeline Claude) — 4-state: incomplete → glazing → glazed → departing → hidden. 3 haptic points. Check circle spring with rotation.
- **Timeline layout v2** (Timeline Claude) — Fixed row width constraints, 100pt bottom padding, section headers in gutter, removed stash animation.
- **Timeline header** (Timeline Claude) — Styled warm divider replacing vanilla Divider.
- **Add screen polish** (Add Screen Claude) — 19 refinements: signature moment, TextField container, keyboard handling, shame-free design, touch targets, accessibility, block indicators, etc.
- **MainAppView type-checker fix** — Extracted 4 sub-expressions to resolve Swift type-checker timeout.
- **"+" button → NavigationStack push** (Add Screen Claude) — Replaced sheet presentation with NavigationStack wrapper + `.navigationDestination`. "+" now pushes PlanPageView as a full page.
- **Habit model** (Add Screen Claude) — Added `parentHabitID: UUID?` (sub-task support), `sortOrder: Int` (list ordering), `isSubTask` computed property.
- **Tower block time text** (Add Screen Claude) — Simplified from "3:15 PM – 3:30 PM" range to single timestamp "3:30 PM". Block size already communicates duration visually.

## Fixed

- **Block drop animation flash** — Set `.falling` phase immediately in `enqueueDrop()` so blocks enter render tree already offscreen.
- **Tower block viewport culling** — Fixed inverted `towerScrollOffset` sign. Lowered culling threshold 80→40 blocks.
- **Timeline overlapping blocks** (Timeline Claude) — Added `.frame(maxWidth: .infinity)` + trailing padding to row HStack.
- **Timeline scroll clipping** (Timeline Claude) — Bottom padding 24→100pt for tab bar clearance.
- **Timeline section header overlap** (Timeline Claude) — Moved section headers into gutter area.

## Removed

- **Architecture cleanup** — Removed BottomBarView, TimelineSheetView. ContentView reduced to thin wrapper.
- **Glass morphing infrastructure** — Superseded by native TabView migration.
- **Dynamic footer clearance** — Superseded by native TabView safe area.
- **FloatingBottomBar.swift** — Replaced by native TabView.
- **Dead code** (Timeline Claude) — Deleted IncompleteHabitRow.swift, WeekStripView.swift, MorphingDrawerView.swift.
- **Duplicate time formatters** (Timeline Claude) — Removed from TimelineHabitRow, consolidated to BlockTimeFormatter.
