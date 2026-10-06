import PencilKit
import SwiftUI
import UIKit

// MARK: - The controller

/// **One pen's state, for whoever holds the canvas.** The drawing as it
/// stands, whether the eraser is on, and whether there is anything to undo.
///
/// A class rather than bindings because undo belongs to the canvas: PencilKit
/// records each stroke on the canvas's own undo manager, and the control row
/// beside it has to reach that manager and hear when it changes.
@MainActor
@Observable
final class InkController {
    /// The drawing, as it stands after the last stroke.
    private(set) var drawing: PKDrawing
    /// The pen's width in canvas points. `InkPen.width` everywhere except
    /// the month editor, which draws on a bigger canvas than the page shows
    /// and scales the pen so the line lands at the house width on the page.
    let penWidth: CGFloat
    var erasing = false {
        didSet { canvas?.tool = erasing ? InkPen.eraser : pen }
    }
    private(set) var canUndo = false
    private(set) var canRedo = false

    @ObservationIgnored private weak var canvas: PKCanvasView?

    init(drawing: PKDrawing = PKDrawing(), penWidth: CGFloat = InkPen.width) {
        self.drawing = drawing
        self.penWidth = penWidth
    }

    var isEmpty: Bool { drawing.strokes.isEmpty }

    var pen: PKInkingTool { PKInkingTool(.monoline, color: .black, width: penWidth) }

    func undo() {
        canvas?.undoManager?.undo()
        refresh()
    }

    /// A drawing from somewhere else (a saved sketch, opened to edit): the
    /// canvas shows it and its undo starts empty, so undo cannot reach back
    /// past what was saved.
    func load(_ drawing: PKDrawing) {
        self.drawing = drawing
        canvas?.drawing = drawing
        canvas?.undoManager?.removeAllActions()
        refresh()
    }

    fileprivate func attach(_ canvas: PKCanvasView) {
        self.canvas = canvas
        canvas.drawing = drawing
        canvas.tool = erasing ? InkPen.eraser : pen
    }

    fileprivate func changed(_ drawing: PKDrawing) {
        self.drawing = drawing
        refresh()
    }

    private func refresh() {
        canUndo = canvas?.undoManager?.canUndo ?? false
        canRedo = canvas?.undoManager?.canRedo ?? false
    }
}

// MARK: - The canvas

/// **The one ink canvas.** The journal's sketch strip, a crew doodle and the
/// month drawing all draw here, so they are one pen with one feel (spec
/// section 4, "The ink canvas"): PencilKit with `drawingPolicy = .anyInput`
/// so a finger draws, one black monoline (`InkPen`), an eraser toggle and
/// undo, and NO `PKToolPicker`, because there is nothing to pick.
///
/// The well is the page's quiet fill, not a card: chrome separates by tone,
/// never by a rim (CLAUDE.md, "chrome is not a block"). The controls are the
/// app's own glass buttons in a row under it, with room on the trailing side
/// for whatever finishes the drawing where it is used (Done in the journal).
struct InkCanvas<Accessory: View>: View {
    let controller: InkController
    /// The well's width over its height, or nil to fill what it is given.
    var aspectRatio: CGFloat? = nil
    var accessory: Accessory

    init(controller: InkController, aspectRatio: CGFloat? = nil,
         @ViewBuilder accessory: () -> Accessory) {
        self.controller = controller
        self.aspectRatio = aspectRatio
        self.accessory = accessory()
    }

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            well
            InkControls(controller: controller) { accessory }
        }
    }

    @ViewBuilder
    private var well: some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
        let surface = InkSurface(controller: controller)
            .background(AppColors.quietFill)
            .clipShape(shape)
            .accessibilityLabel("Drawing")
            .accessibilityHint("Draw with one finger")
        if let aspectRatio {
            surface.aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            surface
        }
    }
}

extension InkCanvas where Accessory == EmptyView {
    init(controller: InkController, aspectRatio: CGFloat? = nil) {
        self.init(controller: controller, aspectRatio: aspectRatio) { EmptyView() }
    }
}

/// The eraser and undo, on glass, and the caller's accessory at the end.
struct InkControls<Accessory: View>: View {
    let controller: InkController
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: GridConstants.gapTight) {
            // A toggle: the glyph fills while the eraser is on, as a
            // selected tool does across iOS, and nothing moves.
            GlassIconButton(systemName: controller.erasing ? "eraser.fill" : "eraser",
                            onPage: true,
                            accessibilityLabel: "Eraser") {
                controller.erasing.toggle()
            }
            .accessibilityValue(controller.erasing ? "On" : "Off")
            GlassIconButton(systemName: "arrow.uturn.backward", onPage: true,
                            accessibilityLabel: "Undo") {
                controller.undo()
            }
            .disabled(!controller.canUndo)
            .opacity(controller.canUndo ? 1 : 0.4)
            Spacer(minLength: 0)
            accessory
        }
    }
}

/// `PKCanvasView` for SwiftUI.
private struct InkSurface: UIViewRepresentable {
    let controller: InkController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> OwnUndoCanvas {
        let canvas = OwnUndoCanvas()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.delegate = context.coordinator
        controller.attach(canvas)
        return canvas
    }

    func updateUIView(_ canvas: OwnUndoCanvas, context: Context) {
        context.coordinator.controller = controller
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var controller: InkController
        init(controller: InkController) { self.controller = controller }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            controller.changed(canvas.drawing)
        }
    }
}

/// **A canvas with an undo history of its own.** PencilKit records strokes
/// on `undoManager`, which by default is the WINDOW's, shared with every text
/// field on screen: in the journal, undo on the ink row would have taken back
/// the last words typed in the note above it. This one's history is its own.
final class OwnUndoCanvas: PKCanvasView {
    private let ownUndo = UndoManager()
    override var undoManager: UndoManager? { ownUndo }
}

// MARK: - A saved drawing, on the page

/// **A saved ink picture, drawn in the page's ink.** Read off the main thread
/// (a PNG decode is small, but a list of them is not) and shown as a template
/// image tinted with `tint`, so black ink on a transparent ground follows
/// dark mode the way the owner's drawings do.
struct InkImage: View {
    let url: URL
    var tint: Color = AppColors.inkPrimary
    /// The scale the file was written at, so its natural size is in points.
    var scale: CGFloat = 3

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tint)
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            let url = url, scale = scale
            image = await Task.detached(priority: .userInitiated) {
                InkImageCache.image(at: url, scale: scale)
            }.value
        }
    }
}

/// Decoded ink pictures, by path. Ink files are written under a new name each
/// time they change, so a path never needs invalidating.
nonisolated enum InkImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(at url: URL, scale: CGFloat) -> UIImage? {
        let key = url.path as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let data = try? Data(contentsOf: url),
              let decoded = UIImage(data: data, scale: scale)?.preparingForDisplay() else { return nil }
        cache.setObject(decoded, forKey: key)
        return decoded
    }

    /// The size a file draws at, in points, without keeping the picture.
    static func size(at url: URL, scale: CGFloat) -> CGSize? {
        image(at: url, scale: scale)?.size
    }
}
