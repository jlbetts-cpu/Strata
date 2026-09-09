import Foundation

/// One completed win, flattened off SwiftData.
///
/// The grouping below claims to be pure, and this is what makes that true.
/// `HistoryViewModel.sections(from:)` makes the same claim while taking
/// `[HabitLog]` — a `@Model`, which in practice needs a `Habit` and a
/// container to construct, so its tests are not really store-free. Flattening
/// at the boundary means everything downstream is a value function over value
/// types, testable with struct literals.
struct WinRecord: Equatable {
    let dateString: String
    let completedAt: Date
    let title: String
    /// `habit.displayCategory`, never `habit.category`. An uncategorised win
    /// would otherwise carry `.unlabeled`, which has no colour.
    let category: HabitCategory
    let size: BlockSize
    let photoFileName: String?

    var hasPhoto: Bool { photoFileName != nil }
}

/// What an album is about: a day, or a thing you keep doing.
enum AlbumKind: Hashable {
    /// `yyyy-MM-dd`.
    case day(String)
    /// A normalised title key — see `Album.titleKey`.
    case curated(String)
    /// A moment in time, by rule id — see `Album.Moment`.
    case moment(String)
}

/// Which album a screen is showing.
///
/// A route rather than the album itself, for the reason `DayRoute` already
/// documents: the screen fetches its own logs and does not depend on what the
/// carousel happens to be holding.
enum AlbumRoute: Hashable {
    case day(String)
    case curated(String)
    case moment(String)
}

/// One card in the carousel.
struct Album: Identifiable, Equatable {
    /// `"day:2026-09-06"` or `"curated:gym session"`.
    let id: String
    let kind: AlbumKind
    /// "Today", "Yesterday", a weekday — or the thing you keep doing.
    let title: String
    /// "6 SEP" for a day, "18 PHOTOS" for a curated album.
    let subtitle: String
    /// Newest-first ordering key.
    let sortDate: Date
    /// Cover order: the fan takes the first three. Already de-collided.
    let photoFileNames: [String]
    let winCount: Int
    /// Lowercased title text plus every spelling of the date, so one substring
    /// scan answers "walk", "may", "14", "thursday" and "2026-05" alike.
    let haystack: String

    var route: AlbumRoute {
        switch kind {
        case .day(let key):     return .day(key)
        case .curated(let key): return .curated(key)
        case .moment(let id):   return .moment(id)
        }
    }
}

// MARK: - Building albums

extension Album {

    /// How many photographs a title needs before it is an interest.
    ///
    /// The cover fans three. A three- or four-photograph album is a cover with
    /// nothing behind it — opening it would show you exactly what the card
    /// already did. Five is the smallest number that guarantees otherwise.
    static let minPhotos = 5

    /// On how many separate days.
    ///
    /// Six photographs of one gym session is one session, not an interest.
    /// Repetition has to be *across* days; three occurrences is coincidence.
    static let minPhotoDays = 4

    /// Across how many separate weeks.
    ///
    /// Four times inside one week is a burst — a trip, a deadline — not
    /// something you keep doing.
    static let minSpanWeeks = 2

    /// Curated cards are capped so a heavy user's carousel is not all curated.
    static let maxCurated = 4

    // MARK: The key

    /// Normalises a win title so spellings of the same thing collapse.
    ///
    /// `QuickWinService.logWin` creates a **new `Habit` per win**, so twelve
    /// "Gym session" wins are twelve distinct rows sharing a title string.
    /// Grouping therefore has to key on the string, never on habit identity.
    static func titleKey(_ raw: String) -> String {
        let folded = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                     locale: .current)
        return folded.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Titles that never earn a curated album: the empty string, and the
    /// placeholder a win wears until it is named. "Win" is the absence of a
    /// name, not an interest.
    static func isCuratable(_ key: String) -> Bool {
        !key.isEmpty && key != titleKey(QuickWinService.untitled)
    }

    // MARK: Curated

    /// Titles you keep photographing, newest and busiest first.
    ///
    /// Ordering is **total** — photo count, then day count, then last photo,
    /// then the key itself — because a partial order makes the test flaky
    /// rather than wrong, which is worse.
    static func curatedAlbums(from records: [WinRecord], calendar: Calendar) -> [Album] {
        var byKey: [String: [WinRecord]] = [:]
        for record in records where record.hasPhoto {
            let key = titleKey(record.title)
            guard isCuratable(key) else { continue }
            byKey[key, default: []].append(record)
        }

        // Ranked, then mapped. The sort keys are computed once per title
        // rather than inside the comparator, and the order is TOTAL — a
        // partial one would make the snapshot test flaky rather than wrong,
        // which is harder to notice.
        struct Ranked {
            let key: String
            let group: [WinRecord]
            let photoCount: Int
            let dayCount: Int
            let lastPhoto: Date
        }

        let ranked: [Ranked] = byKey.compactMap { key, group in
            let days = Set(group.map(\.dateString))
            let weeks = Set(group.map { weekKey(for: $0.completedAt, calendar: calendar) })
            guard group.count >= minPhotos,
                  days.count >= minPhotoDays,
                  weeks.count >= minSpanWeeks
            else { return nil }
            return Ranked(
                key: key,
                group: group,
                photoCount: group.count,
                dayCount: days.count,
                lastPhoto: group.map(\.completedAt).max() ?? .distantPast
            )
        }

        return ranked.sorted { lhs, rhs in
            if lhs.photoCount != rhs.photoCount { return lhs.photoCount > rhs.photoCount }
            if lhs.dayCount != rhs.dayCount { return lhs.dayCount > rhs.dayCount }
            if lhs.lastPhoto != rhs.lastPhoto { return lhs.lastPhoto > rhs.lastPhoto }
            return lhs.key < rhs.key
        }.map { item in
            let display = displayTitle(for: item.group)
            return Album(
                id: "curated:\(item.key)",
                kind: .curated(item.key),
                title: display,
                subtitle: "\(item.photoCount) PHOTOS",
                sortDate: item.lastPhoto,
                photoFileNames: coverOrder(for: item.group),
                winCount: item.photoCount,
                haystack: "\(item.key) \(display)".lowercased()
            )
        }
    }

    /// The spelling you actually use: the most common raw form, ties broken by
    /// which was seen first. Correcting "gym session" to "Gym Session" would be
    /// inventing data.
    private static func displayTitle(for group: [WinRecord]) -> String {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Date] = [:]
        for record in group {
            let raw = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
            counts[raw, default: 0] += 1
            if let seen = firstSeen[raw] {
                firstSeen[raw] = min(seen, record.completedAt)
            } else {
                firstSeen[raw] = record.completedAt
            }
        }
        let best = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            let l = firstSeen[lhs.key] ?? .distantFuture
            let r = firstSeen[rhs.key] ?? .distantFuture
            return l > r
        }
        return best?.key ?? ""
    }

    /// The three prints on a curated cover come from three **different days**.
    ///
    /// Without this a single six-shot session supplies all three, and the fan
    /// says "one day" when the album's entire claim is "many days". The rest
    /// follow newest-first behind them.
    private static func coverOrder(for group: [WinRecord]) -> [String] {
        var byDay: [String: [WinRecord]] = [:]
        for record in group { byDay[record.dateString, default: []].append(record) }

        let newestDays = byDay.keys.sorted(by: >).prefix(3)
        var front: [String] = []
        for day in newestDays {
            let newest = (byDay[day] ?? []).max { $0.completedAt < $1.completedAt }
            if let name = newest?.photoFileName { front.append(name) }
        }

        let used = Set(front)
        let rest = group
            .sorted { $0.completedAt > $1.completedAt }
            .compactMap(\.photoFileName)
            .filter { !used.contains($0) }
        return front + rest
    }

    // MARK: Days

    /// One album per day that has at least one photograph.
    ///
    /// A day with none produces nothing at all — a card showing a little tower
    /// is a card about nothing, which is what this screen exists to remove.
    ///
    /// `coverPrints` are the photographs already fanned on a curated cover.
    /// They are **demoted, never filtered**: a day whose only photograph was
    /// reused elsewhere must not silently vanish from the record.
    static func dayAlbums(from records: [WinRecord],
                          calendar: Calendar,
                          now: Date,
                          demoting coverPrints: Set<String>) -> [Album] {
        var byDay: [String: [WinRecord]] = [:]
        for record in records { byDay[record.dateString, default: []].append(record) }

        return byDay.keys.sorted(by: >).compactMap { key -> Album? in
            let group = (byDay[key] ?? []).sorted { $0.completedAt > $1.completedAt }
            let photos = group.compactMap(\.photoFileName)
            guard !photos.isEmpty else { return nil }
            guard let date = group.first?.completedAt else { return nil }

            // Stable: the ones a curated cover already used sink to the back,
            // and everything keeps its relative order otherwise.
            let demoted = photos.filter { !coverPrints.contains($0) }
                + photos.filter { coverPrints.contains($0) }

            let titles = group.map(\.title).joined(separator: " ")
            let short = shortDate(date)
            return Album(
                id: "day:\(key)",
                kind: .day(key),
                title: relativeTitle(for: date, calendar: calendar, now: now),
                subtitle: short,
                sortDate: date,
                photoFileNames: demoted,
                winCount: group.count,
                haystack: "\(titles) \(key) \(short) \(spelledDate(date))".lowercased()
            )
        }
    }

    // MARK: The carousel

    /// What the shelf shows: moments first, then repeated interests.
    ///
    /// **Days are not on it any more.** They were, and the shelf ran to two
    /// dozen near-identical cards that said nothing the month tower above them
    /// did not already say better — the month gives you every day at a glance
    /// and opens any of them. What is left is the two kinds of album you could
    /// not have found yourself: when something happened, and what you keep
    /// doing.
    ///
    /// Moments lead, the way a Flashback leads Snapchat's Memories. They are
    /// the only cards that appear without you having done anything to make
    /// them, which is what makes the screen worth opening on a day you have
    /// not logged anything.
    ///
    /// Returns an empty array when there is nothing worth showing, and the
    /// screen then draws no shelf at all rather than a heading over a gap.
    /// How far back a REPEATED INTEREST counts.
    ///
    /// Separate from the fetch, which now reaches back years so that moments
    /// and the gallery have something to work with. An interest is something
    /// you are still doing, and without this a title you stopped two years ago
    /// would come back as a current one.
    static let interestWindowDays = 180

    static func carousel(from records: [WinRecord],
                         calendar: Calendar,
                         now: Date,
                         maxCurated: Int = Album.maxCurated) -> [Album] {
        let moments = moments(from: records, calendar: calendar, now: now)

        let cutoff = calendar.date(byAdding: .day, value: -interestWindowDays, to: now)
            ?? .distantPast
        let recent = records.filter { $0.completedAt >= cutoff }
        let curated = Array(curatedAlbums(from: recent, calendar: calendar).prefix(maxCurated))

        return moments + curated
    }

    /// Every photograph, newest first, with what it was.
    ///
    /// A photograph belongs to exactly one win, so its title is simply that
    /// win's — no grouping and nothing to disambiguate.
    static func gallery(from records: [WinRecord]) -> [GalleryPhoto] {
        records
            .filter(\.hasPhoto)
            .sorted { $0.completedAt > $1.completedAt }
            .compactMap { record in
                guard let name = record.photoFileName else { return nil }
                let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return GalleryPhoto(
                    fileName: name,
                    // A win logged in one tap has no name, and the block draws
                    // no text for it. The gallery does the same rather than
                    // captioning it "Win".
                    title: (title.isEmpty || title == QuickWinService.untitled) ? nil : title,
                    date: record.completedAt,
                    dateString: record.dateString
                )
            }
    }

    // MARK: - Dates

    static func weekKey(for date: Date, calendar: Calendar) -> String {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return DateUtils.dateString(from: start)
    }

    private static func relativeTitle(for date: Date, calendar: Calendar, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        let df = DateFormatter(); df.dateFormat = "EEEE"
        return df.string(from: date)
    }

    private static func shortDate(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "d MMM"
        return df.string(from: date).uppercased()
    }

    private static func spelledDate(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "EEEE MMMM yyyy"
        return df.string(from: date)
    }
}

// MARK: - The boundary

extension Album {
    /// The only impure step: `HabitLog` is a `@Model`. Everything above this
    /// line is a value function.
    static func records(from logs: [HabitLog]) -> [WinRecord] {
        logs.compactMap { log in
            guard log.completed || log.skipped, let habit = log.habit else { return nil }
            return WinRecord(
                dateString: log.dateString,
                completedAt: log.completedAt ?? .distantPast,
                title: habit.title,
                category: habit.displayCategory,
                size: habit.blockSize,
                photoFileName: log.imageFileName
            )
        }
    }
}

/// One photograph in the gallery, and what it was of.
struct GalleryPhoto: Identifiable, Equatable {
    var id: String { fileName }
    let fileName: String
    /// The win's title, or nil when the win was never named. A win logged in
    /// one tap has no name and its block draws no text; the gallery does the
    /// same rather than captioning it "Win".
    let title: String?
    let date: Date
    let dateString: String
}

/// A run of photographs under one heading — a month of the gallery.
struct GallerySection: Identifiable, Equatable {
    /// `yyyy-MM`.
    let id: String
    /// "September" this year, "September 2025" otherwise.
    let title: String
    let photos: [GalleryPhoto]
}

extension Album {
    /// The gallery, grouped by month.
    ///
    /// Month, not day. Snapchat's Memories groups by month once you are past
    /// the most recent few, and a day heading over one photograph is a heading
    /// with nothing under it — which is most days.
    static func gallerySections(_ photos: [GalleryPhoto],
                                calendar: Calendar,
                                now: Date) -> [GallerySection] {
        var byMonth: [String: [GalleryPhoto]] = [:]
        for photo in photos {
            byMonth[String(photo.dateString.prefix(7)), default: []].append(photo)
        }
        let thisYear = calendar.component(.year, from: now)
        return byMonth.keys.sorted(by: >).map { key in
            let sorted = (byMonth[key] ?? []).sorted { $0.date > $1.date }
            let df = DateFormatter()
            let sameYear = Int(key.prefix(4)) == thisYear
            df.dateFormat = sameYear ? "MMMM" : "MMMM yyyy"
            let title = sorted.first.map { df.string(from: $0.date) } ?? key
            return GallerySection(id: key, title: title, photos: sorted)
        }
    }
}
