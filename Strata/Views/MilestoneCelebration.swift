import SwiftUI

/// #86: Milestone celebration popup — category gradient modal, auto-dismiss 3s
/// Kahneman 2000: peak experiences anchor memory of the journey.

struct MilestoneCelebration: View {
    let milestone: Milestone
    let onDismiss: () -> Void

    @State private var showContent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Scrim
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Card
            VStack(spacing: 16) {
                // Tier icon
                Text(tierIcon)
                    .font(.system(size: 48))
                    .scaleEffect(showContent ? 1.0 : 0.3)

                // Title
                Text(milestone.title)
                    .font(Typography.brandHeader)
                    .foregroundStyle(.primary)

                // Description
                Text(milestone.description)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Tier badge
                Text(milestone.tier.rawValue.capitalized)
                    .font(Typography.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(tierColor, in: Capsule())
            }
            .padding(32)
            .frame(maxWidth: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(reduceMotion ? .none : GridConstants.elasticPop) {
                showContent = true
            }
            // #87: Milestone haptics + #88: Milestone sound
            HapticsEngine.reward()
            SoundEngine.milestoneJingle()
            // Auto-dismiss after 3s
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                withAnimation(GridConstants.crossFade) {
                    onDismiss()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone unlocked: \(milestone.title). \(milestone.description)")
        .accessibilityAddTraits(.isModal)
    }

    private var tierIcon: String {
        switch milestone.tier {
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .platinum: return "💎"
        case .legendary: return "⭐"
        }
    }

    private var tierColor: Color {
        switch milestone.tier {
        case .bronze: return Color(hex: 0xCD7F32)
        case .silver: return Color(hex: 0xC0C0C0)
        case .gold: return Color(hex: 0xFFD700)
        case .platinum: return Color(hex: 0xE5E4E2)
        case .legendary: return Color(hex: 0xFF6B35)
        }
    }
}
