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
                    chartSection
                        .padding(.top, 22)

                    divider
                    rhythmSection
                    divider
                    mixSection
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

    private var divider: some View {
        Rectangle()
            .fill(.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.vertical, 30)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(.primary.opacity(0.32))
            .padding(.horizontal, GridConstants.horizontalPadding)
    }

    /// The sentence a section is there to say. Plain language, because a number
    /// with a label beside it is a metric and a sentence is an answer.
    private func sectionLine(_ text: String) -> some View {
        Text(text)
            .font(Typography.headerSmall)
            .foregroundStyle(.primary.opacity(0.80))
            .padding(.horizontal, GridConstants.horizontalPadding)
    }

    // MARK: - How much

    private var chartSection: some View {
        TowerBarChart(
            columns: chartColumns,
            maxRows: max(chartColumns.map(\.rows).max() ?? 0, 4)
        )
    }

    // MARK: - When

    /// Which day of the week you actually do things on.
    ///
    /// Averaged per weekday rather than totalled, or a Monday that has come
    /// round twice as often as a Sunday wins by arithmetic rather than by
    /// habit.
    private var rhythmSection: some View {
        let totals = weekdayAverages
        let best = totals.enumerated().max { $0.element < $1.element }
        let peak = totals.max() ?? 0
        let names = Calendar.current.weekdaySymbols

        return VStack(alignment: .leading, spacing: 16) {
            sectionTitle("When")
            sectionLine(
                peak > 0 && best != nil
                    ? "Most of your wins land on \(names[best!.offset])."
                    : "Not enough yet to see a pattern."
            )

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(totals.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 8) {
                        // A column, not a dot: the same shape as everything
                        // else that counts on this page, at the smallest size
                        // it still reads at.
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                index == best?.offset && peak > 0
                                    ? AppColors.warmBlack.opacity(0.55)
                                    : AppColors.warmBlack.opacity(0.14)
                            )
                            .frame(height: max(peak > 0 ? 54 * (value / peak) : 0, 3))
                        Text(String(names[index].prefix(1)))
                            .font(Typography.caption2)
                            .foregroundStyle(.primary.opacity(index == best?.offset ? 0.6 : 0.28))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(names[index]): \(String(format: "%.1f", value)) a day")
                }
            }
            .frame(height: 76, alignment: .bottom)
            .padding(.horizontal, GridConstants.horizontalPadding)
        }
    }

    // MARK: - What of

    /// The mix, as one bar of the tower's own colours.
    ///
    /// No legend and no labels on the bar: the colours ARE the categories, and
    /// anyone reading this page has been looking at them on the tower. The list
    /// under it names them once, in the order they actually appear.
    private var mixSection: some View {
        let mix = categoryMix
        let total = mix.reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: 16) {
            sectionTitle("What of")
            sectionLine(
                mix.first.map { "Mostly \($0.category.rawValue)." } ?? "Nothing yet."
            )

            VStack(alignment: .leading, spacing: 14) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(mix, id: \.category) { slice in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(slice.category.style.baseColor)
                                .frame(
                                    width: max(
                                        (geo.size.width - CGFloat(max(mix.count - 1, 0)) * 2)
                                            * CGFloat(slice.count) / CGFloat(max(total, 1)),
                                        3
                                    )
                                )
                        }
                    }
                }
                .frame(height: 14)

                VStack(spacing: 0) {
                    ForEach(Array(mix.enumerated()), id: \.element.category) { index, slice in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 18 * 0.147, style: .continuous)
                                .fill(slice.category.style.baseColor)
                                .frame(width: 18, height: 18)
                            Text(slice.category.rawValue.capitalized)
                                .font(Typography.bodyMedium)
                                .foregroundStyle(.primary.opacity(0.75))
                            Spacer(minLength: 0)
                            Text("\(slice.count)")
                                .font(Typography.bodyMedium)
                                .monospacedDigit()
                                .foregroundStyle(.primary.opacity(0.45))
                        }
                        .frame(minHeight: 44)

                        if index != mix.count - 1 {
                            Rectangle()
                                .fill(.primary.opacity(0.05))
                                .frame(height: 0.5)
                                .padding(.leading, 28)
                        }
                    }
                }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
        }
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

    /// Average wins per weekday, indexed 0 = the calendar's first weekday.
    private var weekdayAverages: [Double] {
        let calendar = Calendar.current
        var totals = [Double](repeating: 0, count: 7)
        var occurrences = [Set<String>](repeating: [], count: 7)

        for log in completedLogs {
            guard let date = Self.dateFormatter.date(from: log.dateString) else { continue }
            // `weekday` is 1-based from Sunday; the symbols array the labels
            // come from is 0-based from the locale's first weekday.
            let index = (calendar.component(.weekday, from: date) - calendar.firstWeekday + 7) % 7
            totals[index] += 1
            occurrences[index].insert(log.dateString)
        }
        return (0..<7).map { totals[$0] / Double(max(occurrences[$0].count, 1)) }
    }

    private var categoryMix: [(category: HabitCategory, count: Int)] {
        var counts: [HabitCategory: Int] = [:]
        for log in completedLogs {
            guard let habit = log.habit else { continue }
            counts[habit.displayCategory, default: 0] += 1
        }
        return counts
            .map { (category: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.category.rawValue < $1.category.rawValue : $0.count > $1.count }
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
