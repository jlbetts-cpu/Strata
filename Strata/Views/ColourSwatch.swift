import SwiftUI

/// **A category, as one chip, on every screen that offers the choice.**
///
/// Every swatch in the app was a flat `Circle().fill(baseColor)` — the add
/// sheet's picker, Profile's background chooser, the map's pins. A block is a
/// body with a light in it and a lit edge; a swatch of the same colour, drawn
/// flat and square-edged a screen away, says the colour is a label rather than
/// the thing you are about to build with.
///
/// Same fill, same rim, same light. Picking a colour now looks like picking a
/// block, because that is what it is.
///
/// ## The four axes, settled 2026-10-01
///
/// The owner found this one himself: "I see the colour on the plan isnt the same
/// as the wins edit sheet with the icons and stuff." `docs/consistency-audit.md`
/// §1.1 counted it at four differences on one idea — circle against rounded
/// square, glyph against none, ring against checkmark, this component against a
/// private `BlockSurface` build in `PlanItemDetailSheet`. All four are decided
/// here now, and this type is the only thing that draws them.
///
/// **The shape is the CIRCLE, and that is the owner's own call rather than a
/// tie-break.** `AddWinSheet` records it: "These were briefly blocks, on the
/// rule that every surface you can act on is one. The owner preferred the
/// circles (2026-09-09) and that settles it: a swatch is not a block you are
/// placing, it is a property of the block you are describing, and a round chip
/// reads as a property in a way a small square does not."
///
/// `PlanItemDetailSheet` had the opposite argument in writing — "a row of
/// swatches would be a picture of a colour, and this is a picture of a block" —
/// and it loses on three counts beyond the date.
///
/// **A plan line already draws a block, at the head of every row.**
/// `PlanBullet` is block-shaped and block-cornered empty, and on completion it
/// becomes a real `BlockSurface` in the line's own colour. So a block-shaped
/// swatch said "block" a second time on a sheet that opens from that list, while
/// nothing on the row said which CATEGORY — which is the fact a person is
/// actually setting here.
///
/// **And the checkmark meant two things on one screen.** `PlanBullet`'s done
/// state is a white checkmark on a coloured block; the swatch's selected state
/// was a white checkmark on a coloured block. One of them says "this line is
/// finished" and the other said "this colour is chosen", in the same drawing,
/// one sheet apart. The ring leaves the checkmark meaning exactly one thing.
///
/// Both
/// designs were built and rendered at 402x874 in both schemes before this was
/// written (`/tmp/c1/swatch-circle/` and `/tmp/c1/swatch-square/`), and the
/// square lost on a measurement neither argument had reached for:
///
/// **A ring offset from a circle is still concentric. A ring offset from a
/// rounded rectangle is not.** The chip is 34pt at
/// `blockCornerRadius(forCell: 34)` = **4.72pt**, and the ring is the same shape
/// at 38pt — so the outer corner keeps the inner one's radius where staying
/// concentric would need 6.72. Measured off the geometry and visible in the
/// render: the gap between the ring and the chip is **2.00pt on the flats and
/// 2.83pt on the 45-degree diagonal, a 41% swing around one chip**, where a
/// circle holds 2.00 the whole way round by construction. Correcting it means a
/// second radius that exists only for this control, which is a rung off the
/// ladder — and the ladder is what `blockCornerRadius(forCell:)` is for.
///
/// The second thing the renders showed is not a number: six 34pt rounded squares
/// with a white symbol on each read as a row of app icons, which is the one
/// thing a category chip must not look like.
///
/// **The glyph is on, both places.** It is the only thing in the row that names
/// the category rather than its colour, and six pastels with nothing in them is
/// a row you have to learn. Six selectable categories, six symbols, no nil
/// (`HabitCategory.iconName`; `unlabeled` is the only nil and is never offered).
///
/// **The mark is the RING, not a checkmark, and nothing scales.** The ring sits
/// two points outside the chip's own edge at 0.55 ink. A checkmark inside the
/// chip covers the colour it is selecting, and the 0.86 scale the plan line used
/// was the third copy of a defect `FilmLookStrip` already measured and removed:
/// `scaleEffect` does not change a layout box, so the boxes stay 44pt apart
/// while the DRAWN circles move, and the row's rhythm then depends on which one
/// is chosen. `docs/consistency-audit.md` §3.2 counted three scale steps for one
/// idea — 1.0, 0.94 and 0.86. **This app's answer: selection is a ring on the
/// chosen shape's own edge, and nothing moves.**
struct ColourSwatch: View {
    var colour: Color
    /// The category's own symbol, drawn white on the colour. Nil draws a bare
    /// chip, which is what Profile's background chooser wants — there the colour
    /// is the whole of the choice and there is no category to name.
    var glyph: String? = nil
    var isSelected: Bool = false
    var side: CGFloat = ColourSwatch.side

    @Environment(\.colorScheme) private var colorScheme

    /// **One shape, named once**, so the chip, its rim and its ring cannot
    /// disagree about what they are drawn around — and so that rendering the
    /// rejected square candidate was one line rather than a rebuild. See the
    /// shape argument in this type's own documentation, and the measurement that
    /// came off those two renders.
    private var shape: Circle { Circle() }

    var body: some View {
        ZStack {
            shape
                .fill(EtherealFill.fill(colour))
                .frame(width: side, height: side)
                .overlay {
                    // **Scaled, with a floor.** A block's 1.9pt rim is 2% of an
                    // 86pt side; drawn at that weight on a 34pt swatch it is 6%,
                    // which stops being a lit edge and becomes a white ring drawn
                    // around a dot. `BlockSurface` scales its rim for exactly
                    // this reason wherever the cell is not the tower's. The floor
                    // is because half a point of white on a saturated circle is
                    // antialiasing rather than an edge.
                    shape.strokeBorder(
                        BlockRim.gradient(in: colorScheme),
                        lineWidth: max(1, GridConstants.blockRimWidth
                                          * side / GridConstants.blockReferenceCell))
                }

            if let glyph {
                // `GridConstants.iconCategory`, the token every other category
                // glyph in the app is drawn at, through `IconStyle` so it grows
                // with the user's text size instead of staying put while the row
                // around it grows (`iconSize`, WCAG 1.4.4). The add sheet typed
                // the 13 as a literal.
                Image(systemName: glyph)
                    .iconSize(GridConstants.iconCategory, relativeTo: .footnote, weight: .medium)
                    .foregroundStyle(.white)
            }

            if isSelected {
                shape
                    // **`inkPrimary`, not `.primary.opacity(0.75)`.** CLAUDE.md's
                    // rule is that this is not a colour, it is a colour in light
                    // mode: 75% black on a near-white page and 75% white on a
                    // near-black one, which are not the same weight. The token is
                    // the adaptive form of exactly this ink.
                    //
                    // **IT HUGS THE SWATCH, AND IT IS NOT BLACK.** A
                    // full-strength `inkPrimary` ring at 42 around a 34pt circle
                    // is a hard black outline floating four points off the thing
                    // it selects — the only pure ink ring in the app, on a row of
                    // pastels, which made the chosen colour look stickered rather
                    // than chosen.
                    //
                    // **38 sits ON the swatch's edge, and the "two points of air"
                    // the old comment claimed was never drawn.** `strokeBorder`
                    // insets inward, so a 2pt stroke on a 38pt circle runs from
                    // r=19 to r=17 and the chip's radius IS 17: the ring is
                    // adjacent to the chip and lies wholly on the page. Measured
                    // off the built sheet at 3x, the ring runs x=192 to 197 and
                    // the chip begins at 198.
                    //
                    // **So the ratio that governs it is the ring against the
                    // PAGE, not against the chip**, and it clears in both
                    // schemes: rgb(131) on the rgb(246) page is **3.51:1**, and
                    // rgb(145) on the rgb(31) night ground is **5.19:1**, against
                    // the 3:1 a shape is held to. Against the chip it is 1.47 and
                    // 1.29, which is the number somebody will quote at this one
                    // day: it is the wrong number, because no part of the ring is
                    // drawn on the chip.
                    //
                    // Selection has to be obvious; it does not have to shout.
                    .strokeBorder(AppColors.inkPrimary.opacity(0.55),
                                  lineWidth: GridConstants.strokeMedium)
                    .frame(width: side + Self.ringGap * 2,
                           height: side + Self.ringGap * 2)
            }
        }
        // The target is the chip's box, not its artwork, at every call site. A
        // swatch sized to its own drawing is a swatch you have to aim at.
        .frame(width: Self.target, height: Self.target)
        .contentShape(Rectangle())
    }

    /// A swatch's own artwork, unringed.
    ///
    /// Not `private`: `SheetRoomTests` works out, from this and the ring, how
    /// much empty box a measured gap above a colour row carries, and therefore
    /// whether the tight end of a sheet's ladder still clears check 11b's 17pt
    /// ceiling. It is the WORST case for that, since a swatch with no ring on it
    /// is 5pt narrower than its box on each side rather than 3.
    ///
    /// `PlanItemDetailSheet` named the same number separately and its own comment
    /// said it was "typed three times in one expression" there — once as a
    /// radius, once as a scale and once as a frame. One number, one place.
    static let side: CGFloat = 34

    /// The air between the chip's edge and the selection ring. Two points: on the
    /// swatch's own edge, not floating off it.
    static let ringGap: CGFloat = 2

    /// The selection ring's diameter at the default size, which is the widest
    /// thing ever drawn inside the 44pt box.
    static let ringSide: CGFloat = side + ringGap * 2

    /// The HIG's minimum target, measured not declared, and the box every swatch
    /// is drawn inside.
    static let target: CGFloat = 44

    /// Half the difference between the 44pt target and the WIDEST thing drawn
    /// inside it, which is the 38pt ring and not the 34pt circle.
    ///
    /// Measured off the built sheet with a colour chosen: the ring's leading edge
    /// came out at 14.0 while the name, both labels, the picker and the well all
    /// start at 16. The pass that pulled the add sheet's row onto the margin
    /// measured the chip and left the mark two points outside it, so the row was
    /// on the margin exactly until you used it.
    ///
    /// The price is that the six circles sit at 18.0 instead of 16.0. That is the
    /// better trade: two points on a row of round shapes is invisible, because a
    /// circle's optical edge is inside its box anyway, and a mark that appears
    /// and shoves the row off the margin is a thing that moves.
    static let inset: CGFloat = (target - ringSide) / 2
}

/// **The row of them, so two sheets cannot drift again.**
///
/// `docs/consistency-audit.md` §3.1 counted `ColourSwatch` at one call site with
/// two private re-implementations. Sharing the chip alone would have left the
/// spacing, the leading correction, the tap target, the press, the haptic, the
/// animation and the accessibility container to be rebuilt per screen, which is
/// how the chip drifted in the first place. One row, two callers.
struct ColourSwatchRow: View {
    @Binding var category: HabitCategory
    /// Whether to draw the ring at all. The add sheet hides it when a photograph
    /// covers the colour: a ring would then be claiming a kind of win, and for a
    /// win nobody gave one that claim is untrue.
    var showsSelection: Bool = true
    /// Called after `category` is written, for a caller that has to record that
    /// the choice was made by a person rather than defaulted.
    var onPick: (HabitCategory) -> Void = { _ in }

    var body: some View {
        // 4pt, the grid's own gutter. The circles are 34 inside 44pt targets, so
        // there is already 10pt of air between them before any spacing at all;
        // the 6 the add sheet had is not a rung, and the plan line's 2 was a
        // sixth spacing value for the same kind of row.
        HStack(spacing: GridConstants.spacing) {
            ForEach(HabitCategory.selectable, id: \.self) { cat in
                let isSelected = showsSelection && category == cat
                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSnappy) { category = cat }
                    onPick(cat)
                } label: {
                    ColourSwatch(colour: cat.style.baseColor,
                                 glyph: cat.iconName,
                                 isSelected: isSelected)
                }
                // The app's press, not `.plain`. A 34pt chip on a page has no
                // background to shift, so the glyph row's scale-and-dim is the
                // whole of the answer — see `PressResponse`, whose own doc named
                // this class of control and had no call sites.
                .buttonStyle(.press)
                .accessibilityLabel(cat.rawValue)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        // **PULLED BACK ONTO THE MARGIN.**
        //
        // Measured off the built sheet: the title's text, the photo well and the
        // COLOUR label all start at 16pt, and the first swatch started at 21. A
        // 34pt circle centred in its 44pt tap frame leaves air on its leading
        // edge, so the row LOOKED indented while every number in the layout said
        // it was not. The frame keeps its 44 — the target is not negotiable — and
        // the row is shifted by exactly the air.
        // `GridConstants.tallyOpticalInset` is the same correction for the same
        // reason on the tower's count.
        .padding(.leading, -ColourSwatch.inset)
        // **The word "Colour" is gone from the page and kept for VoiceOver**, on
        // both sheets now.
        //
        // The rule is `AddWinSheet`'s: cut a label when the screen performs it,
        // keep it when the screen only states it. The plan line kept its
        // `FormSectionLabel("Colour")` on the argument that nothing on that sheet
        // demonstrated what the row set — true of a row of six bare pastels. With
        // the glyphs on, each chip names its own category, so the row states what
        // it is and the word above it is the same fact a third time, after the
        // colour and after the symbol.
        //
        // `.contain` rather than `.combine`: the six discs stay individually
        // focusable and individually selectable — combining them would make the
        // row one element and take the choice away from the people this is for.
        // What the container adds is the sentence the deleted label used to read
        // out, announced on entering the row.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Colour")
    }
}
