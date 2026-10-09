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
    /// The owner's drawn mark when it is in the catalogue ("TipBulb"), and
    /// the system's bulb until then.
    var mark: String = "TipBulb"
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

    var body: some View {
        HStack(alignment: .top, spacing: GridConstants.gapItem) {
            markWell
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                words
                if let actionTitle, let action {
                    pill(actionTitle, action)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Room for the close glyph, which sits in the corner over it.
            .padding(.trailing, GridConstants.gapWide)
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
        .overlay(alignment: .topTrailing) { closeButton }
        .accessibilityElement(children: .contain)
    }

    private var markWell: some View {
        Group {
            if let drawn = UIImage(named: mark) {
                Image(uiImage: drawn)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "lightbulb.fill")
                    .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .regular)
            }
        }
        .foregroundStyle(AppColors.inkPrimary)
        .frame(width: Self.well, height: Self.well)
        .background(Circle().fill(AppColors.quietFill))
        .accessibilityHidden(true)
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
        .frame(maxWidth: .infinity, minHeight: Self.well, alignment: .leading)
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
        .padding(4)
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
