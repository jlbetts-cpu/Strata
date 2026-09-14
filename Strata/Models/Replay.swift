import CoreGraphics
import Foundation
import SwiftData

/// Where a replay block's photograph comes from: the user's own store, or the
/// app bundle (the Settings preview's sample wins).
enum ReplayPhoto: Hashable {
    case stored(String)
    case bundled(String)

    var key: String {
        switch self {
        case .stored(let name): "stored:" + name
        case .bundled(let name): "bundled:" + name
        }
    }
}

/// One win, as a replay needs it. A value, so the replay, its script and its
/// tests never touch `@Model`; only `Replay.wins(from:)` does.
struct ReplayWin: Identifiable, Equatable {
    let id: UUID
    let dateString: String
    let completedAt: Date
    let title: String
    /// `habit.displayCategory`: the colour the block is drawn in.
    let category: HabitCategory
    let size: BlockSize
    let photo: ReplayPhoto?
    var crop: CGPoint = .zero
}

/// A period's wins, ordered and packed into one tower.
struct Replay: Equatable {

    struct Block: Identifiable, Equatable {
        let win: ReplayWin
        /// Index into `period.days`.
        let day: Int
        let column: Int
        let row: Int
        var id: UUID { win.id }
        var columnSpan: Int { win.size.columnSpan }
        var rowSpan: Int { win.size.rowSpan }
    }

    let period: ReplayPeriod
    /// In drop order: by day, then by the time the win was logged.
    let blocks: [Block]
    let rows: Int
    let countsByDay: [Int]
    var count: Int { blocks.count }

    init(period: ReplayPeriod, wins: [ReplayWin]) {
        self.period = period
        let dayIndex = Dictionary(uniqueKeysWithValues: period.days.enumerated().map { ($1, $0) })
        let ordered = wins
            .compactMap { w in dayIndex[w.dateString].map { (day: $0, win: w) } }
            .sorted { ($0.day, $0.win.completedAt) < ($1.day, $1.win.completedAt) }

        var grid: [[Bool]] = []
        var out: [Block] = []
        var counts = Array(repeating: 0, count: period.days.count)
        for item in ordered {
            // The same first-fit scan the tower runs, so this is the app's
            // arrangement and not one that resembles it.
            guard let spot = GridPacker.firstFit(columnSpan: item.win.size.columnSpan,
                                                 rowSpan: item.win.size.rowSpan,
                                                 columns: GridConstants.columnCount,
                                                 grid: &grid) else { continue }
            out.append(Block(win: item.win, day: item.day, column: spot.column, row: spot.row))
            counts[item.day] += 1
        }
        blocks = out
        rows = grid.lastIndex { $0.contains(true) }.map { $0 + 1 } ?? 0
        countsByDay = counts
    }

    /// One true fact about the period, or nil when there is nothing in it.
    ///
    /// Deliberately one fact. No streaks, no comparison, no score: a replay
    /// that grades you is one people stop opening.
    func sentence() -> String? {
        guard let top = countsByDay.max(), top > 0 else { return nil }
        let busiest = countsByDay.indices.filter { countsByDay[$0] == top }
        let daysWithWins = countsByDay.filter { $0 > 0 }.count
        if daysWithWins == 1 {
            return "All on \(period.dayName(busiest[0], capitalised: false))."
        }
        switch busiest.count {
        case 1:
            return "\(period.dayName(busiest[0], capitalised: true)) was your biggest day."
        case 2:
            return "\(period.dayName(busiest[0], capitalised: true)) and \(period.dayName(busiest[1], capitalised: false)) were your biggest days."
        default:
            let words = [3: "Three", 4: "Four", 5: "Five", 6: "Six", 7: "Seven"]
            let n = words[busiest.count] ?? String(busiest.count)
            return "\(n) days tied for your biggest."
        }
    }

    /// What VoiceOver says once, at the close: "Your week, 7 to 13 September.
    /// 31 wins. Thursday was your biggest day." The build is visual, so the
    /// replay speaks its result rather than every landing.
    func announcement(now: Date) -> String {
        [period.title + ", " + period.range(relativeTo: now),
         "\(count) \(count == 1 ? "win" : "wins")",
         // The sentence carries its own full stop; the join adds them all.
         sentence().map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }]
            .compactMap { $0 }
            .joined(separator: ". ") + "."
    }

    /// The only function here that touches `@Model`.
    static func wins(from logs: [HabitLog]) -> [ReplayWin] {
        logs.compactMap { log in
            guard log.completed, !log.skipped, let habit = log.habit else { return nil }
            return ReplayWin(
                id: log.id,
                dateString: log.dateString,
                completedAt: log.completedAt ?? .distantPast,
                title: habit.title,
                category: habit.displayCategory,
                size: habit.blockSize,
                photo: log.imageFileName.map { .stored($0) },
                crop: CGPoint(x: log.cropPositionX ?? 0, y: log.cropPositionY ?? 0)
            )
        }
    }
}

/// For `fullScreenCover(item:)`: one replay per period.
extension Replay: Identifiable {
    var id: String { period.id }
}
