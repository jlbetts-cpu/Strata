import Foundation

/// A month drawn as a tower: one block per day, sized by how much you did.
///
/// This is a **rank** encoding, not a ratio one. The three sizes are 1, 2 and 4
/// cells, and perceived area grows roughly as area^0.7, so mapping a win count
/// linearly onto area over-reads the big days twice over. Binning sublinearly
/// is the correction — cells per win falls from ~0.75 at two wins to ~0.5 at
/// eight.
///
/// Everything here is a value function over value types. It never touches
/// SwiftData, so it is testable without a container.
enum MonthTower {

    /// One day of the month that had at least one win.
    struct Day: Identifiable, Equatable {
        /// `yyyy-MM-dd`. Also the route that opens this day.
        let dateString: String
        let dayOfMonth: Int
        let winCount: Int
        /// The day's dominant `displayCategory` — see `dominantCategory`.
        let category: HabitCategory

        var id: String { dateString }
        var size: BlockSize { MonthTower.size(forWinCount: winCount) }
    }

    /// A day, placed.
    struct Block: Identifiable, Equatable {
        let dateString: String
        let dayOfMonth: Int
        let winCount: Int
        let category: HabitCategory
        let column: Int
        let row: Int
        let columnSpan: Int
        let rowSpan: Int

        var id: String { dateString }
    }

    struct Packed: Equatable {
        let blocks: [Block]
        let rows: Int

        static let empty = Packed(blocks: [], rows: 0)
        var isEmpty: Bool { blocks.isEmpty }
    }

    // MARK: - Sizing

    /// Win count to block size.
    ///
    /// The cuts are 3 and 7, chosen so that:
    ///
    /// - **The largest size stays rare enough to read as large.** On a
    ///   right-skewed distribution of wins per active day, 7+ is about 8% of
    ///   days — two or three blocks in a month. Cutting at 5+ puts it near a
    ///   quarter, at which point a 2×2 stops meaning anything and the month is
    ///   a wall.
    /// - **The median day is the median block.** With the lower cut at 3,
    ///   `.medium` is the modal bin (~48%), so the ordinary day is the ordinary
    ///   block and both small and large are departures from it.
    ///
    /// The asymmetry — 2→3 crosses a boundary but 3→6 does not — follows from
    /// the sublinear binning and is deliberate. This ranks days; it does not
    /// measure them. The exact count is on the day's own screen, one tap away.
    static func size(forWinCount count: Int) -> BlockSize {
        switch count {
        case ..<3:  return .small     // 1–2
        case 3...6: return .medium    // 3–6
        default:    return .hard      // 7+
        }
    }

    /// The category a day wears: the one most of its wins wore.
    ///
    /// Ties break by the *earliest* vote, so the result is deterministic and
    /// the tiebreak means something — what the day started as.
    ///
    /// Callers must pass `habit.displayCategory`, never `habit.category`: an
    /// uncategorised win would otherwise vote `.unlabeled`, which has no
    /// colour, and a colourless block does not belong to a page made of colour.
    static func dominantCategory(_ votes: [(category: HabitCategory, at: Date)]) -> HabitCategory {
        var counts: [HabitCategory: Int] = [:]
        var earliest: [HabitCategory: Date] = [:]
        for vote in votes {
            counts[vote.category, default: 0] += 1
            if let seen = earliest[vote.category] {
                earliest[vote.category] = min(seen, vote.at)
            } else {
                earliest[vote.category] = vote.at
            }
        }
        let winner = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            // Fewer votes loses; equal votes, the later first sighting loses.
            let l = earliest[lhs.key] ?? .distantFuture
            let r = earliest[rhs.key] ?? .distantFuture
            return l > r
        }
        return winner?.key ?? .unlabeled
    }

    // MARK: - Packing

    /// Packs a month, oldest day first, so the month grows the way the tower
    /// grows.
    ///
    /// **Adjacent same-colour days are never merged.** `MergedGroupView` fuses
    /// touching cells of one colour, and on the tower that is true — they are
    /// one object. Here two touching blocks are two different days, and fusing
    /// them would destroy both the tap target and the meaning. Do not reuse
    /// `MiniTowerView` here.
    static func pack(_ days: [Day]) -> Packed {
        var grid: [[Bool]] = []
        var out: [Block] = []

        for day in days.sorted(by: { $0.dateString < $1.dateString }) {
            let size = day.size
            guard let pos = GridPacker.firstFit(
                columnSpan: size.columnSpan,
                rowSpan: size.rowSpan,
                grid: &grid
            ) else { continue }
            out.append(Block(
                dateString: day.dateString,
                dayOfMonth: day.dayOfMonth,
                winCount: day.winCount,
                category: day.category,
                column: pos.column,
                row: pos.row,
                columnSpan: size.columnSpan,
                rowSpan: size.rowSpan
            ))
        }

        let rows = out.map { $0.row + $0.rowSpan }.max() ?? 0
        return Packed(blocks: out, rows: rows)
    }
}
