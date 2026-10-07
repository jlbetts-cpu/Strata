import SwiftUI

/// The launch: the icon's mark, white in the centre, held a beat, and let go.
///
/// **The mark is his drawn camera** (the owner, 2026-10-06: the logo is a
/// camera now, "yes switch them to the camera"), `BrandCamera`, upright: the
/// S's resting angle belonged to the S.
///
/// The static launch screen is only `LaunchGround` (Info.plist
/// `UILaunchScreen`): the tower's page, #F7F7F7 in light and 0.031 in dark,
/// because the app opens on the tower (the owner, 2026-10-06). It was black
/// in both while the app opened on the camera, and a light phone then went
/// black and cut to a white page. The mark is the drawing ink, so it is the
/// icon's own colours in each appearance.
///
/// Over the first frame this draws the S rolling in from the left like a
/// rigid square, in a block's material, cutting to the next block colour on
/// each landing and resolving to the flat white icon S, at the icon's own
/// angle, on the last. Then the S fades on the black
/// and the black fades to reveal the camera (or onboarding, on the first
/// launch ever). The timing is `LaunchRoll`, a pure function of time, which
/// the offline preview in `ground-shots/scripts/roll/` also draws from.
///
/// **Cheap.** One small view: a transform, a colour and two opacities, driven
/// by a `TimelineView` for about 1.2s of frames. Nothing under it re-renders, the
/// camera session starts on its own `.task` underneath, taps pass through
/// the whole time, and VoiceOver never sees it. It removes itself when the
/// black has gone. It lives in the `App`'s own state, so returning from the
/// background never plays it again.
///
/// Reduce Motion: no rolling. The white S stands in the centre, then the
/// same two fades, shorter.
struct LaunchHandoff: View {
    @State private var clock = RollClock()
    @State private var running = false
    @State private var finished = false

    /// The block palette in the owner's order: green, orange, blue, pink,
    /// purple, coral.
    private static let palette: [Color] = [HabitCategory.health, .focus, .work,
                                           .mindfulness, .creativity, .social]
        .map { $0.style.baseColor }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !finished {
            TimelineView(.animation(paused: !running)) { context in
                let t = running ? clock.advance(to: context.date) : 0
                Group {
                    if reduceMotion {
                        // Still, then the two fades (`LaunchRoll`'s own path).
                        let frame = LaunchRoll.frame(at: t, reduceMotion: true)
                        stage(frame)
                            .onChange(of: frame.finished) { _, done in if done { end() } }
                    } else {
                        // **Drawn, then rubbed out** (`LaunchDraw`).
                        let frame = LaunchDraw.frame(at: t)
                        drawing(frame)
                            .onChange(of: frame.finished) { _, done in if done { end() } }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                // `onAppear` runs while the first frame is being built.
                // Hopping the main queue once starts the clock after that
                // frame is committed.
                DispatchQueue.main.async { running = true }
            }
            // A launch that never runs to its end (the app sent to the
            // background mid-way) still lets the crest arrive.
            .onDisappear { LaunchMoment.shared.finish() }
        }
    }

    private func end() {
        finished = true
        LaunchMoment.shared.finish()
    }

    /// The mark's strokes on the ground, each trimmed to what is drawn and
    /// not yet rubbed out: the heavy outline at the body's weight, the rest
    /// lighter, round at the ends as a pen is.
    private func drawing(_ f: LaunchDraw.Frame) -> some View {
        ZStack {
            Color("LaunchGround")
            ZStack {
                ForEach(Array(LogoStrokes.all.enumerated()), id: \.offset) { i, stroke in
                    LogoStrokeShape(stroke: stroke)
                        .trim(from: 0, to: f.drawn[i])
                        .stroke(AppColors.drawingInk,
                                style: StrokeStyle(lineWidth: LaunchRoll.side * (stroke.heavy ? LogoStrokes.outer : LogoStrokes.inner),
                                                   lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: LaunchRoll.side, height: LaunchRoll.side)
            // **Rubbed out**: the eraser's swath, scrubbing back and forth,
            // cut out of the drawing, its edge a little soft as a rubber's is.
            .mask {
                Rectangle()
                    .overlay {
                        EraserScrub()
                            .trim(from: 0, to: f.wiped)
                            .stroke(Color.black, style: StrokeStyle(lineWidth: LaunchRoll.side * LaunchDraw.eraserWidth,
                                                                    lineCap: .round, lineJoin: .round))
                            .blur(radius: 1.5)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .frame(width: LaunchRoll.side * 1.4, height: LaunchRoll.side * 1.4)
            }
        }
        .opacity(f.groundOpacity)
    }

    private func stage(_ f: LaunchRoll.Frame) -> some View {
        ZStack {
            Color("LaunchGround")
            mark(f.fill)
                .frame(width: LaunchRoll.side, height: LaunchRoll.side)
                .rotationEffect(.degrees(f.tilt), anchor: .bottomTrailing)
                .offset(x: f.offset)
                .opacity(f.markOpacity)
        }
        .opacity(f.groundOpacity)
    }

    /// Rolling, the S wears a block: its colour, the wash over its lower
    /// quarter, and the rim lit along its top edge, at `BlockSurface`'s own
    /// weights for a dark ground. Landed in the centre, it is the icon: flat
    /// white.
    @ViewBuilder
    private func mark(_ fill: Int) -> some View {
        if fill >= LaunchRoll.rolls {
            Image("BrandCamera").renderingMode(.template).foregroundStyle(AppColors.drawingInk)
        } else {
            ZStack {
                Image("BrandCamera").renderingMode(.template)
                    .foregroundStyle(Self.palette[fill % Self.palette.count])
                Image("BrandCamera").renderingMode(.template)
                    .foregroundStyle(Self.wash)
            }
        }
    }

    private static let wash = LinearGradient(
        stops: [.init(color: .clear, location: GridConstants.blockBandStart),
                .init(color: .white.opacity(GridConstants.blockScrimOpacity), location: 1)],
        startPoint: .top, endPoint: .bottom)

    /// `BlockSurface.rim` as it is drawn on the dark ground.
    private static let rim = LinearGradient(
        stops: [.init(color: .white.opacity(0.85), location: 0),
                .init(color: .white.opacity(GridConstants.blockRimFalloff * 0.7), location: 0.55),
                .init(color: .white.opacity(GridConstants.blockRimFalloff * 0.7), location: 1)],
        startPoint: .top, endPoint: .bottom)
}

/// The roll's clock: frames, not the wall.
///
/// A cold launch can hold the main thread for most of a second (measured on
/// the first launch after install: one frame of the roll drawn, the next
/// 0.59s later, already fading). On a wall clock the roll is simply skipped.
/// Here each frame advances at most a thirtieth of a second, so a hitch
/// pauses the roll where it is and it carries on when the thread is back.
/// The camera under it is not waiting on this; nothing on screen could have
/// moved during the hitch anyway.
///
/// A plain reference, not observed: `TimelineView` already redraws every
/// frame, and a body that runs twice for one date advances it by zero.
private final class RollClock {
    private var last: Date?
    private(set) var elapsed: Double = 0

    func advance(to now: Date) -> Double {
        if let last { elapsed += min(max(now.timeIntervalSince(last), 0), 1.0 / 30) }
        last = now
        return elapsed
    }
}

/// The eraser's back-and-forth, in the mark's square (`LaunchDraw.scrub`).
private struct EraserScrub: Shape {
    func path(in rect: CGRect) -> Path {
        // The mask is drawn larger than the mark; map the mark's square
        // (its middle 1/1.4) onto it.
        let side = rect.width / 1.4
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        var path = Path()
        for (i, p) in LaunchDraw.scrub.enumerated() {
            let point = CGPoint(x: origin.x + p.0 * side, y: origin.y + p.1 * side)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
