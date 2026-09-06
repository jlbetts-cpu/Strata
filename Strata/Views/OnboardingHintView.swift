import SwiftUI

struct OnboardingHintView: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .iconSize(10, relativeTo: .caption, weight: .medium)
            }
            Text(text)
                .font(Typography.caption)
        }
        .foregroundStyle(Color.primary.opacity(0.8))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .allowsHitTesting(false)
    }
}
