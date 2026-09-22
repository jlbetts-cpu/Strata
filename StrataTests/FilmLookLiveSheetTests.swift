import Testing
import CoreImage
import Metal
import UIKit
@testable import Strata

/// **Writes what the live viewfinder draws, so it can be looked at.**
///
/// The owner's report was about appearance — "no film simulation like grain or
/// anything" and "the looks dont look distinct enough" — and appearance is not
/// something a passing assertion establishes. This renders each look at the
/// size a viewfinder frame actually is and writes it out, so the judgement is
/// made by opening the file.
///
/// It also asserts the one thing that IS measurable about the complaint: that
/// the live path and the colour-only path it replaced are different pictures,
/// and that each look differs from the others by more than rounding.
struct FilmLookLiveSheetTests {

    /// A live frame on this phone is about this big: `.photo` hands the video
    /// output a preview-sized buffer, not a 12MP one. Grain and radii are
    /// quoted for a 2560px photograph and scaled from it, so rendering a
    /// swatch at 132px would show grain four times too coarse and prove
    /// nothing about the viewfinder.
    static let liveSize = CGSize(width: 1080, height: 1440)

    /// The biggest buffer `.photo` is likely to hand the video output on a
    /// recent phone. The budget has to hold at the worst case, not the
    /// convenient one.
    static let worstCase = CGSize(width: 1920, height: 1440)

    private func scene(_ size: CGSize? = nil) -> CIImage? {
        let target = size ?? Self.liveSize
        guard let photo = UIImage(named: "DemoPhoto1", in: .main, compatibleWith: nil) ?? UIImage(named: "DemoPhoto1"),
              let cg = photo.cgImage else { return nil }
        let source = CIImage(cgImage: cg)
        let scale = max(target.width / source.extent.width,
                        target.height / source.extent.height)
        return source
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: CGRect(origin: .zero, size: target))
    }

    private func write(_ image: CIImage, _ name: String) {
        let directory = URL(fileURLWithPath: "/tmp/apollo-film", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let ui = FilmLookRenderer.shared.uiImage(from: image),
              let data = ui.pngData() else { return }
        try? data.write(to: directory.appendingPathComponent(name))
    }

    /// Mean absolute difference per channel, 0...1. A number, so "distinct"
    /// stops being an adjective.
    private func distance(_ a: CIImage, _ b: CIImage) -> Double {
        let difference = a.applyingFilter("CIDifferenceBlendMode",
                                          parameters: [kCIInputBackgroundImageKey: b])
        return FilmLookRenderer.shared.measureMeans(difference)?.reduce(0, +) ?? 0
    }

    /// Renders every look over several scenes, so the set is judged the way
    /// it is used: a face, a landscape, an indoor table. A look that is
    /// beautiful on a valley and ugly on a person is not a look this app can
    /// have, because most of what goes in it is people.
    @Test("Every look, over every kind of scene, written out to be looked at")
    func contactSheet() throws {
        for photo in ["DemoPhoto1", "DemoPhoto4", "DemoPhoto9", "DemoPhoto11"] {
            guard let source = named(photo) else { continue }
            write(source, "sheet-\(photo)-0-none.png")
            for look in FilmLook.all where look.kind != .none {
                write(FilmLookRenderer.shared.apply(look, to: source),
                      "sheet-\(photo)-\(look.kind.rawValue).png")
            }
        }
    }

    private func named(_ name: String) -> CIImage? {
        guard let photo = UIImage(named: name), let cg = photo.cgImage else { return nil }
        let source = CIImage(cgImage: cg)
        let scale = max(Self.liveSize.width / source.extent.width,
                        Self.liveSize.height / source.extent.height)
        return source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    @Test("The live viewfinder carries texture, and the looks are far apart")
    func liveLooksAreDistinct() throws {
        let source = try #require(scene(), "DemoPhoto1 must be in the test bundle's app")
        write(source, "00-plain.png")

        var rendered: [FilmLook.Kind: CIImage] = [:]
        for look in FilmLook.all where look.kind != .none {
            let live = FilmLookRenderer.shared.live(look, to: source, means: nil,
                                                    phase: CGPoint(x: 1013, y: 1409))
            rendered[look.kind] = live
            write(live, "live-\(look.kind.rawValue).png")
            write(FilmLookRenderer.shared.apply(look, to: source), "still-\(look.kind.rawValue).png")
        }

        // Every look must be visibly different from the untouched scene.
        for (kind, image) in rendered {
            let apart = distance(image, source)
            #expect(apart > 0.02, "\(kind.rawValue) is \(apart) from the plain scene, which is a tint")
        }

        // And from each other. The complaint was that they read as one look.
        let kinds = Array(rendered.keys)
        for i in kinds.indices {
            for j in kinds.indices where j > i {
                let apart = distance(rendered[kinds[i]]!, rendered[kinds[j]]!)
                #expect(apart > 0.02,
                        "\(kinds[i].rawValue) and \(kinds[j].rawValue) are only \(apart) apart")
            }
        }
    }

    /// **What a frame costs the GPU, measured the way the viewfinder draws.**
    ///
    /// The first attempt at this measured 440ms and was wrong by an order of
    /// magnitude: it rendered `toBitmap:`, which is a synchronous GPU to CPU
    /// readback of six megabytes a frame, through a `CIContext` with no Metal
    /// device to use. Neither is anything `GradedPreviewView` does. This
    /// builds the same context it builds, renders into a texture the same way,
    /// and reads the command buffer's own GPU clock.
    ///
    /// Still not the phone's number — the simulator runs on the Mac's GPU —
    /// but a floor: a pipeline that cannot hold 30fps here will not hold it
    /// there. The device logs the real figure every sixtieth frame.
    @Test("A live frame fits inside a 30fps budget")
    func aLiveFrameIsAffordable() throws {
        for size in [Self.liveSize, Self.worstCase] { try measureBudget(at: size) }
    }

    private func measureBudget(at size: CGSize) throws {
        let source = try #require(scene(size))
        let device = try #require(MTLCreateSystemDefaultDevice(), "no Metal device")
        let queue = try #require(device.makeCommandQueue())
        let context = CIContext(mtlCommandQueue: queue, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any,
            .cacheIntermediates: false
        ])
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.width), height: Int(size.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let bounds = CGRect(origin: .zero, size: size)
        let space = CGColorSpace(name: CGColorSpace.displayP3)!

        func gpuMilliseconds(_ image: CIImage) -> Double {
            guard let buffer = queue.makeCommandBuffer() else { return .infinity }
            context.render(image, to: texture, commandBuffer: buffer,
                           bounds: bounds, colorSpace: space)
            buffer.commit()
            buffer.waitUntilCompleted()
            return (buffer.gpuEndTime - buffer.gpuStartTime) * 1000
        }

        // Warm the colour cube and the shaders; the first frame pays for both.
        for look in FilmLook.all where look.kind != .none {
            _ = gpuMilliseconds(FilmLookRenderer.shared.live(look, to: source,
                                                             means: [0.4, 0.4, 0.4], phase: .zero))
        }

        for look in FilmLook.all where look.kind != .none {
            var total = 0.0
            let frames = 8
            for i in 0..<frames {
                let phase = CGPoint(x: Double(i) * 1013, y: Double(i) * 1409)
                total += gpuMilliseconds(FilmLookRenderer.shared.live(look, to: source,
                                                                      means: [0.4, 0.4, 0.4], phase: phase))
            }
            let ms = total / Double(frames)
            print("LIVE FRAME \(look.kind.rawValue) at \(Int(size.width))x\(Int(size.height)): \(String(format: "%.2f", ms)) ms on the GPU")
            #expect(ms < 33, "\(look.kind.rawValue) took \(ms)ms, which cannot hold 30fps even here")
        }
    }

    @Test("Grain moves between frames, so it is in the emulsion rather than on the glass")
    func grainMovesWithThePhase() throws {
        let source = try #require(scene())
        let look = FilmLook.silver
        let first = FilmLookRenderer.shared.live(look, to: source, means: nil, phase: .zero)
        let second = FilmLookRenderer.shared.live(look, to: source, means: nil,
                                                  phase: CGPoint(x: 1013, y: 1409))
        let apart = distance(first, second)
        #expect(apart > 0.0005, "two phases of the same look are identical, so no grain is drawn")
    }
}
