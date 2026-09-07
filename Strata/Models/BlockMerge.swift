import Foundation

/// Which sides of a block continue into a neighbour of the same colour.
///
/// Blocks of one colour sitting next to each other should read as one piece,
/// the way a tetromino does — a run of four greens is a shape, not four
/// squares that happen to match. That is done per block rather than by drawing
/// a union path: each block squares the corners that face a shared edge, grows
/// by half the grid gap to close it, and drops its rim along it. Adjacent
/// blocks then meet exactly and the seam disappears, while every block keeps
/// its own text, its own tap target and its own drop animation.
struct MergedEdges: OptionSet, Equatable {
    let rawValue: Int
    static let top      = MergedEdges(rawValue: 1 << 0)
    static let bottom   = MergedEdges(rawValue: 1 << 1)
    static let leading  = MergedEdges(rawValue: 1 << 2)
    static let trailing = MergedEdges(rawValue: 1 << 3)
    static let none: MergedEdges = []

    /// A corner is square when either of the two edges meeting there is shared.
    var topLeadingSquare: Bool     { contains(.top) || contains(.leading) }
    var topTrailingSquare: Bool    { contains(.top) || contains(.trailing) }
    var bottomLeadingSquare: Bool  { contains(.bottom) || contains(.leading) }
    var bottomTrailingSquare: Bool { contains(.bottom) || contains(.trailing) }
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

    static func compute(for blocks: [PlacedBlock]) -> [UUID: MergedEdges] {
        guard !blocks.isEmpty else { return [:] }

        // Cell -> (block id, merge key). A nil key never matches anything.
        var owner: [Int: (id: UUID, key: String?)] = [:]
        let columns = GridConstants.columnCount

        func index(_ column: Int, _ row: Int) -> Int { row * columns + column }

        for block in blocks {
            let key: String? = block.log.imageFileName == nil
                ? block.habit.displayCategory.rawValue
                : nil
            for r in block.row..<(block.row + block.rowSpan) {
                for c in block.column..<(block.column + block.columnSpan) {
                    owner[index(c, r)] = (block.id, key)
                }
            }
        }

        var result: [UUID: MergedEdges] = [:]
        for block in blocks {
            let key: String? = block.log.imageFileName == nil
                ? block.habit.displayCategory.rawValue
                : nil
            guard key != nil else { result[block.id] = .none; continue }

            var edges: MergedEdges = .none
            let rows = block.row..<(block.row + block.rowSpan)
            let cols = block.column..<(block.column + block.columnSpan)

            /// A side merges only when EVERY cell along it faces the same
            /// colour. A partial match would square a corner that still has an
            /// exposed edge running past it, which reads as a chipped block.
            func sideMerges(_ cells: [(Int, Int)]) -> Bool {
                guard !cells.isEmpty else { return false }
                return cells.allSatisfy { c, r in
                    guard c >= 0, c < columns, r >= 0 else { return false }
                    guard let n = owner[index(c, r)] else { return false }
                    return n.id != block.id && n.key == key
                }
            }

            if sideMerges(cols.map { ($0, block.row + block.rowSpan) }) { edges.insert(.top) }
            if sideMerges(cols.map { ($0, block.row - 1) })             { edges.insert(.bottom) }
            if sideMerges(rows.map { (block.column - 1, $0) })          { edges.insert(.leading) }
            if sideMerges(rows.map { (block.column + block.columnSpan, $0) }) { edges.insert(.trailing) }

            result[block.id] = edges
        }
        return result
    }
}
