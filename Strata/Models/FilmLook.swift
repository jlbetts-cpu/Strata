import CoreGraphics
import Foundation

/// A film look: what a photograph becomes when you choose one.
///
/// **The colour is pure arithmetic and lives here.** Everything that depends
/// only on a pixel's own colour — the tone curve, the crossover between
/// layers, the hue moves, the way saturation falls away at both ends, the
/// split tone, the protection of skin — is one function, `graded(_:)`, so it
/// can be tested without a GPU and baked into a single colour table for one
/// fast pass (`FilmLookRenderer`). Everything that depends on a pixel's
/// NEIGHBOURS — halation, bloom, glow, grain, the shadow lift, the vignette —
/// is a filter and lives there.
///
/// The order is the order a film photograph is made in, and each step is here
/// because leaving it out is a way filters look cheap:
///
/// 1. **Linear light.** Tone and colour are done on light rather than on the
///    numbers a screen stores. Contrast on gamma-encoded values is the single
///    biggest reason app filters clip highlights and skew hue.
/// 2. **A curve with a toe and a shoulder**, so highlights compress towards
///    white instead of hitting a wall.
/// 3. **No hue skew in bright colour.** A per-channel curve pushes saturated
///    colours towards whichever primary clips last, so blue goes purple and
///    red goes orange. AgX's answer, used here, is to pull colour towards grey
///    before the curve and let it back out after, holding the hue and letting
///    intense colour fade towards white the way film does.
/// 4. **Crossover between layers**, which is what makes a look read as a stock
///    rather than as a tint.
/// 5. **Saturation that tracks brightness.** Film loses colour approaching
///    white and falling into black. One saturation everywhere is the other
///    big tell.
/// 6. **Memory colours.** Skin, sky and foliage are the three colours everyone
///    has a fixed expectation of. Sky and foliage are eased towards the hues
///    people remember; skin is exempt from every colour move in the look.
///
/// Research and the reasoning behind each number: `docs/film-looks.md`.
nonisolated struct FilmLook: Identifiable, Equatable, Sendable {

    /// Which look. The raw value is what is stored on a win.
    nonisolated enum Kind: String, CaseIterable, Identifiable, Sendable {
        case none, air, bright, silver
        var id: String { rawValue }

        /// What it is called on screen.
        var name: String {
            switch self {
            case .none:   return "None"
            case .air:    return "Air"
            case .bright: return "Bright"
            case .silver: return "Silver"
            }
        }

        /// One line, for the accessibility label.
        var describedAs: String {
            switch self {
            case .none:   return "No film look"
            case .air:    return "Air, warm and soft"
            case .bright: return "Bright, deep colour"
            case .silver: return "Silver, black and white"
            }
        }
    }

    var id: String { kind.rawValue }
    var kind: Kind

    // MARK: - Tone

    /// Exposure applied in linear light before the curve.
    var exposure: Double = 1
    /// The white point the highlights roll towards. Higher is a longer, softer
    /// roll-off.
    var shoulder: Double = 1.8
    /// How much S-curve, and the brightness it turns about, so a look can be
    /// contrasty without becoming darker overall.
    var contrast: Double = 0
    var pivot: Double = 0.5
    /// Film base fog: the shadows never quite reach zero. Warm, per channel,
    /// because a cold lift is what makes a photograph look sad.
    var blackLift: RGB = RGB(0, 0, 0)
    /// The opposite: a crushed toe.
    var blackPoint: Double = 0

    // MARK: - Colour

    /// How far colour is pulled towards grey before the curve, and how much of
    /// it comes back after. See point 3 above.
    var inset: Double = 0.16
    var restore: Double = 0.86
    /// Near-white is eased to neutral by this much, so a blown highlight goes
    /// white rather than magenta: green clips first and leaves red and blue
    /// behind.
    var clipGuard: Double = 0.6
    /// Row-major 3x3, identity plus a few percent.
    var matrix: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
    /// Hue bands: centre and width on a 0..<1 hue circle, how far to move
    /// them, and what to do to their saturation.
    var hues: [HueBand] = []
    /// Familiar colours eased towards the hue people remember them having.
    var memory: [HueBand] = []
    var saturation: Double = 1
    var saturationHigh: Double = 1
    var saturationLow: Double = 1
    /// Where the two ends of the range are tinted, and how far.
    var shadowTint: RGB = RGB(0, 0, 0)
    var shadowAmount: Double = 0
    var highlightTint: RGB = RGB(1, 1, 1)
    var highlightAmount: Double = 0
    /// How much of every colour move is kept off skin.
    var skinProtection: Double = 0.85
    /// Black and white, with the channel weights of a light orange filter so
    /// skin stays light and a sky keeps its clouds.
    var mono: RGB?

    // MARK: - Light and texture (applied by `FilmLookRenderer`)

    /// How much of a colour cast to take out before the look goes on, 0...1.
    var neutralise: Double = 0.45
    /// Lifting only where the picture is dark, so a dim room keeps what is in
    /// it without the whole frame going milky.
    var shadowLift: Double = 0
    /// Red-layer bleed around the brightest edges: threshold, radius in pixels
    /// of a 2560px photograph, and strength.
    var halation: Glare?
    /// A neutral spill off highlights, before they clip.
    var bloom: Glare?
    /// The air: a soft, lifted copy printed back over the picture.
    var glow: Glare?
    /// Local contrast, to pay for the softness the shoulder and the glow cost.
    var clarity: Double = 0
    /// Grain: how strong, how big on a 2560px photograph, and how much colour
    /// it carries.
    var grain: Grain?
    var vignette: Double = 0

    nonisolated struct Glare: Equatable, Sendable {
        var threshold: Double
        var radius: Double
        var amount: Double
    }

    nonisolated struct Grain: Equatable, Sendable {
        var amount: Double
        /// The size of one grain in pixels of a 2560px photograph. About two,
        /// which is what a 35mm scan actually shows.
        var cell: Double
        var colour: Double
    }

    nonisolated struct HueBand: Equatable, Sendable {
        /// 0..<1 around the hue circle.
        var centre: Double
        var width: Double
        /// Moved by this much (`.shift`) or eased this far towards the centre
        /// (`.pull`).
        var move: Double
        var pull: Bool = false
        var saturation: Double = 1
    }

    nonisolated struct RGB: Equatable, Sendable {
        var r: Double, g: Double, b: Double
        init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        /// From a 0...255 triple, which is how the looks were tuned.
        static func bytes(_ r: Double, _ g: Double, _ b: Double) -> RGB {
            RGB(r / 255, g / 255, b / 255)
        }
    }
}

// MARK: - The colour, as arithmetic

extension FilmLook {

    /// What this look does to one colour. Pure: the same input always gives
    /// the same output, which is what lets it be tested and baked into a table.
    ///
    /// Input and output are 0...1 in the display's own space.
    func graded(_ input: RGB) -> RGB {
        guard kind != .none else { return input }
        var colour = input

        if let mono {
            let grey = colour.r * mono.r + colour.g * mono.g + colour.b * mono.b
            colour = RGB(grey, grey, grey)
        }

        // Colour towards grey before the curve, so the curve cannot skew hue.
        let flat = Self.luma(colour)
        if inset > 0 {
            colour = Self.mix(colour, RGB(flat, flat, flat), inset)
        }

        colour = RGB(tone(colour.r, lift: blackLift.r),
                     tone(colour.g, lift: blackLift.g),
                     tone(colour.b, lift: blackLift.b))

        // And back out, except near white: that is the highlight desaturation
        // film is loved for, and why a bright sky rolls to white and not cyan.
        if inset > 0 {
            let widened = Self.saturate(colour, by: 1 / max(1 - inset, 0.05))
            let held = Self.mix(colour, widened, restore)
            colour = Self.mix(held, colour, Self.ramp(Self.luma(colour), 0.72, 0.99))
        }

        if clipGuard > 0 {
            let highest = max(colour.r, max(colour.g, colour.b))
            let near = Self.ramp(highest, 0.93, 1.0) * clipGuard
            let grey = Self.luma(colour)
            colour = Self.mix(colour, RGB(grey, grey, grey), near)
        }

        colour = RGB(matrix[0] * colour.r + matrix[1] * colour.g + matrix[2] * colour.b,
                     matrix[3] * colour.r + matrix[4] * colour.g + matrix[5] * colour.b,
                     matrix[6] * colour.r + matrix[7] * colour.g + matrix[8] * colour.b)

        // **Skin is exempt from every colour move**, and the judgement is made
        // on the colour as it is here, before any of them.
        let skin = Self.skinWeight(colour) * skinProtection
        let beforeColour = colour

        if !hues.isEmpty { colour = Self.steer(colour, by: hues) }
        if !memory.isEmpty { colour = Self.steer(colour, by: memory) }
        // Skin keeps the hue it had, however far the rest of the picture is
        // moved. This is the single most important line in the file: a look
        // that moves skin is a look nobody uses on a photograph of a person.
        if !hues.isEmpty || !memory.isEmpty { colour = Self.mix(colour, beforeColour, skin) }

        let brightness = Self.luma(colour)
        var factor = saturation
        factor = Self.mix(factor, saturationHigh, Self.ramp(brightness, 0.62, 0.98))
        factor = Self.mix(factor, saturationLow, Self.ramp(brightness, 0.30, 0.02))
        let beforeSaturation = colour
        colour = Self.saturate(colour, by: factor)
        // A saturated look must not saturate people: where a look adds
        // colour, skin keeps the saturation it had.
        if factor > 1.02 { colour = Self.mix(colour, beforeSaturation, skin) }

        let keep = 1 - skin
        if shadowAmount > 0 {
            colour = Self.mix(colour, shadowTint, shadowAmount * Self.ramp(brightness, 0.42, 0.02) * keep)
        }
        if highlightAmount > 0 {
            colour = Self.mix(colour, highlightTint, highlightAmount * Self.ramp(brightness, 0.55, 1.0) * keep)
        }

        return RGB(min(max(colour.r, 0), 1), min(max(colour.g, 0), 1), min(max(colour.b, 0), 1))
    }

    /// One channel, through the whole tonal transform.
    private func tone(_ value: Double, lift: Double) -> Double {
        var light = Self.toLinear(value) * exposure
        // Extended Reinhard: rolls off towards `shoulder` and never clips.
        light = light * (1 + light / (shoulder * shoulder)) / (1 + light)
        var v = Self.toDisplay(light)
        if contrast != 0 { v = Self.contrastCurve(v, contrast, pivot) }
        if blackPoint != 0 { v = (v - blackPoint) / (1 - blackPoint) }
        // Film base fog: the shadows stop short of zero.
        if lift != 0 { v = lift + v * (1 - lift) }
        return min(max(v, 0), 1)
    }

    // MARK: - Small maths

    static func toLinear(_ v: Double) -> Double {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    static func toDisplay(_ v: Double) -> Double {
        let c = min(max(v, 0), 1)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    /// Rec.709 luma, which is what both the saturation and the masks are
    /// judged on.
    static func luma(_ c: RGB) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    static func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// 0 at `from`, 1 at `to`, smooth between. Works in either direction, so
    /// a shadow ramp is written the way it reads.
    static func ramp(_ x: Double, _ from: Double, _ to: Double) -> Double {
        guard from != to else { return x >= to ? 1 : 0 }
        return smoothstep((x - from) / (to - from))
    }

    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        RGB(mix(a.r, b.r, t), mix(a.g, b.g, t), mix(a.b, b.b, t))
    }

    static func saturate(_ c: RGB, by factor: Double) -> RGB {
        let grey = luma(c)
        return RGB(grey + (c.r - grey) * factor,
                   grey + (c.g - grey) * factor,
                   grey + (c.b - grey) * factor)
    }

    /// An S-curve that turns about `pivot` rather than about mid-grey.
    static func contrastCurve(_ v: Double, _ amount: Double, _ pivot: Double) -> Double {
        let x = min(max(v, 0), 1)
        if x < pivot {
            let t = x / pivot
            return pivot * (t + amount * (smoothstep(t) - t))
        }
        let t = (x - pivot) / (1 - pivot)
        return pivot + (1 - pivot) * (t + amount * (smoothstep(t) - t))
    }

    // MARK: - Hue

    /// Hue 0..<1, saturation 0...1, value 0...1.
    static func hsv(_ c: RGB) -> (h: Double, s: Double, v: Double) {
        let high = max(c.r, max(c.g, c.b)), low = min(c.r, min(c.g, c.b))
        let span = high - low
        var hue = 0.0
        if span > 0 {
            if high == c.r { hue = (c.g - c.b) / span / 6 }
            else if high == c.g { hue = (2 + (c.b - c.r) / span) / 6 }
            else { hue = (4 + (c.r - c.g) / span) / 6 }
            if hue < 0 { hue += 1 }
        }
        return (hue, high > 0 ? span / high : 0, high)
    }

    static func rgb(h: Double, s: Double, v: Double) -> RGB {
        guard s > 0 else { return RGB(v, v, v) }
        let sector = (h - floor(h)) * 6
        let i = floor(sector), f = sector - i
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch Int(i) % 6 {
        case 0: return RGB(v, t, p)
        case 1: return RGB(q, v, p)
        case 2: return RGB(p, v, t)
        case 3: return RGB(p, q, v)
        case 4: return RGB(t, p, v)
        default: return RGB(v, p, q)
        }
    }

    /// The shortest way round the circle, -0.5...0.5.
    static func hueDistance(_ a: Double, _ b: Double) -> Double {
        var d = a - b
        while d > 0.5 { d -= 1 }
        while d < -0.5 { d += 1 }
        return d
    }

    /// A raised cosine over a band, so its edges blend into their neighbours
    /// instead of drawing a seam through a sky.
    static func window(_ hue: Double, _ centre: Double, _ width: Double) -> Double {
        let d = abs(hueDistance(hue, centre))
        guard d < width else { return 0 }
        return 0.5 * (1 + cos(.pi * d / width))
    }

    /// Move and mute individual hues. A tint moves the whole picture; a stock
    /// moves yellows one way and greens another.
    static func steer(_ c: RGB, by bands: [HueBand]) -> RGB {
        var (h, s, v) = hsv(c)
        guard s > 0.01 else { return c }
        var hue = h, factor = 1.0
        for band in bands {
            let w = window(h, band.centre, band.width)
            guard w > 0 else { continue }
            if band.pull {
                // Eased towards the centre rather than shifted by a fixed
                // amount: a colour already in the right place is left alone.
                hue -= hueDistance(h, band.centre) * band.move * w
            } else {
                hue += band.move * w
            }
            factor *= (1 - w) + w * band.saturation
        }
        s = min(max(s * factor, 0), 1)
        return rgb(h: hue - floor(hue), s: s, v: v)
    }

    /// How much this colour looks like skin: the hue band skin sits in, with
    /// some colour in it, and neither black nor white. Published work on
    /// preferred skin puts it near a CIELAB hue of 49 degrees, which is this
    /// orange-yellow band.
    static func skinWeight(_ c: RGB) -> Double {
        let (h, s, v) = hsv(c)
        let hue = window(h, 0.075, 0.075)
        let sat = ramp(s, 0.10, 0.20) * (1 - ramp(s, 0.70, 0.85))
        let light = ramp(v, 0.12, 0.22) * (1 - ramp(v, 0.94, 1.0))
        return hue * sat * light
    }
}

// MARK: - The looks

extension FilmLook {

    /// Three, and none. **Less is more** (the owner's call): a long list of
    /// looks is a list nobody reads, and the two that were cut both read as
    /// sad — muted plus cool plus heavy shadows is the recipe for gloom.
    static let all: [FilmLook] = [none, air, bright, silver]

    static func look(_ kind: Kind) -> FilmLook {
        all.first { $0.kind == kind } ?? none
    }

    static let none = FilmLook(kind: .none, neutralise: 0)

    /// Soft, warm and luminous. The one for people: nothing in it pushes skin
    /// anywhere, the highlights are creamy rather than clipped, and the glow
    /// does most of the work.
    static let air = FilmLook(
        kind: .air,
        exposure: 1.14, shoulder: 2.30, contrast: 0.16, pivot: 0.53,
        blackLift: RGB(0.046, 0.042, 0.040),
        matrix: [1.01, 0, -0.01, 0, 1, 0, -0.01, 0, 1.01],
        hues: [HueBand(centre: 0.313, width: 0.110, move: 0.020, saturation: 1.02),
               HueBand(centre: 0.588, width: 0.102, move: -0.008, saturation: 1.06),
               HueBand(centre: 0.149, width: 0.070, move: -0.008, saturation: 0.98)],
        memory: [HueBand(centre: 0.345, width: 0.102, move: 0.30, pull: true),
                 HueBand(centre: 0.588, width: 0.102, move: 0.30, pull: true)],
        saturation: 1.02, saturationHigh: 0.84, saturationLow: 0.90,
        shadowTint: .bytes(96, 92, 98), shadowAmount: 0.05,
        highlightTint: .bytes(255, 238, 214), highlightAmount: 0.16,
        skinProtection: 0.90,
        neutralise: 0.45, shadowLift: 0.22,
        halation: Glare(threshold: 0.84, radius: 30, amount: 0.16),
        bloom: Glare(threshold: 0.86, radius: 54, amount: 0.10),
        glow: Glare(threshold: 0.22, radius: 40, amount: 0.30),
        clarity: 0.28,
        grain: Grain(amount: 0.34, cell: 2.2, colour: 0.08))

    /// Velvia's colour with the lights on: greens towards teal, blues deep,
    /// reds loud, and saturation that falls away near white so a sky keeps its
    /// gradient. Skin holds its own saturation throughout.
    static let bright = FilmLook(
        kind: .bright,
        exposure: 1.10, shoulder: 1.55, contrast: 0.34, pivot: 0.48,
        blackLift: RGB(0.016, 0.014, 0.020),
        matrix: [1.06, -0.04, -0.02, -0.03, 1.05, -0.02, -0.02, -0.05, 1.07],
        hues: [HueBand(centre: 0.313, width: 0.118, move: 0.035, saturation: 1.40),
               HueBand(centre: 0.149, width: 0.070, move: -0.020, saturation: 1.12),
               HueBand(centre: 0.470, width: 0.070, move: 0, saturation: 0.86),
               HueBand(centre: 0.588, width: 0.110, move: 0.016, saturation: 1.30),
               HueBand(centre: 0.0, width: 0.055, move: 0, saturation: 1.24)],
        memory: [HueBand(centre: 0.345, width: 0.102, move: 0.34, pull: true),
                 HueBand(centre: 0.588, width: 0.102, move: 0.34, pull: true)],
        saturation: 1.24, saturationHigh: 0.82, saturationLow: 0.90,
        shadowTint: .bytes(60, 72, 92), shadowAmount: 0.07,
        highlightTint: .bytes(255, 250, 240), highlightAmount: 0.06,
        skinProtection: 0.85,
        neutralise: 0.45, shadowLift: 0.18,
        halation: Glare(threshold: 0.83, radius: 22, amount: 0.20),
        bloom: Glare(threshold: 0.90, radius: 38, amount: 0.07),
        glow: Glare(threshold: 0.22, radius: 28, amount: 0.17),
        clarity: 0.50,
        grain: Grain(amount: 0.28, cell: 2.0, colour: 0.07))

    /// Black and white through a light orange filter, so skin stays light and
    /// a sky keeps its clouds. Lifted rather than gloomy, with the grain film
    /// actually has: heaviest in the midtones, gone in the highlights.
    static let silver = FilmLook(
        kind: .silver,
        exposure: 1.11, shoulder: 2.10, contrast: 0.28, pivot: 0.49,
        blackLift: RGB(0.016, 0.016, 0.016),
        inset: 0, restore: 0,
        saturation: 1, saturationHigh: 1, saturationLow: 1,
        highlightTint: .bytes(255, 252, 245), highlightAmount: 0.05,
        skinProtection: 0,
        mono: RGB(0.42, 0.44, 0.14),
        neutralise: 0.45, shadowLift: 0.20,
        bloom: Glare(threshold: 0.88, radius: 44, amount: 0.10),
        glow: Glare(threshold: 0.22, radius: 36, amount: 0.25),
        clarity: 0.46,
        grain: Grain(amount: 0.56, cell: 2.6, colour: 0),
        vignette: 0.05)
}
