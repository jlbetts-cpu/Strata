import SwiftUI
import Testing
import UIKit
@testable import Strata

/// **The 2026-10-02 design review of the Wins side, pinned.**
///
/// `docs/design-review/` is the report; this is the part of it that can come
/// back. Each suite holds both halves, as `ConsistencyTests` does: the thing
/// that was fixed, and an injection proving the matcher would have caught it.
@Suite("Design review, Wins side, 2026-10-02")
struct DesignReviewWinsSideTests {

    // MARK: - Text is never written in the glyph ink

    /// The review's one systemic finding. `inkQuiet` is held to 3:1 because it
    /// is for glyphs, and its own doc says never a sentence, a count or a
    /// subtitle. Six pieces of text on these screens were written in it anyway
    /// and measured **3.32 to 3.35:1** in the light scheme: the add sheet's and
    /// the plan line's prompts, the plan's repeat summary and done lines, and
    /// the replay's "wins", date and "Sample". The dark scheme hid it, at 6.0.
    static let screens = [
        "Strata/Views/AddWinSheet.swift",
        "Strata/Views/PlanSheet.swift",
        "Strata/Views/PlanItemDetailSheet.swift",
        "Strata/Views/PlanTextField.swift",
        "Strata/Views/ReplayFrame.swift",
    ]

    /// A line of code that writes TEXT in `inkQuiet`: a `foregroundStyle`
    /// within three code lines of a `Text(`, or a UIKit field's `textColor`.
    static func textInQuietInk(_ code: String) -> [String] {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var out: [String] = []
        for (i, line) in lines.enumerated() {
            if line.contains("textColor") && line.contains("inkQuiet") {
                out.append(line); continue
            }
            guard line.contains(".foregroundStyle(AppColors.inkQuiet") else { continue }
            let window = lines[max(0, i - 3)..<i]
            if window.contains(where: { $0.contains("Text(") }) { out.append(line) }
        }
        return out
    }

    @Test("no text on the Wins side is set in inkQuiet")
    func noTextInQuietInk() throws {
        for path in Self.screens {
            let code = SourceSweep.code(try SourceSweep.read(path))
            let found = Self.textInQuietInk(code)
            #expect(found.isEmpty, "\(path) writes text in inkQuiet: \(found)")
        }
    }

    @Test("the quiet-ink sweep catches what it is for")
    func quietInkSweepCatches() {
        let prompt = """
                        prompt: Text("What did you do?")
                            .foregroundStyle(AppColors.inkQuiet)
        """
        let field = "        field.textColor = UIColor(isDone ? AppColors.inkQuiet : AppColors.inkPrimary)"
        let glyph = """
                    Image(systemName: "info.circle")
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                        .foregroundStyle(AppColors.inkQuiet)
        """
        #expect(Self.textInQuietInk(prompt).count == 1)
        #expect(Self.textInQuietInk(field).count == 1)
        // A glyph in the quiet ink is what the token is FOR, and must pass.
        #expect(Self.textInQuietInk(glyph).isEmpty)
    }

    /// The arithmetic behind the swap, so the reason survives a palette change:
    /// on the light page the caption ink clears text contrast and the glyph ink
    /// does not. If a future palette lifts `inkQuiet` past 4.5 this goes red and
    /// says the review's reason is gone, which is information, not a failure to
    /// silence.
    @Test("the caption ink clears 4.5 on the page and the glyph ink does not")
    func theInksOnThePage() {
        let page = (r: 247.0 / 255, g: 247.0 / 255, b: 247.0 / 255)
        let tertiary = composite(AppColors.inkTertiary, over: page)
        let quiet = composite(AppColors.inkQuiet, over: page)
        #expect(contrast(tertiary, page) >= 4.5, "inkTertiary is \(contrast(tertiary, page)):1")
        #expect(contrast(quiet, page) < 4.5, "inkQuiet is \(contrast(quiet, page)):1")
    }

    // MARK: - The slot can be used without dragging

    /// WCAG 2.5.1. VoiceOver's activation drops a Quick; the bigger sizes and
    /// the named win were reachable only by a drag, and the hint said "drag".
    @Test("the slot offers every size as an accessibility action")
    func slotOffersEverySize() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/NextSlotButton.swift"))
        #expect(code.contains(".accessibilityActions"))
        #expect(code.contains("fire(size: .medium"))
        #expect(code.contains("fire(size: .hard"))
        #expect(code.contains("onOpenMenu()"))
        #expect(!code.contains("Drag out to make it bigger"),
                "the hint tells a VoiceOver user to do the one thing they cannot")
    }

    // MARK: - The photo menu is on the photograph

    /// The long-press menu hung on the `NavigationStack`, so a long press
    /// anywhere on the sheet lifted the whole sheet. It must be attached after
    /// the photo well is declared and before the next member begins.
    @Test("the photo menu belongs to the photo well")
    func photoMenuOnTheWell() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        let well = try #require(code.range(of: "func photoWell("))
        let menu = try #require(code.range(of: ".contextMenu {"))
        #expect(menu.lowerBound > well.lowerBound, "the menu is attached above the well, at sheet level")
        #expect(code.components(separatedBy: ".contextMenu {").count == 2, "one photo menu, not two")
    }

    // MARK: - Helpers

    private func composite(_ colour: Color, over g: (r: Double, g: Double, b: Double))
        -> (r: Double, g: Double, b: Double) {
        let ui = UIColor(colour).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, gr: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &gr, blue: &b, alpha: &a)
        let al = Double(a)
        return (Double(r) * al + g.r * (1 - al), Double(gr) * al + g.g * (1 - al), Double(b) * al + g.b * (1 - al))
    }

    private func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func ch(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }

    private func contrast(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
