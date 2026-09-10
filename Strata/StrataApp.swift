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
                    // **Not wrapped in a Task.** `reindex` spawns its own
                    // detached task and does all its work inside it, so the
                    // wrapper here bought nothing and cost a Swift 6 error in
                    // waiting: it captured the main-actor `SharedModelContainer
                    // .shared` inside a `@Sendable` closure.
                    SpotlightIndexer.reindex(container: SharedModelContainer.shared)
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
