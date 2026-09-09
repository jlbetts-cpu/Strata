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
    /// Which photograph is on screen, by identity. `scrollPosition` wants an
    /// id, and identity survives a deletion changing every index.
    @State private var currentID: String?
    /// True while the picture on screen is zoomed in. The deck stops paging
    /// then, or a pan across a magnified photo would flick to the next one.
    @State private var isZoomed = false

    private var current: GalleryPhoto? {
        photos.first { $0.id == currentID } ?? photos.first
    }

    private var index: Int {
        photos.firstIndex { $0.id == currentID } ?? 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // A paging `ScrollView`, not a `TabView`.
            //
            // `TabView`'s page style owns its own horizontal gesture and there
            // is no way to switch it off, so panning around a zoomed-in
            // photograph flicked to the next one. A scroll view can be told to
            // stop, which is the whole reason for the swap — and it also lets
            // the deck be keyed by identity rather than by index, so deleting
            // a photograph does not renumber everything behind it.
            GeometryReader { geo in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(photos) { photo in
                            PhotoPage(photo: photo,
                                      image: images[photo.fileName],
                                      isCurrent: photo.id == currentID,
                                      onZoomChanged: { isZoomed = $0 })
                                .frame(width: geo.size.width, height: geo.size.height)
                                .id(photo.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentID)
                .scrollIndicators(.hidden)
                .scrollDisabled(isZoomed)
            }
            .ignoresSafeArea()
        }
        .task(id: currentID) { await loadWindow() }
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) { toolbar }
        .statusBarHidden()
        .onAppear { currentID = startAt }
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
        VStack(spacing: 18) {
            // The title, in the black.
            //
            // It was on the photograph, over a veil, which is what every photo
            // app does and what this one was asked not to do. In the letterbox
            // it needs no veil at all, the picture is never dimmed to make
            // room for it, and there is nothing between you and the thing you
            // opened.
            //
            // Reserved whether or not there is one, so the toolbar does not
            // step up and down as you swipe past an unnamed win.
            Text(current?.title ?? " ")
                .font(Typography.headerMedium)
                .foregroundStyle(.white.opacity(current?.title == nil ? 0 : 0.95))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 24)
                .animation(GridConstants.crossFade, value: currentID)

            controlRow
        }
        .padding(.bottom, 34)
    }

    private var controlRow: some View {
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

/// One photograph, fitted, and zoomable.
///
/// **`aspectRatio(_:contentMode:)`, not `scaledToFit()`.** They look the same
/// and they are not: `scaledToFit` leaves the VIEW filling its frame with the
/// image drawn inside it, so anything measured off it measures the letterbox.
/// Given the image's own ratio, the view's bounds ARE the picture.
///
/// **Nothing shows behind it.** No placeholder colour, no shimmer, no spinner
/// on top of the picture — a full-screen viewer that flashes something else
/// first is the thing that makes an app feel put together out of parts. The
/// frame is black until the photograph is there, and then it is the
/// photograph.
///
/// Zoom is pinch and double tap, both of which snap back to fit when they land
/// below 1. Panning is rubber-banded at the edges rather than hard-stopped,
/// per `docs/apple-design.md`, and only exists while zoomed — which is also
/// when the deck stops paging, or a pan would flick to the next picture.
private struct PhotoPage: View {
    let photo: GalleryPhoto
    /// Handed in, not loaded here — see `PhotoViewer.images`.
    let image: UIImage?
    let isCurrent: Bool
    var onZoomChanged: (Bool) -> Void = { _ in }

    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    /// Where a double tap takes you. Apple's is about this — far enough to be
    /// worth the tap, near enough that the second tap back is not a fall.
    private static let doubleTapScale: CGFloat = 2.5
    private static let maxScale: CGFloat = 6

    private var zoomed: Bool { committedScale > 1.01 }

    var body: some View {
        ZStack {
            Color.black
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / max(image.size.height, 1),
                                 contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .transition(.opacity)
            }
        }
        // A fade, and only a fade. The picture arriving by appearing is the
        // one moment a viewer can look cheap.
        .animation(GridConstants.gentleReveal, value: image != nil)
        .contentShape(Rectangle())
        .gesture(magnify)
        .simultaneousGesture(pan)
        .gesture(doubleTap)
        .onChange(of: zoomed) { _, now in onZoomChanged(now) }
        .onChange(of: isCurrent) { _, now in
            // A page that scrolled away keeps its state in a `LazyHStack`.
            // Coming back to a photograph still magnified from last time is
            // not what anybody means by going back to it.
            if !now { reset(animated: false) }
        }
    }

    // MARK: - Gestures

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(committedScale * value.magnification, Self.maxScale)
            }
            .onEnded { _ in
                if scale <= 1.01 {
                    reset(animated: true)
                } else {
                    committedScale = scale
                    withAnimation(GridConstants.motionSnappy) { clampOffset() }
                    committedOffset = offset
                }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoomed else { return }
                offset = CGSize(width: committedOffset.width + value.translation.width,
                                height: committedOffset.height + value.translation.height)
            }
            .onEnded { _ in
                guard zoomed else { return }
                withAnimation(GridConstants.motionSnappy) { clampOffset() }
                committedOffset = offset
            }
    }

    private var doubleTap: some Gesture {
        TapGesture(count: 2).onEnded {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) {
                if zoomed {
                    scale = 1; offset = .zero
                } else {
                    scale = Self.doubleTapScale; offset = .zero
                }
            }
            committedScale = scale
            committedOffset = offset
        }
    }

    /// Keeps the picture from being dragged off the screen.
    ///
    /// Proportional to how far in you are rather than a fixed number: at 2x
    /// there is half a frame of slack in each direction, at 6x there is five
    /// times as much, and one constant cannot be right for both.
    private func clampOffset() {
        let slack = (committedScale - 1) / 2
        let limitX = UIScreen.main.bounds.width * slack
        let limitY = UIScreen.main.bounds.height * slack
        offset = CGSize(width: min(max(offset.width, -limitX), limitX),
                        height: min(max(offset.height, -limitY), limitY))
    }

    private func reset(animated: Bool) {
        let apply = {
            scale = 1; offset = .zero
            committedScale = 1; committedOffset = .zero
        }
        if animated {
            withAnimation(GridConstants.motionSnappy) { apply() }
        } else {
            apply()
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
