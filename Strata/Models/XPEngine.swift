import Foundation

enum XPEngine {
    static let levelCount = 100

    static func xpRequired(forLevel level: Int) -> Int {
        switch level {
        case 1...10:
            return 50 + (level * 50)
        case 11...30:
            return 300 + ((level - 10) * 100)
        case 31...50:
            return 1500 + ((level - 30) * 200)
        case 51...70:
            return 5500 + ((level - 50) * 400)
        case 71...90:
            return 13500 + ((level - 70) * 800)
        case 91...100:
            return 29500 + ((level - 90) * 1500)
        default:
            return 50
        }
    }

    static func level(forTotalXP totalXP: Int) -> (level: Int, progress: Double, xpIntoLevel: Int, xpForLevel: Int) {
        var cumulativeXP = 0
        for lvl in 1...levelCount {
            let required = xpRequired(forLevel: lvl)
            if cumulativeXP + required > totalXP {
                let xpInto = totalXP - cumulativeXP
                let progress = Double(xpInto) / Double(required)
                return (lvl, progress, xpInto, required)
            }
            cumulativeXP += required
        }
        return (levelCount, 1.0, 0, 0)
    }

    static let levelTitles: [String] = [
        "Seedling", "Sprout", "Sapling", "Bloom", "Root",
        "Stone", "Ember", "Spark", "Flame", "Blaze",
        "Wave", "Stream", "River", "Current", "Tide",
        "Breeze", "Gust", "Wind", "Storm", "Tempest",
        "Peak", "Summit", "Ridge", "Crest", "Pinnacle",
        "Iron", "Steel", "Bronze", "Silver", "Gold",
        "Ruby", "Sapphire", "Emerald", "Diamond", "Obsidian",
        "Hawk", "Eagle", "Falcon", "Phoenix", "Dragon",
        "Sentinel", "Guardian", "Warden", "Champion", "Titan",
        "Oracle", "Sage", "Mystic", "Seer", "Prophet",
        "Knight", "Paladin", "Crusader", "Warlord", "Conqueror",
        "Astral", "Cosmic", "Stellar", "Nebula", "Quasar",
        "Ancient", "Primeval", "Timeless", "Ageless", "Undying",
        "Mythic", "Fabled", "Storied", "Legendary", "Epic",
        "Heroic", "Valiant", "Noble", "Sovereign", "Imperial",
        "Radiant", "Luminous", "Brilliant", "Resplendent", "Glorious",
        "Transcendent", "Boundless", "Limitless", "Unfathomable", "Incomprehensible",
        "Immortal", "Eternal", "Infinite", "Absolute", "Ultimate",
        "Omega", "Alpha", "Apex", "Zenith", "Ascended"
    ]

    static func title(forLevel level: Int) -> String {
        guard level >= 1, level <= levelTitles.count else { return "Seedling" }
        return levelTitles[level - 1]
    }

    // Achievement milestone thresholds
    static let blockMilestones = [10, 25, 50, 100, 250, 500, 1000]

    enum AchievementType: String {
        case star
        case trophy
        case crown
        case gem
    }

    static func achievementType(forMilestone blocks: Int) -> AchievementType {
        switch blocks {
        case 10, 25: return .star
        case 50, 100: return .trophy
        case 250: return .crown
        case 500, 1000: return .gem
        default: return .star
        }
    }
}
