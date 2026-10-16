import SwiftUI

/// **Add to Tonight's Story** (the owner, 2026-10-15: the story selector is
/// "its own row in a different colour and a different spot"; the spec, 2).
///
/// Under the block, at the foot of Add a Win, the last decision on the page.
/// Off, an outline in the evening colour; on, filled, with the one line that
/// is the whole lesson under it. Off for every new win and never remembered:
/// unlike the crews, a story is a decision each time.
struct TonightsStoryRow: View {
    @Binding var isOn: Bool
    /// A photograph is on the win: under 16 it stays on the phone, and the
    /// row says so.
    var hasPhoto = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let word = "Add to Tonight's Story"
    static let onWord = "On Tonight's Story"
    static let lesson = "Your friends see it from 8pm. Gone by morning."
    static let teenLine = "Your friends see the block, not the photo."

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            Button {
                HapticsEngine.tick()
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { isOn.toggle() }
            } label: {
                HStack(spacing: GridConstants.gapTight) {
                    Image(systemName: isOn ? "sunset.fill" : "sunset")
                        .font(Typography.headerMedium)
                        .contentTransition(.symbolEffect(.replace))
                    Text(isOn ? Self.onWord : Self.word)
                        .font(Typography.headerSmall)
                        .lineLimit(1)
                }
                .foregroundStyle(isOn ? Color.white : AppColors.evening)
                .padding(.horizontal, GridConstants.gapWide)
                .frame(minHeight: 44)
                .background {
                    if isOn {
                        Capsule().fill(AppColors.eveningFill)
                    } else {
                        Capsule().strokeBorder(AppColors.evening, lineWidth: 1.5)
                    }
                }
                .contentShape(Capsule())
            }
            .buttonStyle(.press)
            .accessibilityLabel("Tonight's Story")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint(isOn ? "Takes the win off tonight's story." : "Your friends see it from 8pm.")
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            if isOn {
                VStack(spacing: 2) {
                    Text(Self.lesson)
                    if hasPhoto, !CrewAge.current.sendsPhotos { Text(Self.teenLine) }
                }
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
