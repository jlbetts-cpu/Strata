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

    // MARK: - The screen scale
    //
    // Three sizes for everything a screen says about itself, and no more.
    //
    // The app had drifted to a different title size per screen — Memories at
    // 48, a day at 33, an assortment of `.title3`/`.headline` elsewhere — so
    // moving between tabs meant the same kind of thing arriving at a different
    // weight each time. Less variety is the whole point: a page with one title
    // size and one label size has a hierarchy you can read without looking for
    // it.

    /// The one screen title. Every page that names itself uses this.
    ///
    /// 34pt is the platform's own large title, not a number picked to look
    /// impressive. The 48 it replaces came from a lowfi and made the title the
    /// loudest thing on a page whose subject is photographs and blocks.
    static let screenTitleSize: CGFloat = 34
    static let screenTitle = Font.system(size: screenTitleSize, weight: .medium, design: .rounded)

    /// The line under a screen title: "2 wins", a date, a count.
    static let screenSubtitle = Font.system(size: 15, weight: .regular, design: .rounded)

    /// Uppercase section labels — ALBUMS, SEPTEMBER, a month in the gallery.
    /// One size for all of them, so a heading is recognisable as a heading.
    static let sectionLabel = Font.system(size: 13, weight: .medium, design: .rounded)
    static let sectionKerning: CGFloat = 0.8

    /// A photograph's caption in the gallery.
    static let photoCaption = Font.system(size: 12, weight: .medium, design: .rounded)
}

// MARK: - Jaro

// Jaro is no longer a runtime font, and `JaroFont` is gone with the wordmark
// that used it (2026-09-09, owner's call — beside the block-S mark it read as
// a heavy angular slab next to five pale rounded blocks). It was also briefly
// on the tally numeral, which made the one number on each screen look like
// part of the logo rather than a count of your day.
//
// `Strata/Resources/Jaro.ttf` still ships and must stay: the app icon and
// `StrataMark` are its S taken apart at the glyph's own inner corners, and
// `tools/make_app_icon.py` reads the file to regenerate both. `Jaro-OFL.txt`
// stays beside it, which is what the SIL Open Font License requires.
//
// So Jaro supplies GEOMETRY now, not type. Do not reintroduce it as a face.
