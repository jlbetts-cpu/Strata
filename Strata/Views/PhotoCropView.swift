import SwiftUI

/// Context needed to render the block preview overlay on the crop screen.
struct BlockPreviewContext {
    let title: String
    let category: HabitCategory
    let blockSize: BlockSize
    let timeText: String?
}

/// Reusable photo crop view — aspect-ratio-aware crop with block preview overlay.
/// NavigationStack handles safe area. Geometric overlay (no broken mask).
struct PhotoCropView: View {
    let image: UIImage
    var blockContext: BlockPreviewContext? = nil
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropWidth: CGFloat = 0
    @State private var cropHeight: CGFloat = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let aspectRatio = blockContext?.blockSize.cropAspectRatio ?? 1.0
                let maxW = w - 48
                let maxH = h - 80
                let (cropW, cropH): (CGFloat, CGFloat) = if maxW / maxH > aspectRatio {
                    (maxH * aspectRatio, maxH)
                } else {
                    (maxW, maxW / aspectRatio)
                }

                ZStack {
                    Color.black.ignoresSafeArea()

                    // Image layer — pinch to zoom, drag to reposition
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropW, height: cropH)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipShape(Rectangle())
                        .frame(width: cropW, height: cropH)
                        .clipped()
                        .gesture(pinchAndPan)

                    // Darkened border overlay — geometric rectangles (Apple Photos pattern)
                    VStack(spacing: 0) {
                        Color.black.opacity(0.5)
                        HStack(spacing: 0) {
                            Color.black.opacity(0.5)
                            Color.clear.frame(width: cropW, height: cropH)
                            Color.black.opacity(0.5)
                        }
                        .frame(height: cropH)
                        Color.black.opacity(0.5)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    // Block preview — shows how photo will look on the tower
                    ZStack {
                        RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)

                        // Match FlippableBlockView image gradients
                        RadialGradient(
                            colors: [.clear, AppColors.warmBlack.opacity(0.12)],
                            center: UnitPoint(x: 0.5, y: 0.4),
                            startRadius: min(cropW, cropH) * 0.25,
                            endRadius: max(cropW, cropH) * 0.85
                        )
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.35),
                                .init(color: AppColors.warmBlack.opacity(0.45), location: 0.70),
                                .init(color: AppColors.warmBlack.opacity(0.65), location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )

                        if let ctx = blockContext {
                            BlockContentOverlay(
                                title: ctx.title,
                                category: ctx.category,
                                rowSpan: ctx.blockSize.rowSpan,
                                timeText: ctx.timeText,
                                hasImage: true
                            )
                        }
                    }
                    .frame(width: cropW, height: cropH)
                    .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .onAppear {
                    cropWidth = cropW
                    cropHeight = cropH
                }
                .onChange(of: geo.size) { _, _ in
                    cropWidth = cropW
                    cropHeight = cropH
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsEngine.lightTap()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticsEngine.snap()
                        let cropped = cropImage()
                        onCrop(cropped)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { HapticsEngine.lightTap() }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Gestures

    private var pinchAndPan: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(1.0, min(5.0, lastScale * value.magnification))
            }
            .onEnded { _ in lastScale = scale }
            .simultaneously(with:
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastOffset = offset }
            )
    }

    // MARK: - Crop Math

    private func cropImage() -> UIImage {
        guard cropWidth > 0, cropHeight > 0 else { return image }
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let cropAspect = cropWidth / cropHeight

        // scaledToFill: image fills the crop rect completely
        let displaySize: CGSize
        if imageAspect > cropAspect {
            // Image is wider than crop — height-matched
            displaySize = CGSize(width: cropHeight * imageAspect, height: cropHeight)
        } else {
            // Image is taller than crop — width-matched
            displaySize = CGSize(width: cropWidth, height: cropWidth / imageAspect)
        }

        let scaledDisplaySize = CGSize(
            width: displaySize.width * scale,
            height: displaySize.height * scale
        )
        let pixelsPerPoint = imageSize.width / scaledDisplaySize.width

        let cropOriginX = (scaledDisplaySize.width / 2 - cropWidth / 2 - offset.width) * pixelsPerPoint
        let cropOriginY = (scaledDisplaySize.height / 2 - cropHeight / 2 - offset.height) * pixelsPerPoint
        let cropWPixels = cropWidth * pixelsPerPoint
        let cropHPixels = cropHeight * pixelsPerPoint

        let cropRect = CGRect(
            x: max(0, cropOriginX),
            y: max(0, cropOriginY),
            width: min(cropWPixels, imageSize.width - max(0, cropOriginX)),
            height: min(cropHPixels, imageSize.height - max(0, cropOriginY))
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
