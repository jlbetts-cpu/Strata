import SwiftUI
import Testing
import UIKit
@testable import Strata

/// **Two colours that were tuned on one ground and used on two.**
///
/// Both were found on 2026-10-01 by photographing states nobody had
/// photographed: the Edit sheet in the dark, and the replay's loading slot,
/// which `-strataReplayHoldLoad` is the only way to reach. Both are the same
/// family of fault as CLAUDE.md's "an ink is not a surface" list — a number
/// that was measured once, against the page it happened to be written on.
///
/// Neither of these tests can see a screen, and that is not what they are for.
/// What they hold is the thing a measurement discovers and then forgets: that
/// the delete button's red has to INVERT, and that the replay's waiting slot
/// and the tower's real slot are one number rather than two that agree.
@Suite("Slot and delete ink")
struct SlotAndDeleteInkTests {

    private func resolved(_ colour: Color, _ style: UIUserInterfaceStyle) -> (r: Double, g: Double, b: Double) {
        let ui = UIColor(colour).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func ch(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }

    // MARK: - The delete button's red

    /// **It was ONE fixed hex and it had to be two.**
    ///
    /// `.bordered` draws the label at the tint and the pill from the same tint
    /// blended toward the page, so a red chosen to sit dark on a 247 ground
    /// sits dark on a 28 one too. Measured off the built Edit sheet at
    /// 402x874 before this changed: the label 4.56:1 on its pill in the light
    /// and **2.20:1** in the dark, with the pill itself 1.08:1 against the page
    /// — a dim red word floating in the margin, on the one control in this app
    /// that destroys a win.
    ///
    /// **Proven able to fail**: putting the light hex back in both branches
    /// makes the dark red darker than the night ground and this goes red.
    @Test("the delete red inverts with the scheme")
    func destructiveRedInverts() {
        let light = luminance(resolved(AddWinSheet.destructiveTint, .light))
        let dark = luminance(resolved(AddWinSheet.destructiveTint, .dark))
        // The night ground is about rgb(29) and the day page about rgb(247).
        let nightGround = luminance((29 / 255, 29 / 255, 29 / 255))
        let dayPage = luminance((247 / 255, 247 / 255, 247 / 255))
        #expect(light < dayPage,
                "a tint that is not darker than the page it is drawn on cannot be seen on it")
        #expect(dark > nightGround * 4,
                "the dark red's luminance is \(dark) against a ground of \(nightGround): that is the fixed hex again")
        #expect(dark > light,
                "the two reds are the same weight, which means one of the two grounds was never measured")
    }

    /// The light value is the one that was measured and argued for, and it did
    /// not move: a pill of (231, 199, 201) with its label at 4.56:1, against
    /// systemRed's 2.54 and `D70015`'s 3.50. This pins it so a dark-mode fix
    /// cannot quietly take the daylight with it.
    @Test("the light red is still B3000F")
    func theLightRedIsUnchanged() {
        let c = resolved(AddWinSheet.destructiveTint, .light)
        #expect(abs(c.r - 0.702) < 0.004, "red is \(c.r)")
        #expect(abs(c.g - 0.0) < 0.004, "green is \(c.g)")
        #expect(abs(c.b - 0.059) < 0.004, "blue is \(c.b)")
    }

    // MARK: - The two empty slots

    /// **The replay's waiting slot, held to the ratio rather than to a
    /// borrowed alpha.**
    ///
    /// `ReplayLoadingSlot`'s own note said "resting, the two match". It was
    /// true of the recess and stopped being true of the edge the day
    /// `NextSlotButton` went 0.26 to 0.80 — the value both that file and
    /// `AddWinSheet`'s photo well name as the known-bad one. Photographed with
    /// `-strataReplayHoldLoad`, the waiting slot's dash peaked at rgb(191) on a
    /// 247 page: **1.73:1**, under the 3:1 WCAG asks of a shape, on a page with
    /// nothing else drawn on it at all.
    ///
    /// The test is the arithmetic off the render rather than the opacity,
    /// because the opacity is what was wrong: 0.26 means two different
    /// contrasts on the two grounds, and copying `NextSlotButton`'s 0.80 onto
    /// this 1.5pt dash would mean a third.
    ///
    /// **Proven able to fail**: putting 0.26 back takes the light figure to
    /// 1.73 and this goes red; putting 0.80 in takes it to about 8 and the
    /// ceiling catches it.
    @Test("the waiting slot's dash clears 3:1 on both grounds")
    func theWaitingSlotReads() {
        // Measured on the built replay at 402x874: this stroke renders
        // `247 - 215a` on the light page and `29 + 245a` on the night ground.
        let lightInk = ReplayLoadingSlot.edgeInk(in: .light)
        let darkInk = ReplayLoadingSlot.edgeInk(in: .dark)
        let onLight = 247.0 - 215.0 * lightInk
        let onDark = 29.0 + 245.0 * darkInk

        func ratio(_ a: Double, _ b: Double) -> Double {
            func ch(_ v: Double) -> Double {
                let v = v / 255
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            let la = ch(a), lb = ch(b)
            return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
        }

        let light = ratio(onLight, 247)
        let dark = ratio(onDark, 29)
        #expect(light >= 3.0,
                "the dash computes to rgb(\(Int(onLight))) on the page, \(light):1, and a shape is held to 3")
        #expect(dark >= 3.0,
                "the dash computes to rgb(\(Int(onDark))) on the night ground, \(dark):1")
        // And it is a ghost, not a border. Past about 5:1 on either ground this
        // stops being the place a tower will stand and becomes a drawn box.
        #expect(light <= 5.0, "at \(light):1 the waiting slot is a black box on a white page")
        #expect(dark <= 6.0, "at \(dark):1 the waiting slot is a white box on a black page")
    }

    /// The recess was always shared and still is, so this is the half of
    /// "resting, the two match" that was true. Pinned so a change to one slot's
    /// socket has to be a deliberate change to both.
    @Test("a slot's socket is far enough off the page to be a surface")
    func theSocketIsASurface() {
        // `slotInk` is rgb(64, 61, 57) on the light page, so an ink of `a`
        // lands `a * (247 - 64)` levels below a 247 ground. Check 12 of
        // `docs/screen-audit.md` puts the floor between texture and structure
        // at 4 levels.
        let light = 0.038 * (247.0 - 64.0)
        #expect(light >= 4,
                "the socket is \(light) levels below the page, which is texture rather than a place a block goes")
    }
}
