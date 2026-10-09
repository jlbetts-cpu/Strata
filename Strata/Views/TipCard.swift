import SwiftUI

/// **Every tip in the app, one object in one place** (the owner, 2026-10-08:
/// "the tips should just be clean and consistent inside a container... a
/// consistent style for those, easy to click away and grasp"; "half the tips
/// dont even appear in the right spot").
///
/// Before this there were four answers to one question: the daily cue and
/// the day-one hint were a dark chat bubble aimed at the slot from a frame
/// captured a moment earlier (so it landed wherever the slot had been), set
/// `fixedSize` on one line (so a long line ran off the screen's edge); the
/// month drawing's was a system popover that sat over the calendar and once
/// over a sheet; the first-win invitation was a bare line under the header.
///
/// Now a tip is a container under the page's header, full width between the
/// page margins: one line, wrapped, an optional word to act on, and a close
/// glyph with a 44pt target. Its ground is the page's own side of light and
/// dark, light on light and dark on dark, separated by a hairline and never a
/// shadow (chrome separates with hairlines and translucency).
struct TipCard: View {
    let text: String
    /// A word to act on, set as a sheet's confirm word ("Invite").
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// The whole card answers a tap when the tip IS the action (the daily
    /// cue opens Add a Win).
    var onTap: (() -> Void)? = nil
    var close: () -> Void

    private static let tapTarget: CGFloat = 44
    private static let pillHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: GridConstants.gapTight) {
            words
            // **A small primary, not a word** (the owner, 2026-10-08: "the
            // start a crew should be like a white button... like primary so
            // dark for light light for dark"). `PrimaryCapsule`'s own fill
            // and type, at a tip's size, with the 44pt target around it.
            if let actionTitle, let action {
                Button {
                    HapticsEngine.lightTap()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(Typography.headerSmall)
                        .foregroundStyle(WarmBackground.top)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, GridConstants.gapItem + 2)
                        .frame(height: Self.pillHeight)
                        .background(Capsule(style: .continuous).fill(AppColors.inkPrimary))
                        .frame(minHeight: Self.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
            }
            Button {
                HapticsEngine.lightTap()
                close()
            } label: {
                Image(systemName: "xmark")
                    .iconSize(GridConstants.iconAction, relativeTo: .body, weight: .semibold)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(width: Self.tapTarget, height: Self.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityLabel("Close")
        }
        .padding(.leading, GridConstants.gapLabel)
        .padding(.trailing, GridConstants.spacing)
        .padding(.vertical, GridConstants.spacing)
        .frame(maxWidth: .infinity)
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

    @ViewBuilder
    private var words: some View {
        let line = Text(text)
            .font(Typography.bodyLarge)
            .foregroundStyle(AppColors.inkPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Self.tapTarget, alignment: .leading)
        if let onTap {
            Button(action: onTap) { line.contentShape(Rectangle()) }
                .buttonStyle(.pressWord)
        } else {
            line
        }
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
