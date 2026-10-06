import Observation
import SwiftUI

/// One crew tower's state: its own `TowerViewModel` and its own
/// `TowerAnimationCoordinator`.
///
/// **Never the Wins tab's.** `buildTower` writes caches onto the instance it
/// runs on and schedules their cleanup, so running it on the live tower for
/// anything else leaves the Wins tab showing the wrong thing
/// (`DayAlbumDetailView` learned this first). A crew screen builds its own.
@MainActor
@Observable
final class CrewTowerModel {
    let tower = TowerViewModel()
    let animation = TowerAnimationCoordinator()
    private(set) var latticeRipple: LatticeRipple?

    /// Where the grid is on screen: for starting a fall above the top edge,
    /// and for the heads to stand on. The Wins tab's own kind of probe, never
    /// observed, so measuring it invalidates nothing.
    @ObservationIgnored let probe = TowerGeometryProbe()
    @ObservationIgnored private var lastDanceMilestone: Int?
    /// Whether everyone had posted at the last rebuild: nil before the first.
    @ObservationIgnored private var wasEveryoneIn: Bool?
    @ObservationIgnored private var wired = false

    func wire(reduceMotion: Bool) {
        animation.reduceMotion = reduceMotion
        guard !wired else { return }
        wired = true
        animation.lookupMass = { [tower] id in
            tower.placedBlocks.first { $0.id == id }?.look.blockSize.massTier
        }
        animation.onImpact = { [weak self] landedID, mass in
            guard let self else { return }
            animation.triggerRipple(from: landedID, massTier: mass, placedBlocks: tower.placedBlocks)
            rippleTheLattice(from: landedID)
            let column = tower.placedBlocks.first { $0.id == landedID }?.column ?? 2
            SoundEngine.blockImpact(mass: mass, column: column)
        }
    }

    /// **A block's sender line**: "Sam", or, for a shared win, "Sam with
    /// Ana" (spec 1). Your own reads "You with Sam", and nothing at all when
    /// nobody was tagged, as on your own tower.
    ///
    /// `names` is the crew as you see it: someone removed, or blocked, is not
    /// in it and drops out of the line rather than reading "a friend".
    /// You come last, the way people say it: "Ana, Leo & you".
    nonisolated static func senderLine(_ win: SharedWin, me: UUID, names: [UUID: String]) -> String? {
        let mine = win.senderProfileID == me
        let tagged = win.withPeople.filter { $0 != me && names[$0] != nil }
            .map { names[$0].flatMap { $0.isEmpty ? nil : $0 } ?? "a friend" }
            + (!mine && win.withPeople.contains(me) ? ["you"] : [])
        let who: String
        if mine {
            who = "You"
        } else {
            let name = names[win.senderProfileID] ?? ""
            who = name.isEmpty ? "A friend" : name
        }
        switch tagged.count {
        case 0: return mine ? nil : who
        case 1: return "\(who) with \(tagged[0])"
        default: return "\(who) with \(tagged.dropLast().joined(separator: ", ")) & \(tagged[tagged.count - 1])"
        }
    }

    /// Rebuilds from the crew's wins. A win that was not there last time falls
    /// in from above the screen, as yours do; every tenth one sets the tower
    /// dancing.
    ///
    /// **And so does the win that makes everyone in** (2026-10-06, "the
    /// ritual of winning together"). The last person to post today sets the
    /// whole crew's tower dancing, the same dance and the same haptic as the
    /// tenth win, so the crew's two moments read as one family. It never says
    /// who was last: the dance is the crew's, not anyone's. Only a change
    /// seen while the tower is open counts, so opening a finished day does
    /// not dance again.
    func rebuild(wins: [SharedWin], me: UUID, names: [UUID: String], everyoneIn: Bool = false,
                 reactions: (UUID) -> [Reaction] = { _ in [] }) {
        let ordered = wins.sorted { $0.createdAt < $1.createdAt }
        var entries: [TowerViewModel.TowerEntry] = []
        for win in ordered {
            let line = Self.senderLine(win, me: me, names: names)
            var look = PlacedBlock.Look(win: win, sender: line, reactions: reactions(win.winID), me: me)
            // Set, not inferred from the line: "You with Sam" is still yours.
            look.isMine = win.senderProfileID == me
            look.isTagged = line?.contains(" with ") == true
            entries.append(TowerViewModel.TowerEntry(id: win.winID, look: look))
        }
        let hadBuilt = tower.hasBuiltOnce
        withAnimation(GridConstants.motionSnappy) {
            let dropped = tower.buildTower(entries: entries, merges: false)
            animation.ensureStates(for: tower.placedBlocks.map(\.id))
            guard hadBuilt else { return }
            for id in dropped.subtracting(animation.activelyAnimatingIDs) {
                if let block = tower.placedBlocks.first(where: { $0.id == id }) {
                    animation.setFallStart(for: id, offset: fallStartOffset(for: block))
                }
                animation.enqueueDrop(blockIDs: [id])
            }
        }
        let count = tower.placedBlocks.count
        let milestone = count / GridConstants.danceEvery
        let justFull = Self.becameFull(was: wasEveryoneIn, now: everyoneIn)
        wasEveryoneIn = everyoneIn
        guard let last = lastDanceMilestone else { lastDanceMilestone = milestone; return }
        if count > 0, (count % GridConstants.danceEvery == 0 && milestone != last) || justFull {
            lastDanceMilestone = milestone
            Task { @MainActor in
                // After the tenth has landed, as on the Wins tab.
                while !animation.activelyAnimatingIDs.isEmpty { try? await Task.sleep(for: .milliseconds(60)) }
                try? await Task.sleep(for: .milliseconds(180))
                HapticsEngine.reward()
                animation.triggerJubilation(placedBlocks: tower.placedBlocks)
            }
        } else {
            lastDanceMilestone = milestone
        }
    }

    /// Everyone in the crew has a win on the tower today. A crew of one is
    /// never "everyone": there is nobody to win together with yet.
    nonisolated static func everyoneIn(wins: [SharedWin], members: [UUID]) -> Bool {
        let posted = Set(wins.map(\.senderProfileID))
        return members.count > 1 && members.allSatisfy(posted.contains)
    }

    /// Only the moment it turns: not the first look, not staying full.
    nonisolated static func becameFull(was: Bool?, now: Bool) -> Bool {
        was == false && now
    }

    /// The same measurement the Wins tab makes: far enough above its slot
    /// that the block enters from off the top of the screen.
    private func fallStartOffset(for block: PlacedBlock) -> CGFloat {
        guard probe.hasMeasured else { return -GridConstants.dropRunway }
        let frame = block.frame(cellSize: probe.cellSize)
        let slotTopOnScreen = probe.gridTopOnScreen + (probe.gridHeight - frame.maxY)
        return -max(slotTopOnScreen + frame.height + GridConstants.dropClearance, GridConstants.dropRunway)
    }

    private func rippleTheLattice(from landedID: UUID) {
        guard !animation.reduceMotion,
              let block = tower.placedBlocks.first(where: { $0.id == landedID }) else { return }
        let ripple = LatticeRipple(column: block.column, row: block.row,
                                   columnSpan: block.columnSpan, rowSpan: block.rowSpan)
        latticeRipple = ripple
        let life = TowerLattice.duration(for: ripple.span)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(life + 0.05))
            if latticeRipple == ripple { latticeRipple = nil }
        }
    }
}
