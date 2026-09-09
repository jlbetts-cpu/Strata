import Foundation
import SwiftData

/// What the Memories tab knows: the shelf and the month on show.
///
/// ## Why this is not `@Query`
///
/// `@Query` has no fetch limit, materialises its whole result array, and
/// re-runs on every context save. This app saves constantly — every win
/// logged, every rearrange committed, every HealthKit verification — so a
/// History tab on `@Query` would re-materialise the entire record each time
/// something happened on another tab.
///
/// `MainAppView`'s own query is narrowed to the current month, and that
/// narrowing is load-bearing there rather than a bug: `refreshData()` walks
/// every log it holds, on a hot path. Widening it to all-time would turn an
/// O(this month) pass into an O(all time) one. So this fetches its own,
/// explicitly, over a bounded window.
///
/// The week-paged album grid that used to live here is gone with the screen
/// that showed it. The month tower reaches every day and the gallery reaches
/// every photograph, so a third list of the same record was clutter.
@Observable
@MainActor
final class MemoriesViewModel {
    // MARK: The shelf

    /// Moments and repeated interests, from one trailing-window fetch. Empty
    /// when there is nothing worth showing, and the screen then draws no shelf.
    private(set) var carousel: [Album] = []

    /// Every photograph in the window, newest first, grouped by month.
    private(set) var gallery: [GallerySection] = []

    /// How far back the shelf and the gallery look.
    ///
    /// It was 180 days, chosen for repeated interests: an interest is
    /// something you are STILL doing. Moments break that — "a year ago today"
    /// needs a year, and `AlbumMoment.maxYearsBack` asks for three — and the
    /// gallery is supposed to be everything. So the window is three years plus
    /// a margin, which is still a ceiling rather than an unbounded fetch.
    ///
    /// The interest gates are unaffected: they count photographs and days, not
    /// how far back the fetch reached, and `curatedAlbums` still only sees
    /// what is in the window.
    private static let carouselWindowDays = 365 * (AlbumMoment.maxYearsBack + 1)

    // MARK: The month

    private(set) var selectedMonth: Date = Date()
    private(set) var month: MonthTower.Packed = .empty
    /// Keyed "yyyy-MM", so stepping back and forth is free.
    private var monthCache: [String: MonthTower.Packed] = [:]
    /// The month of the first win ever recorded. One `fetchLimit`-1 query,
    /// cached for the session.
    private var earliestWinMonth: Date?

    var canGoBack: Bool {
        guard let earliest = earliestWinMonth else { return false }
        return selectedMonth > earliest
    }
    var canGoForward: Bool { selectedMonth < startOfMonth(Date()) }

    /// Every month with something in it, newest first, for the picker's menu.
    ///
    /// Derived from the range rather than from the record: a month with no
    /// wins still belongs in the list, because a gap you can land on is part
    /// of the picture. Bounded by the first win, so the menu cannot run to
    /// 1970.
    var availableMonths: [Date] {
        guard let earliest = earliestWinMonth else { return [selectedMonth] }
        var months: [Date] = []
        var cursor = startOfMonth(Date())
        while cursor >= earliest, months.count < 120 {
            months.append(cursor)
            guard let previous = calendar.date(byAdding: .month, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return months
    }

    func select(month: Date, context: ModelContext) {
        selectedMonth = startOfMonth(month)
        loadMonth(context: context)
    }

    func title(for month: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = calendar.component(.year, from: month)
            == calendar.component(.year, from: Date()) ? "MMMM" : "MMMM yyyy"
        return df.string(from: month).uppercased()
    }

    var monthTitle: String {
        let df = DateFormatter()
        df.dateFormat = calendar.component(.year, from: selectedMonth)
            == calendar.component(.year, from: Date()) ? "MMMM" : "MMMM yyyy"
        return df.string(from: selectedMonth).uppercased()
    }

    private let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday, so a week section is Mon–Sun
        return c
    }()

    // MARK: - Loading

    func reload(context: ModelContext) {
        monthCache = [:]
        earliestWinMonth = firstWinMonth(context: context)
        selectedMonth = startOfMonth(Date())
        loadCarousel(context: context)
        loadMonth(context: context)
    }

    // MARK: - The shelf

    /// One fetch over the trailing window feeds both kinds of album.
    private func loadCarousel(context: ModelContext) {
        guard let start = calendar.date(byAdding: .day,
                                        value: -Self.carouselWindowDays,
                                        to: Date()) else { return }
        let loKey = DateUtils.dateString(from: start)
        // PHOTOGRAPHED wins only.
        //
        // Everything this feeds wants a photograph: a moment needs three, a
        // repeated interest counts photographed logs, and the gallery is
        // photographs by definition. Fetching the rest was pulling most of the
        // record into memory to throw it away. Measured on a store of 1,089
        // logs: 1,089 fetched in 92ms and built in 30ms, against 363 fetched
        // in 33ms and built in 20ms once the predicate was added — 122ms down
        // to 53ms, on the main actor, every time the tab appears.
        var d = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString >= loKey && $0.imageFileName != nil }
        )
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? context.fetch(d)) ?? []
        let records = Album.records(from: logs)
        let now = Date()
        carousel = Album.carousel(from: records, calendar: calendar, now: now)
        gallery = Album.gallerySections(Album.gallery(from: records),
                                        calendar: calendar, now: now)
    }

    // MARK: - The month

    func step(months: Int, context: ModelContext) {
        guard let next = calendar.date(byAdding: .month, value: months, to: selectedMonth)
        else { return }
        let target = startOfMonth(next)
        if months > 0 { guard target <= startOfMonth(Date()) else { return } }
        if months < 0, let earliest = earliestWinMonth { guard target >= earliest else { return } }
        selectedMonth = target
        loadMonth(context: context)
    }

    /// A month is fetched once and kept. Deriving it from `sections` instead
    /// would be wrong rather than slow: those are paged eight weeks deep, so
    /// anything older would silently come back as a partial month.
    private func loadMonth(context: ModelContext) {
        let key = monthKey(selectedMonth)
        if let cached = monthCache[key] { month = cached; return }

        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth)
        else { month = .empty; return }
        let loKey = DateUtils.dateString(from: selectedMonth)
        let hiKey = DateUtils.dateString(from: next)
        var d = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString >= loKey && $0.dateString < hiKey }
        )
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? context.fetch(d)) ?? []

        let packed = Self.pack(Album.records(from: logs), calendar: calendar)
        monthCache[key] = packed
        month = packed
    }

    /// Pure: records to a packed month. Static so it can be tested directly.
    static func pack(_ records: [WinRecord], calendar: Calendar) -> MonthTower.Packed {
        var byDay: [String: [WinRecord]] = [:]
        for record in records { byDay[record.dateString, default: []].append(record) }

        let days: [MonthTower.Day] = byDay.compactMap { key, group in
            guard let first = group.first else { return nil }
            let day = calendar.component(.day, from: first.completedAt)
            return MonthTower.Day(
                dateString: key,
                dayOfMonth: day,
                winCount: group.count,
                category: MonthTower.dominantCategory(
                    group.map { (category: $0.category, at: $0.completedAt) }
                ),
                // Newest first, so a block that shows only one shows the
                // last thing that happened that day.
                photoFileNames: group
                    .sorted { $0.completedAt > $1.completedAt }
                    .compactMap(\.photoFileName)
            )
        }
        return MonthTower.pack(days)
    }

    private func firstWinMonth(context: ModelContext) -> Date? {
        var d = FetchDescriptor<HabitLog>(sortBy: [SortDescriptor(\.dateString, order: .forward)])
        d.fetchLimit = 1
        guard let first = (try? context.fetch(d))?.first,
              let date = first.completedAt ?? Self.parse(first.dateString) else { return nil }
        return startOfMonth(date)
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func monthKey(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM"
        return df.string(from: date)
    }

    static func parse(_ key: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: key)
    }
}
