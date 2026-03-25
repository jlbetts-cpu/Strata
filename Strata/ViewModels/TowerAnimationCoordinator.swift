import SwiftUI

/// Per-block animation state — each instance is its own @Observable,
/// so mutations only invalidate views that read THIS specific instance.
@Observable
final class BlockAnimationState {
    var dropPhase: TowerAnimationCoordinator.DropPhase? = nil
    var isRippling: Bool = false
    var rippleIntensity: CGFloat = 1.0
    // Jubilation wave (perfect day celebration)
    var jubilationWobble: Double = 0
    var jubilationLift: CGFloat = 0
    var jubilationGlow: Double = 0
}

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

    private(set) var blockStates: [UUID: BlockAnimationState] = [:]
    private(set) var activelyAnimatingIDs: Set<UUID> = []
    var isCascading = false
    var isJubilating = false
    var landedMassTier: Int = 1

    private var pendingDropAnimations: [Set<UUID>] = []
    private var dropDrainTask: Task<Void, Never>?

    /// Whether reduce motion is enabled — set by the view on appear / change.
    var reduceMotion = false

    func state(for id: UUID) -> BlockAnimationState {
        if let existing = blockStates[id] { return existing }
        let new = BlockAnimationState()
        blockStates[id] = new
        return new
    }

    // MARK: - Public API

    func enqueueDrop(blockIDs: Set<UUID>) {
        guard !blockIDs.isEmpty else { return }
        // Immediately set falling phase so blocks render offscreen
        // on the same frame they enter placedBlocks — prevents flash
        if !reduceMotion {
            for id in blockIDs {
                state(for: id).dropPhase = .falling
                activelyAnimatingIDs.insert(id)
            }
        }
        pendingDropAnimations.append(blockIDs)
        startDrainIfNeeded()
    }

    func purgeStaleState(validIDs: Set<UUID>) {
        blockStates = blockStates.filter { validIDs.contains($0.key) }
        activelyAnimatingIDs.formIntersection(validIDs)
    }

    func reset() {
        dropDrainTask?.cancel()
        dropDrainTask = nil
        pendingDropAnimations = []
        blockStates.removeAll()
        activelyAnimatingIDs.removeAll()
        isCascading = false
        landedMassTier = 1
    }

    func triggerRipple(from landedID: UUID, massTier: Int, placedBlocks: [PlacedBlock]) {
        guard !reduceMotion else { return }
        guard let landedBlock = placedBlocks.first(where: { $0.id == landedID }) else { return }
        let landedRow = landedBlock.row
        let massMultiplier = CGFloat(massTier)

        let blocksBelow = placedBlocks.filter { block in
            block.id != landedID && block.row < landedRow && (landedRow - block.row) <= 6
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
                    self.state(for: id).rippleIntensity = intensity
                }
                withAnimation(GridConstants.rippleCompressSpring) {
                    for id in tierIDs {
                        self.state(for: id).isRippling = true
                    }
                }

                try? await Task.sleep(nanoseconds: 80_000_000)
                withAnimation(GridConstants.rippleReleaseSpring) {
                    for id in tierIDs {
                        self.state(for: id).isRippling = false
                        self.state(for: id).rippleIntensity = 1.0
                    }
                }
            }
        }
    }

    // MARK: - Jubilation Wave (Perfect Day Celebration)

    func triggerJubilation(placedBlocks: [PlacedBlock]) {
        guard !isJubilating, !reduceMotion else { return }
        isJubilating = true

        let maxRow = placedBlocks.map { $0.row + $0.rowSpan - 1 }.max() ?? 0
        let rowDelay: Double = 0.07

        Task { @MainActor in
            // === OUTGOING WAVE (bottom → top) — 4 oscillations, ±3.5° ===
            for row in 0...maxRow {
                let rowBlocks = placedBlocks.filter { $0.row <= row && $0.row + $0.rowSpan > row }

                // Sway RIGHT — big, slow, visible
                withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
                    for block in rowBlocks {
                        let s = state(for: block.id)
                        s.jubilationWobble = 3.5
                        s.jubilationLift = -6
                        s.jubilationGlow = 0.08
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(rowDelay * 1_000_000_000))

                // Sway LEFT
                withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
                    for block in rowBlocks {
                        state(for: block.id).jubilationWobble = -3.5
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(rowDelay * 1_000_000_000))

                // Sway RIGHT (decay)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.45)) {
                    for block in rowBlocks {
                        let s = state(for: block.id)
                        s.jubilationWobble = 2.0
                        s.jubilationLift = -3
                        s.jubilationGlow = 0.04
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(rowDelay * 0.8 * 1_000_000_000))

                // Sway LEFT (final oscillation)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.50)) {
                    for block in rowBlocks {
                        state(for: block.id).jubilationWobble = -1.0
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(rowDelay * 0.5 * 1_000_000_000))

                // Settle
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    for block in rowBlocks {
                        let s = state(for: block.id)
                        s.jubilationWobble = 0
                        s.jubilationLift = 0
                        s.jubilationGlow = 0
                    }
                }

                // Ascending glissando
                let pitch = Double(row) * (150.0 / Double(max(maxRow, 1)))
                SoundEngine.completionTone(category: .health, pitchShift: pitch)

                if row == maxRow / 2 { HapticsEngine.lightTap() }
                if row == maxRow { HapticsEngine.success() }
            }

            // === RETURN WAVE (top → bottom, half amplitude) ===
            try? await Task.sleep(for: .milliseconds(200))

            for row in stride(from: maxRow, through: 0, by: -1) {
                let rowBlocks = placedBlocks.filter { $0.row <= row && $0.row + $0.rowSpan > row }

                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                    for block in rowBlocks {
                        let s = state(for: block.id)
                        s.jubilationWobble = -1.0
                        s.jubilationLift = -2
                        s.jubilationGlow = 0.03
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(rowDelay * 0.6 * 1_000_000_000))

                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    for block in rowBlocks {
                        let s = state(for: block.id)
                        s.jubilationWobble = 0
                        s.jubilationLift = 0
                        s.jubilationGlow = 0
                    }
                }

                let pitch = 200.0 - Double(row) * (150.0 / Double(max(maxRow, 1)))
                SoundEngine.completionTone(category: .health, pitchShift: pitch)
            }

            try? await Task.sleep(for: .milliseconds(400))
            isJubilating = false
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
                    try? await Task.sleep(nanoseconds: 60_000_000)
                }
            }
            dropDrainTask = nil
            isCascading = false
            onAllDropsComplete?() // Tower settle moment (Gestalt closure)
        }
    }

    private func triggerDropAnimation(for blockIDs: Set<UUID>) async {
        guard !blockIDs.isEmpty else { return }

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                for id in blockIDs {
                    state(for: id).dropPhase = nil
                }
                activelyAnimatingIDs.subtract(blockIDs)
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
        for id in blockIDs { state(for: id).dropPhase = .falling }

        try? await Task.sleep(nanoseconds: 8_000_000)
        let curve: Animation = switch mass {
        case 1: .timingCurve(0.36, 0, 1, 1, duration: fallDuration)
        case 2: .timingCurve(0.42, 0, 1, 1, duration: fallDuration)
        default: .timingCurve(0.50, 0, 1, 1, duration: fallDuration)
        }
        withAnimation(curve) {
            for id in blockIDs { state(for: id).dropPhase = .squash }
        }

        try? await Task.sleep(nanoseconds: UInt64(fallDuration * 1_000_000_000))

        // Impact haptic callback
        HapticsEngine.squish(mass: mass)
        if let landedID = blockIDs.first {
            onImpact?(landedID, mass)
        }

        // Phase 2: Squash → Stretch — mass-dependent dwell (heavier = lingers in compression)
        let squashDwell: UInt64 = switch mass {
        case 1: 40_000_000; case 2: 70_000_000; default: 100_000_000
        }
        try? await Task.sleep(nanoseconds: squashDwell)
        withAnimation(GridConstants.dropStretchSpring) {
            for id in blockIDs { state(for: id).dropPhase = .stretch }
        }

        // Phase 3: Stretch → Wobble
        let stretchDwell: UInt64 = switch mass {
        case 1: 60_000_000; case 2: 80_000_000; default: 120_000_000
        }
        try? await Task.sleep(nanoseconds: stretchDwell)
        withAnimation(GridConstants.wobbleSpring) {
            for id in blockIDs { state(for: id).dropPhase = .wobble }
        }

        // Phase 4: Wobble → Remove (settle to rest)
        let wobbleDwell: UInt64 = switch mass {
        case 1: 100_000_000; case 2: 160_000_000; default: 220_000_000
        }
        try? await Task.sleep(nanoseconds: wobbleDwell)
        withAnimation(GridConstants.dropSettleSpring) {
            for id in blockIDs {
                state(for: id).dropPhase = nil
            }
            activelyAnimatingIDs.subtract(blockIDs)
        }

        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    /// Callback to look up a block's mass tier by ID. Set by the view.
    var lookupMass: ((UUID) -> Int?)?

    /// Callback when a block impacts. Used for ripple trigger. Set by the view.
    var onImpact: ((UUID, Int) -> Void)?

    /// Callback when all pending drops complete. Used for tower settle. Set by the view.
    var onAllDropsComplete: (() -> Void)?
}
