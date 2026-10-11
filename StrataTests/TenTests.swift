import Foundation
import Testing
@testable import Strata

/// **What a 10 is, held** (`docs/ten.md`; the owner, 2026-10-11: "be very
/// specific what we define as a 10. The usability consistency needs to be a
/// 10"). Each test here is one of the nine rules at a place it was broken.
@MainActor
@Suite("What a 10 is")
struct TenTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }

    @Test("rule 1: a sheet's Cancel and Done are bare words on every sheet")
    func bareWords() throws {
        for path in ["Strata/Views/Crews/CrewInfoSheet.swift", "Strata/Views/YourDaySheet.swift",
                     "Strata/Views/YourThreePicker.swift"] {
            let text = try code(path)
            #expect(text.contains("BareToolbarItem(placement: .topBarTrailing)"), "\(path) puts Done in the system's glass")
            #expect(!text.contains("ToolbarItem(placement: .confirmationAction)"), "\(path)")
        }
        let crews = try code("Strata/Views/Crews/CrewsListView.swift")
        #expect(crews.contains("BareToolbarItem(placement: .topBarLeading)"))
        #expect(!crews.contains("ToolbarItem(placement: .cancellationAction)"))
    }

    @Test("rule 1: the quiet second word, the news dot and the weekday chip are each drawn once")
    func drawnOnce() throws {
        #expect(try code("Strata/Views/Crews/CrewRules.swift").contains("QuietWord(\"Not Now\", fills: true)"))
        #expect(try code("Strata/Views/TipJarViews.swift").contains("QuietWord(TipJar.Copy.notNow)"))
        #expect(try code("Strata/Views/OnboardingFilm.swift").contains("QuietWord(\"Skip\""))
        let list = try code("Strata/Views/Crews/CrewsListView.swift")
        #expect(list.components(separatedBy: "NewsDot(").count - 1 == 2)
        #expect(try code("Strata/Views/Crews/CrewTowerView.swift").contains("NewsDot()"))
        #expect(NewsDot.side == 9)
        #expect(try code("Strata/Views/PlanSuggestionsView.swift").contains("PlanBullet(category: .unlabeled, isDone: false)"))
    }

    @Test("rule 3: what cannot be brought back asks, and what can offers Undo")
    func asksOrUndoes() throws {
        let lines = try code("Strata/Views/PlanLines.swift")
        #expect(lines.contains("UndoLine.shared.show(\"Line deleted\""), "a swiped line is gone with no way back")
        #expect(try code("Strata/Views/DaySheet.swift").contains(".undoLine()"), "the plan has nowhere to show Undo")
        let main = try code("Strata/Views/MainAppView.swift")
        let crewSlot = try #require(main.components(separatedBy: "private func logCrewWin").dropFirst().first?
            .components(separatedBy: "private func logWin").first)
        #expect(crewSlot.contains("UndoLine.shared.show(\"Win added\""), "a win drawn out of a crew's slot cannot be taken back")
        #expect(crewSlot.contains("winSaveFailed = true"), "and a failure there says nothing")
        #expect(try code("Strata/Views/Ink/InkCanvas.swift").contains("if hasWork { asking = true } else { onCancel() }"))
        for path in ["Strata/Views/Ink/BlockDoodleSheet.swift", "Strata/Views/Ink/JournalSketchEditor.swift",
                     "Strata/Views/Ink/MonthDrawingEditor.swift", "Strata/Views/Strip/StripEditor.swift",
                     "Strata/Views/Crews/DoodleSheet.swift"] {
            #expect(try code(path).contains("hasWork: ink.canUndo"), "\(path): Cancel throws a drawing away unasked")
        }
        let viewer = try code("Strata/Views/PhotoViewer.swift")
        #expect(!viewer.contains("{ onWithdraw(current); onClose() } label:"), "a win leaves a crew at one press")
        #expect(viewer.contains("Remove this win from the crew?"))
        #expect(try code("Strata/Views/MemoriesView.swift").contains("Use the original drawing?"))
        #expect(try code("Strata/Views/DaySheet.swift").contains("Remove this sketch?"))
    }

    @Test("rule 3: your three are kept however the sheet closes")
    func threeAreKept() throws {
        let picker = try code("Strata/Views/YourThreePicker.swift")
        #expect(picker.contains(".onChange(of: chosen.map(\\.id)) { _, _ in onDone(chosen) }"))
    }

    @Test("rule 4: one word per thing, and buttons in Title Case")
    func oneWord() throws {
        let onboarding = try code("Strata/Views/OnboardingView.swift")
        for old in ["\"What else\"", "\"Go on\"", "\"Turn on places\"", "\"Make my head\"", "\"Set my goal\"",
                    "\"One more thing\"", "\"Not now\""] {
            #expect(!onboarding.contains(old), "\(old) is a button in sentence case")
        }
        // A photo is a photo, in every sentence a person reads.
        for path in ["Strata/Views/PhotoViewer.swift", "Strata/Views/PhotoCollectionView.swift",
                     "Strata/Views/SettingsView.swift", "Strata/Views/CameraView.swift"] {
            // The noun, in a line that is not a log ("what you photograph",
            // the verb, stays).
            let said = try code(path).components(separatedBy: "\n").filter { line in
                !line.contains("NSLog") && ["a photograph", "the photograph", "photographs", "photograph\\("].contains { line.contains($0) }
            }
            #expect(said.isEmpty, "\(path) says photograph to a person: \(said)")
        }
        // "Line" is the plan's word; the month drawing has words under it.
        let memories = try code("Strata/Views/MemoriesView.swift")
        #expect(!memories.contains("\"Change Line\"") && memories.contains("\"Change Words\""))
        // One sheet, one name for the way into it.
        #expect(!(try code("Strata/Views/PlanLines.swift")).contains("Label(\"Options\""))
        #expect(CrewStats.streakLine(people: 3, waiting: 3).contains("sends a win"))
    }

    @Test("rule 5: an open gives a light tap, a choice gives a tick")
    func haptics() throws {
        #expect(try code("Strata/Views/YourThreePicker.swift").contains("HapticsEngine.tick()"))
        #expect(try code("Strata/Views/Crews/MakeYourHead.swift").contains("HapticsEngine.lightTap()"))
        #expect(try code("Strata/Views/Crews/CrewsListView.swift").contains("Button { HapticsEngine.lightTap(); open(crew.id) }"))
    }

    @Test("rule 8: a save to Photos that did not happen says so, in one way")
    func savesSaySo() throws {
        for path in ["Strata/Views/PhotoViewer.swift", "Strata/Views/Strip/StripBooth.swift",
                     "Strata/Views/Strip/StripStory.swift"] {
            let text = try code(path)
            #expect(text.contains("saveFailed = true") && text.contains(".photoSaveFailed($saveFailed)"),
                    "\(path) fails to save in silence")
        }
    }

    @Test("rule 9: a hold's actions have names for VoiceOver, and a chosen thing says it is chosen")
    func named() throws {
        #expect(try code("Strata/Views/PlanLines.swift").contains("Button(\"Put Back on Today\")"))
        #expect(try code("Strata/Views/Crews/CrewTowerView.swift").contains("Button(\"Let Everyone Out\") { parking.releaseAll() }"))
        #expect(try code("Strata/Views/Strip/StripEditor.swift").contains(".accessibilityAddTraits(on ? [.isSelected] : [])"))
        #expect(try code("Strata/Views/StickerPicker.swift").contains("[.isSelected]"))
    }
}
