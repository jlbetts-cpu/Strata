import Foundation
import SwiftData
import UIKit
#if DEBUG
import QuartzCore
#endif

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
    /// Every photographed win that knows where it was. Clustering happens in
    /// the view, because it depends on the camera's zoom.
    private(set) var pins: [PlaceMap.Pin] = []
    /// Whether `reload` has run. Before it has, no pins means nothing read
    /// yet, not nothing there.
    private(set) var hasLoaded = false

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

    private(set) var selectedMonth: Date = Date() {
        // Worked out once, when the month changes. It was a computed property
        // that made a `DateFormatter`, read three times per body.
        didSet {
            let title = Self.title(for: selectedMonth, calendar: calendar)
            if title != monthTitle { monthTitle = title }
        }
    }
    /// "SEPTEMBER", or "SEPTEMBER 2025" for another year.
    private(set) var monthTitle: String = MemoriesViewModel.title(for: Date(), calendar: MemoriesViewModel.mondayCalendar)
    private(set) var month: MonthTower.Packed = .empty
    /// Keyed "yyyy-MM", so stepping back and forth is free.
    private var monthCache: [String: MonthTower.Packed] = [:]
    /// The month of the first win ever recorded. One `fetchLimit`-1 query,
    /// cached for the session.
    private var earliestWinMonth: Date?


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
        Self.title(for: month, calendar: calendar)
    }

    /// Cached formatters: the month menu asks twice per month, up to 120
    /// months, on every body. See `Album.Formats`.
    private static func title(for month: Date, calendar: Calendar) -> String {
        let sameYear = calendar.component(.year, from: month) == calendar.component(.year, from: Date())
        return (sameYear ? Album.Formats.month : Album.Formats.monthYear).string(from: month).uppercased()
    }

    private static let mondayCalendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday, so a week section is Mon–Sun
        return c
    }()
    private let calendar: Calendar = MemoriesViewModel.mondayCalendar

    init() {
        StoreSaves.observe()
    }

    // MARK: - Loading

    /// What the last completed reload was built from. See `reload`.
    private var loadedSignature: StoreSignature?
    /// A reload that finds a newer one started does not publish.
    private var reloadGeneration = 0

    /// **Only when something changed.** This ran in full on every visit to
    /// the tab — `.task` inside a `TabView` is cancelled when the tab goes and
    /// runs again when it comes back — fetching four years of photographs on
    /// the main actor each time. A few counts say whether anything could have
    /// changed; if nothing did, the month is put back to this one (as a reload
    /// always did) and that is all.
    ///
    /// When something did, the fetch and the flattening to `WinRecord` stay on
    /// the main actor, where the context lives, and the grouping — albums,
    /// gallery, pins — runs off it: it is pure value work, which is what
    /// `WinRecord` exists to make true.
    func reload(context: ModelContext) async {
        #if DEBUG
        let began = CACurrentMediaTime()
        #endif
        let signature = StoreSignature.current(context: context)
        if let loadedSignature, loadedSignature == signature {
            // Assigned only if different: an equal write still invalidates
            // every view reading it, and this runs on every visit.
            let thisMonth = startOfMonth(Date())
            if thisMonth != selectedMonth {
                selectedMonth = thisMonth
                loadMonth(context: context)
            }
            #if DEBUG
            PerfProbe.duration("MemoriesViewModel.reload main (unchanged, skipped)", since: began)
            #endif
            return
        }
        reloadGeneration += 1
        let mine = reloadGeneration
        monthCache = [:]
        earliestWinMonth = firstWinMonth(context: context)
        selectedMonth = startOfMonth(Date())
        let records = carouselRecords(context: context)
        loadMonth(context: context)
        let calendar = self.calendar
        let now = Date()
        #if DEBUG
        PerfProbe.duration("MemoriesViewModel.reload main (fetch)", since: began)
        #endif
        let built = await Task.detached(priority: .userInitiated) {
            #if DEBUG
            let buildStart = CACurrentMediaTime()
            defer { PerfProbe.duration("MemoriesViewModel.build off-main", since: buildStart) }
            #endif
            return Self.build(records, calendar: calendar, now: now)
        }.value
        guard mine == reloadGeneration else { return }
        carousel = built.carousel
        gallery = built.gallery
        pins = built.pins
        hasLoaded = true
        loadedSignature = signature
    }

    /// Everything the shelf, the gallery and the map draw, from one set of
    /// records. Values in, values out.
    nonisolated struct Built: Sendable {
        let carousel: [Album]
        let gallery: [GallerySection]
        let pins: [PlaceMap.Pin]
    }

    nonisolated static func build(_ records: [WinRecord], calendar: Calendar, now: Date) -> Built {
        Built(carousel: Album.carousel(from: records, calendar: calendar, now: now),
              gallery: Album.gallerySections(Album.gallery(from: records),
                                             calendar: calendar, now: now),
              // Free: the same fetch, the same records. A second query for
              // the map would double a cost measured at 53ms.
              pins: PlaceMap.pins(from: records))
    }

    // MARK: - The shelf

    /// One fetch over the trailing window feeds both kinds of album.
    private func carouselRecords(context: ModelContext) -> [WinRecord] {
        guard let start = calendar.date(byAdding: .day,
                                        value: -Self.carouselWindowDays,
                                        to: Date()) else { return [] }
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
        return Album.records(from: logs)
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
        Self.monthKeyFormat.string(from: date)
    }

    static func parse(_ key: String) -> Date? {
        dayKeyFormat.date(from: key)
    }

    private static let monthKeyFormat = posix("yyyy-MM")
    private static let dayKeyFormat = posix("yyyy-MM-dd")
    private static func posix(_ format: String) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = format
        return df
    }
}

/// Whether the store could have changed since a page was last built from it.
///
/// Three counters, two counts and the newest win. The save counter catches
/// anything this process writes, an EDIT included — a renamed win, a changed
/// size or colour, a replaced photograph — which changes no count. The counts
/// catch what another process writes to the shared store (the widget's
/// intents), which can only happen while the app is not in front, so they are
/// only queried again after a save or a return to the foreground: measured on
/// a year of seeded history, the three queries cost 60 to 80ms on the first
/// call of a visit, and a tab switch with nothing changed now makes none.
/// Unsaved changes on the context mean "changed". The day is in it because the
/// shelf's titles ("Today", "A year ago today") are relative to it.
struct StoreSignature: Equatable {
    let logs: Int
    let photographs: Int
    let newest: Date?
    let saves: Int
    let activations: Int
    let day: String
    let pending: Bool

    private struct Counted {
        let container: ObjectIdentifier
        let saves: Int
        let activations: Int
        let logs: Int
        let photographs: Int
        let newest: Date?
    }
    private static var counted: Counted?

    static func current(context: ModelContext) -> StoreSignature {
        let container = ObjectIdentifier(context.container)
        let saves = StoreSaves.generation
        let activations = StoreSaves.activations
        let counts: Counted
        if let cached = counted, cached.container == container,
           cached.saves == saves, cached.activations == activations {
            counts = cached
        } else {
            let logs = (try? context.fetchCount(FetchDescriptor<HabitLog>())) ?? -1
            let photographs = (try? context.fetchCount(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.imageFileName != nil }))) ?? -1
            var newest = FetchDescriptor<HabitLog>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
            newest.fetchLimit = 1
            let latest = (try? context.fetch(newest))?.first?.completedAt
            counts = Counted(container: container, saves: saves, activations: activations,
                             logs: logs, photographs: photographs, newest: latest)
            counted = counts
        }
        return StoreSignature(logs: counts.logs, photographs: counts.photographs, newest: counts.newest,
                              saves: saves, activations: activations,
                              day: DateUtils.dateString(from: Date()),
                              pending: context.hasChanges)
    }

    static func == (lhs: StoreSignature, rhs: StoreSignature) -> Bool {
        // Pending changes never match: there is something not yet counted.
        !lhs.pending && !rhs.pending
            && lhs.logs == rhs.logs && lhs.photographs == rhs.photographs
            && lhs.newest == rhs.newest && lhs.saves == rhs.saves
            && lhs.activations == rhs.activations && lhs.day == rhs.day
    }
}

/// Counts every save of every `ModelContext` in the process, and every return
/// to the foreground.
enum StoreSaves {
    private(set) static var generation = 0
    private(set) static var activations = 0
    private static var tokens: [NSObjectProtocol] = []

    static func observe() {
        guard tokens.isEmpty else { return }
        tokens.append(NotificationCenter.default.addObserver(forName: ModelContext.didSave,
                                                             object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { generation &+= 1 }
        })
        tokens.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                             object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { activations &+= 1 }
        })
    }
}
