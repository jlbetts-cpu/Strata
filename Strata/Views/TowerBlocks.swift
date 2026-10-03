import SwiftUI
import SwiftData

// The tower's blocks, drawn: the ForEach that places them and the view that
// drops, squashes and dances each one. Moved out of `MainAppView` on
// 2026-10-02 so a crew tower draws its blocks with exactly the same code
// (`CrewTowerView`). Nothing in them changed in the move.

struct TowerBlocksForEach: View {
    let visibleBlocks: [PlacedBlock]
    let animCoord: TowerAnimationCoordinator
    let towerVM: TowerViewModel
    /// Members of a merged run, computed over settled blocks only so a
    /// falling block does not join its group before it lands.
    let groupedIDs: Set<UUID>
    /// Blocks that WILL be part of a merged run once they settle,
    /// including ones still in the air.
    let mergeDestinedIDs: Set<UUID>
    let colW: CGFloat
    let gridH: CGFloat
    let cornerRadius: CGFloat
    let expandedBlockID: UUID?
    let reduceMotion: Bool
    let colorScheme: ColorScheme
    let onTapExpandBlock: (UUID) -> Void
    /// Always nil since the block drag was removed. Kept rather than deleted
    /// because the block view reads it to decide whether anything is lifted,
    /// and threading a constant `false` through the same path would be the
    /// same statement in a worse place.
    let liftedBlockID: UUID?
    /// A crew tower's double-tap. Nil on your own tower.
    var onDoubleTapBlock: ((UUID) -> Void)? = nil
    /// A crew tower's press and hold: the reactions, as Messages answers a
    /// held message. Nil on your own tower.
    var onLongPressBlock: ((UUID) -> Void)? = nil

    var body: some View {
        // Read the dance's phase counter here, at the top of the grid's
        // body, so a phase change is guaranteed to invalidate it. Reading
        // the per-block values inside the ForEach closure below is not a
        // dependency SwiftUI reliably attributes to this body — which is
        // exactly why the wave ran to completion without moving anything.
        let _ = animCoord.danceTick
        ForEach(visibleBlocks) { block in
            let f = GridConstants.blockFrame(
                column: block.column, row: block.row,
                columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                cellSize: colW
            )
            let animState = animCoord.state(for: block.id)
            let isNewlyDropped = towerVM.newlyDroppedIDs.contains(block.id)

            AnimatedBlockView(
                block: block,
                // Read from the models now, so `==` compares this
                // evaluation's values with the last one's.
                look: block.habit.flatMap { habit in block.log.map { PlacedBlock.Look(habit: habit, log: $0) } }
                    ?? block.look,
                frame: f, animState: animState,
                isNewlyDropped: isNewlyDropped,
                gridH: gridH,
                cornerRadius: cornerRadius, expandedBlockID: expandedBlockID,
                reduceMotion: reduceMotion, colorScheme: colorScheme,
                isFoundation: towerVM.foundationBlockIDs.contains(block.id),
                isCrown: towerVM.topRowBlockIDs.contains(block.id),
                isGroupMember: groupedIDs.contains(block.id),
                willMerge: mergeDestinedIDs.contains(block.id),
                isCovered: towerVM.coveredBlockIDs.contains(block.id),
                onTapExpandBlock: onTapExpandBlock,
                liftedBlockID: liftedBlockID,
                onDoubleTapBlock: onDoubleTapBlock,
                onLongPressBlock: onLongPressBlock
            )
            .frame(width: f.width, height: f.height)
            // **A PLACED BLOCK CANNOT BE PICKED UP, AND THAT IS THE FIX.**
            //
            // The owner, 2026-09-28: "you can physically move the block...
            // the glitch is you can drag the box which makes the box
            // disappear, just remove the drag all together, not needed."
            //
            // This was `.draggable` plus `.dropDestination`: hold a block,
            // drag it onto another, and the tower repacked around the new
            // order. The disappearing box was the drag PREVIEW, which was
            // deliberately `Color.clear.frame(width: 1, height: 1)` on the
            // reasoning that the block "has already left its slot and the
            // tower has closed the gap", so a chip under the finger would be
            // a second copy of it. What that actually produces is a block
            // that vanishes the moment you press and move, with nothing
            // under the finger and nothing in the grid. It reads as a bug
            // whatever the intent was, and he found it as one.
            //
            // Rearranging is gone rather than repaired, because he asked for
            // that and because the tower is a record of what happened, in the
            // order it happened.
            //
            // WHAT IS NOT AFFECTED, because he named both: drawing a size out
            // of the slot, and out of the camera's shutter, are untouched —
            // "I love the drag to size the block, please don't remove that".
            // Tapping a block still opens it (`onTapExpandBlock`, a
            // TapGesture, which the note above records as the one recogniser
            // a ScrollView never fought over).
            // The dance has to be read HERE.
            //
            // These three lived inside `AnimatedBlockView`, which is an
            // `Equatable` view. Its `==` cannot see them — they live on a
            // shared reference the two sides hold in common — so nothing
            // ever invalidated the child and the wave never reached the
            // screen: the coordinator set `jubilationLift = -10` on every
            // block and the foundation moved one pixel in a whole run.
            // The drop phases only worked because this grid happens to
            // read `dropPhase` below, for `zIndex`, which re-renders the
            // row. Reading the dance here gives it the same guarantee
            // instead of the same accident.
            .rotationEffect(.degrees(animState.jubilationWobble))
            .offset(y: animState.jubilationLift)
            .brightness(animState.jubilationGlow)
            .offset(x: f.minX, y: gridH - f.minY - f.height)
            .zIndex(animState.dropPhase != nil ? 100 : Double(block.row + 1))
            .accessibilitySortPriority(-Double(block.row))
            // **NO insertion transition, for any block.**
            //
            // A newly dropped one never had one: it was fading in over 0.2s
            // while simultaneously falling, so the first half of the fall
            // happened at low opacity and what you saw was the block
            // appearing near its slot, "it just spawns in and then there's a
            // ripple". It is opaque from the first frame and the fall is the
            // whole of its entrance.
            //
            // Every other block has now lost it as well (2026-10-01). The
            // branch fired in two places and neither was a person doing
            // something: arriving on the Wins tab, where it dissolved the
            // entire tower in, and crossing the cull boundary mid-fling,
            // where it is invisible by construction. Check 10 of the audit
            // fails anything that animates because it appeared, and this
            // file already states the rule where it draws the ground.
            .transition(.identity)
        }
    }
}

struct AnimatedBlockView: View, Equatable {
    let block: PlacedBlock
    /// What the block draws with, as values. See `PlacedBlock.Look`.
    let look: PlacedBlock.Look
    let frame: CGRect
    let animState: BlockAnimationState
    let isNewlyDropped: Bool
    let gridH: CGFloat
    let cornerRadius: CGFloat
    let expandedBlockID: UUID?
    let reduceMotion: Bool
    let colorScheme: ColorScheme
    let isFoundation: Bool
    let isCrown: Bool
    let isGroupMember: Bool
    /// True as soon as the tower knows this block BELONGS to a merged run,
    /// even mid-flight.
    let willMerge: Bool
    let isCovered: Bool
    let onTapExpandBlock: (UUID) -> Void
    let liftedBlockID: UUID?
    /// Not in `==`: a closure cannot be compared, and it never changes for a
    /// given tower.
    var onDoubleTapBlock: ((UUID) -> Void)? = nil
    var onLongPressBlock: ((UUID) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    static func == (lhs: Self, rhs: Self) -> Bool {
        // The habit's own properties MUST be in here. Comparing only the
        // id and the frame meant a category change — same block, same
        // slot — compared equal, so SwiftUI skipped the redraw and the new
        // colour did not appear until something else forced a rebuild.
        // That is "editing a block only takes effect when I add another".
        //
        // And they must be VALUES. This compared
        // `lhs.block.habit.title == rhs.block.habit.title`, but both sides
        // hold the same `Habit`, so it read one object twice and was
        // always true; edits showed only because `FlippableBlockView`
        // observes the model itself. `look` is copied out of the models
        // each time the grid builds this view, so it can differ.
        lhs.block.id == rhs.block.id
        && lhs.look == rhs.look
        && lhs.block.isSkipped == rhs.block.isSkipped
        && lhs.frame == rhs.frame
        && lhs.isNewlyDropped == rhs.isNewlyDropped
        && lhs.gridH == rhs.gridH
        && lhs.expandedBlockID == rhs.expandedBlockID
        && lhs.reduceMotion == rhs.reduceMotion
        && lhs.colorScheme == rhs.colorScheme
        && lhs.isFoundation == rhs.isFoundation
        && lhs.isCrown == rhs.isCrown
        && lhs.isGroupMember == rhs.isGroupMember
        && lhs.willMerge == rhs.willMerge
        && lhs.isCovered == rhs.isCovered
        // Without this the lift never renders at all. `AnimatedBlockView`
        // is `Equatable`, so SwiftUI only re-evaluates it when `==` says
        // something changed — and `liftedBlockID` was not among the
        // nineteen properties it compared. This is the same trap
        // CLAUDE.md documents for the dance and the jubilation wave.
        && lhs.liftedBlockID == rhs.liftedBlockID
    }



    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("AnimatedBlockView")
        #endif
        let phase = animState.dropPhase
        let mass = CGFloat(block.look.blockSize.massTier)

        let dropOffset: CGFloat = switch phase {
        case .falling:
            // Captured once, when the drop was queued, from where this
            // block actually sits on screen — far enough above the top edge
            // that it enters from outside the screen rather than appearing
            // in mid-air. See `fallStartOffset(for:)`.
            //
            // Every earlier version of this line computed the start from
            // the world WHILE the block was in the air, and each one made
            // the drop inconsistent in its own way: from `towerScrollOffset`
            // it varied fourfold with the scroll position; from `gridH` it
            // jerked upward one row-pitch on the drops that completed a row;
            // as a constant above the SLOT it started low on a short tower,
            // which is what read as blocks coming up from the bottom.
            animState.fallStartOffset
        case .squash, .stretch, .wobble: CGFloat(0)
        case .none: CGFloat(0)
        }

        let (impactScaleX, impactScaleY): (CGFloat, CGFloat) = switch phase {
        case .squash:
            (1.0 + GridConstants.squashScaleX(mass: mass),
             1.0 - GridConstants.squashScaleY(mass: mass))
        case .stretch:
            (1.0 - GridConstants.stretchScaleX(mass: mass),
             1.0 + GridConstants.stretchScaleY(mass: mass))
        default: (1.0, 1.0)
        }

        let wobbleDegrees: Double = switch phase {
        case .wobble: mass >= 2 ? GridConstants.wobbleDegreesHeavy : GridConstants.wobbleDegreesLight
        default: 0
        }

        // No impact flash on a block that is about to become part of a
        // larger shape.
        //
        // Filmed at 60fps: the landed block sat 6% brighter than the mass
        // it was joining for the whole squash phase, and the crossfade then
        // had to fade that difference out — which is the "lighter patch"
        // that made the merge visible. A block that is merging has no
        // separate surface to flash; the shape it joins is the thing that
        // took the impact.
        let flashBrightness: Double = (phase == .squash && !willMerge) ? 0.06 : 0

        // The landing shadow goes too, for the same reason: it drew an
        // outline around a block that is supposed to be dissolving into its
        // neighbours. It keeps the FALLING shadow — in the air it is still
        // a separate object.
        let (dropShadowRadius, dropShadowY): (CGFloat, CGFloat) = switch phase {
        case .falling: (12, 8)
        case .squash: willMerge ? (0, 0) : (1, 0.5)
        case .stretch: willMerge ? (0, 0) : (3, 1.5)
        case .wobble: willMerge ? (0, 0) : (4, 2)
        case .none: (0, 0)
        }

        let isRippling = animState.isRippling
        let ri = animState.rippleIntensity
        // Compression only — no downward shift.
        //
        // The blocks also moved DOWN by up to 2.5pt when rippled, which on
        // the bottom row (where intensity is highest and there is nothing
        // below to move into) read as the foundation jerking downward. A
        // block being compressed already says it took weight; sliding it
        // down as well says the tower sank, which it did not.
        //
        // Halved as well: apple-design.md §11 asks that per-frame change
        // stay under the perception threshold, and 5% of a block's height
        // in one spring was over it.
        let rippleScaleX: CGFloat = isRippling ? 1.0 + 0.015 * ri : 1.0
        let rippleScaleY: CGFloat = isRippling ? 1.0 - 0.025 * ri : 1.0
        let rippleOffsetY: CGFloat = 0

        let isExpanded = expandedBlockID == block.id

        ZStack {
            // The empty socket shows only while the block is ABOVE it.
            //
            // It was drawn for `isNew`, which stays true for two seconds
            // after the drop — so a translucent material square sat on top
            // of the tower long after the block had landed in it. On a
            // merged run that is a pale patch in the middle of the shape,
            // which is what still made the join obvious after the colour
            // and the chrome had been matched. Filmed at 60fps it was
            // steady, not fading, which is what gave it away: a crossfade
            // artifact would have decayed.
            if phase == .falling {
                ghostSlot(width: frame.width, height: frame.height)
            }

            FlippableBlockView(
                block: block,
                width: frame.width,
                height: frame.height,
                cornerRadius: cornerRadius,
                modelContext: modelContext,
                // A falling block draws itself; it joins the shape on
                // landing.
                isGroupMember: isGroupMember && phase == nil,
                // Chrome goes the moment it touches down, not when the
                // crossfade finishes — the rim is what was still drawing a
                // boundary through the middle of one shape.
                chromeless: willMerge && phase != .falling,
                isCovered: isCovered,
                onTap: {
                    if !isExpanded {
                        onTapExpandBlock(block.id)
                    }
                },
                onDoubleTap: onDoubleTapBlock.map { action in { action(block.id) } },
                onLongPress: onLongPressBlock.map { action in { action(block.id) } },
                isLifted: liftedBlockID == block.id
            )
            // No `matchedGeometryEffect`. It served the expansion card
            // the edit sheet replaced, nothing else was in its namespace,
            // and SwiftUI still tracked every block's geometry for it on
            // every transaction. The opacity stays: it hides the edited
            // block behind its sheet, which is still what you see.
            .opacity(isExpanded ? 0 : block.isSkipped ? 0.30 : 1)
            .overlay {
                // Skipped block diagonal lines
                if block.isSkipped {
                    Canvas { context, size in
                        let step: CGFloat = 8
                        var path = Path()
                        var x: CGFloat = -size.height
                        while x < size.width {
                            path.move(to: CGPoint(x: x, y: size.height))
                            path.addLine(to: CGPoint(x: x + size.height, y: 0))
                            x += step
                        }
                        context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .scaleEffect(x: impactScaleX, y: impactScaleY, anchor: .bottom)
            // The wobble, the impact flash and the landing shadow, only on
            // a block that has dropped. At rest all three are zero, and a
            // tower that opens on sixty blocks was stacking a zero
            // rotation, a zero brightness filter and a clear shadow on
            // every one of them. See `BlockAnimationState.hasDropped` for
            // why the switch is one-way.
            .modifier(DropOnlyEffects(
                active: animState.hasDropped,
                wobbleDegrees: wobbleDegrees,
                flashBrightness: flashBrightness,
                // A block still in the air is `.carried` — it is off the
                // page and the shadow is what says so. See `Elevation`.
                shadowColor: phase != nil
                    ? Elevation.carried.color(in: colorScheme) : .clear,
                shadowRadius: dropShadowRadius,
                shadowY: dropShadowY
            ))
            // **NO SECOND SHADOW, AND THIS IS MOST OF WHY THEY READ
            // STRONG.**
            //
            // There was a row-progressive ambient shadow here — 0.04 ink at
            // a radius that grew with height, cited to Mamassian 1998 —
            // stacked UNDER `BlockSurface`'s own 0.032. Every block in the
            // tower was casting two shadows, so the ink under one was half
            // again what either number says and the gutter between two
            // neighbours took both of theirs. The owner: "they feel a bit
            // too strong... especially for an ethereal theme."
            //
            // The depth cue goes with it rather than being folded in. At
            // 0.04 to 0.06 across the whole height of a tower it was never
            // legible as height on its own, and `Elevation` is one rung per
            // object: a block at the crown is standing on the block below
            // it exactly as firmly as that one stands on the page.
            // Foundation darkening removed.
            //
            // Measured: a merged shape rendered (14,173,116) and a
            // standalone block of the same colour (9,168,111). The entire
            // difference was this 2% — a merged run draws one flat fill and
            // never had it. So a block landing into a group visibly
            // lightened at the moment it joined, which is precisely the
            // thing a merge must not do. Two percent was never legible as a
            // depth cue on its own, and the contact shade does that job
            // properly now.
            // Crown — white top edge on topmost blocks
            .overlay(alignment: .top) {
                if isCrown {
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(height: 1)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .offset(y: dropOffset + animState.microBounceY)
        }
        .scaleEffect(x: rippleScaleX, y: rippleScaleY, anchor: .bottom)
        .offset(y: rippleOffsetY)
        // No per-row parallax.
        //
        // Higher rows used to shift more than lower ones as the tower
        // scrolled, as a depth cue. It is the one effect that directly
        // contradicts the tower being a single structure: the rows slide
        // against each other, and because `towerScrollOffset` was only
        // republished in 8pt steps then, it did it in visible jumps rather
        // than smoothly. The tower moves as one object or it is not one object.
        // The dance is applied by the grid, not here. See `placedBlocksGrid`.
    }

    /// Drop-only effects, in the order they were always applied.
    ///
    /// The MODIFIER is conditional, not its values (CLAUDE.md, on
    /// `.gesture(cond ? g : nil)`): a zero-valued effect is still an effect.
    private struct DropOnlyEffects: ViewModifier {
        let active: Bool
        let wobbleDegrees: Double
        let flashBrightness: Double
        let shadowColor: Color
        let shadowRadius: CGFloat
        let shadowY: CGFloat

        func body(content: Content) -> some View {
            if active {
                content
                    .rotation3DEffect(.degrees(wobbleDegrees), axis: (x: 0, y: 0, z: 1))
                    .brightness(flashBrightness)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            } else {
                content
            }
        }
    }

    /// **The socket a block falls into is the socket it was pressed out
    /// of** (2026-10-01, `docs/consistency-audit.md` 1.12).
    ///
    /// This was eight private lines: `.ultraThinMaterial` plus a 1pt
    /// `Color.white.opacity(0.2)` stroke. `SlotGlass.glassSlot` is the
    /// shared recipe and its own note is the argument this broke, word for
    /// word: "The fallback deliberately draws no white rim ... CLAUDE.md
    /// forbids giving a surface a white rim or a frosted edge because that
    /// is a block's own claim to be a lit object you built, and this
    /// surface is already block-shaped and block-sized."
    ///
    /// That is exactly what this was — block-shaped, block-sized, with the
    /// rim — and it is on screen only while a block is in the air above it,
    /// which is why a year of looking at the tower never caught it. The
    /// slot's own recess goes under the glass, as `NextSlotButton` draws
    /// it, so the hole reads as a hole on both paths and on both schemes
    /// rather than as a pale block with a lit edge.
    private func ghostSlot(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.slotInk.opacity(colorScheme == .dark ? 0.075 : 0.038))
            .frame(width: width, height: height)
            .glassSlot(cornerRadius: cornerRadius)
    }
}
