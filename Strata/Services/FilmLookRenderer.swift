import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Puts a `FilmLook` on a photograph.
///
/// **The colour is one lookup, the texture is filters.** Everything in
/// `FilmLook.graded(_:)` depends only on a pixel's own colour, so it is baked
/// once into a 3D colour table and applied in a single pass however big the
/// photograph is. Only the things that depend on a pixel's NEIGHBOURS —
/// halation, bloom, glow, local contrast, grain, the shadow lift, the
/// vignette — are separate filters.
///
/// `nonisolated` and shared: a `CIContext` is expensive to make and safe to
/// share, and this runs off the main actor when a photograph is kept.
nonisolated final class FilmLookRenderer: @unchecked Sendable {
    static let shared = FilmLookRenderer()

    /// **Wide colour, and floats.** An iPhone photograph is Display P3, which
    /// holds about a quarter more colour than sRGB. Working in sRGB would clip
    /// those colours before the look even ran, and working in bytes would band
    /// the smooth skies the glow is there to protect.
    private let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any,
        .workingFormat: CIFormat.RGBAh,
        .cacheIntermediates: false
    ])
    private let cubeSpace = CGColorSpace(name: CGColorSpace.displayP3)
    private let outputSpace = CGColorSpace(name: CGColorSpace.displayP3)

    /// One table per look, built once. 64 steps a side is 262,144 colours,
    /// which takes a few milliseconds to work out and never has to be worked
    /// out again.
    private let lock = NSLock()
    private var cubes: [FilmLook.Kind: Data] = [:]
    private var grainMasks: [FilmLook.Kind: Data] = [:]
    private var ramps: [RampKey: Data] = [:]
    private static let cubeSide = 64
    private static let maskSide = 16

    /// The size the looks are tuned for: radii and grain are quoted in pixels
    /// of a photograph this big and scaled from there.
    private static let referenceSize: CGFloat = 2560

    // MARK: - Rendering

    func render(_ image: UIImage, look: FilmLook) -> UIImage {
        guard look.kind != .none else { return image }
        let upright = image.uprighted()
        guard let cg = upright.cgImage else { return image }
        let source = CIImage(cgImage: cg)
        let result = apply(look, to: source)
        guard let out = context.createCGImage(result, from: source.extent,
                                              format: .RGBAh, colorSpace: outputSpace) else {
            return image
        }
        return UIImage(cgImage: out, scale: upright.scale, orientation: .up)
    }

    /// The whole pipeline, as `CIImage`s.
    func apply(_ look: FilmLook, to input: CIImage) -> CIImage {
        var image = input
        let scale = max(input.extent.width, input.extent.height) / Self.referenceSize

        if look.neutralise > 0 {
            image = neutralised(image, strength: look.neutralise)
        }

        image = coloured(image, look: look)

        if look.shadowLift > 0 {
            let lift = CIFilter.highlightShadowAdjust()
            lift.inputImage = image
            lift.shadowAmount = Float(look.shadowLift)
            lift.highlightAmount = 1
            lift.radius = Float(max(8, 40 * scale))
            image = lift.outputImage ?? image
        }

        if let halation = look.halation {
            image = haloed(image, halation, scale: scale)
        }
        if let bloom = look.bloom {
            let filter = CIFilter.bloom()
            filter.inputImage = image
            filter.radius = Float(max(2, bloom.radius * scale))
            filter.intensity = Float(bloom.amount)
            image = (filter.outputImage ?? image).cropped(to: input.extent)
        }
        if let glow = look.glow {
            image = glowing(image, glow, scale: scale)
        }
        if look.clarity > 0 {
            let sharpen = CIFilter.unsharpMask()
            sharpen.inputImage = image
            sharpen.radius = Float(max(1.5, 7 * scale))
            sharpen.intensity = Float(look.clarity)
            image = (sharpen.outputImage ?? image).cropped(to: input.extent)
        }
        if let grain = look.grain {
            image = grained(image, grain, look: look, scale: scale)
        }
        if look.vignette > 0 {
            let filter = CIFilter.vignette()
            filter.inputImage = image
            filter.intensity = Float(look.vignette * 2)
            filter.radius = 1.4
            image = filter.outputImage ?? image
        }
        return image.cropped(to: input.extent)
    }

    // MARK: - Colour

    private func coloured(_ image: CIImage, look: FilmLook) -> CIImage {
        guard let data = cube(for: look) else { return image }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = image
        filter.cubeDimension = Float(Self.cubeSide)
        filter.cubeData = data
        filter.colorSpace = cubeSpace
        return filter.outputImage ?? image
    }

    /// **Take part of a colour cast out before the look goes on.** A warm look
    /// on a tungsten room is two casts stacked, which is how a photograph ends
    /// up orange. Correcting fully is worse: the grey-world assumption fails
    /// exactly when a picture really is mostly one colour — a lawn, a sunset,
    /// a team in blue — so the correction is capped at a few percent and
    /// scaled by how neutral the picture already looks.
    private func neutralised(_ image: CIImage, strength: Double) -> CIImage {
        let average = CIFilter.areaAverage()
        average.inputImage = image
        average.extent = image.extent
        guard let averaged = average.outputImage else { return image }
        var pixel = [Float](repeating: 0, count: 4)
        context.render(averaged, toBitmap: &pixel, rowBytes: 16,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBAf, colorSpace: outputSpace)
        let means = [Double(pixel[0]), Double(pixel[1]), Double(pixel[2])]
        let grey = (means[0] + means[1] + means[2]) / 3
        guard grey > 0.01 else { return image }
        let spread = (means.max() ?? 0) - (means.min() ?? 0)
        // A strongly coloured scene scores low and keeps its colour.
        let confidence = max(0, 1 - spread / 0.16)
        let cap = 0.07
        let gains = means.map { mean -> Double in
            let raw = grey / max(mean, 0.0001)
            let capped = min(max(raw, 1 - cap), 1 + cap)
            return 1 + (capped - 1) * strength * confidence
        }
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = CIVector(x: CGFloat(gains[0]), y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: CGFloat(gains[1]), z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: CGFloat(gains[2]), w: 0)
        return filter.outputImage ?? image
    }

    // MARK: - Light

    /// **Halation is a red-layer effect.** Light gets through the emulsion,
    /// reflects off the back of the film base and comes back into the layer
    /// nearest it, which in colour film is the red-sensitive one. So the bleed
    /// goes into red, a little into green, and none into blue.
    ///
    /// Two blurs, not one: a measured glare spread function has a steep core
    /// at the edge of a highlight and a low, broad wash across the frame.
    private func haloed(_ image: CIImage, _ glare: FilmLook.Glare, scale: CGFloat) -> CIImage {
        guard let lit = brightPass(image.clampedToExtent(), threshold: glare.threshold) else {
            return image
        }
        let core = blurred(lit, radius: glare.radius * Double(scale))
        let veil = blurred(lit, radius: glare.radius * 3.5 * Double(scale))
        let mixed = mix(core, over: veil, amount: 0.7)
        let tint = CIFilter.colorMatrix()
        tint.inputImage = mixed
        tint.rVector = CIVector(x: CGFloat(glare.amount), y: 0, z: 0, w: 0)
        tint.gVector = CIVector(x: 0, y: CGFloat(glare.amount * 0.35), z: 0, w: 0)
        tint.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        guard let glow = tint.outputImage else { return image }
        let screen = CIFilter.screenBlendMode()
        screen.inputImage = glow.cropped(to: image.extent)
        screen.backgroundImage = image
        return screen.outputImage ?? image
    }

    /// **The air in the picture**: a soft, lifted copy printed back over the
    /// photograph, which is the darkroom trick of printing through a diffused
    /// negative. Light gets somewhere to spread instead of stopping dead at an
    /// edge.
    private func glowing(_ image: CIImage, _ glare: FilmLook.Glare, scale: CGFloat) -> CIImage {
        let soft = blurred(image.clampedToExtent(), radius: glare.radius * Double(scale))
            .cropped(to: image.extent)
        let screen = CIFilter.screenBlendMode()
        let dim = CIFilter.colorMatrix()
        dim.inputImage = soft
        dim.rVector = CIVector(x: CGFloat(glare.amount), y: 0, z: 0, w: 0)
        dim.gVector = CIVector(x: 0, y: CGFloat(glare.amount), z: 0, w: 0)
        dim.bVector = CIVector(x: 0, y: 0, z: CGFloat(glare.amount), w: 0)
        screen.inputImage = dim.outputImage
        screen.backgroundImage = image
        guard let lifted = screen.outputImage else { return image }
        let creamy = CIFilter.softLightBlendMode()
        creamy.inputImage = soft
        creamy.backgroundImage = lifted
        let blended = mix(creamy.outputImage ?? lifted, over: lifted, amount: 0.5)
        guard let mask = lumaMask(image, from: glare.threshold, to: glare.threshold + 0.5) else {
            return blended.cropped(to: image.extent)
        }
        let keep = CIFilter.blendWithMask()
        keep.inputImage = blended
        keep.backgroundImage = image
        keep.maskImage = mask
        return (keep.outputImage ?? blended).cropped(to: image.extent)
    }

    /// What is above `threshold`, scaled back up to fill the range, and
    /// nothing else. Everything below becomes black.
    private func brightPass(_ image: CIImage, threshold: Double) -> CIImage? {
        let gain = 1 / max(1 - threshold, 0.01)
        let lift = CIFilter.colorMatrix()
        lift.inputImage = image
        lift.rVector = CIVector(x: CGFloat(gain), y: 0, z: 0, w: 0)
        lift.gVector = CIVector(x: 0, y: CGFloat(gain), z: 0, w: 0)
        lift.bVector = CIVector(x: 0, y: 0, z: CGFloat(gain), w: 0)
        lift.biasVector = CIVector(x: CGFloat(-threshold * gain), y: CGFloat(-threshold * gain),
                                   z: CGFloat(-threshold * gain), w: 0)
        guard let lifted = lift.outputImage else { return nil }
        let clamp = CIFilter.colorClamp()
        clamp.inputImage = lifted
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        return clamp.outputImage
    }

    private func blurred(_ image: CIImage, radius: Double) -> CIImage {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image
        blur.radius = Float(max(1, radius))
        return blur.outputImage ?? image
    }

    /// `amount` of the top image over the bottom one. Both are opaque, so
    /// lowering the top's alpha and compositing is a straight mix.
    private func mix(_ top: CIImage, over bottom: CIImage, amount: Double) -> CIImage {
        let fade = CIFilter.colorMatrix()
        fade.inputImage = top
        fade.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(amount))
        let over = CIFilter.sourceOverCompositing()
        over.inputImage = fade.outputImage
        over.backgroundImage = bottom
        return over.outputImage ?? bottom
    }

    // MARK: - Grain

    /// **Grain belongs to the negative.** It is drawn at the photograph's own
    /// resolution with a real grain size, so a block made from the photograph
    /// carries grain that has been averaged down the way a print does, and it
    /// is densest in the midtones and gone in the highlights, which is how an
    /// emulsion behaves.
    private func grained(_ image: CIImage, _ grain: FilmLook.Grain,
                         look: FilmLook, scale: CGFloat) -> CIImage {
        // **A preview must not lie about grain.** Grain is quoted for a
        // 2560px photograph; on a 180pt swatch one grain would be a fifth of a
        // pixel, and a one-pixel grain there is twenty times too coarse. The
        // amount comes down with the size, which is what downsampling a real
        // negative does anyway.
        let cell = max(1, grain.cell * Double(scale))
        let strength = grain.amount * min(1, max(Double(scale), 0.1))
        let noise = CIFilter.randomGenerator().outputImage?
            .transformed(by: CGAffineTransform(scaleX: CGFloat(cell), y: CGFloat(cell)))
            .cropped(to: image.extent)
        guard let noise else { return image }
        // Monochrome, except for as much colour as the dye layers give it. The
        // blue record is the grainiest of the three.
        let tone = CIFilter.colorMatrix()
        tone.inputImage = noise
        let mono = 1 - grain.colour
        tone.rVector = CIVector(x: mono, y: grain.colour * 0.5, z: grain.colour * 0.5, w: 0)
        tone.gVector = CIVector(x: grain.colour * 0.5, y: mono, z: grain.colour * 0.5, w: 0)
        tone.bVector = CIVector(x: grain.colour, y: grain.colour * 0.5, z: mono - grain.colour * 0.5, w: 0)
        tone.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        tone.biasVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let grey = tone.outputImage else { return image }
        let soft = CIFilter.softLightBlendMode()
        soft.inputImage = grey
        soft.backgroundImage = image
        guard let textured = soft.outputImage,
              let mask = grainMask(for: look, image: image, strength: strength / max(grain.amount, 0.0001)) else {
            return image
        }
        let blend = CIFilter.blendWithMask()
        blend.inputImage = textured
        blend.backgroundImage = image
        blend.maskImage = mask
        return blend.outputImage ?? image
    }

    /// Where the grain is allowed to be: a mask built from the picture itself,
    /// peaking in the midtones and thinning out in bright flat areas like sky,
    /// where film's own grain is finest and where blotches read as a bad JPEG.
    private func grainMask(for look: FilmLook, image: CIImage, strength: Double) -> CIImage? {
        guard let data = mask(for: look) else { return nil }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = image
        filter.cubeDimension = Float(Self.maskSide)
        filter.cubeData = data
        filter.colorSpace = cubeSpace
        guard let masked = filter.outputImage, strength < 0.999 else { return filter.outputImage }
        let dim = CIFilter.colorMatrix()
        dim.inputImage = masked
        dim.rVector = CIVector(x: CGFloat(strength), y: 0, z: 0, w: 0)
        dim.gVector = CIVector(x: 0, y: CGFloat(strength), z: 0, w: 0)
        dim.bVector = CIVector(x: 0, y: 0, z: CGFloat(strength), w: 0)
        return dim.outputImage
    }

    /// A greyscale mask that ramps from 0 at `from` to 1 at `to` on the
    /// picture's own brightness.
    private func lumaMask(_ image: CIImage, from: Double, to: Double) -> CIImage? {
        let key = RampKey(from: from, to: to)
        lock.lock()
        var data = ramps[key]
        lock.unlock()
        if data == nil {
            let side = Self.maskSide
            var values = [Float](repeating: 0, count: side * side * side * 4)
            var offset = 0
            for b in 0..<side {
                for g in 0..<side {
                    for r in 0..<side {
                        let l = FilmLook.luma(FilmLook.RGB(Double(r) / Double(side - 1),
                                                           Double(g) / Double(side - 1),
                                                           Double(b) / Double(side - 1)))
                        let value = Float(FilmLook.ramp(l, from, to))
                        values[offset] = value
                        values[offset + 1] = value
                        values[offset + 2] = value
                        values[offset + 3] = 1
                        offset += 4
                    }
                }
            }
            data = values.withUnsafeBufferPointer { Data(buffer: $0) }
            lock.lock()
            ramps[key] = data
            lock.unlock()
        }
        guard let data else { return nil }
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = image
        filter.cubeDimension = Float(Self.maskSide)
        filter.cubeData = data
        filter.colorSpace = cubeSpace
        return filter.outputImage
    }

    private struct RampKey: Hashable { let from: Double; let to: Double }

    // MARK: - Tables

    private func cube(for look: FilmLook) -> Data? {
        lock.lock()
        if let cached = cubes[look.kind] { lock.unlock(); return cached }
        lock.unlock()
        let side = Self.cubeSide
        var values = [Float](repeating: 0, count: side * side * side * 4)
        var offset = 0
        for b in 0..<side {
            for g in 0..<side {
                for r in 0..<side {
                    let colour = look.graded(FilmLook.RGB(Double(r) / Double(side - 1),
                                                          Double(g) / Double(side - 1),
                                                          Double(b) / Double(side - 1)))
                    values[offset] = Float(colour.r)
                    values[offset + 1] = Float(colour.g)
                    values[offset + 2] = Float(colour.b)
                    values[offset + 3] = 1
                    offset += 4
                }
            }
        }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        lock.lock()
        cubes[look.kind] = data
        lock.unlock()
        return data
    }

    private func mask(for look: FilmLook) -> Data? {
        guard let grain = look.grain else { return nil }
        lock.lock()
        if let cached = grainMasks[look.kind] { lock.unlock(); return cached }
        lock.unlock()
        let side = Self.maskSide
        var values = [Float](repeating: 0, count: side * side * side * 4)
        var offset = 0
        for b in 0..<side {
            for g in 0..<side {
                for r in 0..<side {
                    let colour = FilmLook.RGB(Double(r) / Double(side - 1),
                                              Double(g) / Double(side - 1),
                                              Double(b) / Double(side - 1))
                    let l = FilmLook.luma(colour)
                    // Peaks at mid density, falls away to both paper white and
                    // full black, and thins further in the brightest flats.
                    var weight = pow(4 * l * (1 - l), 0.7) * grain.amount
                    weight *= l < 0.69 ? 1 : max(0.35, 1 - (l - 0.69) / 0.43)
                    let value = Float(min(max(weight, 0), 1))
                    values[offset] = value
                    values[offset + 1] = value
                    values[offset + 2] = value
                    values[offset + 3] = 1
                    offset += 4
                }
            }
        }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        lock.lock()
        grainMasks[look.kind] = data
        lock.unlock()
        return data
    }
}

extension UIImage {
    /// The same picture with its orientation baked in, so Core Image and
    /// `CGImage` agree about which way up it is.
    func uprighted() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
