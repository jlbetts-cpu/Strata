# Strata — Brand Language (Single Source of Truth)

> Every bot MUST read this before making visual changes. All values are extracted from the codebase and are authoritative.

## Aesthetic North Star
**Premium "Bento Box" habit tracker for neurodivergent (ADHD) users.** Harmonious, beautiful, highly consistent. Unbelievably premium without being overwhelming or chaotic. Muted container, saturated focal points. Max 2 simultaneous animations.

## Competitive Positioning
**"The habit tracker that respects your brain."** Strata competes on visual craft (9/10 vs market avg 7), ADHD support (8/10, highest in category), and the unique spatial tower metaphor (no competitor has anything similar). We do NOT compete on feature breadth (TickTick), social features (Habitica), or cross-platform (Todoist). We win by being the most thoughtful, most beautiful, most ADHD-friendly habit tracker on iOS.

**Unique moat:** 6 features no competitor offers — spatial tower, mass-based physics, skip-as-decision, hold-to-complete ritual, photo proof-of-work, per-habit grace days.

**Critical gaps to close:** Notifications (table stakes), insights dashboard, widgets, onboarding, cloud sync. These 5 features would move Strata from 6th to 3rd in the market.

---

## Color Palette

### App Colors (`AppColors` in CategoryColors.swift)
| Name | Hex | SwiftUI | Use |
|------|-----|---------|-----|
| warmBlack | #403D39 | `AppColors.warmBlack` | Primary dark, tab bar tint |
| accentWarm | #403D39 | `AppColors.accentWarm` | Selection fills |
| accentPurple | #A689FA | `AppColors.accentPurple` | Accent highlights |
| healthGreen | #34C48B | `AppColors.healthGreen` | Completion rings, success |
| warmRed | #E85D4A | `AppColors.warmRed` | Now indicator, NEXT badge |
| ghostBase | RGB(0.94, 0.93, 0.92) | `AppColors.ghostBase` | Incomplete block bg (light) |
| ghostBaseDark | #4A4740 | `AppColors.ghostBaseDark` | Incomplete block bg (dark) |

### Backgrounds (`WarmBackground.swift`)
| Mode | Value |
|------|-------|
| Light | RGB(0.98, 0.975, 0.965) — warm cream |
| Dark | `Color(uiColor: .systemBackground)` — native iOS black (was #403D39) |

### Category Colors (6 categories)
| Category | Base | Light Tint | Dark Shade |
|----------|------|-----------|-----------|
| Health | #10B77F | #3CCFA0 | #0D9A6B |
| Work | #40A9FF | #6DC0FF | #2E8BE6 |
| Creativity | #AF9CFA | #C4B5FF | #826DD0 |
| Focus | #FDB54F | #FEC873 | #D99A3A |
| Social | #14D4C1 | #42E0D2 | #10B3A3 |
| Mindfulness | #EC85B4 | #F2A0C8 | #C86B98 |

---

## Typography (`Typography.swift`)

**Font family:** SF Pro Rounded (system)

| Token | Weight | Text Style |
|-------|--------|-----------|
| appTitle | Medium | .largeTitle |
| headerLarge | Medium | .title3 |
| headerMedium | Medium | .headline |
| headerSmall | Medium | .subheadline |
| bodyLarge | Regular | .body |
| bodyMedium | Regular | .callout |
| bodySmall | Regular | .footnote |
| caption | Regular | .caption |
| caption2 | Medium | .caption2 |
| blockTitle | Medium | .callout |

All tokens use `Font.system(design: .rounded)` for proper Dynamic Type scaling. No manual kerning needed (SF Rounded has built-in optical kerning).

---

## Layout (`GridConstants.swift`)

### Spatial Grid (4pt/8pt System)
- **4pt base unit** — all spacing values are multiples of 4
- **8pt primary grid** — standard spacing, section gaps, padding
- **16pt secondary** — cornerRadius, horizontal padding, section indentation
- **20pt** — Today screen horizontal padding (wider for readability)

| Constant | Value | Use |
|----------|-------|-----|
| cornerRadius | 16pt | All blocks, cards, containers |
| spacing | 8pt | Grid gaps, standard spacing |
| horizontalPadding | 16pt | Tower grid. Today list uses 20pt. |
| timelineGutterWidth | 56pt | Today screen time label column |
| strokeWidth | 2.5pt | Block border glow |
| shadowRadius | 4pt | Ambient shadow |
| shadowY | 2pt | Shadow vertical offset |
| shadowOpacity | 0.10 | Light mode base. Dark: min(base × 3.5, 0.60) |

### Category Color Semantics
Each category color carries psychological meaning aligned with its domain:
- **Health** (coral) — vitality, physical energy, body awareness
- **Work** (blue) — focus, reliability, professional clarity
- **Creativity** (purple) — expression, imagination, artistic flow
- **Focus** (amber) — alertness, sustained attention, mental clarity
- **Social** (pink) — connection, warmth, interpersonal engagement
- **Mindfulness** (green) — calm, presence, inner peace

---

## Motion System (`GridConstants.swift`)

### Semantic Springs (use these, never inline `.spring(...)`)
| Token | Response | Damping | Use |
|-------|----------|---------|-----|
| motionSnappy | 0.25 | 0.82 | Taps, check circles, toggles |
| motionSmooth | 0.30 | 0.78 | Content transitions, confirms |
| motionGentle | 0.40 | 0.85 | Container expand/collapse |
| motionSettle | 0.50 | 0.90 | Completion settle, end-of-sequence |
| motionReduced | easeOut 0.05s | — | reduceMotion fallback |
| progressFill | 0.60 | 0.70 | Bars, rings filling |
| elasticPop | 0.25 | 0.50 | Celebratory bounces |
| crossFade | easeInOut 0.2s | — | Non-spatial transitions |

### Rules
- **Primary action:** 200-300ms
- **Secondary follow:** +60ms stagger
- **Entry > Exit:** 300ms in, 200ms out
- **Max 2 simultaneous animations** (ADHD research)
- **Always respect `accessibilityReduceMotion`** via `anim()` helper

---

## Haptics (`HapticsEngine.swift`)

| Method | When to use |
|--------|-----------|
| `tick()` | Selection changes (day tap, filter, picker) |
| `lightTap()` | Subtle confirms (collapse, skip, undo) |
| `snap()` | Decisive actions (complete, commit, drawer toggle) |
| `success()` | Achievements (all done, milestone) |
| `reward()` | Reserved — currently unused |
| `squish(mass:)` | Tower block landings (mass-dependent) |
| `cascade(index:)` | Cascade sequence (escalating) |

**Rule:** Never use inline `UIImpactFeedbackGenerator` or `UISelectionFeedbackGenerator`. Always use `HapticsEngine` methods.

---

## Block Visual Tiers

| State | Fill | Border | Shadow | Opacity | Saturation |
|-------|------|--------|--------|---------|-----------|
| **Incomplete (ghost)** | ghostBase + 8% category wash | Category color 0.5 opacity, 1.5pt | None | 1.0 | 1.0 |
| **Completed (dimmed)** | Full category gradient | White 0.3, 1.5pt | Ambient (GridConstants) | 0.55 | 0.7 |
| **Tower block** | Full category gradient | Progressive dual glow + breathing | Dual-layer | 1.0 | 1.0 |

---

## Accessibility Standards (Research-Backed)

### Interaction Standards
- **Haptic coverage target:** 90%+ of user interactions must have a corresponding `HapticsEngine` call (Schultz 2024 — micro-dopamine reinforcement for ADHD habit loops)
- **Touch target minimum:** 44pt × 44pt for all interactive elements (Nielsen 2010 — <44pt targets cause >5% error rates; ADHD motor planning deficits amplify this — Barkley 2012)
- **Destructive action rule:** All deletions require `.confirmationDialog` before executing (Norman 2013 — error recovery; ADHD impulsivity increases accidental actions)

### Color & Contrast
- **Color encoding rule:** NEVER use color as the sole differentiator. Always provide icon + color redundant encoding (Treisman 1980 — pre-attentive processing; WCAG 1.4.1; 8% of males are colorblind)
- **Text contrast:** WCAG AA minimum (4.5:1 for normal text, 3:1 for large text). Ghost blocks intentionally below this for ambient background treatment — document the trade-off.
- **Dark mode:** All opacity values must be tested in both color schemes. Use `colorScheme == .dark` guards where opacity differs.

### Cognitive Load (Sweller 1988, Miller 1956)
- **Primary element budget:** Max 7 simultaneously visible primary interactive elements per screen region (Miller's 7±2 rule; modern research suggests 4±1 for complex tasks)
- **Progressive disclosure:** Use DisclosureGroup, collapsible sections, and Menu pickers to hide secondary options until needed (Iyengar & Lepper 2000 — choice overload above 5-7 options causes abandonment)
- **Time anchoring (ADHD-critical):** Every time-sensitive screen must have a visible "now" anchor — current time marker, "NEXT" badge, or relative time label (Barkley 2015 — ADHD time-blindness requires external temporal cues)

### Motion & Animation
- **reduceMotion:** Every animated view must read `@Environment(\.accessibilityReduceMotion)` and provide a static fallback. Use the `anim()` helper pattern.
- **Animation budget:** Max 2 simultaneous animated properties per view. No `.repeatForever()` loops except breathing (which must stop in `.onDisappear`).
- **Spring tokens:** All animations must use GridConstants semantic tokens. No inline `.spring(response:dampingFraction:)` calls.

### Screen Reader (VoiceOver)
- **Labels:** Every interactive element needs `.accessibilityLabel()` describing its content
- **Hints:** Actions need `.accessibilityHint()` describing what will happen on activation
- **Sort priority:** Complex layouts (tower grid, habit lists) need `.accessibilitySortPriority()` for logical reading order
- **Escape actions:** Modals and sheets need `.accessibilityAction(.escape)` for keyboard dismissal

---

## Performance Standards

### Render Targets
- **Frame budget:** <16ms per frame (60fps minimum, 120fps target on ProMotion)
- **Scroll render:** Use `LazyVStack`/`LazyVGrid` for any list exceeding 20 items
- **Viewport culling:** Tower grid must cull off-screen blocks (threshold: 30 blocks)
- **Layer flattening:** Complex stacks (4+ layers) must use `.compositingGroup()` or `.drawingGroup()`

### Query Standards
- **SwiftData @Query:** Always include `#Predicate` to scope fetches. Never fetch all records unfiltered.
- **fetchLimit:** Use when only a subset is needed (e.g., today's logs, not full history)
- **Index by date:** Use `logsByDate` dictionary pattern for O(1) lookups instead of repeated O(n) filters

### Computation Budgets
- **refreshData() total:** <50ms for 3,000 logs + 100 habits
- **Per-row computation:** O(1) or O(log n) — never O(m²) per row
- **Cache expensive results:** Memoize sort/filter results in @State, recompute only on explicit data change
- **Debounce rapid triggers:** Use 500ms debounce for onChange handlers that fire during batch operations

### Animation Budget
- **Max simultaneous:** 2 animated properties per view
- **Blur limit:** `.blur(radius:)` is expensive — use sparingly, reduce radius on dense layouts
- **No continuous loops:** `.repeatForever()` only for breathing (must stop in `.onDisappear`)
