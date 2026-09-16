#if DEBUG
import SwiftUI

/// **`-strataHeadParity`: the creator's head and a made head, side by side,
/// living the same life** (`docs`: the head-parity plan, §6.2).
///
/// Every head sits on a flat key-green square so a recording can be keyed
/// frame by frame, and every head logs under `-strataHeadTrace` with its own
/// id: `creator` (the owner's head), `made` (the seeded made head),
/// `reduced` (the same head with only neutral and shut, which shows the
/// fallbacks), and `calm` (a map marker's life at the map marker's size).
struct HeadParityView: View {
    private static let key = Color(red: 0, green: 0.694, blue: 0.251)
    private static let big: CGFloat = 152

    private var made: HeadRig? { HeadStore.shared.head ?? HeadRig.creator() }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                square(Self.big) {
                    CreatorHead(side: Self.big, greets: false, lookTarget: CGPoint(x: -0.8, y: -0.8), traceID: "creator")
                }
                square(Self.big) {
                    if let made {
                        LivingHeadView(rig: made, side: Self.big, liveliness: .expressive, traceID: "made")
                    }
                }
            }
            HStack(spacing: 12) {
                square(Self.big) {
                    if let reduced = made.flatMap(Self.reduced) {
                        LivingHeadView(rig: reduced, side: Self.big, liveliness: .expressive, traceID: "reduced")
                    }
                }
                square(Self.big) {
                    if let made {
                        LivingHeadView(rig: made, side: 52, liveliness: .calm, traceID: "calm")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func square<Content: View>(_ side: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack { content() }
            .frame(width: side + 24, height: side + 24)
            .background(Self.key)
    }

    /// The same head with nothing but its neutral face and its blink.
    static func reduced(_ rig: HeadRig) -> HeadRig? {
        guard let neutral = rig.faces[.neutral] else { return nil }
        return HeadRig(faces: [.neutral: neutral], shut: rig.shut,
                       contentHeight: rig.contentHeight, chin: rig.chin)
    }
}
#endif
