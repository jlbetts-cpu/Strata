import SwiftUI

enum GridConstants {
    static let columnCount = 4
    static let spacing: CGFloat = 4
    static let cornerRadius: CGFloat = 8
    /// Habit blocks on tower + timeline.
    ///
    /// 12, not 16: Figma Apollo (248:14) uses a constant 40px radius at every
    /// block size, which against its 272px 1x1 block is 14.7% of the side —
    /// 12.7pt at an 86.5pt cell. 16 read noticeably rounder than the source when
    /// the two were put side by side at native size.
    static let blockCornerRadius: CGFloat = 12

    /// Reference cell the block proportions were drawn against — 4 columns on
    /// a 402pt screen. `blockCornerRadius` is 12 at this width, which is the
    /// Figma ratio; anywhere the cell is a different size the radius has to be
    /// scaled or it is a different shape. The Insights chart draws at up to
    /// 34pt, where a flat 12 is 35% of the side: a pill, not a block.
    static let blockReferenceCell: CGFloat = 86.5

    /// The block corner radius at a cell of any size.
    ///
    /// A block drawn smaller has to be drawn rounder-in-proportion, not
    /// rounder. `blockCornerRadius` is the value at `blockReferenceCell`; at a
    /// 34pt chart cell the same flat 12 is 35% of the side and reads as a pill.
    static func blockCornerRadius(forCell cellSize: CGFloat) -> CGFloat {
        blockCornerRadius * (cellSize / blockReferenceCell)
    }

    /// How long a finger has to rest on a block before it lifts.
    ///
    /// 0.4s, not the 0.35 this started at. Below about 0.4 a hold competes
    /// with the start of a scroll — the finger is often still for 300ms before
    /// a deliberate flick — and blocks were lifting when someone meant to
    /// scroll the tower. It is also comfortably above the ~0.25s that reads as
    /// a tap, so the tap-to-edit gesture is unaffected.
    static let liftHoldDuration: Double = 0.4
    static let cornerRadiusSmall: CGFloat = 8   // Pills, chips, badges
    static let cornerRadiusMicro: CGFloat = 4   // Matrix sparkline blocks, tiny indicators

    // MARK: - Radius Ladder (chrome)
    //
    // Derived from what the app already does rather than invented. Sheets and
    // expansion cards were 20; a form field or well was written as 14, 12 or 10
    // depending on the file; small controls were 8 and tiny marks 4. The field
    // rung is deliberately blockCornerRadius, so chrome and blocks agree.
    /// Sheets and expansion cards — surfaces that become the environment.
    static let radiusSurface: CGFloat = 20
    /// Cards, form fields, wells, pickers. Same value as blockCornerRadius.
    static let radiusField: CGFloat = 12
    /// Small controls, icon wells, drop indicators.
    static let radiusControl: CGFloat = 8
    /// Tiny marks — heatmap cells, day dots, bars.
    static let radiusMark: CGFloat = 4

    // MARK: - Neutral Fills (chrome)
    //
    // Hand-picked greys collapse to three jobs. Text opacities are NOT in here:
    // they are a separate axis and changing them risks legibility.
    /// Input backgrounds and wells (was 0.04 and 0.05 — the same intent twice).
    static let fillWell = Color.primary.opacity(0.04)
    /// Tracks, capsule grounds, unselected states.
    static let fillTrack = Color.primary.opacity(0.06)
    /// Hairlines and card strokes.
    static let fillHairline = Color.primary.opacity(0.08)
    static let horizontalPadding: CGFloat = 16
    static let headerTopPadding: CGFloat = 12
    static let headerBottomPadding: CGFloat = 8
    static let headerDividerOpacity: Double = 0.06
    static let headerDividerHeight: CGFloat = 0.5
    static let timelineGutterWidth: CGFloat = 56

    // 1 block height = 3 meters for altimeter
    static let metersPerBlock: Double = 3.0

    // Minimum scaffold blocks for new users
    static let minimumScaffoldBlocks = 12

    // MARK: - Stroke
    static let strokeWidth: CGFloat = 2.5

    // MARK: - Animation Springs
    static let dropSquashSpring = Animation.spring(response: 0.12, dampingFraction: 0.60)
    static let dropStretchSpring = Animation.spring(response: 0.18, dampingFraction: 0.65)
    static let dropSettleSpring = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let rippleCompressSpring = Animation.spring(response: 0.12, dampingFraction: 0.55)
    static let rippleReleaseSpring = Animation.spring(response: 0.35, dampingFraction: 0.60)

    // MARK: - Squash & Stretch (linear in mass — rigid material)
    // Impact deformation. Raised along with the fall duration: a block that is
    // now visibly falling has visible momentum, and landing without deforming
    // reads as stopping rather than as arriving.
    static func squashScaleY(mass: CGFloat) -> CGFloat { 0.042 * mass }
    static func squashScaleX(mass: CGFloat) -> CGFloat { 0.026 * mass }
    static func stretchScaleY(mass: CGFloat) -> CGFloat { 0.020 * mass }
    static func stretchScaleX(mass: CGFloat) -> CGFloat { 0.013 * mass }

    // MARK: - Shadow

    /// Single soft ambient shadow for depth
    static let shadowRadius: CGFloat = 4
    static let shadowY: CGFloat = 2
    static let shadowOpacity: Double = 0.10

    // MARK: - Adaptive Shadow
    static func adaptiveShadowOpacity(_ base: Double, colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? min(base * 3.5, 0.60) : base
    }

    // MARK: - Tap Bounce
    static let tapSquashSpring = Animation.spring(duration: 0.06, bounce: 0.0)
    static let tapPopSpring = Animation.spring(duration: 0.22, bounce: 0.20)
    static let tapScaleX: CGFloat = 1.02
    static let tapScaleY: CGFloat = 0.97

    // MARK: - Wobble Settle
    static let wobbleSpring = Animation.spring(response: 0.18, dampingFraction: 0.65)
    static let wobbleDegreesLight: Double = 0.8
    static let wobbleDegreesHeavy: Double = 1.5

    // Compute the cell size (1x1 square side) from the available grid width
    static func cellSize(forGridWidth gridWidth: CGFloat) -> CGFloat {
        // gridWidth = (columnCount * cellSize) + ((columnCount - 1) * spacing)
        // cellSize = (gridWidth - (columnCount - 1) * spacing) / columnCount
        let totalSpacing = CGFloat(columnCount - 1) * spacing
        return floor((gridWidth - totalSpacing) / CGFloat(columnCount))
    }

    // Frame for a block given its grid position and computed cell size
    static func blockFrame(column: Int, row: Int, columnSpan: Int, rowSpan: Int, cellSize: CGFloat) -> CGRect {
        let x = CGFloat(column) * (cellSize + spacing)
        let y = CGFloat(row) * (cellSize + spacing)
        let w = CGFloat(columnSpan) * cellSize + CGFloat(columnSpan - 1) * spacing
        let h = CGFloat(rowSpan) * cellSize + CGFloat(rowSpan - 1) * spacing
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // Total grid height for N rows
    static func gridHeight(rows: Int, cellSize: CGFloat) -> CGFloat {
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * cellSize + CGFloat(rows - 1) * spacing
    }

    // Total grid width for the column count
    static func gridWidth(cellSize: CGFloat) -> CGFloat {
        CGFloat(columnCount) * cellSize + CGFloat(columnCount - 1) * spacing
    }

    // MARK: - Semantic Springs (reusable motion vocabulary)

    /// Pop-back — matches tapPopSpring
    static let snapBack = Animation.spring(duration: 0.22, bounce: 0.20)
    /// Content appearing
    static let gentleReveal = Animation.spring(response: 0.22, dampingFraction: 0.85)
    /// Settling — matches dropSettleSpring, reusable
    static let naturalSettle = Animation.spring(response: 0.28, dampingFraction: 0.78)
    /// Large elements settling
    static let heavySettle = Animation.spring(response: 0.28, dampingFraction: 0.80)
    /// Small celebratory bounces
    static let elasticPop = Animation.spring(response: 0.25, dampingFraction: 0.50)
    /// Bars, rings filling
    static let progressFill = Animation.spring(response: 0.25, dampingFraction: 0.70)
    /// Major layout changes (filter transitions, block expansion)
    static let layoutReflow = Animation.spring(response: 0.55, dampingFraction: 0.90)
    /// Non-spatial transitions (cross-fades)
    static let crossFade = Animation.easeInOut(duration: 0.2)
    /// Cascade reveal — new blocks dropping into tower
    static let cascadeReveal = Animation.spring(response: 0.50, dampingFraction: 0.65)

    // MARK: - Today Screen Motion (Timeline Claude)

    /// Tap feedback, check circles — fast, clean
    static let motionSnappy = Animation.spring(response: 0.25, dampingFraction: 0.82)
    /// Content transitions, schedule confirm, row state changes
    static let motionSmooth = Animation.spring(response: 0.22, dampingFraction: 0.78)
    /// Container changes, collapse/expand
    static let motionGentle = Animation.spring(response: 0.40, dampingFraction: 0.85)
    /// Completion settle, end-of-sequence
    static let motionSettle = Animation.spring(response: 0.28, dampingFraction: 0.90)
    /// Reduced motion fallback
    static let motionReduced = Animation.easeOut(duration: 0.05)
    /// Fill sweep duration
    static let fillSweepDuration: TimeInterval = 0.4

    /// Toggle/picker transitions (NewHabitMenu, PlanItemRow)
    static let toggleSwitch = Animation.spring(response: 0.30, dampingFraction: 0.80)

    // MARK: - Slot resize
    /// The snap when the next slot changes size under your finger.
    ///
    /// Faster and slightly springier than `motionSnappy`, because it fires
    /// while you are still dragging: it has to finish before your finger moves
    /// far enough to ask for the next one, or the sizes queue up behind you.
    /// Critically damped, per docs/apple-design.md: overshoot belongs to
    /// motion that momentum caused. Crossing a size threshold mid-drag is a
    /// reposition, not a throw, and a bounce there reads as the slot being
    /// unsure. Response sits at the fast end of Apple's 0.3-0.4 for moves,
    /// because this has to land before the finger asks for the next size.
    static let slotSnap = Animation.spring(response: 0.30, dampingFraction: 1.0)
    /// Drag distance that commits the next size up.
    static let slotStep: CGFloat = 46
    /// Deadband on the way back down.
    ///
    /// Without it, holding a finger still on a threshold flickers the slot
    /// between two sizes on the small tremors of a real hand. Growing at 46 and
    /// shrinking at 34 means a size, once taken, has to be given back
    /// deliberately.
    static let slotStepHysteresis: CGFloat = 12
    /// The bloom left behind when a block is released from the slot. In fast,
    /// out slow — light arrives at once and decays.
    /// The size of the big number in a page header.
    ///
    /// One constant, because the tower and the camera show the same count and
    /// it must not change size between them.
    static let tallyNumeral: CGFloat = 64
    /// The word beside it. Sized with the numeral rather than left at a body
    /// size, or the pair stops reading as one object as the numeral grows.
    static let tallyWord: CGFloat = 24

    // MARK: - The tower's dance

    /// A wave that travels up the tower on every tenth win.
    ///
    /// A celebration is one of the few places bounce is earned: something
    /// travelled through the stack, so the stack may overshoot a little. It is
    /// still small — this is the tower enjoying itself, not the tower coming
    /// apart. apple-design.md §11 still applies at the top of a tall stack.
    static let danceRise = Animation.spring(response: 0.30, dampingFraction: 0.52)
    static let danceSettle = Animation.spring(response: 0.40, dampingFraction: 0.78)
    static let danceLift: CGFloat = -10
    static let danceTilt: Double = 2.4
    static let danceGlow: Double = 0.05
    /// Gap between one row starting to rise and the next, so the wave reads as
    /// travelling rather than as the whole tower twitching at once.
    static let danceRowDelay: Double = 0.045
    /// The wave crosses the tower in at most this long, however tall it is.
    static let danceTravelCap: Double = 0.90
    /// One dance per this many wins.
    static let danceEvery: Int = 10

    /// How far above the top of the screen a block starts its fall.
    ///
    /// The block has to come from somewhere, and "somewhere" has to be off
    /// screen. Starting it a fixed distance above its SLOT meant that on a
    /// short tower — where the slot sits low — the block appeared in the lower
    /// half of the screen and read as coming up from the bottom.
    static let dropClearance: CGFloat = 24

    /// Gravity, in points per second squared.
    ///
    /// The fall is a real constant-acceleration drop rather than a duration:
    /// `t = sqrt(2d/g)`. That is what makes it consistent no matter how far the
    /// block has to come — a longer fall takes longer and arrives faster, which
    /// is the one model every viewer already knows. Tuned so a typical 400pt
    /// fall takes about 0.44s.
    static let dropGravity: CGFloat = 4200

    /// Bounds on the fall time, so an empty tower does not become a wait and a
    /// full one still reads as a fall.
    static let dropDurationRange: ClosedRange<Double> = 0.34...0.72

    /// Constant acceleration as a timing curve: this is `y = t²` exactly at the
    /// midpoint. The fall used to ease OUT at the end — "air resistance" — which
    /// is the one thing a falling object does not do. Arriving at peak speed is
    /// what makes the landing land.
    static let dropFallCurve = Animation.timingCurve(1.0 / 3, 0, 2.0 / 3, 1.0 / 3, duration: 1)

    /// Empty space reserved above the tower for a block to fall through.
    ///
    /// Reserving it inside the scrollable content is what makes the fall the
    /// same every time. Without it the runway was whatever happened to be
    /// on screen, so the distance depended on the scroll position and the fall
    /// varied more than fourfold at a fixed duration — the same drop read as a
    /// plummet or as a spawn depending on where the tower was sitting.
    ///
    /// Costs nothing to look at: the tower is bottom-anchored, so this is space
    /// that was already empty.
    static let dropRunway: CGFloat = 180
    static let slotBloomIn = Animation.easeOut(duration: 0.10)
    static let slotBloomOut = Animation.easeOut(duration: 0.45)

    /// Deceleration rate for momentum projection (docs/apple-design.md §6).
    ///
    /// 0.998 is the scroll-like default; lower is snappier. Chosen by working
    /// out where realistic gestures actually land, because the slot has only
    /// three stops a few dozen points apart and a scroll-sized projection
    /// overshoots all of them:
    ///
    ///                          0.998      0.994      0.990
    ///   slow nudge  (20pt, 120)  Regular    Small      Small
    ///   drag+hold   (50pt,   0)  Regular    Regular    Regular
    ///   brisk flick (20pt, 600)  Deep       Deep       Regular
    ///   hard flick  (20pt,1400)  Deep       Deep       Deep
    ///
    /// At 0.998 anything but a crawl reaches Deep. At 0.994 a brisk flick still
    /// skips Regular, so Regular is only reachable by dragging. 0.990 is the
    /// rate at which all three sizes can be reached by flicking AND by
    /// dragging, which is what makes the projection assist the choice instead
    /// of taking it.
    static let slotDecelerationRate: Double = 0.990

    /// Where a flick would come to rest, given the velocity it was released at.
    ///
    /// The exponential-decay form Apple ships, NOT the textbook v²/(2a) —
    /// docs/apple-design.md is explicit that they differ and which one feels
    /// right.
    static func project(velocity: CGFloat,
                        decelerationRate d: Double = slotDecelerationRate) -> CGFloat {
        (velocity / 1000) * CGFloat(d / (1 - d))
    }

    /// Progressive resistance past a boundary (docs/apple-design.md §9).
    ///
    /// A hard stop reads as frozen. This lets the drag keep moving while
    /// giving back less and less, which reads as "responsive, but there is
    /// nothing more here".
    static func rubberband(overshoot: CGFloat, dimension: CGFloat,
                           constant: CGFloat = 0.55) -> CGFloat {
        (overshoot * dimension * constant) / (dimension + constant * abs(overshoot))
    }
    /// Skeleton pop-in during loading
    static let skeletonPop = Animation.spring(response: 0.35, dampingFraction: 0.65)

    // MARK: - Card Detail (Tower Claude)

    /// Card open/close morph — snappy, no overshoot (Apple .snappy damping)
    static let cardMorph = Animation.spring(response: 0.35, dampingFraction: 0.86)
    /// Card content fade-in — slightly softer for staggered entrance
    static let cardReveal = Animation.spring(response: 0.40, dampingFraction: 0.88)
    /// Expansion card corner radius
    static let cardCornerRadius: CGFloat = 20
    /// Expansion card internal content padding (Apple HIG expanded card standard)
    static let cardContentPadding: CGFloat = 20
    /// Expansion card content group spacing
    static let cardContentSpacing: CGFloat = 16

    // MARK: - Filmstrip
    static let filmstripThumbnailSize: CGFloat = 56
    static let filmstripSpacing: CGFloat = 8

    // MARK: - Icon Sizes
    static let iconSmall: CGFloat = 8      // badges, chevrons, photo indicators
    static let iconMedium: CGFloat = 12    // next-up pill icons
    static let iconCategory: CGFloat = 13  // category icons on blocks
    static let iconAction: CGFloat = 14    // action buttons (close X, replace photo)
    static let iconToolbar: CGFloat = 17   // toolbar icons (gear)
    static let iconEmptyState: CGFloat = 36 // empty state hero icons
    static let iconHero: CGFloat = 40      // large hero elements
    static let iconChevron: CGFloat = 10   // next-up pill chevron

    // MARK: - Block Patina (Perfect-Day Gold Tint)
    static let patinaMaxOpacity: Double = 0.15
    static let patinaGrowthRate: Double = 0.02
    static let patinaGold = Color(red: 0.95, green: 0.80, blue: 0.40)

    // MARK: - Celebration (Phase 2)
    static let celebrationBurst = Animation.spring(response: 0.30, dampingFraction: 0.60)
    static let confettiDuration: TimeInterval = 2.0
    static let confettiParticleCount: Int = 24
    static let blockFlyaway = Animation.spring(response: 0.55, dampingFraction: 0.70)

    // MARK: - Momentum Escalation
    static let fillSweepFast: TimeInterval = 0.28
    static let fillSweepMedium: TimeInterval = 0.32
    static let fillSweepEarly: TimeInterval = 0.36

    // MARK: - Spatial Tower (Phase 3)
    static let depthShadowScale: CGFloat = 0.2      // Reduced: stronger base shadow needs less accumulation
    static let depthShadowYScale: CGFloat = 0.10
    static let breathingCycleDuration: TimeInterval = 3.0
    static let breathingIntensity: Double = 0.015
    static let ghostBlockOpacity: Double = 0.06
    static let ghostBlockPulseMin: Double = 0.04
    static let ghostBlockPulseMax: Double = 0.10
    static let ghostBlockDashLength: CGFloat = 4

    // MARK: - Connected Flow (Phase 4)
    static let staggerInterval: TimeInterval = 0.04
    static let staggerMax: TimeInterval = 0.4
    static let entranceOffset: CGFloat = 12
    static let ambientGlowCycle: TimeInterval = 2.5
    static let ambientGlowIntensity: Double = 0.08

    // MARK: - UI Elements
    // MARK: - Block Shadow (post-border-removal, stronger)
    // MARK: - Block Rim (Figma Apollo 248:14)
    //
    // The block already carried a frosted band and a flat white strip along the
    // bottom. This makes that edge a real rim: uniform on all four sides, crisp
    // above the band and blurred inside it, which is how the source builds it —
    // one solid white border (255:105) under a separate backdrop-blur rect
    // covering the bottom 26% (255:106).
    /// White rim. Figma draws 5px on a 562pt block (0.89%) — 0.77pt at an 86.5pt
    /// cell; 0.8 is 2.4 device px at 3x and renders crisp.
    static let blockRimWidth: CGFloat = 1.4
    /// How much of the rim's white survives below the top edge. The rim is a
    /// highlight, not an outline: full white where the light lands, less
    /// everywhere else.
    static let blockRimFalloff: Double = 0.45
    /// Darkening at the top edge of a block that is carrying another one.
    /// Subtle on purpose: it should be felt as weight, not seen as a stripe.
    static let blockContactShade: Double = 0.11
    /// An unnamed win's surface. White, and translucent enough that the warm
    /// ground reads through it — the block is there without claiming a colour
    /// it has not been given.
    static let blockUnnamedOpacity: Double = 0.52
    /// Blur inside the band. Figma blurs 10px on a 562pt block — 1.78% of width.
    static let blockRimBlur: CGFloat = 1.5
    /// Fraction of block height where the frosted band begins (Figma's 145pt of 565).
    static let blockBandStart: Double = 0.74
    /// The sharp and blurred copies crossfade across this span rather than cutting
    /// hard. Blurring softens a surface's alpha at its edges, so a hard cut makes
    /// the silhouette visibly pinch in at 86pt.
    static let blockBandFeatherStart: Double = 0.66
    static let blockBandFeatherEnd: Double = 0.74
    /// Frosted white wash inside the band.
    ///
    /// Figma's 0.2 put ~22% white into the bottom of every block, which read as
    /// the block fading out rather than as a frosted edge. Halved: the band is
    /// still there and still catches the blurred rim, but the colour stays
    /// colour all the way down.
    static let blockScrimOpacity: Double = 0.10

    // MARK: - Ghost (incomplete) tier
    /// The rim carries the category colour instead of white, and has to define
    /// the shape against a near-white ground on its own, so it is heavier than
    /// the filled block's 0.8pt white rim.
    static let blockGhostRimWidth: CGFloat = 1.5
    static let blockGhostRimOpacity: Double = 0.45

    static let blockShadowRadius: CGFloat = 5
    static let blockShadowY: CGFloat = 2.5
    static let blockShadowOpacity: Double = 0.12
    static let blockShadowOpacityDark: Double = 0.20

    static let checkCircleSize: CGFloat = 24

    // MARK: - Height-Progressive Shadow (#12)
    /// Cap shadow radius at high row counts to prevent oversized shadows
    static let maxDepthShadowRadius: CGFloat = 12

    static func depthShadow(row: Int) -> (radius: CGFloat, y: CGFloat) {
        let r = min(shadowRadius + CGFloat(row) * depthShadowScale, maxDepthShadowRadius)
        let y = shadowY + CGFloat(row) * depthShadowYScale
        return (r, y)
    }

    /// Height-progressive shadow opacity: higher blocks cast slightly stronger shadows (#12)
    static func depthShadowOpacity(row: Int) -> Double {
        let base: Double = 0.04
        return min(base + Double(row) * 0.001, 0.06)
    }

    // MARK: - Semantic Opacity (Today Screen Overhaul Batch 10)
    static let opacityGhost: Double = 0.06       // Backgrounds, decorative fills
    static let opacitySubtle: Double = 0.12      // Borders, dividers, secondary bg
    static let opacityMuted: Double = 0.25       // De-emphasized, disabled
    static let opacitySecondary: Double = 0.50   // Secondary text, icons
    static let opacityPrimary: Double = 0.70     // Primary text on colored bg
    static let opacityFull: Double = 1.0         // Full strength

    // MARK: - Stroke Widths
    static let strokeThin: CGFloat = 1.0
    static let strokeDefault: CGFloat = 1.5
    static let strokeMedium: CGFloat = 2.0
}
