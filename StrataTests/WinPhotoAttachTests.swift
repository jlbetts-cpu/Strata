import Testing
import Foundation
import SwiftData
@testable import Strata

/// **Where a photograph is put, and whether it can be found again.**
///
/// From a phone: "my photos I take dont go on the blocks or stay on the blocks
/// in any screen." The attach path hangs on one lookup — the log the service
/// just wrote, found again through `habit.logs` — and if that lookup comes back
/// empty the photograph is dropped with no error anywhere. `QuickWinService`
/// already carries a comment saying that lookup "intermittently came back
/// empty". These pin it down.
@MainActor
@Suite("WinPhotoAttach")
struct WinPhotoAttachTests {

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Habit.self, HabitLog.self, Tower.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test("the log a win just wrote can be found through its habit")
    func logIsReachableFromHabit() throws {
        let context = try context()
        let win = try QuickWinService.logWin(title: "Ran", category: .health,
                                             context: context, tower: nil)
        let found = win.habit.logs.first { $0.id == win.logID }
        #expect(found != nil, "the log is not on the habit, so the photograph would be dropped")
    }

    /// The same question asked of the store rather than of the relationship,
    /// which is the lookup a photograph can safely depend on.
    @Test("the log a win just wrote can be fetched by its id")
    func logIsFetchableByID() throws {
        let context = try context()
        let win = try QuickWinService.logWin(title: "Ran", category: .health,
                                             context: context, tower: nil)
        let id = win.logID
        let logs = try context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.id == id }))
        #expect(logs.count == 1)
    }

    @Test("a file name written on a log survives a save and a refetch")
    func fileNameSticks() throws {
        let context = try context()
        let win = try QuickWinService.logWin(title: "Ran", category: .health,
                                             context: context, tower: nil)
        let id = win.logID
        guard let log = try context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.id == id })).first else {
            Issue.record("no log to attach to")
            return
        }
        log.imageFileName = "test.heic"
        try context.save()
        let after = try context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.imageFileName != nil }))
        #expect(after.count == 1, "the file name did not survive the save")
    }
}
