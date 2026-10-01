import SwiftUI

/// **Every shadow in the app, in one place, on three rungs.**
///
/// The owner, 2026-09-30: "make sure shadows are consistent — they feel a bit
/// too strong on the buttons and stuff right now, especially for an ethereal
/// theme."
///
/// Both halves of that are true and the first one caused the second. Counted
/// before this existed there were nineteen `.shadow` calls across the app and
/// no two agreed: elevation opacities of 0.032, 0.04, 0.10, 0.12 and 0.22 at
/// radii of 4, 12, 14 and 16, and legibility shadows at 0.35, 0.38, 0.40, 0.45
/// and 0.55 at radii of 3, 4, 6, 10 and 14. Nothing was reading as "one app's
/// light" because there wasn't one — each shadow was chosen against whatever
/// was on screen the day it was written.
///
/// **The two kinds are not the same thing and must never share a number.**
///
/// - `Elevation` says an object is OFF the page. It is a property of the
///   object, it is faint, and it gets fainter and wider the less the object is
///   claiming — which is the whole of the ethereal read: a shadow that only
///   gets lighter starts to look like a rendering mistake, one that gets lighter
///   AND wider reads as air.
/// - `Legibility` says white type is sitting on a photograph. It is a property
///   of the TEXT, not of a surface, it is much darker because it is fighting a
///   live camera feed, and it is not elevation at all. Lumping the two together
///   is how 0.40 ended up on a button.
///
/// `docs/design-system-future.md` §6 reserves shadow for things standing on
/// something, and the rungs here are exactly that rule counted out: what is
/// resting, what is hovering, what is in your hand.
enum Elevation {
    /// **Standing on the page.** A block in the tower.
    ///
    /// These are the numbers the owner settled the blocks on, kept exactly:
    /// wide and nearly nothing, so the tower has footing without the page
    /// carrying forty dark edges.
    case resting
    /// **Hovering over it.** A drawer over the map, a sheet, a portrait, a
    /// floating control.
    ///
    /// This is the rung that was wrong, and it was wrong in the obvious
    /// direction: 0.10 at a 12pt radius is three times a block's ink in two
    /// thirds of its spread, so the lightest objects on the page were throwing
    /// the darkest shadows on it. Half the ink over half again the radius.
    case floating
    /// **In your hand.** A block picked up, or one still falling.
    ///
    /// The only rung that is allowed to be seen, because here the shadow is
    /// INFORMATION — it is the gap between the thing and the page, and that gap
    /// is what the gesture is about. Still well down from the 0.22 it was.
    case carried

    var opacity: Double {
        switch self {
        case .resting: 0.032
        case .floating: 0.05
        case .carried: 0.14
        }
    }

    var radius: CGFloat {
        switch self {
        case .resting: 14
        case .floating: 20
        case .carried: 18
        }
    }

    var y: CGFloat {
        switch self {
        case .resting: 2
        case .floating: 6
        case .carried: 10
        }
    }

    /// **Dark mode multiplies rather than substituting a second number.**
    ///
    /// On a charcoal ground a shadow is most of what separates an object from
    /// the page, so taking it to the light value flattens the screen outright —
    /// but a second hand-written constant per rung is how the two appearances
    /// drifted apart in the first place. One factor, one cap, and the ladder
    /// keeps its shape in both.
    func opacity(in scheme: ColorScheme) -> Double {
        scheme == .dark ? min(opacity * 4, 0.45) : opacity
    }

    func color(in scheme: ColorScheme = .light) -> Color {
        .black.opacity(opacity(in: scheme))
    }
}

extension View {
    /// Lifts this view onto one of the three rungs.
    ///
    /// `scale` is for anything drawn at a cell size that is not the tower's —
    /// the Insights chart, a chip, a preview. A 14pt radius under a 34pt block
    /// is a shadow bigger than the thing casting it.
    func elevation(_ rung: Elevation, in scheme: ColorScheme = .light,
                   scale: CGFloat = 1) -> some View {
        shadow(color: rung.color(in: scheme),
               radius: rung.radius * scale, x: 0, y: rung.y * scale)
    }
}

/// **White type on a photograph, which is not elevation.**
///
/// One definition for every place the app sets light text over imagery it does
/// not control: the camera's chrome over a live lens, a title over a win's
/// photo, the widget's count over whatever is behind it. It was eight different
/// numbers doing this one job.
///
/// It is much darker than any `Elevation` rung on purpose, and that is the
/// point of keeping them apart: this is fighting a sunlit wall, not describing
/// how far off the page something is.
enum Legibility {
    /// Body and control-sized type and glyphs.
    static let ink: Double = 0.42
    static let radius: CGFloat = 6
    static let y: CGFloat = 1

    /// Display type — the camera's countdown. Large glyphs need the shadow
    /// spread over a bigger area or it reads as an outline around them.
    static let displayRadius: CGFloat = 14
}

extension View {
    /// The shadow that keeps white type readable over a photograph.
    func legibleOnImagery(display: Bool = false) -> some View {
        shadow(color: .black.opacity(Legibility.ink),
               radius: display ? Legibility.displayRadius : Legibility.radius,
               x: 0, y: display ? 0 : Legibility.y)
    }
}
