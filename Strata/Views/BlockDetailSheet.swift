import SwiftUI
import SwiftData
import PhotosUI

struct BlockDetailSheet: View {
    let block: PlacedBlock
    let modelContext: ModelContext

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var sheetWidth: CGFloat = 0
    @State private var showPhotoError = false
    @State private var isSavingPhoto = false
    @State private var showPhotoSourceDialog = false
    @State private var showLibraryPicker = false
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss

    private var style: CategoryStyle { block.habit.category.style }
    private var hasImage: Bool { block.log.imageFileName != nil }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Full background in category gradient
            style.gradient
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(block.habit.title)
                            .font(Typography.appTitle)
                            .foregroundStyle(.white)

                        if let completedAt = block.log.completedAt {
                            Text(completedAt.formatted(.dateTime.month(.wide).day().hour().minute()))
                                .font(Typography.bodyMedium)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        // Category pill
                        Text(block.habit.category.rawValue.capitalized)
                            .font(Typography.bodySmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                    }
                    .padding(.top, 40)

                    // Photo area
                    proofOfWorkSection
                        .padding(.horizontal, 24)

                    // Stats row
                    HStack(spacing: 16) {
                        statPill(
                            label: "SIZE",
                            value: block.habit.blockSize.rawValue.capitalized
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }

            // Close button
            Button {
                HapticsEngine.lightTap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .iconSize(GridConstants.iconAction, relativeTo: .caption, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onGeometryChange(for: CGFloat.self, of: { proxy in
            proxy.size.width
        }, action: { newWidth in
            sheetWidth = newWidth
        })
        .confirmationDialog("Add Photo", isPresented: $showPhotoSourceDialog) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showLibraryPicker = true }
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onCapture: { image in
                    showCamera = false
                    Task { await savePhotoDirectly(image) }
                },
                onCancel: { showCamera = false }
            )
        }
        .onChange(of: selectedItem) { _, newItem in
            HapticsEngine.lightTap()
            Task { await loadPhoto(from: newItem) }
        }
        .alert("Photo couldn't be saved", isPresented: $showPhotoError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("Try again or choose a different photo.")
        })
        .onChange(of: showPhotoError) { _, isError in
            if isError { HapticsEngine.error() }
        }
    }

    // MARK: - Proof of Work Section

    @ViewBuilder
    private var proofOfWorkSection: some View {
        if hasImage {
            // Show the captured photo
            ZStack(alignment: .bottomTrailing) {
                CachedImageView(
                    fileName: block.log.imageFileName,
                    width: max(sheetWidth - 48, 280),
                    height: 320,
                    cornerRadius: 0,
                    fullResolution: true
                )
                .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
                .accessibilityLabel("\(block.habit.title) photo")
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

                // Replace photo button
                Button {
                    showPhotoSourceDialog = true
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .iconSize(GridConstants.iconAction, relativeTo: .caption, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
                .padding(12)

                // Loading indicator
                if isSavingPhoto {
                    ZStack {
                        RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
                            .fill(.black.opacity(0.3))
                        ProgressView().tint(.white)
                    }
                }
            }
        } else {
            // Empty state — photo picker placeholder
            Button {
                showPhotoSourceDialog = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .iconSize(GridConstants.iconHero, relativeTo: .body, weight: .light)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Add Photo")
                        .font(Typography.blockTitle)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(.white.opacity(0.12))
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1.5)
                )
            }
        }
    }

    // MARK: - Stat Pill

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Typography.headerMedium)
                .foregroundStyle(.white)

            Text(label)
                .font(Typography.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Photo Capture

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let img = await Task.detached { UIImage(data: data) }.value else { return }
        await savePhotoDirectly(img)
    }

    @MainActor
    private func savePhotoDirectly(_ img: UIImage) async {
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        let (maxDim, quality): (CGFloat, CGFloat) = switch block.habit.blockSize {
        case .small: (512, 0.70)
        case .medium: (768, 0.75)
        case .hard: (1024, 0.80)
        }
        do {
            // Delete old cached image before overwriting
            if let oldFileName = block.log.imageFileName {
                ImageManager.shared.deleteImage(fileName: oldFileName)
            }
            block.log.imageFileName = nil  // force CachedImageView to reset
            let fileName = try await ImageManager.shared.save(image: img, for: block.log.id, maxDimension: maxDim, quality: quality)
            block.log.imageFileName = fileName
            try? modelContext.save()
        } catch {
            showPhotoError = true
        }
    }
}
