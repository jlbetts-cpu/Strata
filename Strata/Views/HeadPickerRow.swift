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
            VStack(spacing: 6) {
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
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(isChosen ? AppColors.inkPrimary : .clear, lineWidth: 2)
                }
                .scaleEffect(isChosen ? 1 : 0.94)
                .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: isChosen)

                Text(entry.name)
                    .font(Typography.bodySmall)
                    .foregroundStyle(isChosen ? AppColors.inkPrimary : AppColors.inkQuiet)
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
