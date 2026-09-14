import Foundation
import SwiftData

/// Fetches a period's wins for a replay.
///
/// `FetchDescriptor` over the `dateString` range, the way `MemoriesViewModel`
/// fetches a month: indexed, bounded, and never through `MainAppView`'s query,
/// which is deliberately narrowed to the current month.
///
/// Both fetches use the tower's rule, `Replay.isBlock`: completed or skipped,
/// with a habit. `hasWins` answering yes to a period whose `replay` then comes
/// back empty is how a pill could open an empty replay.
enum ReplayLoader {
    static func replay(for period: ReplayPeriod, context: ModelContext) -> Replay {
        guard let lo = period.days.first, let hi = period.days.last else { return Replay(period: period, wins: []) }
        var d = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString >= lo && $0.dateString <= hi && ($0.completed || $0.skipped) && $0.habit != nil }
        )
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? context.fetch(d)) ?? []
        return Replay(period: period, wins: Replay.wins(from: logs))
    }

    static func hasWins(_ period: ReplayPeriod, context: ModelContext) -> Bool {
        guard let lo = period.days.first, let hi = period.days.last else { return false }
        var d = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString >= lo && $0.dateString <= hi && ($0.completed || $0.skipped) && $0.habit != nil }
        )
        d.fetchLimit = 1
        return ((try? context.fetchCount(d)) ?? 0) > 0
    }
}
