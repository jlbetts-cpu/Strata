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
    /// Which film: the onboarding's, or Crews' first-visit film
    /// (`CrewsFilm`, 2026-10-08), played by this same player.
    var resource = "OnboardingFilm"
    var poster = "OnboardingFilmPoster.jpg"
    /// The onboarding film reports to `Analytics` as the trailer; others do not.
    var reports = true
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var playing = false
    @State private var ended: NSObjectProtocol?
    @State private var done = false
    /// The page's own colour rising over the film as it ends, in dark mode.
    @State private var dims = false
    @Environment(\.colorScheme) private var colorScheme

    private var film: URL? { Bundle.main.url(forResource: resource, withExtension: "mp4") }
    /// How long the dark page takes to rise over the film's last frame.
    static let darkHandoff: Double = 0.9

    var body: some View {
        ZStack {
            Color(red: 0.969, green: 0.969, blue: 0.969).ignoresSafeArea()
            if let player, playing {
                FilmLayer(player: player)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else if let still = UIImage(named: poster) {
                Image(uiImage: still)
                    .resizable()
                    .scaledToFill()
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
        // **Into the dark page through the dark page** (the owner,
        // 2026-10-08: "the transition from light to dark mode is a little
        // harsh"). The film is a picture of the app in light; on a phone in
        // dark mode its last frame cut straight to a charcoal page. Now the
        // page's own colour rises over the film first, slowly, and the pages
        // arrive on a ground that is already dark.
        .overlay {
            WarmBackground.top.ignoresSafeArea()
                .opacity(dims ? 1 : 0)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Some Wins, a short film")
        .onAppear { if !reduceMotion { start() } }
        .onDisappear { stop() }
    }

    private func start() {
        guard player == nil, let url = film else {
            if film == nil { finish(skipped: false) }
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
        if reports { Analytics.shared.signal(.trailer, [.action(.played)]) }
    }

    private func stop() {
        player?.pause()
        if let ended { NotificationCenter.default.removeObserver(ended) }
        ended = nil
    }

    private func finish(skipped: Bool) {
        guard !done else { return }
        done = true
        if reports { Analytics.shared.signal(.trailer, [.action(skipped ? .skipped : .finished)]) }
        guard colorScheme == .dark, !reduceMotion else {
            stop()
            onDone()
            return
        }
        withAnimation(GridConstants.filmHandoff) { dims = true }
        Task {
            try? await Task.sleep(for: .seconds(Self.darkHandoff))
            stop()
            onDone()
        }
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
        // **Filling, because the film is the phone's own shape now**
        // (2026-10-08). It was 9:16 shown whole on a 9:19.5 screen, and the
        // phone in its shots ran past the film's bottom edge, so on the
        // screen it was sliced by a hard line partway down, with a band
        // below (the owner: "a clear white cutoff on the bottom"). The film
        // is rendered at 1080 x 2340 now, its 9:16 composition centred and
        // its full-bleed grid grown to the height, so filling crops nothing
        // on a modern iPhone and only a sliver of empty page on any other.
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = UIColor(red: 0.969, green: 0.969, blue: 0.969, alpha: 1)
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: Host, context: Context) {}
}
