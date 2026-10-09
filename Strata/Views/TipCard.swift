import SwiftUI

/// **Every tip in the app, one object in one place** (the owner, 2026-10-08:
/// "the tips should just be clean and consistent inside a container... a
/// consistent style for those, easy to click away and grasp"; "half the tips
/// dont even appear in the right spot").
///
/// **Its anatomy is Apple's own tip's** (the second pass, same day: "the hints
/// feel really cramped and they dont seem to me to fit the system"). One line
/// of body type squeezed between an edge and a close glyph read as a banner
/// wedged into the page. A tip now has what TipKit's own view has, in this
/// app's materials: a drawn mark in a round well, a short title, a message in
/// the secondary ink under it, its action as a small primary below the words,
/// and a quiet close in the corner, with 16 of air on every side.
///
/// It stands under the page's header, full width between the page margins.
/// Its ground is the page's own side of light and dark, a step toward the
/// viewer, separated by a hairline and never a shadow.
struct TipCard: View {
    let title: String
    var message: String? = nil
    /// The owner's drawn mark (`docs/icons/source.png`, cut to `Tip*`):
    /// his sparkle star unless a tip names its own.
    var mark: String = "TipSparkle"
    /// The action, as a small primary under the words ("Start a Crew").
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// The whole card answers a tap when the tip IS the action (the daily
    /// cue opens Add a Win).
    var onTap: (() -> Void)? = nil
    var close: () -> Void

    private static let tapTarget: CGFloat = 44
    private static let pillHeight: CGFloat = 34
    private static let well: CGFloat = 40

    /// **The grid** (the owner, 2026-10-08: "make sure the grid is good on
    /// the tips they still look a bit inconsistent"). Every measure is a
    /// token and every edge lines up with another:
    ///
    ///     16 | well 40 | 12 | words ............ | x (glyph 16 from edge)
    ///                       | pill, at the words' own left edge
    ///     16
    ///
    /// The words centre on the well, the close glyph shares their centre
    /// line, and the pill starts where the words start (16 + 40 + 12 = 68
    /// from the card's edge), so a tip with an action and one without are the
    /// same object with one more row.
    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            HStack(alignment: .center, spacing: GridConstants.gapItem) {
                markWell
                words
                closeButton
                    // The 44pt target reaches into the card's own margin, so
                    // the glyph, not the target, sits 16 from the edge.
                    .padding(.trailing, -Self.closeInset)
                    .padding(.vertical, -2)
            }
            if let actionTitle, let action {
                pill(actionTitle, action)
                    .padding(.leading, Self.well + GridConstants.gapItem)
            }
        }
        .padding(GridConstants.gapLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                .fill(Self.ground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                .strokeBorder(Self.hairline, lineWidth: GridConstants.strokeThin)
        }
        .accessibilityElement(children: .contain)
    }

    /// How far the close target reaches past the words into the margin:
    /// the target is 44 and the glyph about 12, so 16 of air each side.
    private static let closeInset: CGFloat = 16

    private var markWell: some View {
        MarkWell(mark: mark)
    }

    @ViewBuilder
    private var words: some View {
        let stack = VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
            if let message {
                Text(message)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        if let onTap {
            Button(action: onTap) { stack.contentShape(Rectangle()) }
                .buttonStyle(.pressWord)
        } else {
            stack
        }
    }

    /// **A small primary** (the owner: "it should be a button like primary
    /// so dark for light light for dark"): `PrimaryCapsule`'s fill and type at
    /// a tip's size, with the 44pt target around it.
    private func pill(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            Text(title)
                .font(Typography.headerSmall)
                .foregroundStyle(WarmBackground.top)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, GridConstants.gapLabel)
                .frame(height: Self.pillHeight)
                .background(Capsule(style: .continuous).fill(AppColors.inkPrimary))
                .frame(minHeight: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
    }

    private var closeButton: some View {
        Button {
            HapticsEngine.lightTap()
            close()
        } label: {
            Image(systemName: "xmark")
                .iconSize(GridConstants.iconMedium, relativeTo: .body, weight: .semibold)
                .foregroundStyle(AppColors.inkTertiary)
                .frame(width: Self.tapTarget, height: Self.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel("Close")
    }

    /// White on the light page (0.992), a raised charcoal on the dark one
    /// (0.112): a step toward the viewer on each side, never the other side's
    /// colour.
    static let ground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.165, green: 0.162, blue: 0.158, alpha: 1)
            : UIColor(white: 1, alpha: 1)
    })
    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.07)
    })
}

/// **Who is showing a tip right now**, so two never stand in one place: the
/// first-win invitation and the day-one hint both answer a first win.
@MainActor @Observable
final class TipStage {
    static let shared = TipStage()
    private(set) var holder: String?
    /// **The first-win invitation, handed to the Wins header** to draw in
    /// the one place a tip stands there (`MainAppView.winsTip`), so it and the
    /// daily cue can never stand in two places or on each other.
    var invite: InviteTip?

    func take(_ who: String) -> Bool {
        guard holder == nil || holder == who else { return false }
        holder = who
        return true
    }

    func release(_ who: String) {
        if holder == who { holder = nil }
    }

    /// Waits for the place under the header to be free, up to `seconds`.
    func waitUntilFree(seconds: Double = 20) async {
        var waited = 0.0
        while holder != nil, waited < seconds, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
            waited += 0.25
        }
    }
}

extension View {
    /// A tip under a page's header: full width between the page margins,
    /// arriving from the top.
    func tipUnderHeader<Tip: View>(top: CGFloat, @ViewBuilder _ tip: () -> Tip) -> some View {
        overlay(alignment: .top) {
            tip()
                .padding(.horizontal, GridConstants.horizontalPadding)
                .padding(.top, top)
        }
    }
}

/// The first-win invitation's words and actions, for the Wins header.
struct InviteTip {
    let hasCrew: Bool
    let invite: () -> Void
    let close: () -> Void
}

/// **Every tip's words in one place**, so the one-line rule can be held:
/// a tip's message is one line at the column it gets (about 237pt on a
/// 393pt phone, 15pt type), which is 32 characters. A message that wrapped
/// made that tip a line taller than its neighbours (photographed 2026-10-08).
nonisolated enum TipCopy {
    static let monthDrawing = "Hold the drawing to redraw it."
    static let longestMessage = 32
    static var messages: [String] {
        [monthDrawing, DayOneHint.drawOut, WinCue.tapToAdd, FirstWinInvite.ask]
    }
}

/// **His drawn mark in its round well**: the one way a mark is shown, in a
/// tip and in every list that explains something (`FeatureRow`). Cut on the
/// 26pt canvas (`docs/icons/slice_icons.py`) and shown at that size, never
/// scaled, so every mark in the app is one size in one well.
struct MarkWell: View {
    let mark: String
    static let side: CGFloat = 40

    var body: some View {
        Group {
            if UIImage(named: mark) != nil {
                Image(mark).renderingMode(.template)
            } else {
                Image("TipSparkle").renderingMode(.template)
            }
        }
        .foregroundStyle(AppColors.inkPrimary)
        .frame(width: Self.side, height: Self.side)
        .background(Circle().fill(AppColors.quietFill))
        .accessibilityHidden(true)
    }
}

/// **One layout for everything that explains** (the owner, 2026-10-08, of
/// the Crews intro, the crew rules and Why It Works: "why are they all so
/// differnt in terms of layout... premium apps know how to use there space").
/// They were three: a mark and a sentence, a mark and a wrapping rule, a
/// small mark and a heading over a paragraph. Now each is a list of these,
/// the tip's own anatomy without its card: the mark in its well, a short
/// title centred on the well, the words under it in the secondary ink.
/// Rows stand `gapWide` apart on the page margin, the edge the page's button
/// keeps, so the list and the action line up.
struct FeatureRow: View {
    let mark: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: GridConstants.gapLabel) {
            MarkWell(mark: mark)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(detail)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The title's line centred on the well: a 22pt line in 40.
            .padding(.top, (MarkWell.side - 22) / 2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A list of `FeatureRow`s at the one spacing.
struct FeatureList: View {
    let rows: [(mark: String, title: String, detail: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapWide) {
            ForEach(rows, id: \.title) { FeatureRow(mark: $0.mark, title: $0.title, detail: $0.detail) }
        }
    }
}
