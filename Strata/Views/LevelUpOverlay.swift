import SwiftUI

struct LevelUpOverlay: View {
    let level: Int
    let title: String
    let onDismiss: () -> Void

    @State private var ringScale: CGFloat = 0.3
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            AppColors.warmBlack.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 20) {
                // Shockwave ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accentWarm, AppColors.accentPurple, AppColors.accentWarm],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(ringScale)
                    .opacity(2.0 - Double(ringScale))

                VStack(spacing: 8) {
                    Text("LEVEL UP")
                        .font(Typography.caption)
                        .fontWeight(.black)
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.7))

                    Text("\(level)")
                        .font(Font.custom("FamiljenGrotesk-Medium", size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accentWarm, AppColors.accentPurple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(title)
                        .font(Typography.headerLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .opacity(textOpacity)

                Text("Tap to continue")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            // Shockwave
            withAnimation(.easeOut(duration: 0.8)) {
                ringScale = 1.5
            }

            // Text fade in
            withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }

            // Haptic pattern
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                generator.impactOccurred(intensity: 0.7)
                try? await Task.sleep(for: .milliseconds(100))
                generator.impactOccurred(intensity: 0.5)
                try? await Task.sleep(for: .milliseconds(150))
                generator.impactOccurred(intensity: 1.0)
            }
        }
    }
}
