import Foundation
import SwiftData
import UserNotifications

/// Which period's window is open right now: the NOTIFICATION rule.
///
/// It used to be the Wins tab's replay pill as well. The pill is deleted
/// (2026-10-01, the owner: "the your month doesnt belong on the wins because
/// its already in memories"), so this decides one thing now, and the screen
/// has its own rule in `ReplayShelfModel.live(in:besides:now:)`.
///
/// **The two rules disagree on purpose, and the disagreement is the point.**
enum ReplayEntry {
    /// **The month wins over the week on a day both are open, because a
    /// notification is an interruption and the rarer event earns it.**
    ///
    /// The old reason written here was "the week is on its shelf either way",
    /// and that is no longer true: the week is on no shelf. What replaced it
    /// is the Memories row, and `ReplayShelfModel.live` inverts this tie for
    /// exactly that reason. The month there is one named tap away in the
    /// picker directly above the row, so the row spends itself on the week;
    /// here there is no picker and nothing else will offer the month at all.
    static func live(now: Date, calendar: Calendar = .current, hasWins: (ReplayPeriod) -> Bool) -> ReplayPeriod? {
        if let m = ReplayPeriod.current(.month, at: now, calendar: calendar), hasWins(m) { return m }
        if let w = ReplayPeriod.current(.week, at: now, calendar: calendar), hasWins(w) { return w }
        return nil
    }

    /// The next moment after `now` that a week's or a month's window opens or
    /// closes: when the offer may have to appear or leave with the app open.
    /// `MainAppView` sleeps until it, once, rather than polling, and
    /// re-schedules the notifications there.
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

    /// **The body, written ONCE and not twice** (`docs/copy-audit.md` cut 17,
    /// 2026-10-01). It was "Seven days of wins, stacked into one tower." and
    /// "A month of wins, stacked into one tower." — 16 words, which is one
    /// sentence written twice with the length changed, and the length is the
    /// only thing the two titles already differ by. The audit classed both as
    /// Explanation and proposed cutting them outright: a notification body that
    /// describes the feature is the push equivalent of a caption under a
    /// picture.
    ///
    /// **It is trimmed rather than cut, for a reason the audit could not see
    /// from the strings.** It wrote that the thing described is "one tap away".
    /// It is not: there is no notification-response handler anywhere in the app
    /// (`grep didReceive` over `Strata/` and `Shared/` finds only a memory
    /// warning), so tapping this opens the app on the Wins tower, where nothing
    /// is "ready" and nothing says where to look. The title carries the news and
    /// the body now carries the only fact the title cannot and the app does not
    /// otherwise deliver. 16 words to 4.
    ///
    /// "Find it in …" is the app's own construction for this, not a new one:
    /// `OnboardingView`'s head page says "Find it in Profile, and on your
    /// photos."
    ///
    /// **If a deep link is ever added, cut this line.** At that point the tap
    /// lands on the replay and the sentence is describing a journey the person
    /// has already finished, which is cut 17 as written.
    private static let whereToLook = "Find it in Memories."

    static func upcoming(now: Date, calendar: Calendar = .current,
                         hasWins: (ReplayPeriod) -> Bool) -> [(period: ReplayPeriod, date: Date, title: String, body: String)] {
        let week = ReplayPeriod.week(containing: now, calendar: calendar)
        let month = ReplayPeriod.month(containing: now, calendar: calendar)
        let monthName = month.range(relativeTo: month.firstDay)
        return [
            (week, week.notificationDate, "Your week is ready", Self.whereToLook),
            (month, month.notificationDate, "\(monthName) is ready", Self.whereToLook)
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
