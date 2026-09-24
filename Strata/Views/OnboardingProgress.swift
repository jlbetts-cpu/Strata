import SwiftUI

/// How far through the walkthrough you are, drawn as the tower's own cells.
///
/// **A visible sense of progress, in this app's language rather than in the
/// platform's.** A row of page dots is the generic answer, and it says nothing
/// about what this app is. The tower's grid already means "one of these is a
/// thing you did", so the walkthrough fills one cell per page and the row reads
/// as the first four or five blocks of something being built. Same 4pt gutter
/// (`GridConstants.spacing`) and the same radius the cell ladder gives a square
/// this small (`GridConstants.blockCornerRadius(forCell:)`), which is
/// `docs/design-system-future.md` section 3: a screen laying out a grid of
/// things uses the same cell language rather than inventing a pattern.
///
/// **Nothing here animates on appearance** (section 5 and section 8). The fill
/// changes because somebody pressed the button, and it changes inside the
/// caller's own transaction, so the row moves with the page rather than on a
/// spring of its own.
struct OnboardingProgress: View {

    /// The page you are on, from 0.
    let step: Int
    let count: Int

    /// Whether the ground under it is the dark of a photograph.
    ///
    /// The camera and map pages are dark whatever the phone is set to, so the
    /// adaptive inks are wrong there and the `onDark` scale is what the app
    /// uses instead. CLAUDE.md: an ink is for text and inverts; ask what the
    /// contrast is against.
    let onDark: Bool

    /// The side of one cell.
    ///
    /// Six of these and five gutters measure 92pt, a quarter of a 370pt
    /// column, so the readout is a caption beside the wordmark rather than a
    /// control competing with it.
    static let cell: CGFloat = 12

    /// A page you have reached: 62% ink on the page, 75% white on a
    /// photograph. Both are the app's own heading ink, which is the rank this
    /// is: it names where you are and is not the thing you read.
    private var filled: Color {
        onDark ? AppColors.onDarkSecondary : AppColors.inkSecondary
    }

    /// A page still to come. The state is carried by ten times the ink rather
    /// than by a shape or an outline, so there is nothing here to mistake for a
    /// control: `quietFill` is the app's empty-cell token, and on a photograph
    /// 6% white would be gone, so the dark scale's hairline value stands in.
    private var empty: Color {
        onDark ? AppColors.onDarkFaint : AppColors.quietFill
    }

    var body: some View {
        HStack(spacing: GridConstants.spacing) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(
                    cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
                    style: .continuous
                )
                .fill(index <= step ? filled : empty)
                .frame(width: Self.cell, height: Self.cell)
            }
        }
        // One element, and it says the number rather than leaving VoiceOver to
        // read six unlabelled squares.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(count)")
    }
}
