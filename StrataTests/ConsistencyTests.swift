import Foundation
import Testing
@testable import Strata

/// The 2026-10-01 consistency pass, pinned.
///
/// `docs/consistency-audit.md` is check 3 of `docs/screen-audit.md` tested rather
/// than asserted: it took each shared component, listed its call sites, and went
/// looking for the places that draw the same thing without it. It found eight
/// components with a live private copy of themselves, ten answers to "this is
/// selected", six shapes of destructive action and six shapes of sheet title row.
///
/// **Every one of those is a thing that comes back**, because a second copy of a
/// component is written by somebody who could not find the first. So each fix
/// below is pinned the way `CopyCutsTests` pins a deleted sentence — against the
/// working tree, through `SourceSweep`, because all of this lives inside view
/// bodies and none of it is reachable from a unit test through the app's own API.
///
/// **Each suite holds both halves**, which is `docs/screen-audit.md`'s rule for
/// its own gates. A test that only checks a thing is gone would also pass if
/// somebody deleted the thing that stays, and a sweep that cannot fail is worse
/// than no sweep at all, so every one of these has an injection beside it that
/// proves the matcher catches what it is for.
@Suite("Consistency, 2026-10-01")
struct ConsistencyTests {

    // MARK: - One category picker

    /// §1.1, which is the owner's own instance: "I see the colour on the plan
    /// isnt the same as the wins edit sheet with the icons and stuff."
    ///
    /// The add sheet and the plan line each built a row of category swatches, and
    /// the two differed on four axes at once — circle against rounded square,
    /// glyph against none, ring against checkmark, `ColourSwatch` against a
    /// private `BlockSurface`. There is one row now and both sheets call it.
    ///
    /// The sweep is for the SHAPE of the fault rather than for the old code:
    /// anything that walks `HabitCategory.selectable` to draw a picker is a
    /// category picker, so only the component is allowed to do it.
    @Test("only ColourSwatchRow walks the categories to build a picker")
    func onlyOneCategoryPicker() throws {
        let offenders = try ConsistencySweep.views()
            .filter { $0.path != "Strata/Views/ColourSwatch.swift" }
            .filter { SourceSweep.code($0.text).contains("ForEach(HabitCategory.selectable") }
            .map(\.path)
        // **Profile's background chooser is the written exemption**, and it is a
        // different question rather than a third copy: its row offers "no colour"
        // as a seventh option, which `HabitCategory` has no case for, and it names
        // colours ("Green", "Blue") where this names categories. It already wears
        // the same 0.55 ink ring, which is the part that had to agree. Moving it
        // onto the component means the component grows an optional colour and a
        // second naming scheme, which is a bigger change than the drift.
        #expect(offenders == ["Strata/Views/ProfileView.swift"],
                "a category picker was rebuilt outside ColourSwatchRow: \(offenders)")
    }

    /// Both sheets reach the row, which is the half a "nothing else draws it"
    /// test cannot see. If `AddWinSheet` dropped its colour row entirely the test
    /// above would still pass.
    @Test("both sheets draw the shared row")
    func bothSheetsDrawTheSharedRow() throws {
        for path in ["Strata/Views/AddWinSheet.swift",
                     "Strata/Views/PlanItemDetailSheet.swift"] {
            let code = SourceSweep.code(try SourceSweep.read(path))
            #expect(code.contains("ColourSwatchRow("), "\(path) stopped using the shared row")
        }
    }

    /// The injection. These are the two spellings the private copies actually
    /// had, so a sweep that passes them is a sweep that would have passed the
    /// fault it was written for.
    @Test("the picker sweep catches what it is for")
    func pickerSweepCatchesWhatItIsFor() {
        let bad = [
            "            ForEach(HabitCategory.selectable, id: \\.self) { category in",
            "        ForEach(HabitCategory.selectable, id: \\.self) { cat in",
        ]
        for line in bad {
            #expect(SourceSweep.code(line).contains("ForEach(HabitCategory.selectable"),
                    "the sweep let this through: \(line)")
        }
        // A mention in a comment is not a picker. `CopyCutsTests` records why
        // this distinction has to be tested: these files argue in prose.
        let good = "    /// ForEach(HabitCategory.selectable) is what this replaced."
        #expect(!SourceSweep.code(good).contains("ForEach(HabitCategory.selectable"),
                "the sweep read a comment as code")
    }

    // MARK: - The plan line's delete

    /// §1.5. It deleted the line, committed and dismissed on ONE press, from
    /// `ToolbarItem(placement: .topBarLeading)` — the slot `AddWinSheet` gives to
    /// Cancel and `PlanSheet`, directly behind it, gives to ＋. Four of the app's
    /// six deletes confirm; this was one of the two that did not.
    ///
    /// The placement is the half that is not arguable, so both halves are pinned:
    /// the leading slot is empty, and the press asks first.
    @Test("the plan line's delete confirms, and is not in the leading slot")
    func planLineDeleteConfirms() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanItemDetailSheet.swift"))
        #expect(!code.contains("topBarLeading"),
                "something is back in the slot a thumb has learned means 'back out of this'")
        #expect(code.contains("confirmationDialog"),
                "the plan line deletes without asking")
        // The confirmation has to be ON the delete rather than anywhere on the
        // sheet, which is the thing a `contains` cannot see on its own: the
        // dialog's own destructive button is what commits.
        #expect(code.contains("Button(\"Delete Line\", role: .destructive)"),
                "the dialog no longer carries the delete")
    }

    /// And it still deletes. A sheet that lost the control entirely would pass
    /// every assertion above.
    @Test("the plan line can still be deleted")
    func planLineCanStillBeDeleted() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanItemDetailSheet.swift"))
        #expect(code.contains("modelContext.delete(item)"), "the delete is gone, not moved")
        #expect(code.contains("StoreReset.commitDelete"),
                "the delete stopped going through the one commit path")
    }

    // MARK: - The sheet title row

    /// §1.4 and §3.4: eight sheets, six shapes, "Done" in two inks, and three of
    /// six word buttons under 44pt. One modifier holds the tier, the ink and the
    /// box, so a sheet cannot be written without them.
    ///
    /// The sweep is the confirm and cancel WORDS, because those are what drifted.
    @Test("every sheet's confirm and cancel word goes through sheetAction")
    func sheetWordsGoThroughTheModifier() throws {
        var offenders: [String] = []
        for file in try ConsistencySweep.views() {
            let lines = file.text.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, raw) in lines.enumerated() {
                let line = String(raw)
                guard !SourceSweep.isComment(line) else { continue }
                guard ConsistencySweep.sheetWords.contains(where: { line.contains("Text(\"\($0)\")") })
                else { continue }
                // The modifier may sit on the same line or on the next, which is
                // how a long label is wrapped.
                let window = lines[i...min(i + 2, lines.count - 1)].joined(separator: "\n")
                if !window.contains(".sheetAction") {
                    offenders.append("\(file.path):\(i + 1)  \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(offenders.isEmpty,
                "a sheet action is drawing its own ink, tier or box:\n\(offenders.joined(separator: "\n"))")
    }

    /// The injection: the exact line each of the three unfixed sheets carried,
    /// and the fixed form beside it.
    @Test("the sheet-action sweep catches what it is for")
    func sheetActionSweepCatchesWhatItIsFor() {
        let bad = [
            #"            Text("Done").font(Typography.headerSmall)"#,
            #"            Text("Cancel").font(Typography.headerSmall)"#,
            #"                Text("Done")"#,
        ]
        for line in bad {
            #expect(ConsistencySweep.looksLikeABareSheetWord(line),
                    "the sweep let this through: \(line)")
        }
        let good = [
            #"            Text("Done").sheetAction()"#,
            #"                .sheetAction(isFinished ? .confirm : .cancel)"#,
            #"    /// Text("Done") used to be a bare Text here."#,
        ]
        for line in good {
            #expect(!ConsistencySweep.looksLikeABareSheetWord(line),
                    "the sweep flagged a fixed line: \(line)")
        }
    }

    // MARK: - The press

    /// §1.8: **`PressResponse.press` had zero call sites**, and the controls its
    /// own doc names by name — "the grid, the flash, the flip and the timer, and
    /// the size chips beside the shutter" — were all still `.plain`. The app was
    /// 25 `.plain` against 8 press styles.
    @Test("the base press style has call sites")
    func thePressStyleIsUsed() throws {
        let uses = try ConsistencySweep.views()
            .filter { SourceSweep.code($0.text).contains(".buttonStyle(.press)") }
        #expect(uses.count >= 3,
                "PressResponse.press is back to being a style nobody calls: \(uses.map(\.path))")
    }

    /// And the other half: a `.plain` button is only correct when its label is
    /// already Liquid Glass, which responds on its own, or is the shutter, which
    /// hand-rolls its press.
    ///
    /// **An allowlist with a count, not a pattern**, which is how this codebase
    /// writes an exemption: the file is named, the reason is written down, and the
    /// number is what it was when it was checked. The count may go DOWN — another
    /// worker converting one of these must not fail this test — and may not go up,
    /// which is what catches a new plain button being added to a file that already
    /// has a legitimate one.
    @Test("no control is left without a press answer")
    func everyPlainButtonIsGlass() throws {
        var offenders: [String] = []
        for file in try ConsistencySweep.views() {
            let found = SourceSweep.code(file.text)
                .components(separatedBy: ".buttonStyle(.plain)").count - 1
            let allowed = ConsistencySweep.glassBacked[file.path] ?? 0
            if found > allowed {
                offenders.append("\(file.path): \(found) plain buttons, \(allowed) of them accounted for")
            }
        }
        #expect(offenders.isEmpty,
                "a control was left with no answer to a finger:\n\(offenders.joined(separator: "\n"))")
    }
}

/// The sweep's own vocabulary, kept out of the suite so the injections above can
/// drive exactly what the tests drive.
enum ConsistencySweep {

    /// Every view file, as `(path, text)`.
    static func views() throws -> [(path: String, text: String)] {
        try SourceSweep.sources()
            .filter { $0.0.hasPrefix("Strata/Views/") }
            .map { (path: $0.0, text: $0.1) }
    }

    /// The words a sheet's title row says. Not "Delete": that is a destructive
    /// action and wears the destructive shape, which is a different question
    /// (§3.3) with its own answer.
    static let sheetWords = ["Done", "Cancel", "Save", "Add"]

    /// One line, judged the way the sweep judges it.
    static func looksLikeABareSheetWord(_ line: String) -> Bool {
        guard !SourceSweep.isComment(line) else { return false }
        guard sheetWords.contains(where: { line.contains("Text(\"\($0)\")") }) else { return false }
        return !line.contains(".sheetAction")
    }

    /// **The `.plain` buttons that are correct, with the reason for each**, and
    /// the count as of 2026-10-01. A `.plain` label that is already Liquid Glass
    /// answers the press itself: `.interactive()` is on `glassCircle`,
    /// `glassCapsule` and `photoOverlay`, which is why `PressResponse`'s own doc
    /// says those three were never the problem.
    static let glassBacked: [String: Int] = [
        // The zoom pill, which is `glassCapsule()`.
        "Strata/Views/CameraView.swift": 1,
        // The component itself: its label IS `GlassIconLabel`.
        "Strata/Views/GlassIconButton.swift": 1,
        // The shutter, which hand-rolls its own press — the one control somebody
        // presses most, and the reason `PressResponse` says a press was always
        // ANSWERED on that screen.
        "Strata/Views/HeadMakerView.swift": 1,
        // The review's head sticker, on `glassCircle()`.
        "Strata/Views/HeadSticker.swift": 1,
        // The viewer's close, which is a `GlassIconButton`.
        "Strata/Views/PhotoViewer.swift": 1,
        // The header's profile picture, built on `GlassIconButton`'s skeleton and
        // drawn on `glassCircle()`.
        "Strata/Views/ProfileAvatar.swift": 1,
        // Save Video and Share, both `CapsuleControlLabel`, which is
        // `glassCapsule()`.
        "Strata/Views/ReplayView.swift": 2,
        // The reactions face and the Reply/Doodle chips, both `glassCapsule()`.
        // A scaling press on interactive glass cancelled taps on a real phone
        // (the owner, 2026-10-05). `MemoriesConsistencyTests` already exempts
        // this file for that reason (91c5ae5); this twin allowlist was never
        // told, and failed on main before the chat work.
        "Strata/Views/Crews/CrewReactions.swift": 2,
    ]
}
