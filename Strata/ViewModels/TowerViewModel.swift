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
    /// Per-block exposure: maps block ID → set of absolute column indices exposed to sky
    private(set) var blockExposure: [UUID: Set<Int>] = [:]

    // Cascade drop tracking
    private(set) var newlyDroppedIDs: Set<UUID> = []
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

    // MARK: - Build Unified Grid

    func buildTower(from logs: [HabitLog], incompleteHabits: [Habit]) {
        // Boolean grid matrix: grid[row][col] = true means occupied
        var grid = [[Bool]]()

        // 1. Place completed blocks first (solid foundation), oldest first so newest land on top
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

        // Compute per-column sky exposure using completed-only grid (before incomplete blocks)
        blockExposure = computeExposure(placed: placed, grid: grid)

        // 2. Place incomplete blocks on top (muted, above completed)
        var incomplete: [PlacedIncompleteBlock] = []
        for habit in incompleteHabits {
            let colSpan = habit.blockSize.columnSpan
            let rowSpan = habit.blockSize.rowSpan

            if let pos = findPosition(columnSpan: colSpan, rowSpan: rowSpan, grid: &grid) {
                incomplete.append(PlacedIncompleteBlock(
                    id: habit.id,
                    habit: habit,
                    column: pos.column,
                    row: pos.row,
                    columnSpan: colSpan,
                    rowSpan: rowSpan
                ))
            }
        }
        incompleteBlocks = incomplete

        totalRows = grid.count

        // Clear the dropped set after animation window
        if !newlyDroppedIDs.isEmpty {
            let droppedCopy = newlyDroppedIDs
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                self.newlyDroppedIDs.subtract(droppedCopy)
            }
        }
    }

    func staggerDelay(for block: PlacedBlock) -> Double {
        guard newlyDroppedIDs.contains(block.id) else { return 0 }
        let sortedNew = placedBlocks
            .filter { newlyDroppedIDs.contains($0.id) }
            .sorted { $0.row < $1.row }
        guard let index = sortedNew.firstIndex(where: { $0.id == block.id }) else { return 0 }
        return Double(index) * 0.05
    }

    /// Returns a per-segment boolean array for a block's columns.
    /// A 1-column block gets [Bool]; a 2-column block gets [Bool, Bool], etc.
    func exposedSegments(for block: PlacedBlock) -> [Bool] {
        let exposedCols = blockExposure[block.id] ?? []
        return (0..<block.columnSpan).map { offset in
            exposedCols.contains(block.column + offset)
        }
    }

    // MARK: - Sky Exposure Detection

    /// Per-column exposure: for each block, which of its columns have open sky above.
    private func computeExposure(
        placed: [PlacedBlock],
        grid: [[Bool]]
    ) -> [UUID: Set<Int>] {
        var result: [UUID: Set<Int>] = [:]

        for block in placed {
            let topRow = block.row + block.rowSpan
            var exposedCols = Set<Int>()

            for c in block.column..<(block.column + block.columnSpan) {
                if topRow >= grid.count || !grid[topRow][c] {
                    exposedCols.insert(c)
                }
            }

            if !exposedCols.isEmpty {
                result[block.id] = exposedCols
            }
        }
        return result
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
