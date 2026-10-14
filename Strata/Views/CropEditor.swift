import SwiftUI

/// **Move a photo inside its frame** (the owner, 2026-10-11: "make it so
/// you are able to edit the crop of the photos in the add sheet and in the
/// photostrip edit screen").
///
/// A block shows the middle of its photo unless the window was dragged at
/// the camera's review, and once the photo was on a win there was no way to
/// move it: a face cut off by a Quick block stayed cut off. This is the one
/// place to do it from, for a win's block and for a frame on the strip.
///
/// The frame holds still and the photo moves under the finger, as setting a
/// profile photo does, and a pinch zooms it (the owner, 2026-10-13: "you
/// should be able to move the crop like zoom in that goes for all the
/// cropping"). The photo runs on past the box, faded, so you can see what
/// there is to bring in (`CropBox`). What is kept is the camera's own number (`crop`: how
/// far the window sits from the middle, in fractions of the photo as it is
/// drawn), so the block, the replay and the strip all read it the way they
/// already read one from the camera (`CachedImageView.shift`), and beside
/// it how far in the window is (`PhotoWindow`).
struct CropEditor: View {
    let image: UIImage
    /// The frame's width over its height.
    let aspect: CGFloat
    let onDone: (CGPoint, CGFloat) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var crop: CGPoint
    @State private var zoom: CGFloat
    /// **How far each gesture had got at its last event, and which gesture
    /// that was** (by where it began). The drag and the pinch run together
    /// and each reports a total since it started, so each is applied as the
    /// step since its own last event. Re-basing one from the other made the
    /// photo jump when a finger lifted, and a gesture that is cancelled never
    /// says it ended, so the next one is told apart by its starting point
    /// (found by review, 2026-10-13).
    @State private var lastDrag: (from: CGPoint, moved: CGSize)?
    @State private var lastPinch: (from: CGPoint, by: CGFloat)?

    init(image: UIImage, aspect: CGFloat, crop: CGPoint, zoom: CGFloat = 1,
         onDone: @escaping (CGPoint, CGFloat) -> Void) {
        self.image = image
        self.aspect = max(aspect, 0.1)
        self.onDone = onDone
        _crop = State(initialValue: crop)
        _zoom = State(initialValue: PhotoWindow.zoom(zoom))
    }

    /// How far the window may sit from the middle on each axis, for a photo
    /// filled into `frame`: half of what hangs outside it. Zoomed in, more
    /// hangs outside, so there is further to go.
    static func range(photo: CGSize, frame: CGSize, zoom: CGFloat = 1) -> CGSize {
        CachedImageView.range(photo: photo, frame: frame, zoom: zoom)
    }

    /// `crop` held inside the photo, so the frame never shows past its edge.
    static func clamped(_ crop: CGPoint, photo: CGSize, frame: CGSize, zoom: CGFloat = 1) -> CGPoint {
        CachedImageView.held(crop, photo: photo, frame: frame, zoom: zoom)
    }

    /// One step of zoom, for VoiceOver's swipe up and down.
    static let step: CGFloat = 0.25
    /// How tall the line of words under the photo is, measured, so the box
    /// sits in the middle of what is left.
    @State private var hintHeight: CGFloat = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // **The photo runs on under the header and the words, and the
                // system softens it there** (the owner, 2026-10-13: "make sure
                // the clean header blur is there like it is elsewhere"). It
                // was cut to its room and faded out by a gradient drawn here,
                // which is the hand-built scrim `ScrollEdge` exists to avoid.
                // The blur belongs to a scroll view's edge, so the photo is
                // in one, held still.
                hinted(
                    ScrollView {
                        stage(in: CGSize(width: geo.size.width, height: max(1, geo.size.height - hintHeight)))
                    }
                    .scrollDisabled(true)
                    .softScrollEdge([.top, .bottom])
                )
            }
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Move Photo", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Text("Cancel").sheetAction(.cancel) }
                        .buttonStyle(.pressWord)
                }
                BareToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticsEngine.lightTap()
                        // Held inside the photo for this frame, whether or
                        // not it was touched: a crop handed in from another
                        // shape of block is put right on the way out.
                        onDone(Self.clamped(crop, photo: image.size, frame: CGSize(width: aspect, height: 1), zoom: zoom),
                               zoom)
                        dismiss()
                    } label: { Text("Done").sheetAction(.confirm) }
                        .buttonStyle(.pressWord)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    /// The words under the photo, as a bar: what the photo passes under at
    /// the bottom, as it passes under the title at the top.
    @ViewBuilder
    private func hinted(_ view: some View) -> some View {
        if #available(iOS 26.0, *) {
            view.safeAreaBar(edge: .bottom, spacing: 0) { hint }
        } else {
            view.safeAreaInset(edge: .bottom, spacing: 0) { hint }
        }
    }

    private var hint: some View {
        // On glass made for words over a photograph: the photo runs under
        // it now, and bare on river stones the line could not be read (seen
        // 2026-10-13).
        Text("Drag to move, pinch to zoom.")
            .font(Typography.headerSmall)
            .foregroundStyle(AppColors.inkPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCapsule(carriesType: true, interactive: false)
            .frame(maxWidth: .infinity)
            .padding(.vertical, GridConstants.gapItem)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hintHeight = $0 }
    }

    /// The photo, the box over it, and the finger on both.
    private func stage(in size: CGSize) -> some View {
        let room = CGSize(width: size.width - GridConstants.horizontalPadding * 2,
                          height: size.height - GridConstants.gapSection * 2)
        let width = max(1, min(room.width, room.height * aspect))
        let frame = CGSize(width: width, height: width / aspect)
        let drawn = CachedImageView.filled(image.size, in: frame, zoom: zoom)
        let shift = CachedImageView.shift(crop: crop, photo: image.size, frame: frame, zoom: zoom)
        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: drawn.width, height: drawn.height)
                .offset(shift)
            CropBox(box: frame, radius: CropBox.radius(for: frame))
        }
        // Not clipped: what hangs past this room is what the bars blur.
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    // The picture follows the finger: moved right, the
                    // window sits further left.
                    let before = lastDrag?.from == drag.startLocation ? (lastDrag?.moved ?? .zero) : .zero
                    lastDrag = (drag.startLocation, drag.translation)
                    let moved = CGPoint(x: crop.x - (drag.translation.width - before.width) / max(drawn.width, 1),
                                        y: crop.y - (drag.translation.height - before.height) / max(drawn.height, 1))
                    crop = Self.clamped(moved, photo: image.size, frame: frame, zoom: zoom)
                }
                .onEnded { _ in lastDrag = nil }
                .simultaneously(with: MagnifyGesture()
                    .onChanged { pinch in
                        // About the box's middle: the window stays where it
                        // is on the photo and takes less of it. Zooming out
                        // near an edge brings the window back inside.
                        let before = lastPinch?.from == pinch.startLocation ? (lastPinch?.by ?? 1) : 1
                        lastPinch = (pinch.startLocation, pinch.magnification)
                        zoom = PhotoWindow.zoom(zoom * pinch.magnification / max(before, 0.01))
                        crop = Self.clamped(crop, photo: image.size, frame: frame, zoom: zoom)
                    }
                    .onEnded { _ in lastPinch = nil })
        )
        .accessibilityElement()
        .accessibilityLabel("Photo")
        .accessibilityValue("Zoom \(Int((zoom * 100).rounded())) percent")
        .accessibilityHint("Drag to move it inside its frame. Swipe up or down to zoom.")
        .accessibilityAdjustableAction { direction in
            let next = PhotoWindow.zoom(zoom + (direction == .increment ? Self.step : -Self.step))
            zoom = next
            crop = Self.clamped(crop, photo: image.size, frame: frame, zoom: next)
        }
        .accessibilityIdentifier("cropStage")
    }
}
