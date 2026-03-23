# Strata — Completed Work

## Added

- **V8 SectionEditSheet & Smart View Personalization** (Add Task Claude) — Premium `.sheet` with `.presentationDetents([.medium])` for section editing (Apple Reminders "Show List Info" pattern). Live preview header, name TextField, icon LazyVGrid (20 SF Symbols), color LazyVGrid (10 system colors), selection rings (Fitts' Law 44pt targets). Smart View Override Engine: Today/Tomorrow/Inbox icon + color customizable via `@AppStorage("smartViewOverrides")` JSON dictionary. "Reset to Default" for permanent sections. Context menu simplified: "Edit Section" replaces 3 nested sub-menus (Accot-Zhai Steering Law). Research: Shneiderman 1983 (Direct Manipulation), Ryan & Deci 2000 (SDT/Autonomy), Norton 2012 (IKEA Effect), Kahneman 1991 (Endowment Effect), Treisman 1980 (Pre-attentive Processing), Sweller 1988 (Cognitive Load Theory), Barkley 1997/2012 (ADHD Working Memory + Externalization).
- **V5 GTD Architecture** (Add Task Claude) — Segmented Picker (Routines/To-Dos), permanent Smart Horizons (Today/Tomorrow as dynamic cross-cutting filters), Inbox paradigm (renamed from Unassigned), PlanFolder.colorHex with color picker context menu, Dynamic Type audit (all hardcoded .system(size:) → native type tokens).
- **V3 Custom Sections** (Add Task Claude) — PlanFolder SwiftData model (mirrors Tower pattern), Habit.planFolder relationship, user-created sections with drag-and-drop (.draggable/.dropDestination), folder CRUD (create/rename/icon/delete), context menu on section headers.
- **V2 Hero Block Planning** (Add Task Claude) — 80pt centered MiniBlockPreview in expanded card (dynamic blockSize/category), .ultraThinMaterial card background, category-colored top edge, decluttered title row (icon hidden when expanded).
- **V1 Contextual Capture** (Add Task Claude) — Timeline Glimpse (horizontal day-strip in time picker), Progressive Metadata (smart summary → deferred pill row), Mini Block Visual Bridge (collapsed/expanded previews).
- **Efficiency Protocol** (Add Task Claude) — Pre-compiled regexes in InputParser (~100× speedup), removed double-highlighting in HighlightingTextField, cached maxSortOrder, GeometryReader→aspectRatio in MiniBlockPreview, subtask lookup dictionary.
- **Honest Timeline V2** (Timeline Claude) — Complete "Status Grammar" system: 4 visual states (Pending/Active/Completed/Skipped). Skip stays in place with diagonal hash overlay and grey × check circle. Undo-skip via tap. Dual-color rings (green completed + grey skipped, hidden when 0 habits). Three-state closure: "X remaining" / "All done!" (green, success haptic) / "All cleared" (grey, neutral). Full `skippedHabitIDs` pipeline through MainAppView → ScheduleTimelineView → TimelineHabitRow. `HabitLog.skipped`, `DayProgressData.skippedCount/handledRate/remainingCount`. Research: Gollwitzer 2008 (response inhibition), Goodhart's Law, Zeigarnik 1927 (closure), Deci & Ryan 2000 (SDT).
- **Today screen spec** (Timeline Claude) — `tasks/today_spec.md` — research-backed design spec covering Status Grammar, Honest Calendar rules, Fluid Interaction (embodied cognition), Visual Dissonance audit, Closure Model, Performance Architecture, and remaining gaps. 12+ peer-reviewed citations.
- **Momentum Ground Glow** (Tower Claude) — Tower ground plane subtly warms from neutral to green as daily completions accumulate. Ambient color shift, no animation loops. Resets daily. Research: Goal Gradient Effect (Hull 1932, Kivetz 2006).
- **Block Patina** (Tower Claude) — In week/month filter views, blocks from perfect days (100% completion) develop a subtle golden border tint that intensifies slightly with age. Positive-only — no penalty for imperfect days. Uses `perfectDayDates` environment key computed in `refreshData()`. Research: Endowment Effect (Kahneman 1990), IKEA Effect (Norton 2012).

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
- **Timeline debug buttons** (Timeline Claude) — Debug menu on Today screen matching tower pattern. Add scheduled/unscheduled habits with realistic names and random times.

## Changed

- **Tower Screen Audit Fix** (Tower Claude) — Resolved all 7 peer-review UX action items + 2 performance items. Haptics: filter change tick, PhotosPicker lightTap (both sheets), drag-dismiss snap. Error recovery: photo save failure alerts replace silent catch blocks. Accessibility: tower grid `.accessibilityElement(children: .combine)`, `@ScaledMetric` Dynamic Type on header/pill/sheet icons. Typography: 8 icon size tokens in GridConstants, 10 hardcoded `.system(size:)` replaced. Performance: `.drawingGroup()` on blur overlays (HabitBlockView + FlippableBlockView), `scheduleRefresh()` 16ms debounce on 5 burst-prone `refreshData()` sites. Build verified. Grade: B- → A-.
- **Performance audit** (Timeline Claude) — Single-pass `logsByDate` index in `refreshData()` eliminates 5 redundant O(n) log scans (~18,000 iterations → ~3,200). `.compositingGroup()` on TimelineHabitRow (6 GPU layers → 1 texture). Nested GeometryReader removed from hash overlay. `GridConstants.toggleSwitch`/`skeletonPop` tokens added. All MainAppView inline springs replaced with GridConstants tokens. MiniBlockPreview `breatheT` parameter for shared breathing clock. Timer guard O(n) → O(1).
- **Tower brand sync** (Tower Claude) — BlockContentOverlay time/XP fonts → `Typography.bodySmall` (was SF Rounded), `.sensoryFeedback` → `HapticsEngine.lightTap()` in 3 files (HabitBlockView, FlippableBlockView, TowerHeaderView), breathing variance magic numbers → `GridConstants.breatheVarianceMin/Max`, XPBarView inline spring → `GridConstants.progressFill`, MainAppView compression rebound → `naturalSettle` + initial load → `layoutReflow`, skeleton build-up springs documented as intentional variants, LevelUpOverlay hero font documented as one-off.
- **Tower cross-audit peer review implementation** (Tower Claude) — 6 findings from Add Task Claude's audit: visual ground plane at tower foundation (Lakoff embodied cognition anchor), peak-end block count at scroll top (Kahneman closure), category icon 11→13pt (WCAG colorblind scanning), cascadeReveal spring extracted to GridConstants, culling threshold 40→30 blocks with 150pt buffer, VoiceOver accessibilitySortPriority for bottom-to-top grid traversal.

- **Tower header design + ADHD audit** (Tower Claude) — 68pt compact TowerHeaderView: day-of-week date (time blindness accommodation), "X of Y today" progress with capsule bar, inline altimeter, gear + filter controls. Empty tower state message. Replaced 110pt dead space with research-backed ADHD-accessible header. `collapsedHeaderHeight` 110→68.
- **Plan tab replaces Preferences + floating "+" button** (Add Screen Claude) — 4-tab bar (Tower → Today → Plan → Insights). Preferences moved to gear icon sheet overlay on Tower tab. Removed ZStack wrapper, addButton, showPlanPage state from MainAppView.
- **Timeline completed-habit rendering** (Timeline Claude) — ScheduleTimelineView accepts allHabits + completedHabitIDs (was incompleteHabits). Completed habits render glazed in-place. Debug menu added to timeline.
- **TimelineHabitRow completed state** (Timeline Claude) — New `isAlreadyCompleted` param renders glazed ceramic immediately with breathing shimmer. Removed `departing`/`hidden` states. Interactive guard prevents swipe on completed rows.
- **PlanItemRow time picker + icon circles** (Add Screen Claude) — Added `onUpdateTime` callback, time toggle+picker in expanded options. Category indicators upgraded to 20pt icon circles. Button wrapping replaces onTapGesture. Labeled sections with Gestalt spacing.
- **Tower filter pill → compact Menu button** (Tower Claude) — Replaced 3-option segmented pill (Day/Week/Month) with native `Menu`+`Picker`. Matches AltimeterPill styling (Typography.caption, ultraThinMaterial, Capsule). Filter icon uses `.fill` variant when non-default. Moved to top-right; gear icon moved up to top-left row 1; debug menu moved to top-left row 2. Research-backed: Apple Maps, Calendar iOS 18, and Structured 4.0 all abandoned segmented controls for this pattern.
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
- **PlanPage definitive overhaul** (Add Screen Claude) — Labeled sections ("Category", "Effort", "Schedule", "Time") with 24pt Gestalt spacing, no dividers. Row indicators: plain dots → 20pt icon circles (NN/g: 37% faster scanning). Block-shaped effort pills with equal width. Time picker added (Toggle + DatePicker). Category labels under circles. Keyboard toolbar removed. "No days" frequency bug fixed. onTapGesture → Button, DispatchQueue → Task, Date() → Date.now (swiftui-pro skill compliance).
- **Timeline v3 overlap fix** (Timeline Claude) — Google Calendar column-splitting algorithm: overlapping habits render side-by-side. GeometryReader for available width.
- **Timeline v3 matte/glazed visual gap** (Timeline Claude) — Added `Color.white.opacity(0.08)` chalky overlay on matte blocks. Removed shadow from matte (flat), enhanced dual-layer shadow on glazed (lifted). Visible depth difference.
- **Timeline v3 completed stay in place** (Timeline Claude) — Completed habits stay in time slot as glazed blocks. `allHabits` + `completedHabitIDs` replace `incompleteHabits` prop. `isAlreadyCompleted` flag on TimelineHabitRow.
- **Plan page smart grouping + QoL** (Add Screen Claude) — Temporal section ordering (Today first — Primacy Effect), collapsible DisclosureGroup sections, sort menu (Recent/Category/Oldest) with glass button, inline title editing via @FocusState, type icons (↻ habits, ○ tasks), schedule shows time ("Daily · 9:00 AM"), inline sub-task creation, starter habit templates in empty state (ADHD), expand hint, left-edge category accent, section headers with icon + count. Title "Habits" → "Plan".
- **Timeline v4 Structured-inspired redesign** (Timeline Claude) — Full rewrite of ScheduleTimelineView. Replaced proportional time-grid with flat ordered list. Scheduled section ("Your Day") with time labels. Unscheduled section above as horizontal scroll chips. Tap unscheduled → suggest open slot (gap-finding algorithm). Fixed block heights (56/72/88pt by blockSize). Removed: pixelsPerMinute, MagnificationGesture, effectiveScale, nowIndicator, overlap column algorithm, minutesFromStartOfDay. Research-backed: BJ Fogg anchoring, Gollwitzer implementation intentions, NNGroup F-pattern scanning, Goal Gradient Effect.

## Fixed

- **Default frequency for new habits** (Add Screen Claude) — PlanPageViewModel now sets `frequency: DayCode.allCases` (was empty, causing habits to not appear on any day).
- **Block drop animation flash** — Set `.falling` phase immediately in `enqueueDrop()` so blocks enter render tree already offscreen.
- **Tower block viewport culling** — Fixed inverted `towerScrollOffset` sign. Lowered culling threshold 80→40 blocks.
- **Timeline overlapping blocks** (Timeline Claude) — Added `.frame(maxWidth: .infinity)` + trailing padding to row HStack.
- **Timeline scroll clipping** (Timeline Claude) — Bottom padding 24→100pt for tab bar clearance.
- **Timeline section header overlap** (Timeline Claude) — Moved section headers into gutter area.
- **Timeline v5 completion UX** (Timeline Claude) — Three-tier visual system: ghost blocks (cream card + category border) for incomplete, dimmed gradient for completed, full gradient for tower. Things 3-style fill-sweep animation (left-to-right color mask). Tap-to-toggle undo. Strikethrough on completed titles.
- **Timeline v6 zero-onboarding QoL** (Timeline Claude) — NEXT badge on first incomplete habit, first-launch swipe hint ("Swipe right to complete →"), renamed UNSCHEDULED → FLEXIBLE, darkened ghost contrast, removed misleading "Pick a different time" dialog button.
- **Timeline holistic motion system** (Timeline Claude) — Unified spring vocabulary in GridConstants (motionSnappy/Smooth/Gentle/Settle/Reduced). All haptics via HapticsEngine methods. Full reduceMotion compliance via `anim()` helper. 3-phase completion (fill circle → sweep → settle). Proportional swipe threshold (Fitts' Law). easeOut swipe exit. Cancellable Task for all async sequences.
- **Timeline peer review integration** (Timeline Claude) — 9/10 Tower Claude findings implemented: removed todayPulse loop, added WeekProgressStrip accessibility, semantic spring tokens, HapticsEngine methods, reduceMotion on schedule dialog, 44pt chip targets, AppColors.ghostBase extraction, VoiceOver hidden swipe icons.
- **Timeline QA crash fixes** (Timeline Claude) — T1-T2: WeekProgressStrip array bounds guards. T3: effectiveHour empty string guard. T4: cancellable completion Task with onDisappear. T5: replaced DispatchQueue with cancellable Tasks. T6: habitToSchedule isDeleted guard. T7: onChange vs gesture conflict guard. T10: reset suggestion state on date change.
- **Timeline header redesign** (Timeline Claude) — 28pt Bold hero date (research: Fantastical/Things 3 scale). Minimalism pass: removed day name, progress ring, "completed" text (7→2 elements, Cognitive Load Theory). Non-sticky header (scrolls with content). Tap date to return to today.
- **Timeline Day/Week toggle** (Timeline Claude) — Segmented picker (Day/Wk). Week mode: 7 day columns with completion rings + count, today green tint, tap column → day detail. Research-backed: Structured split-screen pattern adapted for habits.
- **Timeline dark mode** (Timeline Claude) — WarmBackground dark mode switched to `Color(uiColor: .systemBackground)`. Ghost block dark border opacity reduced (0.5→0.3). Completed block white border reduced (0.3→0.15). Drift reward blend mode adaptive (dark=.screen, light=.overlay).
- **Drift Rewards innovation** (Timeline Claude) — ~25% of completions, after 1.5-4s random delay, completed block gets subtle iridescent overlay glow. Never counted/promised. Respects reduceMotion. Research: Schultz 2024 (unexpected rewards maximize dopamine), Lepper 1973 (no overjustification).
- **brand.md created** (Timeline Claude) — Single source of truth for all bots: colors, typography, layout, motion presets, haptics. Updated dark mode background.
- **Tab bar collapse on Tower tab** (Tower Claude) — Removed `.scrollBounceBehavior(.basedOnSize)` and flattened ZStack with full-size siblings into `.overlay()` modifiers so tab bar system can identify the primary ScrollView.

## Removed

- **Leveling/XP/gamification system** — Deleted XPEngine.swift, GamificationViewModel.swift, XPBarView.swift, LevelUpOverlay.swift. Removed XP display from blocks, tower header, CompletedHabitRow, BlockDetailSheet. Simplified HabitLog.markCompleted() (no more XP generation/bonus blocks). Deprecated XP fields retained for schema compatibility.
- **FamiljenGrotesk custom font** — Replaced with SF Pro Rounded (system). Deleted font files and Info.plist UIAppFonts registration. Typography.swift rewritten to use `Font.system(design: .rounded)` with standard text styles for proper Dynamic Type scaling.
- **IncompleteBlockView** (Tower Claude) — Dead struct in HabitBlockView.swift. Had brand violations (hardcoded shadow, inline UIImpactFeedbackGenerator). Unused per `project_no_incomplete_blocks.md`.
- **Dead header/tab views** — Deleted StrataHeaderView.swift, TowerHeaderBar.swift, HeaderView.swift (+ FloatingPlusButton), TowerTabView.swift. All unused legacy code replaced by TowerHeaderView.
- **Architecture cleanup** — Removed BottomBarView, TimelineSheetView. ContentView reduced to thin wrapper.
- **Glass morphing infrastructure** — Superseded by native TabView migration.
- **Dynamic footer clearance** — Superseded by native TabView safe area.
- **FloatingBottomBar.swift** — Replaced by native TabView.
- **Dead code** (Timeline Claude) — Deleted IncompleteHabitRow.swift, WeekStripView.swift, MorphingDrawerView.swift.
- **Duplicate time formatters** (Timeline Claude) — Removed from TimelineHabitRow, consolidated to BlockTimeFormatter.
