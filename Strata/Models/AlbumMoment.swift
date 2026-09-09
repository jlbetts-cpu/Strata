import Foundation

/// Albums that exist because of *when* something happened.
///
/// Snapchat's Memories opens on a Flashback whenever you have a saved snap at
/// least a year old **to the day**, and it titles the story by what is in it
/// rather than by the date. Apple Photos does the same trick under "On This
/// Day". The mechanic is worth copying because it needs nothing from the user:
/// the calendar does the curating, so the screen has something to show on a
/// day you have not opened it in months.
///
/// Three rules, and no more. Each one answers a question somebody actually
/// asks — *what was I doing exactly a year ago / around this time last year /
/// last month* — and anything past that is a feature looking for a use.
///
/// The rules are values, not stored data: every one is recomputed from the
/// record, so a moment can never go stale and nothing has to be migrated when
/// a rule changes.
enum AlbumMoment: Hashable {
    /// The same calendar date, `years` back. Snapchat's rule exactly.
    case onThisDay(years: Int)
    /// The same week of the year, one year back.
    case weekLastYear
    /// The whole of the previous calendar month.
    case lastMonth

    /// How many years back `onThisDay` will look. Three is where it stops
    /// being a memory and starts being an archive.
    static let maxYearsBack = 3

    /// Every rule worth evaluating, newest feeling first.
    static var all: [AlbumMoment] {
        (1...maxYearsBack).map { AlbumMoment.onThisDay(years: $0) } + [.weekLastYear, .lastMonth]
    }

    /// A stable id, so a moment can be a navigation route rather than a
    /// payload — the same reason `DayRoute` carries a date string and not an
    /// album.
    var id: String {
        switch self {
        case .onThisDay(let years): return "onThisDay:\(years)"
        case .weekLastYear:         return "weekLastYear"
        case .lastMonth:            return "lastMonth"
        }
    }

    init?(id: String) {
        if id == "weekLastYear" { self = .weekLastYear; return }
        if id == "lastMonth" { self = .lastMonth; return }
        let parts = id.split(separator: ":")
        guard parts.count == 2, parts[0] == "onThisDay", let years = Int(parts[1]) else { return nil }
        self = .onThisDay(years: years)
    }

    /// What the card calls it.
    func title(calendar: Calendar, now: Date) -> String {
        switch self {
        case .onThisDay(let years):
            return years == 1 ? "A year ago today" : "\(years) years ago today"
        case .weekLastYear:
            return "This week last year"
        case .lastMonth:
            guard let date = calendar.date(byAdding: .month, value: -1, to: now) else { return "Last month" }
            let df = DateFormatter()
            df.dateFormat = "MMMM"
            return df.string(from: date)
        }
    }

    /// Whether a win belongs to this moment.
    ///
    /// Date arithmetic through `Calendar` rather than by subtracting seconds:
    /// a year is not 365 days, a month is not 30, and the day this is wrong on
    /// is the day somebody notices.
    func contains(_ date: Date, calendar: Calendar, now: Date) -> Bool {
        switch self {
        case .onThisDay(let years):
            guard let then = calendar.date(byAdding: .year, value: -years, to: now) else { return false }
            return calendar.isDate(date, inSameDayAs: then)

        case .weekLastYear:
            guard let then = calendar.date(byAdding: .year, value: -1, to: now),
                  let week = calendar.dateInterval(of: .weekOfYear, for: then) else { return false }
            return week.contains(date)

        case .lastMonth:
            guard let then = calendar.date(byAdding: .month, value: -1, to: now),
                  let month = calendar.dateInterval(of: .month, for: then) else { return false }
            return month.contains(date)
        }
    }
}

extension Album {
    /// How many photographs a moment needs before it earns a card.
    ///
    /// Three, not the five a repeated interest needs. A moment is rarer and
    /// its claim is smaller — it says "this is when", not "this is a thing you
    /// keep doing" — and three is what fills the cover's fan. Below that there
    /// is nothing behind the card.
    static let minMomentPhotos = 3

    /// The time-based cards, newest feeling first.
    ///
    /// These lead the shelf, the way a Flashback leads Snapchat's Memories:
    /// they are the only albums that appear without you having done anything
    /// to make them, so they are the reason the screen is worth opening on a
    /// day you have not logged anything.
    static func moments(from records: [WinRecord],
                        calendar: Calendar,
                        now: Date) -> [Album] {
        AlbumMoment.all.compactMap { moment in
            let matching = records
                .filter { $0.hasPhoto && moment.contains($0.completedAt, calendar: calendar, now: now) }
                .sorted { $0.completedAt > $1.completedAt }
            guard matching.count >= minMomentPhotos else { return nil }

            let photos = matching.compactMap(\.photoFileName)
            let title = moment.title(calendar: calendar, now: now)
            return Album(
                id: "moment:\(moment.id)",
                kind: .moment(moment.id),
                title: title,
                subtitle: "\(photos.count) PHOTOS",
                sortDate: matching.first?.completedAt ?? .distantPast,
                photoFileNames: photos,
                winCount: matching.count,
                haystack: title.lowercased()
            )
        }
    }
}
