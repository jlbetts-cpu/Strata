import SwiftUI
import SwiftData

@main
struct StrataApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            HabitLog.self,
            MoodLog.self,
            Tower.self,
            PlanFolder.self,
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(eventKitService)
                .environment(healthKitService)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                try? sharedModelContainer.mainContext.save()
            }
        }
    }
}
