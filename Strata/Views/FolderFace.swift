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
    /// **Dark glass, not dark paint.**
    ///
    /// The owner: "make sure the light in the eyes is white, and the eye
    /// matches the design system like the glass and blur, and don't make the
    /// eyes so stark."
    ///
    /// A flat 88% black disc was a hole cut in the pocket: the one element on
    /// this screen that was not made of the same stuff as everything else.
    /// Every other dark surface in Apollo is Liquid Glass with a black tint —
    /// the camera's corner button, the film tray — so a button eye is the
    /// same recipe at 26 points. It takes the pocket's own colour and light
    /// through it, which is what stops it reading as a cut-out, and it is
    /// what a real button does: a glassy thing sitting on cloth, not a hole
    /// in it.
    ///
    /// The tint is a fraction of what the fill was, because glass does the
    /// rest of the work.
    var tint: Double = 0.56

    private var diameter: CGFloat { eyeWidth * expression.scale }
    /// **Set wide, because close-set eyes are not cute.**
    ///
    /// The owner: "the eyes are too close to each other and too large still,
    /// I want the eyes to genuinely be so adorable."
    ///
    /// That is not a taste note, it is anatomy: what reads as endearing in a
    /// face is the infant schema — small features, set LOW and WIDE on a
    /// large head. Close-set eyes read as intense, and large ones as a
    /// cartoon. Small, far apart and a touch low is the whole recipe, and it
    /// is why the folder should look like an object with a face rather than
    /// a character with a body.
    ///
    /// Fixed to the BASE size rather than the scaled one, so eyes that widen
    /// do not also drift apart.
    private var gap: CGFloat { eyeWidth * 1.85 }

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
        return Color.clear
            .frame(width: diameter, height: diameter)
            .eyeGlass(tint: tint)
            // **A dark body inside the glass, so the rim stops out-shouting
            // it.**
            //
            // Glass alone made a bubble rather than a button: zoomed in, the
            // brightest thing in the eye was its own refractive edge, and the
            // genuinely dark part was a thin crescent. A button's edge is not
            // supposed to be its loudest feature.
            //
            // Inset by a sixteenth, so the rim survives as a thin edge around
            // a solid centre — which is what a button sewn on cloth looks
            // like, and what the glass was there to suggest in the first
            // place.
            .overlay {
                Circle()
                    .fill(.black.opacity(0.46))
                    .padding(diameter * 0.06)
            }
            // **The light, and it is white.** It was a quarter of the eye and
            // blurred, which behaves like a second pale pupil rather than a
            // glint; a real button's shine is small and sharp. Smaller,
            // harder and brighter now, and it goes on last so nothing sits
            // over it.
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: diameter * 0.16, height: diameter * 0.16)
                    .blur(radius: diameter * 0.012)
                    .offset(x: diameter * 0.21, y: diameter * 0.18)
            }
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
    ///
    /// **Nearly nothing at rest.** It sat at 0.12, which flat-tops a small
    /// circle: zoomed in, the buttons read as domes rather than as buttons,
    /// and a flat top is the one thing a button does not have. The lid earns
    /// its place in the expressions; at rest it should be almost invisible.
    var lid: CGFloat = 0.03
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
        left: Eye(lid: 0.02), right: Eye(lid: 0.20, tilt: -5))

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


private extension View {
    /// The app's own glass, at eye size. The same family as the camera's
    /// corner button and the film tray, so the face is made of what the rest
    /// of the screen is made of.
    @ViewBuilder
    func eyeGlass(tint: Double) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.clear.tint(.black.opacity(tint)), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().fill(.black.opacity(tint * 0.8)) }
        }
    }
}
