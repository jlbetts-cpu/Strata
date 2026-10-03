import SwiftUI
import SwiftData

// MARK: - Smart Brick View (Clay Cartridge)

struct FlippableBlockView: View {
    /// The lamp over the tower this block is standing in, if it is in one. See
    /// `BlockLight`: one light for the whole stack, so where a block stands
    /// decides which of its corners catches it.
    @Environment(\.blockLight) private var blockLight
    @Environment(\.colorScheme) private var colorScheme

    let block: PlacedBlock
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let modelContext: ModelContext
    /// True when this block is part of a merged run.
    ///
    /// The run is drawn once, as one shape, by `MergedGroupView` — so a settled
    /// member draws nothing at all and exists only for its tap target. That is
    /// what makes a merge genuinely one object: there is no second outline, no
    /// second band and no second shadow to leak through a seam, because there
    /// is no second anything.
    ///
    /// A member still draws itself while FALLING, so a block descends as a
    /// block and joins the shape on landing.
    var isGroupMember: Bool = false
    /// Drop the rim, the frosted band and the shadow.
    ///
    /// Set the instant a merging block LANDS. In the air it is a separate
    /// object and looks like one; on the ground it is about to be part of a
    /// larger shape, and a rim is an outline drawn around something that is
    /// supposed to have no edge there. Filmed at 60fps, that white outline was
    /// the last thing still announcing the join.
    var chromeless: Bool = false
    /// Something is resting directly on this block.
    var isCovered: Bool = false
    var onTap: (() -> Void)? = nil
    /// A crew block's double-tap: a heart, as on a photo in Instagram. Nil
    /// everywhere else, which keeps the single tap there immediate: a block
    /// that listens for two taps has to wait out the first (about 250ms).
    var onDoubleTap: (() -> Void)? = nil
    /// A crew block's press and hold: the reaction bar. Nil everywhere else.
    var onLongPress: (() -> Void)? = nil
    var showOverlay: Bool = true
    /// True while this block is the one being carried.
    var isLifted: Bool = false
    /// True when releasing would land the carried block here.

    @State private var tapTrigger: Int = 0

    @Environment(\.displayScale) private var displayScale
    @Environment(\.towerFilterMode) private var towerFilterMode
    @Environment(\.perfectDayDates) private var perfectDayDates
    /// **The tower honours Reduce Motion** (2026-10-01).
    ///
    /// `docs/motion-audit.md` named this file as the worst of the twelve that
    /// did not: it is what the tower actually renders, so with the setting on
    /// every block in the stack still squashed and popped on every tap, and
    /// the lift still sprang. Nineteen files in the app honoured the setting
    /// and the one the owner looks at most did not.
    ///
    /// Gated to a cut rather than to nothing. A tap still has to be ANSWERED,
    /// and it is: the haptic fires either way, and the block's own `brightness`
    /// step still lands, just without the scale and without a spring carrying
    /// it. Reduce Motion asks for less motion, not less feedback.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // displayCategory, not category: an unchosen block still needs a colour.
    private var style: CategoryStyle { block.look.displayCategory.style }
    private var hasImage: Bool { block.look.hasPhoto }
    private var massTier: CGFloat { CGFloat(block.look.blockSize.massTier) }
    private var tapSquashX: CGFloat { 1.02 - (massTier - 1) * 0.004 }
    private var tapSquashY: CGFloat { 0.97 + (massTier - 1) * 0.006 }

    private var patinaOpacity: Double {
        guard towerFilterMode != .day else { return 0 }
        guard perfectDayDates.contains(block.look.dateString) else { return 0 }
        guard let blockDate = BlockTimeFormatter.dateFormatter.date(from: block.look.dateString) else {
            return GridConstants.patinaMaxOpacity
        }
        let daysAgo = max(0, Calendar.current.dateComponents([.day], from: blockDate, to: Date()).day ?? 0)
        return min(GridConstants.patinaMaxOpacity, 0.05 + Double(daysAgo) * GridConstants.patinaGrowthRate)
    }

    var body: some View {
        // A member hides instantly. No crossfade.
        //
        // Fading it out was meant to soften the handover, and filmed at 60fps
        // it did the opposite: for the fifth of a second it took, the block was
        // half-transparent over a group that did not yet include its cell, so
        // the page showed through as a pale square sitting in the middle of the
        // shape. That is the ghost.
        //
        // Both this flag and the group's cells come from the same set —
        // `activelyAnimatingIDs`, cleared in one transaction with `dropPhase` —
        // so the block disappears on exactly the frame the group takes over.
        // With the colours identical and the chrome already stripped, that swap
        // has nothing left to see.
        Group {
            if isGroupMember {
                // A member draws its LABEL and nothing else.
                //
                // The run's surface — the fill, the rim, the band, the shadow
                // — is drawn once by `MergedGroupView`, so a member drawing
                // its own would put a second outline through the middle of one
                // shape. But now that named blocks merge, it still has
                // something to say: the words sit on the merged surface the
                // way words sit on a wall, and the wall is still one wall.
                BlockContentOverlay(
                    title: block.look.title,
                    rowSpan: block.rowSpan,
                    hasImage: false
                )
                .frame(width: width, height: height)
            } else {
                blockBody
            }
        }
            // The tap belongs to the BLOCK, not to its chrome.
            //
            // It used to be attached inside `chromedBody`, which a merged
            // block never reaches: merging makes it `chromeless`, and that
            // branch is a bare rounded rect. So every block that had joined a
            // group silently lost its tap target and there was no way to open
            // a merged block to edit it. A member is also drawn at zero
            // opacity, so the hit area has to be declared here, after that,
            // rather than inherited from something visible.
            // Picked up, or marked as where it would land.
            //
            // A lifted block scales UP and gains a shadow — the two things
            // that read as "off the surface" without moving it, so the finger
            // stays over what it grabbed. The target dims rather than growing:
            // if both changed size the whole tower would ripple while you
            // dragged, and only one of them is in your hand.
            .scaleEffect(isLifted ? 1.06 : 1)
            // `.carried` is the one rung that is meant to be seen, because here
            // the shadow IS the information: the gap between the block and the
            // page is what the gesture is about. See `Elevation`.
            .shadow(
                color: isLifted ? Elevation.carried.color(in: colorScheme) : .clear,
                radius: isLifted ? Elevation.carried.radius : 0,
                y: isLifted ? Elevation.carried.y : 0
            )
            // No dimming of the other blocks.
            //
            // That was here to make the lift legible when a 6% scale was the
            // only signal. It is not needed now and it actively hurts: the
            // whole point of reflowing live is to show you the rearranged
            // TOWER, and dimming forty blocks to 0.4 hides the very thing you
            // are being shown.
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.slotSnap,
                       value: isLifted)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // **No press without somewhere to go.** A block with no `onTap`
            // (a past day's block with no photograph, the share card) used to
            // squash and tick and then open nothing, which reads as a fault
            // rather than a toy (2026-10-02, design review, `day-album.md` #1).
            // `including: .subviews` keeps the gesture's place in the tree and
            // simply stops it answering.
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        HapticsEngine.lightTap()
                        tapTrigger += 1
                        onTap?()
                    },
                including: onTap == nil || onDoubleTap != nil ? .subviews : .all
            )
            // Two taps or one, exclusively, only where a double-tap means
            // something. Both stay attached so the block keeps its identity;
            // the mask decides which one answers.
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        tapTrigger += 1
                        onDoubleTap?()
                    }
                    .exclusively(before: TapGesture().onEnded {
                        HapticsEngine.lightTap()
                        tapTrigger += 1
                        onTap?()
                    }),
                including: onDoubleTap == nil ? .subviews : .all
            )
            // Held: the reactions, at the moment the hold is long enough,
            // not on release, as Messages does it. Simultaneous, so the
            // tower still scrolls under a finger that moves.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35, maximumDistance: 10)
                    .onEnded { _ in onLongPress?() },
                including: onLongPress == nil ? .subviews : .all
            )
            .overlay(alignment: .topTrailing) {
                if !block.look.reactionEmoji.isEmpty, !isGroupMember {
                    ReactionBadge(emoji: block.look.reactionEmoji, count: block.look.reactionCount,
                                  mine: block.look.myReaction != nil)
                        .padding(5)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.elasticPop,
                       value: block.look.reactionEmoji)
            .modifier(CrewBlockSpeech(look: block.look, isCrew: onDoubleTap != nil,
                                      open: onTap, react: onLongPress))
    }

    @ViewBuilder
    private var blockBody: some View {
        if chromeless {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(style.baseColor)
                .frame(width: width, height: height)
        } else {
            chromedBody
        }
    }

    /// Where the light falls on THIS block. Overhead when there is no tower
    /// light — a block in a replay frame or a preview is its own object.
    private var aim: BlockAim {
        blockLight?.aim(column: block.column, row: block.row,
                        columnSpan: block.columnSpan, rowSpan: block.rowSpan)
            ?? .overhead
    }

    private var chromedBody: some View {
        BlockFace(
            title: block.look.title,
            category: block.look.displayCategory,
            rowSpan: block.rowSpan,
            width: width,
            height: height,
            cornerRadius: cornerRadius,
            hasPhoto: hasImage,
            // No time. `BlockContentOverlay` has not drawn one since the tower
            // stopped showing timestamps, and the parameter that carried it is
            // gone rather than being passed `nil` through two views.
            showOverlay: showOverlay,
            aim: aim
        ) {
            if let shared = block.look.sharedPhoto {
                // A friend's photograph, from the crew's cache. Never through
                // `CachedImageView`, whose file names are YOUR photographs.
                CrewPhotoView(url: shared, width: width, height: height,
                              crop: CGPoint(x: block.look.cropX ?? 0, y: block.look.cropY ?? 0))
            } else {
                CachedImageView(
                    fileName: block.look.imageFileName,
                    width: width,
                    height: height,
                    cornerRadius: 0,
                    crop: CGPoint(x: block.look.cropX ?? 0,
                                  y: block.look.cropY ?? 0),
                    // The block's own colour is what shows while this decodes.
                    showsPlaceholder: false
                )
            }
        }
        // CONTACT SHADE.
        //
        // Stacked objects darken where another one sits on them. Without it
        // every block is lit as if it were alone, and a tower of them reads as
        // tiles on a wall rather than as a structure carrying its own weight.
        // Top edge only, short, and never across a merged seam — inside one
        // piece there is nothing resting on anything.
        .overlay {
            if isCovered {
                // Clipped to the block's own shape.
                //
                // Unclipped, this filled the square corners OUTSIDE the rounded
                // rect — a hard grey wedge at each top corner that read as a
                // rendering glitch, which is exactly what it was. It also has
                // to sit inside a full-size container: a 14pt-tall view clipped
                // to a 12pt corner radius rounds the gradient itself instead of
                // following the block.
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            AppColors.warmBlack.opacity(GridConstants.blockContactShade),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(14, height * 0.22))
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
        }
        // Perfect-day patina — golden surface wash
        .overlay {
            if patinaOpacity > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(GridConstants.patinaGold.opacity(patinaOpacity * 0.5))
                    .blendMode(.overlay)
            }
        }
        // Tap bounce: fast squash → bouncy pop-back. With Reduce Motion the
        // squash is 1.0 on both axes, so the block does not move and only the
        // brightness step plays, on `crossFade`. See `reduceMotion` above.
        .phaseAnimator([false, true], trigger: tapTrigger) { content, phase in
            content
                .scaleEffect(
                    x: phase && !reduceMotion ? tapSquashX : 1.0,
                    y: phase && !reduceMotion ? tapSquashY : 1.0
                )
                .brightness(phase ? -0.03 : 0)
        } animation: { phase in
            if reduceMotion { GridConstants.crossFade }
            else { phase ? GridConstants.tapSquashSpring : GridConstants.tapPopSpring }
        }
        // #495: Smart Invert — photos excluded from color inversion
        .accessibilityIgnoresInvertColors(hasImage)
    }
}

/// A crew block's reactions, in its corner: up to three emoji overlapping, and
/// the count when more people reacted than there are emoji shown. Small glass,
/// so it reads on a colour and on a photograph alike.
struct ReactionBadge: View {
    let emoji: [String]
    let count: Int
    /// You reacted.
    var mine = false

    /// **Quiet** (the owner, 2026-10-03: "the reactions in the crew right now
    /// they feel too loud like in the pill... can we make it feel a bit more
    /// minimal"). One emoji, the one most given (yours first, when you gave
    /// one), at the page's smallest size and on no chip; a small white count beside it
    /// when more than one person reacted. Yours sits on a soft white dot, so
    /// you can tell at a glance without it shouting. Who gave what is in the
    /// carousel's line.
    var body: some View {
        HStack(spacing: 3) {
            if let first = emoji.first {
                Text(first)
                    .font(Typography.screenSubtitle)
                    .padding(2)
                    .background {
                        if mine { Circle().fill(Color.white.opacity(0.55)) }
                    }
            }
            if count > 1 {
                Text("\(count)")
                    .font(Typography.headerSmall)
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.92))
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((count == 1 ? "1 reaction, \(emoji.joined(separator: " "))"
                                        : "\(count) reactions, \(emoji.joined(separator: " "))")
                            + (mine ? ", yours among them" : ""))
    }
}


/// **A crew block, said aloud** (the 2026-10-03 audit). Whose win it is, what,
/// and how many reacted, as one element; Open and React as actions, because
/// a hold and a double tap are gestures VoiceOver users cannot make. Your own
/// tower's blocks are left as they were.
private struct CrewBlockSpeech: ViewModifier {
    let look: PlacedBlock.Look
    let isCrew: Bool
    var open: (() -> Void)?
    var react: (() -> Void)?

    func body(content: Content) -> some View {
        if isCrew {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { open?() }
                .accessibilityAction(named: "React") { react?() }
        } else {
            content
        }
    }

    private var label: String {
        let who = look.sender.map { "\($0)'s win" } ?? "Your win"
        let what = look.title.isEmpty ? (look.hasPhoto ? "a photo" : "untitled") : look.title
        let reactions = look.reactionCount == 0 ? ""
            : (look.reactionCount == 1 ? ", 1 reaction" : ", \(look.reactionCount) reactions")
        let yours = look.myReaction.map { ", you reacted \($0)" } ?? ""
        return "\(who), \(what)\(reactions)\(yours)"
    }
}
