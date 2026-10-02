import Foundation
import SwiftData
import Testing
@testable import Strata

/// **The second Wins-side pass, 2026-10-02, pinned.**
///
/// Three fixes from `docs/design-review/wins.md` and `add-a-win.md`, each held
/// with an injection that proves the matcher would have caught the old code.
@Suite("Wins side, second pass, 2026-10-02")
struct WinsSideSecondPassTests {

    // MARK: - The empty state's sentence stands on the slot

    /// It was a page overlay at y144 with the slot at y694: 533pt between an
    /// instruction and the thing it names. It hangs off the slot now, and it
    /// leaves when the press commits, before the first block falls through
    /// the space it occupied.
    static func sentenceSitsOnTheSlot(_ code: String) -> Bool {
        guard let slot = code.range(of: "private func emptyTowerSlot("),
              let next = code.range(of: "private var towerEmptyStateMessage",
                                    range: slot.upperBound..<code.endIndex)
        else { return false }
        let body = code[slot.upperBound..<next.lowerBound]
        // Used inside the slot, gated on the cascade, and nowhere else.
        return body.contains("towerEmptyStateMessage")
            && body.contains("!animCoord.isCascading")
            && code.components(separatedBy: "towerEmptyStateMessage").count == 3
    }

    @Test("the empty tower's sentence is hung on the slot, and leaves on the press")
    func emptyStateOnTheSlot() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(Self.sentenceSitsOnTheSlot(code))
    }

    @Test("the slot matcher catches the page overlay it replaced")
    func emptyStateMatcherCatches() {
        let old = """
            private func emptyTowerSlot(colW: CGFloat, gridH: CGFloat) -> some View {
                NextSlotButton()
            }
                            .overlay(alignment: .top) {
                                if !towerVM.isLoading && towerVM.totalRows == 0 {
                                    towerEmptyStateMessage
                                }
                            }
            private var towerEmptyStateMessage: some View { Text("") }
            """
        #expect(!Self.sentenceSitsOnTheSlot(old))
        let ungated = """
            private func emptyTowerSlot(colW: CGFloat) -> some View {
                NextSlotButton().overlay { towerEmptyStateMessage }
            }
            private var towerEmptyStateMessage: some View { Text("") }
            """
        #expect(!Self.sentenceSitsOnTheSlot(ungated), "a sentence that stays up while the first block falls through it")
    }

    // MARK: - The keyboard is the floor

    /// The block arrived with its bottom 19.7pt under the keyboard on every
    /// fresh Add: a `gapPage` floor drawn behind the keys plus a `gapPage`
    /// spacer at its minimum. Both ends take `gapWide` while the name has
    /// focus. Arithmetic off the built sheet at 402x874, keyboard top y540:
    /// the size control ends at y314.7, the Quick well is 181pt.
    ///
    /// **Re-derived 2026-10-02**, when the sheet stopped flooring the block
    /// (the owner: "why is the spacing that spaced out"). The name to the
    /// controls went 64 to `gapSection`, so the controls end 32pt higher, and
    /// the block follows them at `gapSection` with no spacer at all.
    @Test("a fresh Add's block clears the keyboard")
    func blockClearsTheKeyboard() throws {
        let controlsEnd: CGFloat = 314.7 - (GridConstants.gapPage - GridConstants.gapSection)
        let keyboardTop: CGFloat = 540
        let well: CGFloat = (402 - GridConstants.horizontalPadding * 2 - GridConstants.spacing) / 2
        let bottom = controlsEnd + GridConstants.gapSection + well
        #expect(bottom < keyboardTop - GridConstants.gapWide,
                "the block's bottom is at \(bottom), within \(GridConstants.gapWide) of the keyboard at \(keyboardTop)")

        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        #expect(!code.contains("Spacer(minLength: titleFocused"), "the floored block came back")
        #expect(code.contains(".padding(.top, GridConstants.gapSection)"))
    }

    // MARK: - A failed save says so

    @Test("each failure has one short sentence in the app's voice")
    func failureCopy() {
        let all: [AddWinFailure] = [.win, .photo, .removal]
        for f in all {
            #expect(!SourceSweep.longDash(f.message), "a long dash in \(f.message)")
            #expect(f.message.count <= 46, "\(f.message) is \(f.message.count) characters: one line at 15pt is the budget")
            #expect(f.message.hasPrefix("Couldn't"))
            for word in ["watch", "track", "we ", "sorry", "error"] {
                #expect(!f.message.lowercased().contains(word), "\(f.message) says \(word)")
            }
        }
    }

    /// The verb changes with what the press will do, and Cancel stops being
    /// offered once the win is saved, because closing then keeps it.
    @Test("the bar's words change with what each press will do")
    func failureWords() {
        #expect(AddWinFailure.win.retry == "Try Again")
        #expect(AddWinFailure.win.dismissal == "Cancel")
        #expect(!AddWinFailure.win.winIsSaved)
        for f in [AddWinFailure.photo, .removal] {
            #expect(f.winIsSaved)
            #expect(f.dismissal == "Done", "Cancel cannot undo a win that is already saved")
        }
    }

    /// The silent paths, by name: a `catch` that only cleared `isSaving`, a
    /// `try?` on the edit save, and a `try?` on the photograph's write.
    /// Whitespace is collapsed on both sides, so indentation cannot hide one.
    static func silentFailures(_ code: String) -> [String] {
        func flat(_ text: String) -> String {
            text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).joined(separator: " ")
        }
        let patterns = [
            "catch { isSaving = false }",
            "try? modelContext.save()",
            "try? await ImageManager.shared.save(",
        ]
        let body = flat(code)
        return patterns.filter { body.contains($0) }
    }

    @Test("no save or photo write on the add sheet fails in silence")
    func noSilentFailures() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        #expect(Self.silentFailures(code).isEmpty, "silent: \(Self.silentFailures(code))")
        #expect(code.contains("fail(.win)"))
        #expect(code.contains("fail(.photo)"))
        #expect(code.contains("AccessibilityNotification.Announcement(now.message)"))
    }

    @Test("the silence matcher catches the code it replaced")
    func silenceMatcherCatches() {
        let old = """
                    HapticsEngine.success()
                    onSaved(win.habit)
                    dismiss()
                } catch {
                    isSaving = false
                }
            """
        #expect(Self.silentFailures(old).count == 1)
        #expect(Self.silentFailures("        if let name = try? await ImageManager.shared.save(image: image, for: id) {").count == 1)
        #expect(Self.silentFailures("            try? modelContext.save()").count == 1)
    }

    // MARK: - Try Again cannot make two wins

    /// `logWin` inserts, then saves. If the save throws, its habit and log stay
    /// in the context, and a retry would insert a second pair that the next
    /// save writes with the first. The sheet takes back what the failed press
    /// inserted, by the same mechanism this exercises: everything inserted
    /// since a snapshot, deleted before it was ever saved.
    @MainActor
    @Test("taking back a failed press's inserts leaves one win after the retry")
    func failedInsertIsTakenBack() throws {
        let container = try ModelContainer(
            for: Habit.self, HabitLog.self, Tower.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.autosaveEnabled = false

        // The failed press: inserted, never saved.
        let pending = Set(context.insertedModelsArray.map(\.persistentModelID))
        let habit = Habit(title: "Ran", category: .health)
        context.insert(habit)
        for model in context.insertedModelsArray where !pending.contains(model.persistentModelID) {
            context.delete(model)
        }

        // The retry.
        _ = try QuickWinService.logWin(title: "Ran", category: .health, context: context, tower: nil)
        let habits = try context.fetch(FetchDescriptor<Habit>())
        #expect(habits.count == 1, "the retry wrote \(habits.count) wins")
    }
}
