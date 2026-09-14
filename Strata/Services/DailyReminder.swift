import Foundation
import UserNotifications

/// **The daily reminder, only on a day with nothing on the tower yet.**
///
/// It used to be one repeating notification at a fixed time, every day, with
/// the words "Time to build / Your tower is ready for a new block" — so on a
/// day you had already logged three wins, it still arrived to tell you to go
/// and log one. A reminder that fires after the thing it reminds you of is
/// done teaches you to ignore it.
///
/// So it is scheduled as single notifications, one per day for the next two
/// weeks, and a day's is taken back the moment that day has a win. Opening the
/// app tops the fortnight up. Somebody who does not open Strata for two weeks
/// stops being reminded, which is the right end for a nudge nobody answered.
nonisolated enum DailyReminder {
    /// How many days ahead are scheduled. iOS keeps at most 64 pending for an
    /// app; this leaves room for everything else.
    static let horizon = 14
    static let prefix = "strata.reminder."
    /// The repeating request earlier builds scheduled. Removed wherever this
    /// schedules, so an upgrade does not remind twice.
    static let legacy = "strata.daily.reminder"

    static let title = "Nothing on today's tower yet"
    static let body = "Anything you finished counts."

    /// The days to remind on, at `hour`:`minute`: the next `horizon` days,
    /// without today if today already has a win or the time has gone.
    static func days(from now: Date, hour: Int, minute: Int, loggedToday: Bool,
                     calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: now)
        return (0..<horizon).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { return nil }
            if offset == 0, loggedToday || at <= now { return nil }
            return at
        }
    }

    static func identifier(for date: Date, calendar: Calendar = .current) -> String {
        prefix + DateUtils.dateString(from: date)
    }

    /// Replaces whatever is pending with the next fortnight.
    static func schedule(hour: Int, minute: Int, loggedToday: Bool) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
        await removePending()
        for at in days(from: Date(), hour: hour, minute: minute, loggedToday: loggedToday) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            let request = UNNotificationRequest(
                identifier: identifier(for: at),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }

    /// Today has a win, so today's reminder has nothing to say.
    static func skipToday() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: Date())])
    }

    /// Every reminder this app has pending, the old repeating one included.
    static func removePending() async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) || $0 == legacy }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
