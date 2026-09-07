import Foundation

/// A run of adjacent blocks drawn as one shape.
///
/// Only blocks with no name merge. A named block is a specific thing you did
/// and carries its own title, so running two of them together would hide the
/// boundary between two different accomplishments. Unnamed blocks have no text
/// at all, which is exactly what makes them safe to fuse — and it is the state
/// most in need of the help, since a wall of identical untitled squares is what
/// looks least like a structure.
struct MergeGroup: Identifiable {
    let id: UUID
    let category: HabitCategory
    let cells: Set<GridCell>
    let memberIDs: Set<UUID>
    /// Row of the lowest cell — where the group's frosted band belongs.
    let bottomRow: Int
}

enum BlockMerge {
    /// Works out, for every block, which of its sides continue into a
    /// same-colour neighbour.
    ///
    /// Photo blocks never merge: an image has its own edges, and running two
    /// photographs together would read as one broken picture rather than as
    /// one piece. Colour is the only thing that merges.
    ///
    /// O(cells) — each block writes its footprint into a lookup grid once, then
    /// each block reads its four neighbours. Recomputed only when the tower is
    /// rebuilt, not per frame.
    /// Blocks with something resting directly on top of them, whatever colour.
    ///
    /// Separate from merging on purpose: merging is about colour, contact is
    /// about load. A green block under a red one is not one piece with it, but
    /// it is still carrying it, and it should look like it.
    static func covered(in blocks: [PlacedBlock]) -> Set<UUID> {
        guard !blocks.isEmpty else { return [] }
        let columns = GridConstants.columnCount
        var occupied: Set<Int> = []
        func index(_ c: Int, _ r: Int) -> Int { r * columns + c }
        for block in blocks {
            for r in block.row..<(block.row + block.rowSpan) {
                for c in block.column..<(block.column + block.columnSpan) {
                    occupied.insert(index(c, r))
                }
            }
        }
        var result: Set<UUID> = []
        for block in blocks {
            let above = block.row + block.rowSpan
            let anyAbove = (block.column..<(block.column + block.columnSpan))
                .contains { occupied.contains(index($0, above)) }
            if anyAbove { result.insert(block.id) }
        }
        return result
    }

    /// Groups adjacent, same-colour, unnamed blocks.
    ///
    /// Union-find over cells: each block claims its cells, then any two
    /// adjacent cells belonging to mergeable blocks of the same colour are
    /// unioned. Working in cells rather than blocks means a 2x2 and a 1x1 merge
    /// correctly without any special case.
    static func groups(for blocks: [PlacedBlock]) -> [MergeGroup] {
        let mergeable = blocks.filter { block in
            block.log.imageFileName == nil
                && (block.habit.title == QuickWinService.untitled || block.habit.title.isEmpty)
        }
        guard mergeable.count > 1 else { return [] }

        var cellOwner: [GridCell: PlacedBlock] = [:]
        for block in mergeable {
            for r in block.row..<(block.row + block.rowSpan) {
                for c in block.column..<(block.column + block.columnSpan) {
                    cellOwner[GridCell(column: c, row: r)] = block
                }
            }
        }

        var parent: [GridCell: GridCell] = [:]
        func find(_ c: GridCell) -> GridCell {
            var root = c
            while let p = parent[root], p != root { root = p }
            var cur = c
            while let p = parent[cur], p != root { parent[cur] = root; cur = p }
            return root
        }
        func union(_ a: GridCell, _ b: GridCell) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }
        for cell in cellOwner.keys { parent[cell] = cell }

        for (cell, block) in cellOwner {
            let key = block.habit.displayCategory
            for neighbour in [
                GridCell(column: cell.column + 1, row: cell.row),
                GridCell(column: cell.column, row: cell.row + 1)
            ] {
                guard let other = cellOwner[neighbour],
                      other.habit.displayCategory == key else { continue }
                union(cell, neighbour)
            }
        }

        var byRoot: [GridCell: Set<GridCell>] = [:]
        for cell in cellOwner.keys { byRoot[find(cell), default: []].insert(cell) }

        return byRoot.compactMap { _, cells in
            let members = Set(cells.compactMap { cellOwner[$0]?.id })
            // A single block is not a group — it draws itself, with its own
            // rounded corners and band, exactly as it always did.
            guard members.count > 1, let any = cells.first,
                  let block = cellOwner[any] else { return nil }
            return MergeGroup(
                id: members.sorted(by: { $0.uuidString < $1.uuidString }).first!,
                category: block.habit.displayCategory,
                cells: cells,
                memberIDs: members,
                bottomRow: cells.map(\.row).min() ?? 0
            )
        }
    }
}
