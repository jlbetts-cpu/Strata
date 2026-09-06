import Foundation

/// #84: Achievement milestone data model (Locke & Latham 2002)
/// Tracks user achievements without shame — celebrates progress, not perfection.

enum MilestoneType: String, Codable, CaseIterable {
    case blockCount       // Total blocks placed
    case towerHeight      // Peak tower height in meters
    case perfectDay       // Days with all habits completed
    case categoryMastery  // Blocks in a single category
    case streakLength     // Consecutive days with any completion
}

enum MilestoneTier: String, Codable, Comparable {
    case bronze
    case silver
    case gold
    case platinum
    case legendary

    static func < (lhs: MilestoneTier, rhs: MilestoneTier) -> Bool {
        let order: [MilestoneTier] = [.bronze, .silver, .gold, .platinum, .legendary]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

struct Milestone: Codable, Identifiable, Equatable {
    var id: String { "\(type.rawValue)_\(threshold)" }
    let type: MilestoneType
    let threshold: Int
    let tier: MilestoneTier
    let title: String
    let description: String
    var unlockedAt: Date?

    var isUnlocked: Bool { unlockedAt != nil }

    /// Named height comparisons (Tversky 1977 — concrete anchoring)
    static let heightMilestones: [Milestone] = [
        Milestone(type: .towerHeight, threshold: 10, tier: .bronze, title: "Telephone Pole", description: "Your tower is as tall as a telephone pole"),
        Milestone(type: .towerHeight, threshold: 30, tier: .bronze, title: "10-Story Building", description: "Your tower matches a 10-story building"),
        Milestone(type: .towerHeight, threshold: 50, tier: .silver, title: "Leaning Tower", description: "You've built a Tower of Pisa"),
        Milestone(type: .towerHeight, threshold: 93, tier: .silver, title: "Statue of Liberty", description: "Your tower reaches Lady Liberty's torch"),
        Milestone(type: .towerHeight, threshold: 100, tier: .gold, title: "Sequoia Tree", description: "Tall as the world's largest tree"),
        Milestone(type: .towerHeight, threshold: 330, tier: .gold, title: "Eiffel Tower", description: "You've matched the Eiffel Tower"),
        Milestone(type: .towerHeight, threshold: 443, tier: .platinum, title: "Empire State", description: "Your tower rivals the Empire State Building"),
        Milestone(type: .towerHeight, threshold: 828, tier: .legendary, title: "Burj Khalifa", description: "The tallest structure on Earth"),
        Milestone(type: .towerHeight, threshold: 1000, tier: .legendary, title: "Stratosphere", description: "You're reaching for the sky"),
    ]

    /// Block count milestones
    static let blockCountMilestones: [Milestone] = [
        Milestone(type: .blockCount, threshold: 1, tier: .bronze, title: "First Block", description: "Every tower starts with one"),
        Milestone(type: .blockCount, threshold: 10, tier: .bronze, title: "Foundation", description: "10 blocks — you're building something real"),
        Milestone(type: .blockCount, threshold: 25, tier: .bronze, title: "Quarter Century", description: "25 blocks of practice"),
        Milestone(type: .blockCount, threshold: 50, tier: .silver, title: "Half Century", description: "50 blocks — that's dedication"),
        Milestone(type: .blockCount, threshold: 100, tier: .silver, title: "Centurion", description: "100 blocks. You're a builder."),
        Milestone(type: .blockCount, threshold: 250, tier: .gold, title: "Master Builder", description: "250 blocks of consistent effort"),
        Milestone(type: .blockCount, threshold: 500, tier: .platinum, title: "Architect", description: "500 blocks — your tower tells a story"),
        Milestone(type: .blockCount, threshold: 1000, tier: .legendary, title: "Monument", description: "1000 blocks. This is mastery."),
    ]

    /// Perfect day milestones (cumulative, not consecutive — no shame)
    static let perfectDayMilestones: [Milestone] = [
        Milestone(type: .perfectDay, threshold: 1, tier: .bronze, title: "Perfect Day", description: "Your first day with everything done"),
        Milestone(type: .perfectDay, threshold: 5, tier: .bronze, title: "Five Stars", description: "5 perfect days earned"),
        Milestone(type: .perfectDay, threshold: 10, tier: .silver, title: "Perfect Ten", description: "10 days of total completion"),
        Milestone(type: .perfectDay, threshold: 25, tier: .silver, title: "Perfectionist", description: "25 perfect days"),
        Milestone(type: .perfectDay, threshold: 50, tier: .gold, title: "Flawless", description: "50 perfect days — remarkable"),
        Milestone(type: .perfectDay, threshold: 100, tier: .platinum, title: "Century Perfect", description: "100 perfect days"),
    ]

    /// Streak milestones
    static let streakMilestones: [Milestone] = [
        Milestone(type: .streakLength, threshold: 7, tier: .bronze, title: "Week Strong", description: "7 consecutive days"),
        Milestone(type: .streakLength, threshold: 14, tier: .bronze, title: "Fortnight", description: "Two solid weeks"),
        Milestone(type: .streakLength, threshold: 30, tier: .silver, title: "Monthly", description: "A full month of consistency"),
        Milestone(type: .streakLength, threshold: 66, tier: .gold, title: "Habit Formed", description: "66 days — the habit is yours (Lally 2010)"),
        Milestone(type: .streakLength, threshold: 100, tier: .platinum, title: "Triple Digits", description: "100 days without breaking"),
        Milestone(type: .streakLength, threshold: 365, tier: .legendary, title: "Year One", description: "365 days. Extraordinary."),
    ]

    /// All milestones combined
    static let allMilestones: [Milestone] = heightMilestones + blockCountMilestones + perfectDayMilestones + streakMilestones
}

/// Persistent storage for unlocked milestones
struct MilestoneStore: Codable {
    var unlockedMilestones: [String: Date] = [:] // milestone.id → unlock date

    func isUnlocked(_ milestone: Milestone) -> Bool {
        unlockedMilestones[milestone.id] != nil
    }

    mutating func unlock(_ milestone: Milestone) {
        guard unlockedMilestones[milestone.id] == nil else { return }
        unlockedMilestones[milestone.id] = Date()
    }

    // MARK: - Persistence

    private static let storageKey = "milestoneStore"

    static func load() -> MilestoneStore {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let store = try? JSONDecoder().decode(MilestoneStore.self, from: data) else {
            return MilestoneStore()
        }
        return store
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
