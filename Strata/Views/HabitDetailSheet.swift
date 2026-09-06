import SwiftUI
import SwiftData
import PhotosUI

struct HabitDetailSheet: View {
    let habit: Habit
    let selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showPhotoError = false
    @State private var imageToCrop: UIImage? = nil
    @State private var isSavingPhoto = false
    @State private var showPhotoSourceDialog = false
    @State private var showLibraryPicker = false
    @State private var showCamera = false

    private var style: CategoryStyle { habit.category.style }
    private var coverHeight: CGFloat { todayLog.imageFileName != nil ? 200 : 100 }

    // MARK: - Today's Log

    private var todayLog: HabitLog {
        let dateStr = TimelineViewModel.dateString(from: selectedDate)
        if let existing = habit.logs.first(where: { $0.dateString == dateStr }) {
            return existing
        }
        let log = HabitLog(habit: habit, dateString: dateStr)
        modelContext.insert(log)
        try? modelContext.save()
        return log
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { todayLog.note ?? "" },
            set: { todayLog.note = $0.isEmpty ? nil : $0; try? modelContext.save() }
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Cover photo area
                coverPhotoSection

                // Content
                VStack(alignment: .leading, spacing: 16) {
                    // Title + time
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if let icon = habit.category.iconName {
                                Image(systemName: icon)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(style.baseColor)
                            }
                            Text(habit.title)
                                .font(Typography.headerMedium)
                                .foregroundStyle(.primary)
                        }

                        if let time = habit.scheduledTime {
                            let end = BlockTimeFormatter.endTime(time, durationMinutes: habit.blockSize.durationMinutes)
                            HStack(spacing: 6) {
                                Text("\(BlockTimeFormatter.format12Hour(time)) – \(BlockTimeFormatter.format12Hour(end))")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                                if habit.blockSize != .small {
                                    Text(habit.blockSize == .medium ? "30m" : "1h")
                                        .font(Typography.caption2)
                                        .foregroundStyle(style.baseColor.opacity(0.6))
                                }
                            }
                        }
                    }

                    // HealthKit verification status + disconnect
                    if let hkTypeStr = habit.healthKitType,
                       let hkType = HealthKitHabitType(rawValue: hkTypeStr) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.circle")
                                    .font(Typography.bodySmall.weight(.medium))
                                    .foregroundStyle(AppColors.healthGreen)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-verifies: \(hkType.displayName)")
                                        .font(Typography.caption)
                                    if let threshold = habit.healthKitThreshold, threshold > 0, !hkType.isPresenceBased {
                                        Text("> \(Int(threshold)) \(hkType.thresholdUnit)")
                                            .font(Typography.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            Button(role: .destructive) {
                                habit.healthKitType = nil
                                habit.healthKitThreshold = nil
                                try? modelContext.save()
                                HapticsEngine.lightTap()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle")
                                        .font(Typography.caption)
                                    Text("Disconnect")
                                        .font(Typography.caption)
                                }
                                .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }

                    Divider()

                    // Notes
                    TextField("Add a note…", text: noteBinding, axis: .vertical)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1...8)

                    // Subtasks
                    if !todayLog.subtasks.isEmpty {
                        Divider()
                        ForEach(todayLog.subtasks) { subtask in
                            HStack(spacing: 8) {
                                Image(systemName: subtask.completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(subtask.completed ? style.baseColor : .secondary)
                                Text(subtask.title)
                                    .font(Typography.bodySmall)
                                    .strikethrough(subtask.completed)
                                    .foregroundStyle(subtask.completed ? .secondary : .primary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticsEngine.tick()
                                toggleSubtask(subtask)
                            }
                        }
                    }

                    // Close via native sheet drag (consistent with iOS standard)
                }
                .padding(20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemBackground))
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
        .onChange(of: selectedItem) { _, newItem in
            HapticsEngine.lightTap()
            Task {
                guard let newItem else { return }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let img = await Task.detached(operation: { UIImage(data: data) }).value else { return }
                imageToCrop = img
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { imageToCrop != nil },
            set: { if !$0 { imageToCrop = nil } }
        )) {
            if let img = imageToCrop {
                PhotoCropView(
                    image: img,
                    blockContext: BlockPreviewContext(
                        title: habit.title,
                        category: habit.category,
                        blockSize: habit.blockSize,
                        timeText: habit.scheduledTime.map { BlockTimeFormatter.format12Hour($0) }
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
    }

    // MARK: - Cover Photo Section

    private var coverPhotoSection: some View {
        GeometryReader { geo in
        ZStack(alignment: .bottomLeading) {
            // Photo or category gradient (guard against zero-width GeometryReader)
            if geo.size.width > 0, let fileName = todayLog.imageFileName {
                CachedImageView(
                    fileName: fileName,
                    width: geo.size.width,
                    height: coverHeight,
                    cornerRadius: 0,
                    fullResolution: false
                )
            } else {
                // Proto-block gradient (no photo)
                LinearGradient(
                    stops: [
                        .init(color: style.lightTint, location: 0.0),
                        .init(color: style.baseColor, location: 0.3),
                        .init(color: style.baseColor, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Gradient mask — fades photo into sheet background
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color(uiColor: .systemBackground), location: 1.0)
                ],
                startPoint: .init(x: 0.5, y: 0.6),
                endPoint: .bottom
            )

            // Photo source overlay
            Button {
                showPhotoSourceDialog = true
            } label: {
                if todayLog.imageFileName == nil {
                    VStack(spacing: 6) {
                        if let icon = habit.category.iconName {
                            Image(systemName: icon)
                                .font(Typography.brandHeader)
                                .foregroundStyle(.white)
                        }
                        Text("Add Photo")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Tap photo to replace
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)

            // Loading indicator
            if isSavingPhoto {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView().tint(.white)
                }
            }
        }
        .frame(height: coverHeight)
        .clipped()
        } // GeometryReader
        .frame(height: coverHeight)
    }

    // MARK: - Actions

    private func toggleSubtask(_ subtask: SubTask) {
        guard let idx = todayLog.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        todayLog.subtasks[idx].completed.toggle()
        try? modelContext.save()
        HapticsEngine.tick()
    }

    @MainActor
    private func savePhoto(_ img: UIImage) async {
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        // Delete old photo file to prevent disk leak
        if let oldFileName = todayLog.imageFileName {
            ImageManager.shared.deleteImage(fileName: oldFileName)
        }

        let (maxDim, quality): (CGFloat, CGFloat) = switch habit.blockSize {
        case .small: (512, 0.70)
        case .medium: (768, 0.75)
        case .hard: (1024, 0.80)
        }
        do {
            let fileName = try await ImageManager.shared.save(image: img, for: todayLog.id, maxDimension: maxDim, quality: quality)
            todayLog.imageFileName = fileName
            try? modelContext.save()
            selectedItem = nil
            HapticsEngine.snap()
        } catch {
            showPhotoError = true
        }
    }
}
