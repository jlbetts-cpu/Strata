import Charts
import SwiftUI

/// **What Your Stats draws, shaped once** (2026-10-16: the owner asked for
/// "an actually interesting looking stats sheet that's actually researched
/// and looks good with interesting graphs that you can interact with").
///
/// Three questions a person asks of their own record, each a chart they can
/// put a finger on, as Apple's Health and Fitness charts are read: drag
/// across and the bar under the finger says itself. Colour is the blocks'
/// own (the rule: colour is content, chrome is ink); nothing is a verdict.
nonisolated enum StatsData {
    struct Entry: Equatable, Sendable {
        let day: String
        let hour: Int
        let category: HabitCategory
    }

    struct Day: Identifiable, Equatable, Sendable {
        let date: Date
        let key: String
        /// In the tower's colour order, so the stacks always stack alike.
        let counts: [(HabitCategory, Int)]
        var total: Int { counts.reduce(0) { $0 + $1.1 } }
        var id: String { key }

        static func == (a: Day, b: Day) -> Bool {
            a.key == b.key && a.counts.map(\.0) == b.counts.map(\.0) && a.counts.map(\.1) == b.counts.map(\.1)
        }
    }

    static let order: [HabitCategory] = HabitCategory.selectable + [.unlabeled]

    /// The last seven days, today last, each day's wins by colour.
    static func week(_ entries: [Entry], today: Date, calendar: Calendar = .current) -> [Day] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).reversed().compactMap { back -> Day? in
            guard let date = calendar.date(byAdding: .day, value: -back, to: start) else { return nil }
            let key = DateUtils.dateString(from: date)
            let those = entries.filter { $0.day == key }
            let counts = order.compactMap { c -> (HabitCategory, Int)? in
                let n = those.filter { $0.category == c }.count
                return n > 0 ? (c, n) : nil
            }
            return Day(date: date, key: key, counts: counts)
        }
    }

    /// Wins in each hour of the day, over the last `days`.
    static func hours(_ entries: [Entry], today: Date, days: Int = 30, calendar: Calendar = .current) -> [Int] {
        let cutoff = DateUtils.dateString(from: calendar.date(byAdding: .day, value: -(days - 1),
                                                              to: calendar.startOfDay(for: today)) ?? today)
        var out = Array(repeating: 0, count: 24)
        for e in entries where e.day >= cutoff && (0..<24).contains(e.hour) { out[e.hour] += 1 }
        return out
    }

    /// The hour most wins land in, if there is a clear one.
    static func peakHour(_ hours: [Int]) -> Int? {
        guard let most = hours.max(), most > 0 else { return nil }
        return hours.firstIndex(of: most)
    }

    /// "9am", "12pm".
    static func hourWord(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }
}

/// **This week, a bar a day**, in ink, with your goal as a quiet
/// line. Drag across to read a day.
struct WeekWinsChart: View {
    let days: [StatsData.Day]
    let goal: Int
    @State private var picked: Date?

    private var pickedDay: StatsData.Day? {
        guard let picked else { return nil }
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: picked) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            Text(caption)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .contentTransition(.numericText())
                .animation(GridConstants.motionSnappy, value: caption)
            Chart {
                ForEach(bars) { bar in
                    BarMark(x: .value("Day", bar.date, unit: .day), y: .value("Wins", bar.count), width: .ratio(0.55))
                        .foregroundStyle(bar.colour.opacity(bar.dimmed ? 0.2 : 0.85))
                        .cornerRadius(3)
                }
                if goal > 0 {
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(AppColors.inkTertiary)
                }
            }
            .chartXSelection(value: $picked)
            // All seven days, the empty ones too: a week with one day of wins
            // drew one bar across the whole chart.
            .chartXScale(domain: domain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
            .sensoryFeedback(.selection, trigger: pickedDay?.key)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week: " + days.map {
            "\($0.date.formatted(.dateTime.weekday(.wide))), \($0.total)"
        }.joined(separator: "; "))
    }

    private var domain: ClosedRange<Date> {
        let first = days.first?.date ?? Date()
        let last = days.last.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0.date) } ?? Date()
        return first...last
    }

    /// One segment of a day's stack.
    private struct Bar: Identifiable {
        let id: String
        let date: Date
        let count: Int
        let colour: Color
        let dimmed: Bool
    }

    /// **One ink bar a day** (the owner, 2026-10-16: "stop being so stuck up
    /// on the colour ... the colour is a side product of the app"). It was a
    /// stack by colour; what a day is, is how many.
    private var bars: [Bar] {
        let pickedKey = pickedDay?.key
        return days.map { day in
            Bar(id: day.key, date: day.date, count: day.total,
                colour: AppColors.inkPrimary, dimmed: pickedKey != nil && pickedKey != day.key)
        }
    }

    private var caption: String {
        if let day = pickedDay {
            let name = day.date.formatted(.dateTime.weekday(.wide))
            return "\(name), \(day.total == 1 ? "1 win" : "\(day.total) wins")"
        }
        let total = days.reduce(0) { $0 + $1.total }
        return total == 1 ? "1 win this week" : "\(total) wins this week"
    }
}

/// **When you win**: wins by the hour, over the last month. Drag to read
/// an hour; at rest it names the busiest one.
struct HourWinsChart: View {
    let hours: [Int]
    @State private var picked: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            Text(caption)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .animation(GridConstants.motionSnappy, value: caption)
            Chart {
                ForEach(Array(hours.enumerated()), id: \.offset) { hour, count in
                    // A fixed width: on a number axis `.ratio` has no band to
                    // be a share of, and drew every bar at nothing.
                    BarMark(x: .value("Hour", hour), y: .value("Wins", count), width: .fixed(9))
                        .foregroundStyle(AppColors.inkPrimary.opacity(picked == nil || picked == hour ? 0.85 : 0.2))
                        .cornerRadius(2)
                }
            }
            .chartXSelection(value: $picked)
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { value in
                    AxisValueLabel {
                        if let h = value.as(Int.self) { Text(StatsData.hourWord(h)) }
                    }
                    .foregroundStyle(AppColors.inkSecondary)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 110)
            .sensoryFeedback(.selection, trigger: picked)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
    }

    private var caption: String {
        if let picked, hours.indices.contains(picked) {
            let n = hours[picked]
            return "Around \(StatsData.hourWord(picked)), \(n == 1 ? "1 win" : "\(n) wins")"
        }
        guard let peak = StatsData.peakHour(hours) else { return "Your wins, by the hour" }
        return "Most wins around \(StatsData.hourWord(peak))"
    }
}
