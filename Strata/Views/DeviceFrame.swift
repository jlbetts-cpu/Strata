import SwiftUI

/// A phone, drawn, with something of the app's on its screen.
///
/// The owner, 2026-09-23: "I like how they put the photo of the app into an
/// actual like Apple device. I feel like it makes it look a lot cleaner.
/// Especially we can use that for the camera as like an intro, I think it would
/// look a lot better."
///
/// **Drawn, never a photograph of a phone.** Apple's product imagery and every
/// downloaded mockup come with a licence and with somebody else's lighting, and
/// this app was rejected under guideline 4.1(a) already. A shell we draw is also
/// the only one that can sit on this app's own ladder, and it fits the design
/// language better than a photograph would: `docs/design-system-future.md` calls
/// the app a beautifully made instrument, and a device inside a device is exactly
/// that.
///
/// **Every number here comes from something real.** The screen ratio is a real
/// display's (393 x 852). The corner is `GridConstants.blockCornerRadius(forCell:)`,
/// the ladder's one proportional rung, which at this width lands within half a
/// point of the real device's corner: a phone's corner is about 14% of its width
/// and a block's is 14.7% of its side, so the phone and the block are already the
/// same shape. The bezel is `GridConstants.spacing`, the grid's own 4pt gutter.
/// The island is the real one's proportions.
///
/// **And nothing else.** No reflection, no glass highlight, no shadow (CLAUDE.md:
/// only something standing on the ground gets one, and this is not standing on
/// anything), and no home indicator, because the screen inside does not have one.
struct DeviceFrame<Screen: View>: View {

    /// The shell's outer width. The caller decides it, because on these pages the
    /// answer is the page's own margin and only the caller knows that.
    let width: CGFloat

    /// The Dynamic Island. Off for a screen that would not show one.
    var island: Bool = true

    @ViewBuilder var screen: () -> Screen

    /// A real display: 393 x 852 points.
    static var aspect: CGFloat { 393.0 / 852.0 }

    /// The whole shell's height at this width.
    var height: CGFloat { width / Self.aspect }

    /// The black band around the screen.
    ///
    /// **A band, not a hairline.** A hairline outline round a photograph is a
    /// framed picture; the band is what makes a phone read as a phone at a
    /// glance, which is the entire point of the exercise. It is the grid's own
    /// gutter rather than a number chosen by eye, and it is the app's warm black
    /// rather than pure black, so the device belongs to a palette whose black has
    /// always had brown in it.
    var bezel: CGFloat = DeviceFrame.defaultBezel

    /// The band's width, as a number a caller can do arithmetic with: the screen
    /// inside the shell is the shell less twice this, and anything composed to
    /// fit that screen needs to know it.
    ///
    /// **Computed, not stored.** CLAUDE.md: static STORED properties are not
    /// allowed in a generic type at all, which is why `DrawerMetrics` exists,
    /// and this type is generic over what is on its screen. `aspect` above is
    /// computed for the same reason.
    static var defaultBezel: CGFloat { GridConstants.spacing }

    private var outerRadius: CGFloat {
        GridConstants.blockCornerRadius(forCell: width)
    }

    /// Concentric: the screen's corner is the shell's less the band, so the two
    /// curves stay parallel instead of crossing.
    private var innerRadius: CGFloat { max(outerRadius - bezel, 0) }

    var body: some View {
        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
            .fill(AppColors.warmBlack)
            .overlay {
                screen()
                    .frame(width: width - bezel * 2, height: height - bezel * 2)
                    .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                    .overlay(alignment: .top) { islandView }
            }
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }

    /// The island, at the real one's proportions: 125 x 36.7 points, 11 from the
    /// top of the screen, on a 393 point display.
    @ViewBuilder
    private var islandView: some View {
        if island {
            Capsule(style: .continuous)
                .fill(AppColors.warmBlack)
                .frame(width: width * 125 / 393, height: width * 36.7 / 393)
                .padding(.top, width * 11 / 393)
        }
    }
}
