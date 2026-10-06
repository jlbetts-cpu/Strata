import PencilKit
import SwiftUI
import TipKit

/// **Draw your own month** (spec section 4, "The editor"): a full-screen
/// sheet, the shared one-pen canvas at the month art's shape, Cancel and
/// Done, and one switch, "Bring It to Life", on by default and kept with the
/// drawing.
///
/// **The pen is scaled to the page, not to the editor.** The canvas here is
/// larger than the drawing is shown (`MemoriesView` gives it 290pt of height
/// at most), so a line drawn here at the house width would land thinner than
/// the owner's own drawings. The pen is widened by the same ratio
/// (`InkPen.width(onCanvasOfHeight:shownAt:)`), and the line arrives on the
/// page at the house width.
///
/// **A line of your own under it** (the owner, 2026-10-06: "when you are
/// drawing your own you can add you own quote"): typed under the canvas in
/// the very type the page sets it in (`DrawingLine`), centred where it will
/// sit, so what you write is what Memories shows.
///
/// **Stickers of your own on it** (the owner, 2026-10-06: "make it so you can
/// add stickers to doodles when you are drawing them"), from the canvas's
/// row, kept in the record and popped in by the replay once the lines are on.
///
/// Done with nothing drawn is the original again (`MonthDrawingStore.save`).
struct MonthDrawingEditor: View {
    /// "2026-10".
    let month: String
    /// "October", for the title.
    let monthName: String

    @Environment(\.dismiss) private var dismiss
    @State private var ink: InkController
    @State private var bringsToLife: Bool
    @State private var line: String
    @State private var canvasSize: CGSize = .zero
    /// The strokes as they were when the editor opened, at this canvas's
    /// size, to tell an edit from a look; and the stickers, likewise.
    @State private var baseline = Data()
    @State private var baselineStickers: [InkSticker] = []
    private let saved: MonthDrawing?

    /// The month art's shape: the owner's drawings are 2:3 (October is 580 by
    /// 870), so a drawing of your own sits in the same room.
    static let aspect: CGFloat = 2 / 3
    /// The height the page shows a month drawing at, at most.
    static let shownHeight: CGFloat = 290

    init(month: String, monthName: String, store: MonthDrawingStore? = nil) {
        self.month = month
        self.monthName = monthName
        let saved = (store ?? .shared).drawing(for: month)
        self.saved = saved
        let strokes = saved.flatMap { try? PKDrawing(data: $0.strokes) } ?? PKDrawing()
        _ink = State(initialValue: InkController(drawing: strokes, stickers: saved?.stickers ?? []))
        _bringsToLife = State(initialValue: saved?.bringsToLife ?? true)
        _line = State(initialValue: saved?.line ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: GridConstants.gapWide) {
                InkCanvas(controller: ink, aspectRatio: Self.aspect)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fit(width: $0) }
                    .frame(maxHeight: .infinity)
                TextField("Add a line", text: $line)
                    .font(DrawingLine.font)
                    .tracking(DrawingLine.tracking)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .frame(minHeight: GlassIconButton.defaultSide)
                    .onChange(of: line) { _, now in
                        if now.count > DrawingLine.maxLength { line = String(now.prefix(DrawingLine.maxLength)) }
                    }
                    .accessibilityLabel("Line under the drawing")
                Toggle(isOn: $bringsToLife) {
                    Text("Bring It to Life")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                .tint(AppColors.switchTrack)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.vertical, GridConstants.gapItem)
            .sheetTitle(monthName, drawn: false)
            .toolbar {
                InkSheetToolbar(confirm: "Done",
                                onCancel: { dismiss() },
                                onConfirm: done)
            }
            .background { WarmBackground().ignoresSafeArea() }
        }
    }

    /// The canvas's size, as laid out: the pen scaled to it, and a saved
    /// drawing made on another size of canvas scaled to fit this one.
    ///
    /// **Rescaled from the saved strokes every time the size changes, until
    /// you draw.** The sheet lays the canvas out more than once on its way up,
    /// and the first width it reports is not the last: scaling once, on the
    /// first, drew the saved drawing at a third of its size in the corner
    /// (seen in the simulator, 2026-10-05).
    private func fit(width: CGFloat) {
        let size = CGSize(width: width, height: width / Self.aspect)
        guard size.width > 0, size != canvasSize else { return }
        canvasSize = size
        ink.penWidth = InkPen.monthWidth(onCanvasOfHeight: size.height, shownAt: Self.shownHeight)
        if !ink.canUndo, let saved, let strokes = try? PKDrawing(data: saved.strokes) {
            let k = size.width / saved.canvasWidth
            ink.load(abs(k - 1) < 0.001 ? strokes
                     : strokes.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                     stickers: (saved.stickers ?? []).map { $0.scaled(by: k) })
            baseline = ink.drawing.dataRepresentation()
            baselineStickers = ink.stickers
        }
    }

    private func done() {
        HapticsEngine.lightTap()
        // Opened and closed with nothing changed writes nothing.
        let untouched = saved.map {
            baseline == ink.drawing.dataRepresentation() && baselineStickers == ink.stickers
                && $0.bringsToLife == bringsToLife && $0.line == DrawingLine.kept(line)
        } ?? ink.isEmpty
        if !untouched {
            MonthDrawingStore.shared.save(ink.drawing, stickers: ink.stickers, canvas: canvasSize,
                                          bringsToLife: bringsToLife, line: line, for: month)
        }
        dismiss()
    }
}

/// The month in an editor's title: "October", from "2026-10".
enum MonthName {
    static func of(_ month: String) -> String {
        let parts = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, (1...12).contains(parts[1]) else { return "" }
        return DateFormatter().standaloneMonthSymbols[parts[1] - 1]
    }
}

/// **The one clue to a hidden gesture** (spec section 4, "Entry"; NN/g:
/// hidden gestures need a clue and a second way in). Shown once, on about
/// the third visit to Memories and only after the month's drawing has
/// played, so it arrives on a page that has already shown what it is
/// pointing at. Invalidated the first time the drawing is made yours, from
/// the hold or from Settings, so it never explains a thing you have done.
struct MonthDrawingTip: Tip {
    static let visited = Tips.Event(id: "memories.visited")
    @Parameter static var artPlayed: Bool = false

    var title: Text { Text("Hold the drawing to make it yours") }

    var rules: [Rule] {
        #Rule(Self.$artPlayed) { $0 == true }
        #Rule(Self.visited) { $0.donations.count >= 3 }
    }

    var options: [any TipOption] { [Tips.MaxDisplayCount(1)] }

    /// The drawing was made yours: the tip has nothing left to say.
    static func used() {
        MonthDrawingTip().invalidate(reason: .actionPerformed)
    }
}
