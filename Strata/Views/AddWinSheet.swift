import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Logging a win, with a photo of it.
///
/// This is the add screen. It asks what you did, what colour it is, how big it
/// was, and lets you put a picture on it — and pressing Add drops the block on
/// the tower. It is not a form about the future; everything it asks about has
/// already happened.
///
/// It replaced a form with eleven controls (a title field, a category picker, a
/// recurring/one-time control, a date picker, a "set time" toggle, a time
/// picker, an effort picker, a HealthKit type picker and a threshold picker) to
/// say "read a chapter". No time, no schedule: the tower records what you did,
/// not when you meant to.
///
/// The controls are the same ones the block's own card uses — six colour
/// circles and three size buttons — so the thing you are making looks like the
/// thing it becomes.
struct AddWinSheet: View {

    let modelContext: ModelContext
    let tower: Tower?
    /// When set, the sheet edits this block's habit instead of creating one.
    var editing: Habit? = nil
    var editingLog: HabitLog? = nil
    /// A photograph the sheet opens already holding — a shot just taken on
    /// the camera tab, which lands here to be named and sized rather than
    /// going straight onto the tower unnamed.
    /// Pre-filled title, when the win is being written from a plan line.
    var initialTitle: String? = nil
    var initialPhoto: UIImage? = nil
    var onSaved: (Habit) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var category: HabitCategory = .health
    @State private var size: BlockSize = .small
    @State private var photo: UIImage?
    /// Whether the user touched the photo at all this time round.
    ///
    /// Without it, every save rewrote the image — re-encoding a JPEG that had
    /// already been encoded, losing a little each time, for an edit that was
    /// only ever a rename.
    @State private var photoChanged = false
    @State private var showCamera = false
    @State private var choosingSource = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var loaded = false
    @State private var confirmingDelete = false
    @State private var isSaving = false

    private var isEditing: Bool { editing != nil }
    /// A name is optional.
    ///
    /// Naming a win is the slowest part of logging one, and the app already
    /// has a block that carries no text — that is what the empty slot drops
    /// when you hold it. Requiring a name here made the sheet stricter than
    /// the gesture beside it for no reason, and the most common thing anyone
    /// wants to record is one they cannot be bothered to describe.
    ///
    /// An unnamed block is a colour and a size, which is a perfectly good
    /// thing to have done.
    private var canSave: Bool { !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TextField(isEditing ? "Name" : "What did you do?", text: $title)
                        .font(Typography.headerMedium)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }

                    photoWell

                    field("Colour") { categoryControl }
                    field("Size") { sizeControl }

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle(isEditing ? "Edit" : "Add a win")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!canSave)
                        .fontWeight(.medium)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("Delete this?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteIt() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The block leaves the tower.")
            }
        }
        // Full height, and it stays that way. A medium detent was tried to
        // close the empty space at the bottom and it clipped the size control
        // instead — the sheet's content is taller than half a screen once the
        // photo well is a 2x2. Empty space under a form is ordinary; a control
        // cut off by the edge of a sheet is a bug.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // The page's own background, not the default translucent one. Through
        // frosted glass the tower's colours bleed up behind the controls and
        // the sheet reads as muddy — and a frosted surface is the block's
        // material, not a sheet's.
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .fullScreenCover(isPresented: $showCamera) {
            // No count passed: the tally belongs to the tower's camera, and
            // with nothing to put in it the grid line runs unbroken.
            CameraView(
                onCaptured: { image in
                    photo = image
                    photoChanged = true
                    showCamera = false
                },
                onClose: { showCamera = false },
                fillsScreen: true
            )
            // No colour-scheme override on this one.
            //
            // A `preferredColorScheme` inside a full-screen cover still
            // reaches the window, so opening the camera from the add sheet
            // flipped the whole app dark and flipped it back on dismiss — the
            // screen lurching around a photo you were only trying to attach.
            // The status bar renders white over the black viewfinder on its
            // own, so it bought nothing.
        }
        // Two sources, asked once.
        //
        // The camera alone was the wrong call: most wins are photographed when
        // they happen and named later, so by the time you are filling this in
        // the picture is usually already in your library. Taking one now is
        // the other half, not the whole of it.
        .confirmationDialog("Add a photo", isPresented: $choosingSource, titleVisibility: .hidden) {
            Button("Take a photo") { showCamera = true }
            Button("Choose from library") { showLibrary = true }
            if photo != nil {
                Button("Remove photo", role: .destructive) {
                    photo = nil
                    photoChanged = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photo = image
                    photoChanged = true
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func field(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.primary.opacity(0.32))
            content()
        }
    }

    /// The photo, shown as the block will show it.
    ///
    /// It is the block's own aspect ratio and the block's own corner radius, so
    /// what you frame here is what ends up on the tower — a square well for a
    /// square block, wide for a wide one. Tapping it opens the camera; tapping
    /// a photo you already took replaces it.
    private var photoWell: some View {
        // The well is the block, at the block's real proportions.
        //
        // It was `.aspectRatio` on a full-width frame, so Quick (1x1) and Deep
        // (2x2) are both square and both came out the same size — the one
        // control whose job is to show you what you are making showed no
        // difference between the smallest thing and the biggest. It is sized
        // from the grid now: one cell for Quick, two across for Regular, two
        // across and two down for Deep, using the same cell pitch and corner
        // radius the tower uses. Picking Deep makes the box visibly bigger,
        // because the block is.
        let cell: CGFloat = 96
        let gap = GridConstants.spacing
        let wellRadius = GridConstants.blockCornerRadius(forCell: cell)
        let w = CGFloat(size.columnSpan) * cell + CGFloat(size.columnSpan - 1) * gap
        let h = CGFloat(size.rowSpan) * cell + CGFloat(size.rowSpan - 1) * gap

        return Button {
            HapticsEngine.lightTap()
            choosingSource = true
        } label: {
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    // The tower's empty slot, at this size. A photo well is
                    // literally "a block goes here, with a picture on it", and
                    // the app already has a way of saying that — a recess with
                    // a dashed edge. A flat grey rectangle said nothing.
                    RoundedRectangle(cornerRadius: wellRadius, style: .continuous)
                        .fill(AppColors.warmBlack.opacity(0.038))
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.35))
                        if size != .small {
                            Text("Add a photo")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.primary.opacity(0.35))
                        }
                    }
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: wellRadius, style: .continuous))
            .overlay {
                // Empty, it is a slot: dashed, like the one at the top of the
                // tower. Filled, it is a block: a white rim, like every other
                // block with a photograph on it.
                RoundedRectangle(cornerRadius: wellRadius, style: .continuous)
                    .strokeBorder(
                        photo == nil ? AppColors.warmBlack.opacity(0.26) : Color.white.opacity(0.55),
                        style: photo == nil
                            ? StrokeStyle(lineWidth: 1.5, dash: [GridConstants.ghostBlockDashLength])
                            : StrokeStyle(lineWidth: GridConstants.blockRimWidth)
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if photo != nil {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Circle().fill(.black.opacity(0.35)))
                        .padding(8)
                }
            }
            // Grows from the top left, where a block is anchored, so the
            // change reads as the block getting bigger rather than as the box
            // moving.
            //
            // No `.animation` here. Changing the size is ONE change and it has
            // to be one animation: this modifier ran the well on `slotSnap`
            // while the button's fill and everything the well pushes down the
            // page ran on the `motionSmooth` of the `withAnimation` that set
            // the value — two springs at different rates and different
            // damping, which is exactly why the parts looked like they were
            // moving separately. The transaction at the source now covers all
            // of it.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo == nil ? "Add a photo" : "Replace the photo")
    }

    /// Colour, as the blocks it is.
    ///
    /// It was a row of circles with an icon in each. Circles are not in this
    /// app's vocabulary — every coloured thing in Strata is a block, and a
    /// swatch shaped like something else makes the choice look like it belongs
    /// to a different product. Unpicked, a chip is the slot its block would
    /// fill; picked, it is the block.
    private var categoryControl: some View {
        HStack(spacing: 10) {
            ForEach(HabitCategory.selectable, id: \.self) { cat in
                BlockChip(category: cat, isSelected: category == cat) {
                    withAnimation(GridConstants.motionSmooth) { category = cat }
                } label: {
                    if let icon = cat.iconName {
                        Image(systemName: icon)
                            .iconSize(13, relativeTo: .footnote, weight: .medium)
                    }
                }
                .accessibilityLabel(cat.rawValue)
            }
            Spacer(minLength: 0)
        }
    }

    /// Size, as the shapes the sizes are.
    ///
    /// It was a segmented control reading "Quick / Regular / Deep" — words for
    /// shapes, on a screen whose entire subject is shapes. The tower already
    /// teaches this mapping by letting you drag the slot out into the size you
    /// want; teaching it again in a second language is how an app stops
    /// feeling like one thing.
    private var sizeControl: some View {
        BlockSizePicker(size: Binding(
            get: { size },
            set: { newValue in
                // One transaction for the whole change: the well resizes and
                // everything below it moves on the same spring.
                withAnimation(GridConstants.slotSnap) { size = newValue }
            }
        ), category: category)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            HapticsEngine.tick()
            confirmingDelete = true
        } label: {
            Text("Delete")
                .font(Typography.bodyMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: GridConstants.radiusControl, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Load, save, delete

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let initialPhoto {
            photo = initialPhoto
            photoChanged = true
        }
        if let initialTitle, !initialTitle.isEmpty {
            title = initialTitle
        }
        if let habit = editing {
            title = habit.title == QuickWinService.untitled ? "" : habit.title
            category = habit.displayCategory
            size = habit.blockSize
            if let name = editingLog?.imageFileName {
                Task { photo = await ImageManager.shared.loadFullImage(fileName: name) }
            }
        } else {
            titleFocused = true
        }
    }

    private func save() {
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // `untitled` is the sentinel a nameless block already uses: the block
        // views check for it and draw no text at all, and the title field
        // shows it back as an empty placeholder rather than as the word "Win"
        // for you to delete.
        let trimmed = typed.isEmpty ? QuickWinService.untitled : typed
        guard !isSaving else { return }
        isSaving = true

        if let habit = editing {
            habit.title = trimmed
            habit.category = category
            habit.spontaneousCategoryRaw = nil
            habit.blockSize = size
            try? modelContext.save()
            if photoChanged, let log = editingLog {
                if let photo {
                    attach(photo, to: log)
                } else {
                    // Removing a photo used to do nothing at all: the dialog
                    // set `photo` to nil, and the save path only ever ran when
                    // there WAS a photo, so `imageFileName` was never cleared
                    // and the block kept its face.
                    if let name = log.imageFileName {
                        ImageManager.shared.deleteImage(fileName: name)
                    }
                    log.imageFileName = nil
                    try? modelContext.save()
                }
            }
            HapticsEngine.success()
            onSaved(habit)
            dismiss()
            return
        }

        do {
            let win = try QuickWinService.logWin(
                title: trimmed,
                category: category,
                size: size,
                context: modelContext,
                tower: tower
            )
            // The photo is attached to the LOG the service just returned rather
            // than looked up afterwards. Re-deriving it from `habit.logs` is
            // exactly the lookup that intermittently came back empty.
            if let photo,
               let log = win.habit.logs.first(where: { $0.id == win.logID }) {
                attach(photo, to: log)
            }
            HapticsEngine.success()
            onSaved(win.habit)
            dismiss()
        } catch {
            isSaving = false
        }
    }

    /// Writes the image to disk and points the log at it.
    ///
    /// Saved before the sheet closes, not after: the tower reads
    /// `imageFileName` on its next build, and a block that arrives with no face
    /// and grows one a moment later is the flash this avoids.
    /// The photograph is stored WHOLE, not cropped to the block it is going on.
    ///
    /// It used to be trimmed to the block's aspect before writing, on the
    /// reasoning that the block clips it anyway so the rest is bytes nobody can
    /// see. That is true right up until the block is resized — and then the
    /// already-cropped picture was loaded back, cropped AGAIN to the new
    /// aspect, and written. Every resize cropped the crop, so the subject
    /// zoomed further out of frame each time until it was gone.
    ///
    /// `CachedImageView` draws with `.scaledToFill()`, so the block crops to
    /// its own shape at display time, from the whole image, every time. Which
    /// means a resize now re-frames rather than re-crops, and is reversible.
    private func attach(_ image: UIImage, to log: HabitLog) {
        let id = log.id
        Task { @MainActor in
            if let name = try? await ImageManager.shared.save(image: image, for: id) {
                log.imageFileName = name
                try? modelContext.save()
            }
        }
    }

    private func deleteIt() {
        guard let habit = editing else { return }
        for log in habit.logs { modelContext.delete(log) }
        modelContext.delete(habit)
        try? modelContext.save()
        HapticsEngine.tick()
        onDeleted()
        dismiss()
    }
}
