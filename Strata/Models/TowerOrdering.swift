import Foundation
import SwiftData

/// Where a block goes when you move it.
///
/// A free function on a plain array rather than a method on the view, so the
/// rule can be tested without a simulator, a finger, or a tower. The gesture
/// that triggers it cannot be driven from a test — XCUITest cannot synthesise
/// the lift that starts a UIKit drag — so the arithmetic underneath it is
/// where the confidence has to come from.
enum TowerOrdering {

    /// The order after moving one block onto another's position.
    ///
    /// The tower packs in sequence, so reordering IS reordering the sequence:
    /// there is no "put it at these coordinates", because a block's
    /// coordinates are a consequence of what came before it. Moving a 2x2 past
    /// a 1x1 can restack several rows, which is correct — that is the tower
    /// you would have had if you had done them in that order.
    /// The target's index is taken BEFORE the move is removed, and that is the
    /// whole subtlety. Reading it afterwards looks equivalent and is not: when
    /// a block moves up, everything above it shifts down by one as it leaves,
    /// so the target's index has already changed by the time you ask. Dragging
    /// a block onto its immediate neighbour above then inserted it exactly
    /// where it started and the tower did not move at all — which from the
    /// outside is a rearrange that silently ignores you. Using the original
    /// index means the moved block lands on the target's old position in both
    /// directions, which is also the only symmetric answer.
    static func reordered<T: Identifiable>(_ items: [T], moving: T.ID, onto target: T.ID) -> [T] {
        guard moving != target,
              let from = items.firstIndex(where: { $0.id == moving }),
              let to = items.firstIndex(where: { $0.id == target }) else { return items }
        var result = items
        let block = result.remove(at: from)
        result.insert(block, at: min(to, result.count))
        return result
    }

    /// Applies a move and writes it down.
    ///
    /// Every block gets an explicit index, not just the ones that moved. A
    /// partial order is worse than none: the blocks left holding `nil` sort by
    /// completion time while the rest sort by index, and the two interleave
    /// unpredictably on the next build.
    @discardableResult
    static func commit(moving: UUID, onto target: UUID,
                       logs: [HabitLog], context: ModelContext,
                       then reflow: () -> Void) -> Bool {
        let ordered = reordered(logs, moving: moving, onto: target)
        guard ordered.map(\.id) != logs.map(\.id) else { return false }
        for (index, log) in ordered.enumerated() { log.towerOrder = index }
        try? context.save()
        HapticsEngine.success()
        reflow()
        return true
    }
}
