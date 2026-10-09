import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Strata

/// **The drifts `docs/consistency-audit.md` found, as rules that can fail.**
///
/// The audit's own method is the reason this file exists. Check 3 of
/// `docs/screen-audit.md` — "every surface, control, card, rim and shadow comes
/// from the system; a privately rebuilt one fails" — was asked screen by screen
/// and every screen passed; asked component by component, eight shared components
/// had a live private copy somewhere. A question that gets two answers depending
/// on which way you ask it is a question nobody can keep answering by hand.
///
/// So each suite below is one of the audit's counts, held as arithmetic or as a
/// sweep of the sources. **A sweep has to be able to fail on its own deletion
/// note**, which is the trap `CLAUDE.md` names: the needle must distinguish a
/// declaration from a mention, or a comment explaining what went counts as the
/// thing that went. Every sweep here strips comment lines first, and
/// `theSweepCanSeeCode` proves the stripper has not swallowed the file.
@Suite("Memories, Profile and Settings consistency")
struct MemoriesConsistencyTests {

    // MARK: - The instrument

    /// The checkout, from this file's own path. If the layout changes, the sweep
    /// reports that it could not read rather than returning an empty list — a
    /// sweep that silently finds nothing is the failure mode `CLAUDE.md` names
    /// and `TypographyTests.repoRoot` was written against.
    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Every Swift line in the app's own sources, as (file, line number, text),
    /// with comment-only lines dropped.
    ///
    /// **Comment-only, not "comments stripped".** A trailing `// ...` after real
    /// code is left alone, because the code before it is what the sweep is for;
    /// what has to go is the paragraph that says "this used to be
    /// `.buttonStyle(.plain)`". Doc comments (`///`), block comments on their own
    /// line and `// MARK:` all count as comment-only.
    static func codeLines(in dirs: [String] = ["Strata", "Shared", "StrataWidget"]) -> [(file: String, line: Int, text: String)] {
        var out: [(file: String, line: Int, text: String)] = []
        let root = repoRoot()
        for dir in dirs {
            let base = root.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(atPath: base.path) else {
                out.append((file: "\(dir)-UNREADABLE", line: 0, text: base.path))
                continue
            }
            for case let rel as String in walker where rel.hasSuffix(".swift") {
                let path = base.appendingPathComponent(rel)
                guard let text = try? String(contentsOf: path, encoding: .utf8) else { continue }
                var inBlock = false
                for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    let line = String(raw)
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if inBlock {
                        if trimmed.contains("*/") { inBlock = false }
                        continue
                    }
                    if trimmed.hasPrefix("/*") {
                        if !trimmed.contains("*/") { inBlock = true }
                        continue
                    }
                    if trimmed.hasPrefix("//") { continue }
                    out.append((file: path.lastPathComponent, line: i + 1, text: line))
                }
            }
        }
        return out
    }

    private static func hits(_ needle: String, excluding files: Set<String> = []) -> [String] {
        codeLines()
            .filter { !files.contains($0.file) && $0.text.contains(needle) }
            .map { "\($0.file):\($0.line)  \($0.text.trimmingCharacters(in: .whitespaces))" }
    }

    /// **The sweep's own self-test.** A comment stripper that ate the file would
    /// make every test below pass by finding nothing, which is exactly the shape
    /// of "a gate that cannot fail". These two needles are in the shipping
    /// sources and must be found; if either goes to zero the instrument is broken
    /// rather than the app being clean.
    @Test("the sweep can see code, and it cannot see comments")
    func theSweepCanSeeCode() {
        let lines = Self.codeLines()
        #expect(lines.count > 5_000, "the sweep read \(lines.count) code lines, which is not this app")
        #expect(!lines.contains { $0.file.hasSuffix("-UNREADABLE") },
                "the sweep could not read a source directory: \(lines.filter { $0.file.hasSuffix("-UNREADABLE") })")
        #expect(!Self.hits("struct CountReadout: View").isEmpty,
                "the sweep cannot find a declaration it is standing on")
        // `SwitchTrack.swift`'s doc comment names `AppColors.switchOn` four times
        // over, and the whole point of the stripper is that those do not count.
        // If this finds one, a comment is being read as code.
        #expect(Self.hits(".tint(AppColors.switchOn)").isEmpty,
                "found in: \(Self.hits(".tint(AppColors.switchOn)"))")
    }

    // MARK: - §1.3 Switches are one colour, and it is a surface

    /// The audit counted eleven switches in two colours: `AppColors.switchOn`
    /// (#138BC2) on Profile's four and the plan line's, `AppColors.inkPrimary` on
    /// Settings' six, on two screens one push apart.
    @Test("every switch in the app has one tint")
    func oneSwitchTint() {
        let blue = Self.hits(".tint(AppColors.switchOn)")
        #expect(blue.isEmpty, "a switch still wears the retired blue: \(blue)")

        // **The needle is the INDENT, and that is not a trick.** Both screens
        // set two kinds of tint, and only one of them is a switch:
        //
        //   - at 8 spaces, on the `Form` itself, so the platform's links and
        //     pickers carry the primary. That is INK ON A PAGE and `inkPrimary`
        //     is right for it.
        //   - at 16 spaces, on a `Toggle` inside a `Section`. That is a SURFACE
        //     under a white thumb, and `inkPrimary` is a near-white there in
        //     dark mode.
        //
        // Nothing else in either file sits at that depth with a `.tint`, so the
        // indent separates the two cases exactly where the meaning does. A
        // reformat would make this stop finding anything, which is what
        // `rowTintsExist` below is for.
        // Plus any switch wearing the switch token at a shallower indent: Crew
        // Info's reaction switch lives in its own property, at 12 spaces, and
        // the indent alone stopped seeing it (2026-10-02).
        let deep = Self.hits("                .tint(AppColors.")
        let rowTints = deep + Self.hits(".tint(AppColors.switchTrack)").filter { !deep.contains($0) }
        #expect(!rowTints.isEmpty, "the sweep found no row-level tint at all, so it is measuring nothing")
        let wrong = rowTints.filter { !$0.contains("switchTrack") }
        #expect(wrong.isEmpty,
                "a switch is tinted with something other than `switchTrack`, which in dark mode is a surface under a white thumb: \(wrong)")
        // Eleven: Profile's four, Settings' six, and the plan line's one, which
        // another worker moved onto this token in the same pass. The audit
        // counted the plan line among the five `switchOn` sites, so the app's
        // whole switch population is one colour now.
        // Twelve since Crews (2026-10-02): Crew Info's reaction switch. Its
        // Hide Alerts switch became the Mute menu the same day.
        // Thirteen since 2026-10-03: Crew Info's Heads switch, which turns a
        // crew's heads off on this phone. It wears the token.
        // Fourteen since 2026-10-05: Settings' "Past Wins" (it read "A Past Win"
        // until the cohesion pass the same day), the evening
        // notification about a past win (`PastWinReminder`).
        // Fifteen since 2026-10-05: Settings' "Lock Journal", off by default,
        // which asks for Face ID or the passcode before the day's journal
        // opens (`JournalLock`). It wears the token.
        // Sixteen since 2026-10-05: the month drawing editor's "Bring It to
        // Life", on by default and kept with the drawing
        // (`MonthDrawingEditor`). It wears the token.
        // Sixteen again since 2026-10-07: Your day's "Hard day" switch came
        // and went (the owner: "I don't understand the point of checking the
        // hard day thing"; his pick: remove it).
        // Seventeen since 2026-10-08: Settings' "Share Anonymous Usage", on
        // by default, the switch for `Analytics`. It wears the token.
        #expect(rowTints.count == 17,
                "there are \(rowTints.count) switches in the app and there were 17; a new one needs the token too")
    }

    /// **The rule the two retired colours each broke, as arithmetic.**
    ///
    /// `switchOn`'s own header is the specification: "one colour in both schemes,
    /// chosen to contrast with the white thumb AND with either ground". A switch
    /// track is a SURFACE — `CLAUDE.md`'s "An ink is not a surface" — so it is
    /// measured against the knob, never against the page.
    ///
    /// **Proven able to fail**: putting `AppColors.inkPrimary` in place of
    /// `switchTrack` sends the dark-mode thumb ratio to 1.17 and this goes red,
    /// which is the state `SettingsView` shipped in.
    @Test("the switch track clears 3:1 against the white thumb and both grounds")
    func switchTrackIsASurface() {
        // **Per scheme since 2026-10-08**: one fixed grey cannot separate ON
        // from OFF in both schemes (the test below proves it), and on device
        // the fixed taupe read as disabled in light and as OFF in dark. Each
        // scheme's track is held to its own grounds.
        let thumb = Contrast.luminance((1, 1, 1))
        let light = Contrast.luminance(Contrast.resolved(AppColors.switchTrack, .light))
        let lightPage = Contrast.luminance((247 / 255, 247 / 255, 247 / 255))
        let offLight = Contrast.luminance((197 / 255, 197 / 255, 199 / 255))
        for (name, other) in [("the white thumb", thumb), ("the light page", lightPage), ("the light OFF track", offLight)] {
            let r = Contrast.ratio(light, other)
            #expect(r >= 3.0, "light: the track measures \(r):1 against \(name), under the 3:1 a control is held to")
        }
        let dark = Contrast.luminance(Contrast.resolved(AppColors.switchTrack, .dark))
        let darkPage = Contrast.luminance((29 / 255, 29 / 255, 29 / 255))
        let offDark = Contrast.luminance((101 / 255, 101 / 255, 105 / 255))
        for (name, other) in [("the white thumb", thumb), ("the night ground", darkPage)] {
            let r = Contrast.ratio(dark, other)
            #expect(r >= 3.0, "dark: the track measures \(r):1 against \(name), under the 3:1 a control is held to")
        }
        #expect(Contrast.ratio(dark, offDark) >= 1.7,
                "dark: ON is only \(Contrast.ratio(dark, offDark)):1 from OFF, and the two read as one state")
    }

    /// **And the thing that CANNOT be fixed, pinned so nobody spends an evening
    /// trying.** iOS draws its OFF track at rgb(197) in light and rgb(101) in
    /// dark — sampled off the built Settings screen in both schemes, not assumed
    /// — which is 96 levels apart. One fixed colour cannot sit 3:1 from both of
    /// those AND 3:1 from a white knob; swept in 4-level steps from rgb(96) to
    /// rgb(176), the best any fixed grey manages on its worst ratio is 1.82.
    ///
    /// So this asserts the arithmetic rather than a threshold the design cannot
    /// meet: the window the knob and the two grounds leave open does not contain
    /// a value that also clears 3:1 against both OFF tracks. **If this ever goes
    /// green, a floor moved and `AppColors.switchTrack` should be re-chosen**,
    /// which is the opposite of the usual direction and is why it is written as
    /// an expectation rather than a comment.
    @Test("no fixed grey can be 3:1 from both of iOS's OFF tracks and the white knob")
    func theMonochromeSwitchHasAKnownCeiling() {
        let knob = Contrast.luminance((1, 1, 1))
        let offLight = Contrast.luminance((197 / 255, 197 / 255, 199 / 255))
        let offDark = Contrast.luminance((101 / 255, 101 / 255, 105 / 255))
        var bestWorst = 0.0
        for level in stride(from: 80.0, through: 200.0, by: 1.0) {
            // Warm, at the app's own ratio, which is how the token is built.
            let c = (r: level / 255, g: level * 118 / 124 / 255, b: level * 111 / 124 / 255)
            let l = Contrast.luminance(c)
            let worst = min(Contrast.ratio(l, knob),
                            Contrast.ratio(l, offLight),
                            Contrast.ratio(l, offDark))
            bestWorst = max(bestWorst, worst)
        }
        #expect(bestWorst < 3.0,
                "a fixed grey now reaches \(bestWorst):1 on its worst of those three, so a monochrome switch CAN separate its own two states in both schemes and `AppColors.switchTrack` should be moved to it")

        // And the value that ships does clear the two ratios that are reachable.
        let track = Contrast.luminance(Contrast.resolved(AppColors.switchTrack, .dark))
        #expect(Contrast.ratio(track, knob) >= 3.0)
        #expect(Contrast.ratio(track, Contrast.luminance((44 / 255, 44 / 255, 46 / 255))) >= 3.0,
                "the track no longer clears 3:1 against the dark Form card it is drawn on")
    }

    // MARK: - §1.4 A sheet's confirm word

    /// The audit's table: two inks nine levels apart for one word, and three of
    /// six sheets leaving it under 44pt.
    ///
    /// **Proven able to fail**: making both roles return `inkPrimary` collapses
    /// the step and `theInkStepSaysWhichWordIsTheButton` goes red.
    @Test("the two roles are a real ink step, and the box is 44")
    func sheetActionIsOneAnswer() {
        #expect(SheetAction.target == 44, "the target is \(SheetAction.target), and the HIG's minimum is 44")
        let confirm = Contrast.luminance(Contrast.resolved(AppColors.inkPrimary, .light))
        let cancel = Contrast.luminance(Contrast.resolved(AppColors.inkSecondary, .light))
        #expect(cancel > confirm,
                "Cancel is not quieter than the confirm, so nothing in the bar says which word is the button")
        let step = Contrast.ratio(confirm, cancel)
        #expect(step >= 2.0,
                "the step between the two words is \(step):1, and `AddWinSheet` settled it at about 2.4 (14.4:1 beside 6.1:1)")
    }

    /// Every confirm or cancel word in a sheet's title row goes through the
    /// modifier, so the next sheet cannot be the fourth one without a 44pt box.
    /// The needle is the thing a hand-rolled one has and the modifier does not: a
    /// `Text` carrying `Typography.headerSmall` on the same line.
    @Test("no sheet sets its own confirm word's font")
    func noSheetHandRollsItsConfirmWord() {
        let handRolled = Self.hits("""
        Text("Done").font(Typography.headerSmall)
        """)
        #expect(handRolled.isEmpty, "a sheet still styles Done by hand: \(handRolled)")
    }

    // MARK: - §1.13 One count readout

    /// Four copies of six lines, and the only thing left between the two rungs is
    /// the optical inset. `SectionHeading` held the condition for sharing them —
    /// "it needs both rungs above" — and §2.4 found the record of those rungs
    /// stale the same day.
    /// **And it has no parameter at all, because the thing that was going to be
    /// one measured zero.** The audit's §1.13 says the inset is all that
    /// separates the two rungs; `StrataFont.opticalInset` went to 0 on
    /// 2026-09-30 when the drawn face came off, so it separated nothing. This
    /// holds both halves: the one size, and the fact that nothing is correcting
    /// a sidebearing that is not there.
    ///
    /// **Proven able to fail**: putting 0.0712 back in `StrataFont` makes the
    /// second expectation red and says, correctly, that the readout now has a
    /// decision to make again.
    @Test("the count readout is one size, with no options")
    func countReadoutIsOneRung() {
        #expect(CountReadout.size == 15,
                "the readout is \(CountReadout.size)pt; the app's label tier is 15 and `headerSmall`, `screenSubtitle` and `sectionLabel` are all on it")
        #expect(StrataFont.opticalInset == 0,
                "the face has a left sidebearing of \(StrataFont.opticalInset) again, so a count in a card's caption needs it corrected and a count under a screen title does not: `CountReadout` needs the parameter back")
    }

    /// The pluralisation, because the component owns the word now and a wrong
    /// plural would be wrong on three screens at once rather than one.
    @Test("a count of one is singular")
    func oneIsSingular() {
        #expect(CountReadout.wins(1).unit == "win")
        #expect(CountReadout.wins(2).plural == "wins")
        #expect(CountReadout.photos(1).unit == "photo")
        #expect(CountReadout.photos(0).plural == "photos")
    }

    /// Nothing else in the app corrects for the face's left bearing by hand. The
    /// one other legitimate reader is `GridConstants.tallyOpticalInset`, which is
    /// a different size on a different screen and is named rather than inline.
    @Test("the optical inset is applied in one place")
    func opticalInsetHasOneReader() {
        let readers = Self.hits("StrataFont.opticalInset",
                                excluding: ["CountReadout.swift", "GridConstants.swift", "StrataFont.swift"])
        #expect(readers.isEmpty, "a view corrects the left bearing by hand: \(readers)")
    }

    // MARK: - §1.14 One hairline

    /// `RestoreBackupView` states it: "One hairline, one token: `1 / displayScale`,
    /// not a flat 0.5, which is 50% too heavy on a 3x phone." `ReplayRow` drew a
    /// flat 0.5 under a comment saying it drew the same hairline as the album card
    /// one band above it.
    @Test("no card strokes a flat half point")
    func hairlinesAreOneDevicePixel() {
        let flat = Self.hits("lineWidth: 0.5")
            // The tower's lattice is drawn in a `Canvas`, where a stroke is in
            // the context's own units and `displayScale` is already applied to
            // the whole drawing. Not a card's edge, and not this file's to change.
            .filter { !$0.hasPrefix("MainAppView.swift") }
            // The same skipped-block stripes, moved unchanged out of
            // MainAppView into TowerBlocks.swift (2026-10-02), still a Canvas.
            .filter { !$0.hasPrefix("TowerBlocks.swift") }
        #expect(flat.isEmpty, "a flat 0.5 hairline is 50% too heavy on a 3x phone: \(flat)")
    }

    // MARK: - §1.8 Every button answers a finger

    /// `docs/motion-audit.md` §5.1 counted thirty-one buttons with no answer to a
    /// press; the consistency audit counted twenty-five `.buttonStyle(.plain)` of
    /// which twenty were on non-glass controls. **Every exemption here is named
    /// with its reason**, which is what `docs/screen-audit.md` asks of an
    /// exemption, and the list is the whole of what `.plain` is still allowed to
    /// mean: this control already answers a press some other way.
    @Test("the only .plain left is on something that already answers a press")
    func plainIsOnlyOnGlassOrAHandRolledPress() {
        let exempt: [String: String] = [
            "GlassIconButton.swift": "Liquid Glass is `.interactive()` and responds by itself",
            "ProfileAvatar.swift": "its label is a `GlassIconButton`",
            "PhotoViewer.swift": "its label is a glass overlay",
            "ReplayView.swift": "both labels are `glassCapsule()`",
            "HeadMakerView.swift": "the shutter hand-rolls its own press, measured, because a disabled plain button is dimmed by the environment and the block came out at 128 of 255",
            "CameraView.swift": "the shutter, the same reason",
            "HeadSticker.swift": "not this worker's file",
            "AddWinSheet.swift": "not this worker's file",
            "LogWinWidgets.swift": "a widget's button: WidgetKit draws the press itself, and an app press style cannot run in a widget",
            "CrewReactions.swift": "labels are Liquid Glass, which answers the press itself; a scaling press style on interactive glass cancelled taps on a real phone (2026-10-05)",
            "CrewTowerView.swift": "the name capsule is `glassCapsule(onPage:)`; the CrewReactions reason (2026-10-06 audit)",
            "DaySheet.swift": "the emoji disc is `glassCircle(onPage:)`, as `GlassIconButton` is; the CrewReactions reason (2026-10-06 audit)",
            "GoalRing.swift": "the goal's caption is `CrestCaption`, the crew name's own `glassCapsule(onPage:)`; the CrewReactions reason (2026-10-06)"
        ]
        let unexplained = Self.hits(".buttonStyle(.plain)").filter { hit in
            !exempt.keys.contains { hit.hasPrefix($0 + ":") }
        }
        #expect(unexplained.isEmpty,
                "a button draws its label and nothing else, with no reason on record: \(unexplained)")
    }

    // MARK: - §1.6 and §1.7 One primary capsule

    /// `PrimaryCapsule` exists because three screens had three copies of it in
    /// two colours. The map's "Turn On Places" was a fourth, in a file the
    /// extracting sweep did not open, and the walkthrough's LinkedIn button was a
    /// second copy of the OUTLINED state forty lines above the call to the type
    /// that fixed its corner.
    @Test("nothing draws its own 50pt capsule")
    func thePrimaryCapsuleIsTheOnlyOne() {
        let copies = Self.hits("PrimaryCapsule.height", excluding: ["PrimaryCapsule.swift"])
        #expect(copies.isEmpty, "a screen sizes its own pill off the type instead of using it: \(copies)")
        let fills = Self.hits("Capsule().fill(AppColors.slotInk)")
        #expect(fills.isEmpty, "the map's private primary pill is back: \(fills)")
    }

    // MARK: - §1.16 A block has the inside light

    /// Eight of ten `BlockSurface` call sites hand it `EtherealFill.fill(...)`.
    /// The two that handed it a flat colour were the plan line's swatches and the
    /// walkthrough's demo block, which is the first block anybody ever sees. The
    /// owner asked for it by name: "I want the blocks to have this kinda glass
    /// transparency as well in them, for the inner colour instead of just flat."
    @Test("the walkthrough's block is lit like a block")
    func theFirstBlockIsLit() {
        let flat = Self.hits("category.style.baseColor", excluding: ["CategoryColors.swift"])
            .filter { $0.hasPrefix("OnboardingView.swift") && !$0.contains("EtherealFill") }
        #expect(flat.isEmpty, "the first block anybody sees is a flat fill: \(flat)")
    }

    // MARK: - §1.15 An icon grows with the text beside it

    /// `IconStyle`'s own doc: "`.font(.system(size:))` is a fixed size, it does
    /// not respond to the user's text size at all, so icons stayed put while the
    /// labels beside them grew", and brand.md requires Dynamic Type everywhere
    /// (WCAG 1.4.4). Thirteen call sites used `.iconSize`; five did not, and two
    /// of the five are geometry-solved fractions of an object, which is the
    /// exception `Typography` already declares.
    @Test("the Memories page's play glyph scales with its label")
    func theReplayRowsGlyphScales() {
        let fixed = Self.hits(".font(.system(size:")
            .filter { $0.hasPrefix("ReplayRow.swift") }
        #expect(fixed.isEmpty, "the play glyph is a fixed size again: \(fixed)")
    }

    // MARK: - §1.9 One way of saying a tile is chosen

    /// `FilmLookStrip` measured the cost of the scale step and removed it: "the
    /// declared 8pt gutter rendered as 9.7 / 11.4 / 11.4: one number on the ladder
    /// arriving on screen as two that are not, and the pattern moves every time
    /// you pick a different look." Both head pickers kept it.
    @Test("no picker scales an unchosen tile")
    func noPickerScalesItsTiles() {
        let scaled = Self.hits("scaleEffect(isChosen")
        #expect(scaled.isEmpty,
                "a picker still scales its unchosen tiles, which breaks the gutter it declares: \(scaled)")
    }

    /// And the signal that is left has to carry it on its own, because dropping
    /// the scale takes a default roster from two signals to one.
    @Test("the chosen ring reads on both cards")
    func theRingCarriesIt() {
        let ink = 0.55
        // The card a picker sits on, sampled off the built sheet in both schemes:
        // rgb(255) in light and rgb(45) in dark (`HeadPickerRow`'s own note).
        for (name, card, ringOver) in [("light", 255.0, 0.0), ("dark", 45.0, 255.0)] {
            let ring = card + ink * (ringOver - card)
            let r = Contrast.ratio(Contrast.luminance((ring / 255, ring / 255, ring / 255)),
                                   Contrast.luminance((card / 255, card / 255, card / 255)))
            #expect(r >= 3.0,
                    "the ring measures \(r):1 on the \(name) card, and it is now the only thing saying which head is chosen")
        }
    }

    // MARK: - §1.13 The dead card really is gone

    /// 173 lines with no caller, and `SectionHeading` cited one of its functions
    /// as live. A deletion that leaves the names behind is the water comment all
    /// over again, so this holds that they are names in prose and not in code.
    @Test("the shelf's replay card and its five properties are deleted")
    func theDeadCardIsGone() {
        for needle in ["private func card(_ replay: Replay",
                       "private func periodName(", "private func countLine(",
                       "let model: ReplayShelfModel"] {
            let found = Self.hits(needle, excluding: ["ReplayShelfModel.swift"])
                .filter { $0.hasPrefix("MemoriesShelf.swift") }
            #expect(found.isEmpty, "the dead card is back: \(found)")
        }
    }

    /// And `isPushed`, which had one value at both of its call sites, so Settings
    /// drew no confirm word at all while the audit counted it as one of six.
    /// `SectionHeading`: "A flag with one value in the whole app is a decision
    /// nobody made."
    @Test("Settings has no flag with one value")
    func settingsHasNoDeadFlag() {
        let found = Self.hits("isPushed")
        #expect(found.isEmpty, "the flag is back: \(found)")
    }
}

// MARK: - Contrast, computed rather than looked at

/// `CLAUDE.md`: "Contrast is arithmetic, so compute it rather than looking: the
/// four above were all found by computing WCAG ratios from the token's real RGB
/// over the real ground, and all four were invisible to the eye on the simulator
/// in the scheme they were authored in."
///
/// The same three functions `SlotAndDeleteInkTests` carries privately. They are
/// here rather than shared because that file is another worker's this session;
/// one of the two copies should go.
enum Contrast {
    static func resolved(_ colour: Color, _ style: UIUserInterfaceStyle) -> (r: Double, g: Double, b: Double) {
        let ui = UIColor(colour).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        // An adaptive token can resolve with alpha below 1 (`inkPrimary` is
        // `white.opacity(0.92)`), and a ratio against a ground needs the
        // COMPOSITE. Over the scheme's own page, which is what these inks are
        // drawn on.
        let ground: Double = style == .dark ? 29 / 255 : 247 / 255
        func over(_ c: CGFloat) -> Double { Double(c) * Double(a) + ground * (1 - Double(a)) }
        return (over(r), over(g), over(b))
    }

    static func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func ch(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }

    static func ratio(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
