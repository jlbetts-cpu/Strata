import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Strata", category: "ModelContainer")

enum SharedModelContainer {
    private(set) static var isUsingInMemoryFallback = false

    static let shared: ModelContainer = {
        let schema = Schema([Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanFolder.self, PlanItem.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            logger.error("Failed to create ModelContainer: \(error.localizedDescription). Falling back to in-memory store.")
            isUsingInMemoryFallback = true
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Could not create in-memory ModelContainer: \(error)")
            }
        }
    }()
}
