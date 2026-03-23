import SwiftUI
import SwiftData
import PhotosUI

enum FilmstripMode: String, CaseIterable {
    case today = "Today"
    case journey = "Journey"
}

struct BlockExpansionCard: View {
    let block: PlacedBlock
    let dailyPhotoBlocks: [PlacedBlock]
    let habitPhotoBlocks: [PlacedBlock]
    let namespace: Namespace.ID
    let modelContext: ModelContext
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var selectedPhotoLogID: UUID? = nil
    @State private var filmstripMode: FilmstripMode = .today
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showPhotoError = false
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var style: CategoryStyle { selectedLog.habit?.category.style ?? block.habit.category.style }
    private let cardWidth: CGFloat = UIScreen.main.bounds.width - 48
    private var heroHeight: CGFloat { min(CGFloat(block.rowSpan) * 80 * 2.0, 280) }

    private var selectedLog: HabitLog {
        if let logID = selectedPhotoLogID {
            let source = filmstripMode == .journey ? habitPhotoBlocks : dailyPhotoBlocks
            if let photoBlock = source.first(where: { $0.log.id == logID }) {
                return photoBlock.log
            }
        }
        return block.log
    }

    private var selectedHabit: Habit {
        if let logID = selectedPhotoLogID {
            let source = filmstripMode == .journey ? habitPhotoBlocks : dailyPhotoBlocks
            if let photoBlock = source.first(where: { $0.log.id == logID }) {
                return photoBlock.habit
            }
        }
        return block.habit
    }

    private var activeFilmstripBlocks: [PlacedBlock] {
        filmstripMode == .journey ? habitPhotoBlocks : dailyPhotoBlocks
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { selectedLog.note ?? "" },
            set: { selectedLog.note = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero area — ZStack for morph anchor + photo overlay + capture
            ZStack {
                FlippableBlockView(
                    block: block,
                    width: cardWidth,
                    height: heroHeight,
                    cornerRadius: 20,
                    modelContext: modelContext
                )
                .matchedGeometryEffect(id: block.id, in: namespace)
                .opacity(selectedPhotoLogID == nil ? 1 : 0)
                .allowsHitTesting(false)

                if let logID = selectedPhotoLogID {
                    let source = filmstripMode == .journey ? habitPhotoBlocks : dailyPhotoBlocks
                    if let photoBlock = source.first(where: { $0.log.id == logID }),
                       let fileName = photoBlock.log.imageFileName {
                        CachedImageView(
                            fileName: fileName,
                            width: cardWidth,
                            height: heroHeight,
                            cornerRadius: 20,
                            fullResolution: true
                        )
                        .transition(.opacity.animation(GridConstants.crossFade))
                        .allowsHitTesting(false)
                    }
                }

                // Photo capture overlay — shown when no photo on this block
                if block.log.imageFileName == nil && selectedPhotoLogID == nil {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2.weight(.light))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("Add Proof")
                                .font(Typography.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: cardWidth, height: heroHeight)

            // Content area
            if showContent {
                VStack(alignment: .leading, spacing: 12) {
                    // Title + category + time
                    HStack {
                        Image(systemName: selectedHabit.category.iconName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(style.baseColor)
                        Text(selectedHabit.title)
                            .font(Typography.headerMedium)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let time = selectedLog.completedAt {
                            Text(time, style: .time)
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .animation(GridConstants.crossFade, value: selectedPhotoLogID)

                    // Filmstrip mode toggle — only when Journey data exists
                    if !habitPhotoBlocks.isEmpty {
                        Picker("", selection: $filmstripMode) {
                            ForEach(FilmstripMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: filmstripMode) {
                            HapticsEngine.tick()
                            // Reset selection when switching modes
                            withAnimation(GridConstants.crossFade) {
                                selectedPhotoLogID = nil
                            }
                        }
                    }

                    // Filmstrip — horizontal thumbnails
                    if !activeFilmstripBlocks.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: GridConstants.filmstripSpacing) {
                                ForEach(activeFilmstripBlocks) { photoBlock in
                                    let isSelected = selectedPhotoLogID == photoBlock.log.id
                                    let thumbStyle = photoBlock.habit.category.style

                                    VStack(spacing: 4) {
                                        CachedImageView(
                                            fileName: photoBlock.log.imageFileName,
                                            width: GridConstants.filmstripThumbnailSize,
                                            height: GridConstants.filmstripThumbnailSize,
                                            cornerRadius: 12
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(
                                                    isSelected ? thumbStyle.baseColor : .primary.opacity(0.15),
                                                    lineWidth: isSelected ? 2 : 1
                                                )
                                        )

                                        // Date label in Journey mode
                                        if filmstripMode == .journey {
                                            Text(BlockTimeFormatter.dateLabel(from: photoBlock.log.dateString))
                                                .font(Typography.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .onTapGesture {
                                        HapticsEngine.lightTap()
                                        withAnimation(GridConstants.crossFade) {
                                            if isSelected {
                                                selectedPhotoLogID = nil
                                            } else {
                                                selectedPhotoLogID = photoBlock.log.id
                                            }
                                        }
                                    }
                                    .accessibilityLabel("\(photoBlock.habit.title) photo")
                                }
                            }
                        }
                    }

                    // Note editor
                    TextField("Add a note…", text: noteBinding, axis: .vertical)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1...6)

                    // Caption
                    if !selectedLog.caption.isEmpty {
                        Text(selectedLog.caption)
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                    }

                    // Subtasks (toggle only)
                    if !selectedLog.subtasks.isEmpty {
                        Divider()
                        ForEach(selectedLog.subtasks) { subtask in
                            HStack(spacing: 8) {
                                Image(systemName: subtask.completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(subtask.completed ? style.baseColor : .secondary)
                                Text(subtask.title)
                                    .font(Typography.bodySmall)
                                    .strikethrough(subtask.completed)
                                    .foregroundStyle(subtask.completed ? .secondary : .primary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggleSubtask(subtask) }
                            .accessibilityLabel("\(subtask.title), \(subtask.completed ? "completed" : "not completed")")
                            .accessibilityHint("Tap to toggle")
                        }
                    }

                    Divider()

                    // Close button
                    Button {
                        HapticsEngine.lightTap()
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                            Text("Close")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("Close card")
                }
                .padding(16)
                .transition(.opacity)
            }
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .scrollDismissesKeyboard(.interactively)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 80 {
                        HapticsEngine.snap()
                        onDismiss()
                    }
                }
        )
        .transition(.opacity)
        .onAppear {
            // Auto-select this block's photo if it has one
            if block.log.imageFileName != nil {
                selectedPhotoLogID = block.log.id
            }
            let delay: Double = reduceMotion ? 0 : 0.15
            withAnimation(GridConstants.gentleReveal.delay(delay)) {
                showContent = true
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            HapticsEngine.lightTap()
            Task { await loadPhoto(from: newItem) }
        }
        .alert("Photo couldn't be saved", isPresented: $showPhotoError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again or choose a different photo.")
        }
        .accessibilityAddTraits(.isModal)
    }

    private func toggleSubtask(_ subtask: SubTask) {
        guard let idx = selectedLog.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        selectedLog.subtasks[idx].completed.toggle()
        try? modelContext.save()
        HapticsEngine.tick()
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
            block.log.imageFileName = fileName
            try? modelContext.save()
            withAnimation(GridConstants.crossFade) {
                selectedPhotoLogID = block.log.id
            }
            HapticsEngine.lightTap()
        } catch {
            showPhotoError = true
        }
    }
}
