import SwiftUI

/// **Hold a friend's block to react, on any tower of shared wins.**
///
/// It lived inside `CrewTowerView` until a friend's profile became their
/// tower (the owner, 2026-10-15: "make sure you are able to still be able to
/// react and the functionality is very good on everything"). One copy, so the
/// profile's tower holds, slides, double-taps and bursts exactly as the
/// crew's does: the state and the rules here, the drawing in
/// `TowerReactionLayers`.
///
/// The hold is only for reacting (the owner, 2026-10-02: "the hold... should
/// just be to react"). Who reacted and Report are in the carousel a tap
/// opens.
@MainActor @Observable
final class TowerReactions {
    struct Burst: Identifiable { let id = UUID(); let block: UUID; let emoji: String }

    /// The crew a block's win is in, or nil when that block takes no
    /// reaction on this tower.
    @ObservationIgnored var crewOf: (UUID) -> CrewID? = { _ in nil }

    /// The block a press and hold opened the reactions over.
    var reacting: UUID?
    /// Double-tap hearts in the air, over the blocks they landed on.
    var bursts: [Burst] = []
    /// The mark under a finger sliding from a hold (`HoldPhase`).
    var hovered: Int?
    /// The emoji keyboard, opened from "+".
    var pickingMore = false
    var barSize = CGSize(width: 200, height: 44)
    /// Where the open bar stands, for reading a finger against it.
    @ObservationIgnored var barFrame: (() -> CGPoint)?
    /// When it opened: the finger lifting off a hold must not also count as
    /// a tap and open the block.
    @ObservationIgnored private var heldAt = Date.distantPast
    /// The bar closing itself after a hold let go of nothing.
    @ObservationIgnored private var dismissing: Task<Void, Never>?

    private var store: SocialStore { .shared }

    /// A tap that is really the end of a hold.
    var justHeld: Bool { Date().timeIntervalSince(heldAt) <= 0.6 }

    func mine(_ id: UUID) -> String? {
        crewOf(id).flatMap { store.myReaction(to: id, in: $0) }
    }

    func hold(_ id: UUID, _ phase: HoldPhase) {
        switch phase {
        case .began:
            guard crewOf(id) != nil else { return }
            HapticsEngine.success()
            heldAt = Date()
            dismissing?.cancel()
            hovered = nil
            reacting = id
        case .moved(let at):
            guard reacting == id else { return }
            let next = mark(at: at)
            if next != hovered {
                if next != nil { HapticsEngine.lightTap() }
                hovered = next
            }
        case .ended(let at):
            guard reacting == id else { return }
            let chosen = at.flatMap { mark(at: $0) }
            hovered = nil
            if let chosen {
                let glyph = ReactionBar.glyphs(mine: mine(id))[chosen]
                if glyph == "+" { pickingMore = true } else { give(glyph, to: id) }
            } else {
                // Let go anywhere else: the bar stays a moment for a tap,
                // then goes on its own (the owner, 2026-10-03: "it doesnt
                // disappear automatically").
                closeSoon()
            }
        }
    }

    /// The heart, without a bar.
    func doubleTap(_ id: UUID) {
        guard let crew = crewOf(id) else { return }
        HapticsEngine.success()
        burst(Reaction.doubleTap, over: id)
        if store.myReaction(to: id, in: crew) != Reaction.doubleTap {
            Task { await store.react(Reaction.doubleTap, to: id, in: crew) }
        }
    }

    func give(_ emoji: String, to id: UUID) {
        guard let crew = crewOf(id) else { return close() }
        if store.myReaction(to: id, in: crew) != emoji { burst(emoji, over: id) }
        HapticsEngine.success()
        Task { await store.react(emoji, to: id, in: crew) }
        close()
    }

    func close() {
        dismissing?.cancel()
        barFrame = nil
        hovered = nil
        pickingMore = false
        reacting = nil
        heldAt = Date()
    }

    func setPicking(_ open: Bool) {
        pickingMore = open
        if open { dismissing?.cancel() } else if reacting != nil { closeSoon() }
    }

    private func closeSoon() {
        dismissing?.cancel()
        dismissing = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, !pickingMore else { return }
            close()
        }
    }

    private func burst(_ emoji: String, over id: UUID) {
        let burst = Burst(block: id, emoji: emoji)
        bursts.append(burst)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            bursts.removeAll { $0.id == burst.id }
        }
    }

    /// The mark under a finger, read from where the bar stands: the finger
    /// can be a little above or below the row, as on a Tapback.
    private func mark(at point: CGPoint) -> Int? {
        guard let reacting, let center = barFrame?() else { return nil }
        let top = center.y - barSize.height / 2, bottom = center.y + barSize.height / 2
        guard point.y > top - 28, point.y < bottom + 36 else { return nil }
        let count = ReactionBar.glyphs(mine: mine(reacting)).count
        return ReactionBar.index(atX: point.x - (center.x - barSize.width / 2), count: count)
    }

    func barCenter(over f: CGRect, gridW: CGFloat, gridH: CGFloat) -> CGPoint {
        CGPoint(x: min(max(f.midX, barSize.width / 2), gridW - barSize.width / 2),
                y: gridH - f.minY - f.height - 8 - barSize.height / 2)
    }
}

/// The hearts and the bar, over the tower's own grid. OVERLAYS, never
/// children of the stack: as a child, `.position` took the whole proposed
/// size and the tower jumped 85pt for the length of a burst (filmed
/// 2026-10-02).
struct TowerReactionLayers: ViewModifier {
    let reactions: TowerReactions
    let blocks: [PlacedBlock]
    let colW: CGFloat
    let gridW: CGFloat
    let gridH: CGFloat
    /// Reply on the hold itself, where the tower has a chat to answer in.
    var reply: ((UUID) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                ForEach(reactions.bursts) { burst in
                    if let block = blocks.first(where: { $0.id == burst.block }) {
                        let f = block.frame(cellSize: colW)
                        ReactionBurst(emoji: burst.emoji, size: min(f.width, f.height) * 0.62)
                            .frame(width: f.width, height: f.height)
                            .offset(x: f.minX, y: gridH - f.minY - f.height)
                    }
                }
            }
            // The reactions a hold opened, over the block that was held, and
            // anywhere else on the tower closes them.
            .overlay(alignment: .topLeading) {
                if let id = reactions.reacting, let block = blocks.first(where: { $0.id == id }) {
                    let f = block.frame(cellSize: colW)
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { reactions.close() }
                        // Centred over the block, kept inside the tower's
                        // width, and 8pt clear of the block's top edge.
                        bar(id)
                            .fixedSize()
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { reactions.barSize = $0 }
                            .position(reactions.barCenter(over: f, gridW: gridW, gridH: gridH))
                            .onAppear {
                                // Weak: the object holding a closure that
                                // holds the object never let go of either.
                                reactions.barFrame = { [weak reactions] in
                                    reactions?.barCenter(over: f, gridW: gridW, gridH: gridH) ?? .zero
                                }
                            }
                            .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                    }
                    .frame(width: gridW, height: gridH, alignment: .topLeading)
                }
            }
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.elasticPop, value: reactions.reacting)
            // Where a sliding finger is read (`HoldPhase.space`): the same
            // top-leading origin the bar is positioned from.
            .coordinateSpace(.named(HoldPhase.space))
    }

    private func bar(_ id: UUID) -> some View {
        ReactionBar(mine: reactions.mine(id), hovered: reactions.hovered,
                    picking: Binding(get: { reactions.pickingMore }, set: { reactions.setPicking($0) })) { emoji in
            reactions.give(emoji, to: id)
        }
        // **Reply, on the hold itself** (the owner, 2026-10-14: "replying to
        // wins is really hidden like you have to press on the win and then
        // press the reaction button and then press reply ... when you are
        // holding to react reply should pop up as an option and the chat
        // should pop up"). Over the bar, as an overlay, so the bar's own
        // measure (what a sliding finger is read against) is the marks alone.
        .overlay(alignment: .top) {
            if let reply, SocialStore.shared.canReply() {
                Button {
                    HapticsEngine.lightTap()
                    reactions.close()
                    reply(id)
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.inkPrimary)
                        .padding(.horizontal, GridConstants.gapLabel)
                        .frame(minHeight: 44)
                        // On the tower's page: its clear glass (2026-10-17).
                        .glassCapsule(onPage: true)
                        .contentShape(Capsule())
                }
                .buttonStyle(.pressSurface)
                .fixedSize()
                // Its foot `gapTight` above the bar's top edge.
                .offset(y: -(44 + GridConstants.gapTight))
                .accessibilityHint("Opens the chat with this win quoted.")
            }
        }
    }
}
