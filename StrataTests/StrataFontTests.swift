import Testing
import SwiftUI
import UIKit
@testable import Strata

/// **The drawn face is off (2026-09-30), so these tests changed with it.**
///
/// The owner: "remove the old branding, the custom numbers and everything."
/// `StrataFont` is a shim over the system face now — see its own note for why
/// the type survived its font. Three of these tests were about the drawn face's
/// character map and metrics and could only ever have passed while it was
/// setting type; they are updated here with the reason rather than deleted,
/// because the file is still in the bundle and going back is a one-file change.
///
/// What is still worth proving: that the TTF really ships (so the revert is
/// one file and not a hunt), that `covers` answers the way callers now branch
/// on it, and the interpolation bug `digits` exists to prevent — which is the
/// only thing here that was never about the face at all.
@MainActor
struct StrataFontTests {

    /// `Font.custom` falls back to the system face silently, so a missing
    /// `UIAppFonts` entry would pass every other test and look like SF.
    @Test func isRegistered() {
        #expect(StrataFont.isAvailable)
        #expect(UIFont(name: StrataFont.name, size: 17) != nil)
    }

    /// **`covers` is now true for everything with a character in it.**
    ///
    /// It asked whether the DRAWN face had a glyph for every character, because
    /// iOS falls back glyph by glyph and "Café" would have set its é in SF — a
    /// lighter, narrower patch in the middle of a word. The accented, the
    /// apostrophed and the Japanese cases below were the whole point of it, and
    /// they are kept as the record of what it was for; they assert the opposite
    /// now, which is the honest statement of what changed. The system face has
    /// no gaps, so every caller's "drawn or not" branch resolves one way.
    @Test func coversEveryStringWithSomethingInIt() {
        #expect(StrataFont.covers("Memories"))
        #expect(StrataFont.covers("0123456789"))
        // Each of these was false while the drawn face was setting type.
        #expect(StrataFont.covers("Café"))
        #expect(StrataFont.covers("O’Hare"))
        #expect(StrataFont.covers("東京"))
        #expect(StrataFont.covers("9/14"))
        // And the empty string still is not a string to set.
        #expect(!StrataFont.covers(""))
    }

    /// **The drawn face's own numbers, which nothing lays out against any
    /// more.**
    ///
    /// It proved that `opticalInset` matched the mean left sidebearing of the
    /// ten digits, so the tally's negative pad could not drift from the font it
    /// was compensating for. `opticalInset` is 0 now — SF's digits do not have
    /// that air — so the assertion that tied them together is replaced by the
    /// one that matters today: the inset must stay at zero while the system
    /// face is setting, or every count in the app pulls a point and a half off
    /// its margin.
    ///
    /// The metrics themselves are still checked, because they are what a revert
    /// would restore and a silently re-exported font is exactly the kind of
    /// thing that breaks it.
    @Test func drawnFaceStillShipsWithItsMetrics() throws {
        #expect(StrataFont.opticalInset == 0, "SF's digits carry no sidebearing to cancel")
        let font = try #require(UIFont(name: StrataFont.name, size: 1000))
        #expect(abs(font.capHeight - 700) < 1)
        let ct = font as CTFont
        var lsbTotal: CGFloat = 0
        var advances: Set<Int> = []
        for d in "0123456789".utf16 {
            var ch = d
            var glyph: CGGlyph = 0
            #expect(CTFontGetGlyphsForCharacters(ct, &ch, &glyph, 1))
            var rect = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(ct, .horizontal, &glyph, &rect, 1)
            lsbTotal += rect.minX
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(ct, .horizontal, &glyph, &advance, 1)
            advances.insert(Int(advance.width.rounded()))
        }
        #expect(advances == [906], "digits are no longer tabular at 0.906 em")
        #expect(abs(lsbTotal / 10 / 1000 - 0.0712) < 0.002,
                "the drawn face's own sidebearing, for whenever it comes back")
    }

    /// `"\(1000)"` in a `Text` is "1,000", and the face has no comma.
    @Test func digitsCarryNoGrouping() {
        #expect(StrataFont.digits(1000) == "1000")
        #expect(StrataFont.digits(12345) == "12345")
        #expect(StrataFont.covers(StrataFont.digits(1000)))
    }
}
