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
    var title: String = "Wins"
    var count: Int = 0
    var tint: Color = WinFolder.defaultTint
    /// What is in it. Drawn peeking out of the top and blurred by the pocket.
    var contents: [UIImage] = []
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
        face.openness *= idle.blink
        // The stroke flattens as the lid comes down. See `FolderIdle.flatten`.
        face.left.bend *= (1 - idle.flatten)
        face.right.bend *= (1 - idle.flatten)
        face.gaze.width += idle.gaze.width
        face.gaze.height += idle.gaze.height + idle.breath
        return face
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

                // 2. The wins, NOT clipped to the plate.
                //
                // They were, and it was the thing that kept it from reading
                // as a folder: a photograph sitting flush with the top edge
                // is printed ON the folder, where one standing proud of it is
                // IN the folder. Every reference does this and it is the
                // whole trick. Nothing is lost by letting them out, because
                // the pocket in front still holds them down.
                peeking(width: w, height: h)

                // 3. The pocket. A material, so the wins behind it are really
                //    blurred rather than drawn faint, which is the difference
                //    between a folder holding things and a folder printed
                //    with a picture of them.
                pocket(width: w, height: h)

                // 4. The face, on the pocket, and the name under it.
                VStack(spacing: h * 0.085) {
                    FolderFace(expression: live, eyeWidth: w * 0.145)
                    VStack(spacing: 2) {
                        Text(title)
                            .font(Typography.headerSmall)
                            .foregroundStyle(.white)
                        Text("\(count)")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, h * 0.11)
            }
            .compositingGroup()
            // The one shadow, and it is the folder standing on the ground
            // rather than chrome pretending to float.
            .shadow(color: .black.opacity(0.45), radius: h * 0.06, y: h * 0.025)
        }
    }

    /// The wins, leaning out of the top of the folder the way photographs in
    /// a real one never sit square.
    private func peeking(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            // Two, not three. Three read as a jumble at folder size, and the
            // point of a card leaning out is that you can see it is a
            // photograph, which needs room.
            ForEach(Array(contents.prefix(2).enumerated()), id: \.offset) { index, photo in
                let lean = [-9.0, 6.0][min(index, 1)]
                let slide = [-w * 0.13, w * 0.11][min(index, 1)]
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.42, height: w * 0.42)
                    .clipShape(RoundedRectangle(cornerRadius: w * 0.055, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: w * 0.055, style: .continuous)
                            .strokeBorder(.white.opacity(0.7), lineWidth: w * 0.011)
                    }
                    .rotationEffect(.degrees(lean))
                    .offset(x: slide, y: -h * 0.22)
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
            .frame(height: h * 0.62)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
