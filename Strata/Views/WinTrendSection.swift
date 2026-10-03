import Accessibility
import Charts
import SwiftUI

/// Wins per day, week or month: one sentence, one chart, and the control
/// over them.
///
/// **One component, drawn by Profile and by a crew's page** (2026-10-02).
/// It was Profile's own until a crew needed the same chart, and two copies
/// of a chart are two charts that drift apart. Everything said below about
/// it was said on Profile first and still holds.
struct WinTrendSection: View {
    /// Whose wins the sentences talk about.
    enum Owner {
        case you, crew
        var possessive: String { self == .you ? "your" : "the crew's" }
    }

    /// All three units, worked out before the view is drawn, so switching
    /// between them is instant rather than a recount per tap.
    let bars: [WinTrend.Unit: [WinTrend.Bar]]
    let summaries: [WinTrend.Unit: WinTrend.Summary]
    @Binding var unitRaw: String
    var owner: Owner = .you

    /// The bar a tap has picked out, by the start of its period. Nil shows
    /// the trend.
    @State private var selectedBar: Date?

    private var unit: WinTrend.Unit { WinTrend.Unit(rawValue: unitRaw) ?? .week }

    /// Tall enough to compare bars by eye, short enough that the chart and
    /// its sentence share a screen with the streak.
    private static let chartHeight: CGFloat = 160
    /// **The tally's ink, taken from the palette.**
    ///
    /// The streak figure and the bars were `.primary.opacity(0.85)` and
    /// `.primary.opacity(0.45)`. CLAUDE.md is explicit that this is not a
    /// colour, it is a colour in light mode: the same number is 85% black on a
    /// near-white page and 85% WHITE on a near-black one, and the two are not
    /// the same weight of voice. `AppColors.inkPrimary` is exactly that ink made
    /// adaptive (0.85 light, 0.92 dark), and it exists because the literal had
    /// been written in eight places.
    ///
    /// So the numbers below are FRACTIONS of the token rather than alphas of
    /// their own.
    ///
    /// The period we are in, which is not finished. 0.53 of the ink lands on
    /// the same 0.45 in light mode that was measured at 3.3:1, and a little
    /// stronger in dark, which is the correction the token exists for. It still
    /// clears 3:1 as a graphic while reading as not yet whole; 0.35 fell to
    /// 2.4:1.
    private static let unfinishedBarShare = 0.53
    /// A bar that is not the one you picked. It steps back rather than
    /// disappearing, so its height can still be compared with the picked one's.
    private static let unpickedBarShare = 0.4

    var body: some View {
        trend
            .onChange(of: unitRaw) { _, _ in selectedBar = nil }
    }

    /// Apple Health's Highlight: one sentence, one chart, and a Day / Week /
    /// Month control over them. The sentence is the point and quotes the
    /// numbers behind it; the chart is the evidence (Apple HIG, Charts:
    /// "Summarize the main message of your chart").
    private var trend: some View {
        let summary = summaries[unit] ?? WinTrend.Summary(kind: .empty)
        let bars = self.bars[unit] ?? []
        return Section {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                // **No control until there is something to switch between**
                // (2026-10-02, design review `profile.md` #3). Over no data
                // Day, Week and Month all draw the same sentence, so the
                // control was three choices with no effect: the loudest thing
                // in an empty card, saying nothing. The first win brings it in;
                // the card growing once, at the moment there is a chart to
                // show, is the right moment for it to change.
                if summary.kind != .empty {
                    Picker("Wins per", selection: $unitRaw) {
                        ForEach(WinTrend.Unit.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // `GridConstants.spacing`, and it was a hand-typed 0.
                //
                // The pair was 17 Regular-ish over 13 Regular and the size gap
                // did the separating; both lines are Medium now and 17 over 15
                // with nothing between them read as one paragraph. 4 is the rung
                // `OnboardingView` and `RestoreBackupView` already put between a
                // name and the line that says what it is, which is this pair.
                VStack(alignment: .leading, spacing: GridConstants.spacing) {
                    Text(shownHeadline(summary: summary, bars: bars))
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .contentTransition(.numericText())
                    // **There is a second line only when a bar is picked**
                    // (cut 4, 2026-10-01). The trend's own second line was not
                    // dropped, it was PROMOTED: `detail` is what the line above
                    // now says, because it was always the one with the numbers
                    // in it. See `headline(_:)`. The pair that survives is a
                    // count over the week it belongs to, which is two facts.
                    if let line = shownDetail(summary: summary, bars: bars) {
                        Text(line)
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .animation(GridConstants.motionSnappy, value: selectedBar)

                if summary.kind != .empty {
                    chart(bars)
                        .frame(height: Self.chartHeight)
                        .padding(.top, GridConstants.gapTight)
                        .animation(GridConstants.motionSnappy, value: unitRaw)
                }
            }
            .padding(.vertical, GridConstants.gapTight)
        } header: {
            FormSectionLabel("Wins per \(unit.name)")
        }
    }

    /// The one line over the chart.
    ///
    /// **The mood headline is gone and the numbers took its place** (cut 4,
    /// `docs/copy-audit.md`, 2026-10-01). It used to read "You're logging more
    /// wins lately." / "You're keeping a steady pace." / "A quieter stretch
    /// lately." at `headerMedium`, with `detail` under it at `screenSubtitle`
    /// saying the same thing WITH the numbers in it: "3 wins a week over the
    /// last 8 weeks, up from 2 wins before that."
    ///
    /// A title over a strictly more informative subtitle is the pattern upside
    /// down — the louder line was the one carrying less. So the subtitle was
    /// promoted into the headline's slot and the mood was deleted, rather than
    /// one of the two lines being dropped: one medium-weight sentence over the
    /// chart, no small grey line under it. Apple HIG, Charts, is what the pair
    /// was built on in the first place ("Summarize the main message of your
    /// chart"), and the summary is the one with the figures in it.
    ///
    /// **The two states with nothing to promote keep a sentence**, because a
    /// chart that cannot be drawn yet has to say so, and `detail` is already
    /// nil at both of them.
    private func headline(_ summary: WinTrend.Summary) -> String {
        switch summary.kind {
        case .notEnough: return beforeTheTrend
        case .empty:     return "\(owner.possessive.prefix(1).uppercased() + owner.possessive.dropFirst()) \(unit.plural) will show up here."
        // `detail` is non-nil for exactly these three kinds, so the fallback
        // is unreachable rather than a state. It is the sentence for "not yet"
        // rather than an empty string, so that if the two functions ever stop
        // agreeing the page says something true instead of nothing.
        case .more, .same, .fewer: return detail(summary) ?? beforeTheTrend
        }
    }

    private var beforeTheTrend: String { "Keep logging to see \(owner.possessive) trend." }

    /// The numbers, in words somebody's mum reads without a legend: how many
    /// a day, week or month lately, and what "usual" was.
    ///
    /// **This is the HEADLINE now, not the line under it** (cut 4,
    /// 2026-10-01). The name is kept because every word below is still true of
    /// it and because `shownDetail` is still the second line's function; what
    /// changed is which slot this text is drawn in. See `headline(_:)`.
    ///
    /// **Nil in the two states where it had nothing of its own to say**
    /// (2026-10-01, the type pass). It used to read "It appears once you have
    /// about 6 weeks of wins." under "Keep logging to see your trend.", and
    /// "Log a win and it's counted here." under "Your weeks will show up
    /// here." — the same sentence twice, which is what the owner means by
    /// "over explaining components loses the charm".
    ///
    /// It surfaced as a measurement rather than as taste: at 13 Regular that
    /// line fitted on one row, and at 15 Medium it wrapped to **three**, with
    /// "of wins." alone on the last. Three lines of repetition is the opposite
    /// of "everything thats not like photos to have air to breathe". The three
    /// states that remain all carry NUMBERS the chart has no other legend for.
    private func detail(_ summary: WinTrend.Summary) -> String? {
        let recent = Self.wins(summary.recentAverage)
        let usual = Self.wins(summary.usualAverage)
        let stretch = "the last \(unit.recent) \(unit.plural)"
        switch summary.kind {
        case .more:
            return "\(recent) a \(unit.name) over \(stretch), up from \(usual) before that."
        case .same:
            // "Close to", not "right in line with": inside the band is not
            // the same as equal, and 2.3 "right in line with" 2.7 read as the
            // page contradicting its own numbers.
            return "About \(recent) a \(unit.name) over \(stretch), close to \(owner.possessive) usual \(Self.number(summary.usualAverage))."
        case .fewer:
            return "\(recent) a \(unit.name) over \(stretch), down from \(usual) before that."
        case .notEnough, .empty:
            return nil
        }
    }

    /// "18", "4.5", "0.6" — whole above ten, one decimal below, and never a
    /// trailing ".0".
    private static func number(_ value: Double) -> String {
        if value >= 10 { return String(Int(value.rounded())) }
        let tenths = (value * 10).rounded() / 10
        return tenths == tenths.rounded() ? String(Int(tenths)) : String(format: "%.1f", tenths)
    }

    private static func wins(_ value: Double) -> String {
        let text = number(value)
        return "\(text) \(text == "1" ? "win" : "wins")"
    }

    // MARK: - A bar, picked out

    /// Tap a bar and the sentence above the chart becomes that day, week or
    /// month: its count and when it was. Where Apple Health puts a scrubbed
    /// value, so the number is read where the eye already is rather than in a
    /// callout covering the bars beside it. Tap it again for the trend back.
    private func picked(from bars: [WinTrend.Bar]) -> WinTrend.Bar? {
        guard let selectedBar else { return nil }
        return bars.first { $0.start == selectedBar }
    }

    private func shownHeadline(summary: WinTrend.Summary, bars: [WinTrend.Bar]) -> String {
        guard let bar = picked(from: bars) else { return headline(summary) }
        return "\(bar.count) \(bar.count == 1 ? "win" : "wins")"
    }

    /// The second line, and there is one only when a bar is picked.
    ///
    /// **Nil with nothing picked** (cut 4): `detail` is the headline now, so
    /// returning it here as well would print the sentence twice. With a bar
    /// picked the pair is a count over the period it belongs to — two facts,
    /// not one fact and a mood — which is the arrangement this slot was built
    /// for and the one it keeps.
    private func shownDetail(summary: WinTrend.Summary, bars: [WinTrend.Bar]) -> String? {
        guard let bar = picked(from: bars) else { return nil }
        switch unit {
        case .day:
            return bar.isCurrent
                ? "Today so far"
                : bar.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            let start = bar.start.formatted(.dateTime.month(.abbreviated).day())
            if bar.isCurrent { return "This week so far, since \(start)" }
            let end = Calendar.current.date(byAdding: .day, value: 6, to: bar.start)
                .map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? ""
            return "\(start) to \(end)"
        case .month:
            return bar.isCurrent
                ? "This month so far"
                : bar.start.formatted(.dateTime.month(.wide).year())
        }
    }

    private func barInk(for bar: WinTrend.Bar) -> Color {
        let share = bar.isCurrent ? Self.unfinishedBarShare : 1.0
        guard let selectedBar else { return AppColors.inkPrimary.opacity(share) }
        // The picked bar keeps its ink; the rest step back rather than
        // disappearing, so its height can still be compared with theirs.
        return AppColors.inkPrimary
            .opacity(bar.start == selectedBar ? share : share * Self.unpickedBarShare)
    }

    private func pick(_ date: Date, in bars: [WinTrend.Bar]) {
        let component = unit.component
        guard let bar = bars.first(where: { bar in
            Calendar.current.dateInterval(of: component, for: bar.start)?.contains(date) ?? false
        }) else { return }
        HapticsEngine.tick()
        selectedBar = selectedBar == bar.start ? nil : bar.start
    }

    // MARK: - The chart

    private func chart(_ bars: [WinTrend.Bar]) -> some View {
        let ticks = yTicks(bars)
        let labelEvery = unit == .day ? 7 : (unit == .week ? 4 : 3)
        let labelFormat: Date.FormatStyle = unit == .month
            ? .dateTime.month(.abbreviated)
            : .dateTime.month(.abbreviated).day()
        return Chart(bars) { bar in
            BarMark(x: .value("Period", bar.start, unit: unit.component),
                    y: .value("Wins", bar.count),
                    // 0.6 read as a wall of white slabs on the dark ground.
                    width: .ratio(0.5))
                .foregroundStyle(barInk(for: bar))
                .cornerRadius(GridConstants.radiusMark)
        }
        .chartYScale(domain: 0...(ticks.last ?? 2))
        .chartYAxis {
            AxisMarks(position: .trailing, values: ticks) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: GridConstants.headerDividerHeight))
                    // `quietFill` is the token for "a hairline's fill", and it
                    // is adaptive. The 0.1 here was a `.primary.opacity`, the
                    // one thing CLAUDE.md says a colour must never be.
                    .foregroundStyle(AppColors.quietFill)
                // **The axis reads at the page's body size, not at a size only
                // the chart uses.**
                //
                // These two labels were `Typography.caption2` (11 Medium),
                // then `bodySmall` (13), and are `screenSubtitle` (15 Medium)
                // since 2026-10-01. Profile carried four text sizes at the
                // default Dynamic Type setting (34 for the tally, 17, 13, 11)
                // where check 4 allows three, and the fourth existed to serve
                // one chart. A chart with a size of its own is a chart with a
                // type scale of its own. It is now 34 / 17 / 15, which is the
                // whole app's scale.
                //
                // The axis still recedes, because it recedes on INK
                // (inkSecondary, 0.62, measured 6.19:1) rather than on being
                // smaller than everything else.
                //
                // Collision rechecked at 15: at the week unit a label lands
                // every 4 bars, so three of them, about 46pt wide against the
                // 110pt they are spaced; at the month unit, four labels of
                // about 30pt against 83pt. Nothing touches — the margin was
                // 2.75x and is 2.39x.
                AxisValueLabel()
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: unit.component, count: labelEvery)) { _ in
                // The same size as the y axis above, for the same reason.
                AxisValueLabel(format: labelFormat)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        // A tap anywhere in the plot picks the period under it. The whole
        // plot is the target, not the bar: a bar 12pt wide is under the 44pt
        // the HIG asks for, and Apple HIG, Charts suggests exactly this.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plot = proxy.plotFrame else { return }
                        let x = location.x - geometry[plot].origin.x
                        guard let date: Date = proxy.value(atX: x) else { return }
                        pick(date, in: bars)
                    }
            }
        }
        .accessibilityChartDescriptor(PeriodWinsDescriptor(bars: bars, unit: unit,
                                                           summary: headline(summaries[unit] ?? WinTrend.Summary(kind: .empty))))
    }

    /// Familiar ticks — steps of 1, 2, 5, 10… — so the axis reads 0 / 10 / 20
    /// rather than 0 / 7 / 14 (Apple HIG, Charts: prefer familiar sequences).
    ///
    /// The smallest familiar step that covers the tallest bar in at most
    /// three steps. The first version took the smallest step whose DOUBLE
    /// covered it, which put a 21-win week under an axis running to 40: half
    /// the chart was empty sky above bars that all looked the same height.
    private func yTicks(_ bars: [WinTrend.Bar]) -> [Int] {
        let top = max(bars.map(\.count).max() ?? 0, 1)
        let steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000]
        let step = steps.first { top <= $0 * 3 } ?? Int((Double(top) / 3).rounded(.up))
        let count = Int((Double(top) / Double(step)).rounded(.up))
        return (0...max(count, 1)).map { $0 * step }
    }
}

/// VoiceOver and Audio Graphs for the chart: values with context, never
/// adjectives (Apple HIG, Charts).
private struct PeriodWinsDescriptor: AXChartDescriptorRepresentable {
    let bars: [WinTrend.Bar]
    let unit: WinTrend.Unit
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(unit == .month ? "MMMMyyyy" : "MMMd")
        let names = bars.map { formatter.string(from: $0.start) }
        let top = Double(bars.map(\.count).max() ?? 0)
        let title = "Wins per \(unit.name)"

        let xAxis = AXCategoricalDataAxisDescriptor(title: unit.title, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(title: "Wins",
                                                range: 0...max(top, 1),
                                                gridlinePositions: []) { value in
            let wins = Int(value)
            return "\(wins) \(wins == 1 ? "win" : "wins")"
        }
        let points = zip(bars, names).map { bar, name in
            AXDataPoint(x: name, y: Double(bar.count),
                        label: bar.isCurrent ? "This \(unit.name), so far" : nil)
        }
        let series = AXDataSeriesDescriptor(name: title, isContinuous: false, dataPoints: points)
        return AXChartDescriptor(title: title, summary: summary,
                                 xAxis: xAxis, yAxis: yAxis,
                                 additionalAxes: [], series: [series])
    }
}
