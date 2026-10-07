import Foundation
import Observation

/// **A tap on a notification lands on its subject** (the cohesion pass,
/// 2026-10-05).
///
/// Until this, only a crew's notifications went anywhere: the delegate was
/// installed only with Crews on, and it read nothing but a crew. So "A year
/// ago today: Morning run" opened the app on the Wins tower, and "Your week
/// is ready" had to carry a body telling you where to look for it
/// (`ReplayReminder`'s "Find it in Memories.", cut now that the tap gets
/// there itself).
///
/// Pure, so the mapping is a test rather than a hope:
/// - a crew's (it carries `crew`): that crew, at its win;
/// - the past win (`PastWinReminder.prefix`): Memories, on that day;
/// - a replay (`ReplayReminder.prefix` + the period's id): Memories, playing it;
/// - the daily reminder (`DailyReminder.prefix`, or its old repeating id): Wins.
///
/// Read from the request's identifier first, so a notification scheduled by
/// a build from before this existed still lands; the past win's day is in
/// its `userInfo` because its identifier carries the day it was SENT.
nonisolated enum NotificationRoute: Equatable, Sendable {
    case crew(String, win: UUID?)
    case wins
    /// Memories, on its own page.
    case memories
    /// Memories, then that day (`yyyy-MM-dd`).
    case memoriesDay(String)
    /// Memories, with that replay playing. `kind` is "week" or "month" and
    /// `firstDay` its first day's key, which is how `ReplayPeriod.id` spells it.
    case replay(kind: String, firstDay: String)

    /// The `userInfo` key for the past win's day.
    static let dayKey = "day"

    static func of(identifier: String, userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        if let crew = userInfo["crew"] as? String {
            return .crew(crew, win: (userInfo["win"] as? String).flatMap(UUID.init(uuidString:)))
        }
        if identifier.hasPrefix(Prefix.pastWin) {
            if let day = userInfo[dayKey] as? String, !day.isEmpty { return .memoriesDay(day) }
            return .memories
        }
        if identifier.hasPrefix(Prefix.replay) {
            let id = String(identifier.dropFirst(Prefix.replay.count))
            guard let dash = id.firstIndex(of: "-") else { return .memories }
            let kind = String(id[..<dash])
            let first = String(id[id.index(after: dash)...])
            guard kind == "week" || kind == "month", first.count == 10 else { return .memories }
            return .replay(kind: kind, firstDay: first)
        }
        if identifier.hasPrefix(Prefix.daily) || identifier == Prefix.dailyLegacy
            || identifier.hasPrefix(Prefix.evening) { return .wins }
        return nil
    }

    /// The three local notifications' identifier prefixes, spelled once
    /// here so the router and the schedulers cannot drift. Each scheduler's
    /// own `prefix` is this string, and `NotificationRouteTests` holds them
    /// together.
    enum Prefix {
        static let daily = "strata.reminder."
        static let evening = "strata.evening."
        static let dailyLegacy = "strata.daily.reminder"
        static let pastWin = "strata.pastwin."
        static let replay = "strata.replay."
    }

    /// **One thread per kind** on the Lock Screen, so a week of reminders
    /// stacks as one pile and does not interleave with the past wins.
    enum Thread {
        static let daily = "strata.daily"
        static let pastWin = "strata.pastwin"
        static let replay = "strata.replay"
    }
}

/// Where a tapped notification asked the app to go, held until the screen
/// that can show it is there to take it. A cold launch from a notification
/// delivers the tap before the tab bar exists; the request waits here.
@MainActor
@Observable
final class LandingRouter {
    static let shared = LandingRouter()

    /// The tab half: set by the delegate, cleared by `MainAppView` once it
    /// has chosen the tab.
    var pending: NotificationRoute?
    /// The Memories half (a day, a replay), cleared by Memories once shown.
    var memories: NotificationRoute?
    /// Bumped by a tap on the Memories tab while already on it: back to
    /// this month, at the top (the cohesion pass, 2026-10-05).
    var memoriesReselected = 0

    func land(_ route: NotificationRoute) {
        switch route {
        case .memoriesDay, .replay: memories = route
        default: break
        }
        pending = route
    }
}
