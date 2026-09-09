import Foundation
import SwiftData

/// What the Memories tab knows: the shelf, the month on show, and the full
/// record behind it, paged a few weeks at a time.
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
/// O(this month) pass into an O(all time) one. So History fetches its own,
/// explicitly, and pages.
@Observable
@MainActor
final class MemoriesViewModel {
    /// Weeks per page. Eight is about two screens of albums, so the sentinel
    /// at the bottom is reached rarely.
    private static let weeksPerPage = 8

    private(set) var sections: [WeekSection] = []
    private(set) var isLoading = false
    private(set) var reachedEnd = false

    var searchText: String = "" { didSet { applyFilter() } }
    private(set) var visibleSections: [WeekSection] = []

    // MARK: The shelf

    /// Curated albums then recent days, from one trailing-window fetch.
    private(set) var carousel: [Album] = []

    /// How far back the shelf looks. An interest is something you are STILL
    /// doing, and 180 days is long enough to catch a seasonal one while
    /// keeping the fetch bounded — roughly 900 rows at five wins a day. Not
    /// all-time: a card for a thing you stopped doing two years ago is noise,
    /// and the fetch would have no ceiling.
    private static let carouselWindowDays = 180

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

    var monthTitle: String {
        let df = DateFormatter()
        df.dateFormat = calendar.component(.year, from: selectedMonth)
            == calendar.component(.year, from: Date()) ? "MMMM" : "MMMM yyyy"
        return df.string(from: selectedMonth).uppercased()
    }

    private var oldestLoadedWeekStart: Date?
    private let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday, so a week section is Mon–Sun
        return c
    }()

    // MARK: - Loading

    func reload(context: ModelContext) {
        sections = []
        oldestLoadedWeekStart = nil
        reachedEnd = false
        monthCache = [:]
        earliestWinMonth = firstWinMonth(context: context)
        selectedMonth = startOfMonth(Date())
        loadCarousel(context: context)
        loadMonth(context: context)
        loadNextPage(context: context)
    }

    // MARK: - The shelf

    /// One fetch over the trailing window feeds both kinds of album.
    private func loadCarousel(context: ModelContext) {
        guard let start = calendar.date(byAdding: .day,
                                        value: -Self.carouselWindowDays,
                                        to: Date()) else { return }
        let loKey = DateUtils.dateString(from: start)
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString >= loKey })
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? context.fetch(d)) ?? []
        carousel = Album.carousel(from: Album.records(from: logs),
                                  calendar: calendar, now: Date())
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
                )
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

    func loadNextPage(context: ModelContext) {
        guard !isLoading, !reachedEnd else { return }
        isLoading = true
        defer { isLoading = false }

        let anchor = oldestLoadedWeekStart ?? startOfWeek(for: Date())
        guard let lo = calendar.date(byAdding: .weekOfYear,
                                     value: -(Self.weeksPerPage - 1), to: anchor),
              let hiExclusive = calendar.date(byAdding: .day, value: 7, to: anchor)
        else { reachedEnd = true; return }

        let loKey = DateUtils.dateString(from: lo)
        let hiKey = DateUtils.dateString(from: hiExclusive)
        // A lexicographic range on "yyyy-MM-dd" is a date range, which is the
        // same trick MainAppView's own predicate uses. `#Index` on dateString
        // is what keeps it off a table scan.
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString >= loKey && $0.dateString < hiKey },
            sortBy: [SortDescriptor(\.dateString, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.habit]

        let logs = (try? context.fetch(descriptor)) ?? []
        let page = Self.sections(from: logs, calendar: calendar)
        sections.append(contentsOf: page)
        oldestLoadedWeekStart = lo

        // Nothing older than the first win. One empty page is not proof —
        // a gap of eight quiet weeks is perfectly normal — so this checks
        // whether anything at all exists before the window.
        if !hasAnything(before: loKey, context: context) { reachedEnd = true }
        applyFilter()
    }

    private func hasAnything(before key: String, context: ModelContext) -> Bool {
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString < key })
        d.fetchLimit = 1
        return ((try? context.fetch(d)) ?? []).isEmpty == false
    }

    private func startOfWeek(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    // MARK: - Filtering

    private func applyFilter() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { visibleSections = sections; return }
        visibleSections = sections.compactMap { section in
            let kept = section.albums.filter { album in
                album.haystack.contains(q)
            }
            return kept.isEmpty ? nil : WeekSection(id: section.id, title: section.title, albums: kept)
        }
    }

    // MARK: - Grouping

    /// Pure, so it can be tested without a store or a simulator.
    static func sections(from logs: [HabitLog], calendar: Calendar) -> [WeekSection] {
        let usable = logs.filter { ($0.completed || $0.skipped) && $0.habit != nil }
        var byDay: [String: [HabitLog]] = [:]
        for log in usable { byDay[log.dateString, default: []].append(log) }

        let albums: [DayAlbum] = byDay.keys.sorted(by: >).compactMap { key in
            guard let dayLogs = byDay[key], let date = dayLogs.first?.completedAt ?? parse(key)
            else { return nil }
            let built = album(dateString: key, date: date, logs: dayLogs, calendar: calendar)
            // Photographs only. A day with none produces no album at all — a
            // card showing a little tower is a card about nothing, and the
            // chart that used to show the gaps is gone.
            return built.hasPhotos ? built : nil
        }

        var byWeek: [String: [DayAlbum]] = [:]
        for a in albums { byWeek[a.weekKey, default: []].append(a) }
        return byWeek.keys.sorted(by: >).map { week in
            let days = (byWeek[week] ?? []).sorted { $0.id > $1.id }
            return WeekSection(id: week, title: weekTitle(week, calendar: calendar), albums: days)
        }
    }

    private static func album(dateString: String, date: Date,
                              logs: [HabitLog], calendar: Calendar) -> DayAlbum {
        let sorted = logs.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let photos = sorted.compactMap(\.imageFileName)
        let titles = sorted.compactMap { $0.habit?.title }.joined(separator: " ")

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        let short = df.string(from: date).uppercased()
        df.dateFormat = "EEEE MMMM yyyy"
        let spelled = df.string(from: date)

        return DayAlbum(
            id: dateString,
            date: date,
            title: relativeTitle(for: date, calendar: calendar),
            dateLabel: short,
            weekKey: DateUtils.dateString(from: weekStart),
            winCount: sorted.count,
            photoFileNames: photos,
            haystack: "\(titles) \(dateString) \(short) \(spelled)".lowercased()
        )
    }

    private static func relativeTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let df = DateFormatter(); df.dateFormat = "EEEE"
        return df.string(from: date)
    }

    private static func weekTitle(_ weekKey: String, calendar: Calendar) -> String {
        guard let start = parse(weekKey),
              let end = calendar.date(byAdding: .day, value: 6, to: start)
        else { return weekKey }
        let df = DateFormatter()
        if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
            df.dateFormat = "MMM d"
            let a = df.string(from: start)
            df.dateFormat = "d"
            return "\(a)–\(df.string(from: end))".uppercased()
        }
        df.dateFormat = "MMM d"
        return "\(df.string(from: start))–\(df.string(from: end))".uppercased()
    }

    static func parse(_ key: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: key)
    }
}
