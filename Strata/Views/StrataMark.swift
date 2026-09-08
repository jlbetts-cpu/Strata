import SwiftUI

/// The app's mark: one block, with an S on it.
///
/// Drawn rather than shipped as an image, and drawn out of `BlockSurface` —
/// the same chrome every block on the tower uses. So the mark cannot drift
/// from the thing it is a picture of: change the rim or the band and the logo
/// changes with them.
///
/// The **app icon** is deliberately not this view. An icon is masked by iOS
/// and lives at 60pt in Settings, where a rim, a corner radius of our own and
/// a reflection all become noise — measured by rendering both and looking at
/// them at 180/120/80/60. The icon is the flat pink field and the letter.
/// In the app, at 40pt and up on a warm ground, the block reads as a block and
/// should look like one.
struct StrataMark: View {
    var side: CGFloat = 44
    /// Mindfulness pink. The mark is a block, so it wears a block's colour
    /// rather than a brand colour invented alongside them.
    private var pink: Color { HabitCategory.mindfulness.style.baseColor }

    var body: some View {
        BlockSurface(
            cornerRadius: GridConstants.blockCornerRadius(forCell: side),
            // Rim weight and blur are absolutes tuned to the tower's cell;
            // at 44pt an unscaled 1.4pt rim is nearly twice as heavy in
            // proportion. `BlockSurface` already takes the ratio.
            scale: side / GridConstants.blockReferenceCell
        ) {
            pink
        }
        .frame(width: side, height: side)
        .overlay {
            Text("S")
                .font(.system(size: side * 0.60, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                // The letter's optical centre sits slightly below its bounding
                // box centre, which is why this is not simply centred.
                .offset(y: -side * 0.01)
        }
        .accessibilityLabel("Strata")
    }
}
