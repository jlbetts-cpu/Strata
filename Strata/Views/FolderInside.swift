import SwiftUI

/// One win, as it sits in the folder.
struct ScatterWin: Identifiable, Equatable {
    var id: String
    /// **Optional, because not every win is a photograph.** The tower drew a
    /// win with no picture as a plain coloured block, and dropping that would
    /// lose every win somebody typed rather than shot. A card with no image
    /// is its colour and its title, which is exactly what the block was.
    var image: UIImage?
    var size: BlockSize
    var title: String = ""
    var colour: Color = WinFolder.defaultTint

    static func == (a: ScatterWin, b: ScatterWin) -> Bool {
        a.id == b.id && a.size == b.size && (a.image == nil) == (b.image == nil)
    }
}

/// **Inside the folder: organised clutter, and it is a phone.**
///
/// The owner: "hover state doesn't make sense because it's a phone, build the
/// animations like a phone."
///
/// He is right, and it is worth being explicit about what replaces it,
/// because "hover" is doing real work in every desktop reference and
/// something has to. A pointer has a state between NOT TOUCHING and
/// CHOOSING; a finger does not. What a phone has instead is:
///
/// - **Touch down**, which is the honest equivalent and the one used here: a
///   card lifts and its shadow spreads the moment a finger lands, before any
///   decision has been made, and settles back if the finger leaves. That is
///   hover, minus the pretending.
/// - **The press that becomes a hold**, which is where a card detaches and
///   can be carried.
/// - **Scroll position**, which is the phone's real hover: things wake as
///   they come into view rather than when something points at them.
///
/// So nothing here waits to be pointed at. Everything answers a finger.
///
/// **One layout, and the scattered one is gone.** There were two, and a
/// button to move between them. The owner, looking at both: "the unorganised
/// look still doesn't look good, I think we should just have the organised
/// version, newest on top." He is right and it is subtraction: a folder
/// somebody KEEPS is laid out, not dropped, and a toggle between two ways of
/// reading the same wins was a choice nobody asked to make. The lean, the
/// jitter and the tuck were all in service of the version that lost.
struct FolderInside: View {
    var title: String
    var wins: [ScatterWin]
    var tint: Color = WinFolder.defaultTint
    var onClose: () -> Void = {}
    var onOpenWin: (String) -> Void = { _ in }
    /// **Off when the screen already has a header.** On the Wins screen the
    /// count and the word sit in the top left, six points above where this
    /// was drawing them again, so opening the folder put "9 wins" on screen
    /// twice in two sizes. The controls stay; the labels go.
    var showsTitle: Bool = true
    /// Room for the tab bar, when there is one under this.
    var bottomInset: CGFloat = 0

    @State private var pressed: String?
    /// **Photographs at the size they are drawn, not the size they were
    /// taken.**
    ///
    /// The owner: "make sure the photo scroller isn't jittery, it is jittery
    /// on my end." It was, and this is why: every card held the FULL
    /// resolution image and asked SwiftUI to scale it down on every frame of
    /// the scroll. Twenty multi megapixel photographs resampled sixty times a
    /// second is not something any phone does smoothly, and it gets worse the
    /// better the camera is.
    ///
    /// Downsampled once, off the main actor, and kept. The app already has a
    /// derivative pipeline for exactly this — `ImageDerivatives` bakes 320
    /// and 640 tiers beside every original — and the real integration should
    /// read those rather than scaling here. This is the prototype's version
    /// of the same idea and it is the same fix.
    @State private var thumbs: [String: UIImage] = [:]
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Grey.g950.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                scatter
            }
        }
        .task(id: wins.map(\.id)) {
            await prepareThumbnails()
        }
        .task {
            guard !reduceMotion else { arrived = true; return }
            // The cards do not fade in, they ARRIVE: the folder has just
            // been opened and they are coming out of it.
            withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
                arrived = true
            }
        }
    }

    /// The widest a card is ever drawn is the full content width, so twice
    /// that in pixels covers every screen this runs on with a little over.
    private static let thumbnailSide: CGFloat = 840

    private func prepareThumbnails() async {
        let source = wins
        let made = await Task.detached(priority: .userInitiated) { () -> [String: UIImage] in
            var out: [String: UIImage] = [:]
            for win in source {
                guard let original = win.image else { continue }
                let side = max(original.size.width, original.size.height)
                guard side > FolderInside.thumbnailSide else { out[win.id] = original; continue }
                let scale = FolderInside.thumbnailSide / side
                let size = CGSize(width: original.size.width * scale,
                                  height: original.size.height * scale)
                let format = UIGraphicsImageRendererFormat.default()
                format.scale = 1
                format.opaque = true
                out[win.id] = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    original.draw(in: CGRect(origin: .zero, size: size))
                }
            }
            return out
        }.value
        thumbs = made
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapTight) {
            if showsTitle {
                VStack(alignment: .leading, spacing: 2) {
                    // The brand's own voice, the same as Home's. A day is
                    // named in a serif on the page and was named in a sans
                    // once you opened it, which is the sort of seam that
                    // makes an app feel assembled rather than designed.
                    Text(title)
                        .font(Typography.screenTitleSerif)
                        .tracking(-0.6)
                        .foregroundStyle(.white)
                    Text("\(wins.count) \(wins.count == 1 ? "win" : "wins")")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Grey.g400)
                }
            }
            Spacer()
            GlassIconButton(systemName: "xmark", tint: .white,
                            accessibilityLabel: "Close the folder", action: onClose)
        }
        .padding(.horizontal, GridConstants.gapWide)
        .padding(.bottom, GridConstants.gapWide)
    }

    private var scatter: some View {
        GeometryReader { geo in
            let width = geo.size.width - GridConstants.gapWide * 2
            let placed = ScatterLayout.place(
                wins.map { ScatterLayout.Item(id: $0.id, size: $0.size) },
                in: width, tidy: true)
            let byID = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0) })

            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(wins.enumerated()), id: \.element.id) { index, win in
                        if let spot = byID[win.id] {
                            card(win, spot: spot, index: index)
                        }
                    }
                }
                .frame(width: width, height: ScatterLayout.height(placed),
                       alignment: .topLeading)
                .padding(.horizontal, GridConstants.gapWide)
                // **The caller's inset, not a guessed 80.** `bottomInset`
                // was declared, documented as "room for the tab bar, when
                // there is one under this", and then never read — so the
                // last card ran under the bar whatever the caller passed.
                // Photographed on Home, where the bar is 96.
                .padding(.bottom, max(bottomInset, 24) + GridConstants.gapWide)
            }
        }
    }

    private func card(_ win: ScatterWin, spot: ScatterLayout.Placement, index: Int) -> some View {
        let isPressed = pressed == win.id
        // The corner and the edge come from `PhotoFinish` now, so nothing
        // here decides either.
        return WinCardFace(win: win, image: thumbs[win.id] ?? win.image)
            .frame(width: spot.frame.width, height: spot.frame.height)
            // The one shadow, and it is the card standing off the ground
            // rather than chrome floating. It grows under a finger, which is
            // most of what makes the press feel like lifting something.
            // Flattened before the shadow: without this SwiftUI shadows the
            // live image every frame, which is the other half of why a
            // scroll full of these stutters.
            .compositingGroup()
            .shadow(color: .black.opacity(isPressed ? 0.55 : 0.34),
                    radius: isPressed ? 22 : 10,
                    y: isPressed ? 12 : 5)
            .rotationEffect(.degrees(spot.angle))
            .scaleEffect(isPressed ? 1.055 : 1)
            .zIndex(isPressed ? 100 : Double(index))
            .position(x: spot.frame.midX, y: spot.frame.midY)
            // Out of the folder, one after another, nearest first.
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived ? 0 : 26)
            .animation(.spring(response: 0.5, dampingFraction: 0.8)
                        .delay(Double(index) * 0.022), value: arrived)
            .animation(GridConstants.motionSnappy, value: isPressed)
            // **Touch down, not tap.** The lift happens while the finger is
            // still deciding, which is the whole difference.
            .onLongPressGesture(minimumDuration: 6, maximumDistance: 40) {
            } onPressingChanged: { down in
                pressed = down ? win.id : nil
                if down { HapticsEngine.lightTap() }
            }
            // The tap opens the win, which is the same sheet the tower's
            // blocks opened. Separate from the press feedback above so a
            // finger that slides off lifts the card back without opening it.
            .onTapGesture { onOpenWin(win.id) }
            .accessibilityLabel("Win \(index + 1) of \(wins.count)")
    }
}
