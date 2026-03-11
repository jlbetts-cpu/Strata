import SwiftUI
import SwiftData
import PhotosUI

struct BlockDetailSheet: View {
    let block: PlacedBlock
    let modelContext: ModelContext

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var displayImage: UIImage? = nil
    @Environment(\.dismiss) private var dismiss

    private var style: CategoryStyle { block.habit.category.style }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Full background in category gradient
            style.gradient
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 6) {
                        Text(block.habit.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        if let completedAt = block.log.completedAt {
                            Text(completedAt.formatted(.dateTime.month(.wide).day().hour().minute()))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        // Category pill
                        Text(block.habit.category.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                    }
                    .padding(.top, 40)

                    // Photo area
                    proofOfWorkSection
                        .padding(.horizontal, 24)

                    // Stats row
                    if let xp = block.log.pendingXP {
                        HStack(spacing: 16) {
                            statPill(label: "XP", value: "+\(xp)")
                            if block.log.isBonusBlock {
                                statPill(label: "BONUS", value: "★")
                            }
                            statPill(
                                label: "SIZE",
                                value: block.habit.blockSize.rawValue.capitalized
                            )
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .onAppear(perform: loadExistingImage)
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    // MARK: - Proof of Work Section

    @ViewBuilder
    private var proofOfWorkSection: some View {
        if let image = displayImage {
            // Show the captured photo
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

                // Replace photo button
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(12)
            }
        } else {
            // Empty state — photo picker placeholder
            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack(spacing: 14) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Add Proof of Work")
                        .font(.system(size: 16, weight: .semibold))
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
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Photo Handling

    private func loadExistingImage() {
        if let data = block.log.imageData, let img = UIImage(data: data) {
            displayImage = img
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let img = UIImage(data: data) else { return }

        // Compress to JPEG to keep storage reasonable
        let compressed = img.jpegData(compressionQuality: 0.8)

        withAnimation(.easeOut(duration: 0.25)) {
            displayImage = img
        }

        block.log.imageData = compressed
        try? modelContext.save()
    }
}
