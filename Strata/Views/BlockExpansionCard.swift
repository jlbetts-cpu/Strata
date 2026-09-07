import SwiftUI
import SwiftData
import PhotosUI

// FilmstripMode removed — Hick's Law: one photo source, no picker needed

struct BlockExpansionCard: View {
    let block: PlacedBlock
    let dailyPhotoBlocks: [PlacedBlock]
    let namespace: Namespace.ID
    let modelContext: ModelContext
    let onDismiss: () -> Void
    /// Called when a change alters the block's footprint, so the tower can
    /// repack. Without it a resized block kept its old shape until the next
    /// drop happened to rebuild the grid.
    var onLayoutChanged: () -> Void = {}

    @State private var showContent = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showPhotoError = false
    @State private var imageToCrop: UIImage? = nil
    @State private var isSavingPhoto = false
    @State private var showPhotoSourceDialog = false
    @State private var showLibraryPicker = false
    @State private var showCamera = false
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // displayCategory, not category: an unchosen block still needs a colour.
    private var style: CategoryStyle { block.habit.displayCategory.style }
    @State private var cardWidth: CGFloat = 353 // Updated by GeometryReader on appear
    // Hero matches source block aspect ratio (Pylyshyn 2001: object constancy)
    private var heroHeight: CGFloat {
        let sourceAspect = CGFloat(block.columnSpan) / CGFloat(block.rowSpan)
        return min(cardWidth / sourceAspect, 300)
    }

    private var currentLog: HabitLog { block.log }
    private var currentHabit: Habit { block.habit }

    private var noteBinding: Binding<String> {
        Binding(
            get: { currentLog.note ?? "" },
            set: { currentLog.note = $0.isEmpty ? nil : $0 }
        )
    }

    /// Editing the title writes straight through to the habit.
    ///
    /// An untitled win reads as empty rather than as the word "Win", so the
    /// placeholder can do the explaining and the field is never pre-filled with
    /// something you have to delete before you can type.
    private var titleBinding: Binding<String> {
        Binding(
            get: {
                let t = currentHabit.title
                return t == QuickWinService.untitled ? "" : t
            },
            set: { new in
                let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                currentHabit.title = trimmed.isEmpty ? QuickWinService.untitled : trimmed
                try? modelContext.save()
            }
        )
    }

    /// Size, with what it costs.
    ///
    /// Effort and duration are separate ideas in this app (a Quick thing can
    /// still take an hour), but at the moment of sizing a block the only
    /// question is how much room it takes, so the control shows the number it
    /// implies rather than making you hold the mapping in your head.
    private var sizeControl: some View {
        HStack(spacing: 6) {
            ForEach([BlockSize.small, .medium, .hard], id: \.self) { size in
                let isSelected = currentHabit.blockSize == size
                Button {
                    guard !isSelected else { return }
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) {
                        currentHabit.blockSize = size
                    }
                    try? modelContext.save()
                    // The block's footprint just changed, so the grid has to
                    // repack around it now rather than at the next drop.
                    onLayoutChanged()
                } label: {
                    VStack(spacing: 1) {
                        Text(size.effortLabel)
                            .font(Typography.bodySmall)
                        Text(BlockExpansionCard.durationLabel(size))
                            .font(Typography.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : .primary.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        isSelected ? AnyShapeStyle(currentHabit.displayCategory.style.baseColor)
                                   : AnyShapeStyle(GridConstants.fillTrack),
                        in: RoundedRectangle(cornerRadius: GridConstants.radiusControl, style: .continuous)
                    )
                    .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(size.effortLabel), \(BlockExpansionCard.durationLabel(size))")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// Which of the six this block is.
    ///
    /// A win arrives with a colour already picked for it, because a colourless
    /// block is invisible on this page. This is where that guess gets
    /// corrected — one tap, no menu, and the block re-colours under your
    /// finger while the card is still open.
    private var categoryControl: some View {
        HStack(spacing: 6) {
            ForEach(HabitCategory.selectable, id: \.self) { cat in
                let isSelected = currentHabit.category == cat
                Button {
                    guard !isSelected else { return }
                    HapticsEngine.tick()
                    withAnimation(GridConstants.motionSmooth) {
                        currentHabit.category = cat
                    }
                    try? modelContext.save()
                    // Colour decides what merges with what, so changing it
                    // changes the SHAPE of the tower, not just this block. The
                    // merge map is computed on rebuild; without this the block
                    // re-coloured instantly and stayed visibly separate from
                    // its new neighbours until something else happened to
                    // rebuild the grid.
                    onLayoutChanged()
                } label: {
                    ZStack {
                        Circle()
                            .fill(cat.style.baseColor)
                            .frame(width: 30, height: 30)
                        // The icon, not just the colour. Six dots told you
                        // there were six of something; they did not tell you
                        // which one you were about to pick.
                        if let icon = cat.iconName {
                            Image(systemName: icon)
                                .iconSize(12, relativeTo: .footnote, weight: .semibold)
                                .foregroundStyle(.white)
                        }
                        if isSelected {
                            Circle()
                                .strokeBorder(cat.style.baseColor, lineWidth: 1.5)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cat.rawValue.capitalized)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    static func durationLabel(_ size: BlockSize) -> String {
        let m = Int(size.durationMinutes)
        return m < 60 ? "\(m)m" : (m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m")
    }

    // #389: Rotating note prompts
    private var notePrompt: String {
        let prompts = ["Add a note…", "How did it feel?", "What did you learn?", "Any thoughts?", "Worth remembering?"]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return prompts[dayOfYear % prompts.count]
    }

    // MARK: - Body

    /// Extracted: making `iconName` optional pushed this card's body past the
    /// type-checker's limit inline.
    @ViewBuilder
    private var categoryGlyph: some View {
        if let icon = currentHabit.category.iconName {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(style.baseColor)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero area — swipeable carousel (replaces filmstrip thumbnails)
            ZStack {
                // Invisible anchor for matchedGeometryEffect morph animation
                Color.clear
                    .frame(width: cardWidth, height: heroHeight)
                    .matchedGeometryEffect(id: block.id, in: namespace)

                // Single hero — this block only, no carousel
                heroSlide(for: block)

                // Photo capture overlay — shown when no photo on current block
                if block.log.imageFileName == nil {
                    Button {
                        showPhotoSourceDialog = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2.weight(.light))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("Add Photo")
                                .font(Typography.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Loading indicator
                if isSavingPhoto {
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView().tint(.white)
                    }
                }
            }
            .frame(width: cardWidth, height: heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.cardCornerRadius, style: .continuous))

            // Content area
            if showContent {
                VStack(alignment: .leading, spacing: GridConstants.cardContentSpacing) {
                    // Title + category + time
                    //
                    // The title is a field, not a label. This card was the only
                    // place a block's name appeared and the only place it could
                    // not be changed, so a win logged in one tap could never be
                    // told what it was. Typing here IS the edit — no edit mode,
                    // no save button, the same as changing a cell in a sheet.
                    HStack {
                        categoryGlyph
                        TextField("Name this block", text: titleBinding)
                            .font(Typography.brandCardTitle)
                            .foregroundStyle(.primary)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.done)
                        Spacer(minLength: 8)
                        if let time = currentLog.completedAt {
                            Text(time, style: .time)
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .animation(GridConstants.crossFade, value: block.id)

                    sizeControl
                    categoryControl

                    // HealthKit verification badge
                    if currentLog.verifiedByHealthKit {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.circle")
                                .font(Typography.caption)
                                .foregroundStyle(AppColors.healthGreen)
                            Text("Verified by Apple Health")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // #389: Note editor with rotating prompts (encourages reflection)
                    TextField(notePrompt, text: noteBinding, axis: .vertical)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1...6)

                    // Caption
                    if !currentLog.caption.isEmpty {
                        Text(currentLog.caption)
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                    }

                    // Photo actions — always available (Norman 1988)
                    if block.log.imageFileName != nil {
                        HStack(spacing: 16) {
                            Button {
                                showPhotoSourceDialog = true
                            } label: {
                                Label("Replace Photo", systemImage: "camera")
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(style.baseColor)
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let fileName = block.log.imageFileName {
                                    ImageManager.shared.deleteImage(fileName: fileName)
                                    block.log.imageFileName = nil
                                    HapticsEngine.warning()
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Subtasks (toggle only)
                    if !currentLog.subtasks.isEmpty {
                        Divider()
                        ForEach(currentLog.subtasks) { subtask in
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

                }
                .padding(.horizontal, GridConstants.cardContentPadding)
                .padding(.top, GridConstants.cardContentPadding)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: GridConstants.cardCornerRadius, style: .continuous)
                // #10: Tinted material — .thickMaterial + 3% category overlay (Gestalt similarity)
                .fill(.thickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: GridConstants.cardCornerRadius, style: .continuous)
                        .fill(style.baseColor.opacity(0.03))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.cardCornerRadius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if showContent {
                Button {
                    HapticsEngine.lightTap()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Typography.brandHeader)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
                .padding(12)
                .accessibilityLabel("Close card")
                .transition(.opacity)
            }
        }
        // #14: Dual shadow — ambient + tight contact shadow
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
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
                    // #268: Velocity-based dismiss — if swipe > 500pt/s, dismiss regardless of distance
                    if value.translation.height > 80 || value.velocity.height > 500 {
                        HapticsEngine.snap()
                        onDismiss()
                    }
                }
        )
        .transition(.opacity)
        .background(GeometryReader { geo in
            Color.clear.onAppear { cardWidth = geo.size.width }
        })
        .onAppear {
            let delay: Double = reduceMotion ? 0 : 0.12
            withAnimation(GridConstants.cardReveal.delay(delay)) {
                showContent = true
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            HapticsEngine.lightTap()
            Task {
                guard let newItem else { return }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let img = await Task.detached(operation: { UIImage(data: data) }).value else {
                    showPhotoError = true; return
                }
                imageToCrop = img
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showPhotoSourceDialog) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showLibraryPicker = true }
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onCapture: { image in showCamera = false; imageToCrop = image },
                onCancel: { showCamera = false }
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { imageToCrop != nil },
            set: { if !$0 { imageToCrop = nil } }
        )) {
            if let img = imageToCrop {
                PhotoCropView(
                    image: img,
                    blockContext: BlockPreviewContext(
                        title: block.habit.title,
                        category: block.habit.category,
                        blockSize: block.habit.blockSize,
                        timeText: nil
                    ),
                    onCrop: { cropped in
                        imageToCrop = nil
                        Task { await savePhoto(cropped) }
                    },
                    onCancel: {
                        imageToCrop = nil
                        selectedItem = nil
                    }
                )
            }
        }
        .alert("Photo couldn't be saved", isPresented: $showPhotoError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("Try again or choose a different photo.")
        })
        .accessibilityAddTraits(.isModal)
        // #129: Expansion card focus trap for VoiceOver
        .accessibilityElement(children: .contain)
    }

    // MARK: - Hero Slide

    @ViewBuilder
    private func heroSlide(for photoBlock: PlacedBlock) -> some View {
        if let fileName = photoBlock.log.imageFileName {
            CachedImageView(
                fileName: fileName,
                width: cardWidth,
                height: heroHeight,
                cornerRadius: 0
            )
        } else {
            FlippableBlockView(
                block: photoBlock,
                width: cardWidth,
                height: heroHeight,
                cornerRadius: 0,
                modelContext: modelContext,
                showOverlay: false
            )
            .allowsHitTesting(false)
        }
    }

    // MARK: - Subtask Toggle

    private func toggleSubtask(_ subtask: SubTask) {
        guard let idx = currentLog.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        currentLog.subtasks[idx].completed.toggle()
        try? modelContext.save()
        HapticsEngine.tick()
    }

    // MARK: - Photo Save (receives cropped image from PhotoCropView)

    @MainActor
    private func savePhoto(_ img: UIImage) async {
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        // Delete old photo file to prevent disk leak
        if let oldFileName = block.log.imageFileName {
            ImageManager.shared.deleteImage(fileName: oldFileName)
        }

        let (maxDim, quality): (CGFloat, CGFloat) = switch block.habit.blockSize {
        case .small: (512, 0.70)
        case .medium: (768, 0.75)
        case .hard: (1024, 0.80)
        }
        do {
            let fileName = try await ImageManager.shared.save(image: img, for: block.log.id, maxDimension: maxDim, quality: quality)
            block.log.imageFileName = fileName
            try? modelContext.save()
            selectedItem = nil
            HapticsEngine.lightTap()
        } catch {
            showPhotoError = true
        }
    }
}
