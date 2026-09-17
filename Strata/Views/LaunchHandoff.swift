import SwiftUI

/// The launch screen, held for the first frame and then let go.
///
/// The launch screen is `UILaunchScreen` in Info.plist: `LaunchBlack` (the
/// camera's own ground, 0.031 in both appearances, because the app opens on
/// the camera and the camera is dark whatever the phone is set to) with the
/// icon's diagonal S centred on it. iOS removes that snapshot the instant the
/// first frame draws, so on its own the S would pop off.
///
/// This is the same S, at the same size (the same asset, so the same points),
/// centred in the same full-screen bounds, on the same black. Once the first
/// frame is up it lets go in two steps, with no hold between them: the S
/// fades out on the black while the black stays fully opaque, then the black
/// fades to reveal the camera (or onboarding, on the first launch ever). The
/// owner's order: the mark leaves before the app arrives, so the S never sits
/// half transparent over the camera's grid.
///
/// The S step eases in and the black step eases out, so the fade is fastest
/// at the handover and the join does not read as a pause.
///
/// It never delays anything: the app underneath is built and running from the
/// first frame, the camera starts on its own `.task`, and the overlay takes no
/// touches and is invisible to VoiceOver. It removes itself from the hierarchy
/// once the second fade completes, so it costs nothing afterwards.
///
/// Reduce Motion: both steps are opacity only and nothing moves or scales, so
/// it keeps the same order with shorter fades.
struct LaunchHandoff: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var markVisible = true
    @State private var groundVisible = true
    @State private var finished = false

    /// About 0.55s in total; about 0.3s under Reduce Motion.
    private var markFade: Animation { .easeIn(duration: reduceMotion ? 0.12 : 0.25) }
    private var groundFade: Animation { .easeOut(duration: reduceMotion ? 0.18 : 0.30) }

    var body: some View {
        if !finished {
            ZStack {
                Color("LaunchBlack")
                Image("LaunchS")
                    .opacity(markVisible ? 1 : 0)
            }
            .ignoresSafeArea()
            .opacity(groundVisible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear(perform: letGo)
        }
    }

    private func letGo() {
        // `onAppear` runs while the first frame is being built. Hopping the
        // main queue once starts the sequence after that frame is committed,
        // so the first thing on screen is the S exactly where the snapshot
        // had it.
        DispatchQueue.main.async {
            withAnimation(markFade) {
                markVisible = false
            } completion: {
                withAnimation(groundFade) {
                    groundVisible = false
                } completion: {
                    finished = true
                }
            }
        }
    }
}
