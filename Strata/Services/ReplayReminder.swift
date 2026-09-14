import Foundation
import SwiftData
import UserNotifications

/// Whether the Wins tab shows a replay pill right now, and for which period.
enum ReplayEntry {
    /// The month wins over the week on a day both are open: it is the rarer
    /// event, and the week is on its shelf either way.
    static func live(now: Date, calendar: Calendar = .current, hasWins: (ReplayPeriod) -> Bool) -> ReplayPeriod? {
        if let m = ReplayPeriod.current(.month, at: now, calendar: calendar), hasWins(m) { return m }
        if let w = ReplayPeriod.current(.week, at: now, calendar: calendar), hasWins(w) { return w }
        return nil
    }

    /// The next moment after `now` that a week's or a month's window opens or
    /// closes: when the pill may have to appear or leave with the app open.
    /// The Wins tab sleeps until it, once, rather than polling.
    static func nextEdge(after now: Date, calendar: Calendar = .current) -> Date? {
        var edges: [Date] = []
        for step in [-1, 0, 1] {
            if let d = calendar.date(byAdding: .day, value: 7 * step, to: now) {
                let w = ReplayPeriod.week(containing: d, calendar: calendar)
                edges += [w.windowOpens, w.windowCloses]
            }
            if let d = calendar.date(byAdding: .month, value: step, to: now) {
                let m = ReplayPeriod.month(containing: d, calendar: calendar)
                edges += [m.windowOpens, m.windowCloses]
            }
        }
        return edges.filter { $0 > now }.min()
    }
}

/// The Sunday and 1st-of-the-month notifications.
///
/// Only when reminders are already allowed, only when the period has a win,
/// and re-decided every time the app becomes active, the way `DailyReminder`
/// tops itself up.
enum ReplayReminder {
    static let defaultsKey = "replayRemindersOn"
    static let prefix = "strata.replay."

    static var isEnabled: Bool {
        get {
            UserDefaults.standard.register(defaults: [defaultsKey: true])
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static func upcoming(now: Date, calendar: Calendar = .current,
                         hasWins: (ReplayPeriod) -> Bool) -> [(period: ReplayPeriod, date: Date, title: String, body: String)] {
        let week = ReplayPeriod.week(containing: now, calendar: calendar)
        let month = ReplayPeriod.month(containing: now, calendar: calendar)
        let monthName = month.range(relativeTo: month.firstDay)
        return [
            (week, week.notificationDate, "Your week is ready", "Seven days of wins, stacked into one tower."),
            (month, month.notificationDate, "\(monthName) is ready", "A month of wins, stacked into one tower.")
        ]
        .filter { $0.1 > now && hasWins($0.0) }
        .map { (period: $0.0, date: $0.1, title: $0.2, body: $0.3) }
    }

    @MainActor
    static func schedule(context: ModelContext) async {
        await removePending()
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for item in upcoming(now: Date(), hasWins: { ReplayLoader.hasWins($0, context: context) }) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            try? await center.add(UNNotificationRequest(
                identifier: prefix + item.period.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
    }

    static func removePending() async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
