import SwiftUI

/// The app's name, as the owner drew it.
///
/// **It is artwork, not text.** `Apollowordmark.svg` is the mark as outlined
/// vectors, straight from his file, so it is exactly the drawn one at every
/// size with no font to register and no licence question. Template-rendered,
/// so it takes the page's ink and inverts with the appearance rather than
/// being a white shape that vanishes on a light page.
///
/// This replaces `StrataWordmark` at every call site. The two are not
/// interchangeable in their sizing, and that is the thing to know: the old
/// view's `size` is a CAP height, and this one's `height` is the artwork's
/// whole BOX, ascender to descender. The box runs past the baseline because
/// of the `p`.
struct ApolloWordmark: View {

    /// **The box, not the cap.** His own dimensions: 145.638 x 50 on a screen
    /// that has other content — the home frame (13646:7424) and the camera
    /// page (13646:7517) both set it at exactly that, so there is one number
    /// rather than a per-screen ladder.
    ///
    /// The launch is the exception and it is his too: 223.98 x 76.84 from the
    /// launch frame, where nothing else is on the screen for the mark to be
    /// in proportion with.
    static let boxHeight: CGFloat = 50
    static let boxWidth: CGFloat = 145.638
    static let launchBoxHeight: CGFloat = 76.84

    /// The artwork's own aspect, 583:200 in the SVG. 145.638 / 50 = 2.913
    /// against 583 / 200 = 2.915 — the same drawing at two boxes, to three
    /// figures.
    static let aspect: CGFloat = 583.0 / 200.0

    /// Where the CAP sits inside the box, as fractions of it.
    ///
    /// Parsed from the SVG: the `A` runs 3.3 to 153.5 of the 200 unit
    /// viewBox, and the baseline is 153.4.
    static let capTopFraction: CGFloat = 3.3 / 200
    static let baselineFraction: CGFloat = 153.4 / 200

    /// **The box IS the ink, top and bottom**, which is why a gap cut to the
    /// box is balanced around the word.
    ///
    /// It is not obvious and it was nearly "corrected" on a bad measurement.
    /// `capTopFraction` above is the CAP, and the cap is not the tallest
    /// thing here: the two `l` ascenders go higher, all the way to the top of
    /// the viewBox, and the `p`'s descender goes all the way to the bottom of
    /// it. Rasterised a thousand points tall, the very first row carries 35
    /// inked pixels and so does the very last. `ApolloWordmarkInkTests`
    /// asserts exactly that, so if the artwork is ever redrawn with padding,
    /// every gap cut to this box fails here rather than on his screen.


    /// **How far to raise a control so it centres on the mark's CAP rather
    /// than on its box.**
    ///
    /// A circular control set beside this mark with `.center` alignment
    /// centres against the BOX, which includes the `p`'s descender — so it
    /// hangs low by exactly the descender's depth. At a 50pt box that is
    /// 5.41pt, which is enough to read as a misalignment.
    ///
    /// This cost four passes to find on the shelved Apollo branch, each time
    /// diagnosed as something else. It is the rule for every screen that sets
    /// a control beside the mark.
    static func capCentreRise(boxHeight h: CGFloat = boxHeight) -> CGFloat {
        h / 2 - h * (capTopFraction + baselineFraction) / 2
    }

    var height: CGFloat = ApolloWordmark.boxHeight
    var color: Color? = nil

    /// Whether the mark grows with Dynamic Type.
    ///
    /// True on a page, because a logo that ignores the most-used
    /// accessibility setting on the platform is the same omission as a title
    /// that does. **False on the launch**: that mark is already sized to
    /// leave 89pt of margin on a 402pt screen, and unlike a word it cannot
    /// wrap or truncate to make room.
    var scalesWithText: Bool = true

    @ScaledMetric(relativeTo: .largeTitle) private var scale100: CGFloat = 100

    private var drawnHeight: CGFloat {
        guard scalesWithText else { return height }
        // Capped at 1.6x: past that the mark starts eating the row any control
        // beside it is on, and the artwork is one piece that cannot reflow.
        return height * min(scale100 / 100, 1.6)
    }

    var body: some View {
        Image("ApolloWordmark")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(Self.aspect, contentMode: .fit)
            .frame(height: drawnHeight)
            .foregroundStyle(color ?? AppColors.inkPrimary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Apollo")
    }
}

// **There is deliberately no in-app "A" view.**
//
// The standalone mountain A belongs to the app icon on the home screen and to
// nothing inside the app. The name is the more important of the two, and a
// mark directly above a wordmark says the same thing twice — which is why
// `StrataMark`'s S block left the Settings header with the rename rather than
// being redrawn as an A.
