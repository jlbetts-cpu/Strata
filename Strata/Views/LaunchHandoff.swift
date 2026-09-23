import SwiftUI

/// The launch: the icon's S tumbles in, lands white in the centre, and lets go.
///
/// The static launch screen is only `LaunchBlack` (Info.plist
/// `UILaunchScreen`), the camera's own ground at 0.031 in both appearances,
/// because the app opens on the camera and the camera is dark whatever the
/// phone is set to. There is no image on it: a static S would have to vanish
/// before it could roll in.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = RollClock()
    @State private var running = false
    @State private var finished = false

    /// The block palette in the owner's order: green, orange, blue, pink,
    /// purple, coral.
    private static let palette: [Color] = [HabitCategory.health, .focus, .work,
                                           .mindfulness, .creativity, .social]
        .map { $0.style.baseColor }

    var body: some View {
        if !finished {
            TimelineView(.animation(paused: !running)) { context in
                let frame = LaunchRoll.frame(at: running ? clock.advance(to: context.date) : 0,
                                             reduceMotion: reduceMotion)
                stage(frame)
                    .onChange(of: frame.finished) { _, done in
                        if done { finished = true }
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
        }
    }

    private func stage(_ f: LaunchRoll.Frame) -> some View {
        ZStack {
            Color("LaunchBlack")
            mark(f.fill)
                .rotationEffect(.degrees(f.restAngle))
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
            Image("LaunchS").renderingMode(.template).foregroundStyle(.white)
        } else {
            ZStack {
                Image("LaunchS").renderingMode(.template)
                    .foregroundStyle(Self.palette[fill % Self.palette.count])
                Image("LaunchS").renderingMode(.template)
                    .foregroundStyle(Self.wash)
                Image("LaunchSRim").renderingMode(.template)
                    .foregroundStyle(Self.rim)
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
