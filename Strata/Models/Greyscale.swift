import SwiftUI

/// **The app's greyscale, and the only place a neutral is allowed to come
/// from.**
///
/// The owner's own ramp, sent as eleven steps: "Can we make the greyscale
/// interface reserved to these colours?"
///
/// Named by step rather than by role on purpose. A role name (`panel`,
/// `hairline`) invites a second opinion about which grey a panel should be;
/// a step number is the thing he actually specified, and a call site that
/// says `Grey.g950` can be checked against his ramp by reading it.
///
/// **These are fixed, not adaptive, and that is the boundary of the rule.**
/// The ramp describes one scale of greys; it does not say which end of it a
/// surface should use in light mode versus dark. So it governs the surfaces
/// that are a fixed grey in both appearances — the camera and the head maker,
/// which are dark-only screens by design — and it deliberately does NOT
/// replace `AppColors`' adaptive inks, which are opacities over whichever
/// ground is behind them and are derived from measured contrast ratios in both
/// appearances. Snapping those to a fixed step would fix them to one
/// appearance and break the other. See the audit in the commit for the full
/// list and what each one rounds to.
enum Grey {
    /// `#F3F3F3`
    static let g50 = Color(hex: 0xF3F3F3)
    /// `#E6E6E6`
    static let g100 = Color(hex: 0xE6E6E6)
    /// `#CECECE`
    static let g200 = Color(hex: 0xCECECE)
    /// `#B5B5B5`
    static let g300 = Color(hex: 0xB5B5B5)
    /// `#9C9C9C`
    static let g400 = Color(hex: 0x9C9C9C)
    /// `#838383`
    static let g500 = Color(hex: 0x838383)
    /// `#6B6B6B`
    static let g600 = Color(hex: 0x6B6B6B)
    /// `#525252`
    static let g700 = Color(hex: 0x525252)
    /// `#393939`
    static let g800 = Color(hex: 0x393939)
    /// `#212121`
    static let g900 = Color(hex: 0x212121)
    /// `#080808`, the darkest. The camera's ground.
    static let g950 = Color(hex: 0x080808)

    /// The ramp in order, for a test that wants to walk it.
    static let ramp: [Color] = [g50, g100, g200, g300, g400, g500,
                                g600, g700, g800, g900, g950]
    /// The same values as bytes, so a contrast assertion can do arithmetic.
    static let levels: [Int] = [0xF3, 0xE6, 0xCE, 0xB5, 0x9C, 0x83,
                                0x6B, 0x52, 0x39, 0x21, 0x08]
}
