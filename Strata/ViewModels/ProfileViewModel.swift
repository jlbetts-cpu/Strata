import Foundation
import Observation
import SwiftData

/// The facts on Profile: the streak, and wins per day, week and month.
///
/// One fetch, the same one `MainAppView.refreshStreak` makes — completed rows
/// only, a 400-day horizon, only `dateString` materialised — so the streak on
/// Profile and the streak the milestones read can never disagree about which
/// days count. Never `MainAppView`'s own query, which is narrowed to the
/// current month on purpose.
///
/// All three views of the chart are worked out at load, so switching between
/// Day, Week and Month is instant rather than a recount per tap.
@Observable
@MainActor
final class ProfileViewModel {
    private(set) var currentStreak = 0
    private(set) var bestStreak = 0
    private var barsByUnit: [WinTrend.Unit: [WinTrend.Bar]] = [:]
    private var summaryByUnit: [WinTrend.Unit: WinTrend.Summary] = [:]

    func bars(_ unit: WinTrend.Unit) -> [WinTrend.Bar] { barsByUnit[unit] ?? [] }
    func summary(_ unit: WinTrend.Unit) -> WinTrend.Summary { summaryByUnit[unit] ?? WinTrend.Summary(kind: .empty) }

    func load(context: ModelContext, today: Date = Date()) {
        let horizon = Calendar.current.date(byAdding: .day, value: -400, to: today)
            .map { DateUtils.dateString(from: $0) } ?? ""
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.completed && $0.dateString >= horizon }
        )
        descriptor.propertiesToFetch = [\.dateString]
        guard let logs = try? context.fetch(descriptor) else { return }

        var counts: [String: Int] = [:]
        for log in logs { counts[log.dateString, default: 0] += 1 }

        for unit in WinTrend.Unit.allCases {
            barsByUnit[unit] = WinTrend.bars(dayCounts: counts, unit: unit, today: today)
            summaryByUnit[unit] = WinTrend.summary(dayCounts: counts, unit: unit, today: today)
        }
        currentStreak = Streaks.current(among: counts.keys, today: today)
        // Best can never read lower than current. They are the same run on
        // the day a record is being set, and a "best" under "current" would
        // be the page contradicting itself.
        bestStreak = max(Streaks.longest(among: counts.keys), currentStreak)
    }
}
