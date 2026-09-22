import SwiftUI

/// **A round eye and a lid that cuts across it, which is the whole rig.**
///
/// The owner: "do you know Sackboy? I feel like that's lowkey a good
/// recommendation, I love Sackboy and the expressive eyes."
///
/// It is a good recommendation, and it is a different mechanic from the two
/// strokes this replaced. A Sackperson has **button eyes** — round, fixed,
/// identical in every expression — and everything the face says is said by
/// the sackcloth LID coming down over them at an angle. No eyebrows: the lid
/// IS the brow. That is why the character reads from across a room with
/// almost nothing drawn.
///
/// Two parts, and between them far more range than two strokes had:
///
/// - **How far the lid is down** gives wide, level, heavy, shut. A blink is
///   this going to one and back.
/// - **Which way the lid is tilted** gives the feeling. Inner corners down is
///   determined or cross; outer corners down is worried. It is the same lid
///   in both, turned.
/// - **The lower lid coming up** is the squint that reads as a smile, which
///   is the one thing eyes do that a mouth usually gets credit for.
/// - **The pupil** gives gaze on top of all of it, for free.
///
/// Everything is a number, everything interpolates, and the whole thing is
/// still two shapes an eye. Drawn light on the folder's own pocket, because a
/// dark button on a dark pocket is a hole.
struct FolderFace: View {
    var expression: FaceExpression = .idle
    /// The diameter of one eye. Everything else is derived, so the face
    /// scales as one thing.
    var eyeWidth: CGFloat = 34
    var ink: Color = .white

    private var diameter: CGFloat { eyeWidth * expression.scale }
    /// The gap is fixed to the BASE size rather than the scaled one, so eyes
    /// that widen do not also drift apart.
    private var gap: CGFloat { eyeWidth * 1.05 }

    var body: some View {
        HStack(spacing: gap) {
            eye(expression.left, mirrored: false)
            eye(expression.right, mirrored: true)
        }
        .offset(x: expression.gaze.width,
                y: expression.gaze.height + expression.drop)
    }

    private func eye(_ eye: Eye, mirrored: Bool) -> some View {
        let side: CGFloat = mirrored ? -1 : 1
        // A blink closes whatever lid is already there rather than replacing
        // it, so it composes with a squint instead of fighting it.
        let shut = 1 - expression.openness
        let lid = eye.lid + (1 - eye.lid) * shut

        // **A solid dot, because that is what a button is.** The first
        // version drew a white eye with a dark pupil inside it, which is a
        // cartoon eye and not what the reference has: the owner, on sight,
        // "those aren't the Sackboy eyes, Sackboy eyes are dots." A
        // Sackperson has BUTTONS — one solid shape each — and everything the
        // face says is said by the lid cutting across them. No sclera, no
        // pupil, nothing inside.
        //
        // It also folds the two ideas together: a lid over a dot makes the
        // same arcs the old two-stroke face made, so nothing that read well
        // before is lost, and the lid angle adds everything it could not do.
        return Circle()
            .fill(ink)
            .frame(width: diameter, height: diameter)
            .offset(x: side * expression.pupilSplit * eyeWidth)
        .mask {
            LidMask(lid: lid, lower: eye.lower, tilt: eye.tilt * side)
        }
    }
}

/// The open part of an eye: everything between the upper lid and the lower
/// one, turned by the lid's tilt.
struct LidMask: Shape {
    var lid: CGFloat
    var lower: CGFloat
    var tilt: Double

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(lid, AnimatablePair(lower, CGFloat(tilt))) }
        set {
            lid = newValue.first
            lower = newValue.second.first
            tilt = Double(newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let top = rect.minY + rect.height * min(max(lid, 0), 1)
        let bottom = rect.maxY - rect.height * min(max(lower, 0), 1)
        // Wider than the eye, so turning it never uncovers a corner.
        let wide = rect.width * 3
        var path = Path()
        path.addRect(CGRect(x: centre.x - wide / 2, y: top,
                            width: wide, height: max(bottom - top, 0)))
        return path.applying(
            CGAffineTransform(translationX: centre.x, y: centre.y)
                .rotated(by: tilt * .pi / 180)
                .translatedBy(x: -centre.x, y: -centre.y))
    }
}

/// One eye's lid, in three numbers.
struct Eye: Equatable {
    /// How far the upper lid is down. 0 wide, 1 shut.
    var lid: CGFloat = 0.12
    /// Which way the lid is turned, in degrees. **Negative drops the INNER
    /// corner**, which is determined or cross; positive drops the outer one,
    /// which is worried. Mirrored for the right eye, so the pair is
    /// symmetrical without two sets of numbers.
    var tilt: Double = 0
    /// How far the lower lid is up. The squint that reads as a smile.
    var lower: CGFloat = 0
}

/// **A face, as data.**
struct FaceExpression: Equatable {
    var left = Eye()
    var right = Eye()
    /// 1 open, 0 shut. A blink is this going to zero and back, and it closes
    /// whatever lid is already there.
    var openness: CGFloat = 1
    /// Pushes the two eyes apart. Only dizzy uses it, and it is the one
    /// thing a pair does that a lid cannot.
    var pupilSplit: CGFloat = 0
    /// Where the pair is looking, in points.
    var gaze: CGSize = .zero
    /// How far down the face sits. Sleepy sits lower, which is most of why
    /// it reads as sleepy.
    var drop: CGFloat = 0
    /// **How big the eyes are, as a multiple.**
    ///
    /// The owner, on the buttons: "I like them, but also I did like when they
    /// were smaller, like the dots." So the resting size came down and this
    /// is what lets an expression have it back — eyes widen with surprise
    /// and narrow when somebody is not really paying attention, which is a
    /// real thing faces do and which a fixed size cannot say.
    ///
    /// Small at rest is also the right default here: two small dots on a
    /// large pocket read as a face on an object, and two large ones read as
    /// a character wearing the object as a body.
    var scale: CGFloat = 1

    // MARK: - The set

    /// **Most of these are not happy, and that proportion is the point.** A
    /// folder that can be bored is a folder that wants something put in it; a
    /// folder wearing a constant grin is wallpaper by the second week.
    ///
    /// None is ever reached by somebody NOT doing something.
    static let idle = FaceExpression()

    /// The squint from below. Eyes smile with the lower lid, which is the one
    /// thing they do that a mouth usually gets credit for.
    static let happy = FaceExpression(
        left: Eye(lid: 0.06, lower: 0.44), right: Eye(lid: 0.06, lower: 0.44),
        scale: 1.16)

    static let sleepy = FaceExpression(
        left: Eye(lid: 0.60, lower: 0.06), right: Eye(lid: 0.60, lower: 0.06),
        drop: 4, scale: 1.05)

    static let bored = FaceExpression(
        left: Eye(lid: 0.40), right: Eye(lid: 0.40))

    /// Inner corners down.
    static let annoyed = FaceExpression(
        left: Eye(lid: 0.26, tilt: -17), right: Eye(lid: 0.26, tilt: -17))

    /// Outer corners down, and a little squint under it.
    static let nervous = FaceExpression(
        left: Eye(lid: 0.14, tilt: 15, lower: 0.16),
        right: Eye(lid: 0.14, tilt: 15, lower: 0.16))

    /// One lid up, one down. Asymmetry is what reads as thinking rather than
    /// as feeling, and it is the only face here that is not a mirror.
    static let confused = FaceExpression(
        left: Eye(lid: 0.34, tilt: -10), right: Eye(lid: 0.02, tilt: 6))

    /// Wide, with the pupils gone their own ways.
    static let dizzy = FaceExpression(
        left: Eye(lid: 0.02), right: Eye(lid: 0.02), pupilSplit: 0.13, scale: 1.22)

    // MARK: - Resting

    /// Wide awake and level.
    static let wide = FaceExpression(
        left: Eye(lid: 0.02), right: Eye(lid: 0.02), scale: 1.18)

    /// Half lidded and calm, the face of something content to wait.
    static let easy = FaceExpression(
        left: Eye(lid: 0.30, lower: 0.10), right: Eye(lid: 0.30, lower: 0.10),
        scale: 0.92)

    /// A small asymmetry: attentive rather than emotional.
    static let curious = FaceExpression(
        left: Eye(lid: 0.05), right: Eye(lid: 0.22, tilt: -5))

    /// What a resting folder drifts between, all of them neutral. Drifting
    /// between pleasant idles is the illusion of life; drifting towards sad
    /// is a guilt machine.
    static let restingSet: [FaceExpression] = [.idle, .wide, .easy, .curious]

    static let all: [(String, FaceExpression)] = [
        ("Idle", .idle), ("Happy", .happy), ("Sleepy", .sleepy),
        ("Bored", .bored), ("Annoyed", .annoyed), ("Nervous", .nervous),
        ("Confused", .confused), ("Dizzy", .dizzy),
        ("Wide", .wide), ("Easy", .easy), ("Curious", .curious)
    ]
}
