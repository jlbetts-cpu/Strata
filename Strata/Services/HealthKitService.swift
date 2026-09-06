import Foundation
import HealthKit

struct WorkoutEvent: Identifiable, Sendable {
    let id: UUID
    let workoutType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let calories: Double?

    var displayName: String {
        switch workoutType {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Bike Ride"
        case .swimming: return "Swim"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        case .hiking: return "Hike"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stairs"
        default: return "Workout"
        }
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }
}

/// HealthKit type identifiers used for habit auto-verification
enum HealthKitHabitType: String, CaseIterable {
    case stepCount = "stepCount"
    case workout = "workout"               // Any workout
    case workoutRunning = "workout.running"
    case workoutWalking = "workout.walking"
    case workoutCycling = "workout.cycling"
    case workoutSwimming = "workout.swimming"
    case workoutYoga = "workout.yoga"
    case workoutStrength = "workout.strength"
    case workoutHIIT = "workout.hiit"
    case mindfulSession = "mindfulSession"

    var displayName: String {
        switch self {
        case .stepCount: return "Steps"
        case .workout: return "Any Workout"
        case .workoutRunning: return "Running"
        case .workoutWalking: return "Walking"
        case .workoutCycling: return "Cycling"
        case .workoutSwimming: return "Swimming"
        case .workoutYoga: return "Yoga"
        case .workoutStrength: return "Strength Training"
        case .workoutHIIT: return "HIIT"
        case .mindfulSession: return "Mindfulness"
        }
    }

    var iconName: String {
        switch self {
        case .stepCount: return "figure.walk"
        case .workout: return "figure.mixed.cardio"
        case .workoutRunning: return "figure.run"
        case .workoutWalking: return "figure.walk"
        case .workoutCycling: return "figure.outdoor.cycle"
        case .workoutSwimming: return "figure.pool.swim"
        case .workoutYoga: return "figure.yoga"
        case .workoutStrength: return "dumbbell.fill"
        case .workoutHIIT: return "bolt.heart.fill"
        case .mindfulSession: return "brain.head.profile"
        }
    }

    var defaultThreshold: Double {
        switch self {
        case .stepCount: return 10000
        case .workout, .workoutRunning, .workoutWalking, .workoutCycling,
             .workoutSwimming, .workoutYoga, .workoutStrength, .workoutHIIT:
            return 0 // Presence-based
        case .mindfulSession: return 10 // 10 minutes
        }
    }

    var thresholdUnit: String {
        switch self {
        case .stepCount: return "steps"
        case .mindfulSession: return "min"
        default: return ""
        }
    }

    var thresholdPresets: [(label: String, value: Double)] {
        switch self {
        case .stepCount:
            return [("5,000", 5000), ("7,500", 7500), ("10,000", 10000), ("12,000", 12000)]
        case .mindfulSession:
            return [("5 min", 5), ("10 min", 10), ("15 min", 15), ("30 min", 30)]
        default:
            return [] // Presence-based — no threshold needed
        }
    }

    /// Whether this type uses presence detection (any sample = done) vs cumulative threshold
    var isPresenceBased: Bool {
        switch self {
        case .stepCount, .mindfulSession: return false
        default: return true
        }
    }

    /// The HKObjectType(s) needed for authorization
    var requiredReadTypes: Set<HKObjectType> {
        switch self {
        case .stepCount:
            return [HKQuantityType(.stepCount)]
        case .workout, .workoutRunning, .workoutWalking, .workoutCycling,
             .workoutSwimming, .workoutYoga, .workoutStrength, .workoutHIIT:
            return [HKObjectType.workoutType()]
        case .mindfulSession:
            return [HKCategoryType(.mindfulSession)]
        }
    }

    /// Maps workout subtypes to HKWorkoutActivityType for filtering
    var workoutActivityType: HKWorkoutActivityType? {
        switch self {
        case .workoutRunning: return .running
        case .workoutWalking: return .walking
        case .workoutCycling: return .cycling
        case .workoutSwimming: return .swimming
        case .workoutYoga: return .yoga
        case .workoutStrength: return .traditionalStrengthTraining
        case .workoutHIIT: return .highIntensityIntervalTraining
        default: return nil
        }
    }
}

/// Notification posted when a habit crosses its HealthKit threshold
extension Notification.Name {
    static let healthKitHabitVerified = Notification.Name("healthKitHabitVerified")
}

@Observable
final class HealthKitService {
    private(set) var isAvailable = false
    private(set) var isAuthorized = false
    private(set) var todaysWorkouts: [WorkoutEvent] = []

    /// Per-habit progress (0.0 → 1.0) keyed by habit UUID
    private(set) var habitProgress: [UUID: Double] = [:]

    /// Habit UUIDs that have crossed their threshold (verified-ready)
    private(set) var verifiedHabitIDs: Set<UUID> = []

    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var refreshTimer: Timer?

    // Connected habits (set from MainAppView)
    var connectedHabits: [(id: UUID, type: String, threshold: Double)] = []

    // MARK: - Check Availability

    func checkAvailability() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Request Access

    func requestAccess() async {
        guard isAvailable else { return }

        // Collect all types needed by connected habits
        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]

        for habit in connectedHabits {
            if let hkType = HealthKitHabitType(rawValue: habit.type) {
                readTypes.formUnion(hkType.requiredReadTypes)
            }
        }

        // Always request steps + mindfulness for future connections
        readTypes.insert(HKQuantityType(.stepCount))
        readTypes.insert(HKCategoryType(.mindfulSession))

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            fetchTodaysWorkouts()
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Request Access for Specific Type

    func requestAccess(for type: HealthKitHabitType) async -> Bool {
        guard isAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: type.requiredReadTypes)
            isAuthorized = true
            return true
        } catch {
            return false
        }
    }

    // MARK: - Fetch Today's Workouts

    func fetchTodaysWorkouts() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            guard let workouts = samples as? [HKWorkout] else { return }

            let events = workouts.map { workout in
                let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie())

                return WorkoutEvent(
                    id: UUID(),
                    workoutType: workout.workoutActivityType,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    duration: workout.duration,
                    calories: calories
                )
            }

            Task { @MainActor [weak self] in
                self?.todaysWorkouts = events
            }
        }

        healthStore.execute(query)
    }

    // MARK: - New Workouts Since

    func newWorkoutsSince(_ date: Date) -> [WorkoutEvent] {
        todaysWorkouts.filter { $0.endDate > date }
    }

    // MARK: - Setup Observer Queries (Background Delivery)

    func setupObservers() {
        guard isAvailable, isAuthorized else { return }

        // Clean up existing observers
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries = []

        // Steps observer (hourly is sufficient for cumulative)
        setupObserver(for: HKQuantityType(.stepCount))

        // Workout observer (immediate — discrete events)
        setupObserver(for: HKObjectType.workoutType())

        // Mindfulness observer (immediate)
        setupObserver(for: HKCategoryType(.mindfulSession))

        // Enable background delivery
        healthStore.enableBackgroundDelivery(for: HKQuantityType(.stepCount), frequency: .hourly) { _, _ in }
        healthStore.enableBackgroundDelivery(for: HKObjectType.workoutType(), frequency: .immediate) { _, _ in }
        healthStore.enableBackgroundDelivery(for: HKCategoryType(.mindfulSession), frequency: .immediate) { _, _ in }
    }

    private func setupObserver(for sampleType: HKSampleType) {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, _ in
            Task { @MainActor [weak self] in
                self?.refreshProgress()
                self?.evaluateThresholds()
            }
            completionHandler()
        }
        healthStore.execute(query)
        observerQueries.append(query)
    }

    // MARK: - Start Foreground Polling (5-min timer)

    func startForegroundPolling() {
        stopForegroundPolling()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshProgress()
                self?.evaluateThresholds()
            }
        }
    }

    func stopForegroundPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Refresh Progress for All Connected Habits

    func refreshProgress() {
        guard isAuthorized else { return }

        for habit in connectedHabits {
            guard let hkType = HealthKitHabitType(rawValue: habit.type) else { continue }
            fetchProgress(for: habit.id, type: hkType, threshold: habit.threshold)
        }
    }

    private func fetchProgress(for habitID: UUID, type: HealthKitHabitType, threshold: Double) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        switch type {
        case .stepCount:
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(.stepCount),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let progress = threshold > 0 ? min(steps / threshold, 1.0) : (steps > 0 ? 1.0 : 0.0)
                Task { @MainActor [weak self] in
                    self?.habitProgress[habitID] = progress
                }
            }
            healthStore.execute(query)

        case .mindfulSession:
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.mindfulSession),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, _ in
                let totalMinutes = (samples ?? []).reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                }
                let progress = threshold > 0 ? min(totalMinutes / threshold, 1.0) : (totalMinutes > 0 ? 1.0 : 0.0)
                Task { @MainActor [weak self] in
                    self?.habitProgress[habitID] = progress
                }
            }
            healthStore.execute(query)

        case .workout, .workoutRunning, .workoutWalking, .workoutCycling,
             .workoutSwimming, .workoutYoga, .workoutStrength, .workoutHIIT:
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, _ in
                let workouts = samples as? [HKWorkout] ?? []
                let matched: Bool
                if let activityType = type.workoutActivityType {
                    matched = workouts.contains { $0.workoutActivityType == activityType }
                } else {
                    matched = !workouts.isEmpty // Any workout
                }
                Task { @MainActor [weak self] in
                    self?.habitProgress[habitID] = matched ? 1.0 : 0.0
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Evaluate Thresholds

    func evaluateThresholds() {
        // Clean up stale entries for disconnected habits
        let connectedIDs = Set(connectedHabits.map(\.id))
        verifiedHabitIDs = verifiedHabitIDs.intersection(connectedIDs)
        habitProgress = habitProgress.filter { connectedIDs.contains($0.key) }

        var newlyVerified: [UUID] = []

        for habit in connectedHabits {
            let progress = habitProgress[habit.id] ?? 0
            if progress >= 1.0 && !verifiedHabitIDs.contains(habit.id) {
                verifiedHabitIDs.insert(habit.id)
                newlyVerified.append(habit.id)
            } else if progress < 1.0 {
                verifiedHabitIDs.remove(habit.id)
            }
        }

        if !newlyVerified.isEmpty {
            NotificationCenter.default.post(
                name: .healthKitHabitVerified,
                object: nil,
                userInfo: ["habitIDs": newlyVerified]
            )
        }
    }

    // MARK: - Reset for New Day

    func resetDailyState() {
        habitProgress = [:]
        verifiedHabitIDs = []
    }
}
