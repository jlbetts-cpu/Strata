import Testing
import Foundation
import SwiftData
@testable import Strata

/// **The crew chat's bar on the Plan and the Journal** (the owner,
/// 2026-10-06: "i really like the crew chat like chat section and I think we
/// should use some of the design for the plan and journal tab"; his pick,
/// "Composer for both").
@MainActor
@Suite("Day sheet: the chat's bar on the Plan and the Journal")
struct DayComposerTests {
    @Test("a sent paragraph joins the note, and the note is never rewritten")
    func journalAppends() {
        #expect(DayComposing.appending("Lunch with Ana.", to: "") == "Lunch with Ana.")
        #expect(DayComposing.appending("Lunch with Ana.", to: "Ran by the river.")
                == "Ran by the river.\n\nLunch with Ana.")
        // Trailing space or lines on the note do not pile up between paragraphs.
        #expect(DayComposing.appending("  Lunch.  ", to: "Ran.\n\n\n ") == "Ran.\n\nLunch.")
        #expect(DayComposing.appending("   ", to: "Ran.") == "Ran.", "an empty send changed the note")
    }

    @Test("a sent plan line lands at the end of the plan, trimmed, in a colour")
    func planAddsAtTheEnd() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let first = PlanItem(text: "Run the loop", order: 0)
        let second = PlanItem(text: "Send the invoice", order: 4)
        context.insert(first); context.insert(second)
        let line = try #require(DayComposing.addPlanLine("  Water the plants ", after: [first, second],
                                                         habits: [], context: context))
        #expect(line.text == "Water the plants")
        #expect(line.order == 5, "the line did not go last")
        #expect(DayComposing.addPlanLine(" \n", after: [first, second, line], habits: [], context: context) == nil)
    }

    @Test("the bar is the chat's: page glass, the 44pt floor, the glass ↑")
    func barIsTheChats() throws {
        let bar = SourceSweep.code(try SourceSweep.read("Strata/Views/DayComposer.swift"))
        #expect(bar.contains(".glassCapsule(onPage: true, interactive: false)"))
        #expect(bar.contains(".frame(minHeight: GlassIconButton.defaultSide)"))
        #expect(bar.contains("GlassIconButton(systemName: \"arrow.up\""))
        #expect(bar.contains(".disabled(!canSend)"))
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(sheet.contains("placeholder: \"Add to the plan\""))
        #expect(sheet.contains("isToday ? \"Write about today\" : \"Write about that day\""))
    }

    /// Return on the Plan's bar hands over the field's own words and empties
    /// it in the same keystroke. Through the binding, typing fast sent the old
    /// line again ("Water the plants" three times) and ran new words onto the
    /// old ("Water the plantsT"), both seen on the simulator.
    @Test("the Plan's Return sends the field's own words, not the binding's")
    func planReturnReadsTheField() throws {
        let field = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanTextField.swift"))
        let shouldReturn = try #require(field.components(separatedBy: "func textFieldShouldReturn").dropFirst().first)
        let body = shouldReturn.components(separatedBy: "func textFieldDidBeginEditing").first ?? ""
        #expect(body.contains("let words = field.text"))
        #expect(body.contains("field.text = \"\""))
        #expect(body.contains("onSend(words)"))
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(sheet.contains("onSend: sendPlanLine)"))
    }

    /// The owner, 2026-10-06: "I think the suggest should only pop up when
    /// the keyboard does looks a little off above it". At rest the bar
    /// stands alone; Suggest appears over it while a field has the keyboard.
    @Test("Suggest shows only while the keyboard is up, on both tabs")
    func suggestOnlyWithTheKeyboard() throws {
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(sheet.contains("offersWord: planFocus != nil)"))
        #expect(sheet.contains("if writing || journalComposing {\n                journalSuggest"))
        let plan = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanSuggestionsView.swift"))
        #expect(plan.contains("if offersWord {"))
        // Suggestions already asked for stay when the keyboard goes down:
        // only the idle word is gated.
        let showing = try #require(plan.components(separatedBy: "case .showing").dropFirst().first)
        #expect(!(showing.components(separatedBy: "case .failed").first ?? "").contains("offersWord"))
        // A plan field that loses the keyboard says so, or the word stays.
        let field = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanTextField.swift"))
        #expect(field.contains("func textFieldDidEndEditing"))
    }
}
