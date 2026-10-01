import SwiftUI
import UIKit

/// **The platform's segmented control, in this app's material.**
///
/// The owner, 2026-09-30, asked for the middle rather than either end: "make the
/// app work with the Apple tabs like that and make it work with our style, like
/// finding the perfect middle man that helps merge the ecosystems."
///
/// Which is the right call, and it is also the one he already made once. The
/// size picker was three hand-built buttons before it was a `Picker` — "I wish
/// they were more Apple buttons" — so rebuilding it to win a material argument
/// would be walking back a decision AND throwing away everything a segmented
/// control knows how to do: Dynamic Type, the VoiceOver adjustable trait, the
/// drag that carries the thumb, keyboard focus. The control stays Apple's. Only
/// what it is made of changes.
///
/// **An appearance proxy does this, and it was nearly abandoned on a wrong
/// measurement.** A first pass looked like it had no effect — the track stayed
/// the platform grey and the thumb stayed pure white — and the conclusion drawn
/// was that SwiftUI's `.segmented` style ignores UIKit appearance. It does not.
/// Proved by setting the track green and the thumb red and photographing it.
///
/// What had actually happened is the trap below, and it is worth the paragraph:
/// the thumb was derived as `WarmBackground.top` plus a lift. But `top` is
/// 0.972 BEFORE `GroundField` and its `seat` darken it, so adding anything to it
/// clamps at 1.0 — pure white, exactly what it was replacing. **The page's
/// colour in the source is not the page's colour on the screen**, and anything
/// meant to sit near the page has to be measured against the rendered page, not
/// the token the page starts from.
///
/// So these are the rendered numbers, sampled off the built sheet:
///
/// | | measured |
/// |---|---|
/// | the page | (240, 238, 232) |
/// | the track, below it | (230, 228, 224) |
/// | the thumb, above it | (246, 245, 241) |
///
/// Which is the same shape as everything else on this page: `PageSurface` is
/// five levels over the ground, a block's rim defines it rather than its
/// brightness, and the header's pill is three. A well with a pane sliding in it,
/// instead of a grey bar with a white tile on it.
enum EtherealControls {

    /// Called from `StrataApp.init`. An appearance proxy decides what gets
    /// built, so it has to run before anything is.
    static func install() {
        let segmented = UISegmentedControl.appearance()
        segmented.backgroundColor = UIColor(track)
        segmented.selectedSegmentTintColor = UIColor(thumb)
        segmented.setTitleTextAttributes(
            [.foregroundColor: UIColor(AppColors.inkSecondary)], for: .normal)
        segmented.setTitleTextAttributes(
            [.foregroundColor: UIColor(AppColors.inkPrimary)], for: .selected)
    }

    /// **Neutral, like the page.** This was the page's warm, and the page has
    /// none now — see `WarmBackground.top` for why a ground with a hue is a
    /// ground the content argues with. A control is chrome and chrome is ink
    /// and light here, never a colour.
    private static let hue: CGFloat = 0
    private static let saturation: CGFloat = 0

    /// The track: a well, a little under the page. Opaque rather than
    /// `quietFill`'s 6% ink, because this is a UIKit colour and a translucent
    /// one over a sheet that is itself translucent compounds into a grey nobody
    /// chose.
    private static let track = Color(uiColor: UIColor { traits in
        UIColor(hue: hue, saturation: saturation,
                brightness: traits.userInterfaceStyle == .dark ? 0.16 : 0.952,
                alpha: 1)
    })

    /// The selected segment: a pane over the page, at `PageSurface`'s distance.
    ///
    /// **0.965, and it had drifted to 0.998.** The pass that took the whole app
    /// off warm and onto clean white moved these two numbers with everything
    /// else, and 0.998 renders at 255 — which is pure white, the exact thing
    /// this was written to stop the thumb being. Caught by the screen audit on
    /// the add sheet, measured at (255, 255, 255) against a (245, 245, 245)
    /// page, and it is the second time this file has been fooled: a value that
    /// looks safe in the source is not a value until it has been sampled off
    /// the built screen.
    private static let thumb = Color(uiColor: UIColor { traits in
        UIColor(hue: hue, saturation: saturation,
                brightness: traits.userInterfaceStyle == .dark ? 0.22 : 0.965,
                alpha: 1)
    })
}
