import Foundation

/// **On this day** (the owner, 2026-10-12: "I feel like Snapchat does the
/// memories the best, being able to bring up previous memories from years
/// prior"). The design, what the others do, and the rubric this is held to
/// are in `docs/flashback.md`.
///
/// One album card, first on the Memories shelf, on the day it is true:
/// "A year ago today", with the real date under it. A press opens that
/// day. It is worked out from the wins that are there and never stored, so
/// it is gone at midnight and there is nothing to keep in step.
///
/// **A ladder, because nobody has years yet.** A year ago today needs a
/// year of the app, which no one has at launch. So: years ago first, then
/// six months, then one month, the furthest back that has a photo. Nothing
/// nearer than a month: that is last week, and the weekly replay is for it.
///
/// **The exact date, or nothing.** "A month ago today" on 31 March would be
/// 28 February with a caption that is not true. A date that has no
/// counterpart is skipped.
///
/// **Under a year, at most once a week.** Someone who photographs every day
/// would otherwise be shown one every day, and a thing that is always
/// there is furniture. A year or more ago always shows: it is once a year.
nonisolated enum Flashback {
    /// One rung of the ladder on a given day.
    struct Rung: Equatable {
        /// The day it looks back to, `yyyy-MM-dd`.
        var day: String
        var title: String
        /// Less than a year back: held to once a week.
        var underAYear: Bool
    }

    /// The titles, all of them: nothing else is ever shown.
    static func title(years: Int) -> String { years == 1 ? "A year ago today" : "\(years) years ago today" }
    static let sixMonths = "6 months ago today"
    /// His own line (the Launch Pack: "This day last month"). It was "A
    /// month ago today", written to match the years.
    static let oneMonth = "This day last month"
    /// What Settings calls every look back, once Never Show Past Days is
    /// chosen.
    static let familyName = "Past Days"

    /// How many days must pass between two flashbacks from under a year ago.
    static let quietDays = 7
    static let lastShownKey = "memories.flashback.lastUnderAYear"

    /// Today's rungs, the furthest back first. Only dates that exist.
    static func rungs(today: Date, calendar: Calendar, maxYears: Int = AlbumMoment.maxYearsBack) -> [Rung] {
        let day = calendar.component(.day, from: today)
        let month = calendar.component(.month, from: today)
        var out: [Rung] = []
        for years in stride(from: max(maxYears, 1), through: 1, by: -1) {
            guard let then = calendar.date(byAdding: .year, value: -years, to: today),
                  calendar.component(.day, from: then) == day,
                  calendar.component(.month, from: then) == month else { continue }
            out.append(Rung(day: DateUtils.dateString(from: then), title: title(years: years), underAYear: false))
        }
        for (months, title) in [(6, sixMonths), (1, oneMonth)] {
            guard let then = calendar.date(byAdding: .month, value: -months, to: today),
                  calendar.component(.day, from: then) == day else { continue }
            out.append(Rung(day: DateUtils.dateString(from: then), title: title, underAYear: true))
        }
        return out
    }

    /// The one flashback for today, or nil: the furthest rung back whose
    /// day has a photo. `lastUnderAYear` is the day one from under a year
    /// ago was last shown.
    static func pick(photoDays: Set<String>, today: Date, calendar: Calendar, lastUnderAYear: String?) -> Rung? {
        let todayKey = DateUtils.dateString(from: today)
        let quiet: Bool = {
            guard let last = lastUnderAYear, last != todayKey, let then = DateUtils.date(from: last) else { return false }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: then),
                                               to: calendar.startOfDay(for: today)).day ?? quietDays
            return days >= 0 && days < quietDays
        }()
        for rung in rungs(today: today, calendar: calendar) where photoDays.contains(rung.day) {
            if rung.underAYear, quiet { continue }
            return rung
        }
        return nil
    }

    /// The date under the title, as a card's caption reads one: "12 SEP",
    /// with the year when it is not this one.
    static func caption(for day: String, today: Date, calendar: Calendar) -> String {
        guard let date = DateUtils.date(from: day) else { return "" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: today)
        // The shelf's own formatters, so the month reads in the phone's
        // language as every other card's does.
        return Album.Formats.formatter(sameYear ? "d MMM" : "d MMM yyyy").string(from: date).uppercased()
    }

    /// The card, as any album on the shelf is one. Its kind is the day, so
    /// a press opens that day's page.
    static func album(records: [WinRecord], today: Date, calendar: Calendar, lastUnderAYear: String?) -> (album: Album, rung: Rung)? {
        let photographed = records.filter(\.hasPhoto)
        guard let rung = pick(photoDays: Set(photographed.map(\.dateString)), today: today, calendar: calendar,
                              lastUnderAYear: lastUnderAYear) else { return nil }
        let group = photographed.filter { $0.dateString == rung.day }
        guard !group.isEmpty else { return nil }
        let album = Album(id: "flashback:\(rung.day)",
                          kind: .day(rung.day),
                          title: rung.title,
                          subtitle: caption(for: rung.day, today: today, calendar: calendar),
                          sortDate: group.map(\.completedAt).max() ?? .distantPast,
                          photoFileNames: Album.coverOrder(for: group),
                          winCount: group.count,
                          haystack: rung.title.lowercased())
        return (album, rung)
    }
}
