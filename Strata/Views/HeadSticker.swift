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
        let renderer = ImageRenderer(content: HeadStill(rig: rig, side: side))
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

/// The head on the review, movable. Laid over the photograph's own frame, so
/// its fractions are fractions of the picture and the composite lands exactly
/// where it was shown.
struct HeadStickerOverlay: View {
    let rig: HeadRig
    @Binding var placement: StickerPlacement?

    private struct DragBase { var centre: CGPoint; var translation: CGSize }
    @State private var dragBase: DragBase?
    @State private var widthBase: CGFloat?
    @State private var angleBase: Angle?
    @State private var isHeld = false

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

                if let current = placement {
                    let side = current.width * size.width
                    let canvas = side / rig.contentHeight
                    // Calm: it blinks and glances while you place it, and
                    // holds still in the picture.
                    LivingHeadView(rig: rig, side: side, liveliness: .calm)
                        .frame(width: canvas, height: canvas)
                        .rotationEffect(current.angle)
                        .scaleEffect(isHeld ? 1.04 : 1)
                        .frame(width: max(canvas, Self.minimumTarget),
                               height: max(canvas, Self.minimumTarget))
                        .contentShape(Rectangle())
                        .gesture(move(in: size))
                        .position(x: current.centre.x * size.width,
                                  y: current.centre.y * size.height)
                        .accessibilityElement()
                        .accessibilityLabel("Your head on the photo")
                        .accessibilityHint("Drag to move it. Pinch or turn with two fingers to change it.")
                        .accessibilityAction(named: "Make it bigger") { resize(by: 1.2) }
                        .accessibilityAction(named: "Make it smaller") { resize(by: 1 / 1.2) }
                }
            }
            .simultaneousGesture(sizeAndTurn)
        }
        .coordinateSpace(.named(Self.space))
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
                withAnimation(GridConstants.motionSnappy) { isHeld = false }
            }
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
            }
    }

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

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(x: crop.minX * geometry.size.width,
                              y: crop.minY * geometry.size.height,
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
