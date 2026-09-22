import Testing
import CoreImage
import CoreGraphics
import Metal
@testable import Strata

/// **Which way up Core Image renders into a Metal texture.**
///
/// The owner, on the first build with the graded viewfinder: "The camera for
/// some reason is a weird orientation." There are two candidates for that and
/// they are independent, so they have to be separated rather than guessed at:
/// the rotation of the camera's own buffers, and the handedness of
/// `CIContext.render(_:to:commandBuffer:bounds:colorSpace:)`.
///
/// The second one is testable without a camera, which is the whole point of
/// this file: Core Image works in a y-up coordinate system and a Metal texture
/// is addressed y-down, so whether the result arrives flipped is a fact about
/// the frameworks and not about the phone. The simulator has a Metal device
/// even though it has no lens, so this runs here and settles it with a number
/// instead of an opinion.
@Suite("Graded viewfinder orientation")
struct GradedViewfinderOrientationTests {

    /// A 2x2 image with ONE red pixel, in the top-left of the picture as a
    /// person looks at it. Everything else is black.
    private func markedImage() -> CIImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
                                  bytesPerRow: 8, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        // CGContext is y-up, so the TOP-left of the picture is y = 1.
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 1, width: 1, height: 1))
        guard let cg = ctx.makeImage() else { return nil }
        return CIImage(cgImage: cg)
    }

    /// **Measured on 2026-09-21: Core Image DOES flip.** The marked corner,
    /// which is the top of the picture, arrived in the BOTTOM row of the
    /// texture: top row red 0, bottom row red 255.
    ///
    /// That is the bug the owner saw. `GradedPreviewView` compensates with a
    /// vertical flip in drawable space, and this test asserts the underlying
    /// behaviour rather than the compensation, so that if an OS release ever
    /// changes the handedness this fails HERE, on a machine with no camera,
    /// instead of on his phone.
    @Test("Core Image flips vertically when rendering into a Metal texture")
    func metalRenderFlipsVertically() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            // No Metal here at all, which is a real configuration: the
            // viewfinder falls back to the plain preview and there is nothing
            // to assert about a render that never happens.
            return
        }
        let image = try #require(markedImage())
        let context = CIContext(mtlCommandQueue: queue, options: [.cacheIntermediates: false])

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 2, height: 2, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let buffer = try #require(queue.makeCommandBuffer())

        context.render(image, to: texture, commandBuffer: buffer,
                       bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        buffer.commit()
        buffer.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: 16)
        texture.getBytes(&bytes, bytesPerRow: 8,
                         from: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0)

        // bgra8: the red channel is byte 2 of each pixel. Texture row 0 is the
        // top row as the drawable is presented.
        let topLeftRed = bytes[2]
        let bottomLeftRed = bytes[8 + 2]

        // Recorded as an assertion rather than a comment so that if a future
        // OS changes the handedness, this fails here instead of on his phone.
        #expect(bottomLeftRed > 200,
                "the picture's TOP arrives in the texture's BOTTOM row: Core Image is y-up, the texture is y-down")
        #expect(topLeftRed < 60,
                "if the mark is at the top, Core Image has stopped flipping and GradedPreviewView's flip must go")
    }
}
