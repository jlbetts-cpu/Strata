import SwiftUI

/// **A win, as a print.**
///
/// From the owner's Figma (`13258-6988`): "we are going to make all the wins
/// look like that, not when you are scrolling through the photos but when you
/// click and interact with them... clean and modern with just subtle
/// branding."
///
/// **It is not a Polaroid**, which is what the render looks like at a glance
/// and is not what the file says. There is no white frame and no caption
/// band: it is the photograph itself, squared to one format, with an 8pt
/// corner, a hairline edge and the mark signed into the bottom right. A
/// caption band would have put type on every photograph, which he ruled out
/// once already — "the titles shouldn't be on the cards with photos."
///
/// **The format is the point.** 3:4 is a crop, and the app's wins are three
/// different shapes. Fixing the print means every win comes out the same
/// object whatever it was shot at, which is what a film format does and why a
/// box of prints looks like a set. It also divides the work cleanly: SIZE
/// reads while you are browsing, so the folder's cards stay three shapes;
/// FORMAT reads when you are holding one, so the print is always this one.
///
/// **Where it belongs**, and the test is presented versus browsed — one
/// image held still, or many at once under a thumb. A hairline and a corner
/// radius repeated twenty times down a scroll stop being a frame and become a
/// pattern, and the eye starts reading frames instead of photographs. See
/// `docs/the-print.md` for the surface-by-surface list.
struct WinPrint: View {
    var image: UIImage?
    /// A win with no photograph is still a win. It gets the generated field
    /// its card uses, at the same format, so a day of typed wins is a set of
    /// prints rather than a set of holes.
    var win: ScatterWin?
    /// Where the owner dragged the frame, as a fraction away from the middle.
    /// `HabitLog.cropPositionX/Y`, so a print is cropped where the person
    /// cropped it rather than wherever the middle happens to fall.
    var crop: CGPoint = .zero
    /// **Off by default, and that is the whole caution about it.**
    ///
    /// A wordmark on a photograph is a SIGNATURE where the image leaves the
    /// app — a share, an export, somebody else's feed — and a WATERMARK where
    /// it does not, because the person looking already has the app. Baking it
    /// in would make every photograph an advertisement to its own owner.
    var showsMark: Bool = false

    /// 342 x 452 in the file. Stated as the ratio so it is one number rather
    /// than a pair that can drift.
    static let aspect: CGFloat = 342.0 / 452.0

    /// Every other measurement is a fraction of the card's WIDTH, so the
    /// print is the same drawing at 120pt on a shelf and at 340pt held.
    private static let radiusRatio: CGFloat = 8.0 / 342.0
    private static let markWidthRatio: CGFloat = 66.0 / 342.0
    private static let markInsetRatio: CGFloat = 16.0 / 342.0
    private static let markOpacity: CGFloat = 0.8

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let radius = w * Self.radiusRatio
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

            ZStack {
                photograph(in: geo.size)

                if showsMark {
                    ApolloWordmark(height: w * Self.markWidthRatio / ApolloWordmark.aspect,
                                   color: .white)
                        .opacity(Self.markOpacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomTrailing)
                        .padding(.trailing, w * Self.markInsetRatio)
                        .padding(.bottom, w * Self.markInsetRatio)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(shape)
            .overlay {
                // **A hairline, and a real one.** The file says 0.2px, which
                // is a Figma number rather than a screen one: below one
                // device pixel it renders as a paler line rather than a
                // thinner one, and on a 3x phone 0.2pt is 0.6px. One device
                // pixel is the thinnest a line can honestly be, so that is
                // what it draws, and it is the app's own quiet ink rather
                // than a hex value from a file that does not know about dark
                // mode.
                shape.strokeBorder(AppColors.inkPrimary.opacity(0.10),
                                   lineWidth: 1 / max(UIScreen.main.scale, 1))
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }

    @ViewBuilder
    private func photograph(in size: CGSize) -> some View {
        if let image {
            // **Filled and offset, not `scaledToFill` alone.** A 3:4 print of
            // a 4:3 photograph throws away a third of it, and which third is
            // the owner's decision — he made it on the camera's review and it
            // is on the log. Centre is only the default for a win nobody
            // moved.
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .offset(x: crop.x * size.width, y: crop.y * size.height)
                .clipped()
        } else if let win {
            WinCardFace(win: win, image: nil, showsTitle: false, corner: 0)
        } else {
            AppColors.quietFill
        }
    }
}
