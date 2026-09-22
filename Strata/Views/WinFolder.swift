import SwiftUI

/// The folder's silhouette: a back plate with a tab, the shape everybody
/// already reads as "folder" without being told.
///
/// The tab is on the LEFT and the step down to the body is a curve rather
/// than a corner, which is what the reference draws and what keeps it from
/// looking like a file icon from 1994.
struct FolderBack: Shape {
    /// How much of the width the tab takes.
    var tabWidth: CGFloat = 0.40
    /// How far below the tab's top the body sits, as a fraction of height.
    /// It was 0.11 and the notch did not read at all at 150pt: the folder
    /// looked like a rounded rectangle with photographs behind it.
    var step: CGFloat = 0.16

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let r = min(w, h) * 0.135
        let bodyTop = rect.minY + h * step
        let tabEnd = rect.minX + w * tabWidth
        let slope = w * 0.07

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: tabEnd - slope, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: tabEnd + slope * 0.4, y: bodyTop),
                       control: CGPoint(x: tabEnd + slope * 0.1, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: bodyTop))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: bodyTop + r),
                       control: CGPoint(x: rect.maxX, y: bodyTop))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// **A folder of wins, with a face on the pocket.**
///
/// The owner picked the semi-translucent reference, so the pocket is a
/// material rather than a fill: what is inside is genuinely behind it and
/// genuinely blurred, which is why the folder reads as holding something
/// rather than as a picture of a folder.
///
/// **`tint` is the whole customisation story and it is one parameter.** Every
/// colour in here is derived from it, so a folder is recoloured by changing
/// one value rather than by redrawing anything. Nothing else in this view
/// knows what colour it is.
///
/// Apollo is a dark app, so the construction is inverted from the light
/// reference: the plate is a deep tint and the pocket is a frosted lighter
/// one, rather than the other way round. The face is the app's own white.
struct WinFolder: View {
    /// Kept for the accessibility label, which still has to say what this
    /// is and how much is in it. Nothing is drawn from either.
    var title: String = "Wins"
    var count: Int = 0
    var tint: Color = WinFolder.defaultTint
    /// **What is in it, as wins rather than as pictures.** It took
    /// `[UIImage]`, which meant a day made of wins somebody TYPED showed an
    /// empty folder: the tower drew those as plain coloured blocks and
    /// dropping them lost the whole outside of the folder on any day without
    /// photographs. A card with no image is its colour, exactly as the block
    /// was.
    var contents: [ScatterWin] = []
    var expression: FaceExpression = .idle
    /// Off for a still. On, the face blinks, looks around and breathes.
    var isAlive: Bool = true


    /// A neutral that belongs to the greyscale rather than arriving from
    /// outside it. A folder is a container, not an accent.
    static let defaultTint = Color(red: 0.36, green: 0.41, blue: 0.60)

    @State private var idle = FolderIdle()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var live: FaceExpression {
        var face = expression
        guard isAlive, !reduceMotion else { return face }
        // A blink closes whatever lid is already there, so it composes with a
        // squint rather than replacing it. `FolderIdle.flatten` is gone with
        // the strokes: on a round eye a lid coming down IS the blink, and
        // there is no curve left to flatten on the way.
        face.openness *= idle.blink
        face.gaze.width += idle.gaze.width
        face.gaze.height += idle.gaze.height + idle.breath
        return face
    }

    /// **How full the folder looks, 0 to 1.**
    ///
    /// The owner: "a fun little detail of the folder, the fuller it gets."
    ///
    /// Twelve is a full day, so that is the top of the scale. Three things
    /// move with it and all of them are small: the stack spreads wider, the
    /// pocket swells as though there is something behind it, and the shadow
    /// deepens because a fuller folder is a heavier one. None of them is
    /// legible on its own, which is the point — it should be noticed as the
    /// folder getting fuller rather than as an animation happening.
    private var fullness: CGFloat {
        min(CGFloat(max(count, contents.count)) / 12, 1)
    }

    var body: some View {
        // **The aspect is established BEFORE the geometry is read, not
        // after.** A `GeometryReader` has no intrinsic size of its own, so
        // inside a scrolling stack it is proposed an unbounded height and
        // `.aspectRatio` applied outside it has nothing to work from: the
        // whole folder rendered at zero and the lab came up black. Reading
        // the size of a shape that already has one is the way round.
        Color.clear
            .aspectRatio(1.04, contentMode: .fit)
            .overlay { folder }
            .animation(GridConstants.naturalSettle, value: fullness)
            .onAppear { if isAlive { idle.reach = 5; idle.start() } }
            .onDisappear { idle.stop() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(count) wins")
    }

    private var folder: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let shape = FolderBack()

            ZStack {
                // 1. The plate.
                LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.62)],
                               startPoint: .top, endPoint: .bottom)
                    .clipShape(shape)

                // 2. The wins, NOT clipped to the plate. They rise and
                //    spread as the pocket falls away from them.
                //
                // They were, and it was the thing that kept it from reading
                // as a folder: a photograph sitting flush with the top edge
                // is printed ON the folder, where one standing proud of it is
                // IN the folder. Every reference does this and it is the
                // whole trick. Nothing is lost by letting them out, because
                // the pocket in front still holds them down.
                peeking(width: w, height: h)

                // 3. The pocket, which is the hinge. A material, so the wins behind it are really
                //    blurred rather than drawn faint, which is the difference
                //    between a folder holding things and a folder printed
                //    with a picture of them.
                pocket(width: w, height: h)

                // 4. The face, on the pocket, and the name under it.
                // **The face, and nothing else written on it.**
                //
                // It carried the title and the count until the owner saw it
                // on the real screen: "the Today and 9 aren't important on
                // the folder because they are already on the top left." They
                // were, in bigger type, six points away. Two labels saying
                // the same thing is one of them being noise, and the one to
                // lose is the one on the object rather than the one in the
                // header that every other screen has too.
                //
                // It also gives the face the pocket to itself, which is what
                // it wanted: a face with a caption under it reads as a logo.
                FolderFace(expression: live, eyeWidth: w * 0.108)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, h * 0.11)
            }
            .compositingGroup()
            // The one shadow, and it is the folder standing on the ground
            // rather than chrome pretending to float.
            // A fuller folder is a heavier one.
            .shadow(color: .black.opacity(0.42 + 0.12 * fullness),
                    radius: h * (0.055 + 0.015 * fullness),
                    y: h * (0.022 + 0.010 * fullness))
        }
    }

    /// **A stack that gets thicker as the folder fills.**
    ///
    /// The owner: "photos in the folder shouldn't be transparent and they
    /// shouldn't have the outline, they should show the size... a folder with
    /// 10 wins should look like it's storing 10 wins."
    ///
    /// It drew exactly two cards at a fixed square, with a white border, so
    /// a day with two wins and a day with twenty looked identical and the
    /// loudest thing on a dark screen was a white frame. Now: up to five
    /// cards fanned, newest at the front, each one showing its own block's
    /// proportion, no border, opaque.
    ///
    /// **One width, several heights.** Fanning cards of wildly different
    /// widths reads as a mess rather than as a stack, so the width is shared
    /// and the block's shape comes through in the HEIGHT — a 2x1 win is a
    /// wide short card, a 1x1 is square, a 2x2 is tall. The stack still reads
    /// as a stack and a win still reads as the shape it was drawn at.
    private func peeking(width w: CGFloat, height h: CGFloat) -> some View {
        let shown = Array(contents.prefix(5).enumerated())
        let cardWidth = w * 0.40
        return ZStack {
            ForEach(shown, id: \.offset) { index, win in
                // The fan opens from the middle outwards, oldest furthest
                // back and widest out, so the newest sits square at the front.
                let depth = Double(shown.count - 1 - index)
                let spread = depth / Double(max(shown.count - 1, 1))
                let side: Double = index % 2 == 0 ? -1 : 1
                let ratio = CGFloat(win.size.rowSpan) / CGFloat(win.size.columnSpan)

                // No title on the stack: a card here is 40% of a small
                // folder and a word would be a smudge.
                WinCardFace(win: win, image: win.image, showsTitle: false,
                            corner: w * 0.05)
                .frame(width: cardWidth, height: cardWidth * max(0.5, min(ratio, 1.15)))
                .shadow(color: .black.opacity(0.28), radius: w * 0.02, y: w * 0.008)
                .rotationEffect(.degrees(side * spread * (10 + 6 * Double(fullness))))
                .offset(x: CGFloat(side) * CGFloat(spread) * w * (0.13 + 0.07 * fullness),
                        y: -h * 0.20 + CGFloat(spread) * h * 0.02)
                .zIndex(Double(index))
            }
        }
        .frame(width: w, height: h, alignment: .center)
    }

    private func pocket(width w: CGFloat, height h: CGFloat) -> some View {
        let radius = min(w, h) * 0.135
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0.44)],
                                         startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                // The lit top edge a pocket catches, and the only hairline
                // here. It is what stops the pocket reading as a rectangle
                // pasted over the plate.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            // The pocket swells a little as the folder fills, as though
            // something is behind it.
            .frame(height: h * (0.62 + 0.025 * fullness))
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
