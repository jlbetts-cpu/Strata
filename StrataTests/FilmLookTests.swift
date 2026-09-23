import Testing
import Foundation
@testable import Strata

/// The looks' arithmetic. Pure, so all of it can be checked without a GPU —
/// and it has to be, because what it produces is baked into a colour table
/// and applied to every photograph somebody keeps.
@Suite("FilmLook")
struct FilmLookTests {

    private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-6) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - Tone

    @Test("linear and display are inverses")
    func transferRoundTrip() {
        for step in 0...20 {
            let v = Double(step) / 20
            #expect(close(FilmLook.toDisplay(FilmLook.toLinear(v)), v, 1e-9))
        }
    }

    @Test("the contrast curve holds its pivot and its ends")
    func contrastCurve() {
        for pivot in [0.4, 0.5, 0.6] {
            #expect(close(FilmLook.contrastCurve(0, 0.4, pivot), 0))
            #expect(close(FilmLook.contrastCurve(1, 0.4, pivot), 1))
            #expect(close(FilmLook.contrastCurve(pivot, 0.4, pivot), pivot))
        }
        // Below the pivot it darkens, above it it brightens. Not at the
        // quarter points: a smoothstep crosses identity exactly there, which
        // is a property of the curve rather than a bug in it.
        #expect(FilmLook.contrastCurve(0.15, 0.4, 0.5) < 0.15)
        #expect(FilmLook.contrastCurve(0.85, 0.4, 0.5) > 0.85)
    }

    @Test("every look is monotonic: brighter in, brighter out")
    func monotonic() {
        for look in FilmLook.all {
            var last = -1.0
            for step in 0...64 {
                let v = Double(step) / 64
                let out = FilmLook.luma(look.graded(FilmLook.RGB(v, v, v)))
                #expect(out >= last - 1e-9, "\(look.kind.name) reverses at \(v)")
                last = out
            }
        }
    }

    /// **Nothing may leave the range.** A look is baked into a colour table
    /// and anything outside 0...1 there is a clipped highlight or a crushed
    /// shadow that no amount of care later can recover.
    @Test("no look clips, and none of it is NaN")
    func inRange() {
        for look in FilmLook.all {
            for r in stride(from: 0.0, through: 1.0, by: 0.2) {
                for g in stride(from: 0.0, through: 1.0, by: 0.2) {
                    for b in stride(from: 0.0, through: 1.0, by: 0.2) {
                        let out = look.graded(FilmLook.RGB(r, g, b))
                        for value in [out.r, out.g, out.b] {
                            #expect(value.isFinite, "\(look.kind.name) produced \(value)")
                            #expect(value >= 0 && value <= 1)
                        }
                    }
                }
            }
        }
    }

    @Test("no look is identity, and none is a look")
    func noneIsNothing() {
        let colour = FilmLook.RGB(0.4, 0.35, 0.3)
        let untouched = FilmLook.none.graded(colour)
        #expect(untouched == colour)
        for look in FilmLook.all where look.kind != .none {
            #expect(look.graded(colour) != colour, "\(look.kind.name) does nothing")
        }
    }

    // MARK: - Colour

    @Test("Silver is black and white")
    func silverIsGrey() {
        for r in stride(from: 0.0, through: 1.0, by: 0.25) {
            let out = FilmLook.silver.graded(FilmLook.RGB(r, 1 - r, 0.5))
            #expect(close(out.r, out.g, 1e-6) && close(out.g, out.b, 1e-6))
        }
    }

    @Test("hue conversion round-trips")
    func hueRoundTrip() {
        for colour in [FilmLook.RGB(0.8, 0.2, 0.3), FilmLook.RGB(0.1, 0.6, 0.4),
                       FilmLook.RGB(0.2, 0.3, 0.9), FilmLook.RGB(0.5, 0.5, 0.5)] {
            let (h, s, v) = FilmLook.hsv(colour)
            let back = FilmLook.rgb(h: h, s: s, v: v)
            #expect(close(back.r, colour.r, 1e-9) && close(back.g, colour.g, 1e-9)
                    && close(back.b, colour.b, 1e-9))
        }
    }

    @Test("a pull eases towards the centre; a shift moves by the amount")
    func steering() {
        // A green at hue 0.40 exactly, pulled towards a centre it is NOT
        // already sitting on.
        let colour = FilmLook.RGB(0.2, 0.7, 0.4)
        let before = FilmLook.hsv(colour).h
        #expect(close(before, 0.40, 1e-9), "the fixture moved")
        let centre = 0.45
        let pulled = FilmLook.hsv(FilmLook.steer(colour, by: [
            FilmLook.HueBand(centre: centre, width: 0.2, move: 0.5, pull: true)])).h
        #expect(abs(pulled - centre) < abs(before - centre))
        let shifted = FilmLook.hsv(FilmLook.steer(colour, by: [
            FilmLook.HueBand(centre: before, width: 0.2, move: 0.05)])).h
        #expect(close(shifted, before + 0.05, 1e-6))
    }

    @Test("skin is recognised, and a sky is not")
    func skin() {
        // A mid-tone skin colour, and two things that are not skin.
        #expect(FilmLook.skinWeight(FilmLook.RGB(0.78, 0.60, 0.48)) > 0.5)
        #expect(FilmLook.skinWeight(FilmLook.RGB(0.35, 0.55, 0.85)) == 0)
        #expect(FilmLook.skinWeight(FilmLook.RGB(0.5, 0.5, 0.5)) == 0)
    }

    /// **The one that matters.** Every look moves colour; none of them may
    /// move a face. A look that turns skin ruddy is a look nobody uses on a
    /// photograph of a person, and that is the failing of every saturated
    /// filter on the phone.
    @Test("no look shifts the hue of skin more than a hair")
    func skinKeepsItsHue() {
        let skins = [FilmLook.RGB(0.92, 0.76, 0.64), FilmLook.RGB(0.78, 0.60, 0.48),
                     FilmLook.RGB(0.55, 0.40, 0.31), FilmLook.RGB(0.35, 0.25, 0.19)]
        for look in FilmLook.all where look.kind != .none && look.mono == nil {
            for skin in skins {
                let before = FilmLook.hsv(skin).h
                let after = FilmLook.hsv(look.graded(skin)).h
                #expect(abs(FilmLook.hueDistance(after, before)) < 0.02,
                        "\(look.kind.name) moved skin from \(before) to \(after)")
            }
        }
    }

    @Test("Bright adds colour to a leaf but not to a face")
    func brightHoldsSkinBack() {
        let leaf = FilmLook.RGB(0.25, 0.55, 0.25)
        let face = FilmLook.RGB(0.78, 0.60, 0.48)
        let leafGain = FilmLook.hsv(FilmLook.bright.graded(leaf)).s / FilmLook.hsv(leaf).s
        let faceGain = FilmLook.hsv(FilmLook.bright.graded(face)).s / FilmLook.hsv(face).s
        #expect(leafGain > 1.15, "the leaf should gain colour, got \(leafGain)")
        #expect(faceGain < leafGain, "skin gained as much as foliage")
    }

    @Test("a blown highlight goes white, not magenta")
    func clippedHighlightsStayNeutral() {
        // Green clipped first, which is what tips a blown area magenta.
        let blown = FilmLook.RGB(1.0, 0.97, 1.0)
        for look in FilmLook.all where look.kind != .none {
            let out = look.graded(blown)
            let spread = max(out.r, max(out.g, out.b)) - min(out.r, min(out.g, out.b))
            #expect(spread < 0.03, "\(look.kind.name) left \(spread) of colour in a blown highlight")
        }
    }
}
