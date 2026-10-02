import SwiftUI

/// **A sheet's title-row control, in one place.**
///
/// `docs/consistency-audit.md` §1.4 counted eight sheets and six shapes of title
/// row, and the word "Done" in two inks across six of them. §3.4 has the table.
/// The three faults it names are all answered here rather than per sheet:
///
/// - **Two inks for one word.** Add, Plan and the plan line drew their confirm in
///   `AppColors.accentWarm`, measured rgb(28, 26, 24) on the built sheet;
///   Profile and Restore drew it in `AppColors.inkPrimary`, rgb(37, 36, 37). Nine
///   levels apart, which nobody can see and which is still two tokens for one
///   word. **`inkPrimary` wins**, and not for the audit's stated reason — it
///   claimed `accentWarm` is "a fixed warm black that does not invert", and that
///   is wrong: `accentWarm` carries a `userInterfaceStyle` branch and goes to a
///   warm near-white in the dark. It wins because the app is monochrome ink now
///   ("lets just do the basic"), `inkPrimary` is the token for ink, and
///   `accentWarm`'s remaining job is a ground and a brand near-black rather than
///   the ink on a control.
/// - **Three of six word buttons were under 44pt.** A bare `Text` in a toolbar
///   measured 68x36 off the accessibility tree, on the screen the owner had
///   already called "really easy to miss click". The box arrives with the
///   modifier, which is what stops the next sheet going without it.
/// - **Two type tiers.** `Typography.headerSmall`, 15, which is what Profile,
///   Settings, Plan and the plan line already were. Add's two words were the
///   system body size and stood visibly bigger than Profile's Done.
///
/// **The ink step is the thing that says which word is the button**, and it is
/// the part that does not come free. Where a sheet has two words, Cancel is
/// `.cancel` at `inkSecondary` and the confirm is `.confirm` at `inkPrimary`,
/// which is the step `AddWinSheet` settled. Where a sheet has only a confirm —
/// Profile, the plan line — the word is the same ink as the title beside it, and
/// §2.7 of the audit is still open on that: it is a question about `StrataTitle`,
/// not about this modifier, and it wants the owner's eye rather than a guess.
enum SheetActionRole {
    /// Done, Save, Add, and the ＋ that adds a line: what the sheet is for.
    case confirm
    /// Cancel, and anything that backs out. One step quieter, deliberately.
    case cancel
}

/// What the action is MADE of, which is the only thing that changes its size.
///
/// Both exist in the shipping app — Plan puts ＋ in the leading slot where Add a
/// win puts "Cancel" — so this carries both rather than leaving the glyph to be
/// sized by hand. `Typography.headerSmall` for a word;
/// `GridConstants.iconToolbar` through `iconSize` for a glyph, so the glyph grows
/// with the user's text size (`docs/consistency-audit.md` §1.15).
enum SheetActionMark {
    case word
    case glyph
}

private struct SheetActionStyle: ViewModifier {
    let role: SheetActionRole
    let mark: SheetActionMark

    /// **Read from the environment, not passed in.** `.disabled(true)` on the
    /// enclosing `Button` reaches here, so Add's "cannot save yet" state is one
    /// modifier at the call site rather than a ternary on a colour. CLAUDE.md's
    /// note that `.disabled(true)` does NOT drop a button from the accessibility
    /// tree is why this dims rather than hides.
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .modifier(SheetActionType(mark: mark))
            .foregroundStyle(ink)
            // **44, measured.** Not padding, and not a minimum on one axis: a
            // bare `Text` in a toolbar measured 68 by 36 and a bare glyph 35 by
            // 36. `minWidth` rather than `width`, because a word is allowed to be
            // wider than the box and must never be clipped by it.
            .frame(minWidth: SheetAction.target, minHeight: SheetAction.target)
            .contentShape(Rectangle())
    }

    private var ink: Color {
        guard isEnabled else { return AppColors.inkQuiet }
        switch role {
        case .confirm: return AppColors.inkPrimary
        case .cancel:  return AppColors.inkSecondary
        }
    }
}

/// Split out because `iconSize` is itself a modifier and a `switch` inside a
/// `body` that returns one opaque type cannot apply two different ones.
private struct SheetActionType: ViewModifier {
    let mark: SheetActionMark

    @ViewBuilder
    func body(content: Content) -> some View {
        switch mark {
        case .word:
            content
                .font(Typography.headerSmall)
                // **A sheet's word must never wrap, and this was a REGRESSION
                // this pass caused and then photographed** (2026-10-01).
                //
                // Extracting the three per-sheet copies into a `ViewModifier` put
                // the `Text` one layer further inside, and a toolbar item sizes
                // its content against what it is offered: on the built Add a win
                // sheet "Cancel" came back hyphenated across two lines, "Can-" /
                // "cel", where the same text drawn by the sheet itself had always
                // been one. Measured by looking at the render, not by reading the
                // source, which said nothing had changed.
                //
                // It is also the right rule on its own: at the largest text sizes
                // a toolbar word will wrap wherever it is declared, and a confirm
                // that reads "Can-cel" is worse than one that runs under the
                // title. `fixedSize` horizontally only, so a word may still grow
                // taller with Dynamic Type.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        case .glyph:
            content.iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
        }
    }
}

enum SheetAction {
    /// The HIG's minimum, measured not declared. Named once so a sheet cannot
    /// have its own copy of it, which is how three of six ended up without one.
    static let target: CGFloat = 44
}

extension View {
    /// Make this the confirm or the back-out action in a sheet's title row.
    ///
    /// Apply it to the `Button`'s LABEL, not to the `Button`: the press, the
    /// haptic and the action stay the caller's, and `.buttonStyle(.pressWord)`
    /// goes on the button as it does everywhere else in the app.
    func sheetAction(_ role: SheetActionRole = .confirm,
                     as mark: SheetActionMark = .word) -> some View {
        modifier(SheetActionStyle(role: role, mark: mark))
    }
}
