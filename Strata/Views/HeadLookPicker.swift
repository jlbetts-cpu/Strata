import SwiftUI
import UIKit

/// Choosing the look your head wears, in Profile.
///
/// **Your own head, four times**, the same way the camera shows your own
/// photograph four times: a named swatch would be a guess. Rendered small and
/// off the main actor from the head as it was made, so the swatches never
/// compound one look on top of another.
struct HeadLookPicker: View {
    let head: HeadRig
    let selection: FilmLook.Kind
    let onSelect: (FilmLook.Kind) -> Void

    /// A one-face head per look. Drawn with `HeadStill`, irises and all: the
    /// face image alone has its eyes painted white ready for drawn irises,
    /// and a row of heads with blank white eyes is not something to put in
    /// front of anybody.
    @State private var previews: [FilmLook.Kind: HeadRig] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let side: CGFloat = 60

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FilmLook.all) { look in
                swatch(look)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, GridConstants.gapTight)
        .task(id: ObjectIdentifier(head.face(.neutral).image)) { await makePreviews() }
    }

    private func swatch(_ look: FilmLook) -> some View {
        let isChosen = selection == look.kind
        let radius = GridConstants.blockCornerRadius(forCell: Self.side)
        // **A swatch waits for its own head rather than borrowing one.**
        //
        // It used to draw the undressed head under every label at 0.4 opacity
        // until the dressed previews landed: for that moment five different
        // looks were all showing the `none` look, dimmed by an alpha that is
        // not a token, and each then jumped to full as its own picture
        // arrived. `HeadPickerRow` sits one row under this in Profile and is
        // deliberately the same swatch; it already refuses this ("every other
        // one waits for its swatch rather than borrowing a face that is not
        // its own"), and it is right. The slot is what a slot looks like until
        // there is something true to put in it, which is what `quietFill` is
        // for everywhere else in the app.
        //
        // `none` never waits: its look IS the head as it was made, which is
        // already in memory.
        let undressed: HeadRig? = look.kind == .none ? head : nil
        let rig: HeadRig? = previews[look.kind] ?? undressed
        return Button {
            guard !isChosen else { return }
            HapticsEngine.tick()
            onSelect(look.kind)
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

                Text(look.kind.name)
                    .font(Typography.headerSmall)
                    // `inkSecondary`, not `inkQuiet`, for the same reason as
                    // `HeadPickerRow`'s name one row above: 6.19:1 where
                    // `inkQuiet` measured 3.3:1, and `inkQuiet` is the token for
                    // a hint rather than for a word somebody reads.
                    .foregroundStyle(isChosen ? AppColors.inkPrimary : AppColors.inkSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(look.kind.describedAs)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }

    private func makePreviews() async {
        let source = head
        let made = await Task.detached(priority: .userInitiated) { () -> [FilmLook.Kind: HeadRig] in
            // Neutral's picture and eyes only: its blink would be dressed five
            // times for a preview that never blinks.
            let neutral = source.face(.neutral)
            guard let neutralOnly = HeadRig(faces: [.neutral: HeadRig.Face(image: neutral.image, eyes: neutral.eyes)],
                                            contentHeight: source.contentHeight, chin: source.chin)
            else { return [:] }
            var out: [FilmLook.Kind: HeadRig] = [:]
            for look in FilmLook.all { out[look.kind] = neutralOnly.dressed(in: look) }
            return out
        }.value
        previews = made
    }
}
