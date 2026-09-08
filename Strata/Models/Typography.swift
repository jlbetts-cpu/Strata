import SwiftUI

enum Typography {
    // MARK: - Brand (SF Pro Rounded — unified single-font system)
    // TWO WEIGHTS, EVERYWHERE: medium for anything that is a heading, a
    // number or a control, regular for everything you read. Semibold, light
    // and bold are not in the app's voice — a third weight is a third level of
    // emphasis, and every screen here has at most two things to say.
    static let brandLogo = Font.system(.title2, design: .rounded, weight: .medium)
    static let brandHeader = Font.system(.title3, design: .rounded, weight: .medium)
    static let brandSubheader = Font.system(.headline, design: .rounded, weight: .medium)
    static let brandHeroDate = Font.system(.title, design: .rounded, weight: .medium)
    static let brandCardTitle = Font.system(.title3, design: .rounded, weight: .medium)
    static let brandLogoKerning: CGFloat = 1.5

    // MARK: - System (SF Pro Rounded — warm/humanist for body + detail)
    static let appTitle = Font.system(.largeTitle, design: .rounded, weight: .medium)
    static let headerLarge = Font.system(.title3, design: .rounded, weight: .medium)
    static let headerMedium = Font.system(.headline, design: .rounded, weight: .medium)
    static let headerSmall = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let bodyLarge = Font.system(.body, design: .rounded)
    static let bodyMedium = Font.system(.callout, design: .rounded)
    static let bodySmall = Font.system(.footnote, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let caption2 = Font.system(.caption2, design: .rounded, weight: .medium)
    static let blockTitle = Font.system(.callout, design: .rounded, weight: .medium)
    // Mini block preview (fixed size — too small for text styles)
    static let miniBlockTitle = Font.system(size: 10, weight: .medium, design: .rounded)
    static let miniBlockIcon = Font.system(size: 9, weight: .medium, design: .rounded)
    // Kerning (SF Rounded has built-in optical kerning — no manual adjustment needed)
    static let headerKerning: CGFloat = 0
    static let titleKerning: CGFloat = 0
}

// MARK: - Jaro

/// The display face, used for the app's own name. Nothing else.
///
/// It was briefly on the tally numeral too. Jaro's digits are as geometric as
/// its letters, which made the one number on each screen read as part of the
/// logo rather than as a count of your day — SF Pro Rounded says the number
/// and gets out of the way. Jaro is the wordmark and the mark, and that is
/// the whole of its job.
///
/// It is a variable font with an optical-size axis (6–72, default 14). iOS
/// picks an instance by point size on its own once the font is registered, so
/// a 64pt numeral gets the display cut and a 20pt wordmark gets a tighter one
/// without anything here asking for it.
///
/// Licensed under the SIL Open Font License; `Strata/Resources/Jaro-OFL.txt`
/// ships beside it, which is what that licence requires.
enum JaroFont {
    /// PostScript name, read out of the font's own `name` table rather than
    /// guessed — `Font.custom` silently falls back to the system face when the
    /// name is wrong, which looks like the font simply not loading.
    static let name = "Jaro-Regular"

    static func size(_ points: CGFloat) -> Font {
        .custom(name, size: points)
    }

    /// Scales with Dynamic Type, which a plain `.custom(_:size:)` does not.
    static func relative(_ points: CGFloat, to style: Font.TextStyle) -> Font {
        .custom(name, size: points, relativeTo: style)
    }
}
