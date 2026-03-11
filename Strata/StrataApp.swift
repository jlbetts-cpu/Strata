import SwiftUI
import SwiftData

@main
struct StrataApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            HabitLog.self,
            MoodLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var eventKitService = EventKitService()
    @State private var healthKitService = HealthKitService()

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(eventKitService)
                .environment(healthKitService)
        }
        .modelContainer(sharedModelContainer)
    }
}
