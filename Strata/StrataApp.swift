import SwiftUI
import SwiftData
import AppIntents

@main
struct StrataApp: App {
    @State private var focusFilterService = FocusFilterService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register ModelContainer for App Intents access (WWDC 2024 pattern)
        AppDependencyManager.shared.add(dependency: SharedModelContainer.shared)
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(focusFilterService)
                .onAppear {
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
