import SwiftUI

/// Your heads, in a row: the one in use marked, its name under it.
///
/// The owner, 2026-09-23: "I want it so you are able to save multiple heads,
/// like you are able to add your friend's head for instance to your tower
/// instead of yours. I feel like that would add a lot of flavor to an already
/// cool looking application."
///
/// **Deliberately the same shape as `HeadLookPicker`**, which sits one row
/// under it in Profile: the same square of `quietFill` at the block's own
/// corner, the same 2pt ink border on the one that is picked, the same caption
/// under it, the same step back for the ones that are not. Two ways of saying
/// "this one is chosen", ten points apart, would be two things to learn.
///
/// No shadow. A swatch is a picture of a head, not a head standing on
/// something (`CLAUDE.md`, and `docs/design-system-future.md` §6).
///
/// The name is language, so it is SF Rounded and not the drawn face
/// (`design-system-future.md` §2: never set a label in Jaro).
struct HeadPickerRow: View {
    let entries: [HeadStore.Entry]
    let activeID: UUID?
    /// One neutral face per head, read off the main actor by
    /// `HeadStore.swatches()`. A head missing from here has not landed yet.
    let swatches: [UUID: HeadRig]
    /// The active head, which is already in memory, so the one that matters
    /// most is drawn before any reading happens.
    let active: HeadRig?
    let onPick: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `HeadLookPicker`'s swatch, to the point.
    private static let side: CGFloat = 60

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // **No "+" tile.** Adding is the labelled row under the switches,
            // and one action with two affordances ten points apart is two
            // things to learn for one thing to do. The row is also reachable
            // without scrolling once there are four heads.
            HStack(alignment: .top, spacing: GridConstants.gapItem) {
                ForEach(entries) { tile($0) }
            }
            .padding(.vertical, GridConstants.gapTight)
        }
    }

    private func tile(_ entry: HeadStore.Entry) -> some View {
        let isChosen = entry.id == activeID
        let radius = GridConstants.blockCornerRadius(forCell: Self.side)
        // The active head comes from memory; every other one waits for its
        // swatch rather than borrowing a face that is not its own.
        let rig = swatches[entry.id] ?? (isChosen ? active : nil)
        return Button {
            guard !isChosen else { return }
            HapticsEngine.tick()
            onPick(entry.id)
        } label: {
            // `gapTight`, not a loose 6. Six is not a rung of the spacing
            // ladder (8 / 12 / 16 / 24 / 32) and it was the only value on
            // either picker that was not, which is the fifth value check 7
            // fails a screen for.
            VStack(spacing: GridConstants.gapTight) {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(AppColors.quietFill)
                    if let rig {
                        HeadStill(rig: rig, side: Self.side * 0.78)
                            .frame(width: Self.side, height: Self.side)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
                }
                .frame(width: Self.side, height: Self.side)
                .overlay {
                    // **0.55 ink, not full strength, and the system's own
                    // stroke width.** `AddWinSheet` settled what a selection
                    // ring is on 2026-10-01: "a full-strength `inkPrimary` ring
                    // is a hard black outline floating off the thing it selects,
                    // the only pure ink ring in the app". These two pickers were
                    // the last places still drawing one, and they draw it around
                    // a photograph of somebody's face, where a hard black
                    // outline reads as a cut-out rather than as a choice.
                    //
                    // It can go quieter here than anywhere else, because this
                    // swatch says "chosen" three times over: the ring, the step
                    // up from 0.94 to full size, and the name under it going
                    // from secondary ink to primary. The ring is the loudest of
                    // the three and it is the one that did not need to be.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(AppColors.inkPrimary.opacity(isChosen ? 0.55 : 0),
                                      lineWidth: GridConstants.strokeMedium)
                }
                .scaleEffect(isChosen ? 1 : 0.94)
                .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: isChosen)

                Text(entry.name)
                    .font(Typography.bodySmall)
                    // **`inkSecondary` for the ones not chosen, not
                    // `inkQuiet`.** A head's name is text somebody reads, and
                    // `inkQuiet` says in its own doc that it is held to 3:1
                    // rather than 4.5:1 because it is for chevrons, placeholders
                    // and hints. Measured on the built sheet, `inkQuiet`
                    // composites to (136, 136, 136) on a white card, 3.3:1;
                    // `inkSecondary` lands at (97, 97, 97), 6.19:1. The step
                    // down from the chosen name is still plain, 15.1:1 against
                    // 6.19:1, and it is now a step between two legible inks
                    // rather than one into a grey the audit would fail.
                    .foregroundStyle(isChosen ? AppColors.inkPrimary : AppColors.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // A little wider than the square, so a name of two or
                    // three words is cut rather than pushing its neighbour.
                    .frame(width: Self.side + GridConstants.gapItem)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // **The name, and the trait says the rest.** This read
        // "\(entry.name), in use" AND carried `.isSelected`, which VoiceOver
        // already speaks as "selected": the same fact twice inside one
        // element, and `HeadLookPicker` beside it does not do it. The words go
        // rather than the trait, because a trait is also what an assistive
        // technology can act on instead of only read out.
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }
}
