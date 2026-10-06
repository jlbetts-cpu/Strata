import Testing
import Foundation
import UserNotifications
@testable import Strata

/// What the owner picked from the 2026-10-06 quality-of-life research:
/// Undo instead of "Delete this?", logging from the reminder, back to the
/// plan after a line's win, and quieter crew alerts.
@Suite("The owner's picks, 2026-10-06")
struct OwnerPicksOctoberSixTests {
    private func code(_ path: String) throws -> String {
        SourceSweep.code(try SourceSweep.read(path))
    }

    @Test("a delete happens at once and offers Undo; the dialog is gone")
    func deleteOffersUndo() throws {
        let sheet = try code("Strata/Views/AddWinSheet.swift")
        #expect(!sheet.contains("Delete this?"), "the confirm came back in front of Undo")
        #expect(sheet.contains("WinDeletion.delete(habit, in: modelContext)"))
        #expect(sheet.contains("UndoLine.shared.show(\"Win deleted\""))
        let main = try code("Strata/Views/MainAppView.swift")
        #expect(main.contains("UndoLine.shared.show(\"Win added\""), "a win drawn from the slot cannot be taken back")
        #expect(main.contains("towerTabRoot.undoLine()"))
        #expect(main.contains("memoriesTabRoot.undoLine()"))
    }

    @MainActor
    @Test("the line runs its undo, or its expiry, never both")
    func undoOrExpire() {
        let line = UndoLine()
        var undone = 0, expired = 0
        line.show("Win deleted", undo: { undone += 1 }, expire: { expired += 1 })
        line.undo()
        #expect(undone == 1 && expired == 0)
        line.show("Win deleted", undo: { undone += 1 }, expire: { expired += 1 })
        // A second line finishes the first, so its photographs still go.
        line.show("Win added", undo: {}, expire: {})
        #expect(expired == 1 && undone == 1)
        line.finish()
        #expect(line.line == nil)
    }

    @Test("the reminder carries Quick, Regular and Deep, and they log without opening")
    func reminderLogs() throws {
        let category = DailyReminder.notificationCategory
        #expect(category.identifier == DailyReminder.category)
        #expect(category.actions.map(\.title) == ["Quick", "Regular", "Deep"])
        #expect(category.actions.allSatisfy { !$0.options.contains(.foreground) },
                "an action opens the app; the point is that it does not")
        #expect(Set(category.actions.map(\.identifier)) == Set(DailyReminder.actions.keys))
        let reminder = try code("Strata/Services/DailyReminder.swift")
        #expect(reminder.contains("content.categoryIdentifier = category"))
        let delegate = try code("Strata/Social/StrataAppDelegate.swift")
        #expect(delegate.contains("setNotificationCategories([DailyReminder.notificationCategory])"))
        #expect(delegate.contains("DailyReminder.actions[response.actionIdentifier]"))
    }

    @Test("a plan line's win goes back to the plan")
    func backToThePlan() throws {
        let main = try code("Strata/Views/MainAppView.swift")
        #expect(main.contains("returnsToPlan = true"))
        #expect(main.contains("dayOpeningTab = .plan"))
    }

    @Test("a friend's win arrives quietly; what is addressed to you still alerts")
    func quietCrewWins() {
        let win = UNMutableNotificationContent()
        CrewAlertLevel.apply(to: win, kind: .win, tagsMe: false)
        #expect(win.interruptionLevel == .passive)
        #expect(win.sound == nil)
        let tagged = UNMutableNotificationContent()
        CrewAlertLevel.apply(to: tagged, kind: .win, tagsMe: true)
        #expect(tagged.interruptionLevel == .active)
        #expect(tagged.sound != nil)
        let reaction = UNMutableNotificationContent()
        CrewAlertLevel.apply(to: reaction, kind: .reaction, tagsMe: false)
        #expect(reaction.interruptionLevel == .active)
        #expect(reaction.relevanceScore > win.relevanceScore)
    }

    @Test("the extension and the app both set the level")
    func bothPathsQuiet() throws {
        #expect(try code("SomeWinsNotifications/NotificationService.swift").contains("CrewAlertLevel.apply("))
        #expect(try code("Strata/Social/CrewNotifications.swift").contains("CrewAlertLevel.apply("))
    }

    @Test("who it was with is one tag button, not a row between the crews and the photos")
    func withIsATagButton() throws {
        let sheet = try code("Strata/Views/AddWinSheet.swift")
        #expect(sheet.contains("CrewWithRow(crews: crewChoice, selection: $withPeople, stacked: true)"))
        #expect(!sheet.contains("CrewWithRow(crews: crewChoice, selection: $withPeople)\n"),
                "the With row is back on the page (the owner, 2026-10-06)")
        #expect(sheet.contains(".popover(isPresented: $tagging)"))
        // The strip's own scroll is not moved by the keyboard: it drew the
        // block 40pt above its frame, over the crew names, and took their taps.
        #expect(sheet.contains(".ignoresSafeArea(.keyboard)"))
    }
}
