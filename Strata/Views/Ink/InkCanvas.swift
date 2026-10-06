import PencilKit
import SwiftUI
import UIKit

// MARK: - The controller

/// **One pen's state, for whoever holds the canvas.** The drawing as it
/// stands, whether the eraser is on, and whether there is anything to undo.
///
/// A class rather than bindings because undo belongs to the canvas, and the
/// control row beside it has to reach that history and hear when it changes.
///
/// **The history is this controller's own, a list of drawings, and PencilKit
/// does not write to it** (2026-10-06). Undo used to be PencilKit's: each
/// stroke registered itself on the canvas's undo manager. Then the pen began
/// to help (`InkAssist`): a stroke is smoothed when it lands and snapped to a
/// shape when you hold, which REPLACES the stroke PencilKit just registered.
/// Its undo action then names a stroke that is no longer in the drawing, and
/// whether it removes the smoothed one, nothing, or something else is
/// PencilKit's private business. So every step is recorded here as the
/// drawing it undoes back to: a stroke is one step (its smoothing is part of
/// it, so undo never "un-smooths" and looks as if it did nothing), a snap is
/// a second step on top (one undo gives back the freehand stroke you held, a
/// second removes it), and an eraser drag is one step however many strokes it
/// takes.
@MainActor
@Observable
final class InkController {
    /// The drawing, as it stands after the last stroke.
    private(set) var drawing: PKDrawing
    /// The line's width as seen, in canvas points. `InkPen.width` everywhere except
    /// the month editor, which draws on a bigger canvas than the page shows
    /// and scales the pen so the line lands at the house width on the page.
    var penWidth: CGFloat {
        didSet { if !erasing { canvas?.tool = pen } }
    }
    var erasing = false {
        didSet { canvas?.tool = erasing ? InkPen.eraser : pen }
    }
    private(set) var canUndo = false

    @ObservationIgnored private weak var canvas: OwnUndoCanvas?
    /// What each undo goes back to, the most recent last.
    @ObservationIgnored private var history: [PKDrawing] = []
    /// When the last step was recorded and whether it added one tiny stroke,
    /// for the dot a two-finger tap's first finger can leave.
    @ObservationIgnored private var lastStep: (at: Date, stray: Bool) = (.distantPast, false)

    init(drawing: PKDrawing = PKDrawing(), penWidth: CGFloat = InkPen.width) {
        self.drawing = drawing
        self.penWidth = penWidth
    }

    var isEmpty: Bool { drawing.strokes.isEmpty }

    /// How many steps undo can take back.
    var undoDepth: Int { history.count }

    /// The tool for `penWidth`, the line as seen (`InkPen.toolWidth`).
    var pen: PKInkingTool {
        PKInkingTool(.monoline, color: .black, width: InkPen.toolWidth(forLine: penWidth))
    }

    func undo() {
        guard let before = history.popLast() else { return }
        lastStep = (.distantPast, false)
        show(before)
    }

    /// A drawing from somewhere else (a saved sketch, opened to edit): the
    /// canvas shows it and its undo starts empty, so undo cannot reach back
    /// past what was saved.
    func load(_ drawing: PKDrawing) {
        history.removeAll()
        lastStep = (.distantPast, false)
        show(drawing)
    }

    /// A step: `before` is what undoing it gives back.
    func record(_ before: PKDrawing, stray: Bool = false) {
        history.append(before)
        lastStep = (Date(), stray)
        refresh()
    }

    /// The last step, if it was a dot left within `window` seconds: the
    /// first finger of a two-finger tap, which is not a mark anyone made.
    func dropStray(within window: TimeInterval) {
        guard lastStep.stray, Date().timeIntervalSince(lastStep.at) <= window else { return }
        undo()
    }

    fileprivate func attach(_ canvas: OwnUndoCanvas) {
        self.canvas = canvas
        // Quietly: the drawing it opens with is not a step, and recording
        // it gave undo a first press that did nothing.
        canvas.setDrawingQuietly(drawing)
        canvas.tool = erasing ? InkPen.eraser : pen
    }

    /// The canvas's drawing changed under a finger and has been assisted.
    fileprivate func changed(_ drawing: PKDrawing) {
        self.drawing = drawing
        refresh()
    }

    /// Puts `drawing` on the canvas without it counting as a step.
    fileprivate func show(_ drawing: PKDrawing) {
        self.drawing = drawing
        canvas?.setDrawingQuietly(drawing)
        refresh()
    }

    private func refresh() {
        canUndo = !history.isEmpty
    }
}

// MARK: - The canvas

/// **The one ink canvas.** The journal's sketch editor, a crew doodle and the
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
    /// What the well is: the page's quiet fill, or a block's own colour for
    /// a doodle on a block (`BlockDoodleSheet`).
    var ground: AnyShapeStyle = AnyShapeStyle(AppColors.quietFill)
    var cornerRadius: CGFloat = GridConstants.blockCornerRadius
    /// The ink drawn white, as it will be on the block. The strokes are the
    /// one black pen as everywhere; the canvas is shown as in dark mode,
    /// where PencilKit draws black ink white.
    var lightInk = false
    var accessory: Accessory

    init(controller: InkController, aspectRatio: CGFloat? = nil,
         ground: AnyShapeStyle = AnyShapeStyle(AppColors.quietFill),
         cornerRadius: CGFloat = GridConstants.blockCornerRadius, lightInk: Bool = false,
         @ViewBuilder accessory: () -> Accessory) {
        self.controller = controller
        self.aspectRatio = aspectRatio
        self.ground = ground
        self.cornerRadius = cornerRadius
        self.lightInk = lightInk
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
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let surface = InkSurface(controller: controller, lightInk: lightInk)
            .background(Rectangle().fill(ground))
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
    init(controller: InkController, aspectRatio: CGFloat? = nil,
         ground: AnyShapeStyle = AnyShapeStyle(AppColors.quietFill),
         cornerRadius: CGFloat = GridConstants.blockCornerRadius, lightInk: Bool = false) {
        self.init(controller: controller, aspectRatio: aspectRatio, ground: ground,
                  cornerRadius: cornerRadius, lightInk: lightInk) { EmptyView() }
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

/// `PKCanvasView` for SwiftUI, and the pen's four kinds of help
/// (2026-10-06, the owner's approved scope): hold to snap, smoothing as a
/// stroke lands, pinch to zoom with a two-finger pan, and a two-finger tap
/// to undo. None of them has a button: "scarcity", no new chrome.
private struct InkSurface: UIViewRepresentable {
    let controller: InkController
    var lightInk = false

    /// How far the canvas zooms in. One finger always draws; two pan and
    /// pinch. At 1 the page is exactly the well, so nothing scrolls.
    static let maximumZoom: CGFloat = 4

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> OwnUndoCanvas {
        let canvas = OwnUndoCanvas()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        if lightInk { canvas.overrideUserInterfaceStyle = .dark }
        // Scrolling is on so that a zoomed page can be panned; at a scale of
        // 1 the content is the well's own size (`OwnUndoCanvas.layoutSubviews`)
        // and there is nowhere to go. The strokes stay in the page's own
        // points at every scale, so what is saved never knows about zoom.
        canvas.isScrollEnabled = true
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = Self.maximumZoom
        canvas.bounces = false
        canvas.bouncesZoom = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.delegate = context.coordinator
        context.coordinator.watch(canvas)
        controller.attach(canvas)
        return canvas
    }

    func updateUIView(_ canvas: OwnUndoCanvas, context: Context) {
        context.coordinator.controller = controller
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var controller: InkController

        /// The drawing gesture under way, counted, so an eraser drag that
        /// changes the drawing several times is one step of undo.
        private var gesture = 0
        private var recordedGesture = -1
        /// The finger, while it draws: where it has been (window points)
        /// and where it last came to rest.
        private var trail: [CGPoint] = []
        private var anchor: CGPoint = .zero
        private var holdTimer: DispatchWorkItem?
        /// The finger came to rest at the end of this stroke for
        /// `InkAssist.holdDuration`, and whether the snap was felt already.
        private var held = false
        private var felt = false
        /// A two-finger tap just undid: a dot that lands now is its first finger.
        private var strayUntil = Date.distantPast
        /// When two fingers last zoomed or panned the page.
        private var movedAt = Date.distantPast

        init(controller: InkController) { self.controller = controller }

        func watch(_ canvas: OwnUndoCanvas) {
            canvas.drawingGestureRecognizer.addTarget(self, action: #selector(track(_:)))
            // **Two fingers, tapped, undo** (Procreate's gesture). The
            // visible undo button stays: a hidden gesture is never the only
            // way in.
            let tap = UITapGestureRecognizer(target: self, action: #selector(twoFingerTap(_:)))
            tap.numberOfTouchesRequired = 2
            tap.delegate = self
            canvas.addGestureRecognizer(tap)
        }

        // MARK: Hold to snap

        /// Watches the finger while it draws. Still for 0.45s inside 3pt
        /// (in screen points, so zoom does not change how still is still)
        /// and the stroke will snap when it lifts; the haptic says so at
        /// the moment of the hold, when it is felt as an answer.
        @objc private func track(_ recognizer: UIGestureRecognizer) {
            let point = recognizer.location(in: nil)
            switch recognizer.state {
            case .began:
                held = false
                felt = false
                trail = [point]
                restartHold(at: point, recognizer)
            case .changed:
                trail.append(point)
                if hypot(point.x - anchor.x, point.y - anchor.y) > InkAssist.holdSlop {
                    held = false
                    restartHold(at: point, recognizer)
                }
            default:
                holdTimer?.cancel()
            }
        }

        private func restartHold(at point: CGPoint, _ recognizer: UIGestureRecognizer) {
            anchor = point
            holdTimer?.cancel()
            let timer = DispatchWorkItem { [weak self, weak recognizer] in
                guard let self, let recognizer, !self.controller.erasing,
                      recognizer.state == .began || recognizer.state == .changed else { return }
                self.held = true
                if InkAssist.shape(for: self.trail) != nil {
                    HapticsEngine.snap()
                    self.felt = true
                }
            }
            holdTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + InkAssist.holdDuration, execute: timer)
        }

        // MARK: Two-finger tap

        @objc private func twoFingerTap(_ recognizer: UITapGestureRecognizer) {
            // A pinch or a pan under way, or just finished, is not a tap.
            guard recognizer.state == .ended, Date().timeIntervalSince(movedAt) > 0.5 else { return }
            // The first finger may have landed as a dot before the second
            // arrived, and PencilKit may commit it either side of this.
            controller.dropStray(within: 0.5)
            strayUntil = Date().addingTimeInterval(0.4)
            controller.undo()
        }

        /// Alongside the pen's own gesture, so the first finger's stroke
        /// does not swallow the tap; NOT alongside the scroll view's pinch
        /// and pan, so a pinch that ends quickly is a zoom and never also
        /// an undo (seen on the simulator: a 300ms pinch to 2x undid a
        /// stroke as well).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            (other.view as? PKCanvasView)?.drawingGestureRecognizer === other
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            movedAt = Date()
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            movedAt = Date()
        }

        // MARK: The drawing

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            gesture += 1
        }

        /// A finger changed the drawing. A new stroke is assisted (snapped
        /// or smoothed) and swapped in before anything else sees it, and the
        /// step is recorded on the controller's own history.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let canvas = canvasView as? OwnUndoCanvas, !canvas.isSettingQuietly else { return }
            let before = controller.drawing
            var after = canvas.drawing
            let added = after.strokes.count == before.strokes.count + 1
            let stray = added && Self.isDot(after.strokes.last)

            if stray, Date() < strayUntil {
                // The two-finger tap's first finger, landing after the undo.
                canvas.setDrawingQuietly(before)
                return
            }
            // One step per stroke; an eraser drag's several changes are one.
            if added || recordedGesture != gesture {
                controller.record(before, stray: stray)
                recordedGesture = gesture
            }
            if added, !controller.erasing, let last = after.strokes.indices.last {
                let result = InkAssist.assisted(after.strokes[last], held: held)
                if result.snapped {
                    // A second step: one undo gives back the stroke as drawn.
                    controller.record(after)
                    if !felt { HapticsEngine.snap() }
                }
                after.strokes[last] = result.stroke
                canvas.setDrawingQuietly(after)
            }
            held = false
            felt = false
            controller.changed(after)
        }

        /// A stroke no bigger than a dot.
        private static func isDot(_ stroke: PKStroke?) -> Bool {
            guard let stroke else { return false }
            let box = stroke.renderBounds
            return max(box.width, box.height) < 8
        }
    }
}

/// **A canvas whose undo history is the controller's** (`InkController`).
///
/// PencilKit records strokes on `undoManager`, which by default is the
/// WINDOW's, shared with every text field on screen: in the journal, undo on
/// the ink row would have taken back the last words typed in the note above
/// it. So the canvas has a manager of its own, and since the pen began
/// replacing the strokes PencilKit registers (2026-10-06), that manager
/// records nothing: the steps live on the controller, where a snap is a
/// step of its own and a stroke's smoothing is part of the stroke's.
final class OwnUndoCanvas: PKCanvasView {
    private let silenced: UndoManager = {
        let manager = UndoManager()
        manager.disableUndoRegistration()
        return manager
    }()
    override var undoManager: UndoManager? { silenced }

    /// True while the drawing is being set in code, so the delegate does not
    /// take it for a finger.
    private(set) var isSettingQuietly = false

    func setDrawingQuietly(_ drawing: PKDrawing) {
        isSettingQuietly = true
        self.drawing = drawing
        isSettingQuietly = false
    }

    /// The page is the well, at every zoom: its content is the view's own
    /// size times the scale, so at 1 there is nothing to scroll to and
    /// zoomed in there is exactly the page to pan round.
    override func layoutSubviews() {
        super.layoutSubviews()
        let page = CGSize(width: bounds.width * zoomScale, height: bounds.height * zoomScale)
        if contentSize != page { contentSize = page }
    }
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
    /// Drawn at its natural size rather than fitted to the space it is
    /// given: the journal's sketch, which is written at the size it is shown
    /// (`JournalSketches.shownHeight`) and must not be blown up to the width.
    var natural = false

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image, natural {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .foregroundStyle(tint)
            } else if let image {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tint)
            } else if natural {
                Color.clear.frame(height: 0)
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

// MARK: - A sheet's bar

/// Cancel and a confirm word, for a sheet that holds the canvas (a doodle's
/// Send, the month editor's Done). Typed `ToolbarContent`, as `DaySheet`'s
/// is, and words through `sheetAction` like every sheet in the app.
struct InkSheetToolbar: ToolbarContent {
    let confirm: String
    var confirmDisabled = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    /// Without the system's own glass behind the words, as `DaySheet` and
    /// the journal do: inside iOS 26's toolbar capsule a word was cut to
    /// "Cance" (seen on the doodle sheet, 2026-10-05).
    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { cancel }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { confirmButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { cancel }
            ToolbarItem(placement: .topBarTrailing) { confirmButton }
        }
    }

    private var cancel: some View {
        Button(action: onCancel) { Text("Cancel").sheetAction(.cancel) }
            .buttonStyle(.pressWord)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) { Text(confirm).sheetAction() }
            .buttonStyle(.pressWord)
            .disabled(confirmDisabled)
            .opacity(confirmDisabled ? 0.4 : 1)
    }
}
