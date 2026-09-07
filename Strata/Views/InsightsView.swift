import SwiftData
import SwiftUI

/// What it all adds up to.
///
/// Four answers, in the order you would ask them: how much, how steadily,
/// when, and what of. Each is one line of plain language with one thing to
/// look at, and they are separated by space rather than by boxes.
///
/// **No cards.** A filled well with a rim says "you built this and it is
/// standing on something", which is a block's claim to make. Everything on
/// this page is a reading of blocks, not another block, so it gets air and a
/// hairline and nothing else.
///
/// **No new chart types.** The bars are towers, the mix is the six colours the
/// tower is made of, and the rhythm is the same bars again at a smaller size.
/// Nothing here has a legend, because nothing here introduces a vocabulary the
/// tower has not already taught.
struct InsightsView: View {
    let habits: [Habit]
    let logs: [HabitLog]
    var onAddHabit: (() -> Void)? = nil
    var onNavigateToTower: ((TowerFilterMode) -> Void)? = nil
    var openSettings: (() -> Void)? = nil

    @AppStorage("insightsRange") private var rangeRaw: String = TowerFilterMode.day.rawValue
    private var range: TowerFilterMode {
        get { TowerFilterMode(rawValue: rangeRaw) ?? .day }
        nonmutating set { rangeRaw = newValue.rawValue }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, GridConstants.horizontalPadding)

                if completedLogs.isEmpty {
                    emptyState
                } else {
                    // The chart, and nothing under it.
                    //
                    // "When" and "What of" were two more things to read on a
                    // page whose one job is to show you the towers. They were
                    // honest readings, and they were still a second and third
                    // idea competing with the first — and a page with three
                    // ideas has no main one. This is the tab now: your towers,
                    // side by side, at whatever span you asked for.
                    chartSection
                        .padding(.top, 26)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 110)
        }
        .background { WarmBackground().ignoresSafeArea() }
        // No navigation bar, so the count sits where the count on the other two
        // pages sits. The bar was reserving about 44pt above the content, which
        // put the same numeral at a different height on every screen.
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(chartColumns.reduce(0) { $0 + $1.winCount })")
                    .font(.system(size: GridConstants.tallyNumeral, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))
                    .contentTransition(.numericText())
                Text("wins")
                    .font(.system(size: GridConstants.tallyWord, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.35))
                Spacer(minLength: 0)
                TowerRangePicker(
                    selection: Binding(
                        get: { range == .week ? .day : range },
                        set: { range = $0 }
                    ),
                    options: [.day, .month]
                )
                Button {
                    HapticsEngine.lightTap()
                    openSettings?()
                } label: {
                    Image(systemName: "gearshape")
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .regular)
                        .foregroundStyle(.primary.opacity(0.45))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }

            if dailyStreak > 0 {
                Text(dailyStreak == 1 ? "1 day in a row" : "\(dailyStreak) days in a row")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary.opacity(0.40))
            }
        }
    }



    /// The sentence a section is there to say. Plain language, because a number
    /// with a label beside it is a metric and a sentence is an answer.

    // MARK: - How much

    private var chartSection: some View {
        // Given real room, since it is the only thing on the page now.
        TowerBarChart(
            columns: chartColumns,
            maxRows: max(chartColumns.map(\.rows).max() ?? 0, 4),
            maxBarHeight: 340
        )
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Nothing to show yet")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.6))
            Text("Log a win and it shows up here.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    // MARK: - Data

    private var completedLogs: [HabitLog] {
        logs.filter { $0.completed && $0.habit != nil }
    }

    /// One streak: consecutive days you logged something.
    ///
    /// Per-habit streaks went with repeating habits — there is nothing left to
    /// keep a streak ON, and a streak per habit rewards doing the same thing
    /// while the tower rewards doing anything.
    ///
    /// Today not being logged yet does not break it. A streak that resets at
    /// midnight and shames you until lunch is measuring the clock rather than
    /// you, so it counts back from today if today has something and from
    /// yesterday if it does not.
    private var dailyStreak: Int {
        let calendar = Calendar.current
        var days = Set<String>()
        for log in completedLogs { days.insert(log.dateString) }
        guard !days.isEmpty else { return 0 }

        var cursor = Date()
        if !days.contains(Self.dateFormatter.string(from: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(Self.dateFormatter.string(from: cursor)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }



    /// One column per period, most recent last.
    ///
    /// A fixed count of periods rather than everything: bars stay a readable
    /// width, and the chart says what you have been doing lately, which is the
    /// question, instead of compressing a year into a smear.
    private var chartColumns: [TowerBarChart.Column] {
        let calendar = Calendar.current
        let now = Date()
        let component: Calendar.Component
        let count: Int
        switch range {
        case .day, .week: component = .day;   count = 14
        case .month:      component = .month; count = 12
        }

        // Indexed once, rather than filtering the whole set per column.
        var byPeriod: [Date: [HabitLog]] = [:]
        for log in logs {
            guard let date = Self.dateFormatter.date(from: log.dateString),
                  let start = calendar.dateInterval(of: component, for: date)?.start
            else { continue }
            byPeriod[start, default: []].append(log)
        }
        let currentStart = calendar.dateInterval(of: component, for: now)?.start

        return (0..<count).reversed().compactMap { back -> TowerBarChart.Column? in
            guard let date = calendar.date(byAdding: component, value: -back, to: now),
                  let start = calendar.dateInterval(of: component, for: date)?.start
            else { return nil }
            return TowerBarChart.Column(
                id: ISO8601DateFormatter().string(from: start),
                label: component == .day
                    ? String(start.formatted(.dateTime.weekday(.narrow)))
                    : String(start.formatted(.dateTime.month(.narrow))),
                isCurrent: start == currentStart,
                blocks: MiniTowerPacker.pack(byPeriod[start] ?? [])
            )
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
