import Testing
import Foundation
import SwiftData
import Observation
@testable import Strata

/// `TowerViewModel.buildTower`, which runs after every save and every drop.
///
/// Two things it must keep doing now that it is cheaper: place every block
/// exactly where the shared first-fit rule does, and stay quiet when a rebuild
/// changes nothing while still speaking up when a block's look changes.
@MainActor
@Suite("TowerBuild")
struct TowerBuildTests {

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Habit.self, HabitLog.self, Tower.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    /// A fixed, mixed sequence of sizes, long enough that the packer's
    /// starting row moves well above the foundation and leaves holes for
    /// later small blocks to backfill.
    private func seed(_ context: ModelContext, count: Int) throws -> [HabitLog] {
        let sizes: [BlockSize] = [.small, .hard, .medium, .small, .small, .hard, .medium, .small, .medium]
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0..<count {
            _ = try QuickWinService.logWin(
                title: "Win \(i)", category: .health, size: sizes[(i * 7) % sizes.count],
                on: start.addingTimeInterval(Double(i)), context: context, tower: nil)
        }
        return try context.fetch(FetchDescriptor<HabitLog>())
    }

    @Test("every block lands where GridPacker.firstFit puts it")
    func placementMatchesTheSharedRule() throws {
        let context = try context()
        let logs = try seed(context, count: 150)
        let vm = TowerViewModel()
        vm.buildTower(from: logs)
        #expect(vm.placedBlocks.count == 150)

        var grid: [[Bool]] = []
        for block in vm.placedBlocks {
            let pos = GridPacker.firstFit(columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                                          columns: GridConstants.columnCount, grid: &grid)
            #expect(pos?.column == block.column && pos?.row == block.row,
                    "block \(block.look.title) at (\(block.column),\(block.row)), rule says \(String(describing: pos))")
        }
    }

    @Test("the slot is where the shared rule puts the next block, for every size")
    func ghostMatchesTheSharedRule() throws {
        let context = try context()
        let logs = try seed(context, count: 37)
        let vm = TowerViewModel()
        vm.buildTower(from: logs)
        for size in BlockSize.allCases {
            var grid: [[Bool]] = []
            for block in vm.placedBlocks {
                _ = GridPacker.firstFit(columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                                        columns: GridConstants.columnCount, grid: &grid)
            }
            let expected = GridPacker.firstFit(columnSpan: size.columnSpan, rowSpan: size.rowSpan,
                                               columns: GridConstants.columnCount, grid: &grid)
            // Twice: the second answer comes from the cache.
            for _ in 0..<2 {
                let slot = vm.computeGhostPosition(for: size)
                #expect(slot?.column == expected?.column && slot?.row == expected?.row)
            }
        }
    }

    @Test("a rebuild that changes nothing does not notify the tower's observers")
    func unchangedRebuildIsQuiet() throws {
        let context = try context()
        let logs = try seed(context, count: 20)
        let vm = TowerViewModel()
        vm.buildTower(from: logs)

        var fired = false
        withObservationTracking {
            _ = vm.placedBlocks
            _ = vm.mergeGroups
            _ = vm.coveredBlockIDs
            _ = vm.totalRows
            _ = vm.isLoading
        } onChange: { fired = true }
        vm.buildTower(from: logs)
        #expect(!fired, "an identical rebuild still invalidated every view reading the tower")
    }

    /// The other half of the same contract, and the reason `Look` holds
    /// values: the models are shared references, so a rename would compare
    /// equal to itself if the comparison read them.
    @Test("renaming a block makes the rebuild notify")
    func renameIsAChange() throws {
        let context = try context()
        let logs = try seed(context, count: 20)
        let vm = TowerViewModel()
        vm.buildTower(from: logs)

        var fired = false
        withObservationTracking {
            _ = vm.placedBlocks
        } onChange: { fired = true }
        vm.placedBlocks[3].habit.title = "Renamed"
        vm.buildTower(from: logs)
        #expect(fired)
        #expect(vm.placedBlocks[3].look.title == "Renamed")
    }
}
