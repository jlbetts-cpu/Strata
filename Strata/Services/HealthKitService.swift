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

@Observable
final class HealthKitService {
    private(set) var isAvailable = false
    private(set) var isAuthorized = false
    private(set) var todaysWorkouts: [WorkoutEvent] = []

    // MARK: - Check Availability

    func checkAvailability() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Request Access

    func requestAccess() async {
        guard isAvailable else { return }

        let healthStore = HKHealthStore()
        let workoutType = HKObjectType.workoutType()
        let readTypes: Set<HKObjectType> = [workoutType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            fetchTodaysWorkouts()
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Fetch Today's Workouts

    func fetchTodaysWorkouts() {
        guard isAuthorized else { return }

        let healthStore = HKHealthStore()
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
}
