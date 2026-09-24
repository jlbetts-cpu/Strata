import SwiftUI

/// How far through the walkthrough you are: one rule, margin to margin, that
/// fills.
///
/// **It was six small rounded cells in the top right corner, and the owner was
/// right about them** (2026-09-23: "the progress bar doesn't look good tbh").
/// Six marks is six objects to count, they sat in a cluster in the corner with
/// air around them, and a row of little squares in a corner is a pagination
/// widget whatever it is drawn with. The tower's cell language does not rescue
/// that: a cell means a win, and a page of a walkthrough is not a win.
///
/// **It is the first thing on the page now**, across the top on the page's own
/// margin, where the wordmark used to be: the owner's reference puts its rule
/// there and he asked for the same. That position is also what stops it reading
/// as an underline of whatever sits above it, which is what it did when it lived
/// under the wordmark.
///
/// **A measured rule is the instrument's answer.** One element instead of six,
/// spanning exactly the width the page's content spans, so it belongs to the
/// same geometry as everything under it, and it says how far through you are
/// without asking anybody to count. A scale on an instrument is a line with a
/// mark on it.
///
/// `1 / displayScale` belongs to a separator (`docs/design-system-future.md`
/// section 6); this is a readout, not a separator, so it has a thickness of its
/// own. See `thickness`.
///
/// **Nothing animates on appearance** (sections 5 and 8). The fill's width
/// changes because somebody pressed the button, inside the caller's own
/// transaction, so it moves with the page rather than on a spring of its own.
struct OnboardingProgress: View {

    /// The page you are on, from 0.
    let step: Int
    let count: Int

    /// **A few points, fully rounded.** `GridConstants.spacing`, the grid's own
    /// gutter, so the number comes from the system rather than from an eye. At
    /// 2pt it read as a hairline that had gone wrong; at 4 it is a bar.
    static let thickness: CGFloat = GridConstants.spacing

    /// The travelled part, in the strongest ink the app has, which is what the
    /// title under it is set in.
    private var ink: Color { AppColors.inkPrimary }

    /// The part still to come: `quietFill`, the app's own empty-surface token.
    private var track: Color { AppColors.quietFill }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(track)
                Capsule(style: .continuous)
                    .fill(ink)
                    // **The first page is already one page of six**, so the rule
                    // is never empty: an empty gauge on the opening screen reads
                    // as something that failed to load.
                    .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(max(count, 1)))
            }
        }
        .frame(height: Self.thickness)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(count)")
    }
}
