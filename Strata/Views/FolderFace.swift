import SwiftUI

/// **Two strokes, and every face this folder can make is made of them.**
///
/// The owner: "I want the folder to be extremely expressive with idle
/// animations." And from the reference, the constraint that makes it read
/// premium rather than cartoonish: the whole emotional range in
/// `Folder icons with feelings` is two line segments. No mouth, no eyebrows,
/// no character art.
///
/// **Every one of the seven faces is the same two chevrons at a curvature and
/// an angle**, which is the thing that turns a set of drawings into a system:
///
///     ^     bend +1, angle 0       arched, happy
///     u     bend -1, angle 0       cupped, sleepy
///     >     bend +1, angle +90     a chevron on its side
///     <     bend +1, angle -90
///     \     bend  0, angle +18     a straight line, tilted
///     |     bend  0, angle +90
///     -     bend  0, angle 0       flat, bored
///
/// So `> <` is not a drawing of a nervous face, it is two arches rotated a
/// quarter turn, and the app can move continuously between any two of these
/// rather than cutting between pictures.
///
/// **This is built as a SwiftUI `Shape`, deliberately, and not in Rive or
/// Lottie or GSAP.** All three were suggested and all three are the right
/// answer to a different question. Lottie is pre-rendered, so it cannot be
/// parametric at all — the entire point here is that the numbers are live.
/// Rive is genuinely good at state machines, but it is a runtime to embed, a
/// binary asset to keep in step with the code, a licence, and an editor round
/// trip for every tweak. GSAP's MorphSVG is a web library.
///
/// SwiftUI already does the thing they were all being reached for: a `Shape`
/// with `animatableData` is interpolated by the system, so `bend` can be
/// animated with the app's own springs, by the app's own motion ladder, for
/// free, with no asset and nothing to keep in sync. Rotation, squash and
/// gaze are view modifiers, which animate natively too — so the whole
/// parametric rig is four numbers and no dependency.
struct EyeStroke: Shape {
    /// -1 cupped, 0 flat, +1 arched. Interpolated by SwiftUI.
    var bend: CGFloat

    var animatableData: CGFloat {
        get { bend }
        set { bend = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        // The control point of a quadratic sits at twice the visual height of
        // the curve, so the reach is halved to make `bend` mean what it says.
        let reach = rect.height * bend
        path.move(to: CGPoint(x: rect.minX, y: midY + reach / 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: midY + reach / 2),
            control: CGPoint(x: rect.midX, y: midY - reach * 1.5)
        )
        return path
    }
}

/// One eye's two numbers, plus the one special case.
struct Eye: Equatable {
    var bend: CGFloat = 0
    var angle: Double = 0
}

/// **A face, as data.** Everything an expression is: two eyes, where they are
/// looking, how open they are, and whether the dizzy cross is showing.
struct FaceExpression: Equatable {
    var left = Eye()
    var right = Eye()
    /// 1 open, 0 shut. A blink is this going to zero and back.
    var openness: CGFloat = 1
    /// The dizzy `x`, which is the one face two strokes cannot make: a second
    /// mirrored stroke fades in over the first.
    var cross: Double = 0
    /// Where the pair is looking, in points.
    var gaze: CGSize = .zero
    /// How far down the face sits. Sleepy sits lower, which is most of why it
    /// reads as sleepy.
    var drop: CGFloat = 0

    // MARK: - The seven, and the one they rest at

    /// **Six of the reference's seven are not happy, and that proportion is
    /// the point.** A folder that can be bored is a folder that wants
    /// something put in it; a folder wearing a constant grin is wallpaper by
    /// the second week.
    ///
    /// None of these are ever reached by the ABSENCE of somebody doing
    /// something. They are reactions to what is happening now, and to what is
    /// in the folder. That line is the whole of the Tamagotchi decision.
    static let idle = FaceExpression(
        left: Eye(bend: 0.28), right: Eye(bend: 0.28))

    static let happy = FaceExpression(
        left: Eye(bend: 0.95), right: Eye(bend: 0.95))

    static let sleepy = FaceExpression(
        left: Eye(bend: -0.5), right: Eye(bend: -0.5),
        openness: 0.72, drop: 5)

    static let bored = FaceExpression(
        left: Eye(bend: 0), right: Eye(bend: 0), openness: 0.9)

    static let annoyed = FaceExpression(
        left: Eye(bend: 0, angle: 26), right: Eye(bend: 0, angle: -26))

    /// `> <`, which is the reference's own title.
    static let nervous = FaceExpression(
        left: Eye(bend: 0.85, angle: 90), right: Eye(bend: 0.85, angle: -90))

    /// `> |`, the raised eyebrow, and the only asymmetric one. Asymmetry is
    /// what reads as thinking rather than as feeling.
    static let confused = FaceExpression(
        left: Eye(bend: 0.75, angle: 90), right: Eye(bend: 0, angle: 90))

    static let dizzy = FaceExpression(
        left: Eye(bend: 0, angle: 34), right: Eye(bend: 0, angle: -34), cross: 1)

    static let all: [(String, FaceExpression)] = [
        ("Idle", .idle), ("Happy", .happy), ("Sleepy", .sleepy),
        ("Bored", .bored), ("Annoyed", .annoyed), ("Nervous", .nervous),
        ("Confused", .confused), ("Dizzy", .dizzy)
    ]
}

/// Draws a `FaceExpression`. Knows nothing about folders, moods or timing, so
/// it can be dropped on anything and tested on its own.
struct FolderFace: View {
    var expression: FaceExpression = .idle
    /// The width of one eye. Everything else is derived, so the face scales
    /// as one thing.
    var eyeWidth: CGFloat = 34
    var ink: Color = .white

    private var thickness: CGFloat { max(2, eyeWidth * 0.135) }
    private var eyeHeight: CGFloat { eyeWidth * 0.72 }
    private var gap: CGFloat { eyeWidth * 0.62 }

    var body: some View {
        HStack(spacing: gap) {
            eye(expression.left)
            eye(expression.right)
        }
        .offset(x: expression.gaze.width,
                y: expression.gaze.height + expression.drop)
    }

    private func eye(_ eye: Eye) -> some View {
        ZStack {
            stroke(bend: eye.bend)
            // **The dizzy cross, and the first version of it did not cross.**
            // A mirrored copy of a straight line at +34 degrees is a line at
            // +34 degrees, so `x x` rendered as `\ /`. What makes an x is the
            // second stroke rotated to the OPPOSITE angle, which inside an
            // already-rotated frame is twice the angle back.
            stroke(bend: eye.bend)
                .rotationEffect(.degrees(-2 * eye.angle))
                .opacity(expression.cross)
        }
        .frame(width: eyeWidth, height: eyeHeight)
        .rotationEffect(.degrees(eye.angle))
        // Squashing the Y axis is the whole of a blink, and it is also what
        // makes a squint: a blink is this at zero for a tenth of a second.
        .scaleEffect(x: 1, y: expression.openness, anchor: .center)
    }

    private func stroke(bend: CGFloat) -> some View {
        EyeStroke(bend: bend)
            .stroke(ink, style: StrokeStyle(lineWidth: thickness,
                                            lineCap: .round, lineJoin: .round))
    }
}
