import SwiftUI
import SwiftData

/// The photographs, full screen.
///
/// Built to a reference the owner supplied, and the reference is right about
/// the thing this screen kept getting wrong: **the picture is an object on a
/// black field, not a fill for the screen.** Inset, with its own corner
/// radius, so it reads as a print laid down rather than as the window itself.
/// Everything else is arranged around it — title above, date below, the run it
/// belongs to along the bottom.
///
/// The history is worth keeping because it was two wrong answers in a row: it
/// filled the screen and cropped (a portrait photo lost half its width), then
/// it fitted edge-to-edge with the caption in the letterbox. Fitted was right;
/// edge-to-edge was not.
///
/// **It takes the whole run and an index into it**, not one file name — the
/// next photograph is a swipe away, and a viewer holding a single file cannot
/// know what the next one is.
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
    /// The name of the place the current photograph was taken, once it has
    /// arrived. Held rather than read straight from `PlaceNames` so the view
    /// re-renders when it lands.
    @State private var placeName: String?
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
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .frame(height: Self.headerHeight)

                    // The picture, and only the picture, gets the room that is
                    // left. Solved rather than guessed: every other band is
                    // fixed, so whatever remains is the stage.
                    //
                    // The insets count. Leaving them out of this subtraction
                    // made the deck 88pt taller than its container and pushed
                    // the strip clean off the bottom of the screen.
                    deck(size: CGSize(
                        width: geo.size.width,
                        height: geo.size.height
                            - Self.topInset - Self.bottomInset
                            - Self.headerHeight - Self.dateHeight - Self.stripHeight
                    ))

                    dateLine
                        .frame(height: Self.dateHeight)

                    filmstrip
                        .frame(height: Self.stripHeight)
                }
                .padding(.top, Self.topInset)
                .padding(.bottom, Self.bottomInset)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear { currentID = startAt }
        // The window of decoded pictures follows whatever is on screen. This
        // was lost for one build when the layout was rewritten around it, and
        // the symptom was a viewer that showed a filmstrip and a black stage —
        // nothing errored, because an absent image is a legal state.
        .task(id: currentID) { await loadWindow() }
        // The place's name, asked for as you arrive at each photograph. It is
        // a network call that is allowed to fail, and the caption is already
        // correct without it.
        .task(id: currentID) {
            placeName = nil
            guard let place = current?.place else { return }
            placeName = PlaceNames.shared.name(for: place)
            guard placeName == nil else { return }
            await PlaceNames.shared.resolve(place)
            placeName = PlaceNames.shared.name(for: place)
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

    // MARK: - Metrics

    /// Fixed bands, so the picture's stage is the remainder rather than a
    /// guess. Clear of the status bar and the Dynamic Island — a control at
    /// y=34 in screen coordinates is not pressable, which this app has already
    /// learned once.
    private static let topInset: CGFloat = 58
    private static let bottomInset: CGFloat = 28
    private static let headerHeight: CGFloat = 44
    private static let dateHeight: CGFloat = 34
    private static let stripHeight: CGFloat = 74
    /// How far the print sits in from the edge of the screen.
    private static let printInset: CGFloat = 20

    // MARK: - The deck

    /// The run, paged, with each photograph inset as a print.
    ///
    /// A paging `ScrollView`, not a `TabView`: `TabView`'s page style owns its
    /// horizontal gesture and cannot be told to stop, so panning a zoomed-in
    /// photograph flicked to the next one.
    private func deck(size: CGSize) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(photos) { photo in
                    PhotoPage(photo: photo,
                              image: images[photo.fileName],
                              isCurrent: photo.id == currentID,
                              inset: Self.printInset,
                              onZoomChanged: { isZoomed = $0 })
                        .frame(width: size.width, height: max(size.height, 1))
                        .id(photo.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .scrollDisabled(isZoomed)
        .frame(height: max(size.height, 1))
    }

    // MARK: - The strip

    /// The run you are inside, along the bottom.
    ///
    /// This is the part of the reference that makes the screen feel like a
    /// place rather than a slide: you can always see that there is more, and
    /// which of it you are in. The current frame stands taller than its
    /// neighbours, so the strip needs no highlight, no border and no dot row —
    /// the size IS the indicator.
    ///
    /// It shares `currentID` with the deck, so the two stay in step in both
    /// directions for free: swipe the picture and the strip scrolls, tap the
    /// strip and the picture pages.
    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(photos) { photo in
                        let isCurrent = photo.id == currentID
                        Button {
                            HapticsEngine.tick()
                            withAnimation(GridConstants.motionSnappy) { currentID = photo.id }
                        } label: {
                            CachedImageView(fileName: photo.fileName,
                                            width: Self.stripHeight,
                                            height: Self.stripHeight,
                                            cornerRadius: 6)
                                .frame(width: isCurrent ? 52 : 40,
                                       height: isCurrent ? 66 : 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .opacity(isCurrent ? 1 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .id(photo.id)
                        .accessibilityLabel(photo.title ?? "Photo")
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .animation(GridConstants.motionSnappy, value: currentID)
            .onChange(of: currentID) { _, id in
                guard let id else { return }
                withAnimation(GridConstants.motionSmooth) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onAppear {
                guard let currentID else { return }
                proxy.scrollTo(currentID, anchor: .center)
            }
        }
    }

    /// Close on the left, what the photograph is OF in the middle, and
    /// everything you can do to it on the right.
    ///
    /// The title moved up here from the black under the picture. Below, it
    /// read as a caption for the screen; above, between the two controls, it
    /// is the screen's subject — which is what it is, because every photograph
    /// in this app is a photograph of a win and the win already has a name.
    ///
    /// One `Menu` rather than a row of three glyphs. Share, save and delete
    /// are three things you do rarely to a picture you are looking at, and a
    /// permanent toolbar for them competes with the photograph for the one
    /// thing this screen is for. `⋯` at the top right is also where both
    /// references put it, and where iOS puts it.
    private var header: some View {
        ZStack {
            Text(current?.title ?? " ")
                .font(Typography.headerMedium)
                .foregroundStyle(.white.opacity(current?.title == nil ? 0 : 0.95))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 64)
                .animation(GridConstants.crossFade, value: currentID)

            HStack {
                Button(action: onClose) { chromeGlyph("xmark") }
                    .accessibilityLabel("Close photo")
                Spacer(minLength: 0)
                actionMenu
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, GridConstants.horizontalPadding)
    }

    private var actionMenu: some View {
        Menu {
            if let current, let image = shareImage {
                ShareLink(item: image,
                          preview: SharePreview(current.title ?? "Photo", image: image)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Button { save() } label: {
                Label(isSaved ? "Saved to Photos" : "Save to Photos",
                      systemImage: isSaved ? "checkmark" : "square.and.arrow.down")
            }
            .disabled(saving || isSaved)
            Divider()
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label("Remove Photo", systemImage: "trash")
            }
        } label: {
            chromeGlyph("ellipsis")
        }
        .accessibilityLabel("Photo actions")
    }

    /// When it was, under the picture. Quiet, because it is the one fact here
    /// nobody opened this screen to read.
    private var dateLine: some View {
        // **When, and — if the win knows — where**, on one line in that order.
        //
        // The place joins the date rather than taking a line of its own: the
        // whole discipline of this screen is that the photograph is the
        // content and everything else is a caption, and a second caption line
        // would be the chrome growing to hold a fact nobody opened the screen
        // to read. Photos does the same. It appears only when there is one,
        // and it appears LATE — the name is a network call — so it fades in
        // rather than pushing the line about.
        Text(caption)
            .font(Typography.screenSubtitle)
            .foregroundStyle(.white.opacity(0.45))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .animation(GridConstants.crossFade, value: currentID)
            .animation(GridConstants.gentleReveal, value: placeName)
            .accessibilityHidden(current == nil)
    }

    private var caption: String {
        guard let current else { return " " }
        let when = Self.dayLabel(current.date) + " · " + Self.timeLabel(current.date)
        guard let place = current.place,
              let name = placeName ?? PlaceNames.shared.name(for: place) else { return when }
        return when + " · " + name
    }

    private func chromeGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
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

    /// The time of day, in the locale's own shape.
    static func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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
    /// How far the print sits in from the edge of its page.
    let inset: CGFloat
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
                    // A print, not a window. The radius is the app's surface
                    // radius, so a photograph laid on the black agrees with
                    // every other surface the app puts down.
                    .clipShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface,
                                                style: .continuous))
                    .padding(inset)
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
                // Resisted at the edges WHILE dragging, not clamped only on
                // release. The doc comment above has claimed this since the
                // day it was written and the code did not do it: a hard
                // `min/max` stopped the picture dead under the finger, which
                // `docs/apple-design.md` §9 is explicit about — progressive
                // resistance, never a hard stop.
                offset = resisted(CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                ))
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

    /// Settles the picture back inside its limits when the finger lifts.
    private func clampOffset() {
        let (limitX, limitY) = limits()
        offset = CGSize(width: min(max(offset.width, -limitX), limitX),
                        height: min(max(offset.height, -limitY), limitY))
    }

    /// The same limits, but giving back progressively less past them rather
    /// than refusing to move.
    private func resisted(_ proposed: CGSize) -> CGSize {
        let (limitX, limitY) = limits()
        return CGSize(width: resisted(proposed.width, limit: limitX),
                      height: resisted(proposed.height, limit: limitY))
    }

    private func resisted(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        guard abs(value) > limit else { return value }
        let over = abs(value) - limit
        let give = GridConstants.rubberband(overshoot: over, dimension: max(limit, 1))
        return (limit + give) * (value < 0 ? -1 : 1)
    }

    /// How far the picture may travel before it is being dragged off screen.
    ///
    /// Proportional to how far in you are rather than a fixed number: at 2x
    /// there is half a frame of slack in each direction, at 6x five times as
    /// much, and one constant cannot be right for both.
    private func limits() -> (CGFloat, CGFloat) {
        let slack = (committedScale - 1) / 2
        return (UIScreen.main.bounds.width * slack,
                UIScreen.main.bounds.height * slack)
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
