import SwiftUI
import SwiftData
import AppIntents

@main
struct StrataApp: App {
    @State private var focusFilterService = FocusFilterService()
    /// Whether the first run has happened.
    ///
    /// **At the app's root, not inside a tab.** Onboarding presented from
    /// `MainAppView` would sit on the tab bar's window and inherit whatever
    /// appearance the launch tab forces — the camera pins `.dark` — so the
    /// first thing somebody saw could be the app's own chrome behind a sheet.
    /// Here it is the whole window and there is nothing behind it.
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register ModelContainer for App Intents access (WWDC 2024 pattern)
        AppDependencyManager.shared.add(dependency: SharedModelContainer.shared)
    }

    /// Whether to put onboarding on screen.
    ///
    /// Under the harness it is off unless asked for: it is a full-screen cover
    /// and would otherwise be the only thing in every screenshot this project
    /// takes and the reason every UI test failed to find its first element.
    private var showsOnboarding: Bool {
        #if DEBUG
        if DebugHarness.isActive { return DebugHarness.showsOnboarding }
        #endif
        return !hasOnboarded
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(focusFilterService)
                .fullScreenCover(isPresented: .constant(showsOnboarding)) {
                    OnboardingView { hasOnboarded = true }
                        // Onboarding is a light room whatever the phone is set
                        // to — it is the app introducing itself, and the
                        // blocks are the subject.
                        .interactiveDismissDisabled()
                }
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
