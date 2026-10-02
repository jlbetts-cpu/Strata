import Testing
import Foundation
import SwiftData
@testable import Strata

/// **A friend's win stands in a tower without being a model.**
@MainActor
@Suite("Tower entries")
struct TowerEntryTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Habit.self, HabitLog.self, Tower.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    static let sizes: [BlockSize] = [.small, .hard, .medium, .small, .medium, .hard, .small, .small, .medium]

    static func wins(_ count: Int) -> [SharedWin] {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        return (0..<count).map { i in
            SharedWin(winID: UUID(), crewID: CrewID(rawValue: "crew-t"), senderProfileID: UUID(),
                      crewDay: "2027-01-15", title: "Win \(i)", colour: .health, icon: .health,
                      blockSize: sizes[i % sizes.count], photo: nil, cropX: nil, cropY: nil,
                      createdAt: start.addingTimeInterval(Double(i)), updatedAt: start)
        }
    }

    @Test func sharedWinsPackExactlyAsYourOwnDo() throws {
        let context = try context()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0..<40 {
            _ = try QuickWinService.logWin(title: "Win \(i)", category: .health, size: Self.sizes[i % Self.sizes.count],
                                           on: start.addingTimeInterval(Double(i)), context: context, tower: nil)
        }
        let own = TowerViewModel()
        own.buildTower(from: try context.fetch(FetchDescriptor<HabitLog>()))

        let crew = TowerViewModel()
        crew.buildTower(entries: Self.wins(40).map {
            TowerViewModel.TowerEntry(id: $0.winID, look: PlacedBlock.Look(win: $0, sender: "Sam"))
        }, merges: false)

        #expect(crew.placedBlocks.count == 40)
        let ownPlaces = own.placedBlocks.map { [$0.column, $0.row, $0.columnSpan, $0.rowSpan] }
        let crewPlaces = crew.placedBlocks.map { [$0.column, $0.row, $0.columnSpan, $0.rowSpan] }
        #expect(ownPlaces == crewPlaces)
        #expect(crew.placedBlocks.allSatisfy { $0.habit == nil && $0.log == nil })
    }

    @Test func aCrewTowerNeverMerges() {
        // Six unnamed small health blocks side by side would merge on your
        // own tower. In a crew they are six people's wins.
        let wins = (0..<6).map { i in
            SharedWin(winID: UUID(), crewID: CrewID(rawValue: "crew-t"), senderProfileID: UUID(), crewDay: "2027-01-15",
                      title: "", colour: .health, icon: .unlabeled, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                      createdAt: Date(timeIntervalSince1970: Double(i)), updatedAt: .now)
        }
        let vm = TowerViewModel()
        vm.buildTower(entries: wins.map { .init(id: $0.winID, look: PlacedBlock.Look(win: $0, sender: nil)) }, merges: false)
        #expect(vm.mergeGroups.isEmpty)
    }

    @Test func aCrewBlockKnowsWhoseItIs() {
        let win = Self.wins(1)[0]
        let theirs = PlacedBlock.Look(win: win, sender: "Sam")
        #expect(theirs.sender == "Sam" && !theirs.isMine)
        let mine = PlacedBlock.Look(win: win, sender: nil)
        #expect(mine.isMine)
        #expect(theirs != mine, "the back changes when the sender does, so == must see it")
    }
}
