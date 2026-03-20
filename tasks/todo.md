# Strata — Current Status

## Completed

- **Tower block design pass** — Softer shadows, matte ceramic bevels (TileBevelShape), warm background, 16pt squircle corners, refined warmer palette
- **Unified footer pill** — Single glass element: tab bar at collapsed, sheet at expanded, seamless morph transition
- **Universal tile highlights** — Replaced dynamic exposure with static L-shaped bevel shape, eliminated corner artifacts
- **Footer & timeline design pass** — Brought sheet chrome, week strip, timeline rows, and hour grid up to the same elevated standard as tower blocks:
  - Sheet: subtler drag indicator (40×4, 0.2 opacity), 28pt glass radius, lighter dividers
  - Week strip: health green (0x34C48B) replacing neon brandMint, thinner 2.5pt ring strokes
  - Timeline rows: radial specular highlight (not linear gloss), neutral two-layer shadows matching tower, 28pt check circle, removed false-affordance chevron, 16pt morph radius for seamless transitions
  - Hour grid: recessive labels (0.4 opacity), hairline dividers (0.05/0.33pt), warm red now-indicator (0xE85D4A)
  - Snap-back spring tuned to 0.8 damping for decisive feel

- **Block Figma matching (Round 1)** — Gradient fill, soft border, overlay removal to match Figma target
- **Block Figma matching (Round 2)** — 3-stop diagonal gradient (lightTint top 30%), outward border glow via overlay, frosted overlay reduced to near-invisible (0.06 opacity)
- **Block Figma matching (Round 3)** — Top-lit gradient border glow (thicker 2.5pt stroke, stronger blur radius 4, top-bright 0.85 opacity), 8px block spacing
- **Block Figma matching (Round 4)** — Two-overlay progressive border glow (crisp top, diffused bottom), 20% frosted gradient overlay
- **Squishy Silicone Block Animations** — Full animation overhaul for Bento Box aesthetic: squash/stretch drop phases, silicone press on tower blocks, breathe idle animation, soft haptics
- **TowerAnimationCoordinator extraction** — Moved animation state (drop phases, ripple, cascade) out of MainAppView into dedicated coordinator
- **Architecture cleanup** — ContentView reduced to thin wrapper, removed BottomBarView and TimelineSheetView, added SheetContentView
- **Dynamic block drop offset** — Blocks fall from top of visible screen instead of hardcoded -600pt offset; scroll clip disabled so blocks render above content bounds
- **Block interaction polish** — Silicone press animation, breathe idle animation, time text on blocks, photo overlay improvements
- **Timeline zoom persistence** — `@AppStorage` for pixelsPerMinute so zoom level survives app restarts
- **Warm color palette refinements** — Updated CategoryColors, Typography scale adjustments
- **Native Liquid Glass tab bar** — Separated "+" button pinned to trailing edge via `role: .search` (Apple Music pattern), renamed Journal → Insights with `chart.bar.xaxis` icon

- **Warm grey color pass** — Replaced all blacks (#000) with warm grey (#403D39), swapped blue accent (#648BF2) → warm grey, removed tab bar scroll gradient, updated AccentColor asset, added filled tab icons for selected state
- **Filled/hollow tab icons** — Wired `selectedIcon` into tab bar labels so selected tabs show filled icons and unselected show outlines; set `unselectedItemTintColor` to warm grey (#403D39) for consistent tinting

- **Tab bar minimization & tighter grid** — Added `.tabBarMinimizeBehavior(.onScrollDown)` so tab bar auto-shrinks on scroll, softened unselected tab tint to 0.45 opacity, reduced block spacing from 8pt to 4pt

- **Selected tab accent color & labels restored** — Set AccentColor to work blue (`0x40A9FF`) so selected tab icons/labels render in blue instead of warm grey; removed `.labelStyle(.iconOnly)` to restore text labels under all 5 tab icons

- **Tower filter pill (Day/Week/Month)** — Apple Photos-style segmented picker at top of tower tab. Day shows today's blocks with time labels, Week shows current week with date labels (e.g. "3/19"), Month shows full month with date labels. Native `Picker(.segmented)`, environment-driven block text switching, query widened to month with client-side filtering.

- **Dynamic footer clearance** — Made `footerClearance` responsive to tab bar state: 74pt when expanded (icons + labels visible), 62pt when collapsed (scroll), so the last block row always clears the FloatingBottomBar with a consistent gap

## Next Up

- Dark mode audit across all new opacity values
- Accessibility review (dynamic type, VoiceOver, reduce motion)
- Insights tab implementation
- Profile tab implementation
