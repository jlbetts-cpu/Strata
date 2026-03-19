import SwiftUI
import SwiftData

/// Legacy wrapper — all UI is in MainAppView.
struct ContentView: View {
    var body: some View {
        MainAppView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitLog.self, MoodLog.self], inMemory: true)
        .environment(EventKitService())
        .environment(HealthKitService())
}
