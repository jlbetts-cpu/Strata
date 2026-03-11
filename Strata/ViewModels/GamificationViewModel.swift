import Foundation

@Observable
final class GamificationViewModel {

    private(set) var totalXP: Int = 0
    private(set) var currentLevel: Int = 1
    private(set) var levelProgress: Double = 0
    private(set) var xpIntoLevel: Int = 0
    private(set) var xpForCurrentLevel: Int = 0
    private(set) var totalBlocksCompleted: Int = 0
    private(set) var reachedMilestones: [Int] = []
    private(set) var showLevelUp: Bool = false
    private(set) var newLevel: Int = 0

    var levelTitle: String {
        XPEngine.title(forLevel: currentLevel)
    }

    var nextMilestone: Int? {
        XPEngine.blockMilestones.first { $0 > totalBlocksCompleted }
    }

    var blocksToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next - totalBlocksCompleted
    }

    // MARK: - Recalculate from Logs

    func recalculate(from logs: [HabitLog]) {
        let completedLogs = logs.filter { $0.completed }
        totalBlocksCompleted = completedLogs.count

        // Calculate total XP from collected logs
        var xp = 0
        for log in completedLogs {
            guard let habit = log.habit else { continue }

            // Base XP from block size
            xp += habit.blockSize.baseXP

            // Collected pending XP
            if log.xpCollected, let pending = log.pendingXP {
                xp += pending
            }

            // Creation XP (first completion only - simplified)
            xp += habit.creationXP
        }

        let previousLevel = currentLevel
        totalXP = xp

        let levelInfo = XPEngine.level(forTotalXP: totalXP)
        currentLevel = levelInfo.level
        levelProgress = levelInfo.progress
        xpIntoLevel = levelInfo.xpIntoLevel
        xpForCurrentLevel = levelInfo.xpForLevel

        // Check for level up
        if currentLevel > previousLevel && previousLevel > 0 {
            newLevel = currentLevel
            showLevelUp = true
        }

        // Milestones
        reachedMilestones = XPEngine.blockMilestones.filter { $0 <= totalBlocksCompleted }
    }

    func dismissLevelUp() {
        showLevelUp = false
    }

    // MARK: - Momentum Bonus

    func rollMomentumBonus() -> Int? {
        // 15% chance
        guard Double.random(in: 0...1) < 0.15 else { return nil }
        return Int.random(in: 10...25)
    }
}
