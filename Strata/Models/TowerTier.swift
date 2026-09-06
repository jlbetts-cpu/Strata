import SwiftUI

/// #91: Tower progression tier system (Deci & Ryan 2000 — self-determination theory)
/// Visual and narrative progression without competitive pressure.

enum TowerTier: String, CaseIterable, Comparable {
    case seedling   // 0-9 blocks
    case sapling    // 10-49 blocks
    case tree       // 50-149 blocks
    case grove      // 150-499 blocks
    case forest     // 500+ blocks

    /// Block count threshold to enter this tier
    var minimumBlocks: Int {
        switch self {
        case .seedling: return 0
        case .sapling:  return 10
        case .tree:     return 50
        case .grove:    return 150
        case .forest:   return 500
        }
    }

    /// User-facing display name
    var displayName: String {
        switch self {
        case .seedling: return "Seedling"
        case .sapling:  return "Sapling"
        case .tree:     return "Tree"
        case .grove:    return "Grove"
        case .forest:   return "Forest"
        }
    }

    /// Emoji icon for the tier
    var icon: String {
        switch self {
        case .seedling: return "🌱"
        case .sapling:  return "🌿"
        case .tree:     return "🌳"
        case .grove:    return "🌲"
        case .forest:   return "🏔️"
        }
    }

    /// Determine tier from block count
    static func tier(for blockCount: Int) -> TowerTier {
        for tier in TowerTier.allCases.reversed() {
            if blockCount >= tier.minimumBlocks {
                return tier
            }
        }
        return .seedling
    }

    /// Blocks needed for next tier (nil if at max)
    func blocksToNextTier(currentBlocks: Int) -> Int? {
        guard let nextTier = Self.allCases.first(where: { $0.minimumBlocks > currentBlocks }) else {
            return nil
        }
        return nextTier.minimumBlocks - currentBlocks
    }

    static func < (lhs: TowerTier, rhs: TowerTier) -> Bool {
        lhs.minimumBlocks < rhs.minimumBlocks
    }
}
