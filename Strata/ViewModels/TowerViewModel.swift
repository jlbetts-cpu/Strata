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
    var isLoading: Bool = true
    // Cascade drop tracking
    private(set) var newlyDroppedIDs: Set<UUID> = []
    private(set) var staggerDelayCache: [UUID: Double] = [:]
    private var previousBlockIDs: Set<UUID> = []
    private var dropCleanupTask: Task<Void, Never>? = nil

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
    func buildTower(from logs: [HabitLog]) -> Set<UUID> {
        // Boolean grid matrix: grid[row][col] = true means occupied
        var grid = [[Bool]]()

        // Place completed blocks (solid foundation), oldest first so newest land on top
        let completedLogs = logs
            .filter { $0.completed && $0.habit != nil }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

        var placed: [PlacedBlock] = []
        for log in completedLogs {
            guard let habit = log.habit else { continue }
            let colSpan = habit.blockSize.columnSpan
            let rowSpan = habit.blockSize.rowSpan

            if let pos = findPosition(columnSpan: colSpan, rowSpan: rowSpan, grid: &grid) {
                placed.append(PlacedBlock(
                    id: log.id,
                    habit: habit,
                    log: log,
                    column: pos.column,
                    row: pos.row,
                    columnSpan: colSpan,
                    rowSpan: rowSpan
                ))
            }
        }

        // Detect newly added blocks for cascade animation
        let newIDs = Set(placed.map(\.id))
        newlyDroppedIDs = newIDs.subtracting(previousBlockIDs)
        previousBlockIDs = newIDs

        placedBlocks = placed
        incompleteBlocks = []

        // Pre-compute stagger delays (O(1) lookup per block instead of O(n) per call)
        if !newlyDroppedIDs.isEmpty {
            let sortedNew = placed
                .filter { newlyDroppedIDs.contains($0.id) }
                .sorted { $0.row < $1.row }
            let count = max(sortedNew.count, 1)
            staggerDelayCache = [:]
            for (index, block) in sortedNew.enumerated() {
                let normalizedIndex = Double(index) / Double(count)
                let decelerated = pow(normalizedIndex, 0.7)
                staggerDelayCache[block.id] = min(decelerated * 0.4, 0.4)
            }
        }

        totalRows = grid.count
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

    func staggerDelay(for block: PlacedBlock) -> Double {
        staggerDelayCache[block.id] ?? 0
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
