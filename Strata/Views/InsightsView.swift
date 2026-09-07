import SwiftUI
import SwiftData

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

    @State private var viewModel = InsightsViewModel()
    @State private var showAllStreaks = false
    @State private var selectedInsightHabit: Habit? = nil
    @Environment(\.switchTab) private var switchTab

    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                towerChartSection

                // Empty state
                if habits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(Typography.brandHeader)
                            .foregroundStyle(Color.primary.opacity(0.35))
                        Text("Nothing to show yet")
                            .font(Typography.headerMedium)
                            .foregroundStyle(Color.primary.opacity(0.6))
                        Text("Log a win and it shows up here.")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }

                // SECTION 2: PHOTO CALENDAR
                calendarSection

                // SECTION 3: DAY DETAIL (tap to reveal)
                if let selectedDay = viewModel.selectedDay,
                   let dayInsight = viewModel.monthDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) && $0.isCurrentMonth }) {
                    dayDetailCard(for: dayInsight)
                }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.bottom, 100)
        }
        .background { WarmBackground().ignoresSafeArea() }
        // No navigation bar at all, so the count sits where the other pages'
        // counts sit.
        //
        // The bar was reserving about 44pt above the content, which put this
        // page's numeral that much lower than the identical numeral on the
        // tower and the camera — one number, three heights. Settings moves
        // into the header row, which is where it can live without costing a
        // bar.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.compute(habits: habits, logs: logs)
        }
    }

    // MARK: - The towers, side by side

    /// The hero. Every period drawn as the tower it actually was.
    ///
    /// It leads because it is the only thing here that answers the question
    /// people open this tab with — how am I doing — in one look, and it
    /// answers it in the app's own language rather than in a chart's. The
    /// header is the tower's header: same numeral, same word, same range
    /// picker in the same corner, so moving between the two screens is moving
    /// between two views of one thing rather than between two designs.
    private var towerChartSection: some View {
        let columns = chartColumns
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(columns.reduce(0) { $0 + $1.winCount })")
                    .font(.system(size: GridConstants.tallyNumeral, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))
                    .contentTransition(.numericText())
                Text("wins")
                    .font(.system(size: GridConstants.tallyWord, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.35))
                Spacer(minLength: 0)
                TowerRangePicker(selection: Binding(
                    get: { range },
                    set: { range = $0 }
                ))
                Button {
                    HapticsEngine.lightTap()
                    openSettings?()
                } label: {
                    Image(systemName: "gearshape")
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .regular)
                        .foregroundStyle(.primary.opacity(0.45))
                        .frame(width: 34, height: 34)
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

            TowerBarChart(
                columns: columns,
                maxRows: max(columns.map(\.rows).max() ?? 0, 4)
            )
            // The chart already insets itself to the page's padding, and this
            // section is inside a container that adds its own.
            .padding(.horizontal, -16)
        }
        .padding(.top, 4)
    }

    /// One column per period, most recent last.
    ///
    /// The window is a fixed count of periods rather than "everything", so the
    /// bars stay a readable width and the chart says what you have been doing
    /// lately — which is the question — instead of compressing a year into a
    /// smear.
    private var chartColumns: [TowerBarChart.Column] {
        let calendar = Calendar.current
        let now = Date()
        let component: Calendar.Component
        let count: Int
        switch range {
        case .day:   component = .day;        count = 14
        case .week:  component = .weekOfYear; count = 12
        case .month: component = .month;      count = 12
        }

        // Index the logs once by the period they fall in, rather than filtering
        // the whole set once per column.
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
                label: label(for: start, component: component, calendar: calendar),
                isCurrent: start == currentStart,
                blocks: MiniTowerPacker.pack(byPeriod[start] ?? [])
            )
        }
    }

    private func label(for date: Date, component: Calendar.Component, calendar: Calendar) -> String {
        switch component {
        case .day:
            // One letter. Under a bar this narrow anything longer wraps or
            // clips, and the shape of the week is legible from initials.
            return String(date.formatted(.dateTime.weekday(.narrow)))
        case .weekOfYear:
            return "\(calendar.component(.day, from: date))"
        default:
            return String(date.formatted(.dateTime.month(.narrow)))
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - The streak

    /// One streak: consecutive days you logged something.
    ///
    /// Per-habit streaks went with repeating habits — there is nothing left to
    /// keep a streak ON. A streak per habit was also the wrong count for this
    /// app even when it had them: it rewards doing the same thing, and the
    /// tower rewards doing anything. This counts days you showed up, which is
    /// the only claim the data can still make.
    ///
    /// Today not being logged yet does not break it. A streak that resets at
    /// midnight and shames you until lunch is measuring the clock, not you —
    /// so the count runs back from today if today has something, and from
    /// yesterday if it does not.
    private var dailyStreak: Int {
        let calendar = Calendar.current
        var days = Set<String>()
        for log in logs where log.completed { days.insert(log.dateString) }
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

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) {
                        viewModel.previousMonth(habits: habits, logs: logs)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text(viewModel.monthTitle)
                    .font(Typography.headerMedium)
                    .foregroundStyle(.primary)
                    .contentTransition(.interpolate)

                Spacer()

                Button {
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) {
                        viewModel.nextMonth(habits: habits, logs: logs)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(width: 44, height: 44)
                }
            }

            // Day labels
            LazyVGrid(columns: dayColumns, spacing: 0) {
                // Indexed, not `id: \.self`: the labels contain "T" and "S"
                // twice, and identical ids collapse into one element — the
                // header rendered as S M T W _ F _, with Thursday and Saturday
                // simply missing.
                ForEach(dayLabels.indices, id: \.self) { index in
                    Text(dayLabels[index])
                        .font(Typography.caption2)
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: dayColumns, spacing: 4) {
                ForEach(viewModel.monthDays) { day in
                    if day.isCurrentMonth {
                        calendarCell(for: day)
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
    }

    // MARK: - Calendar Cell

    private func calendarCell(for day: InsightsViewModel.DayInsight) -> some View {
        let isSelected = viewModel.selectedDay != nil &&
            Calendar.current.isDate(day.date, inSameDayAs: viewModel.selectedDay!)

        return Button {
            HapticsEngine.lightTap()
            withAnimation(GridConstants.gentleReveal) {
                if isSelected {
                    viewModel.selectedDay = nil
                } else {
                    viewModel.selectedDay = day.date
                }
            }
        } label: {
            ZStack {
                if let photoFile = day.photoFileNames.first {
                    // Photo IS the cell (Liftoff pattern, Paivio 1971)
                    CachedImageView(
                        fileName: photoFile,
                        width: 48, height: 48,
                        cornerRadius: 0
                    )
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.45)],
                        startPoint: .top, endPoint: .bottom
                    )
                    Text("\(day.dayNumber)")
                        .font(Typography.caption)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(4)
                    // Multi-photo badge
                    if day.photoFileNames.count > 1 {
                        Text("+\(day.photoFileNames.count - 1)")
                            .font(Typography.miniBlockIcon)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(3)
                    }
                } else {
                    // Standard cell — day number + status dot
                    VStack(spacing: 3) {
                        Text("\(day.dayNumber)")
                            .font(Typography.caption)
                            .fontWeight(day.isToday ? .bold : .regular)
                            .foregroundStyle(day.isFuture ? Color.primary.opacity(0.3) : Color.primary)
                        if !day.isFuture && day.totalCount > 0 {
                            Circle()
                                .fill(day.completedCount > 0 ? AppColors.healthGreen : Color.primary.opacity(0.15))
                                .frame(width: 6, height: 6)
                        } else {
                            Color.clear.frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: GridConstants.cornerRadiusSmall, style: .continuous)
                            .fill(day.isToday ? AppColors.healthGreen.opacity(0.08) :
                                  (isSelected ? Color.primary.opacity(0.06) : Color.clear))
                    )
                }
            }
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Detail Card

    private func dayDetailCard(for day: InsightsViewModel.DayInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header
            Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(Typography.headerSmall)
                .foregroundStyle(.primary)

            // Photos — horizontal carousel for multi-photo days
            if !day.photoFileNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(day.photoFileNames, id: \.self) { file in
                            CachedImageView(
                                fileName: file,
                                width: day.photoFileNames.count == 1 ? 320 : 200,
                                height: 140,
                                cornerRadius: 0
                            )
                            .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadiusSmall, style: .continuous))
                            .accessibilityLabel("Habit photo")
                        }
                    }
                }
            }

            // Habit statuses — tappable (Pirolli & Card 1999: information scent)
            ForEach(day.habitStatuses) { status in
                Button {
                    selectedInsightHabit = status.habit
                } label: {
                HStack(spacing: 10) {
                    if let icon = status.habit.category.iconName {
                        Image(systemName: icon)
                            .font(Typography.caption)
                            .foregroundStyle(status.habit.category.style.baseColor)
                    }

                    Text(status.habit.title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.primary)
                        .strikethrough(status.isCompleted || status.isSkipped)

                    Spacer()

                    if status.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Typography.bodySmall)
                            .foregroundStyle(AppColors.healthGreen)
                    } else if status.isSkipped {
                        Image(systemName: "minus.circle")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.primary.opacity(0.3))
                    } else {
                        Image(systemName: "circle")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.primary.opacity(0.15))
                    }
                }
                }
                .buttonStyle(.plain)
            }

            if day.habitStatuses.isEmpty {
                Text("Nothing logged this day")
                    .font(Typography.caption)
                    .foregroundStyle(Color.primary.opacity(0.3))
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .sheet(item: $selectedInsightHabit) { habit in
            HabitDetailSheet(habit: habit, selectedDate: day.date)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Habit Calendar Drill-Down

struct HabitCalendarView: View {
    let habit: Habit
    let logs: [HabitLog]
    let currentStreak: Int
    let bestStreak: Int

    @State private var selectedMonth: Date = Date()

    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private var style: CategoryStyle { habit.category.style }

    private var monthTitle: String {
        selectedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var habitLogs: [String: HabitLog] {
        Dictionary(
            logs.filter { $0.habit?.id == habit.id }
                .map { ($0.dateString, $0) },
            uniquingKeysWith: { _, last in last }
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Streak header
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("\(currentStreak)")
                            .font(Typography.appTitle)
                            .foregroundStyle(currentStreak > 0 ? style.baseColor : Color.primary.opacity(0.3))
                        VStack(alignment: .leading) {
                            Text(currentStreak == 1 ? "day streak" : "day streak")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(.primary)
                            if habit.graceDays > 0 {
                                Text("\(habit.graceDays) day grace period")
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.primary.opacity(0.4))
                            }
                        }
                    }

                    Text("Best: \(bestStreak) days")
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                // Month navigation
                HStack {
                    Button {
                        HapticsEngine.tick()
                        let calendar = Calendar.current
                        if let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                            withAnimation(GridConstants.motionSmooth) { selectedMonth = prev }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .frame(width: 44, height: 44)
                    }

                    Spacer()
                    Text(monthTitle)
                        .font(Typography.headerMedium)
                        .contentTransition(.interpolate)
                    Spacer()

                    Button {
                        HapticsEngine.tick()
                        let calendar = Calendar.current
                        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                            withAnimation(GridConstants.motionSmooth) { selectedMonth = next }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .frame(width: 44, height: 44)
                    }
                }

                // Calendar grid for this habit
                habitMonthGrid

                // Stats
                let monthLogs = logs.filter {
                    $0.habit?.id == habit.id &&
                    $0.dateString.hasPrefix(TimelineViewModel.dateString(from: selectedMonth).prefix(7).description)
                }
                let completed = monthLogs.filter { $0.completed }.count
                let skipped = monthLogs.filter { $0.skipped }.count
                let total = completed + skipped

                if total > 0 {
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(Int(Double(completed) / Double(max(total, 1)) * 100))%")
                                .font(Typography.headerLarge)
                                .foregroundStyle(style.baseColor)
                            Text("completion")
                                .font(Typography.caption)
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                        VStack {
                            Text("\(skipped)")
                                .font(Typography.headerLarge)
                                .foregroundStyle(Color.primary.opacity(0.4))
                            Text("skipped")
                                .font(Typography.caption)
                                .foregroundStyle(Color.primary.opacity(0.4))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle(habit.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var habitMonthGrid: some View {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth) else {
            return AnyView(EmptyView())
        }
        let firstDay = monthInterval.start
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var cells: [(day: Int, dateStr: String, status: String)] = []

        // Leading blanks
        for _ in 0..<firstWeekday {
            cells.append((0, "", "blank"))
        }

        // Month days
        for offset in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: offset, to: firstDay) {
                let dateStr = TimelineViewModel.dateString(from: date)
                let log = habitLogs[dateStr]
                let isFuture = date > Date() && !calendar.isDateInToday(date)

                let status: String
                if isFuture { status = "future" }
                else if log?.completed == true { status = "completed" }
                else if log?.skipped == true { status = "skipped" }
                else { status = "empty" }

                cells.append((offset + 1, dateStr, status))
            }
        }

        return AnyView(
            LazyVGrid(columns: dayColumns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if cell.day == 0 {
                        Color.clear.frame(height: 40)
                    } else {
                        VStack(spacing: 2) {
                            Text("\(cell.day)")
                                .font(Typography.caption2)
                                .foregroundStyle(cell.status == "future" ? Color.primary.opacity(0.3) : Color.primary)

                            Circle()
                                .fill(
                                    cell.status == "completed" ? style.baseColor :
                                    cell.status == "skipped" ? Color.primary.opacity(0.2) :
                                    Color.primary.opacity(0.06)
                                )
                                .frame(width: 8, height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                    }
                }
            }
        )
    }
}
