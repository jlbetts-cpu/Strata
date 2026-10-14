import PencilKit
import SwiftUI

/// **Draw on the photograph, and put stickers on it** (the owner,
/// 2026-10-13, of the camera's review: "you should be able to doodle ...
/// add stickers ... the interface needs to feel similar"). The strip
/// editor's own canvas, with the photograph under it in place of the strip:
/// the same pen, the same eraser, the same stickers, the same undo.
///
/// Done hands the marks back and the review keeps them until Use Photo draws
/// them in (`PhotoMarks`). Done with nothing on it takes them off.
struct PhotoMarksSheet: View {
    /// Which tool it opens on: the review has a button for each.
    enum Opening: String, Identifiable {
        case pen, stickers
        var id: String { rawValue }
    }

    let photo: UIImage
    /// What is on the photograph already, to carry on from.
    var marks: InkDoodle?
    var opening: Opening = .pen
    let onDone: (InkDoodle?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ink = InkController()
    @State private var canvasSize: CGSize = .zero

    private var aspect: CGFloat { photo.size.width / max(photo.size.height, 1) }

    var body: some View {
        NavigationStack {
            VStack(spacing: GridConstants.gapWide) {
                InkCanvas(controller: ink, aspectRatio: aspect,
                          ground: AnyShapeStyle(Color.clear),
                          cornerRadius: GridConstants.blockCornerRadius,
                          lightInk: true,
                          underlay: AnyView(Image(uiImage: photo).resizable()))
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fit(width: $0) }
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.vertical, GridConstants.gapItem)
            .sheetTitle(opening == .stickers ? "Stickers" : "Doodle", drawn: false)
            .toolbar {
                InkSheetToolbar(confirm: "Done", hasWork: ink.canUndo, onCancel: { dismiss() }, onConfirm: {
                    HapticsEngine.lightTap()
                    let made = InkDoodle(drawing: ink.drawing, stickers: ink.stickers, canvas: canvasSize)
                    onDone(made.isEmpty ? nil : made)
                    dismiss()
                })
            }
            .background { WarmBackground().ignoresSafeArea() }
        }
        .interactiveDismissDisabled(ink.canUndo)
        // Straight to the stickers, once the sheet has risen: a popover from
        // a sheet still rising does not appear (`StripEditor`).
        .task {
            guard opening == .stickers else { return }
            try? await Task.sleep(for: .milliseconds(450))
            ink.wantsStickers = true
        }
    }

    /// The canvas as laid out, and marks made on another size of it scaled
    /// to fit, until you draw (`BlockDoodleSheet.fit`).
    private func fit(width: CGFloat) {
        let size = CGSize(width: width, height: width / max(aspect, 0.01))
        guard size.width > 0, size != canvasSize else { return }
        canvasSize = size
        guard !ink.canUndo, let marks, marks.canvas.width > 0 else { return }
        let k = size.width / marks.canvas.width
        ink.load(abs(k - 1) < 0.001 ? marks.drawing
                 : marks.drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                 stickers: marks.stickers.map { $0.scaled(by: k) })
    }
}
