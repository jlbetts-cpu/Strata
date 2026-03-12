import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EventKitService.self) private var eventKitService
    @Environment(HealthKitService.self) private var healthKitService
    @Query private var habits: [Habit]
    @Query private var logs: [HabitLog]

    @State private var selectedTab: StrataTab = .tower
    @State private var selectedDate: Date = Date()
    @State private var towerVM = TowerViewModel()
    @State private var timelineVM = TimelineViewModel()
    @State private var gamificationVM = GamificationViewModel()
    @State private var streakVM = StreakViewModel()
    @State private var habitManagerVM = HabitManagerViewModel()
    @State private var hasLoadedDemo = false
    @State private var showLevelUpOverlay = false
    @State private var lastWorkoutCheck = Date()

    // Dates that had all habits completed
    private var completedDates: Set<String> {
        // Simple: dates where at least one log is completed
        Set(logs.filter { $0.completed }.map { $0.dateString })
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HeaderView(
                    completionRate: timelineVM.completionRate,
                    totalBlocks: gamificationVM.totalBlocksCompleted
                )

                // Week calendar strip
                WeekStripView(
                    selectedDate: selectedDate,
                    completedDates: completedDates,
                    onSelectDate: { date in
                        selectedDate = date
                        refreshData()
                    }
                )

                // Main content
                Group {
                    switch selectedTab {
                    case .tower:
                        TowerTabView(
                            towerVM: towerVM,
                            gamificationVM: gamificationVM,
                            onBlockTap: handleBlockTap
                        )
                    case .tasks:
                        tasksPlaceholder
                    case .journal:
                        journalPlaceholder
                    case .profile:
                        profilePlaceholder
                    }
                }
                .frame(maxHeight: .infinity)

                // Tab bar
                TabBarView(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)

            // Level up overlay
            if showLevelUpOverlay {
                LevelUpOverlay(
                    level: gamificationVM.newLevel,
                    title: XPEngine.title(forLevel: gamificationVM.newLevel),
                    onDismiss: {
                        showLevelUpOverlay = false
                        gamificationVM.dismissLevelUp()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.5), value: showLevelUpOverlay)
        .onAppear(perform: setup)
        .onChange(of: habits.count) { refreshData() }
        .onChange(of: logs.count) { refreshData() }
        .onChange(of: healthKitService.todaysWorkouts.count) {
            autoCompleteHealthHabits()
        }
    }

    // MARK: - Setup

    private func setup() {
        timelineVM.modelContext = modelContext
        habitManagerVM.modelContext = modelContext

        if habits.isEmpty && !hasLoadedDemo {
            hasLoadedDemo = true
            habitManagerVM.insertDemoData()
        }

        refreshData()

        // Request ecosystem access
        Task {
            await eventKitService.requestAccess()
            healthKitService.checkAvailability()
            await healthKitService.requestAccess()
            lastWorkoutCheck = Date()
        }
    }

    private func refreshData() {
        timelineVM.loadToday(habits: habits, logs: logs)
        gamificationVM.recalculate(from: logs)

        towerVM.buildTower(from: logs)

        // Check for level up
        if gamificationVM.showLevelUp {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                showLevelUpOverlay = true
            }
        }
    }

    // MARK: - Auto-Complete Health Habits from HealthKit

    private func autoCompleteHealthHabits() {
        let newWorkouts = healthKitService.newWorkoutsSince(lastWorkoutCheck)
        guard !newWorkouts.isEmpty else { return }

        let healthHabits = timelineVM.incompleteToday.filter { $0.category == .health }
        guard let firstHealthHabit = healthHabits.first else { return }

        for _ in newWorkouts.prefix(healthHabits.count) {
            handleHabitComplete(firstHealthHabit)
        }

        lastWorkoutCheck = Date()
    }

    // MARK: - Habit Completion (Cascade Drop Trigger)

    private func handleHabitComplete(_ habit: Habit) {
        timelineVM.completeHabit(habit)

        // Rebuild tower with animation -- new block cascades in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            timelineVM.loadToday(habits: habits, logs: logs)
            towerVM.buildTower(from: logs)
        }

        gamificationVM.recalculate(from: logs)
    }

    // MARK: - Block Tap (XP Collection)

    private func handleBlockTap(_ block: PlacedBlock) {
        guard !block.log.xpCollected, block.log.pendingXP != nil else { return }
        timelineVM.collectXP(for: block.log)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        gamificationVM.recalculate(from: logs)
    }

    // MARK: - Placeholder Tabs

    private var tasksPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Tasks")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var journalPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Journal")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var profilePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Profile")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
}
