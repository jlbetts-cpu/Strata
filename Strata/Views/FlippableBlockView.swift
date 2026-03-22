import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Smart Brick View (Clay Cartridge)

struct FlippableBlockView: View {
    let block: PlacedBlock
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let modelContext: ModelContext
    var onExpandPhoto: ((String) -> Void)? = nil

    @State private var showCameraPrompt = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var autoDismissTask: Task<Void, Never>? = nil
    @State private var tapTrigger: Int = 0
    @State private var breathePhase: Bool = false
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.towerFilterMode) private var towerFilterMode

    private var style: CategoryStyle { block.habit.category.style }
    private var isBig: Bool { block.columnSpan > 1 || block.rowSpan > 1 }
    private var hasImage: Bool { block.log.imageFileName != nil }

    private var timeText: String? {
        BlockTimeFormatter.displayText(
            filterMode: towerFilterMode,
            dateString: block.log.dateString,
            scheduledTime: block.habit.scheduledTime,
            durationMinutes: block.habit.blockSize.durationMinutes,
            completedAt: block.log.completedAt
        )
    }

    var body: some View {
        ZStack {
            if hasImage {
                // Photo block — loaded via CachedImageView
                CachedImageView(
                    fileName: block.log.imageFileName,
                    width: width,
                    height: height,
                    cornerRadius: 0
                )

                // Subtle warm vignette — safety net for icon on bright photos
                RadialGradient(
                    colors: [
                        .clear,
                        AppColors.warmBlack.opacity(0.12)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: min(width, height) * 0.25,
                    endRadius: max(width, height) * 0.85
                )

                // Warm dark scrim — gentle fade for text readability
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: AppColors.warmBlack.opacity(0.45), location: 0.70),
                        .init(color: AppColors.warmBlack.opacity(0.65), location: 1.0)
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

            // Text content: title + time + category icon
            BlockContentOverlay(
                title: block.habit.title,
                category: block.habit.category,
                rowSpan: block.rowSpan,
                timeText: timeText,
                pendingXPText: nil,
                hasImage: hasImage
            )
            .opacity(showCameraPrompt ? 0 : 1)

            // Camera prompt
            if !hasImage {
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
                .compositingGroup()
        )
        .shadow(
            color: .black.opacity(GridConstants.adaptiveShadowOpacity(GridConstants.shadowOpacity, colorScheme: colorScheme)),
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
            if hasImage {
                if let fileName = block.log.imageFileName {
                    onExpandPhoto?(fileName)
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
            if !reduceMotion {
                let delay = Double.random(in: 0...0.5)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let breatheDuration = Double.random(in: 2.7...3.3)
                    withAnimation(.easeInOut(duration: breatheDuration).repeatForever(autoreverses: true)) {
                        breathePhase = true
                    }
                }
            }
        }
        .onDisappear {
            breathePhase = false
        }
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    // MARK: - Photo Capture

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let img = await Task.detached { UIImage(data: data) }.value else { return }

        let (maxDim, quality): (CGFloat, CGFloat) = switch block.habit.blockSize {
        case .small: (512, 0.70)
        case .medium: (768, 0.75)
        case .hard: (1024, 0.80)
        }
        do {
            let fileName = try await ImageManager.shared.save(image: img, for: block.log.id, maxDimension: maxDim, quality: quality)
            withAnimation(.easeInOut(duration: 0.3)) {
                showCameraPrompt = false
            }
            block.log.imageFileName = fileName
            try? modelContext.save()

            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        } catch {
            // Save failed — silently ignore
        }
    }
}
