import Foundation
import SwiftData
import UserNotifications

/// **A past ordinary win, brought back** (the owner picked it from the
/// 2026-10-05 research: people underestimate how much they will enjoy
/// rediscovering ordinary moments, and savouring is worth a moderate effect,
/// g = 0.51, across 20 trials).
///
/// One win a day, the same one all day: the same date a year or more back
/// if there is one ("A year ago today: Morning run"), otherwise an ordinary
/// win from at least four weeks ago, chosen by the date so it does not change
/// each time the page opens. Only named wins: a nameless block has nothing
/// to say.
///
/// It is a line under the Memories calendar, in the photo count's quiet
/// grey, not a card (the owner: "I dont want to add a ui element if its not
/// gonna fit the system"). And one notification in the evening, only on a day
/// that already has a win.
nonisolated enum PastWin {
    struct Pick: Equatable, Sendable {
        let title: String
        let dateString: String
        /// "A year ago today", or the date ("March 4, 2025").
        let when: String
        var line: String { "\(when): \(title)" }
    }

    struct Candidate: Sendable {
        let title: String
        let dateString: String
    }

    /// The youngest a past win can be, so it reads as a memory and not as
    /// last week.
    static let minimumAgeDays = 28

    static func pick(from candidates: [Candidate], today: Date, calendar: Calendar) -> Pick? {
        let todayKey = DateUtils.dateString(from: today)
        let named = candidates.filter { !$0.title.isEmpty && $0.title != QuickWinService.untitled }
        // The same date, a year or more back.
        for years in 1...AlbumMoment.maxYearsBack {
            guard let then = calendar.date(byAdding: .year, value: -years, to: today) else { continue }
            let key = DateUtils.dateString(from: then)
            let thatDay = named.filter { $0.dateString == key }.sorted { $0.title < $1.title }
            if !thatDay.isEmpty {
                let chosen = thatDay[Int(stableHash(todayKey) % UInt64(thatDay.count))]
                return Pick(title: chosen.title, dateString: key,
                            when: years == 1 ? "A year ago today" : "\(years) years ago today")
            }
        }
        // Otherwise any ordinary win old enough to be a memory.
        guard let cutoffDate = calendar.date(byAdding: .day, value: -minimumAgeDays, to: today) else { return nil }
        let cutoff = DateUtils.dateString(from: cutoffDate)
        let old = named.filter { $0.dateString <= cutoff }
            .sorted { ($0.dateString, $0.title) < ($1.dateString, $1.title) }
        guard !old.isEmpty else { return nil }
        let chosen = old[Int(stableHash(todayKey) % UInt64(old.count))]
        return Pick(title: chosen.title, dateString: chosen.dateString,
                    when: dateWords(chosen.dateString, today: today, calendar: calendar))
    }

    /// "March 4", or "March 4, 2025" when it was another year.
    ///
    /// A caption, so its own shape, but the year is `DayTitle`'s rule and is
    /// asked of it (the cohesion pass, 2026-10-05): a caption and the title
    /// of the page it opens must never disagree about whether the year shows.
    static func dateWords(_ key: String, today: Date, calendar: Calendar) -> String {
        guard let date = DateUtils.date(from: key) else { return key }
        var style = Date.FormatStyle.dateTime.month(.wide).day()
        if DayTitle.showsYear(date, now: today, calendar: calendar) {
            style = style.year()
        }
        return date.formatted(style)
    }

    /// The same number for the same day on every launch (Swift's `hashValue`
    /// is seeded per process).
    static func stableHash(_ text: String) -> UInt64 {
        text.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
    }

    /// Every named win's title and day, from the store.
    @MainActor
    static func candidates(context: ModelContext) -> [Candidate] {
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed })
        d.relationshipKeyPathsForPrefetching = [\.habit]
        return ((try? context.fetch(d)) ?? []).compactMap { log in
            guard let title = log.habit?.title else { return nil }
            return Candidate(title: title, dateString: log.dateString)
        }
    }
}

/// The evening notification: today's past win, at 8pm, only once today has a
/// win of its own and only while the switch in Settings is on.
enum PastWinReminder {
    static let defaultsKey = "pastWinRemindersOn"
    static let prefix = NotificationRoute.Prefix.pastWin
    static let hour = 20

    static var isEnabled: Bool {
        UserDefaults.standard.register(defaults: [defaultsKey: true])
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    @MainActor
    static func schedule(context: ModelContext, now: Date = Date()) async {
        await removePending()
        guard isEnabled else { return }
        let calendar = Calendar.current
        let today = DateUtils.dateString(from: now)
        let loggedToday = ((try? context.fetchCount(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString == today && $0.completed }))) ?? 0) > 0
        guard loggedToday,
              let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now), at > now,
              let pick = PastWin.pick(from: PastWin.candidates(context: context), today: now, calendar: calendar)
        else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = pick.when
        content.body = pick.title
        // **Passive, deliberately** (the cohesion pass, 2026-10-05). A past
        // win is something to enjoy when you next look, never something to
        // look at now: it arrives silently into Notification Center and the
        // Lock Screen, without lighting the screen or making a sound, and it
        // never breaks through a Focus. The research it came from is about
        // savouring, and nobody savours an interruption.
        content.interruptionLevel = .passive
        content.threadIdentifier = NotificationRoute.Thread.pastWin
        // A tap lands on that day in Memories (`NotificationRoute`).
        content.userInfo = [NotificationRoute.dayKey: pick.dateString]
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        try? await center.add(UNNotificationRequest(
            identifier: prefix + today, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }

    static func removePending() async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
