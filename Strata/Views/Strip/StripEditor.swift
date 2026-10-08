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
                    StripDecor.save(ink.drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                                    stickers: ink.stickers.map { $0.scaled(by: k) },
                                    canvas: CGSize(width: canvas.width * k, height: canvas.height * k),
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
        guard !ink.canUndo, let kept = StripDecor.load(owner: strip.owner, day: strip.day), kept.canvas.width > 0 else { return }
        let k = size.width / kept.canvas.width
        ink.load(kept.drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                 stickers: kept.stickers.map { $0.scaled(by: k).clamped(toCanvas: size) })
    }
}
