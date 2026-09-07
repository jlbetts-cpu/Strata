import SwiftUI

struct WelcomeView: View {
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Mini tower visual — blocks stacked like a growing structure
            VStack(spacing: GridConstants.spacing) {
                // Top (tapers)
                MiniBlockPreview(category: .creativity, blockSize: .small, title: "", showTitle: false)
                    .frame(width: 56, height: 56)
                    .offset(x: 4)

                // Middle row
                HStack(spacing: GridConstants.spacing) {
                    MiniBlockPreview(category: .focus, blockSize: .small, title: "", showTitle: false)
                        .frame(width: 56, height: 56)
                    MiniBlockPreview(category: .health, blockSize: .small, title: "", showTitle: false)
                        .frame(width: 56, height: 56)
                }

                // Foundation (widest)
                HStack(spacing: GridConstants.spacing) {
                    MiniBlockPreview(category: .social, blockSize: .small, title: "", showTitle: false)
                        .frame(width: 56, height: 56)
                    MiniBlockPreview(category: .mindfulness, blockSize: .medium, title: "", showTitle: false)
                        .frame(width: 120, height: 56)
                }
            }
            .scaleEffect(appeared ? 1.0 : 0.9)
            .opacity(appeared ? 1.0 : 0)
            .animation(reduceMotion ? .none : GridConstants.gentleReveal.delay(0.2), value: appeared)
            .padding(.bottom, 40)

            // Copy
            VStack(spacing: 8) {
                Group {
                    Text("Every win you log")
                    + Text("\nbecomes a block.")
                }
                .font(Typography.headerMedium)
                .foregroundStyle(Color.primary)

                Text("Stack enough and you've built something real.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .opacity(appeared ? 1.0 : 0)
            .animation(reduceMotion ? .none : GridConstants.gentleReveal.delay(0.4), value: appeared)

            Spacer()

            // CTA
            VStack(spacing: 16) {
                Button {
                    HapticsEngine.snap()
                    onDismiss()
                } label: {
                    Text("Start stacking")
                        .font(Typography.headerSmall)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.accentWarm, in: Capsule())
                }
                .accessibilityLabel("Start stacking")
                .accessibilityHint("Start your tower")

                Button {
                    HapticsEngine.tick()
                    onDismiss()
                } label: {
                    Text("skip")
                        .font(Typography.caption)
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Skip introduction")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
            .opacity(appeared ? 1.0 : 0)
            .animation(reduceMotion ? .none : GridConstants.gentleReveal.delay(0.6), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { WarmBackground().ignoresSafeArea() }
        .onAppear { appeared = true }
    }
}
