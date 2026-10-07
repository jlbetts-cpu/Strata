import Testing
import UIKit
@testable import Strata

/// **The strip as a Story, at the angle you choose** (the owner, 2026-10-07:
/// "share it at different angles like you can actually rotate it", with the
/// pick "9:16 Stories strip"; the mark only on the strip's foot; a day with
/// no photograph or doodle opens no booth).
@Suite("Strip story")
@MainActor
struct StripStoryTests {
    private func picture(_ colour: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            colour.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    @Test("the picture is the posed strip on clear, trimmed, large enough to look into")
    func transparentPNG() throws {
        let frames = [PhotoStrip.Frame(id: UUID(), title: "Went outside", size: .small, picture: picture(.systemGreen)),
                      PhotoStrip.Frame(id: UUID(), title: "Read", size: .medium, picture: picture(.systemBlue))]
        let strip = PhotoStrip(owner: .me, day: "2026-10-07", candidates: frames, signature: "Jayden")
        for pose in [StripStoryPose(), StripStoryPose(yaw: 40, pitch: -30, roll: 25, scale: 1.5)] {
            let data = try #require(StripStory(strip: strip, frames: frames, day: strip.day, paper: .white,
                                               decor: nil, pose: pose).png())
            let image = try #require(UIImage(data: data)?.cgImage)
            // Clear where nothing is drawn: the top left corner is outside a
            // turned strip's paper (no shadow anywhere, his call).
            let alpha = try #require(Self.alpha(at: (0, 0), in: image))
            #expect(alpha == 0, "the background is transparent")
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst)
            // Trimmed: no wide clear canvas around it, and the strip is at
            // least its 220pt across at 5x.
            let side = StripStory.stripWidth * StripStory.exportScale
            #expect(CGFloat(image.width) >= side * 0.7)
            #expect(CGFloat(image.width) < side * 2.2, "trimmed to the strip")
        }
    }

    private static func alpha(at point: (Int, Int), in image: CGImage) -> UInt8? {
        var pixel: UInt8 = 0
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: -point.0, y: -(image.height - 1 - point.1),
                                       width: image.width, height: image.height))
        return pixel
    }

    @Test("a turn stops before the strip goes edge-on or leaves the card")
    func clamped() {
        let far = StripStoryPose(yaw: 200, pitch: -90, roll: 400, scale: 9).clamped()
        #expect(far.yaw == StripStoryPose.yawReach)
        #expect(far.pitch == -StripStoryPose.pitchReach)
        #expect(far.scale == StripStoryPose.scaleRange.upperBound)
        #expect(far.roll == 400, "a twist is a twist: any angle is still a strip")
        #expect(StripStoryPose().clamped() == StripStoryPose(), "the resting pose is inside its own limits")
    }

    @Test("Share opens the pose; nothing adds a mark of its own; saves keep their clear")
    func wired() throws {
        let booth = SourceSweep.code(try SourceSweep.read("Strata/Views/Strip/StripBooth.swift"))
        #expect(booth.contains("StripStoryComposer(strip: strip, frames: frames, day: day, paper: paper, decor: decor)"))
        #expect(booth.contains("telling = true"))
        #expect(booth.contains("TurningCard(yaw: turnYaw, pitch: turnPitch"), "turned and lit by the drawn angle")
        #expect(!booth.contains("Shadow("), "no shadow under the strip (his call: it made the booth \"super cramped\")")
        #expect(booth.contains("PhotoLibrarySaver.savePNG(data)"), "saved on clear, not re-encoded flat")
        let story = SourceSweep.code(try SourceSweep.read("Strata/Views/Strip/StripStory.swift"))
        #expect(!story.contains("Wordmark("), "the strip's own foot is the only mark (his pick)")
        #expect(!story.contains("Shadow("), "no shadow on the pose or its PNG (his call)")
    }

    @Test("reaching the goal opens the booth only with something to print")
    func emptyDayOpensNothing() throws {
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("guard await !PhotoStrip.mine(day: today, context: modelContext, small: true).candidates.isEmpty"))
    }
}
