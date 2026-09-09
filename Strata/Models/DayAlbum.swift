import Foundation

/// One day of the record, as something you can look at.
///
/// A day, not a week. A tower is a day — that is what the Wins tab shows — so
/// an album is the same unit, and weeks are only how the grid is sectioned.
///
/// A day produces an album only if it has a PHOTOGRAPH. The gaps are shown by
/// the month tower now, where a quiet day is a small block rather than an
/// absent card.
struct DayAlbum: Identifiable, Equatable {
    /// The `"yyyy-MM-dd"` string every log is grouped by.
    let id: String
    let date: Date
    /// "Today", "Yesterday", or the weekday.
    let title: String
    /// "6 SEP" — set uppercase and tracked at the view.
    let dateLabel: String
    /// The Monday of this day's week, which is the section it belongs to.
    let weekKey: String
    let winCount: Int
    /// Newest first. The cover fans the first three.
    let photoFileNames: [String]
    /// Lowercased title text plus every spelling of the date, so one substring
    /// scan answers "walk", "may", "14", "thursday" and "2026-05" alike.
    /// Precomputed because doing it per keystroke over a year of days is work
    /// nobody needs to repeat.
    let haystack: String

    var hasPhotos: Bool { !photoFileNames.isEmpty }
}

/// A week of albums, and the heading above them.
struct WeekSection: Identifiable, Equatable {
    /// The week's Monday, as a date string.
    let id: String
    /// "MAY 14–21".
    let title: String
    /// Newest day first.
    let albums: [DayAlbum]
}

/// Which day a screen is showing.
///
/// A route rather than the album itself, so the day screen fetches its own
/// logs and does not depend on what the grid happens to have paged in.
struct DayRoute: Hashable {
    let dateString: String
}
