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
        return Button {
            guard !isChosen else { return }
            HapticsEngine.tick()
            onSelect(look.kind)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(AppColors.quietFill)
                    HeadStill(rig: previews[look.kind] ?? head, side: Self.side * 0.78)
                        .frame(width: Self.side, height: Self.side)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                        .opacity(previews[look.kind] == nil && look.kind != .none ? 0.4 : 1)
                }
                .frame(width: Self.side, height: Self.side)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(isChosen ? AppColors.inkPrimary : .clear, lineWidth: 2)
                }
                .scaleEffect(isChosen ? 1 : 0.94)
                .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: isChosen)

                Text(look.kind.name)
                    .font(Typography.caption)
                    .foregroundStyle(isChosen ? AppColors.inkPrimary : AppColors.inkQuiet)
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
            guard let neutralOnly = HeadRig(faces: [.neutral: source.face(.neutral)], shut: nil,
                                            contentHeight: source.contentHeight, chin: source.chin)
            else { return [:] }
            var out: [FilmLook.Kind: HeadRig] = [:]
            for look in FilmLook.all { out[look.kind] = neutralOnly.dressed(in: look) }
            return out
        }.value
        previews = made
    }
}
