import SwiftUI
import UIKit

/// **The stickers on the canvas, under the ink and over it** (the owner,
/// 2026-10-06: "make it so you can add stickers to doodles when you are
/// drawing them").
///
/// Two of these sit round the PencilKit canvas (`InkCanvas.well`). The one
/// beneath DRAWS the stickers, so a line drawn across a sticker lands on top
/// of it, as ink does on a sticker on paper. The one above draws nothing and
/// only answers a finger: one that starts on a sticker moves it, pinches it
/// and turns it a little; one that starts anywhere else draws. Hold one for
/// Remove, or drag it off the page and let go.
///
/// The stickers are not PencilKit's, so they follow the canvas's zoom and
/// pan themselves (`InkController.viewport`), in the canvas's own points.
struct InkStickerLayer: View {
    let controller: InkController
    /// True for the layer above the ink, which takes the fingers.
    let interactive: Bool

    /// The well's own coordinates, so a drag's travel is not turned with a
    /// tilted sticker.
    static let space = "inkWell"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            ForEach(controller.stickers) { sticker in
                if let image = InkStickers.image(sticker.name) {
                    if interactive {
                        InkStickerHandle(controller: controller, sticker: sticker, image: image)
                    } else {
                        InkStickerSprite(controller: controller, sticker: sticker, image: image)
                    }
                }
            }
        }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            if !interactive { controller.canvasSize = size }
        }
        .allowsHitTesting(interactive)
    }
}

/// One sticker, as it looks: lifted a hair while a finger holds it, faded
/// while it is past the edge (let go there and it comes off), and popped in
/// when it is first put on.
private struct InkStickerSprite: View {
    let controller: InkController
    let sticker: InkSticker
    let image: UIImage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool

    init(controller: InkController, sticker: InkSticker, image: UIImage) {
        self.controller = controller
        self.sticker = sticker
        self.image = image
        // One already there when the editor opened is simply there.
        _shown = State(initialValue: controller.fresh != sticker.id)
    }

    var body: some View {
        let view = controller.viewport
        let drawn = sticker.drawnSize(for: image.size)
        let held = controller.holding == sticker.id
        Image(uiImage: image)
            .resizable()
            .frame(width: drawn.width * view.scale, height: drawn.height * view.scale)
            .scaleEffect(shown ? (held ? 1.04 : 1) : (reduceMotion ? 1 : 0.6))
            .opacity(shown ? (controller.isOffPage(sticker) ? 0.45 : 1) : 0)
            .rotationEffect(.radians(sticker.rotation))
            .position(x: sticker.x * view.scale - view.offset.x, y: sticker.y * view.scale - view.offset.y)
            .animation(GridConstants.motionSnappy, value: held)
            .onAppear {
                guard !shown else { return }
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.elasticPop) { shown = true }
            }
            .accessibilityHidden(true)
    }
}

/// One sticker's handle: invisible, the sticker's shape (a fingertip at
/// least), above the ink.
private struct InkStickerHandle: View {
    let controller: InkController
    let sticker: InkSticker
    let image: UIImage

    /// The sticker as it was when the fingers came down.
    @State private var start: InkSticker?

    var body: some View {
        let view = controller.viewport
        let drawn = sticker.drawnSize(for: image.size)
        Color.clear
            .frame(width: max(drawn.width * view.scale, GlassIconButton.defaultSide),
                   height: max(drawn.height * view.scale, GlassIconButton.defaultSide))
            .contentShape(Rectangle())
            .gesture(adjust)
            .contextMenu {
                Button("Remove", systemImage: "trash", role: .destructive) { controller.remove(sticker.id) }
            } preview: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .padding(GridConstants.gapItem)
            }
            .rotationEffect(.radians(sticker.rotation))
            .position(x: sticker.x * view.scale - view.offset.x, y: sticker.y * view.scale - view.offset.y)
            .accessibilityElement()
            .accessibilityLabel("Sticker")
            .accessibilityHint("Drag to move it, pinch to size it. Drag it off the drawing to take it off.")
            .accessibilityAction(named: "Remove") { controller.remove(sticker.id) }
    }

    /// Move, pinch and turn at once, from where the sticker was when the
    /// fingers came down: one step of undo for the whole handling.
    private var adjust: some Gesture {
        SimultaneousGesture(DragGesture(coordinateSpace: .named(InkStickerLayer.space)),
                            SimultaneousGesture(MagnifyGesture(), RotateGesture()))
            .onChanged { value in
                let base = start ?? sticker
                if start == nil {
                    start = sticker
                    controller.beginMoving(sticker.id)
                }
                let scale = max(controller.viewport.scale, 1)
                var next = base
                if let drag = value.first {
                    next.x = base.x + drag.translation.width / scale
                    next.y = base.y + drag.translation.height / scale
                }
                if let pinch = value.second?.first { next.size = base.size * pinch.magnification }
                if let turn = value.second?.second { next.rotation = base.rotation + turn.rotation.radians }
                controller.move(next)
            }
            .onEnded { _ in
                start = nil
                controller.endMoving(sticker.id)
            }
    }
}

// MARK: - Still

/// **The stickers of a saved drawing, still**, at the size they are shown:
/// for a drawing shown from its strokes rather than its picture (the Add
/// sheet's block, before the win is saved). A sticker whose file is not on
/// this phone is left out.
struct InkStickersStill: View {
    let stickers: [InkSticker]
    /// The canvas they were placed on.
    let canvas: CGSize

    var body: some View {
        let images = InkStickers.images(for: stickers)
        Canvas { context, size in
            guard canvas.width > 0 else { return }
            let k = size.width / canvas.width
            for sticker in stickers {
                guard let image = images[sticker.name] else { continue }
                InkStickers.draw(sticker, image: image, in: context, scale: k)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension InkStickers {
    /// The images for these stickers that are on this phone, by name.
    static func images(for stickers: [InkSticker]) -> [String: UIImage] {
        var out: [String: UIImage] = [:]
        for sticker in stickers where out[sticker.name] == nil {
            out[sticker.name] = image(sticker.name)
        }
        return out
    }

    /// One sticker into a SwiftUI `Canvas`, `scale` points a canvas point,
    /// grown from its centre by `pop` (the replay's scale-in).
    static func draw(_ sticker: InkSticker, image: UIImage, in context: GraphicsContext,
                     scale k: CGFloat, pop: CGFloat = 1, opacity: Double = 1) {
        var context = context
        context.opacity = opacity
        context.translateBy(x: sticker.x * k, y: sticker.y * k)
        context.rotate(by: .radians(sticker.rotation))
        context.scaleBy(x: pop, y: pop)
        let drawn = sticker.drawnSize(for: image.size)
        context.draw(Image(uiImage: image),
                     in: CGRect(x: -drawn.width * k / 2, y: -drawn.height * k / 2,
                                width: drawn.width * k, height: drawn.height * k))
    }
}
