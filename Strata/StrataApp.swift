import SwiftUI
import SwiftData
import AppIntents

@main
struct StrataApp: App {
    @State private var eventKitService = EventKitService()
    @State private var healthKitService = HealthKitService()
    @State private var focusFilterService = FocusFilterService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register ModelContainer for App Intents access (WWDC 2024 pattern)
        AppDependencyManager.shared.add(dependency: SharedModelContainer.shared)
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(eventKitService)
                .environment(healthKitService)
                .environment(focusFilterService)
                .onAppear {
                    // Initialize HealthKit availability check and observers on launch
                    healthKitService.checkAvailability()
                    // Initial Spotlight index
                    Task.detached(priority: .utility) {
                        SpotlightIndexer.reindex(container: SharedModelContainer.shared)
                    }
                }
        }
        .modelContainer(SharedModelContainer.shared)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                try? SharedModelContainer.shared.mainContext.save()
            }
        }
    }
}
