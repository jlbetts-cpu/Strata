import SwiftUI
import SwiftData

struct DailyStoryCarousel: View {
    let blocks: [PlacedBlock]
    @Binding var activeBlockID: UUID?
    let modelContext: ModelContext

    @Environment(\.dismiss) private var dismissSheet
    @State private var decodedImages: [UUID: UIImage] = [:]

    private var activeBlock: PlacedBlock? {
        let id = activeBlockID ?? blocks.first?.id
        return blocks.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            // Background: blurred photo filling entire screen
            if let block = activeBlock,
               let img = decodedImages[block.id] {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 60)
                    .overlay(AppColors.warmBlack.opacity(0.7))
                    .ignoresSafeArea()
            } else {
                AppColors.warmBlack.ignoresSafeArea()
            }

            // Foreground: strict VStack for keyboard avoidance
            if blocks.isEmpty {
                Color.clear.onAppear { close() }
            } else if blocks.count == 1, let block = blocks.first {
                storyLayout(block: block)
            } else {
                TabView(selection: carouselBinding) {
                    ForEach(blocks) { block in
                        storyLayout(block: block)
                            .tag(block.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { decodeVisibleImages() }
        .onChange(of: activeBlockID) { decodeVisibleImages() }
    }

    private func decodeVisibleImages() {
        guard let activeID = activeBlockID ?? blocks.first?.id,
              let block = blocks.first(where: { $0.id == activeID }),
              decodedImages[block.id] == nil,
              let data = block.log.imageData else { return }
        Task.detached {
            guard let img = UIImage(data: data) else { return }
            await MainActor.run {
                decodedImages[block.id] = img
            }
        }
    }

    // Stable binding
    private var carouselBinding: Binding<UUID> {
        Binding(
            get: { activeBlockID ?? blocks.first?.id ?? UUID() },
            set: { activeBlockID = $0 }
        )
    }

    // MARK: - Story Layout (VStack)

    private func storyLayout(block: PlacedBlock) -> some View {
        let style = block.habit.category.style
        let date = block.log.completedAt ?? Date()

        return VStack(spacing: 0) {
            // Top bar: metadata + dismiss
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Category dot + title
                    HStack(spacing: 8) {
                        Circle()
                            .fill(style.gradient)
                            .frame(width: 8, height: 8)

                        Text(block.habit.title)
                            .font(Typography.headerMedium)
                            .foregroundStyle(.white)
                    }

                    // Date
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Dismiss button
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Centered photo
            if let img = decodedImages[block.id] {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Caption dock — sits at bottom, keyboard pushes it up
            TextField("Add a note...", text: captionBinding(for: block))
                .font(Typography.headerSmall)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .submitLabel(.done)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Caption Binding

    private func captionBinding(for block: PlacedBlock) -> Binding<String> {
        Binding(
            get: { block.log.caption },
            set: { newValue in
                block.log.caption = newValue
                try? modelContext.save()
            }
        )
    }

    // MARK: - Dismiss

    private func close() {
        activeBlockID = nil
        dismissSheet()
    }
}
