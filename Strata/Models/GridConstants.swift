import SwiftUI

enum GridConstants {
    static let columnCount = 4
    /// The tower's gutter, and ONLY the tower's.
    ///
    /// 4pt is deliberately tight because blocks that touch read as one built
    /// object — that is the whole effect the tower is after. It is the wrong
    /// number for anything that is a set of separate things, and it had leaked
    /// into the photo gallery, where three photographs 4pt apart read as
    /// cramped rather than as stacked. Use the `gap` scale below for those.
    nonisolated static let spacing: CGFloat = 4

    // MARK: - The spacing scale
    //
    // Everything that is not the tower's gutter comes from here. There were
    // thirteen distinct hard-coded values across the views — 2, 4, 5, 6, 7, 8,
    // 10, 12, 14, 16, 18, 24 — which is not a rhythm, it is an absence of one.
    //
    // Four steps on a 4pt grid, and nothing between them. If a layout wants a
    // number that is not here, the answer is almost always the nearest step.

    /// Between things that belong to each other — a glyph and its label.
    static let gapTight: CGFloat = 8
    /// Between items in a set — photographs in a grid, chips in a row.
    static let gapItem: CGFloat = 12
    /// Between a heading and what it heads.
    static let gapLabel: CGFloat = 16
    /// Between one section and the next.
    /// Between a header and the block of content under it.
    ///
    /// **Named because the app was already using it, three times, unnamed.**
    /// A rung that exists in practice and not in the ladder is how a ladder
    /// rots: the next person picks 22 or 26 because nothing says otherwise.
    static let gapWide: CGFloat = 24

    static let gapSection: CGFloat = 32

    /// **Between one SUBJECT and the next.** The page's own breath, and the
    /// biggest gap anything on a screen is allowed to take.
    ///
    /// Added 2026-10-01, with check 11 of `docs/screen-audit.md`. The owner,
    /// twice: "make sure it leaves room like a lot of white space", and
    /// "remember space is our friend it makes the experience a lot more
    /// premium".
    ///
    /// **It is a sixth rung and not a fifth value, and the difference is
    /// measured.** `docs/space.md` reads grouping off Kubovy, Holcombe and
    /// Wagemans (1998): proximity groups by the RATIO between competing
    /// distances, not their difference. `gapSection` at 32 against a page of
    /// 24s is 1.33x, which is the ladder's own step, so on a page that already
    /// uses `gapWide` a "section break" is not read as a break at all. 64
    /// against 24 is 2.67x and against 32 is 2.0x, and both are outside any
    /// step the ladder takes, so it cannot be mistaken for the rhythm.
    ///
    /// **It already shipped, unnamed.** `SectionHeading` was writing
    /// `gapSection * 2` since the Memories pass; measured on the built page
    /// that renders as a 74.7pt break, 1.72x the page's median gap, and it is
    /// the only unambiguous break in the app that is not a dead tail at the
    /// bottom of a screen. Naming it is how the next person gets it right.
    ///
    /// **And deliberately nothing at 40 or 48.** The app currently puts 28 of
    /// its 85 measured gaps strictly between 32 and 64, and those 28 are 25
    /// different values. A rung in that span would legitimise the drift
    /// instead of ending it: each of those gaps is either a gap or a break,
    /// and choosing which IS the design decision.
    static let gapPage: CGFloat = gapSection * 2

    /// How much room the floating tab bar needs under a scrolling page.
    ///
    /// **One number, because three places need it.** It was the literal 110
    /// in the Memories page, in `PhotoCollectionView` and in the drawer — so
    /// the bar's height was recorded in three files, and moving it would have
    /// left two of them wrong in a way that only shows as a last row you
    /// cannot quite reach.
    static let tabBarClearance: CGFloat = 110
    /// **One caller, and it is the wrong one.** `MainAppView` reads this as the
    /// corner of every block in the LIVE tower, so at its 82pt cell a block is
    /// 8, which is 9.8% of the side, while the merged run standing beside it is
    /// `blockCornerRadius * styleScale` = a flat 12, and the same block on
    /// `StaticTowerView` is `cell * 0.147` = 12.05. Three values for one object,
    /// measured 2026-10-01. This is also the pre-ladder spelling of
    /// `radiusControl`, which is the same 8 for small controls.
    ///
    /// **THE OWNER LOOKED AT BOTH AND KEPT THE 8. 2026-10-01.** The tower was
    /// built with every block on `blockCornerRadius(forCell:)` (12.4 at the
    /// live cell), rendered, and put beside the current one; he chose to leave
    /// it. So this is now a decision rather than a leftover, and the next pass
    /// should not reopen it on the strength of the inconsistency alone.
    ///
    /// Worth knowing before anything here moves: the share card's two values
    /// already agree with each other to within 0.05pt, deliberately, because
    /// `cell * 0.147` at its capped 82pt cell is 12.05 against a merged run's
    /// flat 12. So the only place the three values are actually visible as a
    /// difference is the Wins tab, between a single block and the run beside
    /// it, which is the thing he has now looked at.
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
    /// **No call sites** (measured 2026-10-01): the only `LongPressGesture` left
    /// in the app is the replay's, on `replayHoldToPause`. Kept rather than
    /// deleted — unlike `Typography.caption2`, which WAS deleted on 2026-10-01
    /// for having none — because here the measurement is the whole value of it:
    /// if a hold on a block ever comes back, 0.35 is the number that was wrong
    /// and the paragraph above says why. A token that sets type is a value
    /// somebody reuses; a duration with a paragraph attached is a note.
    static let liftHoldDuration: Double = 0.4

    // **`cornerRadiusSmall` (8) and `cornerRadiusMicro` (4) are deleted**
    // (2026-10-01). Both had zero call sites, and both were the pre-ladder
    // spelling of a rung that still exists: `radiusControl` is the same 8 for
    // "small controls, icon wells, drop indicators" and `radiusMark` the same 4
    // for "tiny marks: heatmap cells, day dots, bars". Two names for one number
    // is how a ladder stops being one.

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
    /// Hairlines and card strokes.
    static let fillHairline = Color.primary.opacity(0.08)

    // **`fillTrack` (0.06) is deleted** (2026-10-01), zero call sites. It went
    // to zero when the drawer's handle capsule did, and the question it left is
    // whether a palette of three with one unused is a hole or a hazard. It is a
    // hazard, for a measured reason: the app's one remaining track is
    // `EtherealControls.track`, and that file records WHY it is opaque rather
    // than 6% ink: "a translucent one over a sheet that is itself translucent
    // compounds into a grey nobody chose", which cost that file two wrong
    // measurements to find. A token named for tracks would have handed the next
    // person exactly the bug it had already paid for.
    //
    // `docs/design-audit.md` had this open under "Still open": `radiusField` and
    // `fillTrack` are "a second vocabulary for things the block components now
    // cover, and they should be audited before anything new uses them." This is
    // that audit. `radiusField` keeps its caller; this one had none.
    static let horizontalPadding: CGFloat = 16
    /// The darkest a caption's veil over a photograph is allowed to get.
    ///
    /// White type on a photograph is unreadable without one, and the answer
    /// here has always been the shortest, lightest veil that works rather
    /// than a smear of black up the picture. It was 0.80, then 0.48, then
    /// this — the direction has only ever gone one way and it is always the
    /// owner's call. `FlippableBlockView` and `PhotoViewer` both use it, so
    /// the caption on a block and the caption on the same photograph full
    /// screen are the same weight.
    static let photoVeilOpacity: Double = 0.26
    /// How far a tally digit's ink sits inside its own layout box.
    ///
    /// The problem was found on a screenshot: with the header padded to 16pt
    /// the numeral's first dark pixel was at 20pt while the first block's
    /// colour started at 16pt. Type is aligned optically or it is not
    /// aligned.
    ///
    /// The number is no longer measured off a screenshot. `StrataFont`
    /// sets its digits tabular — one advance for all ten, ink centred in it —
    /// so the sidebearing is a fact in the font's `hmtx` table and the
    /// generator reads it out. It is the MEAN of the ten: the widest digit
    /// carries 0.078 em of air and the narrowest 0.118, and no single
    /// correction can be right for both.
    static let tallyOpticalInset: CGFloat = StrataFont.opticalInset * tallyNumeral

    // MARK: - Header alignment

    /// How far below a `Text`'s layout top SF Pro Rounded sets its CAP, as a
    /// fraction of the point size.
    ///
    /// Measured on the device rather than read off the font's metrics: two
    /// headers under identical layout, one at 64pt and one at 48pt, put their
    /// first ink 3.7pt apart — 3.7 / 16 = 0.2313 per point.
    static let roundedCapInset: CGFloat = 0.2313

    /// Distance from the top of a screen's content area to the CAP of its
    /// title.
    ///
    /// Headers cannot simply share a top padding. They are set at different
    /// sizes, and a bigger face pushes its cap further down its own layout
    /// box, so three screens all padded by 4pt measured 77.3pt (Memories,
    /// 48pt), 79.7pt (Camera, 61pt) and 81.0pt (Wins, 64pt) from the top of
    /// the screen. Small, but enough that Memories read as sitting too high.
    ///
    /// 18.8 is the value that leaves the Wins tally exactly where it was, so
    /// this aligns the other two to a position already settled by eye rather
    /// than moving all three somewhere new.
    static let headerCapTop: CGFloat = 18.8

    /// The top padding a header needs for its cap to land on `headerCapTop`.
    /// Ask for it; do not write a number.
    static func headerTopPadding(forTitleSize size: CGFloat) -> CGFloat {
        headerCapTop - roundedCapInset * size
    }

    /// The same, for a header made of ARTWORK rather than type.
    ///
    /// A `Text` sets its cap `roundedCapInset` of the point size below its own
    /// layout box, which is what the function above corrects for. A drawn
    /// wordmark has no ascender space — its frame top IS its cap top — so
    /// applying that correction pushes it up by the whole amount. Measured:
    /// the camera's wordmark landed at 71.7pt against the 81.0pt every other
    /// header sits on, which is the 9.25pt the correction subtracted.
    static let headerArtworkTopPadding: CGFloat = headerCapTop
    static let headerTopPadding: CGFloat = 12
    static let headerDividerHeight: CGFloat = 0.5

    // **`headerBottomPadding` (8), `headerDividerOpacity` (0.06),
    // `timelineGutterWidth` (56) and `minimumScaffoldBlocks` (12) are deleted**
    // (2026-10-01), zero call sites each.
    //
    // The first is `gapTight` under another name. The second had no divider to
    // draw: no header in the app has one, and `headerDividerHeight` survives
    // only because `ProfileView` borrows its flat 0.5 as a chart gridline width.
    // The gutter and the scaffold both belong to screens that no longer exist:
    // the Today/timeline tab (`docs/design-system.md` §8.2) and a starter tower
    // the app does not build. Their values are in `tasks/brand.md`.

    // **`strokeWidth` (2.5) is deleted** (2026-10-01), zero call sites. It is
    // both the pre-ladder spelling AND a fourth value on a three-rung ladder
    // whose rungs are all live (`strokeThin` 1.0, `strokeDefault` 1.5,
    // `strokeMedium` 2.0). Its job was the block's border glow
    // (`tasks/brand.md`), and the border went.

    // MARK: - Animation Springs
    //
    // **`dropSquashSpring` (0.12 / 0.60) is deleted** (2026-10-01), zero call
    // sites, and the thing that replaced it is a better statement of the same
    // intent: the squash phase is reached by `dropFallCurve.speed(1 /
    // fallDuration)` in `TowerAnimationCoordinator`, so the compression arrives
    // ON the fall's own constant-acceleration curve. A spring there would have
    // eased the block into its landing, which is the one thing a falling object
    // does not do. `impact` (the stretch, below) and `dropSettleSpring` keep their callers
    // because they run AFTER the landing, where a spring is right.
    /// **A block landing**: the stretch as it lands, and the wobble that
    /// follows it. One token, because they are one event.
    ///
    /// It was two, `dropStretchSpring` and `wobbleSpring`, with the same
    /// response and the same damping, declared forty lines apart and called
    /// twenty-one lines apart in the same function of
    /// `TowerAnimationCoordinator`. `docs/motion-audit.md` found them; two
    /// names for one number is the thing this file deleted `motionSettle` over.
    /// The name is the CAUSE now rather than either mechanism, which is what
    /// stops the pair coming back.
    static let impact = Animation.spring(response: 0.18, dampingFraction: 0.65)
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
    //
    // **`adaptiveShadowOpacity(_:colorScheme:)` is deleted** (2026-10-01), zero
    // call sites. `Elevation.opacity(in:)` is this function, settled: one factor
    // and one cap for all three rungs, `base * 4` capped at 0.45 against this
    // one's `* 3.5` capped at 0.60. Elevation's own doc argues why there is one
    // factor rather than a hand-written dark value per rung, which is the part
    // worth keeping. The numbers here are recorded in `docs/design-system.md` §4.

    // MARK: - Tap Bounce
    static let tapSquashSpring = Animation.spring(duration: 0.06, bounce: 0.0)
    static let tapPopSpring = Animation.spring(duration: 0.22, bounce: 0.20)
    static let tapScaleX: CGFloat = 1.02
    static let tapScaleY: CGFloat = 0.97

    // MARK: - Wobble Settle
    //
    // **`wobbleSpring` is deleted** (2026-10-01): it was `impact` under a
    // second name. The wobble's two amplitudes stay, because they are the
    // wobble; what went is a duplicate statement of when it happens.
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

    // **`snapBack` is deleted** (2026-10-01). Its own doc said "matches
    // tapPopSpring" and it did, to the digit: 0.22 and 0.20. A token that
    // documents itself as a copy of another token is a copy of another token.
    // Its two callers in `NextSlotButton` read `tapPopSpring` now.
    /// Content appearing
    static let gentleReveal = Animation.spring(response: 0.22, dampingFraction: 0.85)
    /// Settling — matches dropSettleSpring, reusable
    static let naturalSettle = Animation.spring(response: 0.28, dampingFraction: 0.78)
    // **`heavySettle` is deleted** (2026-10-01). Computed closed-form from the
    // parameters it settled in 257ms with 1.52% overshoot, against
    // `motionSnappy`'s 224ms and 1.11%: **33 milliseconds, two frames, and four
    // tenths of a point on a 90pt block.** Its two callers in `MainAppView` read
    // `motionSnappy`. `docs/motion-audit.md` §2 has the whole cluster: five
    // springs inside 73ms and 1.4pt of each other carrying 60 of the app's 147
    // call sites. This is the end of that cluster nobody has to look at twice.
    /// Small celebratory bounces
    static let elasticPop = Animation.spring(response: 0.25, dampingFraction: 0.50)
    /// Major layout changes (filter transitions, block expansion)
    static let layoutReflow = Animation.spring(response: 0.55, dampingFraction: 0.90)
    /// Non-spatial transitions (cross-fades)
    static let crossFade = Animation.easeInOut(duration: 0.2)

    /// A block fading in where it belongs, or out where it stood. Long enough
    /// to read as a change rather than a cut, short enough to be finished by
    /// the time your eye has moved to it.
    static let mapFade = Animation.easeOut(duration: 0.3)

    // **`progressFill` (0.25 / 0.70) and `cascadeReveal` (0.50 / 0.65) are
    // deleted** (2026-10-01), zero call sites each.
    //
    // `progressFill` was for "bars, rings filling", and the app has one: the
    // export ring in `ReplayView`, which follows a progress number with no
    // explicit curve. `cascadeReveal` was the spring new blocks arrived on
    // before the drop became real physics; `dropGravity`, `dropDurationRange`
    // and `dropFallCurve` now say the same thing with a model a viewer already
    // knows, and `MainAppView` records the rule that replaced it: "the fall is
    // the whole of its entrance."

    // MARK: - Named curves that used to be inline
    //
    // Each of these was typed at its call site. They are the SAME values,
    // moved here so the motion vocabulary is in one file; nothing about how
    // any of them feels changed when they were named.

    /// The heavy micro-bounce's drop on a mass-3 landing: 2pt down, quick.
    static let microBounceDownSpring = Animation.spring(response: 0.10, dampingFraction: 0.50)
    /// And back up, a touch slower and less springy.
    static let microBounceUpSpring = Animation.spring(response: 0.15, dampingFraction: 0.70)
    // **`towerBlockFadeIn` (easeOut 0.2) is deleted** (2026-10-01), with the
    // stagger that fed it. It faded a block in "when it first appears", and the
    // place a block first appears is the moment you arrive on the Wins tab — so
    // the whole tower dissolved in every time you pressed the tab. That is the
    // one thing this file already says twice it does not do (see the note where
    // `skeletonPop` was deleted: "nothing in this app animates because a screen
    // appeared"), and `MainAppView` says it a third time where the ground is
    // drawn. A newly dropped block was already exempt, so what remained was an
    // entrance for blocks that did not enter.

    /// The shutter pressing in, before it springs back.
    static let shutterPress = Animation.easeOut(duration: 0.08)
    /// The shutter springing back out. It follows `shutterPress`, so the call
    /// site delays it by that curve's duration.
    static let shutterRelease = Animation.spring(response: 0.28, dampingFraction: 0.6)
    /// The ring arming, and settling to the level you compose by.
    static let screenFlashOut = Animation.easeOut(duration: 0.22)

    /// How long one month-tower photograph takes to hand over to the next.
    /// Slow enough to read as a dissolve rather than a cut.
    static let monthPhotoFadeDuration: Double = 0.7
    /// The handover itself: the incoming picture coming up over one held at 1.
    static let monthPhotoFade = Animation.easeInOut(duration: monthPhotoFadeDuration)

    /// The photo viewer's title changing with the photograph.
    static let photoTitleFade = Animation.easeOut(duration: 0.12)
    /// How long a decoded photograph takes to fade in. Named separately so
    /// `CachedImageView` can hold its placeholder underneath for exactly as
    /// long as the fade runs.
    static let imageFadeInDuration: Double = 0.25
    /// A decoded photograph fading in where it was waiting.
    static let imageFadeIn = Animation.easeIn(duration: imageFadeInDuration)

    // MARK: - Today Screen Motion (Timeline Claude)

    /// Tap feedback, check circles — fast, clean
    static let motionSnappy = Animation.spring(response: 0.25, dampingFraction: 0.82)
    /// Content transitions, schedule confirm, row state changes
    static let motionSmooth = Animation.spring(response: 0.22, dampingFraction: 0.78)

    // **`motionGentle` (0.40 / 0.85), `motionSettle` (0.28 / 0.90) and
    // `motionReduced` (easeOut 0.05) are deleted** (2026-10-01), zero call sites
    // each. All three are a second answer to a question the ladder had already
    // settled, which is how a motion vocabulary stops being one.
    //
    // `motionGentle` was for container changes; `layoutReflow` (0.55 / 0.90) has
    // six callers doing exactly that. `motionSettle` was a THIRD spring at
    // response 0.28, beside `naturalSettle` (0.78) and `heavySettle` (0.80),
    // both live then, and three dampings a fifth of a point apart is not a
    // ladder. **That argument was one token short and it took until
    // 2026-10-01 to finish it:** `heavySettle` is deleted too, and this file
    // had made the case against it a month before anybody acted on it.
    //
    // `motionReduced` is the one worth naming, because it would have been
    // reached for: the app's reduce-motion convention is already written out
    // across about twenty call sites and it is `nil` / `.none` for anything that
    // should not move, and `crossFade` where the change still has to be seen.
    // A 50ms ease is neither: it is a very fast animation, which is what
    // Reduce Motion is asking the app not to do.

    // MARK: - Heads

    // One engine plays every head (`LivingHeadView`, `HeadDirector`); the
    // owner's black-and-white head is the standard the numbers come from
    // (`research-head-parity.md`, 2026-09-16). What differs between a head in
    // chrome and a head that is the subject of its page is `HeadLife`, and
    // every number it holds is one of these.

    /// The blink's clock. A posterised snap reads as a blink; a fade reads
    /// as eyes slowly closing.
    nonisolated static let headStep: TimeInterval = 0.125
    /// How far a head turns. Past about 20° a flat photograph stops reading
    /// as a head and starts reading as a card. The creator's number.
    nonisolated static let headMaxYaw: Double = 16
    /// A glance turns the head this much with the eyes.
    nonisolated static let headGlanceYaw: Double = 5
    /// Rest between idle beats, seconds: where the head is the subject, and
    /// in chrome.
    nonisolated static let headBeatRestExpressive: ClosedRange<Double> = 3.5...8.0
    nonisolated static let headBeatRestCalm: ClosedRange<Double> = 7.0...14.0
    /// The first beat after a head appears, and after its hello.
    nonisolated static let headFirstBeat: Double = 1.5
    nonisolated static let headFirstBeatAfterHello: Double = 3.4
    /// People blink every three to five seconds, irregularly.
    nonisolated static let headBlinkGap: ClosedRange<Double> = 2.6...5.8
    /// The blink's crunch: the head squashes this far as the lids close...
    nonisolated static let headBlinkDepth: ClosedRange<Double> = 0.905...0.935
    /// ...and gives this much back one step later, before the lids open.
    nonisolated static let headBlinkRelease: Double = 0.045
    /// About one blink in four is followed straight away by another.
    nonisolated static let headDoubleBlinkShare: Double = 0.24
    /// How long the eyes rest on a point that is not you, seconds.
    nonisolated static let headWanderExpressive: ClosedRange<Double> = 1.2...2.6
    nonisolated static let headWanderCalm: ClosedRange<Double> = 1.5...4.0
    /// **Eye contact, bounded** (owner, 2026-09-16: yes where the head is the
    /// subject; never in chrome). After looking away, the chance the eyes
    /// come back to you. After contact they always look away on purpose.
    nonisolated static let headContactShare: Double = 0.6
    /// How long they rest on you, and the hard ceiling. People prefer mutual
    /// gaze of about three seconds (Binetti et al., 2016); longer is a stare.
    nonisolated static let headContactHold: ClosedRange<Double> = 1.2...2.6
    nonisolated static let headContactMax: Double = 3.0
    /// Anything that is not contact rests at least this far out from the
    /// middle (-1...1 each way).
    nonisolated static let headStareFloor: Double = 0.45
    /// Fixational micro-saccades on an expressive head: how far, and how often.
    nonisolated static let headMicroX: Double = 0.03
    nonisolated static let headMicroY: Double = 0.02
    nonisolated static let headMicroEvery: ClosedRange<Double> = 1.2...2.8
    /// Eyes land before the head moves: a turn, and a glance or a look down.
    nonisolated static let headEyesLead: Double = 0.09
    nonisolated static let headEyesLeadGlance: Double = 0.08
    /// The pupil as a share of the iris: the portfolio's calibrated ellipse,
    /// and a measured outline's disc.
    nonisolated static let headPupilCalibrated: Double = 0.55
    nonisolated static let headPupilMeasured: Double = 0.46
    /// Squashes: a lid cue in a take, a face popping or morphing in, a double
    /// blink's second close and its release, and a settle's close and release.
    nonisolated static let headSquashLids: Double = 0.94
    nonisolated static let headSquashFace: Double = 0.975
    nonisolated static let headSquashDoubleBlink: Double = 0.92
    nonisolated static let headSquashDoubleBlinkRelease: Double = 0.95
    nonisolated static let headSquashSettle: Double = 0.92
    nonisolated static let headSquashSettleRelease: Double = 0.965
    /// How long a face's squash, and a morph's old layer, are given to land.
    nonisolated static let headMorphLands: Double = 0.16
    /// Holds inside the creator's beats, seconds: a turn looking at something,
    /// a look down at the words, an idle smile, an idle surprise.
    nonisolated static let headTurnHold: ClosedRange<Double> = 1.2...2.2
    nonisolated static let headDownHold: ClosedRange<Double> = 0.9...1.5
    nonisolated static let headSmileHold: ClosedRange<Double> = 1.3...2.0
    nonisolated static let headSurpriseHold: ClosedRange<Double> = 0.7...1.0
    /// The hello: when it starts, how long the brows are up, how long the wink.
    nonisolated static let headHelloDelay: Double = 0.7
    nonisolated static let headHelloBrows: Double = 0.24
    nonisolated static let headHelloWink: Double = 1.6
    /// A made face pops in, like the creator's grin, only when its silhouette
    /// overlaps neutral's this much; otherwise it morphs.
    nonisolated static let headPopIoU: Double = 0.94


    /// A head turning. Critically damped: a head arrives at what it is looking
    /// at, it does not overshoot and correct. About half a second, a relaxed
    /// turn rather than a startled one.
    static let headTurn = Animation.spring(response: 0.55, dampingFraction: 1.0)
    /// An eye moving. Saccades are the fastest movement a body makes (tens of
    /// milliseconds), so the eyes land before the head has started.
    static let eyeSaccade = Animation.spring(response: 0.09, dampingFraction: 1.0)
    /// One face becoming another. Short, because an expression arrives in a
    /// moment — longer and it reads as a slideshow dissolve, not a face.
    static let headMorph = Animation.easeOut(duration: 0.14)
    /// The slow float of a head that is the subject of its page. Two periods
    /// that never line up, so the drift never reads as a metronome. Only on
    /// the expressive head; a head in chrome holds still.
    static let headFloatX = Animation.easeInOut(duration: 3.7).repeatForever(autoreverses: true)
    static let headFloatY = Animation.easeInOut(duration: 2.9).repeatForever(autoreverses: true)
    /// How long a tapped expression stays up, tap to ease-back. People hold a
    /// posed expression two to four seconds; under that a tap reads as a
    /// flicker (owner: "they should hold for longer"; it was 1.4s). Every take
    /// in `HeadTake.catalogue` holds between the short and the long one.
    nonisolated static let headTakeHoldShort: TimeInterval = 2.6
    nonisolated static let headTakeHold: TimeInterval = 3.0
    nonisolated static let headTakeHoldLong: TimeInterval = 3.4
    /// The ease back to calm after a take, and a sleepy head's droop: slower
    /// than a turn.
    static let headTakeEaseBack = Animation.spring(response: 0.7, dampingFraction: 1.0)
    /// One beat of a nod or a shake: fast enough to read as a gesture,
    /// critically damped.
    static let headNod = Animation.spring(response: 0.14, dampingFraction: 0.9)

    // **`fillSweepDuration` (0.4) and `toggleSwitch` (0.30 / 0.80) are deleted**
    // (2026-10-01), zero call sites. `toggleSwitch`'s doc named its own two
    // callers, `NewHabitMenu` and `PlanItemRow`, and neither exists; a token that
    // names the screens it serves is a token you can check, and this one failed
    // its own check. The fill sweep's three tiers go below for the same reason.

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
    /// The tally is a screen title, and every screen title is one size.
    ///
    /// It was 64 — nearly double every other header, so moving between tabs
    /// changed the scale of the page. Rendered side by side at 64 and 34, the
    /// smaller one reads as composed and the larger one as shouting; the
    /// tower is the thing on this screen worth looking at, and the count is a
    /// caption for it.
    static let tallyNumeral: CGFloat = Typography.screenTitleSize

    // **`tallyWord` (18) is deleted** (2026-10-01), zero call sites, and its own
    // doc already said why: the word beside the tally uses
    // `Typography.screenSubtitle` now, like every other line under a title, so it
    // scales with Dynamic Type. A fixed point size cannot, which is the whole
    // reason it stopped being used. Keeping the number invites it back.

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

    // MARK: - A replay, playing

    /// How long a press has to be held before a replay pauses. Shorter than
    /// this it is a tap, which skips to the close; pausing on touch-down
    /// instead would freeze every tap for a moment before the skip.
    static let replayHoldToPause: Double = 0.2
    /// Landing haptics and sounds a replay plays in any one second. A month
    /// can land more blocks than that; past the limit the rest are silent,
    /// so a busy day is a patter and not noise.
    static let replayFeedbackPerSecond: Int = 12
    /// A frame that moves the clock further than this is a skip, not
    /// playback, and plays nothing for the landings it passed.
    static let replaySkipGap: Double = 0.25
    /// The level a replay's landings sound at, against a live landing's 1.
    static let replayImpactGain: Double = 0.6
    /// A replay that cannot start inside this shows where its tower will
    /// stand. Under it a wait reads as the cover arriving, and an indicator
    /// that flashes for a frame is worse than none.
    static let replayLoadingDelay: Double = 0.15

    /// The slot fading out as the replay starts.
    static let replayLoadingFade: Double = 0.24

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
    // **`skeletonPop` (0.35 / 0.65) is deleted** (2026-10-01), zero call sites,
    // and `SkeletonBlockView` is where the reason is written at length: the
    // skeleton is on screen for about half a second, nothing in this app animates
    // because a screen appeared, and anything that moved there muddied the
    // handover as the real blocks faded in over the top. "What is left says the
    // true thing without moving."

    // MARK: - Card Detail (Tower Claude)

    // **`cardMorph` is deleted** (2026-10-01) and its three callers read
    // `crossFade`. Its doc claimed it was "the sheet's open and close now", and
    // it was not: UIKit owns a sheet's presentation, and all three sites set
    // `expandedBlockID`, which moves no geometry. A spring that carries nothing
    // but a flag is a spring nobody can see, and each of the three already fell
    // back to `crossFade` under Reduce Motion, so the fallback was the whole
    // animation on half the devices. Named for a card that was deleted in
    // September. `docs/motion-audit.md` §5.6.

    // **`cardReveal` (0.40 / 0.88), `cardCornerRadius` (20),
    // `cardContentPadding` (20) and `cardContentSpacing` (16) are deleted**
    // (2026-10-01), zero call sites each. They are `BlockExpansionCard`'s, and
    // `MainAppView` records why that card went: "editing a win asks the same four
    // questions as adding one, so it should be the same sheet with the answers
    // filled in." Two of the four are rungs that already exist under better
    // names: `radiusSurface` is the same 20 for "surfaces that become the
    // environment", `gapLabel` the same 16, and the 20pt padding is on no
    // spacing ladder this app keeps. `docs/design-system.md` §9.3 still describes
    // the card.

    // MARK: - Filmstrip
    //
    // **`filmstripThumbnailSize` (56) and `filmstripSpacing` (8) are deleted**
    // (2026-10-01), zero call sites. The app has a filmstrip, `Filmstrip` in
    // `PhotoViewer`, and it rejects both numbers deliberately and in writing.
    // Its card is 46 x 60, portrait, "because a photograph is more often portrait
    // than not and a square frame crops the subject out of it", and its gap is
    // `gapTight` itself rather than a copy of it. A token whose only possible
    // caller has written down why it does not want it is a trap.

    // MARK: - Icon Sizes
    static let iconMedium: CGFloat = 12    // next-up pill icons
    static let iconCategory: CGFloat = 13  // category icons on blocks
    static let iconAction: CGFloat = 14    // action buttons (close X, replace photo)
    static let iconToolbar: CGFloat = 17   // toolbar icons (gear)
    static let iconChevron: CGFloat = 10   // next-up pill chevron

    // **`iconSmall` (8), `iconEmptyState` (36) and `iconHero` (40) are deleted**
    // (2026-10-01), zero call sites. 8 sat below the live floor (`iconChevron`,
    // 10) and nothing in the app draws a glyph that small. The other two are
    // empty-state art, and there is none left: every empty state in the app is
    // type on its own margin. `MemoriesView` holds the reason: "the art is
    // deleted rather than redrawn: the real calendar sits under this copy and
    // shows a real empty month, which is a better promise of the thing than a
    // drawing of a different thing."

    // MARK: - Block Patina (Perfect-Day Gold Tint)
    static let patinaMaxOpacity: Double = 0.15
    static let patinaGrowthRate: Double = 0.02
    static let patinaGold = Color(red: 0.95, green: 0.80, blue: 0.40)

    // MARK: - Celebration (Phase 2)
    static let confettiDuration: TimeInterval = 2.0

    // **`celebrationBurst` (0.30 / 0.60), `blockFlyaway` (0.55 / 0.70) and
    // `confettiParticleCount` (24) are deleted** (2026-10-01), zero call sites.
    //
    // The celebration that ships is `AllClearCelebration`, a `Canvas` driven by
    // `confettiDuration` above; it has no burst spring and nothing flies away.
    // The particle count is the interesting one, because the built file arrives at
    // the SAME 24 and refuses to write it down as 24: `perColor = 4`, times the
    // completed categories, "so the burst is the size of the day: one kind of win
    // throws less than six kinds did." A flat count would make a one-category day
    // and a six-category day look identical, which is the fact the view exists to
    // show. `docs/design-system.md` §5 still tabulates all three.

    // MARK: - Momentum Escalation
    //
    // **`fillSweepFast` (0.28), `fillSweepMedium` (0.32) and `fillSweepEarly`
    // (0.36) are deleted** (2026-10-01), zero call sites. Nothing in the app
    // sweeps a fill, and nothing escalates with momentum. `docs/design-system.md`
    // §5 keeps the three tiers if the idea ever comes back.

    // MARK: - Spatial Tower (Phase 3)
    static let ghostBlockDashLength: CGFloat = 4

    // **`breathingCycleDuration` (3.0), `breathingIntensity` (0.015),
    // `ambientGlowCycle` (2.5) and `ambientGlowIntensity` (0.08) are deleted**
    // (2026-10-01), zero call sites, and they are not merely unused: they are
    // forbidden. `docs/design-system-future.md` §8 refuses, in as many words, to
    // "animate anything on appearance, or loop an animation", and all four are
    // `repeatForever` parameters. `SkeletonBlockView` records the one time a
    // breath was actually built and what it cost.
    //
    // **`ghostBlockOpacity` (0.06), `ghostBlockPulseMin` (0.04) and
    // `ghostBlockPulseMax` (0.10) go with them**, same reason and the same
    // measurement: `ReplayView.ReplayLoadingSlot` is the one thing that pulsed,
    // and it stopped because the slot is on screen for less than one cycle of its
    // own breath, "so what was actually seen was a slot at some arbitrary point of
    // a fade." It draws at full strength now. `ghostBlockDashLength` stays, with two
    // callers, and a dash is a shape, not a loop.

    // MARK: - Connected Flow (Phase 4)

    // **`staggerMax` (0.4) is deleted too, and it was never reachable.** The
    // cache it filled was built ONLY for `newlyDroppedIDs`, and a newly dropped
    // block took `.identity` at the one site that read the delay — so every
    // lookup that mattered fell through to the `?? 0` default. A decelerating
    // wave was computed per block, cached, and cleared, to delay an animation
    // that never ran. It went with `towerBlockFadeIn` above.

    // **`staggerInterval` (0.04) and `entranceOffset` (12) are deleted**
    // (2026-10-01), zero call sites. The stagger that ships is not an interval at
    // all: it is the normalised power curve above, spread over `staggerMax`, so
    // a per-block interval is a model the code does not use. The row-to-row gap
    // that IS an interval is `danceRowDelay` (0.045), and it is live.
    //
    // `entranceOffset` was 12pt of slide on a block appearing. There is none:
    // `MainAppView` is explicit that "the fall is the whole of its entrance", and
    // the distance a block comes from is `dropRunway` and `fallStartOffset`, both
    // of which start it off screen rather than 12pt out of place.

    // Two empty section headings go as well, 2026-10-01: "UI Elements" had
    // nothing under it before this pass, and "Block Shadow (post-border-removal,
    // stronger)" has nothing under it now that the four `blockShadow*` constants
    // are gone. A heading with no section is a map of a room that is not there.

    // MARK: - Block Rim (Figma Apollo 248:14)
    //
    // The block already carried a frosted band and a flat white strip along the
    // bottom. This makes that edge a real rim: uniform on all four sides, crisp
    // above the band and blurred inside it, which is how the source builds it —
    // one solid white border (255:105) under a separate backdrop-blur rect
    // covering the bottom 26% (255:106).
    /// White rim. Figma draws 5px on a 562pt block (0.89%) — 0.77pt at an 86.5pt
    /// cell; 0.8 is 2.4 device px at 3x and renders crisp.
    static let blockRimWidth: CGFloat = 1.9
    /// How much of the rim's white survives below the top edge. The rim is a
    /// highlight, not an outline: full white where the light lands, less
    /// everywhere else.
    static let blockRimFalloff: Double = 0.26
    /// Darkening at the top edge of a block that is carrying another one.
    /// Subtle on purpose: it should be felt as weight, not seen as a stripe.
    static let blockContactShade: Double = 0.11
    // **`blockUnnamedOpacity` (0.52) is deleted** (2026-10-01), zero call sites,
    // and its own doc is now wrong twice over. An unnamed win does not get a white
    // translucent surface: it draws in its category's colour like every other
    // block, and `BlockContent.isUnnamed` decides one thing only, whether a title
    // is drawn: "'Win' is not a name, it is the absence of one." The ground it
    // was translucent against is not warm any more either.
    /// Blur inside the band. Figma blurs 10px on a 562pt block — 1.78% of width.
    static let blockRimBlur: CGFloat = 3.0
    /// Fraction of block height where the frosted band begins (Figma's 145pt of 565).
    static let blockBandStart: Double = 0.74
    /// The sharp and blurred copies crossfade across this span rather than cutting
    /// hard. Blurring softens a surface's alpha at its edges, so a hard cut makes
    /// the silhouette visibly pinch in at 86pt.
    static let blockBandFeatherStart: Double = 0.56
    static let blockBandFeatherEnd: Double = 0.74
    /// Frosted white wash inside the band.
    ///
    /// Figma's 0.2 put ~22% white into the bottom of every block, which read as
    /// the block fading out rather than as a frosted edge. Halved: the band is
    /// still there and still catches the blurred rim, but the colour stays
    /// colour all the way down.
    static let blockScrimOpacity: Double = 0.10

    // MARK: - Ghost (incomplete) tier
    //
    // **`blockGhostRimWidth` (1.5) and `blockGhostRimOpacity` (0.45) are
    // deleted** (2026-10-01), zero call sites. The tier they belonged to, a
    // block outlined in its own category colour because the habit was incomplete,
    // went with the Today/timeline tab. The app has exactly one ghost of a
    // block left, the plan's empty bullet, and it is NOT category-coloured and
    // NOT these numbers: `PlanBullet.outlineInk` and
    // `PlanBullet.outlineWidth(forSide:)`, where the width is derived from
    // `blockRimWidth` so it cannot drift from the real rim, and the ink is
    // `slotInk` at 0.60 because this exact pair of literals measured **2.13:1**
    // against the sheet where the real bullet measures 3.31. That is the record
    // worth keeping, and it is in the file that draws the shape.

    // **`blockShadowRadius` (14), `blockShadowY` (2), `blockShadowOpacity`
    // (0.032) and `blockShadowOpacityDark` (0.13) are deleted** (2026-10-01),
    // zero call sites. `Elevation.resting` IS these numbers, 0.032 at radius 14,
    // y 2, and its doc says so: "these are the numbers the owner settled the
    // blocks on, kept exactly." Dark mode is `opacity * 4` capped at 0.45, which
    // lands on 0.128 against the 0.13 that was hand-written here.
    //
    // **The history below is kept because it is the argument, not the value**,
    // and it is the argument somebody will want the next time a shadow is asked
    // to be stronger. It belongs with `Elevation.resting`, and should move there
    // the next time that file is free to edit.
    //
    // Softer, and lower (2026-09-09, owner's call).
    //
    // A block is a lit plane, not an object thrown onto a table. At 0.12 with
    // a 5pt radius every block carried a visible dark edge under it, and
    // forty of them on one screen add up to a page that reads as heavy rather
    // than as clean. Wider and fainter reads as air under the block instead
    // of a drop shadow on it — which is the difference between "structured"
    // and "stuck on".
    //
    // **Softened again on 2026-09-29 for the ethereal read the owner asked
    // for**: "the shadows are more subtle creating that ethereal feel."
    //
    // Wider and fainter, which is the same direction the note above already
    // argues and simply further along it. A shadow says a block is a solid
    // thing resting on the page; the point of this pass is that the page is now
    // a sheet with light behind it, and something resting on a lit sheet casts
    // almost nothing. The radius grows as the opacity falls so the block keeps
    // its footing — a shadow that only gets fainter starts to look like a
    // rendering mistake, where one that gets fainter AND wider reads as air.
    //
    // Dark mode falls proportionally rather than to the same number: on a
    // charcoal ground a shadow is most of what separates a block from the page,
    // and taking it to 0.07 there would flatten the tower outright.

    // **`checkCircleSize` (24) is deleted** (2026-10-01), zero call sites, and
    // the circle is the part that went: `PlanSheet` records the owner's own
    // objection, "why is there a circle dotted when it should be a square", so
    // what a plan line carries now is a block. The 24 is alive as
    // `PlanBullet.side` and `PlanSheet.bulletSide`, which is where it has to be,
    // because the ghost beside it is sized off the same number so that the outline
    // is the exact silhouette of what lands in it.

    // MARK: - Height-Progressive Shadow (#12)
    //
    // **`depthShadow(row:)`, `depthShadowOpacity(row:)`, `depthShadowScale`
    // (0.2), `depthShadowYScale` (0.10) and `maxDepthShadowRadius` (12) are
    // deleted** (2026-10-01). The two functions had zero call sites and the three
    // constants had no reader but those functions, so the whole mechanism went in
    // one piece.
    //
    // It made a block's shadow grow with its row, which `Elevation` deliberately
    // does not: there are three rungs, and which one a thing is on is a fact
    // about the thing, not about how high up the page it happens to sit. Height
    // reads from the tower, not from forty shadows each slightly different.
    // `shadowRadius`, `shadowY` and `shadowOpacity` stay: they have callers of
    // their own. `docs/design-system.md` §4 keeps the formula.

    // MARK: - Semantic Opacity (Today Screen Overhaul Batch 10)
    //
    // **`opacityGhost` (0.06), `opacitySubtle` (0.12), `opacityMuted` (0.25),
    // `opacitySecondary` (0.50), `opacityPrimary` (0.70) and `opacityFull` (1.0)
    // are deleted** (2026-10-01), zero call sites, and not one of those six
    // numbers appears inline anywhere in the app either: the job went to tokens
    // that can do something a bare opacity cannot.
    //
    // A number is applied to whatever ink it is handed, and in this app that ink
    // has to invert with the appearance. `AppColors.inkPrimary` /
    // `inkSecondary` / `inkTertiary` / `inkQuiet` are adaptive AND measured
    // against the ground they land on; the neutral fills above are the same idea
    // for surfaces. `PlanBullet` records what the other way costs: a fixed dark
    // ink at 0.22 measured 1.47:1 on the light page and 1.08:1 on the dark one,
    // "dark ink on a dark page, which is no contrast at all rather than low
    // contrast." The table is in `docs/design-system.md` §1.

    // MARK: - Stroke Widths
    static let strokeThin: CGFloat = 1.0
    static let strokeDefault: CGFloat = 1.5
    static let strokeMedium: CGFloat = 2.0
}
