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
    /// **0 a line, 1 a dot**, and a dot is not a different drawing.
    ///
    /// The owner: "the eyes should be a bit more expressive, I like dot eyes."
    ///
    /// A round-capped stroke of zero length IS a circle, so a dot is this
    /// same path with its horizontal reach taken to nothing and its weight
    /// taken up. That means the face can travel continuously between a line
    /// and a dot rather than cutting between two pictures, which is the same
    /// property that made the seven original states one system.
    var dot: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bend, dot) }
        set { bend = newValue.first; dot = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        // The stroke closes towards its own centre as it becomes a dot.
        let half = rect.width / 2 * (1 - min(max(dot, 0), 1))
        let left = rect.midX - half, right = rect.midX + half
        // The control point of a quadratic sits at twice the visual height of
        // the curve, so the reach is halved to make `bend` mean what it says.
        let reach = rect.height * bend * (1 - min(max(dot, 0), 1))
        path.move(to: CGPoint(x: left, y: midY + reach / 2))
        path.addQuadCurve(
            to: CGPoint(x: right, y: midY + reach / 2),
            control: CGPoint(x: rect.midX, y: midY - reach * 1.5)
        )
        return path
    }
}

/// One eye's two numbers, plus the one special case.
struct Eye: Equatable {
    var bend: CGFloat = 0
    var angle: Double = 0
    /// 0 a line, 1 a dot. See `EyeStroke.dot`.
    var dot: CGFloat = 0
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

    // MARK: - The resting repertoire

    /// **Faces the folder wears while nothing is happening to it.**
    ///
    /// The owner: "it should switch eyes naturally, not keep the same eyes
    /// and then never change."
    ///
    /// A face that holds one expression forever is a logo. These are what it
    /// drifts between while it is simply sitting there, and every one of them
    /// is NEUTRAL: attentive, calm, looking about. None is a judgement and
    /// none can be reached by somebody failing to do something, which is the
    /// line the whole direction rests on. Drifting between pleasant idles is
    /// the illusion of life; drifting towards sad is a guilt machine.
    static let dots = FaceExpression(
        left: Eye(dot: 1), right: Eye(dot: 1))

    /// Half closed and calm, the face of something content to wait.
    static let easy = FaceExpression(
        left: Eye(bend: 0.55), right: Eye(bend: 0.55), openness: 0.85)

    /// One dot, one arc. Asymmetry reads as attention.
    static let curious = FaceExpression(
        left: Eye(bend: 0.30), right: Eye(dot: 1))

    /// What a resting folder chooses from. Ordered so the plainest is first
    /// and it starts there.
    static let restingSet: [FaceExpression] = [.idle, .dots, .easy, .curious]

    static let all: [(String, FaceExpression)] = [
        ("Idle", .idle), ("Happy", .happy), ("Sleepy", .sleepy),
        ("Bored", .bored), ("Annoyed", .annoyed), ("Nervous", .nervous),
        ("Confused", .confused), ("Dizzy", .dizzy),
        ("Dots", .dots), ("Easy", .easy), ("Curious", .curious)
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
            stroke(bend: eye.bend, dot: eye.dot)
            // **The dizzy cross, and the first version of it did not cross.**
            // A mirrored copy of a straight line at +34 degrees is a line at
            // +34 degrees, so `x x` rendered as `\ /`. What makes an x is the
            // second stroke rotated to the OPPOSITE angle, which inside an
            // already-rotated frame is twice the angle back.
            stroke(bend: eye.bend, dot: eye.dot)
                .rotationEffect(.degrees(-2 * eye.angle))
                .opacity(expression.cross)
        }
        .frame(width: eyeWidth, height: eyeHeight)
        .rotationEffect(.degrees(eye.angle))
        // Squashing the Y axis is the whole of a blink, and it is also what
        // makes a squint: a blink is this at zero for a tenth of a second.
        .scaleEffect(x: 1, y: expression.openness, anchor: .center)
    }

    private func stroke(bend: CGFloat, dot: CGFloat = 0) -> some View {
        // A dot is the same stroke closed up and thickened: the round cap is
        // the circle. 2.6x is the weight at which a dot reads as an eye
        // rather than as a full stop.
        EyeStroke(bend: bend, dot: dot)
            .stroke(ink, style: StrokeStyle(lineWidth: thickness * (1 + 2.6 * dot),
                                            lineCap: .round, lineJoin: .round))
    }
}
