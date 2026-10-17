import ImageIO
import SwiftUI
import UIKit

/// A friend's photograph on a crew block, read from the crew's cache.
///
/// Decoded once, off the main actor, at the size it is drawn and no larger,
/// and kept in a small cache so a block that falls, lands and dances is not
/// decoded three times. The block's own colour shows until it arrives, as it
/// does for your own photographs.
struct CrewPhotoView: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat
    var crop: CGPoint = .zero
    /// Told once the picture is on screen (the stories standard, rule 6: a
    /// story's timer waits for it).
    var shown: (() -> Void)? = nil

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                let shift = CachedImageView.shift(crop: crop, photo: image.size, frame: CGSize(width: width, height: height))
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .offset(x: shift.width, y: shift.height)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(reduceMotion ? .identity : .opacity.animation(GridConstants.imageFadeIn))
            }
        }
        .frame(width: width, height: height)
        // **By the size it is drawn at, too** (the owner, 2026-10-16: "other
        // people's banners come out blurry"): keyed by the url alone, a view
        // first laid out at no size decoded a few pixels and kept them when it
        // grew. Under a point it waits.
        .task(id: "\(url.path)@\(Int(max(width, height) * displayScale))") {
            guard max(width, height) >= 1 else { return }
            let side = max(width, height) * displayScale
            if let cached = Self.cache.object(forKey: Self.key(url, side)) { image = cached; shown?(); return }
            let decoded = await Self.decode(url, side: side)
            if let decoded { Self.cache.setObject(decoded, forKey: Self.key(url, side)) }
            image = decoded
            if decoded != nil { shown?() }
        }
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        return cache
    }()

    /// **Ready before it is reached** (the stories standard, rule 7; a:
    /// Meta's adjacent preload, 2026): decoded into the cache at the size a
    /// view of `width` by `height` will ask for, so it shows at once.
    static func prefetch(_ url: URL, width: CGFloat, height: CGFloat, scale: CGFloat) async {
        let side = max(width, height) * scale
        guard side >= 1, cache.object(forKey: key(url, side)) == nil,
              let decoded = await decode(url, side: side) else { return }
        cache.setObject(decoded, forKey: key(url, side))
    }

    private static func key(_ url: URL, _ side: CGFloat) -> NSString {
        "\(url.path)@\(Int(side))" as NSString
    }

    nonisolated private static func decode(_ url: URL, side: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: side,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
        }.value
    }
}
