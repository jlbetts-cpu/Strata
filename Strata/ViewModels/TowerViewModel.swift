import Foundation
import SwiftData
import SwiftUI

struct PlacedBlock: Identifiable {
    let id: UUID
    let habit: Habit
    let log: HabitLog
    let column: Int
    let row: Int
    let columnSpan: Int
    let rowSpan: Int
    let isSkipped: Bool

    init(id: UUID, habit: Habit, log: HabitLog, column: Int, row: Int, columnSpan: Int, rowSpan: Int, isSkipped: Bool = false) {
        self.id = id
        self.habit = habit
        self.log = log
        self.column = column
        self.row = row
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
        self.isSkipped = isSkipped
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
    /// Which sides of each block continue into a same-colour neighbour.
    /// Recomputed on rebuild, never per frame.
    private(set) var mergedEdges: [UUID: MergedEdges] = [:]
    private(set) var staggerDelayCache: [UUID: Double] = [:]
    private var previousBlockIDs: Set<UUID> = []
    /// False until the first build has happened.
    ///
    /// On that first build every block is "new" relative to an empty set, and
    /// animating the whole tower in as a cascade on launch is neither wanted
    /// nor affordable. Callers use `hasBuiltOnce` to tell "the tower just
    /// loaded" from "a block just arrived".
    private(set) var hasBuiltOnce = false
    private var dropCleanupTask: Task<Void, Never>? = nil

    // Day separators (Week/Month modes)
    private(set) var daySeparators: [DaySeparator] = []

    // Tower metadata
    private(set) var milestoneBlockIDs: [UUID: Int] = [:]     // blockID → block number (10th, 50th, etc.)
    private(set) var topRowBlockIDs: Set<UUID> = []            // blocks on topmost row
    private(set) var foundationBlockIDs: Set<UUID> = []        // blocks on row 0

    // Altimeter
    var altimeterHeight: Double {
        Double(peakCompletedHeight) * GridConstants.metersPerBlock
    }

    var peakCompletedHeight: Int {
        guard !placedBlocks.isEmpty else { return 0 }
        return placedBlocks.reduce(0) { max($0, $1.row + $1.rowSpan) }
    }

    func startLoading() {
        isLoading = true
        totalRows = 0
    }

    // MARK: - Build Unified Grid

    @discardableResult
    func buildTower(from logs: [HabitLog], filterMode: TowerFilterMode = .day) -> Set<UUID> {
        // Boolean grid matrix: grid[row][col] = true means occupied
        var grid = [[Bool]]()

        // Include completed AND skipped blocks, oldest first so newest land on top
        let eligibleLogs = logs
            .filter { ($0.completed || $0.skipped) && $0.habit != nil }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

        let useDayBoundaries = filterMode != .day

        var placed: [PlacedBlock] = []
        var currentDateString: String? = nil
        var dayBoundaryRows: [(dateString: String, row: Int)] = []
        var blockCountByDate: [String: Int] = [:]
        var nonSkippedBlockNumber = 0

        // Milestone thresholds
        let milestoneThresholds: Set<Int> = [10, 25, 50, 100, 150, 200, 250, 500, 1000]
        var milestones: [UUID: Int] = [:]

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

            if let pos = findPosition(columnSpan: colSpan, rowSpan: rowSpan, grid: &grid) {
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

                // Track milestones (skipped blocks excluded)
                if !isSkipped {
                    nonSkippedBlockNumber += 1
                    if milestoneThresholds.contains(nonSkippedBlockNumber) {
                        milestones[log.id] = nonSkippedBlockNumber
                    }
                }
            }
        }

        // Detect newly added blocks for cascade animation
        let newIDs = Set(placed.map(\.id))
        newlyDroppedIDs = newIDs.subtracting(previousBlockIDs)
        previousBlockIDs = newIDs
        defer { hasBuiltOnce = true }

        placedBlocks = placed
        mergedEdges = BlockMerge.compute(for: placed)
        incompleteBlocks = []
        currentGrid = grid
        milestoneBlockIDs = milestones

        // Compute top-row and foundation block IDs
        if !placed.isEmpty {
            let maxRow = placed.map { $0.row + $0.rowSpan - 1 }.max() ?? 0
            topRowBlockIDs = Set(placed.filter { $0.row + $0.rowSpan - 1 == maxRow }.map(\.id))
            foundationBlockIDs = Set(placed.filter { $0.row == 0 }.map(\.id))
        } else {
            topRowBlockIDs = []
            foundationBlockIDs = []
        }

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

        totalRows = placed.isEmpty ? 0 : placed.map { $0.row + $0.rowSpan }.max()!

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

        isLoading = false

        // Clear the dropped set after animation window
        if !newlyDroppedIDs.isEmpty {
            let droppedCopy = newlyDroppedIDs
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                self.newlyDroppedIDs.subtract(droppedCopy)
                for id in droppedCopy {
                    self.staggerDelayCache.removeValue(forKey: id)
                }
            }
        }

        return newlyDroppedIDs
    }

    // MARK: - Day Separators

    func computeDaySeparators(perfectDayDates: Set<String>) {
        guard !placedBlocks.isEmpty else { daySeparators = []; return }

        // Group blocks by dateString
        var blocksByDate: [String: [PlacedBlock]] = [:]
        for block in placedBlocks {
            blocksByDate[block.log.dateString, default: []].append(block)
        }

        // Sort dates
        let sortedDates = blocksByDate.keys.sorted()
        guard sortedDates.count > 1 else { daySeparators = []; return }

        var separators: [DaySeparator] = []
        for (index, dateStr) in sortedDates.enumerated() {
            guard index > 0 else { continue } // No separator before first day
            let blocks = blocksByDate[dateStr] ?? []
            let minRow = blocks.map(\.row).min() ?? 0
            let displayLabel = BlockTimeFormatter.dateLabel(from: dateStr)

            separators.append(DaySeparator(
                id: dateStr,
                displayLabel: displayLabel,
                blockCount: blocks.count,
                isPerfectDay: perfectDayDates.contains(dateStr),
                gridRow: minRow
            ))
        }

        daySeparators = separators
    }

    func staggerDelay(for block: PlacedBlock) -> Double {
        staggerDelayCache[block.id] ?? 0
    }

    // MARK: - Ghost Block Preview (Kliegel 2008 — external prospective memory aid)

    func computeGhostPosition(for blockSize: BlockSize) -> (column: Int, row: Int)? {
        var gridCopy = currentGrid
        return findPosition(columnSpan: blockSize.columnSpan, rowSpan: blockSize.rowSpan, grid: &gridCopy)
    }

    // MARK: - Boolean Grid Matrix Packing

    /// Scans the boolean grid from row 0 (bottom) upward to find the first
    /// position where a block of the given span fits with zero gaps.
    private func findPosition(
        columnSpan: Int,
        rowSpan: Int,
        grid: inout [[Bool]]
    ) -> (column: Int, row: Int)? {
        let colCount = GridConstants.columnCount
        let maxStartCol = colCount - columnSpan
        guard maxStartCol >= 0 else { return nil }

        // Scan from row 0 (bottom / foundation) upward
        var row = 0
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
