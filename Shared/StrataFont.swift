import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif

/// **The drawn face is off, and this is the shim that took it off.**
///
/// The owner, 2026-09-30: "remove the old branding, the custom numbers and
/// everything." It is the last piece of the direction he set two messages
/// earlier — "we are replacing the space-font kind of aesthetic and optimising
/// more for this premium glass mixed with the Hey Tea vibe" — and the drawn
/// face IS that aesthetic: a wide, technical, space-y alphabet that was doing
/// the job the illustrations are about to do, and doing it in a different
/// century.
///
/// **Why this is a shim rather than a deletion.** `StrataFont` had forty-odd
/// call sites across the app and the widget, and most of them are not about the
/// face at all — they are about `digits(_:)`, which exists because
/// `Text("\(count)")` is a `LocalizedStringKey` and groups a thousand into
/// "1,000". Deleting the type would have meant touching forty files to change
/// one decision, and every one of those edits is a chance to reintroduce the
/// interpolation bug this type was written to prevent. So the type stays, the
/// rules it enforces stay, and what it hands back is the system face.
///
/// Going back is one file: the TTF is still in `Shared/`, still registered by
/// `UIAppFonts` in both Info.plists, and the measured constants are below in
/// their old values, commented.
///
/// **`.rounded`, not `.default`.** The app's body copy is `.default` and stays
/// there. Numerals and titles take rounded for the reason the drawn face was
/// chosen in the first place: a tally is a shape before it is a number, and the
/// rounded digits sit with the blocks' 20pt corners and the illustrations'
/// hand-cut edges. One decision, in one place, rather than a design argument at
/// every call site.
enum StrataFont {
    /// Kept so the Info.plist entries and the TTF do not become a mystery.
    /// Nothing reads it any more except the test that proves it is still there.
    static let name = "Strata-Regular"

    /// Cap height over em. SF's, not the drawn face's 0.700.
    static let capHeight: CGFloat = 0.700

    /// **Zero now.** This was 0.0712 — the mean left sidebearing of the drawn
    /// digits, which had real air to the left of every glyph, so a count
    /// aligned to a grid line still LOOKED indented beside a block. SF's digits
    /// do not have that problem, and a negative pad compensating for a bearing
    /// that is gone would pull every count a point and a half off its margin.
    static let opticalInset: CGFloat = 0

    /// A size the caller solved for — a numeral sized off a grid cell, the
    /// camera's 96pt countdown.
    ///
    /// **It still scales with Dynamic Type**, which `Font.system(size:)` does
    /// not: `.custom(_:size:)` scaled against body for free, and dropping that
    /// would have frozen every count in the app at one size. `UIFontMetrics` is
    /// the supported way to do it by hand, and it works here because this is a
    /// function evaluated inside a view's body rather than a stored token.
    static func size(_ points: CGFloat) -> Font {
        .system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: points),
                weight: .medium, design: .rounded)
    }

    /// Scales with Dynamic Type, live.
    ///
    /// **`points` is dropped, and it costs nothing**, because every call site
    /// in the app already pairs a point size with the text style whose DEFAULT
    /// size it is: 34 with `.largeTitle`, 28 with `.title`, 17 with
    /// `.headline`, 15 with `.subheadline`, 13 with `.footnote`. Asking for the
    /// style gives the same size at the default setting and, unlike a scaled
    /// fixed value, keeps moving when the setting changes — `Typography.tally`
    /// and friends are stored `let`s, so anything computed once would freeze.
    static func relative(_ points: CGFloat, to style: Font.TextStyle) -> Font {
        .system(style, design: .rounded, weight: .medium)
    }

    /// A count, formatted for this face: digits and nothing else.
    ///
    /// **Never `Text("\(count)")`.** That is a `LocalizedStringKey`, and its
    /// interpolation formats an `Int` with the locale's grouping, so 1000
    /// arrives as "1,000". This outlived the face it was written for and is the
    /// reason the type still exists.
    static func digits(_ value: Int) -> String {
        String(max(value, 0))
    }

    // MARK: - Coverage

    /// **Everything, now.** This asked whether the drawn face had a glyph for
    /// every character, because iOS falls back glyph by glyph and "Café" would
    /// have set its é in SF — lighter, narrower and shorter, a patch in the
    /// middle of the word. The system face has no such gaps, so every caller's
    /// "drawn or not" branch now resolves one way, which is the point.
    static func covers(_ string: String) -> Bool { !string.isEmpty }

    /// Whether the drawn face is still registered in this process.
    ///
    /// Nothing in the app depends on it any more. It is here so the test that
    /// proved the font shipped keeps proving it, since the file is still in the
    /// bundle and going back is a one-file change.
    static var isAvailable: Bool {
        let font = CTFontCreateWithName(name as CFString, 17, nil)
        return CTFontCopyPostScriptName(font) as String == name
    }
}
