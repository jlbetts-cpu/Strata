import Foundation
import SwiftData
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
    static let prefix = NotificationRoute.Prefix.daily
    /// The repeating request earlier builds scheduled. Removed wherever this
    /// schedules, so an upgrade does not remind twice.
    static let legacy = NotificationRoute.Prefix.dailyLegacy

    /// **A cue, not a register** (the owner, 2026-10-05: "notifications
    /// signal witness, not attendance", his rule since May 2026).
    ///
    /// It was "Nothing on today's tower yet" over "Anything you finished
    /// counts.": a title that announced what was MISSING, which is a
    /// register being called, and then the kind sentence underneath as an
    /// apology for it. The kind sentence is the whole notification now, and
    /// there is no body, because anything under it would have to be about
    /// the day and the only fact about the day is the absence. The logic is
    /// unchanged: it still comes only on a day with nothing on the tower.
    static let title = "Anything you finished counts."

    // MARK: Logging from the reminder (the owner, 2026-10-06)
    //
    // Long-press the reminder and the three sizes are there: the win lands on
    // today's tower without the app opening, which is help at the point of
    // performance (Barkley) rather than one more thing to open. The action
    // runs the same `QuickLog` the widget and Control Center use, so it is
    // the same win, posted the same way.

    static let category = "strata.reminder.log"
    static let actions: [String: QuickLogSize] = [
        "strata.log.quick": .quick, "strata.log.regular": .regular, "strata.log.deep": .deep,
    ]

    /// The reminder's actions, in size order. The words are the add sheet's
    /// own size names.
    static var notificationCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: category,
            actions: [
                UNNotificationAction(identifier: "strata.log.quick", title: "Quick", options: []),
                UNNotificationAction(identifier: "strata.log.regular", title: "Regular", options: []),
                UNNotificationAction(identifier: "strata.log.deep", title: "Deep", options: []),
            ],
            intentIdentifiers: [],
            options: []
        )
    }
    static let body = ""

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
            content.threadIdentifier = NotificationRoute.Thread.daily
            content.categoryIdentifier = category
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

/// **The evening's one question** (2026-10-06: testers log one or two wins a
/// day, and after the first, nothing ever asked again).
///
/// "Anything else today?" at 7pm, the in-app cue's own words (`WinCue`), with
/// the reminder's Quick, Regular and Deep to log without opening the app. It
/// keeps the app's rule of ONE cue a day, whichever way it comes (more
/// notifications measurably worsen inattention: Kushlev, Proulx and Dunn,
/// CHI 2016), so it comes only on a day that:
/// - has one or two wins (none is the morning reminder's day; three or more
///   is a good day, left alone);
/// - did not get the morning reminder (its first win came before it fired);
/// - did not already see the cue on the tower.
/// Reminders off in Settings is off for this too.
nonisolated enum EveningCheckIn {
    static let prefix = NotificationRoute.Prefix.evening
    static let hour = 19
    static let title = WinCue.anythingElse

    /// When today's should come, or nil for none.
    static func when(winsToday: Int, firstWin: Date?, now: Date, morningHour: Int, morningMinute: Int,
                     cueSeenToday: Bool, calendar: Calendar = .current) -> Date? {
        guard (1...WinCue.elseUpTo).contains(winsToday), !cueSeenToday, let firstWin,
              let evening = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now), evening > now,
              let morning = calendar.date(bySettingHour: morningHour, minute: morningMinute, second: 0, of: now)
        else { return nil }
        // The morning reminder fired if the day was still empty at its time.
        guard firstWin < morning else { return nil }
        return evening
    }

    static func identifier(for date: Date) -> String { prefix + DateUtils.dateString(from: date) }

    /// Today's decided again, from the store: after a win, and when the cue
    /// has been seen on the tower.
    @MainActor
    static func update(context: ModelContext, now: Date = Date()) async {
        let defaults = UserDefaults.standard
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: now)])
        guard defaults.bool(forKey: "notificationsEnabled") else { return }
        let today = DateUtils.dateString(from: now)
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString == today && $0.completed }))) ?? []
        let hour = defaults.object(forKey: "reminderHour") as? Int ?? 8
        let minute = defaults.object(forKey: "reminderMinute") as? Int ?? 0
        guard let at = when(winsToday: logs.count, firstWin: logs.compactMap(\.completedAt).min(), now: now,
                            morningHour: hour, morningMinute: minute,
                            cueSeenToday: defaults.string(forKey: WinCue.defaultsKey) == today)
        else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.threadIdentifier = NotificationRoute.Thread.daily
        content.categoryIdentifier = DailyReminder.category
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        try? await center.add(UNNotificationRequest(
            identifier: identifier(for: at), content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
}
