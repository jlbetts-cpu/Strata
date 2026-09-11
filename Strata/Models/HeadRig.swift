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
    }

    let faces: [Expression: Face]
    /// The neutral face with its eyes shut. Nil: this head does not blink.
    let shut: UIImage?
    /// Crown to chin, as a share of the canvas's height.
    let contentHeight: CGFloat
    /// Where the chin sits, from the canvas's top.
    let chin: CGFloat

    init?(faces: [Expression: Face], shut: UIImage?, contentHeight: CGFloat, chin: CGFloat) {
        guard faces[.neutral] != nil else { return nil }
        self.faces = faces
        self.shut = shut
        self.contentHeight = contentHeight
        self.chin = chin
    }

    func face(_ expression: Expression) -> Face {
        faces[expression] ?? faces[.neutral]!
    }

    func has(_ expression: Expression) -> Bool { faces[expression] != nil }

    // MARK: - The creator's head

    /// The owner's own head from his portfolio, as a rig: its faces, and the
    /// eye positions measured for them in the portfolio's calibration mode
    /// (`hero-engine.js`, `FACES`) — the same numbers `HeadFace` holds.
    ///
    /// Stands in for a made head on a simulator that has no camera to make
    /// one with (`-strataSeedHead`).
    static func creator() -> HeadRig? {
        guard let neutral = UIImage(named: "HeadNeutral") else { return nil }
        func eye(_ x: CGFloat, _ y: CGFloat, ry: CGFloat = 0.0192) -> Eye {
            Eye(x: x, y: y, rx: 0.0385, ry: ry)
        }
        var faces: [Expression: Face] = [
            .neutral: Face(image: neutral, eyes: [eye(0.3999, 0.5176), eye(0.6018, 0.5265)])
        ]
        if let brows = UIImage(named: "HeadNeutralBrowsUp") {
            // Same canvas and eyes as neutral: the portfolio swaps the picture
            // and nothing else.
            faces[.browsUp] = Face(image: brows, eyes: [eye(0.3999, 0.5176), eye(0.6018, 0.5265)])
        }
        if let rest = UIImage(named: "HeadRest") {
            faces[.surprised] = Face(image: rest, eyes: [eye(0.4000, 0.5169), eye(0.6041, 0.5269)])
        }
        if let smile = UIImage(named: "HeadSmile") {
            faces[.smile] = Face(image: smile, eyes: [])
        }
        if let wink = UIImage(named: "HeadWink") {
            faces[.wink] = Face(image: wink, eyes: [eye(0.4000, 0.5169, ry: 0.0172)])
        }
        // The portfolio's canvas has more margin than a made head's: the
        // neutral face runs 0.113 to 0.898 of its height.
        return HeadRig(faces: faces, shut: UIImage(named: "HeadNeutralClosed"),
                       contentHeight: 0.785, chin: 0.8988)
    }
}
