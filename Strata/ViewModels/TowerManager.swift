import Foundation
import SwiftData
import SwiftUI

@Observable @MainActor
final class TowerManager {
    var activeTower: Tower?

    @ObservationIgnored
    private var activeTowerIDStorage: String {
        get { UserDefaults.standard.string(forKey: "activeTowerID") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "activeTowerID") }
    }

    /// On first launch, creates a default tower and assigns all orphaned habits to it.
    // Moves `updatedAt` on any orphaned habit it re-parents, and on that tower (StoreStamp).
    func ensureDefaultTower(context: ModelContext) {
        let descriptor = FetchDescriptor<Tower>(sortBy: [SortDescriptor(\.order)])
        let towers = (try? context.fetch(descriptor)) ?? []

        if towers.isEmpty {
            let defaultTower = Tower(name: "My Tower", emoji: "🏗️", order: 0)
            context.insert(defaultTower)

            // Assign all existing habits to the default tower
            let habitDescriptor = FetchDescriptor<Habit>()
            let allHabits = (try? context.fetch(habitDescriptor)) ?? []
            for habit in allHabits where habit.tower == nil {
                habit.tower = defaultTower
            }

            try? context.save()
        } else {
            // Assign any orphaned habits to the first tower
            let habitDescriptor = FetchDescriptor<Habit>()
            let allHabits = (try? context.fetch(habitDescriptor)) ?? []
            let firstTower = towers[0]
            for habit in allHabits where habit.tower == nil {
                habit.tower = firstTower
            }
            if allHabits.contains(where: { $0.tower == nil }) {
                try? context.save()
            }
        }
    }

    /// Load the active tower from persisted ID, or fall back to first tower.
    func loadActiveTower(context: ModelContext) {
        let descriptor = FetchDescriptor<Tower>(sortBy: [SortDescriptor(\.order)])
        let towers = (try? context.fetch(descriptor)) ?? []

        if let storedID = UUID(uuidString: activeTowerIDStorage),
           let match = towers.first(where: { $0.id == storedID }) {
            activeTower = match
        } else {
            activeTower = towers.first
            if let tower = activeTower {
                activeTowerIDStorage = tower.id.uuidString
            }
        }
    }

    func setActive(_ tower: Tower) {
        activeTower = tower
        activeTowerIDStorage = tower.id.uuidString
    }

    // `createTower`, `renameTower` and `allTowers` were here and had no
    // callers: they are the API of a tower picker that was never built. There
    // is one tower, and `ensureDefaultTower` is the only thing that makes it.
}
