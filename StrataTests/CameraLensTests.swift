import Testing
import UIKit
@testable import Strata

/// The camera's rubric, the lines a machine with no camera can hold
/// (`docs/camera.md`, 1 to 4). The rest need a real phone.
@Suite("Camera: lenses, and which way up")
@MainActor
struct CameraLensTests {
    // Rubric 1.
    @Test("a phone with 0.5x, 1x and 3x offers exactly those, by those names")
    func threeLenses() {
        // A triple camera: 1x sits at factor 2, the telephoto at 6.
        let stops = CameraLenses.stops(base: 2, switchovers: [2, 6], maxFactor: 16)
        #expect(stops == [1, 2, 6])
        #expect(stops.map { CameraLenses.label(forDeviceFactor: $0, base: 2) } == ["0.5x", "1x", "3x"])
        #expect(stops.map { CameraLenses.shortLabel(forDeviceFactor: $0, base: 2) } == [".5", "1", "3"])
        // With a main camera that has a true 2x in it: Apple's four.
        let four = CameraLenses.stops(base: 2, switchovers: [2, 6], maxFactor: 16, crop: true)
        #expect(four.map { CameraLenses.shortLabel(forDeviceFactor: $0, base: 2) } == [".5", "1", "2", "3"])
        // Two lenses and the crop: .5, 1, 2.
        let two = CameraLenses.stops(base: 2, switchovers: [2], maxFactor: 16, crop: true)
        #expect(two.map { CameraLenses.shortLabel(forDeviceFactor: $0, base: 2) } == [".5", "1", "2"])
        // A real 2x lens is not offered twice.
        let tele = CameraLenses.stops(base: 1, switchovers: [2], maxFactor: 8, crop: true)
        #expect(tele == [1, 2])
        // One lens, no crop: one stop, and the row is not drawn.
        #expect(CameraLenses.stops(base: 1, switchovers: [], maxFactor: 8) == [1])
        // A stop the lens cannot reach is not offered.
        #expect(CameraLenses.stops(base: 2, switchovers: [2, 10], maxFactor: 8, crop: true) == [1, 2, 4])
    }

    // Rubric 2.
    @Test("a zoom never goes wider than the widest lens or past the limit")
    func clamp() {
        for raw in stride(from: -2.0, through: 40.0, by: 0.37) {
            let held = CameraLenses.clamped(CGFloat(raw), max: 16)
            #expect(held >= 1 && held <= 16)
        }
        #expect(CameraLenses.clamped(0.2, max: 16) == 1)
        #expect(CameraLenses.clamped(99, max: 16) == 16)
        // A camera that cannot zoom stays where it is.
        #expect(CameraLenses.clamped(3, max: 0.5) == 1)
        let service = SourceSweep.code((try? SourceSweep.read("Strata/Services/CameraService.swift")) ?? "")
        #expect(service.components(separatedBy: "CameraLenses.clamped(factor, max: maxZoom)").count == 3)
    }

    // Rubric 3.
    @Test("any lens is one press from any other, and the one in use is marked")
    func onePress() throws {
        let stops: [CGFloat] = [1, 2, 4, 6]
        #expect(CameraLenses.chosen(for: 2, in: stops) == 2)
        // Mid pinch it is the lens doing the work.
        #expect(CameraLenses.chosen(for: 2.8, in: stops) == 2)
        #expect(CameraLenses.chosen(for: 5.99, in: stops) == 6)
        #expect(CameraLenses.chosen(for: 9, in: stops) == 6)
        #expect(CameraLenses.chosen(for: 1, in: stops) == 1)
        let view = SourceSweep.code(try SourceSweep.read("Strata/Views/CameraView.swift"))
        // Every stop is its own button that goes straight there.
        #expect(view.contains("ForEach(lenses.stops, id: \\.self) { stop in"))
        #expect(view.contains("camera.glide(to: stop)"))
        // The pill that cycled is gone.
        let lenses = SourceSweep.code(try SourceSweep.read("Strata/Services/CameraLenses.swift"))
        #expect(!lenses.contains("func stop(after"))
    }

    // Rubric 4.
    @Test("a photo held any of the eight ways comes out the right way up through the app's steps")
    func eightWays() throws {
        // 40 by 20: red top left, green top right, blue bottom left, white bottom right.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let base = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20), format: format).image { c in
            let quarters: [(UIColor, CGRect)] = [(.red, CGRect(x: 0, y: 0, width: 20, height: 10)),
                                                 (.green, CGRect(x: 20, y: 0, width: 20, height: 10)),
                                                 (.blue, CGRect(x: 0, y: 10, width: 20, height: 10)),
                                                 (.white, CGRect(x: 20, y: 10, width: 20, height: 10))]
            for (colour, rect) in quarters { colour.setFill(); c.fill(rect) }
        }
        let cg = try #require(base.cgImage)
        func corners(_ image: UIImage) -> [String] {
            let w = Int(image.size.width), h = Int(image.size.height)
            var bytes = [UInt8](repeating: 0, count: w * h * 4)
            let context = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            UIGraphicsPushContext(context)
            context.translateBy(x: 0, y: CGFloat(h)); context.scaleBy(x: 1, y: -1)
            image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            UIGraphicsPopContext()
            func name(_ x: Int, _ y: Int) -> String {
                let i = (y * w + x) * 4
                let (r, g, b) = (bytes[i] > 128, bytes[i + 1] > 128, bytes[i + 2] > 128)
                return r && g && b ? "white" : r ? "red" : g ? "green" : b ? "blue" : "black"
            }
            return [name(w / 4, h / 4), name(3 * w / 4, h / 4), name(w / 4, 3 * h / 4), name(3 * w / 4, 3 * h / 4)]
        }
        // What each way up looks like, top left first, worked out by hand.
        let expected: [(UIImage.Orientation, [String])] = [
            (.up, ["red", "green", "blue", "white"]),
            (.down, ["white", "blue", "green", "red"]),
            (.upMirrored, ["green", "red", "white", "blue"]),
            (.downMirrored, ["blue", "white", "red", "green"]),
        ]
        for (orientation, colours) in expected {
            let held = UIImage(cgImage: cg, scale: 1, orientation: orientation)
            let kept = ImageManager.resizeIfNeeded(PortraitPolish.apply(to: held), maxDimension: 2560)
            #expect(kept.imageOrientation == .up, "\(orientation.rawValue)")
            #expect(kept.size == CGSize(width: 40, height: 20))
            #expect(corners(kept) == colours, "\(orientation.rawValue)")
        }
        // The four quarter turns: stood on end, upright, and each agrees
        // with what the system itself draws for that photo.
        var seen: Set<[String]> = []
        for orientation in [UIImage.Orientation.left, .right, .leftMirrored, .rightMirrored] {
            let held = UIImage(cgImage: cg, scale: 1, orientation: orientation)
            let kept = ImageManager.resizeIfNeeded(PortraitPolish.apply(to: held), maxDimension: 2560)
            #expect(kept.imageOrientation == .up)
            #expect(kept.size == CGSize(width: 20, height: 40))
            #expect(corners(kept) == corners(held), "\(orientation.rawValue)")
            seen.insert(corners(kept))
        }
        // Four different pictures, not one drawn four times.
        #expect(seen.count == 4)
        // And the cut to the viewfinder's shape keeps the same way up.
        let sideways = UIImage(cgImage: cg, scale: 1, orientation: .right)
        let cut = PortraitPolish.cropped(sideways, toAspect: 1)
        #expect(cut.size == CGSize(width: 20, height: 20))
        #expect(Set(corners(cut)) == Set(corners(sideways)))
    }

    @Test("the photograph, the viewfinder and the live frames ask one kept coordinator")
    func oneCoordinator() throws {
        let service = SourceSweep.code(try SourceSweep.read("Strata/Services/CameraService.swift"))
        // Kept, and watched.
        #expect(service.contains("private var rotation: AVCaptureDevice.RotationCoordinator?"))
        #expect(service.contains("coordinator.observe(\\.videoRotationAngleForHorizonLevelPreview"))
        // The photograph is told at the moment it is taken.
        #expect(service.contains("rotation?.videoRotationAngleForHorizonLevelCapture"))
        // A tap to focus lets go when the picture changes.
        #expect(service.contains("device.isSubjectAreaChangeMonitoringEnabled = true"))
        #expect(service.contains("AVCaptureDevice.subjectAreaDidChangeNotification"))
        let view = SourceSweep.code(try SourceSweep.read("Strata/Views/CameraView.swift"))
        #expect(view.contains("CameraPreview(session: camera.session, box: previewBox, camera: camera)"))
        // The volume buttons are the shutter's own press.
        #expect(view.contains(".onCameraCaptureEvent(isEnabled: review == nil && !camera.isDenied)"))
        // The head maker keeps the angles it was tuned with on a phone.
        let maker = SourceSweep.code(try SourceSweep.read("Strata/Views/HeadMakerView.swift"))
        #expect(maker.contains("CameraPreview(session: model.camera.session, box: previewBox)"))
    }

    @Test("the flash has three states and a bolt for each")
    func flash() {
        #expect(CameraView.flashSymbol(.off) == "bolt.slash.fill")
        #expect(CameraView.flashSymbol(.auto) == "bolt.badge.automatic.fill")
        #expect(CameraView.flashSymbol(.on) == "bolt.fill")
        for symbol in [CameraService.Flash.off, .auto, .on].map(CameraView.flashSymbol) {
            #expect(UIImage(systemName: symbol) != nil, "\(symbol)")
        }
        // With no lamp to ask (here, and the front camera) it is off and on.
        let camera = CameraService()
        camera.cycleFlash()
        #expect(camera.flash == .on && camera.isFlashOn)
        camera.cycleFlash()
        #expect(camera.flash == .off)
        // The head maker's switch still works through the old name.
        camera.isFlashOn = true
        #expect(camera.flash == .on)
    }
}
