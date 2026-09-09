import SwiftUI

/// The app's mark: the S, taken apart into the blocks it is made of.
///
/// Jaro's S is not a curve — it is an angular ribbon, and its outline has four
/// INNER corners. Cutting the glyph on those four lines splits it into exactly
/// the five strokes the letterform is built from, with no seam landing
/// anywhere arbitrary and the geometry of the letter untouched. Each piece is
/// then one of the app's blocks.
///
/// This is the same construction as the app icon, from the same generator, so
/// the thing on the home screen and the thing inside the app cannot drift into
/// two different logos. It replaced a pink block with a white letter on it,
/// which stopped matching the icon the moment the icon became this.
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
    /// The mark's height. Width follows from the letterform.
    var height: CGFloat = 44

    private var width: CGFloat { height * Self.aspect }

    /// Bottom to top, matching the icon. The order was chosen by measuring
    /// CIELAB distance between touching blocks, not by eye — see
    /// `tools/make_app_icon.py`.
    private static let colours: [HabitCategory] = [
        .mindfulness, .health, .creativity, .focus, .work
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Self.bands.enumerated()), id: \.offset) { index, points in
                block(points, category: Self.colours[index])
            }
        }
        .frame(width: width, height: height)
        .accessibilityLabel("Strata")
    }

    private func block(_ points: [CGPoint], category: HabitCategory) -> some View {
        let path = Self.path(points, width: width, height: height)
        let box = path.boundingRect
        // Blur is a fraction of the block's WIDTH, as it is on a real block —
        // never of the rim, which is a separate element.
        let blur = max(0.4, box.width * 0.0178)

        return surface(path, category: category)
            .mask(alignment: .topLeading) {
                // The sharp copy reaches down to the band and stops; the
                // blurred one underneath is already at full opacity by then,
                // so the two never sum to less than opaque.
                LinearGradient(
                    stops: [
                        .init(color: .white, location: GridConstants.blockBandFeatherEnd),
                        .init(color: .clear, location: min(1, GridConstants.blockBandFeatherEnd + 0.12))
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: box.width, height: box.height)
                .offset(x: box.minX, y: box.minY)
            }
            .background(alignment: .topLeading) {
                surface(path, category: category)
                    .blur(radius: blur)
                    // Clipped back to its own block. `BlockSurface` lets the
                    // blur spill past the bottom edge, which is right on the
                    // tower because the 4pt gutter catches it. There is no
                    // gutter here, so the spill would land on the block below
                    // and mix two colours into a dirty seam.
                    .clipShape(path)
            }
    }

    private func surface(_ path: Path, category: HabitCategory) -> some View {
        ZStack {
            path.fill(category.style.baseColor)
            path.fill(.white.opacity(GridConstants.blockScrimOpacity))
            // The rim, brightest along the top edge: a block is lit from
            // above, not outlined. Stroked at double width and clipped, which
            // is the inner border `strokeBorder` would give if a `Path` were
            // insettable.
            path.stroke(
                LinearGradient(
                    colors: [.white, .white.opacity(GridConstants.blockRimFalloff)],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: GridConstants.blockRimWidth * 2 * (height / (5 * GridConstants.blockReferenceCell))
            )
            .clipShape(path)
        }
    }

    private static func path(_ points: [CGPoint], width: CGFloat, height: CGFloat) -> Path {
        var p = Path()
        for (i, pt) in points.enumerated() {
            let q = CGPoint(x: pt.x * width, y: pt.y * height)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    // Generated by tools/make_app_icon.py --swift. Do not hand-edit.
    static let bands: [[CGPoint]] = [
        [   // band 0: y 0–367
            CGPoint(x: 0.0407, y: 1.0000), CGPoint(x: 0.0129, y: 0.9964), CGPoint(x: 0.0040, y: 0.9911),
            CGPoint(x: 0.0002, y: 0.9835), CGPoint(x: 0.0003, y: 0.8334), CGPoint(x: 0.0038, y: 0.8223),
            CGPoint(x: 0.0173, y: 0.8157), CGPoint(x: 0.4472, y: 0.7247), CGPoint(x: 1.0000, y: 0.7247),
            CGPoint(x: 0.9999, y: 0.8537), CGPoint(x: 0.9941, y: 0.8666), CGPoint(x: 0.9820, y: 0.8732),
            CGPoint(x: 0.4328, y: 0.9989)
        ],
        [   // band 1: y 367–545
            CGPoint(x: 0.4472, y: 0.7247), CGPoint(x: 0.4472, y: 0.5911), CGPoint(x: 1.0000, y: 0.5911),
            CGPoint(x: 1.0000, y: 0.7247)
        ],
        [   // band 2: y 545–815
            CGPoint(x: 0.4472, y: 0.5911), CGPoint(x: 0.0155, y: 0.4669), CGPoint(x: 0.0004, y: 0.4522),
            CGPoint(x: 0.0000, y: 0.3886), CGPoint(x: 0.5496, y: 0.3886), CGPoint(x: 0.9786, y: 0.5018),
            CGPoint(x: 0.9966, y: 0.5130), CGPoint(x: 1.0000, y: 0.5911)
        ],
        [   // band 3: y 815–1000
            CGPoint(x: 0.0000, y: 0.3886), CGPoint(x: 0.0000, y: 0.2498), CGPoint(x: 0.5496, y: 0.2498),
            CGPoint(x: 0.5496, y: 0.3886)
        ],
        [   // band 4: y 1000–1333
            CGPoint(x: 0.0000, y: 0.2498), CGPoint(x: 0.0003, y: 0.1664), CGPoint(x: 0.0033, y: 0.1557),
            CGPoint(x: 0.0110, y: 0.1498), CGPoint(x: 0.4690, y: 0.0062), CGPoint(x: 0.5152, y: 0.0000),
            CGPoint(x: 0.9593, y: 0.0000), CGPoint(x: 0.9808, y: 0.0018), CGPoint(x: 0.9943, y: 0.0073),
            CGPoint(x: 1.0000, y: 0.0188), CGPoint(x: 0.9999, y: 0.1483), CGPoint(x: 0.9939, y: 0.1602),
            CGPoint(x: 0.9756, y: 0.1688), CGPoint(x: 0.5496, y: 0.2498)
        ]
    ]
    /// The glyph's own proportions: 615 × 1333 font units.
    static let aspect: CGFloat = 0.4614
}


/// The app's name.
///
/// One view so the camera's wordmark and the Settings header cannot drift into
/// two different sizes of the same word.
///
/// Set in SF Pro Rounded, not Jaro. Jaro still supplies the MARK — the icon
/// and `StrataMark` are its S taken apart — but as a wordmark beside that mark
/// it fought it: a heavy, black, angular slab next to five pale rounded
/// blocks. The kinship was real and invisible. Rendering the pairing settled
/// it (2026-09-09, owner's call).
///
/// **Semibold is a deliberate exception** to the app's two weights. Those
/// govern interface type; a wordmark is drawn artwork, and at 61pt white over
/// a viewfinder Medium reads thin.
struct StrataWordmark: View {
    var size: CGFloat = 28
    var color: Color = .primary

    var body: some View {
        Text("Strata")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .accessibilityLabel("Strata")
    }
}
