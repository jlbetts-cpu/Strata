#if DEBUG
import AVFoundation
import SwiftUI
import UIKit

/// **A lens for the simulator, so the camera can be filmed.**
///
///     -strataFakeLens <path to a video>
///
/// The simulator has no capture device, so the camera tab is a dark ground
/// with chrome on it. With this flag a video plays, looping and muted, where
/// the preview would be, and the shutter takes the frame on screen at that
/// moment as the photograph. Everything after the shutter (the review, the
/// block, the tower) is the real path. Debug builds only; the launch film
/// (2026-10-07) is what it is for.
@MainActor
final class FakeLens {
    static let shared: FakeLens? = DebugHarness.argument("-strataFakeLens").map { FakeLens(path: $0) }

    let player: AVQueuePlayer
    private let looper: AVPlayerLooper

    private init(path: String) {
        let item = AVPlayerItem(url: URL(fileURLWithPath: path))
        player = AVQueuePlayer()
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    /// The frame on screen now, upright, as a photograph.
    func snapshot() -> UIImage? {
        guard let item = player.currentItem else { return nil }
        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let cg = try? generator.copyCGImage(at: player.currentTime(), actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// The fake lens drawn the way the real preview is: filling the viewfinder.
struct FakeLensView: UIViewRepresentable {
    let lens: FakeLens

    final class Host: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Host {
        let view = Host()
        view.playerLayer.player = lens.player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: Host, context: Context) {}
}
#endif
