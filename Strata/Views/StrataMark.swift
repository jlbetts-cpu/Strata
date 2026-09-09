import SwiftUI

/// The app's mark: a block with the S cut out of it.
///
/// Jaro's S is not a curve — it is an angular ribbon, and its outline has four
/// INNER corners. Cutting the glyph on those four lines splits it into exactly
/// the five strokes the letterform is built from, with no seam landing
/// anywhere arbitrary and the geometry of the letter untouched. Each piece is
/// then one of the app's blocks.
///
/// This is the same construction as the app icon, from the same generator, so
/// the thing on the home screen and the thing inside the app cannot drift into
/// two different logos.
///
/// It was five coloured bands for a day. That reads beautifully at 1024px and
/// turns to mush at 50 — the two riser bands come out four pixels tall and the
/// colours average into a blob. One colour, with the field showing through the
/// seams, survives every size the mark is drawn at, and it is the pink the app
/// had before any of this.
///
/// The polygons are generated rather than typed:
///
///     python3 tools/make_app_icon.py --swift
///
/// **Why this does not just use `BlockSurface`.** That takes a
/// `RoundedRectangle` and reaches for `strokeBorder`, which needs an
/// `InsettableShape`; these pieces are irregular polygons. The anatomy below
/// is the same one — flat colour, a 10% wash, a rim brightest along the top
/// edge, and the frosted band over the bottom 26% — reproduced for a `Path`.
/// If `BlockSurface` changes, change this with it.
struct StrataMark: View {
    var side: CGFloat = 44

    /// Mindfulness pink. The mark is a block, so it wears a block's colour
    /// rather than a brand colour invented alongside them.
    private var pink: Color { HabitCategory.mindfulness.style.baseColor }

    var body: some View {
        BlockSurface(
            cornerRadius: GridConstants.blockCornerRadius(forCell: side),
            // Rim weight and blur are absolutes tuned to the tower's cell; at
            // 44pt an unscaled 1.4pt rim is nearly twice as heavy in
            // proportion. `BlockSurface` already takes the ratio.
            scale: side / GridConstants.blockReferenceCell
        ) {
            pink
        }
        .frame(width: side, height: side)
        .overlay {
            // 0.88, not the 0.62 an SF Rounded S wanted. Jaro's S is a much
            // narrower letterform, so the same fraction left it floating in
            // the middle of the block with margin on every side. This puts its
            // cap height at ~58% of the block.
            Text("S")
                .font(JaroFont.size(side * 0.88))
                .foregroundStyle(.white)
                // The letter's optical centre sits slightly below its bounding
                // box centre, which is why this is not simply centred.
                .offset(y: -side * 0.01)
        }
        .accessibilityLabel("Strata")
    }
}

/// The app's name.
///
/// One view so the camera's wordmark and the Settings header cannot drift into
/// two different sizes of the same word.
///
/// Set in Jaro, which is what it was and what it is again (2026-09-09,
/// owner's call). It was briefly SF Pro Rounded Semibold, on the argument that
/// a heavy angular slab fought the mark beside it. That was true of the
/// five-colour mark it was standing next to; against one pink block with a
/// white letter on it, Jaro is the letter and the wordmark is the same
/// letterform larger.
///
/// One consequence worth keeping: the app is back to exactly two system
/// weights, because Jaro has one and needs no exception.
struct StrataWordmark: View {
    var size: CGFloat = 28
    var color: Color = .primary

    var body: some View {
        Text("Strata")
            .font(JaroFont.size(size))
            .foregroundStyle(color)
            .accessibilityLabel("Strata")
    }
}
