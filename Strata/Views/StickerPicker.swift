import PhotosUI
import SwiftUI

/// **The day's mark: a sticker of yours, or an emoji** (the owner,
/// 2026-10-06, "From your photos"). Opens from the journal's corner button.
/// Your stickers, newest first; New Sticker lifts one out of a photograph;
/// Emoji opens the keyboard, as the button always did. Choosing the day's
/// own mark again takes it off, as with an emoji.
///
/// **And a sticker for a drawing** (the owner, 2026-10-06: "make it so you
/// can add stickers to doodles when you are drawing them"): the same grid and
/// New Sticker from the ink canvas's row (`InkControls`), without Emoji,
/// because an emoji is the day's mark and not something drawn on.
struct StickerPicker: View {
    /// What a chosen sticker is for: the day's mark, or a drawing.
    enum Purpose { case day, drawing }

    /// The day's symbol as it stands.
    let current: String?
    var purpose: Purpose = .day
    let onPick: (_ symbol: String) -> Void
    /// New Sticker: the host closes this popover and opens the photos
    /// (`StickerMaking`). The photo picker is never presented from in here.
    ///
    /// **It was, and it crashed** (the owner, 2026-10-06: "new sticker button
    /// crashes"). Presented from inside a popover, the photo picker did
    /// nothing on the simulator and took the app down on a phone. The Emoji
    /// button already did it the safe way (close, then open the next thing a
    /// beat later), and now New Sticker does too.
    let onNewSticker: () -> Void
    /// Emoji, for the day's mark. Nil leaves the button out.
    var onEmoji: (() -> Void)? = nil

    @State private var store = StickerStore.shared
    /// **Edit, to take stickers away** (the owner, 2026-10-08: "there also
    /// needs to be a way to remove stickers in general"). The long press had
    /// it and nobody finds a long press; Edit says it out loud.
    @State private var editing = false

    private static let tile: CGFloat = 60
    private let columns = Array(repeating: GridItem(.fixed(Self.tile), spacing: GridConstants.gapTight), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            if store.names.isEmpty {
                Text("Lift a sticker out of one of your photos.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    Button(editing ? "Done" : "Edit") {
                        HapticsEngine.lightTap()
                        withAnimation(GridConstants.crossFade) { editing.toggle() }
                    }
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(minWidth: 44, minHeight: 32)
                    .buttonStyle(.pressWord)
                }
                ScrollView {
                    LazyVGrid(columns: columns, spacing: GridConstants.gapTight) {
                        ForEach(store.names, id: \.self) { tile($0) }
                    }
                }
                .frame(maxHeight: Self.tile * 3 + GridConstants.gapTight * 2)
            }
            HStack {
                if let onEmoji {
                    Button { onEmoji() } label: {
                        Label("Emoji", systemImage: "face.smiling")
                            .frame(minHeight: GlassIconButton.defaultSide)
                    }
                    Spacer(minLength: GridConstants.gapItem)
                }
                Button { onNewSticker() } label: {
                    Label("New Sticker", systemImage: "plus")
                        .frame(minHeight: GlassIconButton.defaultSide)
                }
                if onEmoji == nil { Spacer(minLength: 0) }
            }
            .font(Typography.headerMedium)
            .foregroundStyle(AppColors.inkPrimary)
            .buttonStyle(.pressWord)
        }
        .padding(GridConstants.gapWide)
        .frame(width: Self.tile * 4 + GridConstants.gapTight * 3 + GridConstants.gapWide * 2)
    }

    private func tile(_ name: String) -> some View {
        let symbol = StickerStore.symbol(for: name)
        return Button {
            HapticsEngine.lightTap()
            if editing {
                withAnimation(GridConstants.crossFade) { store.remove(name) }
                if store.names.isEmpty { editing = false }
            } else {
                onPick(symbol)
            }
        } label: {
            ZStack {
                if symbol == current {
                    Circle().fill(AppColors.inkPrimary.opacity(0.08))
                }
                if let image = store.image(name) {
                    Image(uiImage: image).resizable().scaledToFit().padding(6)
                }
            }
            .frame(width: Self.tile, height: Self.tile)
            .overlay(alignment: .topLeading) {
                if editing {
                    Image(systemName: "minus")
                        .iconSize(GridConstants.iconMedium, relativeTo: .caption, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(AppColors.destructiveInk))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .contextMenu {
            Button("Delete Sticker", systemImage: "trash", role: .destructive) { store.remove(name) }
        }
        .accessibilityLabel(editing ? "Remove sticker" : symbol == current ? "Sticker, chosen" : "Sticker")
        .accessibilityHint(editing ? "Takes it off this list. Anywhere you placed it keeps it" : purpose == .drawing ? "Puts it on the drawing"
                           : symbol == current ? "Takes it off the day" : "Puts it on the day")
    }
}

/// **New Sticker, from the host** (`StickerPicker.onNewSticker`): the photos,
/// then a sticker lifted out of the one chosen, handed back as its symbol.
/// Attached to the view the popover hangs from, so the photo picker is
/// presented by a view that stays on screen.
///
/// **The lift is shown, not waited through** (2026-10-06, the owner's
/// approved "labor illusion, done honestly"). It was a silent second
/// between choosing a photo and a sticker appearing. Now the photo comes up
/// with a light passing over it while the subject is cut out, and the
/// sticker steps forward out of it before it is put down. The work is real;
/// it is only made visible, and held to `shortest` so a fast lift still
/// reads as one.
struct StickerMaking: ViewModifier {
    @Binding var isPresented: Bool
    let onMade: (_ symbol: String) -> Void

    @State private var item: PhotosPickerItem?
    @State private var failed = false
    @State private var photo: UIImage?
    @State private var lifted: UIImage?
    @State private var showing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The least time the moment holds, and how long the sticker is shown
    /// before it is put down.
    static let shortest: Duration = .milliseconds(900)
    static let hold: Duration = .milliseconds(650)

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $item, matching: .images)
            .onChange(of: item) { _, picked in
                guard let picked else { return }
                item = nil
                Task { await make(from: picked) }
            }
            .fullScreenCover(isPresented: Binding(get: { photo != nil }, set: { if !$0 { photo = nil } })) {
                if let photo {
                    StickerLiftMoment(photo: photo, sticker: lifted, reduceMotion: reduceMotion)
                        .opacity(showing ? 1 : 0)
                        .presentationBackground(.clear)
                }
            }
            .alert("Couldn't find anything to lift", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try another photo.")
            }
            #if DEBUG
            .task {
                guard DebugHarness.stickerLiftDemo, let sample = StickerMaker.sample() else { return }
                try? await Task.sleep(for: .seconds(1.5))
                await play(StickerLiftMoment.demoPhoto(sample)) { _ in sample }
            }
            #endif
    }

    private func make(from picked: PhotosPickerItem) async {
        guard let data = try? await picked.loadTransferable(type: Data.self),
              let full = await ImageManager.downsampled(data, maxPixel: ImageManager.storedMaxDimension) else {
            HapticsEngine.warning()
            failed = true
            return
        }
        await play(full) { await StickerMaker.lift($0) }
    }

    /// The moment: the photo up, the lift running under the light, the
    /// sticker forward, then put down (or, with nothing to lift, the
    /// moment closes and says so).
    private func play(_ full: UIImage, lift: @escaping (UIImage) async -> UIImage?) async {
        lifted = nil
        photo = full.preparingThumbnail(of: Self.fitted(full.size, within: 900)) ?? full
        // The lift starts at once; the photo shows once the cover has risen
        // invisibly (its own slide cannot be turned off from here, measured:
        // `disablesAnimations` did not stop it), and the moment holds for
        // `shortest` from then, so the light is always seen.
        let lifting = Task { await lift(full) }
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(GridConstants.momentIn) { showing = true }
        let shown = ContinuousClock.now
        let sticker = await lifting.value
        let spent = ContinuousClock.now - shown
        if spent < Self.shortest { try? await Task.sleep(for: Self.shortest - spent) }
        guard let sticker, let name = StickerStore.shared.add(sticker) else {
            await close()
            HapticsEngine.warning()
            failed = true
            return
        }
        HapticsEngine.success()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.stickerStep) {
            lifted = sticker
        }
        try? await Task.sleep(for: Self.hold)
        await close()
        onMade(StickerStore.symbol(for: name))
    }

    private func close() async {
        withAnimation(GridConstants.cueOut) { showing = false }
        try? await Task.sleep(for: .milliseconds(220))
        photo = nil
        lifted = nil
    }

    static func fitted(_ size: CGSize, within side: CGFloat) -> CGSize {
        let k = min(1, side / max(size.width, size.height, 1))
        return CGSize(width: size.width * k, height: size.height * k)
    }
}

/// The photo while its subject is lifted, then the sticker stepping out.
struct StickerLiftMoment: View {
    let photo: UIImage
    let sticker: UIImage?
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            // The page dimmed behind it, as a sheet's is.
            Color.black.opacity(0.5).ignoresSafeArea()
            ZStack {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
                    .overlay {
                        if sticker == nil && !reduceMotion { sweep }
                    }
                    .opacity(sticker == nil ? 1 : 0)
                    .scaleEffect(sticker == nil ? 1 : 0.96)
                if let sticker {
                    Image(uiImage: sticker)
                        .resizable()
                        .scaledToFit()
                        .padding(GridConstants.gapItem)
                        .transition(.scale(scale: reduceMotion ? 1 : 0.82).combined(with: .opacity))
                }
            }
            .frame(maxWidth: 300, maxHeight: 400)
            .padding(GridConstants.horizontalPadding)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sticker == nil ? "Making a sticker" : "Sticker made")
    }

    /// A band of light crossing the photo, left to right, again and again:
    /// the subject being found. Masked to the photo's own shape.
    private var sweep: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: 1.3)) / 1.3
            GeometryReader { geo in
                let w = geo.size.width
                // Taller than the photo, so tilting it never shows its ends.
                LinearGradient(stops: [.init(color: .white.opacity(0), location: 0),
                                       .init(color: .white.opacity(0.32), location: 0.5),
                                       .init(color: .white.opacity(0), location: 1)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: w * 0.4, height: geo.size.height * 1.6)
                    .rotationEffect(.degrees(12))
                    .position(x: -w * 0.3 + phase * w * 1.6, y: geo.size.height / 2)
                    .blendMode(.plusLighter)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    #if DEBUG
    /// A stand-in photograph for the demo: the sample on a meadow-ish ground.
    static func demoPhoto(_ sample: UIImage) -> UIImage {
        let size = CGSize(width: 600, height: 760)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.62, green: 0.74, blue: 0.86, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.44, green: 0.62, blue: 0.36, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 470, width: 600, height: 290))
            sample.draw(in: CGRect(x: 110, y: 200, width: 380, height: 380))
        }
    }
    #endif
}

extension View {
    func stickerMaking(isPresented: Binding<Bool>, onMade: @escaping (_ symbol: String) -> Void) -> some View {
        modifier(StickerMaking(isPresented: isPresented, onMade: onMade))
    }
}
