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

    /// How the store opened, held in state so "Try Again" can put the app on
    /// screen without a relaunch.
    ///
    /// Read into state rather than read on every render: `opening` is plain
    /// static state and SwiftUI would not know when it moved.
    ///
    /// Seeded in `init`, not here. A property's default value is evaluated
    /// before the initialiser's body, so it would have read `opening` before
    /// anything had asked the ladder to climb, and every launch would have
    /// reported the store fine.
    @State private var storeOpening: StoreOpening

    init() {
        #if DEBUG
        // **In `init`, not in the body.** Forgetting onboarding from inside
        // `body` is too late: `showsOnboarding` is read in the same evaluation
        // and has already decided, so the reset only took effect on the NEXT
        // render — which for a UI test is after it has given up looking.
        if DebugHarness.resetsOnboarding {
            UserDefaults.standard.set(false, forKey: "hasOnboarded")
        }
        #endif
        // **The container is asked for on its own line, and that is not
        // tidiness.** `AppDependencyManager.add(dependency:)` takes an
        // AUTOCLOSURE, so passing `SharedModelContainer.shared` to it directly
        // does not open the store: it stores a closure that opens it later,
        // whenever an App Intent first asks. Written that way, `opening` below
        // was still its default when it was read, every launch reported the
        // store fine, and a forced failure showed onboarding over a store that
        // could not save. Photographed on the simulator, which is the only
        // reason it was found: the log said `unavailable` and the screen said
        // otherwise.
        let container = SharedModelContainer.shared
        // **Only a store that saves is ever handed to the App Intents.** The
        // holding rung's container is in memory and exists for SwiftUI alone.
        // Registered, it became the store Siri logged wins into and read
        // today's wins out of, and the intents run without opening the app, so
        // nobody would ever have seen the blocking screen. Each intent also
        // checks for itself (`StoreUnavailableIntentError.check()`) before
        // touching its dependency, and `retryOpeningStore` registers the
        // container once a retry opens it.
        if SharedModelContainer.opening.savesToDisk {
            AppDependencyManager.shared.add(dependency: container)
        }
        _storeOpening = State(initialValue: SharedModelContainer.opening)
    }

    /// Walks the ladder again from the blocking screen's button, and says
    /// whether it opened.
    private func retryOpeningStore() -> Bool {
        let opening = SharedModelContainer.retry()
        storeOpening = opening
        guard opening.savesToDisk else { return false }
        // Nothing was registered while the store was unavailable, so this is
        // the first registration, and it is of the container that opened.
        let container = SharedModelContainer.shared
        AppDependencyManager.shared.add(dependency: container)
        return true
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

    /// The first block, dropped the moment somebody finishes onboarding.
    ///
    /// **Endowed progress.** A tower that starts at zero asks you to begin; a
    /// tower with one block on it asks you to continue, and those are not the
    /// same request. Nunes and Drèze showed it directly in 2006: a loyalty
    /// card with two of ten stamps already filled was completed at nearly
    /// twice the rate of one with none of eight, for identical remaining
    /// effort. Every habit tool that opens on an empty page is fighting that
    /// finding rather than using it.
    ///
    /// It is also TRUE, which matters more. Finding the app, downloading it
    /// and sitting through the walkthrough is a thing they actually did, and
    /// this app's whole claim is that the things you actually did count. A
    /// fabricated block would be the app lying on its first screen.
    ///
    /// It is a `.hard` — the biggest — because it is the only win of the day
    /// and a lone 1x1 on an empty grid reads as a rounding error rather than
    /// as a start.
    private func finishOnboarding() {
        hasOnboarded = true
        // Logged by `MainAppView`, not here: a win has to land on the ACTIVE
        // tower, and `towerManager` is the thing that knows which that is.
        // Setting a flag and letting the real path do the work is how it ends
        // up identical to a win you logged yourself.
        UserDefaults.standard.set(true, forKey: MainAppView.welcomeWinKey)
    }

    @ViewBuilder
    private var appRoot: some View {
        if !storeOpening.savesToDisk {
            // **Before onboarding, and instead of everything.** An app
            // that cannot write anything down must not take a win, and
            // must not draw an empty tower that looks like the truth.
            StoreUnavailableView(onRetry: retryOpeningStore)
        } else if showsOnboarding {
            OnboardingView { finishOnboarding() }
        } else {
            mainApp
        }
    }

    private var mainApp: some View {
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

    var body: some Scene {
        WindowGroup {
            // **Onboarding INSTEAD of the app, not over it.**
            //
            // It was a `fullScreenCover` on `MainAppView`, and a cover
            // inherits its presenter's forced appearance:
            // `MainAppView.launchTab` is `.camera`, the camera pins the window
            // to `.dark`, so onboarding rendered dark on a phone set to light
            // and the light design could not be seen at all. Measured twice —
            // mean luminance 64 with the simulator in light mode, and
            // `.preferredColorScheme(nil)` on the cover did not lift it,
            // because the presenter's preference wins for the whole window.
            //
            // Swapping the two removes the inheritance rather than fighting
            // it, and it is the more honest structure anyway: until somebody
            // has been through this, it IS the app.
            Group {
                #if DEBUG
                if DebugHarness.headParity {
                    HeadParityView()
                } else {
                    appRoot
                }
                #else
                appRoot
                #endif
            }
            // The launch screen's S, held over the first frame and faded.
            .overlay { LaunchHandoff() }
        }
        .modelContainer(SharedModelContainer.shared)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                try? SharedModelContainer.shared.mainContext.save()
            }
        }
    }
}
