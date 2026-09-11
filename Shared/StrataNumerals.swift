import SwiftUI

/// **In Shared/ so the widget can use it too.** The font file lives beside
/// this, in one place rather than two: a second copy in the app's own
/// resources would collide with this one at build time, and a widget that
/// silently falls back to the system face looks exactly like the font not
/// loading.
///
/// Registered by `UIAppFonts` in Info.plist — the app's, and the widget's. Without that entry `Font.custom`
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

    /// Digits only, because that is all this face has.
    ///
    /// It carries ten glyphs and a space, so a `Text` in it containing a
    /// letter renders `.notdef` — a run of empty boxes. Anything that formats
    /// a number for this font goes through here rather than trusting the
    /// caller not to pass a thousands separator or a minus sign.
    static func digits(_ value: Int) -> String {
        String(max(value, 0))
    }
}
