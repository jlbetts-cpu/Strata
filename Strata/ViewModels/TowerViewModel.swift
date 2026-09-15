import Foundation
import SwiftData
import SwiftUI

struct PlacedBlock: Identifiable, Equatable {
    let id: UUID
    let habit: Habit
    let log: HabitLog
    let column: Int
    let row: Int
    let columnSpan: Int
    let rowSpan: Int
    let isSkipped: Bool
    /// What the block looked like when the tower was built.
    let look: Look

    /// The values a tower block draws with, copied out of the models.
    ///
    /// **Values, because the models are shared references.** Two
    /// `PlacedBlock`s for the same win hold the SAME `Habit`, so comparing
    /// `lhs.habit.title == rhs.habit.title` reads one object twice and is
    /// always true: the `Equatable` trap in CLAUDE.md. A `Look` taken at one
    /// moment and a `Look` taken at another can actually differ, so a rename,
    /// a colour change or a new photograph compares unequal.
    struct Look: Equatable {
        let title: String
        /// `displayCategory`: the colour.
        let displayCategory: HabitCategory
        /// `category`: what the icon and the label logic are given.
        let category: HabitCategory
        let blockSize: BlockSize
        let imageFileName: String?
        let cropX: Double?
        let cropY: Double?

        init(habit: Habit, log: HabitLog) {
            title = habit.title
            displayCategory = habit.displayCategory
            category = habit.category
            blockSize = habit.blockSize
            imageFileName = log.imageFileName
            cropX = log.cropPositionX
            cropY = log.cropPositionY
        }
    }

    init(id: UUID, habit: Habit, log: HabitLog, column: Int, row: Int, columnSpan: Int, rowSpan: Int, isSkipped: Bool = false) {
        self.id = id
        self.habit = habit
        self.log = log
        self.column = column
        self.row = row
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
        self.isSkipped = isSkipped
        self.look = Look(habit: habit, log: log)
    }

    /// Same win, same objects, same place, same look.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.habit === rhs.habit
            && lhs.log === rhs.log
            && lhs.column == rhs.column
            && lhs.row == rhs.row
            && lhs.columnSpan == rhs.columnSpan
            && lhs.rowSpan == rhs.rowSpan
            && lhs.isSkipped == rhs.isSkipped
            && lhs.look == rhs.look
    }

    func frame(cellSize: CGFloat) -> CGRect {
        GridConstants.blockFrame(column: column, row: row, columnSpan: columnSpan, rowSpan: rowSpan, cellSize: cellSize)
    }
}

struct PlacedIncompleteBlock: Identifiable {
    let id: UUID
    let habit: Habit
    let column: Int
    let row: Int
    let columnSpan: Int
    let rowSpan: Int

    func frame(cellSize: CGFloat) -> CGRect {
        GridConstants.blockFrame(column: column, row: row, columnSpan: columnSpan, rowSpan: rowSpan, cellSize: cellSize)
    }
}

@Observable
final class TowerViewModel {
    private(set) var placedBlocks: [PlacedBlock] = []
    private(set) var incompleteBlocks: [PlacedIncompleteBlock] = []
    private(set) var totalRows: Int = 0
    private(set) var currentGrid: [[Bool]] = []
    var isLoading: Bool = true
    // Cascade drop tracking
    private(set) var newlyDroppedIDs: Set<UUID> = []
    /// Runs of adjacent, same-colour, unnamed blocks drawn as one shape.
    /// Recomputed on rebuild, never per frame.
    private(set) var mergeGroups: [MergeGroup] = []
    /// Blocks belonging to some group, so they know to draw nothing.
    private(set) var groupedBlockIDs: Set<UUID> = []
    /// Blocks carrying another block directly above them.
    private(set) var coveredBlockIDs: Set<UUID> = []
    private(set) var staggerDelayCache: [UUID: Double] = [:]
    private var previousBlockIDs: Set<UUID> = []
    /// False until the first build has happened.
    ///
    /// On that first build every block is "new" relative to an empty set, and
    /// animating the whole tower in as a cascade on launch is neither wanted
    /// nor affordable. Callers use `hasBuiltOnce` to tell "the tower just
    /// loaded" from "a block just arrived".
    private(set) var hasBuiltOnce = false

    // Day separators (Week/Month modes)

    // Tower metadata
    private(set) var topRowBlockIDs: Set<UUID> = []            // blocks on topmost row
    private(set) var foundationBlockIDs: Set<UUID> = []        // blocks on row 0

    func startLoading() {
        isLoading = true
        totalRows = 0
    }

    // MARK: - Build Unified Grid

    @discardableResult
    /// - Parameter preserveOrder: take `logs` in the order given instead of
    ///   sorting them. Used while a block is being dragged: the caller is
    ///   showing a *proposed* arrangement that exists only in an array, and
    ///   nothing has been written to `towerOrder` yet — so sorting by
    ///   `towerOrder` here would quietly throw the proposal away and repack
    ///   the tower exactly as it already was.
    func buildTower(from logs: [HabitLog],
                    filterMode: TowerFilterMode = .day,
                    preserveOrder: Bool = false) -> Set<UUID> {
        // Boolean grid matrix: grid[row][col] = true means occupied
        var grid = [[Bool]]()

        // Include completed AND skipped blocks, oldest first so newest land on top
        let filtered = logs.filter { ($0.completed || $0.skipped) && $0.habit != nil }
        let eligibleLogs = preserveOrder ? filtered : filtered
            // Moved blocks first, in the order you put them; everything else
            // in the order it happened. A tower nobody has rearranged sorts
            // exactly as it always did.
            .sorted { a, b in
                switch (a.towerOrder, b.towerOrder) {
                case let (x?, y?): return x == y
                    ? (a.completedAt ?? .distantPast) < (b.completedAt ?? .distantPast)
                    : x < y
                case (_?, nil):    return true
                case (nil, _?):    return false
                default:
                    return (a.completedAt ?? .distantPast) < (b.completedAt ?? .distantPast)
                }
            }

        let useDayBoundaries = filterMode != .day

        var placed: [PlacedBlock] = []
        var currentDateString: String? = nil
        var dayBoundaryRows: [(dateString: String, row: Int)] = []
        var blockCountByDate: [String: Int] = [:]
        // The lowest row with a free cell. Nothing can start below it, so the
        // packer starts there instead of re-scanning the full rows under it
        // for every block, which made a build quadratic in the tower's height.
        var floorRow = 0

        for log in eligibleLogs {
            guard let habit = log.habit else { continue }
            let colSpan = habit.blockSize.columnSpan
            let rowSpan = habit.blockSize.rowSpan
            let isSkipped = log.skipped && !log.completed

            // Day boundary: force new row when date changes (Week/Month only)
            if useDayBoundaries, let current = currentDateString, log.dateString != current {
                // Advance grid to next empty row
                let nextEmptyRow = grid.count
                dayBoundaryRows.append((dateString: log.dateString, row: nextEmptyRow))
            }
            currentDateString = log.dateString

            if let pos = findPosition(columnSpan: colSpan, rowSpan: rowSpan, grid: &grid, from: floorRow) {
                while floorRow < grid.count && !grid[floorRow].contains(false) { floorRow += 1 }
                let block = PlacedBlock(
                    id: log.id,
                    habit: habit,
                    log: log,
                    column: pos.column,
                    row: pos.row,
                    columnSpan: colSpan,
                    rowSpan: rowSpan,
                    isSkipped: isSkipped
                )
                placed.append(block)
                blockCountByDate[log.dateString, default: 0] += 1
            }
        }

        // Every published property below is assigned only when its value
        // changed. `@Observable` already skips an equal write for an
        // `Equatable` type, but `[PlacedBlock]` was not one and `MergeGroup`
        // is not, and `refreshData()` rebuilds on every save and every drop:
        // those two notified every view reading the tower on every rebuild,
        // even when the tower was exactly what it had been. The checks on the
        // Equatable ones say the same thing out loud rather than leaning on
        // the macro. `TowerBuildTests` holds both halves.

        // Detect newly added blocks for cascade animation
        let newIDs = Set(placed.map(\.id))
        let dropped = newIDs.subtracting(previousBlockIDs)
        if newlyDroppedIDs != dropped { newlyDroppedIDs = dropped }
        previousBlockIDs = newIDs
        defer { if !hasBuiltOnce { hasBuiltOnce = true } }

        if placedBlocks != placed { placedBlocks = placed }
        let groups = BlockMerge.groups(for: placed)
        if !Self.sameGroups(mergeGroups, groups) {
            mergeGroups = groups
            let grouped = Set(groups.flatMap(\.memberIDs))
            if groupedBlockIDs != grouped { groupedBlockIDs = grouped }
        }
        let covered = BlockMerge.covered(in: placed)
        if coveredBlockIDs != covered { coveredBlockIDs = covered }
        if !incompleteBlocks.isEmpty { incompleteBlocks = [] }
        if currentGrid != grid {
            currentGrid = grid
            ghostPositionCache.removeAll()
        }

        // Compute top-row and foundation block IDs
        let topRow: Set<UUID>
        let foundation: Set<UUID>
        if !placed.isEmpty {
            let maxRow = placed.map { $0.row + $0.rowSpan - 1 }.max() ?? 0
            topRow = Set(placed.filter { $0.row + $0.rowSpan - 1 == maxRow }.map(\.id))
            foundation = Set(placed.filter { $0.row == 0 }.map(\.id))
        } else {
            topRow = []
            foundation = []
        }
        if topRowBlockIDs != topRow { topRowBlockIDs = topRow }
        if foundationBlockIDs != foundation { foundationBlockIDs = foundation }

        // Pre-compute stagger delays (O(1) lookup per block instead of O(n) per call)
        if !newlyDroppedIDs.isEmpty {
            let sortedNew = placed
                .filter { newlyDroppedIDs.contains($0.id) }
                .sorted { $0.row < $1.row }
            let count = max(sortedNew.count, 1)
            staggerDelayCache = [:]
            for (index, block) in sortedNew.enumerated() {
                let normalizedIndex = Double(index) / Double(count)
                let decelerated = pow(normalizedIndex, 0.5)
                staggerDelayCache[block.id] = min(decelerated * 0.4, 0.4)
            }
        }

        let rows = placed.isEmpty ? 0 : placed.map { $0.row + $0.rowSpan }.max()!
        if totalRows != rows { totalRows = rows }

        #if DEBUG
        // Validate: no two blocks overlap in the grid
        if totalRows > 0 {
            var validationGrid = Array(repeating: Array(repeating: false, count: GridConstants.columnCount), count: totalRows)
            for block in placed {
                for r in block.row..<(block.row + block.rowSpan) {
                    for c in block.column..<(block.column + block.columnSpan) {
                        assert(!validationGrid[r][c], "Block overlap at (\(c), \(r))")
                        validationGrid[r][c] = true
                    }
                }
            }
        }
        #endif

        if isLoading { isLoading = false }

        // Clear the dropped set after animation window
        if !newlyDroppedIDs.isEmpty {
            let droppedCopy = newlyDroppedIDs
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                if !self.newlyDroppedIDs.isDisjoint(with: droppedCopy) {
                    self.newlyDroppedIDs.subtract(droppedCopy)
                }
                // Only keys that are there: block bodies read this cache, and
                // a removal of nothing still notifies them.
                for id in droppedCopy where self.staggerDelayCache[id] != nil {
                    self.staggerDelayCache.removeValue(forKey: id)
                }
            }
        }

        return newlyDroppedIDs
    }

    // MARK: - Day Separators

 
    func staggerDelay(for block: PlacedBlock) -> Double {
        staggerDelayCache[block.id] ?? 0
    }

    // MARK: - Ghost Block Preview (Kliegel 2008 — external prospective memory aid)

    /// Where a block of this size would land next.
    ///
    /// Called from `MainAppView`'s body, so on every evaluation of it; the
    /// answer only changes when the grid does. Cached per size and cleared
    /// wherever `currentGrid` is written. Reading `currentGrid` first keeps
    /// the caller's observation of the grid exactly as it was.
    func computeGhostPosition(for blockSize: BlockSize) -> (column: Int, row: Int)? {
        let grid = currentGrid
        if let cached = ghostPositionCache[blockSize] { return cached.position }
        var gridCopy = grid
        let position = findPosition(columnSpan: blockSize.columnSpan, rowSpan: blockSize.rowSpan, grid: &gridCopy)
        ghostPositionCache[blockSize] = GhostSlot(position: position)
        return position
    }

    private struct GhostSlot {
        let position: (column: Int, row: Int)?
    }

    /// Not observed: a cache filled from inside a view body must not publish.
    @ObservationIgnored private var ghostPositionCache: [BlockSize: GhostSlot] = [:]

    /// The same runs, in any order. `BlockMerge.groups` builds its array
    /// from a dictionary, so the order is not stable from one build to the
    /// next even when the groups are; a reorder alone is not a change.
    private static func sameGroups(_ a: [MergeGroup], _ b: [MergeGroup]) -> Bool {
        guard a.count == b.count else { return false }
        var byID: [UUID: MergeGroup] = [:]
        for group in a { byID[group.id] = group }
        return b.allSatisfy { group in
            guard let other = byID[group.id] else { return false }
            return other.category == group.category
                && other.cells == group.cells
                && other.memberIDs == group.memberIDs
                && other.bottomRow == group.bottomRow
        }
    }

    /// Today's unfinished habits, packed onto the tower above what is built.
    ///
    /// This is what replaced the Today tab. An unfinished habit is not a row on
    /// another screen — it is the cell it is going to occupy, outlined, sitting
    /// on top of the blocks that are already standing. The tower then shows the
    /// whole day at once: what you did, and what is still outlined above it.
    ///
    /// Packed in list order onto a copy of the built grid, so they take the
    /// same cells the real blocks would and the tower's shape is honest about
    /// where the day is going.
    ///
    /// Returns the grid with them marked, so the next slot can be placed above
    /// the pending ones rather than underneath them.
    func packPending(_ habits: [Habit]) -> (blocks: [PlacedIncompleteBlock], gridAfter: [[Bool]]) {
        var grid = currentGrid
        var out: [PlacedIncompleteBlock] = []
        for habit in habits {
            let size = habit.blockSize
            guard let pos = findPosition(
                columnSpan: size.columnSpan,
                rowSpan: size.rowSpan,
                grid: &grid
            ) else { continue }
            out.append(PlacedIncompleteBlock(
                id: habit.id,
                habit: habit,
                column: pos.column,
                row: pos.row,
                columnSpan: size.columnSpan,
                rowSpan: size.rowSpan
            ))
        }
        return (out, grid)
    }

    /// Takes the next free cell for the slot and returns the grid with it
    /// claimed, so the outlined blocks can be stacked ABOVE it.
    ///
    /// The order matters and it is the whole point: built blocks, then the
    /// slot resting on them, then what you still mean to do floating above.
    /// Packing the outlines first put them underneath, so every landing block
    /// shoved them around to reach the gap it wanted.
    /// The next free cell on a grid that already has the pending blocks in it.
    func ghostPosition(for blockSize: BlockSize, on grid: [[Bool]]) -> (column: Int, row: Int)? {
        var copy = grid
        return findPosition(columnSpan: blockSize.columnSpan, rowSpan: blockSize.rowSpan, grid: &copy)
    }

    // MARK: - Boolean Grid Matrix Packing

    /// Scans the boolean grid from row 0 (bottom) upward to find the first
    /// position where a block of the given span fits with zero gaps.
    private func findPosition(
        columnSpan: Int,
        rowSpan: Int,
        grid: inout [[Bool]],
        from startRow: Int = 0
    ) -> (column: Int, row: Int)? {
        let colCount = GridConstants.columnCount
        let maxStartCol = colCount - columnSpan
        guard maxStartCol >= 0 else { return nil }

        // Scan from `startRow` upward: row 0, the foundation, unless the
        // caller knows every row below it is already full
        var row = startRow
        while true {
            // Ensure the grid has enough rows to check this position
            let neededRows = row + rowSpan
            while grid.count < neededRows {
                grid.append(Array(repeating: false, count: colCount))
            }

            for col in 0...maxStartCol {
                if canPlace(column: col, row: row, columnSpan: columnSpan, rowSpan: rowSpan, grid: grid) {
                    // Mark cells as occupied
                    for r in row..<(row + rowSpan) {
                        for c in col..<(col + columnSpan) {
                            grid[r][c] = true
                        }
                    }
                    return (column: col, row: row)
                }
            }

            row += 1

            // Safety cap to prevent infinite loop on malformed data
            if row > 1000 { return nil }
        }
    }

    // MARK: - Skeleton Layout

    struct SkeletonBlock: Identifiable {
        let id: Int
        let column: Int
        let row: Int
        let columnSpan: Int
        let rowSpan: Int
    }

    func skeletonLayout(blockCount: Int = 8) -> [SkeletonBlock] {
        // Deterministic pattern of mixed sizes
        let sizes: [(col: Int, row: Int)] = [
            (1, 1), (2, 1), (1, 1), (1, 1),
            (2, 2), (1, 1), (1, 1), (2, 1),
            (1, 1), (1, 1), (2, 1), (1, 1)
        ]

        var grid = [[Bool]]()
        var blocks: [SkeletonBlock] = []

        for i in 0..<blockCount {
            let size = sizes[i % sizes.count]
            let colSpan = size.col
            let rowSpan = size.row

            if let pos = findPosition(columnSpan: colSpan, rowSpan: rowSpan, grid: &grid) {
                blocks.append(SkeletonBlock(
                    id: i,
                    column: pos.column,
                    row: pos.row,
                    columnSpan: colSpan,
                    rowSpan: rowSpan
                ))
            }
        }

        return blocks
    }

    /// Checks whether every cell in the columnSpan × rowSpan region is false (empty).
    private func canPlace(
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        grid: [[Bool]]
    ) -> Bool {
        for r in row..<(row + rowSpan) {
            guard r < grid.count else { return false }
            for c in column..<(column + columnSpan) {
                if grid[r][c] { return false }
            }
        }
        return true
    }
}
