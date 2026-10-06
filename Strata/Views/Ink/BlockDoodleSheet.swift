import PencilKit
import SwiftUI

/// **Draw on the block** (the owner, 2026-10-06: "should we add doodling on
/// the colored blocks like when you are adding a win alternative to adding a
/// picture"; his picks, "Photo or doodle" and "White ink"). The one-pen
/// canvas, at the block's own shape and on its own colour, the ink white as
/// it will be on the tower. Hold to snap, smoothing, pinch to zoom and a
/// two-finger undo come with the canvas.
///
/// Done hands the strokes and the canvas back; the Add sheet keeps them
/// until the win is saved. Done with nothing drawn takes a doodle off.
struct BlockDoodleSheet: View {
    /// The block's width over its height.
    let aspect: CGFloat
    let colour: HabitCategory
    /// The block's height on the tower, so the pen is scaled to land at
    /// `InkPen.blockLine` there.
    var towerHeight: CGFloat = 0
    var drawing: PKDrawing?
    var drawnOn: CGSize?
    let onDone: (_ drawing: PKDrawing, _ canvas: CGSize) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ink = InkController()
    @State private var canvasSize: CGSize = .zero
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: GridConstants.gapWide) {
                InkCanvas(controller: ink, aspectRatio: aspect,
                          ground: AnyShapeStyle(EtherealFill.fill(colour.style.baseColor)),
                          lightInk: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fit(width: $0) }
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.vertical, GridConstants.gapItem)
            .sheetTitle("Doodle", drawn: false)
            .toolbar {
                InkSheetToolbar(confirm: "Done", onCancel: { dismiss() }, onConfirm: {
                    HapticsEngine.lightTap()
                    onDone(ink.drawing, canvasSize)
                    dismiss()
                })
            }
            .background { WarmBackground().ignoresSafeArea() }
        }
        .interactiveDismissDisabled(ink.canUndo)
    }

    /// The canvas as laid out, and a doodle drawn on another size of canvas
    /// scaled to fit it, until you draw (`MonthDrawingEditor.fit`).
    private func fit(width: CGFloat) {
        let size = CGSize(width: width, height: width / aspect)
        guard size.width > 0, size != canvasSize else { return }
        canvasSize = size
        ink.penWidth = InkPen.blockWidth(onCanvasOfHeight: size.height, shownAt: towerHeight)
        guard !ink.canUndo, let drawing, let drawnOn, drawnOn.width > 0 else { return }
        let k = min(size.width / drawnOn.width, size.height / drawnOn.height)
        ink.load(abs(k - 1) < 0.001 ? drawing
                 : drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)))
    }
}

/// **A doodle on a block**: its picture tinted white over the block's colour,
/// at the block's size. Black on nothing on disk, so the one file reads on
/// every colour, as the owner's own drawings take the page's ink.
struct BlockDoodleImage: View {
    let fileName: String

    var body: some View {
        if let image = BlockDoodles.image(fileName) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }
}
