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

    @Environment(\.dismiss) private var dismiss
    @State private var ink = InkController()
    @State private var stripHeight: CGFloat = 0
    /// The strip with every win on it: the editor's width is fitted to this,
    /// once, so taking a win off shortens the paper rather than resizing it,
    /// and the doodles stay where they were drawn.
    @State private var tallest: CGFloat = 0
    @State private var canvas: CGSize = .zero
    @State private var loaded = false

    private var frames: [PhotoStrip.Frame] { strip.frames(excluding: excluded) }

    var body: some View {
        NavigationStack {
            VStack(spacing: GridConstants.gapWide) {
                choices
                GeometryReader { geo in
                    let width = fittedWidth(in: geo.size)
                    InkCanvas(controller: ink,
                              aspectRatio: stripHeight > 0 ? StripDecor.canvasWidth / stripHeight : 0.4,
                              ground: AnyShapeStyle(Color.clear),
                              cornerRadius: width * 0.02,
                              lightInk: paper == .black,
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
                    dismiss()
                })
            }
            .background { WarmBackground().ignoresSafeArea() }
        }
        .interactiveDismissDisabled(ink.canUndo)
    }

    /// Which wins are on it, and its paper.
    private var choices: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GridConstants.gapTight) {
                    ForEach(strip.candidates) { frame in
                        let on = !excluded.contains(frame.id)
                        Button {
                            HapticsEngine.lightTap()
                            if on { excluded.insert(frame.id) } else { excluded.remove(frame.id) }
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
            HStack(spacing: GridConstants.gapLabel) {
                ForEach(StripPaper.allCases) { option in
                    Button {
                        HapticsEngine.lightTap()
                        withAnimation(GridConstants.crossFade) { paper = option }
                    } label: {
                        Circle()
                            .fill(option.ground)
                            .overlay { Circle().strokeBorder(GridConstants.fillHairline, lineWidth: 1) }
                            .frame(width: 30, height: 30)
                            .padding(4)
                            .overlay {
                                if option == paper {
                                    Circle().strokeBorder(AppColors.inkPrimary, lineWidth: 2)
                                }
                            }
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel("\(option.name) paper")
                    .accessibilityAddTraits(option == paper ? .isSelected : [])
                }
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
        guard !loaded, let kept = StripDecor.load(owner: strip.owner, day: strip.day), kept.canvas.width > 0 else { return }
        loaded = true
        let k = size.width / kept.canvas.width
        ink.load(kept.drawing.transformed(using: CGAffineTransform(scaleX: k, y: k)),
                 stickers: kept.stickers.map { $0.scaled(by: k) })
    }
}
