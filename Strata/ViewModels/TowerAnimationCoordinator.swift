import SwiftUI

/// Manages all tower drop, ripple, and compression animation state.
@Observable
@MainActor
final class TowerAnimationCoordinator {
    enum DropPhase: Equatable {
        case falling
        case squash
        case stretch
        case wobble
    }

    var dropPhases: [UUID: DropPhase] = [:]
    var ripplingBlockIDs: Set<UUID> = []
    var rippleIntensity: [UUID: CGFloat] = [:]
    var isCascading = false
    var landedMassTier: Int = 1

    private var pendingDropAnimations: [Set<UUID>] = []
    private var dropDrainTask: Task<Void, Never>?

    /// Whether reduce motion is enabled — set by the view on appear / change.
    var reduceMotion = false

    // MARK: - Public API

    func enqueueDrop(blockIDs: Set<UUID>) {
        guard !blockIDs.isEmpty else { return }
        pendingDropAnimations.append(blockIDs)
        startDrainIfNeeded()
    }

    func purgeStaleState(validIDs: Set<UUID>) {
        dropPhases = dropPhases.filter { validIDs.contains($0.key) }
        rippleIntensity = rippleIntensity.filter { validIDs.contains($0.key) }
        ripplingBlockIDs = ripplingBlockIDs.intersection(validIDs)
    }

    func triggerRipple(from landedID: UUID, massTier: Int, placedBlocks: [PlacedBlock]) {
        guard !reduceMotion else { return }
        guard let landedBlock = placedBlocks.first(where: { $0.id == landedID }) else { return }
        let landedRow = landedBlock.row
        let massMultiplier = CGFloat(massTier)

        let blocksBelow = placedBlocks.filter { block in
            block.id != landedID && block.row < landedRow && (landedRow - block.row) <= 3
        }
        guard !blocksBelow.isEmpty else { return }

        var tiers: [Int: [PlacedBlock]] = [:]
        for block in blocksBelow {
            let distance = landedRow - block.row
            tiers[distance, default: []].append(block)
        }

        Task { @MainActor in
            for (distance, tierBlocks) in tiers {
                let delay = Double(distance) * 0.05
                let intensity = massMultiplier / (1.0 + pow(CGFloat(distance), 1.5))
                let tierIDs = tierBlocks.map(\.id)

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                for id in tierIDs {
                    self.rippleIntensity[id] = intensity
                }
                withAnimation(GridConstants.rippleCompressSpring) {
                    self.ripplingBlockIDs.formUnion(tierIDs)
                }

                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(GridConstants.rippleReleaseSpring) {
                    for id in tierIDs {
                        self.ripplingBlockIDs.remove(id)
                        self.rippleIntensity.removeValue(forKey: id)
                    }
                }
            }
        }
    }

    // MARK: - Internal

    private func startDrainIfNeeded() {
        guard dropDrainTask == nil else { return }
        dropDrainTask = Task {
            while !pendingDropAnimations.isEmpty {
                let ids = pendingDropAnimations.removeFirst()
                await triggerDropAnimation(for: ids)
                if !pendingDropAnimations.isEmpty {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            dropDrainTask = nil
            isCascading = false
        }
    }

    private func triggerDropAnimation(for blockIDs: Set<UUID>) async {
        guard !blockIDs.isEmpty else { return }

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                for id in blockIDs { dropPhases.removeValue(forKey: id) }
            }
            return
        }

        let mass: Int
        if let landedID = blockIDs.first,
           let massTier = lookupMass?(landedID) {
            mass = massTier
        } else { mass = 1 }
        landedMassTier = mass

        // Gravity-correct durations & curves (accelerate through impact)
        let fallDuration: Double = switch mass {
        case 1: 0.28; case 2: 0.38; default: 0.50
        }

        // Phase 1: Falling
        for id in blockIDs { dropPhases[id] = .falling }

        try? await Task.sleep(nanoseconds: 20_000_000)
        let curve: Animation = switch mass {
        case 1: .timingCurve(0.36, 0, 1, 1, duration: fallDuration)
        case 2: .timingCurve(0.42, 0, 1, 1, duration: fallDuration)
        default: .timingCurve(0.50, 0, 1, 1, duration: fallDuration)
        }
        withAnimation(curve) {
            for id in blockIDs { dropPhases[id] = .squash }
        }

        try? await Task.sleep(nanoseconds: UInt64(fallDuration * 1_000_000_000))

        // Impact haptic callback
        HapticsEngine.squish(mass: mass)
        if let landedID = blockIDs.first {
            onImpact?(landedID, mass)
        }

        // Phase 2: Squash → Stretch — mass-dependent dwell (heavier = lingers in compression)
        let squashDwell: UInt64 = switch mass {
        case 1: 40_000_000; case 2: 70_000_000; default: 110_000_000
        }
        try? await Task.sleep(nanoseconds: squashDwell)
        withAnimation(GridConstants.dropStretchSpring) {
            for id in blockIDs { dropPhases[id] = .stretch }
        }

        // Phase 3: Stretch → Wobble
        let stretchDwell: UInt64 = switch mass {
        case 1: 80_000_000; case 2: 120_000_000; default: 160_000_000
        }
        try? await Task.sleep(nanoseconds: stretchDwell)
        withAnimation(GridConstants.wobbleSpring) {
            for id in blockIDs { dropPhases[id] = .wobble }
        }

        // Phase 4: Wobble → Remove (settle to rest)
        let wobbleDwell: UInt64 = switch mass {
        case 1: 150_000_000; case 2: 220_000_000; default: 300_000_000
        }
        try? await Task.sleep(nanoseconds: wobbleDwell)
        withAnimation(GridConstants.dropSettleSpring) {
            for id in blockIDs { dropPhases.removeValue(forKey: id) }
        }

        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    /// Callback to look up a block's mass tier by ID. Set by the view.
    var lookupMass: ((UUID) -> Int?)?

    /// Callback when a block impacts. Used for ripple trigger. Set by the view.
    var onImpact: ((UUID, Int) -> Void)?
}
