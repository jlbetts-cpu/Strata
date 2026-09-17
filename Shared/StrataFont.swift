import SwiftUI
import CoreText

/// The owner's alphabet and digits, as one real font: `Strata-Regular.ttf`.
///
/// **In Shared/ so the widget can use it too**, registered by `UIAppFonts` in
/// both Info.plists. Without that entry `Font.custom` falls back to the
/// system face SILENTLY, which looks exactly like the font not loading;
/// `isAvailable` is how to tell.
///
/// It replaced `StrataNumerals` (2026-09-16). Its digits ARE those digits,
/// scaled by 700/1443 so their cap meets the capitals', and still tabular.
/// Two numbers changed with it, both read out of the font's own tables: the
/// advance went 0.947 em to 0.906, and the mean left bearing 0.0892 to 0.0712
/// (`opticalInset`). Line metrics are SF Pro Rounded's scaled to 1000 upem
/// (ascent 967, descent -211, cap 700), so a `Text` in it gets the same line
/// box as one in the system face and `headerTopPadding(forTitleSize:)` holds.
///
/// **TrueType, never CFF.** A CFF build is clipped about 0.08 em off the
/// bottom by `.contentTransition(.numericText())` (CLAUDE.md).
///
/// **Where it sets, and nowhere else** (`docs/research/font.md` (a)): screen
/// titles at 34, counts as digits alone, sheet titles at 17, and dynamic
/// titles only through `covers(_:)`. Never buttons, section labels, dates or
/// anything at 13 or below with a letter in it: below about 17pt his D reads
/// as O and his B as 8.
enum StrataFont {
    /// PostScript name, from the font's `name` table.
    static let name = "Strata-Regular"

    /// Cap height over em, from `OS/2.sCapHeight` (700 of 1000).
    static let capHeight: CGFloat = 0.700

    /// The mean left sidebearing of the ten digits, as a fraction of point
    /// size, from `hmtx` (0.060 for the widest to 0.100 for the narrowest).
    /// Tabular centring puts real air to the left of every digit, so a count
    /// aligned to a grid line still LOOKS indented beside a block.
    static let opticalInset: CGFloat = 0.0712

    /// A size the caller solves for. `.custom(_:size:)`, as `StrataNumerals`
    /// had it, so it moves with Dynamic Type relative to body exactly as
    /// before; nothing that swapped faces changed how it scales.
    static func size(_ points: CGFloat) -> Font {
        .custom(name, size: points)
    }

    /// Scales with Dynamic Type, which a fixed size does not.
    static func relative(_ points: CGFloat, to style: Font.TextStyle) -> Font {
        .custom(name, size: points, relativeTo: style)
    }

    /// A count, formatted for this face: digits and nothing else.
    ///
    /// **Never `Text("\(count)")`.** That is a `LocalizedStringKey`, and its
    /// interpolation formats an `Int` with the locale's grouping, so 1000
    /// arrives as "1,000" and the face has no comma.
    static func digits(_ value: Int) -> String {
        String(max(value, 0))
    }

    // MARK: - Coverage

    /// Characters the font has a glyph for that are still stand-ins. `/` is
    /// his `\` mirrored until he draws one (font.md, "Placeholders").
    static let placeholders: Set<Unicode.Scalar> = ["/"]

    /// The font's own character map, or nil when it is not registered.
    private static let characterSet: CharacterSet? = {
        let font = CTFontCreateWithName(name as CFString, 17, nil)
        // CoreText hands back a fallback face rather than failing, so check
        // that the font it made is the one that was asked for.
        guard CTFontCopyPostScriptName(font) as String == name else { return nil }
        return CTFontCopyCharacterSet(font) as CharacterSet
    }()

    /// Whether the font is registered in this process.
    static var isAvailable: Bool { characterSet != nil }

    /// Whether EVERY character of `string` is drawn by the owner.
    ///
    /// iOS falls back glyph by glyph, so "Café" in this face would set its é
    /// in SF Pro, lighter, narrower and shorter, a patch in the middle of the
    /// word. A string that fails goes to SF Pro Rounded WHOLE; never mix.
    static func covers(_ string: String) -> Bool {
        guard let set = characterSet, !string.isEmpty else { return false }
        return string.unicodeScalars.allSatisfy {
            set.contains($0) && !placeholders.contains($0)
        }
    }
}
