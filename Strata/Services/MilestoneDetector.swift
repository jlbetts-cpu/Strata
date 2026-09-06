import Foundation

/// #85: Milestone detection service — checks state on every refreshData()
/// Detects when users cross achievement thresholds and returns newly unlocked milestones.

struct MilestoneDetector {

    /// Check all milestones against current state, return any newly unlocked
    static func detectNewMilestones(
        totalBlocks: Int,
        towerHeightMeters: Double,
        perfectDayCount: Int,
        longestStreak: Int,
        store: inout MilestoneStore
    ) -> [Milestone] {
        var newlyUnlocked: [Milestone] = []

        for var milestone in Milestone.allMilestones {
            guard !store.isUnlocked(milestone) else { continue }

            let value: Int = switch milestone.type {
            case .blockCount: totalBlocks
            case .towerHeight: Int(towerHeightMeters)
            case .perfectDay: perfectDayCount
            case .streakLength: longestStreak
            case .categoryMastery: 0 // Checked separately per category
            }

            if value >= milestone.threshold {
                milestone.unlockedAt = Date()
                store.unlock(milestone)
                newlyUnlocked.append(milestone)
            }
        }

        return newlyUnlocked
    }

    /// Check category-specific mastery milestones
    static func detectCategoryMilestones(
        categoryCounts: [String: Int],
        store: inout MilestoneStore
    ) -> [Milestone] {
        var newlyUnlocked: [Milestone] = []

        let thresholds: [(Int, MilestoneTier, String)] = [
            (25, .bronze, "Bronze"),
            (50, .silver, "Silver"),
            (100, .gold, "Gold"),
            (250, .platinum, "Platinum"),
        ]

        for (category, count) in categoryCounts {
            for (threshold, tier, tierName) in thresholds {
                let milestone = Milestone(
                    type: .categoryMastery,
                    threshold: threshold,
                    tier: tier,
                    title: "\(category.capitalized) \(tierName)",
                    description: "\(threshold) \(category) blocks completed"
                )
                if count >= threshold && !store.isUnlocked(milestone) {
                    var unlocked = milestone
                    unlocked.unlockedAt = Date()
                    store.unlock(unlocked)
                    newlyUnlocked.append(unlocked)
                }
            }
        }

        return newlyUnlocked
    }
}
