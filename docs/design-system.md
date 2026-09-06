# Strata Design System Specification

> Complete design token reference for Figma handoff. Every value verified against source code.
> Last updated: 2026-03-26

---

## 1. Color Tokens

### Category Palettes

Each category has 6 color roles. All text on category fills is white.

| Category | Base | Light Tint | Dark Shade | Border | Glow Opacity | Icon (SF Symbol) |
|----------|------|------------|------------|--------|-------------|-------------------|
| **Health** | `#0EAD74` | `#30C494` | `#0B9362` | `#0B9362` | 20% | `heart.fill` |
| **Work** | `#40A9FF` | `#6DC0FF` | `#2E8BE6` | `#2E8BE6` | 30% | `briefcase.fill` |
| **Creativity** | `#AF9CFA` | `#C4B5FF` | `#826DD0` | `#826DD0` | 30% | `paintbrush.fill` |
| **Focus** | `#FDB54F` | `#FEC873` | `#D99A3A` | `#D99A3A` | 30% | `eye.fill` |
| **Social** | `#F97066` | `#FB8E86` | `#D45E55` | `#D45E55` | 20% | `person.2.fill` |
| **Mindfulness** | `#EC85B4` | `#F2A0C8` | `#C86B98` | `#C86B98` | 30% | `leaf.fill` |

**Gradient usage:** Blocks use a 3-stop vertical gradient: lightTint (top, 0%) -> baseColor (30%) -> darkShade (100%). Frosted overlay adds white gradient on top for material depth.

### System Colors

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| Warm Black | `#403D39` | 64, 61, 57 | Primary brand text, accent |
| Accent Purple | `#A689FA` | 166, 137, 250 | Secondary accent |
| Health Green | `#34C48B` | 52, 196, 139 | Progress rings, success states |
| Warm Red | `#E85D4A` | 232, 93, 74 | Destructive actions, "Remove time" |

### Ghost Blocks (Incomplete Habits)

| Mode | Value | Notes |
|------|-------|-------|
| Light | `RGB(230, 227, 224)` | 12% luminance contrast to warm background |
| Dark | `UIColor.secondarySystemGroupedBackground` | Native iOS card color |

### Warm Background

| Mode | Type | Values |
|------|------|--------|
| Light | Vertical gradient | Top: `RGB(250, 249, 246)` / Bottom: `RGB(249, 247, 244)` |
| Dark | Solid + overlay | `UIColor.systemBackground` + `RGB(38, 26, 13)` @ 2% opacity |

### Patina Gold (Perfect-Day Tint)

| Token | Value |
|-------|-------|
| Color | `RGB(242, 204, 102)` — warm gold |
| Max opacity | 15% |
| Growth rate | +2% per block on perfect days |

### Milestone Tier Colors

| Tier | Hex | Emoji |
|------|-----|-------|
| Bronze | `#CD7F32` | 🥉 |
| Silver | `#C0C0C0` | 🥈 |
| Gold | `#FFD700` | 🥇 |
| Platinum | `#E5E4E2` | 💎 |
| Legendary | `#FF6B35` | ⭐ |

### Semantic Opacity Tokens

| Token | Value | Usage |
|-------|-------|-------|
| Ghost | 6% | Backgrounds, decorative fills |
| Subtle | 12% | Borders, dividers, secondary bg |
| Muted | 25% | Disabled, de-emphasized |
| Secondary | 50% | Secondary text, icons |
| Primary | 70% | Primary text on colored bg |
| Full | 100% | Full strength |

---

## 2. Typography

### Brand Fonts (Space Grotesk)

Architectural/geometric. Used for logos, headers, and hero elements.

| Style | Font | Size | Weight | Kerning |
|-------|------|------|--------|---------|
| `brandLogo` | SpaceGrotesk-Medium | 24pt | Medium (500) | 1.5 |
| `brandHeader` | SpaceGrotesk-Medium | 20pt | Medium (500) | 0 |
| `brandSubheader` | SpaceGrotesk-Medium | 17pt | Medium (500) | 0 |
| `brandHeroDate` | SpaceGrotesk-Medium | 22pt | Medium (500) | 0 |
| `brandCardTitle` | SpaceGrotesk-Medium | 19pt | Medium (500) | 0 |

### System Fonts (SF Pro Rounded)

Warm/humanist. Used for all body text, labels, and UI elements.

| Style | Text Style | Size (default) | Weight | Scales with DT |
|-------|------------|----------------|--------|----------------|
| `appTitle` | .largeTitle | 34pt | Medium | Yes |
| `headerLarge` | .title3 | 20pt | Medium | Yes |
| `headerMedium` | .headline | 17pt | Medium | Yes |
| `headerSmall` | .subheadline | 15pt | Medium | Yes |
| `bodyLarge` | .body | 17pt | Regular | Yes |
| `bodyMedium` | .callout | 16pt | Regular | Yes |
| `bodySmall` | .footnote | 13pt | Regular | Yes |
| `caption` | .caption | 12pt | Regular | Yes |
| `caption2` | .caption2 | 11pt | Medium | Yes |
| `blockTitle` | .callout | 16pt | Medium | Yes |
| `miniBlockTitle` | Fixed | 10pt | Medium | No |
| `miniBlockIcon` | Fixed | 9pt | Medium | No |

---

## 3. Spacing & Layout

### Grid System

| Token | Value |
|-------|-------|
| Column count | 4 |
| Grid spacing | 10pt |
| Horizontal padding | 16pt |
| Timeline gutter width | 56pt |

**Cell size formula:** `cellSize = floor((gridWidth - 3 * 10) / 4)`

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| Standard | 16pt | Blocks, cards, expanded views |
| Small | 8pt | Pills, chips, badges |
| Micro | 4pt | Sparkline blocks, tiny indicators |
| Card | 20pt | Expansion card overlay |

### Padding

| Token | Value | Usage |
|-------|-------|-------|
| Horizontal | 16pt | Content edges |
| Header top | 12pt | Header spacing |
| Header bottom | 8pt | Header spacing |
| Card content | 20pt | Expansion card internal |
| Card content spacing | 16pt | Between card sections |

### Stroke Width

| Token | Value |
|-------|-------|
| Thin | 1.0pt |
| Default | 1.5pt |
| Medium | 2.0pt |
| Thick | 2.5pt |

### Dividers

| Token | Value |
|-------|-------|
| Height | 0.5pt |
| Opacity | 6% |

---

## 4. Shadow System

### Ambient Shadow (default)

| Token | Value |
|-------|-------|
| Radius | 4pt |
| Y offset | 2pt |
| Opacity (light) | 10% |
| Opacity (dark) | 35% (base * 3.5, max 60%) |

### Block Shadow (post-border-removal)

| Token | Value |
|-------|-------|
| Radius | 5pt |
| Y offset | 2.5pt |
| Opacity (light) | 12% |
| Opacity (dark) | 20% |

### Height-Progressive Shadow

Blocks higher in the tower cast slightly stronger shadows:
- Base opacity: 4%
- Growth: +0.1% per row
- Max: 6%
- Max radius: 12pt

---

## 5. Animation Springs

### Drop Physics

| Name | Response | Damping | Usage |
|------|----------|---------|-------|
| `dropSquash` | 0.12s | 0.60 | Block impact |
| `dropStretch` | 0.18s | 0.65 | Block stretch on land |
| `dropSettle` | 0.28s | 0.78 | Post-drop settling |
| `rippleCompress` | 0.12s | 0.55 | Ripple through stack |
| `rippleRelease` | 0.35s | 0.60 | Ripple recovery |

### Tap Feedback

| Name | Duration | Bounce | Scale |
|------|----------|--------|-------|
| `tapSquash` | 0.06s | 0.0 | X: 1.02, Y: 0.97 |
| `tapPop` | 0.22s | 0.20 | — |

### Wobble Settle

| Name | Response | Damping | Degrees |
|------|----------|---------|---------|
| `wobble` | 0.18s | 0.65 | Light: 0.8, Heavy: 1.5 |

### Semantic Motion

| Name | Response | Damping | Usage |
|------|----------|---------|-------|
| `snapBack` | 0.22s | 0.20* | Pop-back after tap |
| `gentleReveal` | 0.22s | 0.85 | Content appearing |
| `naturalSettle` | 0.28s | 0.78 | General settling |
| `heavySettle` | 0.28s | 0.80 | Large elements |
| `elasticPop` | 0.25s | 0.50 | Celebratory bounces |
| `progressFill` | 0.25s | 0.70 | Bars, rings filling |
| `layoutReflow` | 0.55s | 0.90 | Major layout changes |
| `crossFade` | 0.2s | easeInOut | Non-spatial transitions |
| `cascadeReveal` | 0.50s | 0.65 | New blocks dropping |

*snapBack uses duration/bounce API, not response/damping

### Today Screen Motion

| Name | Response | Damping | Usage |
|------|----------|---------|-------|
| `motionSnappy` | 0.25s | 0.82 | Tap feedback, check circles |
| `motionSmooth` | 0.22s | 0.78 | Content transitions |
| `motionGentle` | 0.40s | 0.85 | Expand/collapse |
| `motionSettle` | 0.28s | 0.90 | End-of-sequence |
| `motionReduced` | 0.05s | easeOut | Accessibility fallback |
| `toggleSwitch` | 0.30s | 0.80 | Toggle/picker transitions |
| `skeletonPop` | 0.35s | 0.65 | Loading skeleton pop-in |

### Card Motion

| Name | Response | Damping | Usage |
|------|----------|---------|-------|
| `cardMorph` | 0.35s | 0.86 | Card open/close |
| `cardReveal` | 0.40s | 0.88 | Card content fade-in |

### Celebration

| Name | Response | Damping | Notes |
|------|----------|---------|-------|
| `celebrationBurst` | 0.30s | 0.60 | — |
| `blockFlyaway` | 0.55s | 0.70 | — |
| Confetti duration | 2.0s | — | 24 particles |

### Fill Sweep (Momentum Escalation)

| Tier | Duration |
|------|----------|
| Fast | 0.28s |
| Medium | 0.32s |
| Early | 0.36s |

### Spatial Effects

| Token | Value |
|-------|-------|
| Breathing cycle | 3.0s |
| Breathing intensity | 1.5% |
| Ghost pulse min/max | 4% / 10% |
| Ghost dash length | 4pt |
| Ambient glow cycle | 2.5s |
| Ambient glow intensity | 8% |
| Stagger interval | 0.04s |
| Stagger max | 0.4s |
| Entrance offset | 12pt |

---

## 6. Block Size System

| Size | Grid Span | Duration | Mass (physics) | Effort Label |
|------|-----------|----------|----------------|--------------|
| Small | 1 col × 1 row | 15 min | 1.0 | Quick |
| Medium | 2 col × 1 row | 30 min | 2.0 | Regular |
| Hard | 2 col × 2 row | 60 min | 4.0 | Deep |

### Squash & Stretch (linear in mass)

| Effect | Formula |
|--------|---------|
| Squash Y | 0.025 × mass |
| Squash X | 0.015 × mass |
| Stretch Y | 0.012 × mass |
| Stretch X | 0.008 × mass |

### Altimeter

1 block = 3 meters height

---

## 7. Icon Inventory (SF Symbols)

### Category Icons
`heart.fill` `briefcase.fill` `paintbrush.fill` `eye.fill` `person.2.fill` `leaf.fill`

### Navigation
`checkmark` `checkmark.circle.fill` `xmark` `xmark.circle.fill` `xmark.circle` `chevron.right` `chevron.left` `chevron.compact.down` `chevron.down` `plus` `plus.circle` `plus.circle.fill` `gearshape`

### Status
`checkmark.circle.fill` (completed) `minus.circle.fill` (skipped) `play.circle.fill` (in progress) `circle` (ghost/empty) `sun.min.fill` (active today)

### Actions
`camera.fill` `camera.viewfinder` `arrow.triangle.2.circlepath.camera.fill` `photo` `bookmark` `square.and.arrow.up` `trash.fill`

### Schedule
`calendar` `calendar.badge.plus` `clock` `star.fill` `forward.fill` `arrow.up` `arrow.up.right` `arrow.counterclockwise`

### Data
`flame.fill` `sparkles` `tag.fill` `chart.bar` `line.3.horizontal.decrease.circle.fill` `line.3.horizontal.decrease.circle` `line.3.horizontal.decrease`

### Spatial
`square.stack.3d.up` `cube.transparent`

### Settings
`bell.fill` `speaker.wave.2.fill` `square.dashed` `hand.wave.fill` `envelope.fill` `iphone.radiowaves.left.and.right`

### Icon Sizes

| Token | Size | Usage |
|-------|------|-------|
| Small | 8pt | Badges, chevrons, photo indicators |
| Medium | 12pt | Next-up pill icons |
| Category | 13pt | Category icons on blocks |
| Action | 14pt | Close X, replace photo |
| Toolbar | 17pt | Gear, toolbar items |
| Chevron | 10pt | Next-up pill chevron |
| Empty State | 36pt | Hero icons in empty states |
| Hero | 40pt | Large hero elements |

---

## 8. Screens

### 8.1 Tower Tab (`TowerView.swift`)

**Layout:** ScrollView with 4-column grid. Blocks stack bottom-to-top with cascade drop animations. Day separators between date groups.

**Header:** Date text (brandHeroDate), filter pill (Day/Week/Month), gear icon, progress text + altimeter.

**States:**
- Empty: Welcome view with 4 stacked MiniBlockPreviews + onboarding copy
- Loading: SkeletonBlockView shimmer placeholders
- Populated: Colored blocks in grid (1×1, 2×1, 2×2 sizes)
- Filtered: Day/Week/Month scope with smooth layout reflow
- Perfect day: Patina gold tint on all blocks for that day
- Block expanded: Full-screen BlockExpansionCard with hero animation

**Key measurements:**
- Grid spacing: 10pt
- Block corner radius: 16pt
- Block shadow: radius 5pt, Y 2.5pt, opacity 12%

### 8.2 Today Tab (`ScheduleTimelineView.swift`)

**Layout:** Week strip at top, morning briefing card, scrollable timeline of TimelineHabitRows grouped by day separators.

**States:**
- Empty: No habits scheduled message
- Populated: Rows with category icons, titles, time pills, completion rings
- Completing: Ring fill sweep animation (0.4s)
- Completed: Green checkmark, strikethrough
- Skipped: Grey, skip icon
- HealthKit verifying: Ripple overlay on ring
- All Clear: Confetti celebration (24 particles, 2s)
- Past date: Disabled, historical view

**Key measurements:**
- Week strip day circle: 44pt touch target
- Timeline gutter: 56pt
- Completion ring: 24pt

### 8.3 Plan Tab (`PlanPageView.swift`)

**Layout:** Segmented picker (Routines / To-Dos) in toolbar. Dashboard grid (2×2 LazyVGrid, 8pt spacing). Collapsible list sections below grid.

**Dashboard cards:** Icon circle (28pt) with gradient, count/progress, progress bar (Today only), section title.

**Row:** Category icon (44pt touch target), editable title, metadata (schedule + subtask count + chevron). Expandable card with 3 zones: Time Hero, Metadata Pills, Steps + Actions.

**States:**
- Empty: MiniBlockPreview illustration + "Let's build together" copy + template buttons
- Routines mode: Today, Tomorrow, Done, Next 7 Days, Inbox, custom folders
- To-Dos mode: Today, In Progress, Done, Tomorrow, Next 7 Days, Waiting for You, Saved
- Item expanded: regularMaterial card with shadow, time hero, form rows
- Drag mode: 12% accent highlight on drop target
- Undo: thinMaterial capsule snackbar at bottom

**Key measurements:**
- Dashboard card min height: 80pt (ScaledMetric)
- Row padding: 16pt H, 16pt V
- Expanded card padding: 16pt V
- Expanded card corner radius: 16pt
- Icon frame: 28pt (ScaledMetric)

### 8.4 Insights Tab (`InsightsView.swift`)

**Layout:** Weekly 7-day completion bar chart (Swift Charts). Streaks section with hero streak display. Photo calendar grid.

**States:**
- Empty: No data message
- Populated: Bar chart + streak badges + photo grid
- Streak highlight: Longest streak emphasized

### 8.5 Settings (`SettingsView.swift`)

**Layout:** Form-based (Apple Settings pattern). Grouped sections with toggles, pickers, buttons.

**Sections:** Notifications, Tower Appearance (ghost blocks, parallax, haptics), Data (export, reset), About (rate, feedback, legal, debug).

---

## 9. Sheets & Modals

### 9.1 BlockDetailSheet

Full-screen sheet. Category gradient background. Header with title + completion time + category pill. Photo area with upload/replace. Stats pills (Size, Streak, XP). Notes section. Day's other blocks carousel.

### 9.2 HabitDetailSheet

Sheet with cover photo (200pt with image, 100pt without). Title, category badge, time, frequency. Edit notes, completion circle, delete button.

### 9.3 BlockExpansionCard

In-place morphing card (hero animation). Corner radius: 20pt. Content padding: 20pt. Daily photo filmstrip (56pt thumbnails, 8pt spacing). Habit journey filmstrip (30 most recent photos). Notes with rotating prompts. Drag-to-dismiss.

### 9.4 NewHabitMenu

NavigationStack form. Recurring/One-Time toggle. Title input. Category pills (horizontal scroll). Block size selector (MiniBlockPreviews). Day selector (7 circles). Time picker, grace days stepper, duration. Optional HealthKit link.

### 9.5 SectionEditSheet

`.medium` detent with drag indicator. Live preview header (icon + name + color). Icon grid (20 options, 44pt targets). Color picker (10 colors). "Reset to Default" for system sections.

**Icon options:** star, sunrise, moon, sun, bolt, flame, heart, leaf, book, graduationcap, dumbbell, figure.run, paintbrush, music, gamecontroller, house, briefcase, cup.and.saucer, brain.head.profile, tray.and.arrow.down

**Color options:** Gray `#8E8E93`, Red `#FF3B30`, Orange `#FF9500`, Yellow `#FFCC00`, Green `#34C759`, Teal `#5AC8FA`, Blue `#007AFF`, Indigo `#5856D6`, Purple `#AF52DE`, Pink `#FF2D55`

### 9.6 PhotoCropView

Full-screen. Black background. Square crop with darkened border overlay. Pinch-to-zoom, drag-to-pan. Crop/Cancel buttons.

---

## 10. Reusable Components

### HabitBlockView
Colored clay block in tower grid. 3-stop vertical gradient (lightTint → base → darkShade). Frosted overlay for depth. Shadow scales with tower height. Tap triggers squash/stretch + haptic. Sizes: 1×1, 2×1, 2×2.

### FlippableBlockView
Front: HabitBlockView. Back: Photo + stats. 3D flip animation. Patina gold tint for perfect days. Time text overlay.

### MiniBlockPreview
Small preview block. Aspect ratio from block size. Category gradient + frosted overlay. Optional title. Corner radius: 8pt.

### SkeletonBlockView
Loading placeholder. ShimmerModifier gradient sweep (1.5s cycle, 30 FPS cap, respects reduce motion).

### TimelineHabitRow
Category icon, title, time pill, completion ring (24pt, fill sweep 0.4s). Swipe-to-complete. Streak badge. HealthKit verification overlay.

### PlanItemRow
Category icon (44pt), editable title, metadata HStack (schedule, subtask count, chevron). Left-edge accent bar (4pt wide, orange when in progress). Expandable card: Time Hero + Metadata Pills + Steps/Actions.

### WeekProgressStrip
7 day circles (S-Sa). States: incomplete (empty), partial (half), complete (full). Cascade entrance animation.

### MorningBriefingCard
Time-of-day greeting (morning sun / afternoon cloud / evening moon). Habit count, first habit preview. Smart nudge for afternoon energy dip.

### AllClearCelebration
Canvas-based confetti. 24 particles, 2s duration. Mixed shapes: 40% rectangles, 30% circles, 30% strips. Category colors.

### MilestoneCelebration
Modal popup. Tier icon + badge color. Title, description. Auto-dismiss 3s.

### WarmBackground
Light: subtle warm vertical gradient. Dark: system bg + 2% warm overlay.

### FloatingBottomBar / TabBar
4 tabs: Tower (`square.stack.3d.up`), Today (`calendar`), Plan (`list.bullet.clipboard`), Insights (`chart.bar`).

---

## 11. Milestone System

### Types
- Block Count: 1, 10, 25, 50, 100, 250, 500, 1000
- Tower Height: 10m, 30m, 50m, 93m, 100m, 330m, 443m, 828m, 1000m
- Perfect Days: 1, 5, 10, 25, 50, 100
- Streak Length: 7, 14, 30, 66, 100, 365

### Named Height Comparisons
10m = Telephone Pole, 30m = 10-Story Building, 50m = Leaning Tower of Pisa, 93m = Statue of Liberty, 100m = Sequoia Tree, 330m = Eiffel Tower, 443m = Empire State Building, 828m = Burj Khalifa, 1000m = Stratosphere

---

## 12. Figma Component Checklist

When building the Figma file, create these as components with variants:

- [ ] **HabitBlock** — Variants: small/medium/hard × 6 categories × default/tapped/perfect-day
- [ ] **TimelineRow** — Variants: incomplete/completing/completed/skipped/healthkit
- [ ] **PlanRow** — Variants: collapsed/expanded × completed/active/skipped × routine/todo
- [ ] **DashboardCard** — Variants: today/tomorrow/inbox/done/next7/saved/inprogress × empty/populated
- [ ] **CategoryPill** — Variants: 6 categories × selected/unselected
- [ ] **DayCircle** — Variants: selected/unselected × incomplete/partial/complete
- [ ] **MiniBlock** — Variants: small/medium/hard × 6 categories
- [ ] **SkeletonBlock** — Variants: small/medium/hard (shimmer)
- [ ] **CompletionRing** — Variants: empty/filling/full (animated prototype)
- [ ] **StreakBadge** — Variants: 5 tiers
- [ ] **Section Header** — Variants: collapsed/expanded × system/custom
- [ ] **Snackbar** — Single variant (undo)
- [ ] **MorningCard** — Variants: morning/afternoon/evening
- [ ] **Confetti** — Static frame showing particle distribution

### Color Styles to Create
6 categories × 6 roles (base, lightTint, darkShade, border, glow, text) = 36 color styles
+ 4 system colors + 5 milestone colors + 6 opacity tokens + 2 background modes = 53 total

### Text Styles to Create
5 brand styles + 12 system styles = 17 text styles

### Effect Styles to Create
Ambient shadow (light + dark) + Block shadow (light + dark) + thinMaterial + regularMaterial = 6 effect styles
