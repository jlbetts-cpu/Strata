import Foundation
import QuartzCore

/// Reads the camera roll's next rows before they scroll into view, and stops
/// guessing while a fling is too fast for a guess to land in time.
/// (2026-09-16, `research-image-loading.md` §2.3.)
///
/// **Why it needs no scroll modifier.** A grid's cells appearing ARE the
/// scroll: which one appeared says where the page is, the order says which
/// way it is going, and how fast new rows appear says how fast. That works the
/// same in Memories (where the grid sits inside a larger scroll view, and
/// `onScrollGeometryChange` only reports the outermost) and in a place's own
/// page, and it costs no body evaluations — nothing here is observed.
///
/// **What it asks for.** `rowsAhead` rows past the newest cell, in the
/// direction of travel, on `ThumbnailStore`'s prefetch lane. Behind the
/// scroll, nothing; whatever it asked for that is now behind, or no longer in
/// the lead, is cancelled. Above `flingSpeed` it asks for nothing at all and
/// drops what it had asked: a decode that lands after its cell has gone is
/// pure waste, and it is exactly what would starve the cells where the fling
/// stops. The view asking while drawing is still what loads a picture; this is
/// only ever an extra, earlier ask.
final class GalleryPrefetcher {
    static let rowsAhead = 3
    static let columns = 3
    /// Points per second. A fling crosses a phone screen in about 150ms,
    /// which is ~5,800pt/s; a reading scroll is a few hundred.
    static let flingSpeed: Double = 2000

    enum Direction: Equatable { case down, up }

    /// What to ask for and what to drop after a cell appears. Pure, so the
    /// rule is tested without a grid.
    struct Plan: Equatable {
        var ask: [Int]
        var cancel: [Int]
    }

    private(set) var order: [String] = []
    private var index: [String: Int] = [:]
    private var lastIndex: Int?
    private(set) var direction: Direction = .down
    private var lead: Set<Int> = []
    private var recent: [(index: Int, at: CFTimeInterval)] = []
    /// Suspended by a fling, and when the last cell appeared: a fling that
    /// stops appears as nothing at all, so the grid asks `resumeIfSettled`
    /// a moment later to pick the lookahead back up.
    private(set) var isSuspended = false
    private var lastAppearAt: CFTimeInterval = 0
    /// A cell far from where the grid was, seen once. See `strayRows`.
    private var pendingJump: Int?

    /// Rows from the last cell past which an appearance is not believed on
    /// its own. SwiftUI occasionally re-appears a cell far away (the top of
    /// the roll while you are deep in it); taken at face value that reversed
    /// the direction and cancelled the whole lead. A second appearance near
    /// the first is a real jump (a scroll-to) and is followed.
    static let strayRows = 12

    /// Keeps the flat order in step with the sections, and forgets every
    /// index it held: they pointed into the old order. Returns the names it
    /// had asked for, for the caller to cancel.
    @discardableResult
    func update(_ names: [String]) -> [String] {
        guard names != order else { return [] }
        let dropped = lead.compactMap { $0 < order.count ? order[$0] : nil }
        order = names
        index = Dictionary(names.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        lead = []
        lastIndex = nil
        recent = []
        isSuspended = false
        pendingJump = nil
        return dropped
    }

    /// How fast the grid is moving, in points per second, from the cells that
    /// appeared in the last `window` seconds.
    static func speed(_ appearances: [(index: Int, at: CFTimeInterval)], rowHeight: Double,
                      now: CFTimeInterval, window: CFTimeInterval = 0.2) -> Double {
        let inWindow = appearances.filter { now - $0.at <= window }
        // Under 50ms apart is a screen's worth of cells built at once (the first
        // layout, a jump), not movement.
        guard let first = inWindow.first, let last = inWindow.last, last.at - first.at >= 0.05 else { return 0 }
        let rows = Double(abs(last.index / columns - first.index / columns))
        return rows * rowHeight / (last.at - first.at)
    }

    /// The pure rule. `lead` is what was asked for last time.
    static func plan(appeared: Int, previous: Int?, count: Int, lead: Set<Int>,
                     fast: Bool) -> (plan: Plan, direction: Direction, lead: Set<Int>) {
        let direction: Direction = (previous.map { appeared < $0 } ?? false) ? .up : .down
        guard !fast else {
            return (Plan(ask: [], cancel: lead.sorted()), direction, [])
        }
        let span = rowsAhead * columns
        let wanted: [Int]
        switch direction {
        case .down:
            // From the end of the appearing cell's row onwards.
            // Clamped at both ends: a cell in the last row has nothing after
            // it, and `rowEnd..<count` with rowEnd past count is a trap, not
            // an empty range. (Crashed `RealPhotoTests`, one photograph.)
            let rowEnd = min((appeared / columns + 1) * columns, count)
            wanted = Array(rowEnd..<min(count, rowEnd + span))
        case .up:
            let rowStart = (appeared / columns) * columns
            wanted = Array(max(0, rowStart - span)..<rowStart).reversed()
        }
        let next = Set(wanted)
        return (Plan(ask: wanted.filter { !lead.contains($0) },
                     cancel: lead.subtracting(next).sorted()), direction, next)
    }

    /// A cell has appeared. Returns the file names to prefetch and to cancel.
    func appeared(_ fileName: String, rowHeight: Double,
                  now: CFTimeInterval = CACurrentMediaTime()) -> (ask: [String], cancel: [String]) {
        guard let i = index[fileName] else { return ([], []) }
        // A jump back to where it was is a cell re-appearing at the edge, not
        // a change of direction; only a move of a whole row counts.
        if let last = lastIndex, abs(i / Self.columns - last / Self.columns) == 0 { return ([], []) }
        if let last = lastIndex, abs(i / Self.columns - last / Self.columns) > Self.strayRows {
            let confirmed = pendingJump.map { abs($0 / Self.columns - i / Self.columns) <= 1 } ?? false
            guard confirmed else { pendingJump = i; return ([], []) }
            // A real jump: start over from here, without a speed estimate
            // that spans the jump.
            recent = []
        }
        pendingJump = nil
        lastAppearAt = now
        recent.append((i, now))
        recent.removeAll { now - $0.at > 0.5 }
        let fast = Self.speed(recent, rowHeight: rowHeight, now: now) > Self.flingSpeed
        let result = Self.plan(appeared: i, previous: lastIndex, count: order.count, lead: lead, fast: fast)
        lastIndex = i
        direction = result.direction
        lead = result.lead
        isSuspended = fast
        #if DEBUG
        if fast { Task { @MainActor in PerfProbe.count("PrefetchSuspendedFling") } }
        #endif
        return (result.plan.ask.map { order[$0] }, result.plan.cancel.map { order[$0] })
    }

    /// After a fling: if no cell has appeared for `settle`, the grid has
    /// stopped, so ask for the lead from where it stopped.
    func resumeIfSettled(now: CFTimeInterval = CACurrentMediaTime(),
                         settle: CFTimeInterval = 0.25) -> [String] {
        guard isSuspended, let last = lastIndex, now - lastAppearAt >= settle else { return [] }
        isSuspended = false
        recent = []
        let previous = direction == .up ? last + Self.columns : max(0, last - Self.columns)
        let result = Self.plan(appeared: last, previous: previous, count: order.count, lead: lead, fast: false)
        lead = result.lead
        return result.plan.ask.map { order[$0] }
    }
}
