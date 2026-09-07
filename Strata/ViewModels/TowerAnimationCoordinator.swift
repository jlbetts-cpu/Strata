import SwiftUI

/// Per-block animation state — each instance is its own @Observable,
/// so mutations only invalidate views that read THIS specific instance.
@Observable
final class BlockAnimationState {
    var dropPhase: TowerAnimationCoordinator.DropPhase? = nil
    var isRippling: Bool = false
    var rippleIntensity: CGFloat = 1.0
    // #28: Heavy micro-bounce Y offset after stretch
    var microBounceY: CGFloat = 0
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

    /// Creates the animation state for every placed block, once, up front.
    ///
    /// `state(for:)` creates on demand and stores what it created. That is
    /// fine from the coordinator and wrong from a view body: the body ran
    /// first, created an instance and stored it, and the coordinator then
    /// created a SECOND instance for the same block a moment later. The view
    /// held one object, the drop sequence mutated the other, and no
    /// invalidation ever reached the view — so the block never rendered a
    /// falling phase and simply appeared in place. Measured over four drops,
    /// three had mismatched instances and did not animate; the one that did
    /// was the one whose body happened to re-run and pick up the new object.
    ///
    /// Seeding here, from the same place that builds the tower, means a body
    /// always finds an existing instance and never creates a rival.
    func ensureStates(for ids: some Sequence<UUID>) {
        for id in ids where blockStates[id] == nil {
            blockStates[id] = BlockAnimationState()
        }
    }

    /// Suspends until the display has presented `count` frames.
    ///
    /// The drop sequence needs the block to have actually been DRAWN at the top
    /// of the runway before the fall starts. Sleeping for a duration cannot
    /// promise that — a frame is 16.7ms at 60Hz and longer whenever the device
    /// is busy, which is exactly when a drop is most likely to be dropped. The
    /// display link fires when a frame really happens, so it promises it.
    static func awaitFrames(_ count: Int) async {
        for _ in 0..<count {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                FrameWaiter.wait(cont)
            }
        }
    }

    // MARK: - Public API

    func enqueueDrop(blockIDs: Set<UUID>) {
        guard !blockIDs.isEmpty else { return }

        // Immediately set falling phase so blocks render offscreen
        // on the same frame they enter placedBlocks — prevents flash
        if !reduceMotion {
            // Never animated. Reaching the top of the runway is where the drop
            // STARTS, not a move the viewer should see; if an ambient animation
            // is in flight this is what stops the block sliding up into it.
            withTransaction(Transaction(animation: nil)) {
                for id in blockIDs {
                    state(for: id).dropPhase = .falling
                    activelyAnimatingIDs.insert(id)
                }
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

    /// #430: Clear animation states on filter change to prevent stale ripple/wobble
    func clearAnimationStates() {
        for (_, state) in blockStates {
            state.isRippling = false
            state.rippleIntensity = 1.0
            state.jubilationWobble = 0
            state.jubilationLift = 0
            state.jubilationGlow = 0
        }
    }

    func triggerRipple(from landedID: UUID, massTier: Int, placedBlocks: [PlacedBlock]) {
        guard !reduceMotion else { return }
        // Only a block with real mass disturbs the stack.
        //
        // Every landing used to ripple the whole tower, including the smallest
        // one — so the most common action in the app shook everything under it
        // and the effect stopped meaning anything. A Quick block is one cell
        // and settles on its own; Regular and Deep have the mass to be felt.
        guard massTier >= 2 else { return }
        guard let landedBlock = placedBlocks.first(where: { $0.id == landedID }) else { return }
        let landedRow = landedBlock.row
        let landedCol = landedBlock.column
        let massMultiplier = CGFloat(massTier)

        // #31: Lateral ripple — include same-row blocks that compress at reduced intensity
        let affectedBlocks = placedBlocks.filter { block in
            guard block.id != landedID else { return false }
            let rowDist = landedRow - block.row
            let isSameRow = block.row == landedRow
            let isBelow = rowDist > 0 && rowDist <= 6
            return isSameRow || isBelow
        }
        guard !affectedBlocks.isEmpty else { return }

        var tiers: [Int: [PlacedBlock]] = [:]
        for block in affectedBlocks {
            if block.row == landedRow {
                // #31: Same-row blocks go in tier 0 with lateral distance
                tiers[0, default: []].append(block)
            } else {
                let distance = landedRow - block.row
                tiers[distance, default: []].append(block)
            }
        }

        Task { @MainActor in
            for (distance, tierBlocks) in tiers.sorted(by: { $0.key < $1.key }) {
                let delay = Double(max(distance, 1)) * 0.05
                let tierIDs = tierBlocks.map(\.id)

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                for id in tierIDs {
                    let block = tierBlocks.first { $0.id == id }
                    let intensity: CGFloat
                    if distance == 0 {
                        // #31: Lateral ripple — 0.3x intensity based on column distance
                        let colDist = abs((block?.column ?? landedCol) - landedCol)
                        intensity = massMultiplier * 0.3 / (1.0 + CGFloat(colDist))
                    } else {
                        intensity = massMultiplier / (1.0 + pow(CGFloat(distance), 1.5))
                    }
                    // #33: Ripple merging — use max(existing, new) not additive
                    let existing = self.state(for: id).rippleIntensity
                    self.state(for: id).rippleIntensity = max(existing, intensity)
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

    // #404: Celebration cancellation safety — track tasks for cleanup
    private var jubilationTask: Task<Void, Never>?

    func triggerJubilation(placedBlocks: [PlacedBlock]) {
        guard !isJubilating, !reduceMotion else { return }
        isJubilating = true

        let maxRow = placedBlocks.map { $0.row + $0.rowSpan - 1 }.max() ?? 0
        let rowDelay = min(0.07, 2.5 / Double(max(maxRow, 10))) // Adaptive: caps wave at ~2.5s

        jubilationTask?.cancel()
        jubilationTask = Task { @MainActor in
            // === OUTGOING WAVE (bottom → top) — 4 oscillations, ±3.5° ===
            for row in 0...maxRow {
                // #404: Check for cancellation on each iteration
                guard !Task.isCancelled else { resetJubilationState(placedBlocks: placedBlocks); return }
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
                // #48: Return wave amplitude decays proportional to row (top = full, bottom = minimal)
                let rowFraction = maxRow > 0 ? Double(row) / Double(maxRow) : 1.0
                let amplitude = 0.3 + 0.7 * rowFraction // 30% at bottom, 100% at top

                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                    for block in rowBlocks {
                        let s = state(for: block.id)
                        s.jubilationWobble = -1.0 * amplitude
                        s.jubilationLift = -2 * amplitude
                        s.jubilationGlow = 0.03 * amplitude
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

    /// #404: Reset all jubilation state safely on cancellation
    private func resetJubilationState(placedBlocks: [PlacedBlock]) {
        for block in placedBlocks {
            let s = state(for: block.id)
            s.jubilationWobble = 0
            s.jubilationLift = 0
            s.jubilationGlow = 0
        }
        isJubilating = false
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

        // Gravity-correct durations & curves (accelerate through impact).
        //
        // Was 0.28 / 0.38 / 0.50. Measured by burst-capturing the simulator
        // during eight drops: exactly ONE frame in seventy caught a block in
        // flight. The fall was real and essentially unseeable, which is why it
        // read as the block simply appearing. Long enough to register, still
        // short enough that logging six things in a row does not become a
        // queue you wait through.
        let fallDuration: Double = switch mass {
        case 1: 0.44; case 2: 0.54; default: 0.66
        }

        // Phase 1: Falling — instant, for the same reason as in `enqueueDrop`.
        withTransaction(Transaction(animation: nil)) {
            for id in blockIDs { state(for: id).dropPhase = .falling }
        }

        // Wait for the display, not for the clock.
        //
        // This was `Task.sleep(8ms)`. A frame at 60Hz is 16.7ms, so the block
        // was told to start at the top of the runway and the fall began before
        // a frame had necessarily been drawn showing it there. Whether the
        // viewer saw a fall at all came down to whether a refresh happened to
        // land inside that 8ms window — measured over ten drops, two fell and
        // eight went straight to the landing and simply appeared. That is the
        // inconsistency, and no amount of tuning the offset could fix it,
        // because the block was never rendered at the offset.
        //
        // Two display-link ticks: the first can fire before the transaction is
        // committed, the second cannot.
        await Self.awaitFrames(2)
        // #26: Air resistance — 0.95x velocity in last 20% (second control point < 1.0)
        let curve: Animation = switch mass {
        case 1: .timingCurve(0.36, 0, 0.85, 1, duration: fallDuration)
        case 2: .timingCurve(0.42, 0, 0.82, 1, duration: fallDuration)
        default: .timingCurve(0.50, 0, 0.80, 1, duration: fallDuration)
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

        // Phase 3: Stretch → Wobble (with micro-bounce for heavy blocks)
        let stretchDwell: UInt64 = switch mass {
        case 1: 60_000_000; case 2: 80_000_000; default: 120_000_000
        }
        try? await Task.sleep(nanoseconds: stretchDwell)

        // #28: Heavy micro-bounce — 2pt Y offset after stretch for mass 3+
        if mass >= 3 {
            withAnimation(.spring(response: 0.10, dampingFraction: 0.50)) {
                for id in blockIDs { state(for: id).microBounceY = 2 }
            }
            try? await Task.sleep(nanoseconds: 60_000_000)
            withAnimation(.spring(response: 0.15, dampingFraction: 0.70)) {
                for id in blockIDs { state(for: id).microBounceY = 0 }
            }
        }

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

/// Resumes a continuation on the next display refresh.
///
/// `CADisplayLink` retains its target, so the waiter keeps itself alive until
/// it invalidates — there is nothing for the caller to hold on to.
private final class FrameWaiter: NSObject {
    private var link: CADisplayLink?
    private var cont: CheckedContinuation<Void, Never>?

    static func wait(_ cont: CheckedContinuation<Void, Never>) {
        let waiter = FrameWaiter()
        waiter.cont = cont
        let link = CADisplayLink(target: waiter, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        waiter.link = link
    }

    @objc private func tick() {
        link?.invalidate()
        link = nil
        cont?.resume()
        cont = nil
    }
}
