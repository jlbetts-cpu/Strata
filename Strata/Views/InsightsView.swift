import SwiftUI
import SwiftData

struct InsightsView: View {
    let habits: [Habit]
    let logs: [HabitLog]
    var onAddHabit: (() -> Void)? = nil
    var onNavigateToTower: ((TowerFilterMode) -> Void)? = nil

    @State private var viewModel = InsightsViewModel()
    @State private var showAllStreaks = false
    @State private var selectedInsightHabit: Habit? = nil
    @Environment(\.switchTab) private var switchTab

    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Empty state
                if habits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(Typography.brandHeader)
                            .foregroundStyle(Color.primary.opacity(0.35))
                        Text("Complete habits to see your journey here")
                            .font(Typography.headerMedium)
                            .foregroundStyle(Color.primary.opacity(0.6))
                        Text("Complete habits on the Today tab\nto track your progress here")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }

                // SECTION 1: STREAKS (Hero)
                if !viewModel.streaks.isEmpty {
                    streaksSection
                }

                // SECTION 2: PHOTO CALENDAR
                calendarSection

                // SECTION 3: DAY DETAIL (tap to reveal)
                if let selectedDay = viewModel.selectedDay,
                   let dayInsight = viewModel.monthDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) && $0.isCurrentMonth }) {
                    dayDetailCard(for: dayInsight)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsEngine.tick()
                    onAddHabit?()
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.accentWarm)
                }
            }
        }
        .onAppear {
            viewModel.compute(habits: habits, logs: logs)
        }
    }

    // MARK: - Streaks Section

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STREAKS")
                .font(Typography.caption)
                .tracking(0.5)
                .foregroundStyle(Color.primary.opacity(0.5))

            let sortedStreaks = viewModel.streaks.sorted { $0.streak > $1.streak }
            let displayedStreaks = showAllStreaks ? sortedStreaks : Array(sortedStreaks.prefix(3))
            ForEach(displayedStreaks, id: \.habit.id) { item in
                NavigationLink {
                    HabitCalendarView(
                        habit: item.habit,
                        logs: logs,
                        currentStreak: item.streak,
                        bestStreak: item.bestStreak
                    )
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.habit.category.iconName)
                            .font(Typography.caption)
                            .foregroundStyle(item.habit.category.style.baseColor)
                            .frame(width: 32, height: 32)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(item.habit.category.style.baseColor.opacity(0.18), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.habit.title)
                                .font(Typography.bodyMedium)
                                .foregroundStyle(.primary)
                            if item.habit.graceDays > 0 {
                                Text("\(item.habit.graceDays)d grace")
                                    .font(Typography.caption2)
                                    .foregroundStyle(Color.primary.opacity(0.5))
                            }
                        }

                        Spacer()

                        Text("\(item.streak)")
                            .font(Typography.headerLarge)
                            .foregroundStyle(item.streak > 0 ? AppColors.healthGreen : Color.primary.opacity(0.3))

                        Text(item.streak == 1 ? "day" : "days")
                            .font(Typography.caption)
                            .foregroundStyle(Color.primary.opacity(0.4))

                        Image(systemName: "chevron.right")
                            .font(Typography.caption2)
                            .foregroundStyle(Color.primary.opacity(0.4))
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            stops: [
                                .init(color: item.habit.category.style.lightTint, location: 0.0),
                                .init(color: item.habit.category.style.baseColor, location: 0.3),
                                .init(color: item.habit.category.style.baseColor, location: 1.0)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .opacity(0.12),
                        in: RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        onNavigateToTower?(.week)
                    } label: {
                        Label("View on Tower", systemImage: "square.stack.fill")
                    }
                    Button {
                        switchTab?(.today)
                    } label: {
                        Label("View in Today", systemImage: "calendar")
                    }
                }
            }

            // Progressive disclosure (Miller 1956, Shneiderman 1996)
            if sortedStreaks.count > 3 {
                Button {
                    withAnimation(GridConstants.gentleReveal) { showAllStreaks.toggle() }
                } label: {
                    Text(showAllStreaks ? "Show less" : "Show all \(sortedStreaks.count) habits")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
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
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
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
                    Image(systemName: status.habit.category.iconName)
                        .font(Typography.caption)
                        .foregroundStyle(status.habit.category.style.baseColor)

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
