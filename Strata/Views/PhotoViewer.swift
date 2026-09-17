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
    /// Pages showing the tier-M preview while their full-resolution picture
    /// decodes. See `loadWindow`. Share waits for the real one.
    @State private var previewOnly: Set<String> = []
    /// The deck's position as a FRACTIONAL index, republished every frame it
    /// moves, and the strip's scrub. This is what lets the strip below track a
    /// finger that is still on the photograph above, rather than jumping once
    /// the page settles.
    ///
    /// **A reference, read only by the strip.** It was `@State` here, so every
    /// frame of a swipe re-ran this whole body — header, deck and a strip
    /// holding a card for every photograph in the library. Now a frame redraws
    /// the strip and nothing else; the title reads `shownIndex`, which changes
    /// once per photograph.
    @State private var position = DeckPosition()
    /// `position.progress` rounded: which photograph the deck is over.
    @State private var shownIndex: Int = 0
    /// Where `currentID` sits in `photos`, found once per change rather than
    /// by a scan on every read.
    @State private var currentIndex: Int = 0

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
        if photos.indices.contains(currentIndex), photos[currentIndex].id == currentID {
            return photos[currentIndex]
        }
        return photos.first { $0.id == currentID } ?? photos.first { $0.id == startAt } ?? photos.first
    }

    /// **The photograph the title is of: the one actually on screen.**
    ///
    /// A paging scroll view writes `currentID` when it settles, so the title
    /// belonged to the photograph you had just left for as long as a swipe
    /// takes — reported twice as "the photos and titles arent accurate at
    /// times". The deck reports where it is on every frame for the strip
    /// below; the title reads the same number, rounded, so it is right at
    /// every moment of a swipe rather than only at the end of one.
    private var shown: GalleryPhoto? {
        photos.indices.contains(shownIndex) ? photos[shownIndex] : current
    }

    private var index: Int {
        if photos.indices.contains(currentIndex), photos[currentIndex].id == currentID {
            return currentIndex
        }
        return photos.firstIndex { $0.id == currentID } ?? 0
    }

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("PhotoViewer")
        #endif
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // **The deck reaches up behind the header.**
                //
                // The header used to be a band ABOVE the deck, so the top of
                // the screen was dead to the finger: the owner could not
                // "swipe through on the top in the photo viewer". It is an
                // overlay now, and the deck owns the whole height — but the
                // PICTURE inside each page is still padded down past the
                // header, so the title keeps its black and never sits on the
                // photograph. That rule is settled (CLAUDE.md, 2026-09-09,
                // owner's call) and this does not touch it; only the swipe
                // area moved.
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        deck(size: CGSize(
                            width: geo.size.width,
                            height: geo.size.height
                                - Self.topInset - Self.bottomInset
                                - dateHeight - Self.stripHeight
                        ), topPadding: Self.headerHeight)

                        dateLine
                            .frame(height: dateHeight)

                        Filmstrip(photos: photos, position: position,
                                  currentID: currentID, select: select)
                            .frame(height: Self.stripHeight)
                    }

                    header
                        .frame(height: Self.headerHeight)
                }
                .padding(.top, Self.topInset)
                .padding(.bottom, Self.bottomInset)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear { currentID = startAt }
        .onChange(of: currentID, initial: true) { _, id in
            currentIndex = photos.firstIndex { $0.id == id } ?? 0
        }
        #if DEBUG
        .task { await debugAutoPage() }
        #endif
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

    #if DEBUG
    /// `-strataPerfProbe`: what opening costs in its first two seconds, and,
    /// with `-strataPhotoAutoPage n`, n page turns through the filmstrip's own
    /// select path, each counted over its own window. Nothing here can swipe.
    private func debugAutoPage() async {
        PerfProbe.window("PhotoViewer open", seconds: 2)
        let turns = DebugHarness.photoAutoPages
        guard turns > 0 else { return }
        try? await Task.sleep(for: .seconds(6))
        for turn in 0..<turns {
            guard !Task.isCancelled else { return }
            let next = index + 1
            guard photos.indices.contains(next) else { return }
            PerfProbe.window("PhotoViewer page-turn \(turn)", seconds: 1.5)
            select(photos[next])
            try? await Task.sleep(for: .seconds(2))
        }
    }
    #endif

    // MARK: - Chrome

    // MARK: - Metrics

    /// Fixed bands, so the picture's stage is the remainder rather than a
    /// guess. Clear of the status bar and the Dynamic Island — a control at
    /// y=34 in screen coordinates is not pressable, which this app has already
    /// learned once.
    private static let topInset: CGFloat = 58
    private static let bottomInset: CGFloat = 28
    private static let headerHeight: CGFloat = 44
    /// The band under the picture. Taller when there is a place to name, so
    /// the second line has somewhere to go rather than squeezing the deck.
    private var dateHeight: CGFloat { placeLine == nil ? 34 : 56 }
    private static let stripHeight: CGFloat = 74
    /// How far the print sits in from the edge of the screen.
    private static let printInset: CGFloat = 20

    // MARK: - The deck

    /// The run, paged, with each photograph inset as a print.
    ///
    /// A paging `ScrollView`, not a `TabView`: `TabView`'s page style owns its
    /// horizontal gesture and cannot be told to stop, so panning a zoomed-in
    /// photograph flicked to the next one.
    private func deck(size: CGSize, topPadding: CGFloat = 0) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(photos) { photo in
                    PhotoPage(photo: photo,
                              image: images[photo.fileName],
                              isCurrent: photo.id == currentID,
                              inset: Self.printInset,
                              onZoomChanged: { isZoomed = $0 })
                        // The page is the full height so the whole of it
                        // swipes; the picture inside it starts below the
                        // header, which is what keeps the title in the black.
                        .padding(.top, topPadding)
                        .frame(width: size.width, height: max(size.height, 1))
                        .id(photo.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        // **The join.** A paging scroll view writes `currentID` only when it
        // settles; this reports where it is on every frame, which is what the
        // strip below is drawn from.
        .onScrollGeometryChange(for: Double.self) { geo in
            let page = geo.containerSize.width
            guard page > 0 else { return 0 }
            return Double(geo.contentOffset.x / page)
        } action: { _, progress in
            position.progress = progress
            let rounded = Int(progress.rounded())
            if rounded != shownIndex { shownIndex = rounded }
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(isZoomed)
        .frame(height: max(size.height, 1))
    }

    private func select(_ photo: GalleryPhoto) {
        guard photo.id != currentID else { return }
        HapticsEngine.tick()
        withAnimation(GridConstants.motionSnappy) { currentID = photo.id }
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
            Text(shown?.title ?? " ")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.onDarkStrong.opacity(shown?.title == nil ? 0 : 1))
                .animation(GridConstants.photoTitleFade, value: shown?.id)
                .lineLimit(1)
                .truncationMode(.tail)
                // Clear of the two chrome buttons, derived rather than
                // typed: their 44pt target plus the page margin. Typed as 64
                // it was a number that happened to work and would not have
                // survived either of them changing size.
                .padding(.horizontal, 44 + GridConstants.horizontalPadding)
                .animation(GridConstants.crossFade, value: currentID)

            HStack {
                GlassIconButton(systemName: "xmark", tint: .white,
                                accessibilityLabel: "Close photo", action: onClose)
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
            Button(role: .destructive) {
                HapticsEngine.warning()
                confirmingDelete = true
            } label: {
                Label("Remove Photo", systemImage: "trash")
            }
        } label: {
            GlassIconLabel(systemName: "ellipsis", tint: .white)
        }
        .accessibilityLabel("Photo actions")
    }

    /// When it was, under the picture. Quiet, because it is the one fact here
    /// nobody opened this screen to read.
    private var dateLine: some View {
        // **When, and — if the win knows — where**, on one line in that order.
        //
        // The place appears only when there is one, and it appears LATE — the
        // name is a network call — so it fades in rather than pushing the
        // line about.
        //
        // **Two lines, so neither of them truncates.**
        //
        // It was one: size, date, time and place joined by middots, and on a
        // real photograph that ran off the edge — "Regular · 8 September ·
        // 6:26 PM · 1 Fennel House, Syca…". The owner read that as the
        // location not being shown at all, which is fair: a fact you cannot
        // finish reading has not been shown to you.
        //
        // The second line only exists when there is a place, so the screen
        // does not grow chrome for photographs that have none.
        VStack(spacing: 2) {
            Text(caption)
                .font(Typography.screenSubtitle)
                // The viewer is always dark, so the dark-ground ink, not a
                // private white. Both lines share it, as in Photos: the
                // smaller size and the pin already say which is secondary.
                .foregroundStyle(AppColors.onDarkQuiet)
            if let place = placeLine {
                Label(place, systemImage: "mappin.and.ellipse")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(AppColors.onDarkQuiet)
                    .labelStyle(.titleAndIcon)
            }
        }
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .animation(GridConstants.crossFade, value: currentID)
            .animation(GridConstants.gentleReveal, value: placeName)
            .accessibilityHidden(current == nil)
    }


    private var caption: String {
        guard let current else { return " " }
        // Size first: it is the one fact about the win that the picture cannot
        // show you, and it is why the block on the tower is the shape it is.
        return current.size.effortLabel + " · "
            + Self.dayLabel(current.date) + " · " + Self.timeLabel(current.date)
    }

    /// The place, on its own line, once its name has arrived.
    private var placeLine: String? {
        guard let place = current?.place else { return nil }
        return placeName ?? PlaceNames.shared.name(for: place)
    }

    // The viewer's chrome (close, and the `⋯` menu) is `GlassIconButton`
    // and `GlassIconLabel`: on glass, not bare, because a tall photograph can
    // arrive directly under them and a white glyph on a white sky is not a
    // control. It was a private 36pt disc with a semibold glyph; it is the
    // same 44pt control the replay, the map and the camera use now.

    // MARK: - Actions

    private var isSaved: Bool { current.map { saved.contains($0.id) } ?? false }

    /// The picture the share sheet sends — the one already on screen, not a
    /// second decode of it.
    private var shareImage: Image? {
        guard let current, !previewOnly.contains(current.fileName),
              let ui = images[current.fileName] else { return nil }
        return Image(uiImage: ui)
    }

    /// The current photograph and its two neighbours, and nothing else.
    ///
    /// Three full-resolution pictures is the working set a swipeable deck
    /// actually needs: the one you are looking at, and the one you are about
    /// to see whichever way you go. Everything outside the window is dropped
    /// on the same pass, so paging through a year does not accumulate.
    private func loadWindow() async {
        // **The one you are looking at, first.**
        //
        // The window used to be built in index order — previous, current,
        // next — and loaded serially, so arriving at a photograph meant
        // waiting for its NEIGHBOUR to decode off disk before the picture in
        // front of you appeared. The owner: "the photo loading is slow." It
        // was not slow; it was queued behind something nobody could see.
        //
        // It also caused the second half of that report, "the photos and
        // titles arent accurate at times": the caption follows `currentID`
        // immediately while the image waits its turn, so for as long as the
        // decode took you were reading one photograph's title over another
        // photograph. Loading the visible one first shrinks that window to
        // almost nothing.
        let order = [index, index + 1, index - 1]
            .filter { photos.indices.contains($0) }
        let window = order.map { photos[$0].fileName }
        images = images.filter { window.contains($0.key) }
        previewOnly = previewOnly.filter { window.contains($0) }
        // **A preview first, then the full picture** (2026-09-16). The one in
        // front of you comes up from its 640px derivative — a few
        // milliseconds from disk — and the 2560px decode replaces it in place
        // when it lands. Same page, same aspect, so the swap is not a second
        // arrival: the fade is keyed on `image != nil`, which the swap does
        // not change.
        //
        // **Every await is a place a page turn can land** (fix round 1): this
        // task is cancelled on each turn, so it stops before starting a
        // decode for a page you have left, and never writes a picture into a
        // window that has moved on. `decodeOriginal` also drops a queued full
        // decode when the task is cancelled.
        if let first = window.first, images[first] == nil, !Task.isCancelled,
           let preview = await ImageManager.shared.loadThumbnail(
               fileName: first, maxWidth: CGFloat(ImageDerivatives.medium)),
           !Task.isCancelled, images[first] == nil {
            images[first] = preview
            previewOnly.insert(first)
            await Task.yield()
        }
        for name in window where images[name] == nil || previewOnly.contains(name) {
            guard !Task.isCancelled else { return }
            if let ui = await ImageManager.shared.loadFullImage(fileName: name) {
                guard !Task.isCancelled else { return }
                images[name] = ui
                previewOnly.remove(name)
            }
            // Yield between decodes so the first one can be drawn before the
            // neighbours are fetched. Without this the three awaits run back
            // to back on the same turn and the picture still arrives late.
            await Task.yield()
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
        // Made once: this runs in the caption, on every body.
        return (calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? Album.Formats.formatter("d MMMM") : Album.Formats.formatter("d MMMM yyyy")).string(from: date)
    }

}

/// The deck's live position, as a reference. See `PhotoViewer.position`.
@Observable
final class DeckPosition {
    var progress: Double = 0
    /// Set while a finger is on the strip itself, which then leads and the
    /// deck follows on release.
    var scrub: Double?
    @ObservationIgnored var scrubOrigin: Double?
    var live: Double { scrub ?? progress }
}

// MARK: - The strip

/// The scrubber, driven by the deck's LIVE scroll position.
///
/// **The two used to be joined only at the ends.** Both bound
/// `scrollPosition(id: $currentID)`, but a paging scroll view writes that
/// binding when it SETTLES — so while your finger was on the photograph
/// the strip sat perfectly still, then jumped once you let go. From a
/// phone: "why is the bottom seprete from the top scroll doesnt make sense
/// at all." It is the right complaint: the strip is a position indicator,
/// and an indicator that only updates after the fact is not indicating
/// anything.
///
/// So the strip is no longer a scroll view of its own. It is an `HStack`
/// offset by a FRACTIONAL index that the deck publishes continuously, and
/// dragging it writes that same fraction back. One number, read every
/// frame, and the two cannot disagree.
///
/// **Its own view, and only the cards near the middle.** It was a property of
/// `PhotoViewer` drawing a card for EVERY photograph in the library, so each
/// frame of a swipe rebuilt all of them, and opening the viewer asked for
/// every thumbnail at once. It now reads the position itself, so a frame
/// redraws the strip alone, and it draws the cards within `reach(width:)` of
/// the middle: every card any part of which can be on screen, plus one either
/// side, worked out from the strip's own width so an iPad draws all of its
/// cards too. What is drawn is unchanged. VoiceOver reads the drawn cards,
/// which always include the neighbours either side (`reach` is never under 2);
/// choosing one moves the window with it.
struct Filmstrip: View {
    let photos: [GalleryPhoto]
    let position: DeckPosition
    let currentID: String?
    let select: (GalleryPhoto) -> Void

    /// One card on the strip. Portrait, because a photograph is more often
    /// portrait than not and a square frame crops the subject out of it.
    static let card = CGSize(width: 46, height: 60)
    static let gap: CGFloat = 10
    static let radius: CGFloat = 7
    /// The size of the decode, as it always was.
    static let side: CGFloat = 74
    static var pitch: CGFloat { card.width + gap }

    /// How many cards either side of the middle are drawn: as many as reach
    /// from the middle card's centre to the strip's edge, plus one.
    static func reach(width: CGFloat) -> Int {
        max(2, Int(((width / 2 + card.width / 2) / pitch).rounded(.up)) + 1)
    }

    /// The indices drawn for a position and a strip width.
    static func window(progress: Double, count: Int, width: CGFloat) -> ClosedRange<Int>? {
        guard count > 0 else { return nil }
        let reach = Double(reach(width: width))
        let last = count - 1
        let lo = min(max(0, Int((progress - reach).rounded(.down))), last)
        let hi = max(min(last, Int((progress + reach).rounded(.up))), lo)
        return lo...hi
    }

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("Filmstrip")
        #endif
        let pitch = Self.pitch
        let progress = position.live
        return GeometryReader { geo in
            let range = Self.window(progress: progress, count: photos.count, width: geo.size.width)
            let lo = range?.lowerBound ?? 0
            let drawn = range.map { Array(photos[$0].enumerated()) } ?? []
            HStack(spacing: Self.gap) {
                ForEach(drawn, id: \.element.id) { offset, photo in
                    let distance = min(abs(Double(lo + offset) - progress), 1)
                    CachedImageView(fileName: photo.fileName,
                                    width: Self.side,
                                    height: Self.side,
                                    cornerRadius: Self.radius)
                        // One size for every frame. The depth does the work; a
                        // second, smaller size for the neighbours would be
                        // saying it twice.
                        .frame(width: Self.card.width, height: Self.card.height)
                        .clipShape(RoundedRectangle(cornerRadius: Self.radius,
                                                    style: .continuous))
                        // Depth without distortion: the middle frame is nearer,
                        // its neighbours recede, sit slightly lower and go
                        // slightly quiet. Every frame stays square on.
                        //
                        // **No rotation.** This was a coverflow wheel — asked
                        // for, built, then seen: "why are the photos rotated
                        // weirly on the bottom." A filmstrip has one job. You
                        // are scanning for a picture you remember, and a
                        // photograph turned forty degrees away is a sliver of
                        // itself.
                        .scaleEffect(1 - 0.22 * distance, anchor: .bottom)
                        .offset(y: 5 * distance)
                        .opacity(1 - 0.3 * distance)
                        // The centre card passes in FRONT of its neighbours,
                        // or the arriving card is drawn under the one it
                        // replaces and the strip flickers as they cross.
                        .zIndex(distance < 0.5 ? 1 : 0)
                        .onTapGesture { select(photo) }
                        .accessibilityLabel(photo.title ?? "Photo")
                    }
            }
            // Centre the frame at `progress`. Half the card either side is why
            // the FIRST and LAST photographs can reach the middle at all. The
            // cards before `lo` are not drawn, so the row starts `lo` pitches
            // further along.
            .offset(x: geo.size.width / 2 - Self.card.width / 2
                       - CGFloat(progress - Double(lo)) * pitch)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .frame(height: Self.card.height)
        // The whole strip is draggable, not just the cards — a scrubber you
        // can only catch by landing on a 46pt thumbnail is a scrubber that
        // feels broken.
        .contentShape(Rectangle())
        .gesture(scrubGesture(pitch: pitch))
        .sensoryFeedback(.selection, trigger: currentID)
        // **A container, or the name lands on every thumbnail.** SwiftUI hands
        // an identifier down to descendants, so without this the strip and all
        // of its 46pt cards answer to "filmstrip" and a UI test swipes a
        // thumbnail instead of the scrubber.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filmstrip")
    }

    /// Dragging the strip scrubs the deck, and releasing settles on a frame.
    private func scrubGesture(pitch: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let from = position.scrubOrigin ?? position.progress
                if position.scrubOrigin == nil { position.scrubOrigin = from }
                let raw = from - Double(value.translation.width / pitch)
                position.scrub = min(max(raw, 0), Double(max(photos.count - 1, 0)))
            }
            .onEnded { _ in
                let landing = Int((position.scrub ?? position.progress).rounded())
                position.scrub = nil
                position.scrubOrigin = nil
                guard photos.indices.contains(landing) else { return }
                select(photos[landing])
            }
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
        // **The pan is only attached while zoomed in.**
        //
        // It used to be a `simultaneousGesture` at all times, guarded by
        // `guard zoomed else { return }` inside the handler — but the guard is
        // in the WRONG PLACE. A `DragGesture` that is installed recognises,
        // whatever its handler decides to do afterwards, and a recogniser on
        // the page starves the deck's paging scroll view of the horizontal
        // drag. So swiping the picture did nothing: the owner reported it as
        // "swiping to the right or left should move through the photos, right
        // now it doesnt", and it never did.
        //
        // CLAUDE.md already records this rule twice over, from the tower:
        // any recogniser on a block measured 0.0pt of scroll, and
        // `.gesture(cond ? g : nil)` still installs one — the MODIFIER has to
        // be conditional, not the gesture. That is what `panWhenZoomed` does.
        .panWhenZoomed(zoomed ? pan : nil)
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
    /// **Not `try?`, and the file goes only if the save went.** A save that
    /// failed silently left the file deleted and the log still pointing at it,
    /// which is a block naming a photograph that is not there. Same rule as
    /// the batch delete: never `try?` a write another step depends on, and say
    /// so in the log when it fails.
    static func removePhoto(fileName: String, context: ModelContext) {
        let descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.imageFileName == fileName }
        )
        do {
            try context.transaction {
                for log in try context.fetch(descriptor) { log.imageFileName = nil }
            }
        } catch {
            NSLog("[strata-photo] could not clear the reference to \(fileName), so the file stays: \(error)")
            return
        }
        ImageManager.shared.deleteImage(fileName: fileName)
    }
}

private extension View {
    /// Attaches a drag gesture only when there is one to attach.
    ///
    /// The conditional is on the MODIFIER: with `.simultaneousGesture(nil)`
    /// SwiftUI still installs a recogniser, and an installed recogniser is
    /// enough to starve an enclosing scroll view whether or not it ever
    /// handles anything.
    @ViewBuilder
    func panWhenZoomed(_ gesture: (some Gesture)?) -> some View {
        if let gesture {
            self.simultaneousGesture(gesture)
        } else {
            self
        }
    }
}
