import Foundation
import Testing
@testable import Strata

/// **One way into Add a Win** (the owner, 2026-10-18: "Route every one of them
/// through ONE single function that opens the new camera-first sheet ...
/// Delete the old Add a Win sheet and anything that can still present it").
/// Each assertion fails the day a second way in, or the old sheet, comes back.
@Suite("One way into Add a Win, 2026-10-18")
struct AddWinOneWayTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    @Test("only presentAddWin opens the card")
    func oneWayIn() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        let sets = main.components(separatedBy: "inlineOpening = ").count - 1
        let clears = main.components(separatedBy: "inlineOpening = nil").count - 1
        // One assignment that opens it, in presentAddWin; the rest put it away.
        #expect(sets - clears == 1, "a second place opens the card: \(sets - clears)")
        #expect(main.contains("withTransaction(Self.still) { inlineOpening = opening }"))
        // The other screens ask through the router, which comes here.
        #expect(main.contains("guard id != nil, let request = AddWinRouter.shared.take() else { return }\n            presentAddWin(request)"))
        // Never a fallback to a sheet when a card is up.
        #expect(main.contains("guard inlineOpening == nil else { return }"))
    }

    @Test("the old sheet is gone: no draft, and the edit sheet needs a win")
    func oldSheetGone() throws {
        #expect((try? SourceSweep.read("Strata/Models/WinDraft.swift")) == nil, "WinDraft is back")
        #expect((try? SourceSweep.read("Strata/Views/AddWinSheet.swift")) == nil, "AddWinSheet is back")
        let edit = try code("Strata/Views/EditWinSheet.swift")
        #expect(edit.contains("    let win: Habit\n"), "the edit sheet can be opened with no win to edit")
        for gone in ["var initialPhoto", "var initialTitle", "var initialCrews", "var onPlan", "var opensDrawing"] {
            #expect(!edit.contains(gone), "\(gone) can be passed in again: the sheet adds wins again")
        }
        for path in ["Strata/Views/Crews/CrewChatSheet.swift", "Strata/Views/PlannedBlocks.swift"] {
            #expect(!(try code(path)).contains("EditWinSheet("), "\(path) opens a sheet to add a win")
        }
    }

    // The injection: a second opening is counted.
    @Test("the count can fail")
    func injection() {
        let bad = "inlineOpening = opening\n inlineOpening = AddWinOpening(from: .zero)\n inlineOpening = nil"
        let sets = bad.components(separatedBy: "inlineOpening = ").count - 1
        let clears = bad.components(separatedBy: "inlineOpening = nil").count - 1
        #expect(sets - clears == 2)
    }
}
