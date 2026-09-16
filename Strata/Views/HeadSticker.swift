import SwiftUI
import UIKit

/// Your head on a photograph you have just taken.
///
/// On the camera's review, the still picture after the shutter, rather than on
/// the live viewfinder: the viewfinder's one gesture layer already owns pinch
/// (zoom) and drag (exposure), and a still is where you decide what a picture
/// is anyway. One press adds your head. Then it behaves like a sticker
/// (owner: "like an actual sticker, super easy"):
///
/// - **One finger on the head moves it.**
/// - **Two fingers anywhere on the photo size and turn it**, so a small head
///   never needs a precise pinch on top of itself.
/// - **It snaps straight** within a few degrees of upright, with a tick.
///
/// Use Photo draws it into the picture. Only when you have made a head and the
/// sticker is switched on in Profile. No frame, no border, no badge, no
/// shadow: it is not standing on anything.
struct StickerPlacement: Equatable {
    /// The head's centre, as fractions of the photo.
    var centre = CGPoint(x: 0.72, y: 0.66)
    /// The head's height, crown to chin, as a fraction of the photo's width.
    var width: CGFloat = 0.3
    var angle: Angle = .zero
    /// The face it is wearing. Tap the head to change it; what is on the
    /// review is what is drawn into the photograph. Set to the face the
    /// tapped take ends on, which the sticker keeps.
    var expression: HeadRig.Expression = .neutral
    /// The tap's expression playing on it (`HeadTake`).
    var take: HeadTake.Played? = nil
    /// Where the take left the eyes looking, if it did. What the photograph
    /// draws, so it matches the review. See `HeadTake.stillGaze`.
    var gaze: CGPoint? = nil

    static let widthRange: ClosedRange<CGFloat> = 0.1...0.8
    /// Close enough to upright to mean upright.
    static let snap: Double = 4

    init() {}

    /// Where a head first lands: low and to the right inside the part of the
    /// photo the block will show, and small enough to leave the picture the
    /// picture. `crop` is in fractions of the photo; `photoAspect` is its
    /// width over height.
    init(crop: CGRect, photoAspect: CGFloat) {
        width = min(0.3 * crop.width, 0.42 * crop.height / max(photoAspect, 0.01))
        centre = CGPoint(x: crop.minX + crop.width * 0.72, y: crop.minY + crop.height * 0.64)
    }
}

enum HeadSticker {
    /// The photo with the head drawn into it, at the photo's own resolution.
    @MainActor
    static func composite(_ photo: UIImage, rig: HeadRig, placement: StickerPlacement) -> UIImage {
        let size = photo.size
        let side = placement.width * size.width
        let canvas = side / rig.contentHeight
        let renderer = ImageRenderer(content: HeadStill(rig: rig, side: side,
                                                        expression: placement.expression,
                                                        gaze: placement.gaze ?? HeadStill.restingGaze))
        renderer.scale = photo.scale
        guard let head = renderer.uiImage else { return photo }
        let format = UIGraphicsImageRendererFormat()
        format.scale = photo.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            photo.draw(in: CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.translateBy(x: placement.centre.x * size.width, y: placement.centre.y * size.height)
            cg.rotate(by: CGFloat(placement.angle.radians))
            head.draw(in: CGRect(x: -canvas / 2, y: -canvas / 2, width: canvas, height: canvas))
        }
    }
}

/// Everything you can do to the photograph on the review, on one layer.
///
/// **One layer, because the gestures have to see each other.** A finger on
/// the head moves the head; a finger anywhere else moves the block's crop
/// over the picture; two fingers size and turn the head. Split across two
/// layers, whichever sat on top would swallow the other's touches, which is
/// the same trap `CameraView` records about the viewfinder's own gestures.
///
/// Laid over the photograph's own frame, so its fractions are fractions of
/// the picture and both the composite and the crop land exactly where they
/// were shown.
struct HeadStickerOverlay: View {
    /// Nil when no head has been made or the sticker is switched off: the
    /// layer is still here for the crop.
    var rig: HeadRig?
    @Binding var placement: StickerPlacement?
    /// Which part of the photograph the block will show, as a fraction of the
    /// picture away from its middle. See `BlockCropOutline`.
    @Binding var crop: CGPoint
    /// How far the crop may travel before it leaves the picture.
    var cropRange: CGSize = .zero
    /// The look the photograph is wearing, so the head is in the same world
    /// as the picture under it rather than sitting on top of it in its own
    /// colours. A likeness, because this head is alive — what gets saved goes
    /// through the real pipeline. See `FilmLook.Likeness`.
    var look: FilmLook = .none

    private struct DragBase { var centre: CGPoint; var translation: CGSize }
    @State private var dragBase: DragBase?
    /// A finger is on the HEAD. The crop's drag is a gesture on the layer
    /// underneath and sees the same finger, so without this one drag moved the
    /// head and the block's window at once.
    @State private var movingHead = false
    @State private var widthBase: CGFloat?
    @State private var angleBase: Angle?
    @State private var cropBase: CGPoint?
    @State private var isHeld = false
    @State private var deck = HeadTakeDeck()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A head can be drawn smaller than a finger. Its target never is.
    private static let minimumTarget: CGFloat = 88
    private static let space = "headSticker"

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                // The photo itself, so two fingers anywhere reach the head.
                Color.clear
                    .contentShape(Rectangle())

                if let current = placement, let rig {
                    let side = current.width * size.width
                    let canvas = side / rig.contentHeight
                    // Calm: it blinks and glances while you place it, and
                    // holds still in the picture.
                    LivingHeadView(rig: rig, side: side, liveliness: .calm,
                                   held: current.expression == .neutral ? nil : current.expression,
                                   take: current.take, keepsTake: true)
                        .frame(width: canvas, height: canvas)
                        .filmLook(look)
                        .rotationEffect(current.angle)
                        .scaleEffect(isHeld ? 1.04 : 1)
                        .frame(width: max(canvas, Self.minimumTarget),
                               height: max(canvas, Self.minimumTarget))
                        .contentShape(Rectangle())
                        .onTapGesture { changeFace() }
                        .gesture(move(in: size))
                        .position(x: current.centre.x * size.width,
                                  y: current.centre.y * size.height)
                        .accessibilityElement()
                        .accessibilityLabel("Your head on the photo")
                        .accessibilityHint("Drag to move it. Pinch or turn with two fingers to change it. Tap for an expression.")
                        .accessibilityAction(named: "Another expression") { changeFace() }
                        .accessibilityAction(named: "Make it bigger") { resize(by: 1.2) }
                        .accessibilityAction(named: "Make it smaller") { resize(by: 1 / 1.2) }
                }
            }
            .simultaneousGesture(sizeAndTurn)
            // A finger on the picture itself moves what the block will show.
            .simultaneousGesture(moveCrop(in: size))
        }
        .coordinateSpace(.named(Self.space))
        #if DEBUG
        .task(id: placement == nil) { await debugTakes() }
        #endif
    }

    /// One finger on the head. Measured in the photo's space, not the head's:
    /// the head moves under the finger, so its own space would report half the
    /// distance travelled. While two fingers are down the head is being sized,
    /// not moved, and when one lifts the move picks up from where the head
    /// is, never from where the finger started.
    private func move(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard let current = placement else { return }
                movingHead = true
                if !isHeld { withAnimation(GridConstants.motionSnappy) { isHeld = true } }
                guard widthBase == nil, angleBase == nil else {
                    dragBase = nil
                    return
                }
                let base = dragBase ?? DragBase(centre: current.centre, translation: value.translation)
                if dragBase == nil { dragBase = base }
                placement?.centre = CGPoint(
                    x: min(max(base.centre.x + (value.translation.width - base.translation.width) / size.width, 0), 1),
                    y: min(max(base.centre.y + (value.translation.height - base.translation.height) / size.height, 0), 1))
            }
            .onEnded { _ in
                dragBase = nil
                movingHead = false
                withAnimation(GridConstants.motionSnappy) { isHeld = false }
            }
    }

    /// **Dragging the picture moves the block's window over it** (the owner:
    /// "you should be able to move the crop on the photo using a basic
    /// moving"), and **the window follows the finger**: the hairline is the
    /// only thing that moves on the review, and the head on the same photo
    /// follows the finger too. It used to run against it ("the slider to crop
    /// feels the wrong way"). Clamped so the window can never leave the
    /// photograph, which is the one thing that would produce an empty edge on
    /// a block. See `BlockCropOutline.dragged`.
    private func moveCrop(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard cropRange != .zero, widthBase == nil, angleBase == nil, !movingHead else { return }
                let base = cropBase ?? crop
                if cropBase == nil { cropBase = base }
                crop = BlockCropOutline.dragged(from: base, translation: value.translation,
                                                in: size, range: cropRange)
            }
            .onEnded { _ in cropBase = nil }
    }

    private var sizeAndTurn: some Gesture {
        MagnifyGesture()
            .simultaneously(with: RotateGesture())
            .onChanged { value in
                guard let current = placement else { return }
                if let pinch = value.first {
                    let base = widthBase ?? current.width
                    if widthBase == nil { widthBase = base }
                    placement?.width = Self.clampedWidth(base * pinch.magnification)
                }
                if let turn = value.second {
                    let base = angleBase ?? current.angle
                    if angleBase == nil { angleBase = base }
                    let wasStraight = current.angle == .zero
                    let turned = Self.snapped(base + turn.rotation)
                    if turned == .zero && !wasStraight { HapticsEngine.tick() }
                    placement?.angle = turned
                }
            }
            .onEnded { _ in
                widthBase = nil
                angleBase = nil
                // The head's own drag has one exit, and a pinch takes the
                // fingers off it without one: clear the flag here too, or the
                // crop stays dead for the rest of the review.
                movingHead = false
            }
    }

    /// **Tap it and it plays an expression** (`HeadTake`): one of twelve,
    /// never the same one twice running, held about three seconds, and a new
    /// tap switches at once. The owner: "when you click it it does a random
    /// expression", then "there should be a bunch of expressions and they
    /// should hold for longer." The motion eases back when the hold ends; the
    /// FACE is kept, so the head you are looking at when you press Use Photo
    /// is the head that gets drawn into the picture.
    private func changeFace() {
        guard let rig else { return }
        let available = HeadTake.available(faces: rig.takeFaces, hasShut: rig.shut != nil,
                                           reduceMotion: reduceMotion)
        guard let next = deck.next(from: available) else { return }
        HapticsEngine.tick()
        play(next, direction: Bool.random() ? 1 : -1, on: rig)
    }

    private func play(_ next: HeadTake, direction: Double, on rig: HeadRig) {
        guard let current = placement else { return }
        placement?.expression = reduceMotion
            ? (rig.has(next.face) ? next.face : .neutral)
            : next.endFace(has: rig.has)
        placement?.take = HeadTake.Played(id: next.id, direction: direction,
                                          nonce: (current.take?.nonce ?? 0) + 1)
        // The head keeps the take's look, so the photograph shows the same
        // eyes as the review. Reduce Motion changes the face and nothing else.
        placement?.gaze = reduceMotion ? nil : next.stillGaze(direction: direction)
    }

    #if DEBUG
    /// `-strataHeadTake`: taps the sticker on its own, through the same path
    /// as a finger, so every take on a photo can be photographed.
    private func debugTakes() async {
        guard let wanted = DebugHarness.headTake, let rig, placement != nil else { return }
        try? await Task.sleep(for: .seconds(4))
        var turn = 0
        while !Task.isCancelled {
            let pool = HeadTake.available(faces: rig.takeFaces, hasShut: rig.shut != nil, reduceMotion: reduceMotion)
            let list = wanted == "cycle" ? pool : pool.filter { $0.id.rawValue.lowercased() == wanted }
            guard !list.isEmpty else { return }
            for next in list {
                turn += 1
                NSLog("[strata-head] take \(next.id.rawValue) hold \(next.hold) (sticker)")
                play(next, direction: turn % 2 == 0 ? -1 : 1, on: rig)
                try? await Task.sleep(for: .seconds(next.hold + 1.2))
                guard !Task.isCancelled else { return }
            }
        }
    }
    #endif

    private func resize(by factor: CGFloat) {
        guard let current = placement else { return }
        withAnimation(GridConstants.motionSnappy) {
            placement?.width = Self.clampedWidth(current.width * factor)
        }
    }

    private static func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, StickerPlacement.widthRange.lowerBound), StickerPlacement.widthRange.upperBound)
    }

    /// Wrapped to ±180°, and upright when it is nearly upright.
    private static func snapped(_ angle: Angle) -> Angle {
        var degrees = angle.degrees.truncatingRemainder(dividingBy: 360)
        if degrees > 180 { degrees -= 360 }
        if degrees < -180 { degrees += 360 }
        return abs(degrees) < StickerPlacement.snap ? .zero : .degrees(degrees)
    }
}

/// The review's sticker control: your own head, in the camera's glass.
struct HeadStickerButton: View {
    let rig: HeadRig
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            LivingHeadView(rig: rig, side: GlassIconButton.defaultSide * ProfileAvatar.headShare, liveliness: .calm)
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .clipShape(Circle())
                .glassCircle()
                .overlay {
                    Circle().strokeBorder(isOn ? AppColors.onDarkStrong : .clear, lineWidth: 2)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Remove your head from the photo" : "Add your head to the photo")
    }
}

/// Where the block will cut the photo: a hairline, nothing dimmed (owner:
/// "subtle, just to see"). Two hairlines, light inside dark, so it reads on a
/// white wall and a night sky alike.
struct BlockCropOutline: View {
    /// In fractions of the photo.
    let crop: CGRect
    /// How far the window has been moved from the middle, in fractions of the
    /// photo.
    var offset: CGPoint = .zero

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(x: (crop.minX + offset.x) * geometry.size.width,
                              y: (crop.minY + offset.y) * geometry.size.height,
                              width: crop.width * geometry.size.width,
                              height: crop.height * geometry.size.height)
            ZStack {
                Rectangle()
                    .stroke(Color.black.opacity(0.22), lineWidth: 1)
                    .frame(width: rect.width - 1, height: rect.height - 1)
                Rectangle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    .frame(width: rect.width - 3, height: rect.height - 3)
            }
            .position(x: rect.midX, y: rect.midY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The part of a photo a block of `size` shows. The block fills itself
    /// with the whole photo, centred (`CachedImageView`, `.scaledToFill`).
    /// How far the window may be moved before it leaves the photograph, in
    /// fractions of the photo.
    static func range(for crop: CGRect) -> CGSize {
        CGSize(width: max(0, (1 - crop.width) / 2), height: max(0, (1 - crop.height) / 2))
    }

    /// Where a dragged window lands, in fractions of the photo away from the
    /// middle. It follows the finger (finger right, window right), clamped to
    /// the picture. The block then shows exactly what the window framed:
    /// `CachedImageView` offsets the picture by minus this, which is correct
    /// there, because a window moved right means the picture moves left
    /// inside the block.
    static func dragged(from base: CGPoint, translation: CGSize, in size: CGSize, range: CGSize) -> CGPoint {
        CGPoint(x: min(max(base.x + translation.width / max(size.width, 1), -range.width), range.width),
                y: min(max(base.y + translation.height / max(size.height, 1), -range.height), range.height))
    }

    static func crop(photo: CGSize, block size: BlockSize) -> CGRect {
        let photoAspect = photo.width / max(photo.height, 1)
        let blockAspect = size.cropAspectRatio
        if blockAspect > photoAspect {
            let height = photoAspect / blockAspect
            return CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
        } else {
            let width = blockAspect / photoAspect
            return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
        }
    }
}


extension View {
    /// A look's likeness, for a view that is alive. See `FilmLook.Likeness`.
    func filmLook(_ look: FilmLook) -> some View {
        let like = look.likeness
        return self
            .saturation(like.saturation)
            .contrast(like.contrast)
            .brightness(like.brightness)
            .grayscale(like.grayscale)
    }
}
