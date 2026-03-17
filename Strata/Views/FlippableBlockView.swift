import SwiftUI
import SwiftData
import PhotosUI
import ImageIO

// MARK: - Smart Brick View (Clay Cartridge)

struct FlippableBlockView: View {
    let block: PlacedBlock
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let exposedSegments: [Bool]
    let modelContext: ModelContext
    var onExpandPhoto: ((Data) -> Void)? = nil

    @State private var showCameraPrompt = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var displayImage: UIImage? = nil
    @State private var autoDismissTask: Task<Void, Never>? = nil

    private var style: CategoryStyle { block.habit.category.style }
    private var isBig: Bool { block.columnSpan > 1 || block.rowSpan > 1 }

    var body: some View {
        ZStack {
            if let image = displayImage {
                // Photo block
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            } else {
                // Solid base color — pure category hex
                Rectangle()
                    .fill(style.baseColor)
            }

            // Title — white, bottom-left
            Text(block.habit.title)
                .font(Typography.blockTitle)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .lineLimit(block.rowSpan > 1 ? 3 : 1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 12)
                .padding(.bottom, 12)
                .opacity(showCameraPrompt ? 0 : 1)

            // Camera prompt
            if displayImage == nil {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: isBig ? 8 : 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: isBig ? 24 : 16, weight: .light))
                            .foregroundStyle(.white.opacity(0.85))

                        if isBig {
                            Text("Add Proof")
                                .font(Typography.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(showCameraPrompt ? 1 : 0)
            }
        }
        .frame(width: width, height: height)
        // 1. Subtle volume gradient
        .overlay(
            LinearGradient(
                colors: [.white.opacity(0.1), .clear, .black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        // 2. Continuous top ledge highlight
        .overlay(alignment: .top) {
            if displayImage == nil {
                HStack(spacing: 0) {
                    ForEach(0..<exposedSegments.count, id: \.self) { i in
                        if exposedSegments[i] {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        } else {
                            Color.clear
                        }
                    }
                }
                .frame(height: 14)
            }
        }
        // 3. Specular gradient border
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.7), .white.opacity(0.1), .black.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // 4. Master clip
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        // 5. Soft drop shadow
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if displayImage != nil {
                if let data = block.log.imageData {
                    onExpandPhoto?(data)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCameraPrompt.toggle()
                }

                autoDismissTask?.cancel()
                if showCameraPrompt {
                    autoDismissTask = Task {
                        try? await Task.sleep(for: .seconds(3.0))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCameraPrompt = false
                        }
                    }
                }
            }
        }
        .onAppear { loadExistingImage() }
        .onDisappear { displayImage = nil }
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    // MARK: - Photo Loading

    private func loadExistingImage() {
        guard let data = block.log.imageData else { return }
        let targetWidth = width * UIScreen.main.scale
        Task.detached {
            let thumbnail = Self.downsample(data: data, maxPixelWidth: targetWidth)
            await MainActor.run {
                displayImage = thumbnail
            }
        }
    }

    private static func downsample(data: Data, maxPixelWidth: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }

        let downsampleOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelWidth,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOpts as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let img = UIImage(data: data) else { return }

        let compressed = img.jpegData(compressionQuality: 0.8)

        withAnimation(.easeInOut(duration: 0.3)) {
            showCameraPrompt = false
            displayImage = img
        }

        block.log.imageData = compressed
        try? modelContext.save()

        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
}
