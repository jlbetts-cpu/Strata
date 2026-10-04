import SwiftUI

/// **One of the owner's drawings, with its line under it.** Nothing around
/// it: no card, no rim, the drawing and the words on the page itself (the
/// owner, 2026-10-03: "I dont like the illustration in the block try it just
/// blank"). The drawing is in the page's ink, so it follows dark mode; the
/// line is SF Pro, set small and close under it so the two read as one piece,
/// the way HeyTea sets theirs.
struct Illustration: View {
    let art: UIImage
    let line: String?
    /// The drawing's height at most; the width follows the drawing. It gives
    /// up to half of it on a small screen rather than crowd what is beside it
    /// (an iPhone SE has about 130pt above October's calendar).
    var height: CGFloat = 150

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            Image(uiImage: art)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColors.inkPrimary)
                .frame(minHeight: height * 0.5, maxHeight: height)
                // Takes its room before the space around it does, so the
                // space shrinks first and the drawing only after.
                .layoutPriority(1)
            if let line {
                Text(line)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .tracking(0.2)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line ?? "")
        .accessibilityHidden(line == nil)
    }
}
