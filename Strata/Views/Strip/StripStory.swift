import SwiftUI
import UIKit

/// **The strip, posed and shared on nothing** (the owner, 2026-10-07: "share
/// it at different angles like you can actually rotate it", then "make sure
/// it saves on a transparent background making it easy to share on other
/// posts"). The booth's Share opens this: the strip large, turned by a finger
/// in 3D, twisted by two, pinched to size, and exported as exactly that pose
/// on a transparent PNG trimmed to the strip, so it drops onto a Story or a
/// post like a sticker. **No shadow anywhere** (the owner, the same day: on
/// the PNG it "looks weird", and in the app it "makes everything look super
/// cramped"): a grey cast read as dirt on a post and as clutter on the page.
///
/// No ground of its own and no mark added (his pick: "Strip foot only"): the
/// strip carries the colour and the name, lit by the booth's own soft studio
/// light (`StripLight`), so the picture and the hand agree.
struct StripStoryPose: Equatable {
    var yaw: Double = -14
    var pitch: Double = 8
    var roll: Double = -4
    var scale: Double = 1

    /// How far each can go: past these a strip reads as edge-on, or is too
    /// small to see what is on it.
    static let yawReach = 42.0
    static let pitchReach = 32.0
    static let scaleRange = 0.6...1.6

    func clamped() -> StripStoryPose {
        var p = self
        p.yaw = max(-Self.yawReach, min(Self.yawReach, yaw))
        p.pitch = max(-Self.pitchReach, min(Self.pitchReach, pitch))
        p.scale = max(Self.scaleRange.lowerBound, min(Self.scaleRange.upperBound, scale))
        return p
    }
}

/// The posed strip, the same view on screen and in the PNG.
struct StripStory: View {
    let strip: PhotoStrip
    let frames: [PhotoStrip.Frame]
    let day: String
    let paper: StripPaper
    let decor: InkPicture?
    var pose: StripStoryPose

    static let stripWidth: CGFloat = 220
    /// Rendered at this many pixels a point: a 220pt strip is 1100px across,
    /// enough to look into the photographs.
    static let exportScale: CGFloat = 5

    private var paperView: StripView {
        StripView(frames: frames, day: day, signature: strip.signature, paper: paper,
                  width: Self.stripWidth, developed: 1, decor: decor)
    }

    var body: some View {
        ZStack {
            paperView
                .overlay {
                    StripLight(yaw: pose.yaw, pitch: pose.pitch, corner: StripView.corner(forWidth: Self.stripWidth))
                }
                .rotation3DEffect(.degrees(pose.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                .rotation3DEffect(.degrees(pose.pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        }
        .fixedSize()
        .rotationEffect(.degrees(pose.roll))
        .scaleEffect(pose.scale)
    }

    /// The pose as a transparent PNG, trimmed to what was drawn. Laid out on
    /// a canvas wide enough for any turn and twist first, because a renderer
    /// keeps only its view's bounds and a rotation draws outside them.
    @MainActor
    func png() -> Data? {
        // **Sized from the strip, not a constant** (the 2026-10-08 audit): a
        // fixed 1.6 widths of room cut the ends off a long strip turned on
        // its side. The pinch is the view's, not the picture's, so it is left
        // out; and the long side is held near 4200px, where a long strip at
        // 5x was about 185 MB rendered on the main thread.
        var flat = self
        flat.pose.scale = 1
        let measured = ImageRenderer(content: paperView.fixedSize()).uiImage?.size
            ?? CGSize(width: Self.stripWidth, height: Self.stripWidth * 3)
        let reach = max(measured.width, measured.height)
        let pad = reach * 0.6
        let renderer = ImageRenderer(content: flat.padding(pad))
        renderer.scale = min(Self.exportScale, 4200 / reach)
        renderer.isOpaque = false
        guard let image = renderer.cgImage, let trimmed = Self.trim(image, margin: 2) else { return nil }
        return UIImage(cgImage: trimmed).pngData()
    }

    /// The smallest rectangle holding every pixel that is not clear, plus a
    /// hair, so the paper's antialiased edge is never cut.
    static func trim(_ image: CGImage, margin: Int) -> CGImage? {
        let w = image.width, h = image.height
        var alpha = [UInt8](repeating: 0, count: w * h)
        guard let context = CGContext(data: &alpha, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where alpha[row + x] > 2 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // The bitmap's rows run bottom-up in a CGContext; the image's top-down.
        let rect = CGRect(x: max(0, minX - margin), y: max(0, (h - 1 - maxY) - margin),
                          width: min(w, maxX + margin + 1) - max(0, minX - margin),
                          height: min(h, (h - 1 - minY) + margin + 1) - max(0, (h - 1 - maxY) - margin))
        return image.cropping(to: rect)
    }
}

/// **Where it is posed**: full screen, the strip as large as the page lets
/// it be, close top right, share and save under it. One finger turns it, two
/// twist it, a pinch sizes it, a double tap puts it back.
struct StripStoryComposer: View {
    let strip: PhotoStrip
    let frames: [PhotoStrip.Frame]
    let day: String
    let paper: StripPaper
    let decor: InkPicture?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pose = StripStoryPose()
    /// The pose when the current gesture began.
    @State private var start = StripStoryPose()
    @State private var turning = false
    @State private var file: URL?
    @State private var saved = false
    @State private var stripSize = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            // Fitted to the room above the buttons, at the pose's own scale.
            let room = CGSize(width: proxy.size.width - GridConstants.horizontalPadding * 2,
                              height: proxy.size.height - 150)
            let fit = stripSize.height > 0
                ? min(1.25, room.width / (stripSize.width * 1.15), room.height / (stripSize.height * 1.1))
                : 1
            VStack(spacing: GridConstants.gapWide) {
                Spacer(minLength: 0)
                StripStory(strip: strip, frames: frames, day: day, paper: paper, decor: decor, pose: pose)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { if !turning { stripSize = $0 } }
                    .scaleEffect(fit)
                    .frame(width: room.width, height: room.height)
                    .contentShape(Rectangle())
                    .gesture(turn)
                    .simultaneousGesture(twist)
                    .simultaneousGesture(pinch)
                    .onTapGesture(count: 2) { reset() }
                    .accessibilityElement()
                    .accessibilityLabel("Your strip")
                    .accessibilityAction(named: "Turn left") { nudge(yaw: -12) }
                    .accessibilityAction(named: "Turn right") { nudge(yaw: 12) }
                    .accessibilityAction(named: "Straighten") { reset() }
                tools
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            GlassIconButton(systemName: "xmark", onPage: true, accessibilityLabel: "Close") { dismiss() }
                .padding(.horizontal, GridConstants.horizontalPadding)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .task { render() }
    }

    private var tools: some View {
        HStack(spacing: GridConstants.gapWide) {
            if let file {
                ShareLink(item: file, preview: SharePreview("Some Wins", image: Image(uiImage: UIImage(contentsOfFile: file.path) ?? UIImage()))) {
                    GlassIconLabel(systemName: "square.and.arrow.up", onPage: true)
                }
                .accessibilityLabel("Share strip")
                GlassIconButton(systemName: saved ? "checkmark" : "square.and.arrow.down", onPage: true,
                                accessibilityLabel: saved ? "Saved" : "Save strip") {
                    Task {
                        guard let data = try? Data(contentsOf: file) else { return }
                        if await PhotoLibrarySaver.savePNG(data) {
                            HapticsEngine.success()
                            saved = true
                        }
                    }
                }
                .disabled(saved)
            }
        }
        .frame(height: 50)
        // Held while turning: a share mid-gesture would send the last pose.
        .opacity(turning ? 0.4 : 1)
        .animation(GridConstants.crossFade, value: turning)
    }

    // MARK: Gestures

    private var turn: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !turning { begin() }
                var next = pose
                next.yaw = start.yaw + Double(value.translation.width) * 0.3
                next.pitch = start.pitch - Double(value.translation.height) * 0.3
                withAnimation(GridConstants.cardFollow) { pose = next.clamped() }
            }
            .onEnded { _ in end() }
    }

    private var twist: some Gesture {
        RotateGesture()
            .onChanged { value in
                if !turning { begin() }
                var next = pose
                next.roll = start.roll + value.rotation.degrees
                pose = next.clamped()
            }
            .onEnded { _ in end() }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if !turning { begin() }
                var next = pose
                next.scale = start.scale * value.magnification
                pose = next.clamped()
            }
            .onEnded { _ in end() }
    }

    private func begin() {
        start = pose
        turning = true
    }

    private func end() {
        turning = false
        start = pose
        render()
    }

    private func nudge(yaw: Double) {
        var next = pose
        next.yaw += yaw
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardRelease) { pose = next.clamped() }
        start = pose
        render()
    }

    private func reset() {
        HapticsEngine.lightTap()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardRelease) { pose = StripStoryPose() }
        start = StripStoryPose()
        render()
    }

    /// The PNG of what is on screen, written when a gesture ends so the share
    /// always sends the pose you let go at. A file, named `.png`, so the
    /// clear background survives the share sheet.
    private func render() {
        saved = false
        let url = FileManager.default.temporaryDirectory.appending(path: "Some Wins \(day).png")
        guard let data = StripStory(strip: strip, frames: frames, day: day, paper: paper, decor: decor,
                                    pose: pose).png(),
              (try? data.write(to: url, options: .atomic)) != nil else { return }
        file = url
    }
}

/// **Light on photo paper, as a studio lights it**, shared by the booth's
/// card and the posed strip so the two agree (the owner, 2026-10-07:
/// "premium and expensive, not a cheap early 2000s looking light"). A broad,
/// soft key light sliding gently across the sheen as the card turns, at a
/// few percent, and a faint shade on the side turned away. Halved again the
/// same day ("the sheen is a bit too much"): about 3% at rest, 6% turned.
struct StripLight: View {
    let yaw: Double
    let pitch: Double
    var lit: Double = 1
    let corner: CGFloat

    var body: some View {
        let lean = max(-1, min(1, (yaw.truncatingRemainder(dividingBy: 180)) / 24))
        let tip = max(-1, min(1, pitch / 24))
        let turned = min(1, abs(lean) + abs(tip))
        ZStack {
            // The key light: wide and low, from above left, moving with the turn.
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0),
                                   .init(color: .white.opacity(0.025 + 0.035 * turned), location: 0.5),
                                   .init(color: .white.opacity(0), location: 1)],
                           startPoint: UnitPoint(x: -0.6 - lean * 0.5, y: -0.4 + tip * 0.4),
                           endPoint: UnitPoint(x: 1.0 - lean * 0.5, y: 1.2 + tip * 0.4))
                .blendMode(.screen)
            // The shade on the far side, so it reads as a lit sheet.
            LinearGradient(colors: [.black.opacity(0.06 * abs(lean)), .clear],
                           startPoint: lean > 0 ? .leading : .trailing, endPoint: .center)
                .blendMode(.multiply)
            LinearGradient(colors: [.black.opacity(0.05 * abs(tip)), .clear],
                           startPoint: tip > 0 ? .bottom : .top, endPoint: .center)
                .blendMode(.multiply)
        }
        .opacity(lit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .allowsHitTesting(false)
    }
}

/// **A card that turns over cleanly** (the owner, 2026-10-07: "the photo
/// strip is still a little glitched when you try and change side"). Which
/// face shows is decided from the angle as it is drawn, frame by frame,
/// because this view is `Animatable`: the face changes exactly as the card
/// passes edge-on. Before, the face was a flag set from the angle it was
/// heading to, so a release faded the front into a mirrored back across the
/// whole spring, and the press and the phone's lean were left out of it.
///
/// Its edge is the paper's thickness, showing on the side turned toward you
/// and nowhere when it faces you square. Lit by `StripLight` at the same
/// drawn angle, so the light and the turn never disagree.
struct TurningCard<Front: View, Back: View>: View, Animatable {
    var yaw: Double
    var pitch: Double
    let width: CGFloat
    let height: CGFloat
    let edge: Color
    var lit: Double = 1
    let front: Front
    let back: Back

    /// The paper's thickness, in points at the card's size.
    static var thickness: CGFloat { 1.8 }

    init(yaw: Double, pitch: Double, width: CGFloat, height: CGFloat, edge: Color, lit: Double = 1,
         @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.yaw = yaw
        self.pitch = pitch
        self.width = width
        self.height = height
        self.edge = edge
        self.lit = lit
        self.front = front()
        self.back = back()
    }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(yaw, pitch) }
        set {
            yaw = newValue.first
            pitch = newValue.second
        }
    }

    var body: some View {
        let showsFront = cos(yaw * .pi / 180) >= 0
        let corner = StripView.corner(forWidth: width)
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(edge)
                .frame(width: width, height: height)
                .offset(x: -sin(yaw * .pi / 180) * Self.thickness, y: sin(pitch * .pi / 180) * Self.thickness)
            front
                .overlay { StripLight(yaw: yaw, pitch: pitch, lit: lit, corner: corner) }
                .opacity(showsFront ? 1 : 0)
            back
                .scaleEffect(x: -1, y: 1)
                .overlay { StripLight(yaw: yaw + 180, pitch: pitch, lit: lit, corner: corner) }
                .opacity(showsFront ? 0 : 1)
        }
        // Both faces stay laid out (the front measures the strip); only
        // which one is seen changes, and never by a fade: the opacity is
        // already the drawn frame's, so it must not be animated again.
        .animation(nil, value: showsFront)
        .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
    }
}
