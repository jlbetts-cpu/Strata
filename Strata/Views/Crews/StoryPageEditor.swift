import PencilKit
import SwiftData
import SwiftUI

/// **Your words page, made by hand, full screen** (the owner, 2026-10-16: "I
/// want it to be like Instagram where you can easily doodle, add stickers in
/// a full screen editing format, add a photo strip, make it nice").
///
/// The page as your friends will see it, filling the screen on black as the
/// story does, and the app's one pen on it (`InkCanvas`): draw with a finger,
/// the eraser, undo, and the tools along the foot, which put things ON the
/// page: your stickers, your head, tonight's photo strip, and a photograph
/// behind the words. A sticker moves with a finger and sizes and turns with
/// two, as everywhere you draw.
///
/// What leaves is the words, and the ink and stickers as one clear picture
/// over them (`StoryPageFiles.keepArt`), so a friend's phone needs nothing
/// it does not already have.
struct StoryPageEditor: View {
    let high: String
    let low: String
    let buffalo: String
    let day: String
    /// Tonight's picked photographs, any of which can go behind the words.
    let photos: [HabitLog]
    /// The photograph behind, as chosen.
    let photo: UUID?
    /// The photograph, the page's picture by name (nil for none), and the
    /// wins whose photographs are in its strip.
    let done: (UUID?, String?, [UUID]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ink: InkController
    @State private var behind: UUID?
    @State private var printing = false
    @State private var noStrip = false
    @State private var stripWins: Set<UUID> = []

    init(high: String, low: String, buffalo: String, day: String, photos: [HabitLog], photo: UUID?,
         done: @escaping (UUID?, String?, [UUID]) -> Void) {
        self.high = high
        self.low = low
        self.buffalo = buffalo
        self.day = day
        self.photos = photos
        self.photo = photo
        self.done = done
        let draft = StoryPageFiles.draft(on: day)
        let drawing = draft.flatMap { try? PKDrawing(data: $0.drawing) } ?? PKDrawing()
        _ink = State(initialValue: InkController(drawing: drawing, stickers: draft?.stickers ?? []))
        _behind = State(initialValue: photo)
        _stripWins = State(initialValue: Set(draft?.stripWins ?? []))
    }

    private var chosen: HabitLog? { behind.flatMap { id in photos.first { $0.id == id } } }

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            top
            InkCanvas(controller: ink, aspectRatio: StoryWordsPage<EmptyView, EmptyView>.aspect,
                      ground: AnyShapeStyle(Color(white: 0.09)),
                      cornerRadius: GridConstants.radiusSurface, lightInk: true,
                      underlay: AnyView(page)) {
                tools
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapTight)
        .background { Color.black.ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .alert("No photos for a strip yet", isPresented: $noStrip) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Pick a win with a photo for tonight's story, and it makes the strip.")
        }
    }

    // MARK: The bar

    private var top: some View {
        HStack {
            StoryGlyph(systemName: "xmark", tint: .white, label: "Cancel") { dismiss() }
            Spacer(minLength: 0)
            Button {
                HapticsEngine.lightTap()
                finish()
            } label: {
                Text("Done").sheetAction()
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.pressWord)
        }
    }

    // MARK: The page under the ink

    private var page: some View {
        StoryWordsPage(high: high.isEmpty ? nil : high, low: low.isEmpty ? nil : low,
                       buffalo: buffalo.isEmpty ? nil : buffalo, hasPicture: chosen != nil) { size in
            if let name = chosen?.imageFileName {
                CachedImageView(fileName: name, width: size.width, height: size.height, cornerRadius: 0)
            }
        }
    }

    // MARK: The tools

    /// After the pen's own (eraser, weight, undo, your stickers): your head,
    /// the strip, and the photograph behind.
    @ViewBuilder private var tools: some View {
        if HeadStore.shared.headForCrews != nil {
            GlassIconButton(systemName: "face.smiling", onPage: true, accessibilityLabel: "Add your head") {
                guard let name = HeadSticker.current() else { return }
                ink.place(name)
            }
        }
        GlassIconButton(systemName: "photo.stack", onPage: true, accessibilityLabel: "Add your photo strip") {
            Task { await addStrip() }
        }
        .disabled(printing)
        if !photos.isEmpty {
            GlassIconButton(systemName: chosen == nil ? "photo" : "photo.fill", onPage: true,
                            accessibilityLabel: "Photo behind") {
                nextPhoto()
            }
            .accessibilityValue(chosen?.habit?.title ?? "None")
        }
    }

    /// A tap goes round: none, then each of tonight's photographs.
    private func nextPhoto() {
        let ids: [UUID?] = [nil] + photos.map(\.id)
        let at = ids.firstIndex(of: behind) ?? 0
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
            behind = ids[(at + 1) % ids.count]
        }
    }

    /// Tonight's strip, as the booth prints it, on your paper, put on the
    /// page as a sticker. **Only tonight's story photographs, each checked**
    /// (the review, 2026-10-16): the day's other pictures, or one the check
    /// held back, never ride out inside the page.
    private func addStrip() async {
        printing = true
        defer { printing = false }
        let strip = await PhotoStrip.mine(day: day, context: modelContext)
        let story = Set(photos.map(\.id))
        var frames: [PhotoStrip.Frame] = []
        for frame in strip.frames(excluding: StripKeeping.excluded(.me, day: day))
        where story.contains(frame.id) && !frame.isDoodle {
            guard let jpeg = frame.picture.jpegData(compressionQuality: 0.8),
                  await SocialStore.shared.photoCheck(jpeg) else { continue }
            frames.append(frame)
        }
        guard !frames.isEmpty else { noStrip = true; return }
        let renderer = ImageRenderer(content: StripView(frames: frames, day: day, signature: strip.signature,
                                                        paper: StripKeeping.paper(for: .dark), width: 200,
                                                        developed: 1, rimmed: false))
        renderer.scale = 3
        renderer.isOpaque = false
        guard let image = renderer.uiImage, let name = StoryPageFiles.addSticker(image) else { return }
        stripWins.formUnion(frames.map(\.id))
        HapticsEngine.success()
        ink.place(name, aspect: image.size)
    }

    // MARK: Done

    private func finish() {
        let canvas = ink.canvasSize
        // A strip taken off the page takes its wins with it.
        let strips = ink.stickers.filter { $0.name.hasPrefix(StoryPageFiles.prefix) }
        let wins = strips.isEmpty ? [] : Array(stripWins)
        StoryPageFiles.keep(.init(drawing: ink.drawing.dataRepresentation(), stickers: ink.stickers,
                                  width: canvas.width, height: canvas.height, stripWins: wins), on: day)
        let art = StoryPageFiles.keepArt(drawing: ink.drawing, stickers: ink.stickers, canvas: canvas)
        done(chosen?.id, art, wins)
        dismiss()
    }
}
