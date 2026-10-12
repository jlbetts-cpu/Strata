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
/// profile photo does. What is kept is the camera's own number (`crop`: how
/// far the window sits from the middle, in fractions of the photo as it is
/// drawn), so the block, the replay and the strip all read it the way they
/// already read one from the camera (`CachedImageView.shift`).
struct CropEditor: View {
    let image: UIImage
    /// The frame's width over its height.
    let aspect: CGFloat
    let onDone: (CGPoint) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var crop: CGPoint
    @State private var start: CGPoint

    init(image: UIImage, aspect: CGFloat, crop: CGPoint, onDone: @escaping (CGPoint) -> Void) {
        self.image = image
        self.aspect = max(aspect, 0.1)
        self.onDone = onDone
        _crop = State(initialValue: crop)
        _start = State(initialValue: crop)
    }

    /// How far the window may sit from the middle on each axis, for a photo
    /// filled into `frame`: half of what hangs outside it.
    static func range(photo: CGSize, frame: CGSize) -> CGSize {
        let drawn = CachedImageView.filled(photo, in: frame)
        guard drawn.width > 0, drawn.height > 0 else { return .zero }
        return CGSize(width: max(0, (drawn.width - frame.width) / 2 / drawn.width),
                      height: max(0, (drawn.height - frame.height) / 2 / drawn.height))
    }

    /// `crop` held inside the photo, so the frame never shows past its edge.
    static func clamped(_ crop: CGPoint, photo: CGSize, frame: CGSize) -> CGPoint {
        let range = range(photo: photo, frame: frame)
        return CGPoint(x: min(max(crop.x, -range.width), range.width),
                       y: min(max(crop.y, -range.height), range.height))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let room = CGSize(width: geo.size.width - GridConstants.horizontalPadding * 2,
                                  height: geo.size.height - GridConstants.gapSection * 2)
                let width = max(1, min(room.width, room.height * aspect))
                let frame = CGSize(width: width, height: width / aspect)
                let drawn = CachedImageView.filled(image.size, in: frame)
                let shift = CachedImageView.shift(crop: crop, photo: image.size, frame: frame)
                VStack(spacing: GridConstants.gapItem) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: drawn.width, height: drawn.height)
                        .offset(shift)
                        .frame(width: frame.width, height: frame.height)
                        .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: min(frame.width, frame.height)),
                                                    style: .continuous))
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    // The picture follows the finger: moved
                                    // right, the window sits further left.
                                    let moved = CGPoint(x: start.x - drag.translation.width / max(drawn.width, 1),
                                                        y: start.y - drag.translation.height / max(drawn.height, 1))
                                    crop = Self.clamped(moved, photo: image.size, frame: frame)
                                }
                                .onEnded { _ in start = crop }
                        )
                        .accessibilityLabel("Photo")
                        .accessibilityHint("Drag to move it inside its frame.")
                    Text("Drag to move the photo.")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        onDone(crop)
                        dismiss()
                    } label: { Text("Done").sheetAction(.confirm) }
                        .buttonStyle(.pressWord)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }
}
