import PencilKit
import SwiftUI

/// **The day's sketch, drawn full screen** (the owner, 2026-10-05: "wish it
/// could be a little bigger canvas for the journal like it is in the month").
///
/// The month editor's experience, on purpose: a full-screen sheet, the shared
/// one-pen canvas at the same 2:3 shape (`MonthDrawingEditor.aspect`), Cancel
/// and Done in words, and the page's own ground. It replaced the 260pt strip
/// that opened inside the note. There is no "Bring It to Life" here: a
/// sketch is not replayed.
///
/// **The pen is scaled to where the sketch is shown**, as the month's is: the
/// canvas is taller than the sketch is shown under the note
/// (`JournalSketches.shownHeight`), so the pen is widened by that ratio and
/// the line lands at `InkPen.width` on the page.
///
/// Cancel keeps nothing. Done hands back the drawing, its stickers and the
/// canvas it was made on; the journal decides whether anything changed.
struct JournalSketchEditor: View {
    let title: String
    let onDone: (InkDoodle) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ink: InkController
    @State private var canvasSize: CGSize = .zero

    static var aspect: CGFloat { MonthDrawingEditor.aspect }

    init(title: String, drawing: PKDrawing, stickers: [InkSticker] = [],
         onDone: @escaping (InkDoodle) -> Void) {
        self.title = title
        self.onDone = onDone
        _ink = State(initialValue: InkController(drawing: drawing, stickers: stickers))
    }

    var body: some View {
        NavigationStack {
            InkCanvas(controller: ink, aspectRatio: Self.aspect)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fit(width: $0) }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, GridConstants.horizontalPadding)
                .padding(.vertical, GridConstants.gapItem)
                .sheetTitle(title, drawn: false)
                .toolbar {
                    InkSheetToolbar(confirm: "Done",
                                    onCancel: { dismiss() },
                                    onConfirm: done)
                }
                .background { WarmBackground().ignoresSafeArea() }
        }
    }

    /// The pen for the canvas as laid out. The sheet lays the canvas out more
    /// than once on its way up (`MonthDrawingEditor.fit` records it), so this
    /// follows every width it reports.
    private func fit(width: CGFloat) {
        let size = CGSize(width: width, height: width / Self.aspect)
        guard size.width > 0, size != canvasSize else { return }
        canvasSize = size
        // The line as it will be seen: the sketch is shown at this size.
        ink.penWidth = InkPen.width
        #if DEBUG
        if let line = DebugHarness.penLine { ink.penWidth = line }
        #endif
    }

    private func done() {
        HapticsEngine.lightTap()
        onDone(InkDoodle(drawing: ink.drawing, stickers: ink.stickers, canvas: canvasSize))
        dismiss()
    }
}
