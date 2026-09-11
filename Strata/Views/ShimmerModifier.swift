import SwiftUI

/// What a thing that is still loading looks like.
///
/// **A breath, not a sweep.** This was a white highlight travelling diagonally
/// across every placeholder at 30fps, which is the effect every website used
/// in 2019 and the owner's note on it was exact: "too much going on, not
/// premium." A sweep is a moving object, and a moving object asks to be
/// watched — so a screen of them is a screen of things demanding attention
/// while claiming to be nothing yet.
///
/// A slow change in weight says the same thing and asks for nothing. It is
/// also most of a frame cheaper: one animated value instead of a gradient
/// re-solved every tick.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deep = false

    func body(content: Content) -> some View {
        content
            .overlay {
                // The app's own ink, so it belongs to whichever ground it is
                // standing on rather than being white on both.
                AppColors.slotInk
                    .opacity(reduceMotion ? 0.05 : (deep ? 0.09 : 0.03))
            }
            .animation(reduceMotion ? nil
                       : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                       value: deep)
            .onAppear { deep = true }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
