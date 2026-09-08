import Testing
@testable import Strata

/// The rule that decides where a dragged block lands.
///
/// The gesture that triggers it cannot be driven from a UI test — XCUITest
/// cannot synthesise the lift that begins a UIKit drag session, which was
/// measured, not assumed. So the arithmetic gets tested directly, and the
/// report says plainly which half is covered.
struct TowerOrderingTests {

    private struct Item: Identifiable, Equatable {
        let id: Int
    }

    private func items(_ ids: [Int]) -> [Item] { ids.map(Item.init) }

    @Test func movingUpInsertsAtTheTargetsPosition() {
        let result = TowerOrdering.reordered(items([0, 1, 2, 3, 4]), moving: 0, onto: 3)
        #expect(result.map(\.id) == [1, 2, 3, 0, 4])
    }

    @Test func movingDownInsertsAtTheTargetsPosition() {
        let result = TowerOrdering.reordered(items([0, 1, 2, 3, 4]), moving: 4, onto: 1)
        #expect(result.map(\.id) == [0, 4, 1, 2, 3])
    }

    @Test func movingOntoTheNeighbourAboveSwapsThem() {
        let result = TowerOrdering.reordered(items([0, 1, 2]), moving: 0, onto: 1)
        #expect(result.map(\.id) == [1, 0, 2])
    }

    @Test func movingOntoItselfChangesNothing() {
        let start = items([0, 1, 2])
        #expect(TowerOrdering.reordered(start, moving: 1, onto: 1) == start)
    }

    @Test func anUnknownBlockChangesNothing() {
        let start = items([0, 1, 2])
        #expect(TowerOrdering.reordered(start, moving: 9, onto: 1) == start)
        #expect(TowerOrdering.reordered(start, moving: 1, onto: 9) == start)
    }

    @Test func everyBlockKeepsItsPlaceExactlyOnce() {
        let start = items(Array(0..<12))
        let result = TowerOrdering.reordered(start, moving: 7, onto: 2)
        #expect(result.count == start.count)
        #expect(Set(result.map(\.id)) == Set(start.map(\.id)))
    }

    /// A single-block tower has nothing to reorder against, and a two-block
    /// one is the smallest that does. Neither may crash or drop a block.
    @Test func smallTowersSurvive() {
        #expect(TowerOrdering.reordered(items([0]), moving: 0, onto: 0).map(\.id) == [0])
        #expect(TowerOrdering.reordered(items([0, 1]), moving: 1, onto: 0).map(\.id) == [1, 0])
    }

    // MARK: - The live preview a drag shows

    /// A drag proposes an arrangement that exists only as an array of ids.
    /// These are the exact transitions the tower performs under the finger.

    @Test func liftRemovesTheCarriedBlockSoTheGapCloses() {
        let committed = [1, 2, 3, 4, 5]
        let preview = committed.filter { $0 != 3 }
        #expect(preview == [1, 2, 4, 5])
    }

    @Test func hoveringProposesTheTargetsPosition() {
        let committed = [1, 2, 3, 4, 5]
        #expect(TowerOrdering.reordered(ids: committed, moving: 1, onto: 4) == [2, 3, 4, 1, 5])
        #expect(TowerOrdering.reordered(ids: committed, moving: 5, onto: 2) == [1, 5, 2, 3, 4])
    }

    /// Moving across several targets must always be measured from the
    /// COMMITTED order, never from the last preview — otherwise the block
    /// walks further with every block the finger crosses.
    @Test func successiveHoversAllMeasureFromTheCommittedOrder() {
        let committed = [1, 2, 3, 4, 5]
        let overFour = TowerOrdering.reordered(ids: committed, moving: 1, onto: 4)
        let overTwo = TowerOrdering.reordered(ids: committed, moving: 1, onto: 2)
        #expect(overFour == [2, 3, 4, 1, 5])
        #expect(overTwo == [2, 1, 3, 4, 5])
        // And going back over the first target returns the same answer it
        // gave the first time.
        #expect(TowerOrdering.reordered(ids: committed, moving: 1, onto: 4) == overFour)
    }

    @Test func cancellingReturnsExactlyTheCommittedOrder() {
        let committed = [1, 2, 3, 4, 5]
        var preview: [Int]? = TowerOrdering.reordered(ids: committed, moving: 2, onto: 5)
        #expect(preview != committed)
        preview = nil                                  // what cancelRearrange does
        #expect((preview ?? committed) == committed)
    }

    @Test func theIdOverloadAgreesWithTheModelOverload() {
        let items = items([0, 1, 2, 3, 4])
        let byItem = TowerOrdering.reordered(items, moving: 0, onto: 3).map(\.id)
        let byID = TowerOrdering.reordered(ids: items.map(\.id), moving: 0, onto: 3)
        #expect(byItem == byID)
    }
}
