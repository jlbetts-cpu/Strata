import Foundation
import SwiftData

/// **Your wins, weighed** (the owner, 2026-10-15: "a 'wins' score showcasing
/// your wins, 1 for small, 2 for medium and 3 for large, making sure if they
/// delete it goes down").
///
/// Counted from the record every time, never kept as a running number: a
/// stored total has to be told about every delete, undo, restore and reset,
/// and the day one path forgets, the score is wrong for good. Read from the
/// rows, a deleted win is simply not there to count.
///
/// What counts is a logged win: a completed `HabitLog`, weighed by its block,
/// Quick 1, Regular 2, Deep 3 (`BlockSize.massTier`). A planned line not yet
/// done counts nothing, and neither does a skipped day.
enum WinsScore {
    struct Tally: Equatable {
        var score = 0
        var wins = 0
    }

    static func points(_ size: BlockSize) -> Int { size.massTier }

    static func tally<Sizes: Sequence>(_ sizes: Sizes) -> Tally where Sizes.Element == BlockSize {
        sizes.reduce(into: Tally()) { tally, size in
            tally.score += points(size)
            tally.wins += 1
        }
    }

    /// Every logged win on this phone.
    @MainActor
    static func tally(in context: ModelContext) -> Tally {
        let descriptor = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed })
        guard let logs = try? context.fetch(descriptor) else { return Tally() }
        return tally(logs.map { $0.habit?.blockSize ?? .small })
    }
}
