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
    let modelContext: ModelContext
    var onExpandPhoto: ((Data) -> Void)? = nil

    @State private var showCameraPrompt = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var displayImage: UIImage? = nil
    @State private var autoDismissTask: Task<Void, Never>? = nil
    @State private var tapTrigger: Int = 0
    @State private var breathePhase: Bool = false
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: CategoryStyle { block.habit.category.style }
    private var isBig: Bool { block.columnSpan > 1 || block.rowSpan > 1 }

    private var timeText: String? {
        BlockTimeFormatter.timeRange(
            scheduledTime: block.habit.scheduledTime,
            durationMinutes: block.habit.blockSize.durationMinutes,
            completedAt: block.log.completedAt
        )
    }

    var body: some View {
        ZStack {
            if let image = displayImage {
                // Photo block
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()

                // Darker gradient overlay for text legibility
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.58),
                        .init(color: Color(red: 0.22, green: 0.22, blue: 0.22).opacity(0.80), location: 0.81)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

            } else {
                // Color fill — gradient from light tint at top to base color
                LinearGradient(
                    stops: [
                        .init(color: style.lightTint, location: 0.0),
                        .init(color: style.baseColor, location: 0.3),
                        .init(color: style.baseColor, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Frosted gradient overlay — subtle white mist at the bottom
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

            }

            // Text content: title + time — white, bottom-left
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(block.habit.title)
                    .font(Typography.bodyMedium)
                    .tracking(0)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(block.rowSpan > 1 ? 3 : 1)
                    .minimumScaleFactor(0.65)

                if let time = timeText {
                    Text(time)
                        .font(Typography.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 10)
            .padding(.bottom, 8)
            .padding(.trailing, 6)
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Overlay 1: Crisp white border — visible at top, fades toward bottom (breathing shimmer)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(breathePhase ? 0.95 : 0.85), location: 0.0),
                            .init(color: .white.opacity(0.4), location: 0.4),
                            .init(color: .white.opacity(0.0), location: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
        )
        // Overlay 2: Diffused white border — invisible at top, soft glow at bottom
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.35), location: 0.45),
                            .init(color: .white.opacity(0.6), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 4
                )
                .blur(radius: 6)
        )
        .shadow(
            color: .black.opacity(GridConstants.shadowOpacity),
            radius: GridConstants.shadowRadius,
            x: 0,
            y: GridConstants.shadowY
        )
        // Tap bounce: fast squash → bouncy pop-back
        .phaseAnimator([false, true], trigger: tapTrigger) { content, phase in
            content
                .scaleEffect(
                    x: phase ? GridConstants.tapScaleX : 1.0,
                    y: phase ? GridConstants.tapScaleY : 1.0
                )
                .brightness(phase ? -0.03 : 0)
        } animation: { phase in
            phase ? GridConstants.tapSquashSpring : GridConstants.tapPopSpring
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: tapTrigger)
        .contentShape(Rectangle())
        .onTapGesture {
            tapTrigger += 1
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
        .onAppear {
            loadExistingImage()
            if !reduceMotion {
                withAnimation(.easeInOut(duration: GridConstants.breatheDuration).repeatForever(autoreverses: true)) {
                    breathePhase = true
                }
            }
        }
        .onDisappear { displayImage = nil }
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    // MARK: - Photo Loading

    private func loadExistingImage() {
        guard let data = block.log.imageData else { return }
        let targetWidth = width * displayScale
        Task.detached {
            let thumbnail = Self.downsample(data: data, maxPixelWidth: targetWidth)
            await MainActor.run {
                displayImage = thumbnail
            }
        }
    }

    nonisolated private static func downsample(data: Data, maxPixelWidth: CGFloat) -> UIImage? {
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
