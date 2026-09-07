import SwiftUI

/// The tower, in the water it stands on.
///
/// This replaces a drop shadow under the bottom row. A shadow says the tower
/// hovers slightly above a surface; a reflection says the surface is a material
/// and the tower is standing in it.
///
/// ## Why this is a Canvas and not a Metal shader
///
/// It was a shader first — `distortionEffect` with a `waterRipple` function,
/// which is the right tool on paper: one GPU pass, per-pixel. It was abandoned
/// after measurement, not on taste. **SwiftUI shader effects do not update
/// their uniforms across frames in the iOS 26.3 simulator.** Verified three
/// ways: a `colorEffect` forcing flat red DID apply (so the Metal pipeline
/// works), a `colorEffect` whose colour came from the time uniform produced an
/// identical pixel on every frame, and the same clock driving a plain
/// `.offset` in Swift animated normally. The shader ran once and froze.
///
/// Motion is the entire point of this view, so it is built from something whose
/// motion can be verified on this machine.
///
/// ## Cost
///
/// One `Canvas`, redrawn at `frameInterval`, drawing one wavy quad per block in
/// the bottom row plus five crest lines — under a dozen paths, no per-pixel
/// work, no offscreen buffer, and no second pass over the tower. The tower's
/// blocks are never re-rendered: a reflection at the base of something shows
/// only what is nearest the water, and shows it without detail, so this needs
/// nothing from a block but its colour and its width.
struct TowerReflection: View {
    /// What of a block reaches the water. Nothing else survives.
    struct Facet: Identifiable, Equatable {
        let id: UUID
        let x: CGFloat
        let width: CGFloat
        let color: Color
    }

    /// Kept as a type so callers still compile, but the water no longer
    /// splashes. Expanding rings read as a stone thrown INTO the water, and
    /// nothing is being thrown in — the tower is standing in it. The surface
    /// moving on its own is the whole effect.
    struct Impact: Identifiable, Equatable {
        let id: UUID
        let x: CGFloat
        let start: TimeInterval
        let mass: Int
        static let lifetime: TimeInterval = 1.5
    }

    let facets: [Facet]
    let impacts: [Impact]
    let gridWidth: CGFloat
    let cornerRadius: CGFloat
    let reduceMotion: Bool

    /// How far the water extends below the waterline.
    /// How far the water extends below the waterline.
    ///
    /// Shortened from 64: the tower now sits tight to the tab bar with nothing
    /// under it but this, and a deeper band both crowded that and read as
    /// somewhere to scroll to. Water needs room to be water, so this is the
    /// knob if it ever feels cramped.
    static let depth: CGFloat = 46

    private static let frameInterval: Double = 1.0 / 30.0
    /// Vertical sampling of the wavy edges. Twelve steps over 64pt is below the
    /// point where the curve reads as segments.
    private static let steps = 12

    private var amplitude: CGFloat { reduceMotion ? 0 : 4 }

    var body: some View {
        TimelineView(.animation(minimumInterval: Self.frameInterval,
                                paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
                draw(in: &ctx, size: size, time: t)
            }
            .blur(radius: 1.2)
        }
        .frame(width: gridWidth, height: Self.depth)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    /// Horizontal displacement of the reflection at a given depth.
    ///
    /// Three sine waves at unrelated frequencies and speeds, summed. One wave
    /// reads as a machine; three that never line up read as water. They travel
    /// in opposite directions so the surface never appears to drift.
    ///
    /// Displacement grows with depth. Right at the waterline the reflection has
    /// to stay locked to the object it belongs to or the two visibly detach;
    /// further out it is free to break up. That gradient is most of what makes
    /// this read as a reflection rather than a wobble.
    private func wave(depth d: CGFloat, time: Double) -> CGFloat {
        let u = Double(d)
        let w = sin(u * 0.22 + time * 1.10) * 0.50
              + sin(u * 0.41 - time * 1.70) * 0.30
              + sin(u * 0.13 + time * 0.63) * 0.20
        return CGFloat(w) * amplitude * (0.05 + d / Self.depth * 0.95)
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let h = size.height
        let stepH = h / CGFloat(Self.steps)

        // Each block's colour, falling into the water as a wavy column.
        for facet in facets {
            var path = Path()
            // Down the left edge…
            for i in 0...Self.steps {
                let y = stepH * CGFloat(i)
                let p = CGPoint(x: facet.x + wave(depth: y, time: time), y: y)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            // …and back up the right.
            for i in stride(from: Self.steps, through: 0, by: -1) {
                let y = stepH * CGFloat(i)
                path.addLine(to: CGPoint(x: facet.x + facet.width + wave(depth: y, time: time), y: y))
            }
            path.closeSubpath()

            ctx.fill(path, with: .linearGradient(
                Gradient(stops: [
                    // Paler than it was. A reflection you notice is a
                    // reflection that reads as content — it was pulling the eye
                    // down the page and inviting a scroll to something that is
                    // not there. Real water at a shallow angle returns very
                    // little.
                    .init(color: facet.color.opacity(0.30), location: 0.0),
                    .init(color: facet.color.opacity(0.17), location: 0.32),
                    .init(color: facet.color.opacity(0.04), location: 0.74),
                    .init(color: facet.color.opacity(0.0), location: 1.0)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: h)
            ))
        }

        // The lit edge of each block, mirrored. In a real reflection the
        // object's bright edge is the brightest thing on the water, and it sits
        // hard against the waterline because that is where displacement is
        // nearly zero.
        for facet in facets {
            let r = CGRect(x: facet.x, y: 0, width: facet.width, height: 1.6)
            ctx.fill(Path(roundedRect: r, cornerRadius: 0.8),
                     with: .color(.white.opacity(0.32)))
        }

        // Light catching the ripples.
        //
        // Without these the band is a smooth vertical gradient, and a smooth
        // gradient displaced smoothly still looks like a smooth gradient — the
        // motion is real but invisible. A horizontal line is the one shape a
        // vertical swell visibly bends, so these are what you actually see as
        // water. Irregular spacing: even spacing reads as corduroy.
        for crest in Self.crests {
            var path = Path()
            let swell = reduceMotion ? 0 : sin(time * crest.speed + crest.phase) * 2.2
            for i in 0...Self.steps {
                let x = size.width / CGFloat(Self.steps) * CGFloat(i)
                let bend = sin(Double(x) * 0.035 + time * crest.speed * 1.3 + crest.phase) * 1.8
                let y = crest.y + CGFloat(swell + bend)
                let p = CGPoint(x: x, y: y)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            ctx.stroke(path,
                       with: .color(.white.opacity(crest.opacity)),
                       lineWidth: crest.thickness)
        }
    }

    private static let crests: [(y: CGFloat, thickness: CGFloat, opacity: Double, speed: Double, phase: Double)] = [
        (8,  1.8, 0.42, 1.10, 0.0),
        (16, 1.6, 0.32, 1.55, 1.7),
        (25, 1.4, 0.23, 0.85, 3.1),
        (34, 1.2, 0.15, 1.35, 4.6),
        (42, 1.0, 0.09, 0.70, 5.9),
    ]
}
