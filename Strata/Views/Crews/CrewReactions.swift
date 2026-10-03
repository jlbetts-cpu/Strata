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
    let react: (String) -> Void

    @State private var picking = false

    var body: some View {
        HStack(spacing: 3) {
            mark("+", label: "More reactions") { picking = true }
                .overlay { EmojiField(isActive: $picking) { react($0) }.frame(width: 1, height: 1).opacity(0.01) }
            ForEach(Reaction.quick, id: \.self) { emoji in
                mark(emoji, label: emoji, chosen: mine == emoji) { react(emoji) }
            }
            // Something from the keyboard you already gave, shown so it can
            // be seen and taken back.
            if let mine, !Reaction.quick.contains(mine) {
                mark(mine, label: mine, chosen: true) { react(mine) }
            }
        }
        .padding(.horizontal, 2)
        .glassCapsule(onPage: !onDark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("React")
    }

    private func mark(_ glyph: String, label: String, chosen: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            Text(glyph)
                .font(.system(size: 20))
                .foregroundStyle(onDark ? AppColors.onDarkStrong : AppColors.inkPrimary)
                .frame(width: 44, height: 44)
                .background {
                    if chosen {
                        Circle()
                            .fill(onDark ? Color.white.opacity(0.18) : AppColors.inkPrimary.opacity(0.08))
                            .padding(4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .contentShape(Circle())
        }
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
