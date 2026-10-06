import PencilKit
import SwiftUI
import UIKit

// MARK: - The bar

/// The reactions you can give a friend's win: "+", 🔥, 👑, ❤️.
///
/// **From the Apollo Figma file** (node 12839:5135): a capsule, the four
/// marks at 20pt, 27pt apart, 14pt in from the ends. Its dark 60% ground is
/// this app's Liquid Glass here, the material every other control on these
/// screens is made of, and each mark is a full 44pt target, which the Figma
/// spacing allows exactly (20 + 27 - 44 = 3pt between targets).
///
/// The one you gave is circled. Tap it again to take it back; tap another to
/// change it, as a Tapback works. "+" opens the system emoji keyboard, as
/// Messages does, for anything else.
struct ReactionBar: View {
    /// Yours, if you reacted.
    let mine: String?
    var onDark = false
    /// Inside a container that is already glass: no capsule of its own.
    var bare = false
    /// The mark under a sliding finger, by its place in `glyphs(mine:)`.
    var hovered: Int? = nil
    /// The emoji keyboard, when the caller opens it (a finger let go on "+").
    var picking: Binding<Bool>? = nil
    let react: (String) -> Void

    @State private var ownPicking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Each mark's width and the gap between, so a finger's position can be
    /// read as a mark without measuring anything (`index(atX:)`).
    static let markSide: CGFloat = 44
    static let gap: CGFloat = 3
    static let inset: CGFloat = 2

    /// The marks in order: "+", the quick ones, and a keyboard one you gave.
    static func glyphs(mine: String?) -> [String] {
        var out = ["+"] + Reaction.quick
        if let mine, !Reaction.quick.contains(mine) { out.append(mine) }
        return out
    }

    /// The mark at a distance from the bar's leading edge, or nil.
    static func index(atX x: CGFloat, count: Int) -> Int? {
        let i = Int(((x - inset + gap / 2) / (markSide + gap)).rounded(.down))
        return (0..<count).contains(i) ? i : nil
    }

    private var isPicking: Binding<Bool> { picking ?? $ownPicking }

    var body: some View {
        let glyphs = Self.glyphs(mine: mine)
        HStack(spacing: Self.gap) {
            ForEach(Array(glyphs.enumerated()), id: \.element) { index, glyph in
                if index == 0 {
                    mark("+", index: 0, label: "More reactions") { isPicking.wrappedValue = true }
                        .overlay {
                            EmojiField(isActive: isPicking) { react($0) }.frame(width: 1, height: 1).opacity(0.01)
                        }
                } else {
                    mark(glyph, index: index, label: glyph, chosen: mine == glyph) { react(glyph) }
                }
            }
        }
        .padding(.horizontal, Self.inset)
        // **The lens.** A drop of glass under the finger as it slides along
        // the bar, gliding from mark to mark: the iOS 26 tab bar's own way
        // of saying which one a finger is on.
        .background(alignment: .leading) {
            if let hovered {
                Lens()
                    .frame(width: Self.markSide + 8, height: Self.markSide + 8)
                    .offset(x: Self.inset - 4 + CGFloat(hovered) * (Self.markSide + Self.gap), y: -6)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? GridConstants.crossFade : GridConstants.elasticPop, value: hovered)
        .modifier(BarGlass(apply: !bare, onPage: !onDark))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("React")
    }

    private func mark(_ glyph: String, index: Int, label: String, chosen: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            // 20pt in the Figma frame, which is Title 3; it grows with
            // Dynamic Type.
            Text(glyph)
                .font(.title3)
                .foregroundStyle(onDark ? AppColors.onDarkStrong : AppColors.inkPrimary)
                .scaleEffect(hovered == index ? 1.4 : 1)
                .offset(y: hovered == index ? -8 : 0)
                .frame(width: Self.markSide, height: Self.markSide)
                .background {
                    if chosen, hovered == nil {
                        Circle()
                            .fill(onDark ? Color.white.opacity(0.18) : AppColors.inkPrimary.opacity(0.08))
                            .padding(4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .contentShape(Circle())
        }
        // An emoji on the bar is ink, not glass, so it takes the app's press.
        .buttonStyle(.pressSurface)
        .animation(GridConstants.elasticPop, value: chosen)
        .accessibilityLabel(label)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }
}

/// The system emoji keyboard, for the bar's "+": a field nobody sees that
/// asks for the emoji input mode, takes the first emoji typed, and closes.
struct EmojiField: UIViewRepresentable {
    @Binding var isActive: Bool
    let picked: (String) -> Void

    final class Field: UITextField {
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiField
        init(_ parent: EmojiField) { self.parent = parent }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            if let first = string.first, first.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0x238C }) {
                parent.picked(String(first))
                parent.isActive = false
                field.resignFirstResponder()
            }
            return false
        }

        func textFieldDidEndEditing(_ field: UITextField) { parent.isActive = false }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> Field {
        let field = Field()
        field.delegate = context.coordinator
        field.tintColor = .clear
        field.accessibilityElementsHidden = true
        return field
    }

    func updateUIView(_ field: Field, context: Context) {
        context.coordinator.parent = self
        if isActive, !field.isFirstResponder { DispatchQueue.main.async { field.becomeFirstResponder() } }
        if !isActive, field.isFirstResponder { field.resignFirstResponder() }
    }
}

// MARK: - Who reacted

/// Everyone who reacted, as Messages shows it: each person's face with their
/// reaction at its shoulder.
struct ReactorRow: View {
    let reactions: [Reaction]
    let crew: Crew
    let me: UUID
    var onDark = false

    var body: some View {
        if !reactions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(reactions) { reaction in
                        if let member = crew.member(reaction.profileID) {
                            VStack(spacing: 4) {
                                CrewFace(member: member, crew: crew.id, me: me, side: 40)
                                    .overlay(alignment: .bottomTrailing) {
                                        Text(reaction.emoji)
                                            .font(Typography.screenSubtitle)
                                            .offset(x: 6, y: 4)
                                    }
                                Text(member.profileID == me ? "You" : member.shortName)
                                    .font(Typography.screenSubtitle)
                                    .foregroundStyle(onDark ? AppColors.onDarkQuiet : AppColors.inkSecondary)
                                    .lineLimit(1)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(member.profileID == me ? "You" : member.shortName), \(reaction.emoji)")
                        }
                    }
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - The burst

/// A double-tap's heart, over the block it landed on.
///
/// The emoji springs up from nothing past full size and settles, then rises
/// and fades, while a few small ones drift up and out around it: Instagram's
/// gesture, in this app's own tokens (`elasticPop` up, `popSpray` out, the
/// same two the tower head's bubble pops with).
/// Under Reduce Motion it fades in and out where it is, and nothing moves.
struct ReactionBurst: View {
    let emoji: String
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .start

    enum Phase { case start, pop, settle, leave }

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<5, id: \.self) { i in
                    let angle = Double(i - 2) * 0.42 - .pi / 2
                    Text(emoji)
                        .font(.system(size: size * 0.32))
                        .offset(x: phase == .start || phase == .pop ? 0 : CGFloat(cos(angle)) * size * 0.9,
                                y: phase == .start || phase == .pop ? 0 : CGFloat(sin(angle)) * size * 1.05)
                        .scaleEffect(phase == .start ? 0.2 : (phase == .leave ? 0.6 : 1))
                        .opacity(phase == .settle ? 1 : 0)
                }
            }
            Text(emoji)
                .font(.system(size: size))
                .scaleEffect(reduceMotion ? 1 : scale)
                .offset(y: phase == .leave && !reduceMotion ? -size * 0.45 : 0)
                .opacity(phase == .start || phase == .leave ? 0 : 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                withAnimation(GridConstants.crossFade) { phase = .settle }
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(GridConstants.crossFade) { phase = .leave }
                return
            }
            withAnimation(GridConstants.elasticPop) { phase = .pop }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(GridConstants.popSpray) { phase = .settle }
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(GridConstants.popSpray) { phase = .leave }
        }
    }

    private var scale: CGFloat {
        switch phase {
        case .start: 0.15
        case .pop: 1.22
        case .settle: 1
        case .leave: 0.9
        }
    }
}

/// The drop of glass under a sliding finger.
private struct Lens: View {
    var body: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular.interactive(), in: Circle())
        } else {
            Circle().fill(.ultraThinMaterial)
        }
    }
}

private struct BarGlass: ViewModifier {
    let apply: Bool
    let onPage: Bool
    func body(content: Content) -> some View {
        // A bar of buttons, not a button: its glass must not take their taps.
        if apply { content.glassCapsule(onPage: onPage, interactive: false) } else { content }
    }
}

// MARK: - Reactions, under a photograph

/// A crew photograph's reactions in the viewer: ONE control (the owner,
/// 2026-10-02: "why should there be multiple buttons").
///
/// At rest it is a capsule that says who reacted, yours first ("❤️🔥 You
/// and Sam"), or, on a friend's win nobody has reacted to, a smiley. A tap
/// opens the bar and everyone's faces over it; reacting folds it again. The
/// bar is never simply there. Report and Remove stay in the viewer's ⋯.
struct CrewReactionsPanel: View {
    let winID: UUID
    let crewID: CrewID
    let mine: Bool
    var onDark = false

    @State private var open = false
    @State private var replying = false
    @State private var draft = ""
    @State private var refused = false
    @State private var doodling = false
    @State private var doodleRefused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var store: SocialStore { SocialStore.shared }

    /// Whoever posted the win, by name, for the reply's words.
    private var owner: String {
        let id = store.winsByCrew[crewID]?.first { $0.winID == winID }?.senderProfileID
        return id.map { CrewReactionsPanel.name($0, crewID: crewID) } ?? "them"
    }

    var body: some View {
        let reactions = CrewReactionsPanel.ordered(store.reactions(to: winID, in: crewID), me: store.me)
        let myReaction = store.myReaction(to: winID, in: crewID)
        VStack(spacing: 10) {
            if open, !mine {
                ReactionBar(mine: myReaction, onDark: onDark) { emoji in
                    Task { await store.react(emoji, to: winID, in: crewID) }
                    withAnimation(motion) { open = false }
                }
                .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                // **Reply** and **Doodle** post into the crew's day chat,
                // quoting this win (the owner, 2026-10-05). They used to be a
                // line and a drawing under the photo that only the win's owner
                // saw; the lists that showed them here are gone, and the panel
                // is the bar, these two words and who reacted.
                // Off together when writing is off (`canReply`).
                if store.canReply() {
                    HStack(spacing: GridConstants.gapTight) {
                        replyChip("Reply") {
                            draft = ""
                            replying = true
                        }
                        replyChip("Doodle") { doodling = true }
                    }
                    .transition(.opacity)
                }
            }
            if open, let crew = store.visible(crewID), !reactions.isEmpty {
                ReactorRow(reactions: reactions, crew: crew, me: store.me, onDark: onDark)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if !reactions.isEmpty || !mine {
                Button {
                    HapticsEngine.tick()
                    withAnimation(motion) { open.toggle() }
                } label: {
                    Group {
                        if reactions.isEmpty {
                            Image(systemName: open ? "xmark" : "face.smiling")
                                .font(.system(size: GridConstants.iconToolbar, weight: .medium))
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 44, height: 44)
                        } else {
                            CrewReactionsPanel.line(reactions, crewID: crewID, onDark: onDark)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                        }
                    }
                    .foregroundStyle(onDark ? AppColors.onDarkStrong : AppColors.inkPrimary)
                    .glassCapsule(onPage: !onDark)
                    .contentShape(Capsule())
                }
                // **Plain, as the viewer's close and ⋯ are.** A scaling press
                // style on a label that is interactive glass fought the glass's
                // own response to the finger: on a phone the face pressed and
                // the tap was cancelled, so the bar never opened (the owner,
                // 2026-10-05). The simulator's instant taps never showed it.
                .buttonStyle(.plain)
                .accessibilityLabel(reactions.isEmpty ? "React"
                    : "Reactions: " + reactions.map { "\(CrewReactionsPanel.name($0.profileID, crewID: crewID)) \($0.emoji)" }.joined(separator: ", "))
            }
        }
        .animation(motion, value: myReaction)
        .animation(motion, value: open)
        .alert("Reply to \(owner)", isPresented: $replying) {
            TextField("A few words", text: $draft)
            Button("Send") {
                let text = draft
                Task {
                    let outcome = await store.reply(text, to: winID, in: crewID)
                    if outcome == .refusedWords { refused = true }
                }
                withAnimation(motion) { open = false }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your reply goes to the crew's chat. It clears when the day ends.")
        }
        .alert("Try other words", isPresented: $refused) {
            Button("OK", role: .cancel) {}
        }
        .alert("That doodle stays with you", isPresented: $doodleRefused) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $doodling) {
            DoodleSheet(owner: owner) { drawing in
                guard let png = InkExport.doodlePNG(drawing) else { return }
                Task {
                    let outcome = await store.doodle(png, to: winID, in: crewID)
                    if outcome == .refusedSketch { doodleRefused = true }
                }
                withAnimation(motion) { open = false }
            }
        }
        #if DEBUG
        // `-strataCrewDoodle sheet|seed`: the panel opens by itself, and on a
        // friend's win the doodle sheet over it, so both can be photographed.
        .task {
            guard let which = DebugHarness.argument("-strataCrewDoodle") else { return }
            try? await Task.sleep(for: .milliseconds(800))
            open = true
            if which == "sheet", !mine { doodling = true }
        }
        #endif
    }

    private var motion: Animation { reduceMotion ? GridConstants.crossFade : GridConstants.elasticPop }

    /// One of the two words under the bar: Reply and Doodle, alike.
    private func replyChip(_ word: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(word)
                .font(Typography.headerSmall)
                .foregroundStyle(onDark ? AppColors.onDarkStrong : AppColors.inkPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .glassCapsule(onPage: !onDark)
                .contentShape(Capsule())
        }
        // Plain on glass, as the face is (see its note): a scaling press on
        // interactive glass cancelled taps on a real phone.
        .buttonStyle(.plain)
    }

    /// Yours first, then in the order they came.
    static func ordered(_ reactions: [Reaction], me: UUID) -> [Reaction] {
        reactions.sorted { a, b in
            if a.profileID == me { return true }
            if b.profileID == me { return false }
            return a.createdAt < b.createdAt
        }
    }

    /// "❤️🔥 You and Sam": the emoji given, then who gave them.
    @MainActor
    static func line(_ reactions: [Reaction], crewID: CrewID, onDark: Bool) -> some View {
        var emoji: [String] = []
        for r in reactions where !emoji.contains(r.emoji) { emoji.append(r.emoji) }
        let names = reactions.map { name($0.profileID, crewID: crewID) }
        let words = names.count > 3
            ? "\(names.prefix(2).joined(separator: ", ")) and \(names.count - 2) others"
            : names.formatted(.list(type: .and))
        return HStack(spacing: 8) {
            HStack(spacing: -4) {
                ForEach(Array(emoji.prefix(3).enumerated()), id: \.offset) { index, e in
                    Text(e).font(Typography.headerMedium).zIndex(Double(3 - index))
                }
            }
            Text(words)
                .font(Typography.headerSmall)
                .lineLimit(1)
            // No chevron: it promised a drawer, and on your own win there is
            // nothing in it to do (the owner, 2026-10-03: "it shows the up
            // chevron even though you cant really do anything with it").
        }
    }

    @MainActor
    static func name(_ id: UUID, crewID: CrewID) -> String {
        let store = SocialStore.shared
        if id == store.me { return "You" }
        let short = store.crew(crewID)?.member(id)?.shortName ?? ""
        return short.isEmpty ? "A friend" : short
    }
}
