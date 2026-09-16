import SwiftUI
import UIKit

/// A head, ready to live: its faces, where the eyes are on each, and how it
/// sits in its square.
///
/// Every face shares one square canvas and one alignment — the maker lines
/// each expression up by the eyes — so changing face never moves the head,
/// and an iris can glide from where it sits on one face to where it sits on
/// the next. That is what lets `LivingHeadView` morph rather than cut.
///
/// The eyes are drawn, as in the portfolio: the photograph's own eyes are
/// painted over with the person's own eye-white, and an iris tinted with
/// their own iris colour is drawn on top, clipped to their own lids. Nothing
/// is placed by hand — the maker measures all of it.
nonisolated struct HeadRig: @unchecked Sendable {

    nonisolated struct RGB: Codable, Equatable, Sendable {
        var r: Double
        var g: Double
        var b: Double

        var color: Color { Color(red: r, green: g, blue: b) }

        func scaled(_ factor: Double) -> RGB {
            RGB(r: min(r * factor, 1), g: min(g * factor, 1), b: min(b * factor, 1))
        }
    }

    /// One eye's opening on one face. Canvas fractions, top-left origin.
    nonisolated struct Eye: Codable, Equatable, Sendable {
        var x: CGFloat
        var y: CGFloat
        /// Half the opening's width and height.
        var rx: CGFloat
        var ry: CGFloat
        /// Radians: the tilt of the line from one corner of the eye to the other.
        var angle: Double = 0
        /// The opening's outline, which the iris is clipped to. Nil clips to an
        /// ellipse from `rx`/`ry` — how the portfolio's faces were calibrated.
        var outline: [CGPoint]? = nil
        /// The person's own iris colour. Nil draws the portfolio's near-black.
        var iris: RGB? = nil
    }

    nonisolated enum Expression: String, Codable, CaseIterable, Sendable {
        case neutral
        /// Neutral with the brows raised: the brow flash, the People's
        /// Eyebrow and the double take all swap to it. For a made head it is
        /// the "raise your eyebrows" capture.
        case browsUp
        /// The portfolio's "rest" face, for the creator's head.
        case surprised
        case smile
        case wink
    }

    nonisolated struct Face: @unchecked Sendable {
        let image: UIImage
        /// Where irises are drawn. Empty means the eyes are the photograph's
        /// own — a grin narrows them past the point where an iris sits right.
        let eyes: [Eye]
        /// **This face with its eyes shut.** The creator has one for every
        /// face; a made head has one for neutral, raised brows and surprised,
        /// each derived from its own blink (`HeadDerivation.lidPatch`), so a
        /// blink changes the lids and nothing else. Nil: this face does not
        /// blink.
        var shut: UIImage? = nil
    }

    let faces: [Expression: Face]
    /// Faces that pop straight in, like a grin, instead of morphing. The
    /// creator's grin and wink; on a made head, the faces whose silhouette
    /// overlaps neutral's closely enough that a hard swap does not move the
    /// head (`GridConstants.headPopIoU`).
    let popsIn: Set<Expression>
    /// Crown to chin, as a share of the canvas's height.
    let contentHeight: CGFloat
    /// Where the chin sits, from the canvas's top.
    let chin: CGFloat

    /// The neutral face with its eyes shut. Nil: this head does not blink.
    var shut: UIImage? { faces[.neutral]?.shut }

    /// `shut` fills the neutral face's blink when it has none of its own.
    init?(faces: [Expression: Face], shut: UIImage? = nil, popsIn: Set<Expression> = [],
          contentHeight: CGFloat, chin: CGFloat) {
        guard var neutral = faces[.neutral] else { return nil }
        var faces = faces
        if neutral.shut == nil, let shut {
            neutral.shut = shut
            faces[.neutral] = neutral
        }
        self.faces = faces
        self.popsIn = popsIn
        self.contentHeight = contentHeight
        self.chin = chin
    }

    /// The shut eyes for one face, if it has them.
    func shut(on expression: Expression) -> UIImage? { faces[expression]?.shut }

    /// Every face that can blink.
    var shutFaces: Set<Expression> { Set(faces.compactMap { $0.value.shut == nil ? nil : $0.key }) }

    func face(_ expression: Expression) -> Face {
        faces[expression] ?? faces[.neutral]!
    }

    func has(_ expression: Expression) -> Bool { faces[expression] != nil }

    /// **The same head in a film look**: every face through the real
    /// pipeline, keeping its outline, and the drawn irises graded by the same
    /// colour maths so the eyes belong to the face they sit in. Slow enough to
    /// be done off the main actor — see `HeadStore.setLook(_:)`.
    func dressed(in look: FilmLook) -> HeadRig {
        guard look.kind != .none else { return self }
        let renderer = FilmLookRenderer.shared
        var dressedFaces: [Expression: Face] = [:]
        for (expression, face) in faces {
            let eyes = face.eyes.map { eye -> Eye in
                var graded = eye
                if let iris = eye.iris {
                    let out = look.graded(FilmLook.RGB(iris.r, iris.g, iris.b))
                    graded.iris = RGB(r: out.r, g: out.g, b: out.b)
                }
                return graded
            }
            dressedFaces[expression] = Face(image: renderer.renderKeepingShape(face.image, look: look), eyes: eyes,
                                            shut: face.shut.map { renderer.renderKeepingShape($0, look: look) })
        }
        return HeadRig(faces: dressedFaces, popsIn: popsIn, contentHeight: contentHeight, chin: chin) ?? self
    }

    /// Every face this head really has, in a fixed order so two heads with the
    /// same faces behave the same way.
    var expressions: [Expression] { Expression.allCases.filter(has) }

    /// The faces a tap's expression can use. See `HeadTake.available`.
    var takeFaces: Set<Expression> { Set(expressions) }

    // MARK: - The creator's head

    /// Built once. Onboarding used to build a rig in every body pass.
    static let creatorRig: HeadRig? = creator()

    /// The owner's own head from his portfolio, as a rig: its faces, their
    /// shut twins, and the eye positions measured for them in the portfolio's
    /// calibration mode (`hero-engine.js`, `FACES`).
    ///
    /// **It is the standard every made head is held to** (owner, 2026-09-16),
    /// and it plays in the same engine. It also stands in for a made head on a
    /// simulator that has no camera to make one with (`-strataSeedHead`).
    static func creator() -> HeadRig? {
        guard let neutral = UIImage(named: "HeadNeutral") else { return nil }
        func eye(_ x: CGFloat, _ y: CGFloat, ry: CGFloat = 0.0192) -> Eye {
            Eye(x: x, y: y, rx: 0.0385, ry: ry)
        }
        let neutralShut = UIImage(named: "HeadNeutralClosed")
        var faces: [Expression: Face] = [
            .neutral: Face(image: neutral, eyes: [eye(0.3999, 0.5176), eye(0.6018, 0.5265)], shut: neutralShut)
        ]
        if let brows = UIImage(named: "HeadNeutralBrowsUp") {
            // Same canvas and eyes as neutral: the portfolio swaps the picture
            // and nothing else, so neutral's shut eyes are its shut eyes too.
            faces[.browsUp] = Face(image: brows, eyes: [eye(0.3999, 0.5176), eye(0.6018, 0.5265)], shut: neutralShut)
        }
        if let rest = UIImage(named: "HeadRest") {
            faces[.surprised] = Face(image: rest, eyes: [eye(0.4000, 0.5169), eye(0.6041, 0.5269)],
                                     shut: UIImage(named: "HeadRestClosed"))
        }
        if let smile = UIImage(named: "HeadSmile") {
            faces[.smile] = Face(image: smile, eyes: [], shut: UIImage(named: "HeadSmileClosed"))
        }
        if let wink = UIImage(named: "HeadWink") {
            faces[.wink] = Face(image: wink, eyes: [eye(0.4000, 0.5169, ry: 0.0172)],
                                shut: UIImage(named: "HeadWinkClosed"))
        }
        // The portfolio's canvas has more margin than a made head's: the
        // neutral face runs 0.113 to 0.898 of its height.
        return HeadRig(faces: faces, popsIn: [.smile, .wink], contentHeight: 0.785, chin: 0.8988)
    }
}
