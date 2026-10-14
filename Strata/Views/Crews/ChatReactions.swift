import SwiftUI
import UIKit

// MARK: - Under a line

/// **A chat line's reactions, as small chips under it** (the owner,
/// 2026-10-06: "make it so you can react to chat messages with stickers and
/// emojis").
///
/// One chip a mark: the emoji, or the sticker's picture at 22pt, and a count
/// beside it only when more than one person chose the same. Yours sits on a
/// deeper fill, the chat's own way of saying "this one is you" without a
/// ring or a colour: ink at 16% against the quiet 6% (at 10% the two
/// measured 4 levels apart on the page, and could not be told apart). **Quiet**, as the crew block's badge was made
/// quiet (the owner, 2026-10-03: "they feel too loud like in the pill"): a
/// shape behind a mark, no glass, no shadow, no border.
///
/// Not a button. Holding the line opens its bar, where your own pick is
/// circled and a tap on it takes it back, as a win's bar works.
struct ChatReactionChips: View {
    let reactions: [Reaction]
    let me: UUID
    /// A person's name as the chat says it ("You", "Sam"), for VoiceOver.
    let name: (UUID) -> String

    /// The sticker's side in a chip: the chat's emoji at body size, matched.
    static let stickerSide: CGFloat = 22
    static let chipHeight: CGFloat = 28

    /// One chip: everyone who chose one mark.
    struct Chip: Identifiable, Equatable {
        let mark: String
        var people: [UUID]
        /// The picture to draw, for a sticker.
        var sticker: URL?
        var mine: Bool
        var id: String { mark }
    }

    /// The chips in order: yours first, then each mark in the order it was
    /// first given. Two people choosing the same emoji share one chip; two
    /// stickers never do, since each is someone's own.
    static func chips(_ reactions: [Reaction], me: UUID) -> [Chip] {
        let ordered = CrewReactionsPanel.ordered(reactions, me: me)
        var out: [Chip] = []
        for reaction in ordered {
            if let i = out.firstIndex(where: { $0.mark == reaction.emoji }) {
                out[i].people.append(reaction.profileID)
                out[i].mine = out[i].mine || reaction.profileID == me
            } else {
                out.append(Chip(mark: reaction.emoji, people: [reaction.profileID],
                                sticker: reaction.isSticker ? reaction.sketch : nil,
                                mine: reaction.profileID == me))
            }
        }
        return out
    }

    var body: some View {
        let chips = Self.chips(reactions, me: me)
        if !chips.isEmpty {
            HStack(spacing: GridConstants.spacing) {
                ForEach(chips) { chip in
                    HStack(spacing: 3) {
                        mark(chip)
                        if chip.people.count > 1 {
                            Text("\(chip.people.count)")
                                .font(Typography.headerSmall)
                                .monospacedDigit()
                                .foregroundStyle(AppColors.inkSecondary)
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.horizontal, GridConstants.gapTight)
                    .frame(minHeight: Self.chipHeight)
                    .background {
                        RoundedRectangle(cornerRadius: Self.chipHeight / 2, style: .continuous)
                            .fill(chip.mine ? AppColors.chosenFill : AppColors.quietFill)
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reactions: " + CrewReactionsPanel.ordered(reactions, me: me).map {
                "\(name($0.profileID)) \($0.isSticker ? "a sticker" : $0.emoji)"
            }.joined(separator: ", "))
        }
    }

    @ViewBuilder
    private func mark(_ chip: Chip) -> some View {
        if let url = chip.sticker {
            if let image = ChatStickerImages.image(at: url) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.stickerSide, height: Self.stickerSide)
            }
        } else {
            Text(chip.mark).font(Typography.bodyLarge)
        }
    }
}

/// A sticker that arrived on a line, decoded once: the chat redraws every few
/// seconds while it is open (`refreshLive`), and a picture read from disk on
/// every pass is a hitch nobody asked for.
@MainActor
enum ChatStickerImages {
    private static let cache = NSCache<NSURL, UIImage>()

    static func image(at url: URL) -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

// MARK: - The bar

/// **The reactions row at the top of a held line's menu** (the owner,
/// 2026-10-13: a hold opens "Reply, Heart, Copy, Report", "with an
/// iMessage-style reactions row ABOVE the menu"). The win's own bar ("+",
/// 🔥, 👑, ❤️, `ReactionBar`), bare: the menu is its ground.
///
/// It was its own glass capsule under the line, with your stickers
/// scrolling inside it and Report and Block folded into a ⋯. Report is a
/// row of the menu now, Block is on the person's face, and **"+" opens your
/// stickers** in the app's sticker sheet, where a tap puts one on the line.
/// Someone who may not send photographs (13 to 15) gets the emoji keyboard
/// behind "+" instead: a sticker is lifted out of a photograph.
struct ChatReactionBar: View {
    /// Yours on this line, if any.
    let mine: Reaction?
    let stickersAllowed: Bool
    let pick: (String) -> Void
    let stickers: () -> Void

    var body: some View {
        ReactionBar(mine: mine.flatMap { $0.isSticker ? nil : $0.emoji }, bare: true,
                    onMore: stickersAllowed ? stickers : nil) { pick($0) }
    }
}
