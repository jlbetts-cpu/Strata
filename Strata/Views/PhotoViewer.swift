import SwiftUI
import SwiftData

/// The photographs, full screen, the way Photos does it.
///
/// It used to show ONE picture, cropped to fill the screen. Two things were
/// wrong with that and both were reported from a phone: a portrait photo on a
/// 19.5:9 screen lost about half its width, and the title sat in the black
/// below the picture rather than on it. A viewer that crops is not a viewer.
///
/// So: the photograph is fitted, not filled; it is one of a SET you can swipe
/// through; the caption sits inside the picture's own bounds; and the three
/// things anybody actually does to a photo — send it, keep it, bin it — are
/// on a toolbar where Photos puts them rather than behind a gesture.
///
/// **It takes the whole run and an index into it**, not one file name. The
/// point of the change is that the next photograph is a swipe away, and a
/// viewer holding a single file cannot know what the next one is.
struct PhotoViewer: View {
    let photos: [GalleryPhoto]
    /// Which one to open on. Identity, not position, so a caller can hand over
    /// the photograph that was tapped without knowing where it sits.
    let startAt: String
    let onClose: () -> Void
    /// Called after a photograph has been removed, so the screen underneath
    /// can drop it from its own list.
    var onDelete: (GalleryPhoto) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @State private var index: Int = 0
    @State private var confirmingDelete = false
    @State private var saving = false
    @State private var saved: Set<String> = []
    /// The decoded pictures, keyed by file name.
    ///
    /// Loading lives HERE rather than in the page, for two reasons. The share
    /// sheet needs the current image up front and would otherwise decode a
    /// second full-resolution copy of a picture already on screen. And a
    /// `TabView` keeps neighbouring pages alive, so pages loading themselves
    /// have no shared idea of how many full-size images are in memory at
    /// once; a window of three, pruned on every move, does.
    @State private var images: [String: UIImage] = [:]

    private var current: GalleryPhoto? {
        photos.indices.contains(index) ? photos[index] : nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { position, photo in
                    PhotoPage(photo: photo, image: images[photo.fileName])
                        .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .task(id: index) { await loadWindow() }
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) { toolbar }
        .statusBarHidden()
        .onAppear {
            index = photos.firstIndex { $0.id == startAt } ?? 0
        }
        .confirmationDialog("Remove this photo?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Remove Photo", role: .destructive) { deleteCurrent() }
            Button("Cancel", role: .cancel) { }
        } message: {
            // Said out loud, because the block is the thing the app is about
            // and nobody should have to guess whether this takes one away.
            Text("The win stays on your tower. Only the photograph is deleted.")
        }
    }

    // MARK: - Chrome

    /// Back on the left, the date in the middle. The same two facts Photos
    /// puts up there, and nothing else — a third control at the top right
    /// would be a menu holding what the toolbar already shows.
    private var header: some View {
        ZStack {
            if let current {
                VStack(spacing: 1) {
                    Text(Self.dayLabel(current.date))
                        .font(Typography.headerSmall)
                    Text(current.date, style: .time)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)
            }

            HStack {
                GlassIconButton(systemName: "chevron.left", tint: .white, glyphSize: 16,
                                accessibilityLabel: "Close photo", action: onClose)
                Spacer(minLength: 0)
            }
        }
        // Clear of the status bar and the Dynamic Island — a control at y=34
        // in screen coordinates is not pressable, which this app has already
        // learned once.
        .padding(.top, 58)
        .padding(.horizontal, GridConstants.horizontalPadding)
    }

    /// Send it, keep it, bin it.
    ///
    /// Three buttons rather than Photos' five: this app has no favourites, no
    /// edit and no metadata worth an info panel, and a toolbar of controls
    /// that do nothing is the opposite of feeling native.
    private var toolbar: some View {
        HStack(spacing: 0) {
            if let current, let image = shareImage {
                ShareLink(item: image,
                          preview: SharePreview(current.title ?? "Photo", image: image)) {
                    toolbarGlyph("square.and.arrow.up")
                }
                .accessibilityLabel("Share photo")
            } else {
                toolbarGlyph("square.and.arrow.up").opacity(0.35)
            }

            Spacer(minLength: 0)

            Button { save() } label: { toolbarGlyph(saveIcon) }
                .disabled(saving || isSaved)
                .accessibilityLabel(isSaved ? "Saved to Photos" : "Save to Photos")

            Spacer(minLength: 0)

            Button { confirmingDelete = true } label: { toolbarGlyph("trash") }
                .accessibilityLabel("Remove photo")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 44)
        .padding(.bottom, 34)
        .animation(GridConstants.motionSnappy, value: saved)
    }

    private func toolbarGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
    }

    // MARK: - Actions

    private var isSaved: Bool { current.map { saved.contains($0.id) } ?? false }
    private var saveIcon: String { isSaved ? "checkmark" : "square.and.arrow.down" }

    /// The picture the share sheet sends — the one already on screen, not a
    /// second decode of it.
    private var shareImage: Image? {
        guard let current, let ui = images[current.fileName] else { return nil }
        return Image(uiImage: ui)
    }

    /// The current photograph and its two neighbours, and nothing else.
    ///
    /// Three full-resolution pictures is the working set a swipeable deck
    /// actually needs: the one you are looking at, and the one you are about
    /// to see whichever way you go. Everything outside the window is dropped
    /// on the same pass, so paging through a year does not accumulate.
    private func loadWindow() async {
        let window = ((index - 1)...(index + 1))
            .filter { photos.indices.contains($0) }
            .map { photos[$0].fileName }
        images = images.filter { window.contains($0.key) }
        for name in window where images[name] == nil {
            if let ui = await ImageManager.shared.loadFullImage(fileName: name) {
                images[name] = ui
            }
        }
    }

    private func save() {
        guard let current, !saving, !isSaved else { return }
        saving = true
        Task { @MainActor in
            let image = await ImageManager.shared.loadFullImage(fileName: current.fileName)
            guard let image else { saving = false; return }
            let ok = await PhotoLibrarySaver.save(image, respectingPreference: false)
            saving = false
            if ok {
                saved.insert(current.id)
                HapticsEngine.success()
            }
        }
    }

    private func deleteCurrent() {
        guard let current else { return }
        PhotoRemoval.removePhoto(fileName: current.fileName, context: modelContext)
        HapticsEngine.snap()
        onDelete(current)
        // The set this viewer was handed is a value; it does not shrink under
        // it. Closing is the honest thing to do rather than paging to a
        // neighbour and leaving a dead frame in the deck.
        onClose()
    }

    /// "Today", "Yesterday", or the date.
    static func dayLabel(_ date: Date, now: Date = Date(),
                         calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? "d MMMM" : "d MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - One page

/// One photograph, fitted, with its caption inside it.
///
/// The caption is on the picture because it belongs to the picture — the
/// title is the name of the win this is a photograph of. Below it, in the
/// letterbox, it reads as a label attached to the screen instead.
///
/// **`aspectRatio(_:contentMode:)`, not `scaledToFit()`.** They look the same
/// and they are not: `scaledToFit` leaves the VIEW filling its frame with the
/// image drawn inside it, so an overlay lands in the black. Given the image's
/// own ratio, the view's bounds ARE the picture, and `.overlay(alignment:
/// .bottom)` lands on it.
private struct PhotoPage: View {
    let photo: GalleryPhoto
    /// Handed in, not loaded here — see `PhotoViewer.images`.
    let image: UIImage?

    var body: some View {
        ZStack {
            Color.black
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / max(image.size.height, 1),
                                 contentMode: .fit)
                    .overlay(alignment: .bottom) { caption }
                    .transition(.opacity)
            } else {
                ProgressView().tint(.white.opacity(0.5))
            }
        }
        .animation(GridConstants.gentleReveal, value: image != nil)
    }

    @ViewBuilder
    private var caption: some View {
        if let title = photo.title {
            Text(title)
                .font(Typography.headerMedium)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
                .background(alignment: .bottom) {
                    // The veil the photo blocks use, at the number they use —
                    // white type on a photograph is unreadable without one,
                    // and this app's answer to that has always been the
                    // shortest, lightest one that works rather than a smear
                    // of black up the picture.
                    LinearGradient(
                        colors: [.clear, .black.opacity(GridConstants.photoVeilOpacity)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                }
        }
    }
}

// MARK: - Removing a photograph

/// Taking a photograph off a win.
///
/// **It removes the PHOTOGRAPH, never the win.** The win is a block on the
/// tower and the tower is the record; a delete button inside a photo viewer
/// that silently shortened your tower would be the worst thing this app could
/// do. The log keeps its title, its size and its place, and loses its picture.
///
/// The file is deleted after the model is saved, and only then — CLAUDE.md's
/// rule is that image files are never touched by a path that only meant to
/// read them, and the inverse holds too: a file removed before the reference
/// is what leaves a block pointing at nothing.
enum PhotoRemoval {
    static func removePhoto(fileName: String, context: ModelContext) {
        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.imageFileName == fileName }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        for log in logs { log.imageFileName = nil }
        try? context.save()
        ImageManager.shared.deleteImage(fileName: fileName)
    }
}
