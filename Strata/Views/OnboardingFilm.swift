import SwiftUI
import AVFoundation
import AVKit

/// **The film, first** (the owner, 2026-10-08: "we should have the vertical
/// trailer in there"). Fifteen seconds of the launch film, cut on the beat,
/// full screen, once. Spec: `docs/superpowers/specs/2026-10-08-onboarding-rebuild-design.md`.
///
/// - **Skip from the first frame**, top right, as a plain word on glass: a
///   film nobody can leave is a wall (WCAG 2.2.2 asks for a stop on any motion
///   over five seconds).
/// - **Sound follows the silent switch** (`.ambient`): a phone on silent plays
///   it quietly to itself; a phone with the ringer on hears the music.
/// - **Reduce Motion: the still and Play**, never autoplay.
/// - It ends into the first page on its own.
struct OnboardingFilm: View {
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var playing = false
    @State private var ended: NSObjectProtocol?
    @State private var done = false

    static let film = Bundle.main.url(forResource: "OnboardingFilm", withExtension: "mp4")

    var body: some View {
        ZStack {
            Color(red: 0.969, green: 0.969, blue: 0.969).ignoresSafeArea()
            if let player, playing {
                FilmLayer(player: player)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else if let still = UIImage(named: "OnboardingFilmPoster.jpg") {
                Image(uiImage: still)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
            if !playing, reduceMotion {
                Button {
                    start()
                } label: {
                    Image(systemName: "play.fill")
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .semibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .frame(width: 64, height: 64)
                        .glassCircle(onPage: true)
                }
                .accessibilityLabel("Play the film")
            }
        }
        .overlay(alignment: .topTrailing) {
            // **A word, not a control** (the owner, 2026-10-08: "the skip
            // button i would prefer if it were cleaner"). Quiet ink on the
            // page, a 44pt target around it, no capsule.
            Button("Skip") { finish(skipped: true) }
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkTertiary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .padding(.trailing, GridConstants.horizontalPadding)
                .accessibilityHint("Goes straight to trying it")
        }
        .overlay(alignment: .bottom) {
            if reduceMotion && !playing {
                Button("Continue") { finish(skipped: true) }
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(minHeight: 44)
                    .padding(.bottom, GridConstants.gapWide)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Some Wins, a short film")
        .onAppear { if !reduceMotion { start() } }
        .onDisappear { stop() }
    }

    private func start() {
        guard player == nil, let url = Self.film else {
            if Self.film == nil { finish(skipped: false) }
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .pause
        ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                       object: p.currentItem, queue: .main) { _ in
            Task { @MainActor in finish(skipped: false) }
        }
        player = p
        withAnimation(GridConstants.crossFade) { playing = true }
        p.play()
        Analytics.shared.signal(.trailer, [.action(.played)])
    }

    private func stop() {
        player?.pause()
        if let ended { NotificationCenter.default.removeObserver(ended) }
        ended = nil
    }

    private func finish(skipped: Bool) {
        guard !done else { return }
        done = true
        Analytics.shared.signal(.trailer, [.action(skipped ? .skipped : .finished)])
        stop()
        onDone()
    }
}

/// The player as a layer, filling the screen edge to edge.
private struct FilmLayer: UIViewRepresentable {
    let player: AVPlayer

    final class Host: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Host {
        let view = Host()
        view.playerLayer.player = player
        // **Whole, never cropped.** The film is 9:16 and a phone is taller;
        // filling cut its lines at the sides ("Made for ADHD brains" lost
        // letters). Its ground is the page's own, so the bands above and
        // below it cannot be seen.
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = UIColor(red: 0.969, green: 0.969, blue: 0.969, alpha: 1)
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: Host, context: Context) {}
}
