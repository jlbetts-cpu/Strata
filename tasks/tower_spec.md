# Tower V2 — Execution Surface Spec

Living spec for the tower's expansion architecture, photo capture, and filmstrip system.

## Expansion Flow

1. **Block tap** → `FlippableBlockView.onTap` fires (all blocks, no branching)
2. `MainAppView` sets `expandedBlockID` with `heavySettle` spring
3. `matchedGeometryEffect` morphs block → `BlockExpansionCard`
4. `.ultraThinMaterial` scrim maintains spatial reference (Object Constancy)
5. Content fades in via `gentleReveal` after 0.15s delay
6. Drag-to-dismiss at >80pt threshold

### Why matchedGeometryEffect (not NavigationTransition)

- **Object Constancy** (Tversky 2002): Block IS the card — same identity through morph
- **Change Blindness prevention** (Rensink 1997): Scrim keeps tower visible
- **Spatial Memory** (Robertson 1998): In-place morph eliminates "where did I come from?" for ADHD users
- iOS 18's `matchedTransitionSource` targets NavigationStack push/pop, not overlay expansions

## Photo Capture

Photo capture lives on the **expansion card** (detail surface), not the block (summary surface).

- **Hick's Law**: One action per tap = zero decision time
- **Gulf of Evaluation** (Norman 1988): Card has more space and is the natural editing context
- PhotosPicker appears as centered camera icon + "Add Proof" when block has no photo

## Filmstrip Modes

| Mode | Data Source | Shows |
|------|-----------|-------|
| Today | `cachedDailyPhotoBlocks` | All photos from same date across habits |
| Journey | `cachedHabitPhotoBlocks` | This habit's photos across all dates (max 30, recent-first) |

- Mode toggle: segmented `Picker`, only shown when `habitPhotoBlocks` is non-empty
- Journey thumbnails include date label below (e.g. "3/19")
- Thumbnail size: 56x56 (Fitts' Law compliance)

## Photo Indicator Badge

- `photo.fill` SF Symbol, 8pt, top-right of block face
- `.white.opacity(0.5)` — subtle, not competing with content
- **Recognition over Recall** (Nielsen 1994): Users see which blocks have richer content

## Animation Budget (max 2 simultaneous)

| Moment | Animation 1 | Animation 2 | Total |
|--------|------------|------------|-------|
| Block tap → expand | `heavySettle` morph | — | 1 |
| Content appears | `gentleReveal` fade | — | 1 |
| Photo capture complete | `crossFade` hero swap | — | 1 |
| Filmstrip mode toggle | `crossFade` data swap | — | 1 |
| Thumbnail tap | `crossFade` hero swap | Title/time update | 2 |
| Dismiss drag | `heavySettle` morph | — | 1 |

## Verified Grid Constants (4pt Base Grid)

All tower layout values are divisible by 4. Apple HIG uses a 4pt base grid; 4, 8, 12, 16, 20, 24 are all valid. Sub-pixel strokes and shadow radii are exempt (visual effects, not spatial rhythm).

| Constant | Value | Grid Multiple |
|----------|-------|---------------|
| `GridConstants.spacing` | 8pt | 2×4 |
| `GridConstants.cornerRadius` | 16pt | 4×4 |
| `GridConstants.horizontalPadding` | 16pt | 4×4 |
| `GridConstants.headerTopPadding` | 12pt | 3×4 |
| `GridConstants.headerBottomPadding` | 8pt | 2×4 |
| TowerHeaderView VStack spacing | 8pt | 2×4 |
| TowerHeaderView HStack spacing (row 1) | 12pt | 3×4 |
| TowerHeaderView HStack spacing (row 2) | 8pt | 2×4 |
| Progress bar track height | 4pt | 1×4 |
| BlockContentOverlay VStack spacing | 4pt | 1×4 |
| TowerNextUpPill horizontal padding | 16pt | 4×4 |
| Tooltip pill horizontal padding | 12pt | 3×4 |
| Tooltip pill vertical padding | 4pt | 1×4 |

### Exempt (visual effects, not spatial)

- `headerDividerHeight: 0.5` — hairline divider
- `strokeWidth: 2.5` — border stroke
- `FlippableBlockView lineWidth: 2.5` — border stroke
- `.blur(radius: 6)` — blur effect
- Ground plane `.frame(height: 2)` — decorative
- Shadow offsets/radii — visual depth

### Ambient Animation Policy

Blocks are **still when idle** — no breathing shimmer, no micro-sway. All interaction physics preserved: tap bounce, drop squash/stretch, ripple compress, wobble settle.

## HCI Citations

- Hick (1952) — Decision time increases logarithmically with choices
- Paivio (1971) — Picture Superiority Effect (images remembered 6x better)
- Nielsen (1994) — Recognition over Recall heuristic
- Nunes & Dreze (2006) — Endowed Progress Effect
- Kurosu & Kashimura (1995) — Aesthetic-Usability Effect
- Norman (1988) — Gulf of Evaluation
- Tversky et al. (2002) — Object Constancy in animation
- Rensink et al. (1997) — Change Blindness
- Robertson et al. (1998) — Spatial Memory and ADHD
