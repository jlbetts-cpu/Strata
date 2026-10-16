import SwiftUI
import UIKit
import Vision

/// **Where a head's eyebrows are**, as shares of its photograph: each brow's
/// middle and half size. Read once per photograph with Vision's face
/// landmarks; until then, or when Vision finds no face, placed above the eyes
/// the photograph already knows (`HeadRig.Eye`).
nonisolated struct BrowSpots: Equatable, Sendable {
    /// x, y, half width, half height, each a share of the photograph.
    var left: SIMD4<Double>
    var right: SIMD4<Double>

    /// Above the eyes: a brow sits about two and a half eye half-widths above
    /// the eye's middle, a little wider than the eye.
    static func above(_ eyes: [HeadRig.Eye]) -> BrowSpots? {
        guard eyes.count >= 2 else { return nil }
        let sorted = eyes.sorted { $0.x < $1.x }
        func spot(_ e: HeadRig.Eye) -> SIMD4<Double> {
            let rx = Double(e.rx)
            return SIMD4(Double(e.x), Double(e.y) - rx * 2.3, rx * 1.9, rx * 1.4)
        }
        return BrowSpots(left: spot(sorted[0]), right: spot(sorted[sorted.count - 1]))
    }

    /// From Vision's landmarks, in the photograph's own shares (y down).
    static func found(in image: CGImage) -> BrowSpots? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil,
              let face = request.results?.first,
              let landmarks = face.landmarks,
              let l = landmarks.leftEyebrow, let r = landmarks.rightEyebrow,
              let le = landmarks.leftEye, let re = landmarks.rightEye else { return nil }
        let box = face.boundingBox
        func points(_ region: VNFaceLandmarkRegion2D) -> [CGPoint] {
            region.normalizedPoints.map {
                CGPoint(x: box.minX + $0.x * box.width, y: 1 - (box.minY + $0.y * box.height))
            }
        }
        func spot(_ brow: [CGPoint], eye: [CGPoint]) -> SIMD4<Double>? {
            guard let minX = brow.map(\.x).min(), let maxX = brow.map(\.x).max(),
                  let eyeTop = eye.map(\.y).min(), !brow.isEmpty else { return nil }
            let midY = brow.map(\.y).reduce(0, +) / CGFloat(brow.count)
            let halfW = (maxX - minX) / 2
            // Down to just above the lid: the skin between moves with the brow.
            let halfH = max((eyeTop - midY) * 0.9, halfW * 0.45)
            return SIMD4(Double((minX + maxX) / 2), Double(midY), Double(halfW * 1.15), Double(halfH))
        }
        // Vision's left and right are the person's; on screen, the person's
        // right brow is on the left.
        guard let a = spot(points(l), eye: points(le)), let b = spot(points(r), eye: points(re)) else { return nil }
        return a.x < b.x ? BrowSpots(left: a, right: b) : BrowSpots(left: b, right: a)
    }

    @MainActor private static var cache: [ObjectIdentifier: BrowSpots] = [:]

    /// The spots for a photograph, Vision's when it has been read.
    @MainActor static func cached(_ image: UIImage) -> BrowSpots? { cache[ObjectIdentifier(image)] }

    @MainActor static func read(_ image: UIImage) async {
        let key = ObjectIdentifier(image)
        guard cache[key] == nil, let cg = image.cgImage else { return }
        let spots = await Task.detached(priority: .utility) { BrowSpots.found(in: cg) }.value
        if let spots { cache[key] = spots }
    }
}

/// The eyebrows' pose: each brow's lift and the inner ends' drop.
nonisolated struct BrowPose: Equatable, Sendable {
    var left: Double = 0
    var right: Double = 0
    var knit: Double = 0
    static let rest = BrowPose()
}

/// **The brows moved on the photograph** (`browWarp` in `BrowWarp.metal`),
/// animatable so a spring carries them.
struct BrowWarpEffect: ViewModifier, Animatable {
    var pose: BrowPose
    let spots: BrowSpots?
    let canvas: CGFloat

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(pose.left, AnimatablePair(pose.right, pose.knit)) }
        set { pose = BrowPose(left: newValue.first, right: newValue.second.first, knit: newValue.second.second) }
    }

    func body(content: Content) -> some View {
        if let spots, pose != .rest {
            let c = Double(canvas)
            let l = spots.left * c, r = spots.right * c
            let reach = max(abs(pose.left), abs(pose.right)) * c + abs(pose.knit) * c * 1.3
            content.distortionEffect(
                ShaderLibrary.browWarp(
                    .float4(Float(l.x), Float(l.y), Float(l.z), Float(l.w)),
                    .float4(Float(r.x), Float(r.y), Float(r.z), Float(r.w)),
                    .float4(Float(pose.left * c), Float(pose.knit * c), Float(pose.right * c), Float(pose.knit * c))),
                maxSampleOffset: CGSize(width: 0, height: reach + 1))
        } else {
            content
        }
    }
}
