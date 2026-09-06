import SwiftUI
import SwiftData

/// Insights tab — momentum, density, balance and rhythm over a selectable window.
///
/// Framing is positive-only throughout, matching the app's reinforcement model
/// (coordination.md, Tower principles): no streak-loss language, no red "missed"
/// states, skipped counted as handled rather than failed. Numbers that can only
/// go up lead; rates support.
struct InsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Insights needs history, so this query is deliberately unscoped. Bounding it
    // needs either a verified string-comparison #Predicate on `dateString` or a
    // real Date column on HabitLog — see tasks/backlog.md.
    @Query private var allHabits: [Habit]
    @Query private var allLogs: [HabitLog]

    @State private var viewModel = InsightsViewModel()
    @AppStorage("insightsRange") private var rangeRaw: String = InsightsRange.month.rawValue
    @State private var rebuildTask: Task<Void, Never>?

    private var range: InsightsRange {
        InsightsRange(rawValue: rangeRaw) ?? .month
    }

    private var rangeBinding: Binding<InsightsRange> {
        Binding(
            get: { range },
            set: { rangeRaw = $0.rawValue }
        )
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : .white
    }

    private var cardStroke: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !viewModel.hasAnyHabits {
                        emptyState
                    } else {
                        rangePicker
                        summaryCard
                        heatmapCard
                        if !viewModel.habitMomentum.isEmpty { momentumCard }
                        if !viewModel.categoryTotals.isEmpty { balanceCard }
                        if let best = viewModel.bestWeekday { rhythmCard(best: best) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background { WarmBackground().ignoresSafeArea() }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { scheduleRebuild() }
        .onChange(of: rangeRaw) { scheduleRebuild() }
        .onChange(of: allHabits.count) { scheduleRebuild() }
        .onChange(of: allLogs.count) { scheduleRebuild() }
        .onDisappear { rebuildTask?.cancel() }
    }

    // MARK: - Rebuild (debounced, never in body)

    private func scheduleRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            viewModel.rebuild(habits: allHabits, logs: allLogs, range: range)
        }
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        Picker("Range", selection: rangeBinding) {
            ForEach(InsightsRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: rangeRaw) { HapticsEngine.tick() }
        .accessibilityLabel("Time range")
    }

    // MARK: - Summary

    private var summaryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                // Hero is a count, not a grade — it only ever goes up.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(viewModel.totalCompleted)")
                        .font(Typography.appTitle)
                        .foregroundStyle(Color.primary)
                        .contentTransition(.numericText())
                    Text("completed")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.primary.opacity(0.5))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.totalCompleted) completed in the \(range.longLabel)")

                Divider().opacity(0.4)

                HStack(spacing: 0) {
                    stat(value: "\(viewModel.activeDayCount)", label: "active days")
                    stat(value: "\(viewModel.totalSkipped)", label: "skipped")
                    stat(value: "\(Int((viewModel.handledRate * 100).rounded()))%", label: "handled")
                }
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Momentum", subtitle: range.longLabel)
                MomentumHeatmap(days: viewModel.days)
            }
        }
    }

    // MARK: - Per-Habit Momentum

    private var momentumCard: some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                sectionHeader("By habit", subtitle: "current run")
                    .padding(.bottom, 4)

                ForEach(Array(viewModel.habitMomentum.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().opacity(0.3)
                    }
                    HabitMomentumRow(momentum: item)
                }
            }
        }
    }

    // MARK: - Category Balance

    private var balanceCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Balance", subtitle: "completions by category")

                VStack(spacing: 10) {
                    ForEach(viewModel.categoryTotals) { total in
                        CategoryBar(total: total, reduceMotion: reduceMotion)
                    }
                }
            }
        }
    }

    // MARK: - Rhythm

    private func rhythmCard(best: WeekdayRhythm) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Rhythm", subtitle: "completion by weekday")

                Text("\(best.label) is your strongest day — \(Int((best.rate * 100).rounded()))% completed.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(viewModel.weekdayRhythm) { day in
                        WeekdayColumn(day: day, isBest: day.id == best.id, reduceMotion: reduceMotion)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: GridConstants.iconEmptyState, weight: .light))
                .foregroundStyle(Color.primary.opacity(0.25))
            Text("No habits yet")
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary.opacity(0.7))
            Text("Add a habit in Plan and your momentum will show up here.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.primary.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Scaffolding

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(Typography.headerSmall)
                .foregroundStyle(Color.primary)
            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(Color.primary.opacity(0.45))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    .fill(cardFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            }
    }
}

// MARK: - Category Bar

private struct CategoryBar: View {
    let total: CategoryTotal
    let reduceMotion: Bool

    @State private var fill: Double = 0

    private var style: CategoryStyle { total.category.style }

    var body: some View {
        HStack(spacing: 10) {
            // Icon + colour — never colour alone
            Image(systemName: total.category.iconName)
                .font(.system(size: GridConstants.iconMedium, weight: .medium))
                .foregroundStyle(style.baseColor)
                .frame(width: 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(style.baseColor.opacity(0.85))
                        .frame(width: max(4, geo.size.width * fill))
                }
            }
            .frame(height: 10)

            Text("\(total.completed)")
                .font(Typography.caption)
                .foregroundStyle(Color.primary.opacity(0.55))
                .frame(minWidth: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(total.category.rawValue.capitalized), \(total.completed) completed")
        .onAppear {
            if reduceMotion {
                fill = total.share
            } else {
                withAnimation(GridConstants.progressFill) { fill = total.share }
            }
        }
        .onChange(of: total.share) { _, newShare in
            if reduceMotion {
                fill = newShare
            } else {
                withAnimation(GridConstants.progressFill) { fill = newShare }
            }
        }
    }
}

// MARK: - Weekday Column

private struct WeekdayColumn: View {
    let day: WeekdayRhythm
    let isBest: Bool
    let reduceMotion: Bool

    @State private var height: Double = 0

    private let maxBarHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: maxBarHeight)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AppColors.healthGreen.opacity(isBest ? 0.9 : 0.45))
                    .frame(height: max(2, maxBarHeight * height))
            }
            .frame(height: maxBarHeight)

            Text(day.label)
                .font(Typography.caption2)
                .foregroundStyle(Color.primary.opacity(isBest ? 0.75 : 0.4))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            day.scheduled > 0
                ? "\(day.label), \(Int((day.rate * 100).rounded())) percent completed"
                : "\(day.label), nothing scheduled"
        )
        .onAppear {
            if reduceMotion {
                height = day.rate
            } else {
                withAnimation(GridConstants.progressFill) { height = day.rate }
            }
        }
        .onChange(of: day.rate) { _, newRate in
            if reduceMotion {
                height = newRate
            } else {
                withAnimation(GridConstants.progressFill) { height = newRate }
            }
        }
    }
}
