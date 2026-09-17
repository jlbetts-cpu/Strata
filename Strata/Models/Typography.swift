import SwiftUI

enum Typography {
    // MARK: - The scale: five sizes, two weights
    //
    // 34, 17, 15, 13 and 11, at Regular and Medium (docs/research/font.md
    // (c)). Semibold is gone from the app: the owner's face has one cut, and
    // its heavy drawn stem already does the job a third weight did. Every
    // token is a text STYLE, so Dynamic Type moves the lot together.
    //
    // Merged on 2026-09-16, each into the rung it was nearest: headerLarge
    // (20) and blockTitle (16) into `headerMedium`, bodyMedium (16) into
    // `bodyLarge`, caption (12) into `bodySmall`, photoCaption (12) into
    // `sectionLabel`. Deleted with no call sites: brandLogo, brandHeader,
    // brandSubheader, brandHeroDate, brandCardTitle, appTitle,
    // miniBlockTitle, miniBlockIcon and the three kernings beside them.
    //
    // Outside the scale on purpose, because geometry solves them rather than
    // a choice: the month block's `cell * 0.16` numeral, the camera
    // countdown, the widget's counts, and symbol glyph sizes.

    /// 17 Medium. Headings, and a block's or a card's title.
    static let headerMedium = Font.system(.headline, design: .rounded, weight: .medium)
    /// 15 Medium. Buttons.
    static let headerSmall = Font.system(.subheadline, design: .rounded, weight: .medium)
    /// 17 Regular. What you read.
    static let bodyLarge = Font.system(.body, design: .rounded)
    /// 13 Regular. Footnotes and captions.
    static let bodySmall = Font.system(.footnote, design: .rounded)
    /// 11 Medium. Chart axes and the smallest labels.
    static let caption2 = Font.system(.caption2, design: .rounded, weight: .medium)

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

    /// The same title in the owner's face (`StrataFont`), for a title that
    /// names the screen, through `DynamicScreenTitle` where the words are data.
    static let screenTitleDrawn = StrataFont.relative(screenTitleSize, to: .largeTitle)

    /// A sheet's title in the owner's face, 17 relative to `.headline`. See
    /// `View.sheetTitle(_:drawn:)`.
    static let sheetTitleDrawn = StrataFont.relative(17, to: .headline)

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

    /// Any number the app states as a fact about your day: the win tally, a
    /// day's numeral on a month block, a photo count. The owner's own digits
    /// — see `StrataFont`.
    ///
    /// **Numbers, never words.** The face has ten glyphs and a space; a
    /// `Text` in it that contains a letter renders `.notdef`. Anything with a
    /// word in it stays on `screenTitle` / `screenSubtitle`.
    static let tally = StrataFont.relative(screenTitleSize, to: .largeTitle)

    /// The same digits, at a size the caller solves for — a month block's
    /// numeral scales off its cell, not off the type scale.
    static func numeral(_ points: CGFloat) -> Font { StrataFont.size(points) }
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
