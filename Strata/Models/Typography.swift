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

    /// **Text STYLES, not point sizes.**
    ///
    /// These were `.system(size:)`, which is a fixed size and does not move
    /// when somebody turns Dynamic Type up. That is the single most-used
    /// accessibility setting on iOS and this app is meant to be handed to
    /// someone's grandmother, so a title that ignores it is not a small
    /// omission.
    ///
    /// Each style below is the one whose DEFAULT size is the number that was
    /// there before, so nothing moves at the default setting and everything
    /// moves together at any other: large title 34, subheadline 15, footnote
    /// 13, caption 12.

    /// The one screen title. Every page that names itself uses this.
    ///
    /// 34pt at the default size is the platform's own large title, not a
    /// number picked to look impressive. The 48 it replaced came from a lowfi
    /// and made the title the loudest thing on a page whose subject is
    /// photographs and blocks.
    static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .medium)

    /// The metric behind it, for layout that has to do arithmetic — the
    /// header's cap-height padding, and the tally numeral. Fixed, because a
    /// layout constant cannot be a font.
    static let screenTitleSize: CGFloat = 34

    /// The CAP HEIGHT of a screen title, for artwork that has to match one.
    ///
    /// A `Font.system(size:)` is an em size and its cap is a fraction of that
    /// — 1443/2048 for SF Pro Rounded, read out of `SFNSRounded.ttf`'s own
    /// `OS/2` table rather than eyeballed. A drawing's `size` IS its cap, so
    /// handing a drawn title the 34 would set it 41% taller than the type it
    /// replaced. Measured before this existed: "Memories" came out with a
    /// 33.3pt cap against the tower tally's 23.3pt, on two screens that are
    /// meant to have the same title.
    static let screenTitleCap: CGFloat = screenTitleSize * 1443 / 2048

    /// The line under a screen title: "2 wins", a date, a count.
    static let screenSubtitle = Font.system(.subheadline, design: .rounded)

    /// Uppercase section labels — ALBUMS, SEPTEMBER, a month in the gallery.
    /// One style for all of them, so a heading is recognisable as a heading.
    static let sectionLabel = Font.system(.footnote, design: .rounded, weight: .medium)
    static let sectionKerning: CGFloat = 0.8

    /// A photograph's caption in the gallery.
    static let photoCaption = Font.system(.caption, design: .rounded, weight: .medium)

    /// Any number the app states as a fact about your day: the win tally, a
    /// day's numeral on a month block, a photo count. The owner's own digits
    /// — see `StrataNumerals`.
    ///
    /// **Numbers, never words.** The face has ten glyphs and a space; a
    /// `Text` in it that contains a letter renders `.notdef`. Anything with a
    /// word in it stays on `screenTitle` / `screenSubtitle`.
    static let tally = StrataNumerals.relative(screenTitleSize, to: .largeTitle)

    /// The same digits, at a size the caller solves for — a month block's
    /// numeral scales off its cell, not off the type scale.
    static func numeral(_ points: CGFloat) -> Font { StrataNumerals.size(points) }
}

// MARK: - Jaro

/// The display face, used for the app's own name and its mark. Nothing else.
///
/// It was removed on 2026-09-09 and restored the same day, on the owner's
/// call. The argument for removing it was that a heavy angular slab fought the
/// pale rounded mark beside it — which was true of the FIVE-COLOUR mark it was
/// sitting next to, and that mark is gone. Against a single pink block with a
/// white letter on it, which is what the mark is again, Jaro is the letter.
///
/// It was also briefly on the tally numeral. Jaro's digits are as geometric as
/// its letters, which made the one number on each screen read as part of the
/// logo rather than as a count of your day. **The wordmark and the mark, and
/// that is the whole of its job.**
///
/// It is a variable font with an optical-size axis (6-72, default 14). iOS
/// picks an instance by point size on its own once the font is registered, so
/// a large wordmark gets the display cut and a small one a tighter one without
/// anything here asking for it. That registration is `UIAppFonts` in
/// Info.plist — without it `Font.custom` falls back to the system face
/// silently, which looks exactly like the font not loading.
///
/// Licensed under the SIL Open Font License; `Strata/Resources/Jaro-OFL.txt`
/// ships beside it, which is what that licence requires.
enum JaroFont {
    /// PostScript name, read out of the font's own `name` table rather than
    /// guessed.
    static let name = "Jaro-Regular"

    static func size(_ points: CGFloat) -> Font {
        .custom(name, size: points)
    }

    /// Scales with Dynamic Type, which a plain `.custom(_:size:)` does not.
    static func relative(_ points: CGFloat, to style: Font.TextStyle) -> Font {
        .custom(name, size: points, relativeTo: style)
    }
}

// MARK: - Strata Numerals

/// The owner's own digits, as a real font.
///
/// They arrived as one Figma export — a 362x28 strip spelling `1234567890`.
/// Shipping the strip would have meant writing a layout engine: measuring
/// advances, positioning ten `Image`s, and hand-rolling the roll-up that
/// `Text` gets for free from `.contentTransition(.numericText())`. So
/// `tools/make_numeral_font.py` turns it into `StrataNumerals.otf` instead,
/// which is what was asked for — "treat it like you would any other font".
///
/// **Metrically compatible with SF Pro Rounded**: 2048 upem, ascent 1980,
/// descent -432, cap 1443, all copied from `SFNSRounded.ttf`'s own tables. A
/// `Text` in this font therefore has the same layout box and the same cap
/// position as a `Text` in the system face at the same point size, so the two
/// mix on a line and `GridConstants.headerTopPadding(forTitleSize:)` works on
/// both without a second constant.
///
/// **The digits are tabular** — one advance for all ten, each centred in it.
/// A count that changes must not reflow the word beside it, and a numeral
/// that animates its digits must not jitter its neighbours. It is also a wide
/// face: the advance is 0.947 em against SF Pro's ~0.57, so three digits set
/// about two and a half times a cap height.
///
/// Registered by `UIAppFonts` in Info.plist. Without that entry `Font.custom`
/// falls back to the system face **silently**, which looks exactly like the
/// font not loading.
enum StrataNumerals {
    /// PostScript name, as written by the generator.
    static let name = "StrataNumerals-Regular"

    /// The mean left sidebearing, as a fraction of point size — measured out
    /// of the font's own `hmtx` table, not guessed. Tabular centring puts
    /// real space to the left of every digit (0.078 em for the widest, 0.118
    /// for the narrowest), so a numeral aligned to a grid line still LOOKS
    /// indented beside a block, whose colour goes right to its edge.
    static let opticalInset: CGFloat = 0.0892

    /// Fixed size. For anything that has to do arithmetic with the result.
    static func size(_ points: CGFloat) -> Font {
        .custom(name, size: points)
    }

    /// Scales with Dynamic Type, which a plain `.custom(_:size:)` does not.
    static func relative(_ points: CGFloat, to style: Font.TextStyle) -> Font {
        .custom(name, size: points, relativeTo: style)
    }
}
