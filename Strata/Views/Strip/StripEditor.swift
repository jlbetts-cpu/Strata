import PencilKit
import SwiftUI

/// **Make the strip yours** (the owner, 2026-10-06: "adding stickers all over
/// and being able to add doodles is a must ... make it so the user is able to
/// edit which ones go into the photostrip"). Which wins are on it, its paper,
/// and the app's own pen and stickers drawn right on it, over the frames.
struct StripEditor: View {
    let strip: PhotoStrip
    @Binding var excluded: Set<UUID>
    @Binding var paper: StripPaper
    /// Which tool it opens on: the booth has a button for each.
    var opening: Opening = .pen

    enum Opening: String, Identifiable {
        case pen, stickers
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var ink = InkController()
    @State private var stripHeight: CGFloat = 0
    /// The strip with every win on it: the editor's width is fitted to this,
    /// once, so taking a win off shortens the paper rather than resizing it,
    /// and the doodles stay where they were drawn.
    @State private var tallest: CGFloat = 0
    @State private var canvas: CGSize = .zero
    /// **Which wins are on it, as edited here**: written back only on Done.
    /// It edited the booth's own set live, so Cancel or a swipe down still
    /// kept every frame taken off (the 2026-10-08 audit).
    @State private var draft: Set<UUID>?
    private var current: Set<UUID> { draft ?? excluded }
    /// **Marks follow their photos** (`StripDecorPlacement`). The layout the
    /// ink on the canvas was drawn over, in `canvasWidth` points; marks on
    /// photos taken off here, kept to come back with them; and whether the
    /// canvas holds anything the file does not, so a resize never reloads
    /// over it.
    @State private var inkLayout: StripAnchors?
    @State private var parked: [String: StripDecorPlacement.Parked] = [:]
    @State private var moved = false
    private var touched: Bool { ink.canUndo || moved }

    private var frames: [PhotoStrip.Frame] { strip.frames(excluding: current) }

    var body: some View {
        NavigationStack {
            VStack(spacing: GridConstants.gapWide) {
                choices
                GeometryReader { geo in
                    let width = fittedWidth(in: geo.size)
                    InkCanvas(controller: ink,
                              aspectRatio: stripHeight > 0 ? StripDecor.canvasWidth / stripHeight : 0.4,
                              ground: AnyShapeStyle(Color.clear),
                              cornerRadius: StripView.corner(forWidth: width),
                              lightInk: paper.lightInk,
                              darkInk: !paper.lightInk,
                              underlay: AnyView(StripView(frames: frames, day: strip.day, signature: strip.signature,
                                                          paper: paper, width: width, developed: 1)))
                        .frame(width: width)
                        .frame(maxWidth: .infinity)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fit(width: $0) }
                        .onChange(of: stripHeight) { fit(width: width) }
                        .onChange(of: frames.map(\.id)) { follow() }
                }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapItem)
            .background(alignment: .top) {
                // The strip's shape, measured once at the canvas width.
                StripView(frames: frames, day: strip.day, signature: strip.signature, paper: paper,
                          width: StripDecor.canvasWidth)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stripHeight = $0 }
                    .hidden()
            }
            .background(alignment: .top) {
                StripView(frames: strip.frames(excluding: []), day: strip.day, signature: strip.signature,
                          paper: paper, width: StripDecor.canvasWidth)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tallest = max(tallest, $0) }
                    .hidden()
            }
            .sheetTitle("Your Strip", drawn: false)
            .toolbar {
                InkSheetToolbar(confirm: "Done", onCancel: { dismiss() }, onConfirm: {
                    HapticsEngine.lightTap()
                    // Kept at the canvas width, so the strip draws it at any size.
                    let k = canvas.width > 0 ? StripDecor.canvasWidth / canvas.width : 1
                    // With the marks on photos taken off, where they were,
                    // and where those photos were, so they come back.
                    StripDecor.save(ink.drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                                    stickers: ink.stickers.map { $0.scaled(by: k) },
                                    canvas: CGSize(width: canvas.width * k, height: canvas.height * k),
                                    anchors: StripAnchors.of(frames), parked: parked,
                                    owner: strip.owner, day: strip.day)
                    if let draft { excluded = draft }
                    dismiss()
                })
            }
            .background { WarmBackground().ignoresSafeArea() }
        }
        .interactiveDismissDisabled(ink.canUndo || (draft != nil && draft != excluded))
        // Opened from the booth's sticker button: straight to the stickers,
        // once the sheet has risen (a popover from a sheet still rising
        // does not appear).
        .task {
            guard opening == .stickers else { return }
            try? await Task.sleep(for: .milliseconds(450))
            ink.wantsStickers = true
        }
    }

    /// Which wins are on it.
    private var choices: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GridConstants.gapTight) {
                    ForEach(strip.candidates) { frame in
                        // On the strip, not merely "not left out": only the
                        // first `PhotoStrip.most` make it, so a ninth showed
                        // ticked and was not there.
                        let on = frames.contains { $0.id == frame.id }
                        Button {
                            var next = current
                            if on {
                                // Never the last one: an empty strip is not a strip.
                                guard frames.count > 1 else { HapticsEngine.warning(); return }
                                next.insert(frame.id)
                            } else {
                                guard frames.count < PhotoStrip.most else { HapticsEngine.warning(); return }
                                next.remove(frame.id)
                            }
                            HapticsEngine.lightTap()
                            draft = next
                        } label: {
                            Image(uiImage: frame.picture)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .opacity(on ? 1 : 0.35)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .font(Typography.headerSmall)
                                        .foregroundStyle(on ? AppColors.inkPrimary : AppColors.inkTertiary)
                                        .background(Circle().fill(WarmBackground.top).padding(1))
                                        .padding(3)
                                }
                        }
                        .buttonStyle(.press)
                        .accessibilityLabel(frame.title.isEmpty ? "A win" : frame.title)
                        .accessibilityValue(on ? "On the strip" : "Off the strip")
                    }
                }
            }
            // The paper moved to the booth's one colour button.
            HStack(spacing: GridConstants.gapLabel) {
                if strip.candidates.count > PhotoStrip.most {
                    Text("Up to \(PhotoStrip.most) on a strip")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkTertiary)
                }
            }
        }
    }

    /// As wide as the strip can be with its controls under it in the room.
    private func fittedWidth(in size: CGSize) -> CGFloat {
        let ratio = max(tallest, stripHeight) > 0 ? max(tallest, stripHeight) / StripDecor.canvasWidth : 2.4
        let roomForControls: CGFloat = 64
        return max(120, min(240, (size.height - roomForControls) / ratio))
    }

    /// The canvas as laid out, and the strip's doodles loaded onto it.
    private func fit(width: CGFloat) {
        let ratio = stripHeight > 0 ? stripHeight / StripDecor.canvasWidth : 2.4
        let size = CGSize(width: width, height: width * ratio)
        guard size.width > 0, size != canvas else { return }
        canvas = size
        // **Reloaded at every size until you draw** (as `MonthDrawingEditor`
        // learned): the width settles after the first layout, and loading
        // once at the first width saved the drawing smaller on every Done.
        reload()
    }

    /// The kept drawing onto the canvas, each mark on its photo as the strip
    /// stands now. Only while nothing here is unsaved.
    private func reload() {
        guard !touched, canvas.width > 0 else { return }
        let now = StripAnchors.of(frames)
        // **Noted even with nothing kept yet** (found 2026-10-10 by review):
        // on a strip's first doodles there was no layout to move them from,
        // so taking a photo off left them where they were and saved them
        // against the new layout, on the wrong photo.
        inkLayout = now
        guard let kept = StripDecor.load(owner: strip.owner, day: strip.day), kept.canvas.width > 0 else { return }
        // `canvasWidth` points first: the anchors are kept at that width.
        let toKept = StripDecor.canvasWidth / kept.canvas.width
        var drawing = kept.drawing.transformed(using: CGAffineTransform(scaleX: toKept, y: toKept))
        var stickers = kept.stickers.map { $0.scaled(by: toKept) }
        var waiting = kept.parked
        if let then = kept.anchors {
            let move = StripDecorPlacement.move(drawing, stickers: stickers, from: then, to: now)
            drawing = move.drawing
            stickers = move.stickers
            waiting.merge(move.parked) { old, _ in old }
        }
        let back = StripDecorPlacement.restore(waiting, to: now)
        drawing.append(back.drawing)
        parked = back.parked
        show(drawing, stickers: stickers + back.stickers)
    }

    /// A photo taken off or put back: what is drawn on the canvas goes with
    /// its photo, and what was parked comes back with one returning.
    private func follow() {
        let now = StripAnchors.of(frames)
        guard touched, canvas.width > 0, let then = inkLayout else {
            reload()
            return
        }
        guard !then.matches(now) else { return }
        let k = StripDecor.canvasWidth / canvas.width
        let live = StripDecorPlacement.move(ink.drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                                            stickers: ink.stickers.map { $0.scaled(by: k) }, from: then, to: now)
        let back = StripDecorPlacement.restore(parked, to: now)
        var drawing = live.drawing
        drawing.append(back.drawing)
        // A photo is on the strip or off it, never both, so the two sets of
        // parked marks never share a photo.
        parked = back.parked.merging(live.parked) { _, new in new }
        inkLayout = now
        moved = true
        show(drawing, stickers: live.stickers + back.stickers)
    }

    /// `canvasWidth` points onto the canvas as laid out.
    private func show(_ drawing: PKDrawing, stickers: [InkSticker]) {
        let k = canvas.width / StripDecor.canvasWidth
        ink.load(drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                 stickers: stickers.map { $0.scaled(by: k).clamped(toCanvas: canvas) })
    }
}
