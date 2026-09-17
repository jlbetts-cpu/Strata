import Testing
import SwiftUI
import UIKit
@testable import Strata

/// The owner's font: that it is really registered, that `covers` tells the
/// truth about its character map, and the one layout bug a count in it had.
@MainActor
struct StrataFontTests {

    /// `Font.custom` falls back to the system face silently, so a missing
    /// `UIAppFonts` entry would pass every other test and look like SF.
    @Test func isRegistered() {
        #expect(StrataFont.isAvailable)
        #expect(UIFont(name: StrataFont.name, size: 17) != nil)
    }

    @Test func coversWhatHeDrew() {
        #expect(StrataFont.covers("Memories"))
        #expect(StrataFont.covers("Add a win"))
        #expect(StrataFont.covers("Saturday 5 September"))
        #expect(StrataFont.covers("0123456789"))
    }

    /// One missing glyph sends the whole string to SF, never a patch.
    @Test func refusesAnythingHeDidNotDraw() {
        #expect(!StrataFont.covers("Café"))
        #expect(!StrataFont.covers("St. Ives"))
        #expect(!StrataFont.covers("O’Hare"))
        #expect(!StrataFont.covers("Zürich"))
        #expect(!StrataFont.covers("東京"))
        #expect(!StrataFont.covers(""))
    }

    /// `/` has a glyph, but it is his `\` mirrored as a stand-in.
    @Test func refusesThePlaceholderSlash() {
        #expect(!StrataFont.covers("9/14"))
    }

    /// The font's own numbers, so the tally inset cannot drift from them.
    @Test func digitMetricsMatchTheFont() throws {
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
        #expect(abs(lsbTotal / 10 / 1000 - StrataFont.opticalInset) < 0.002)
    }

    /// `"\(1000)"` in a `Text` is "1,000", and the face has no comma.
    @Test func digitsCarryNoGrouping() {
        #expect(StrataFont.digits(1000) == "1000")
        #expect(StrataFont.digits(12345) == "12345")
        #expect(StrataFont.covers(StrataFont.digits(1000)))
    }
}
