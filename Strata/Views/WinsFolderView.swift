import SwiftUI

/// **The Wins screen: a folder where the tower was.**
///
/// The owner: "remember this is replacing the wins tower, so make sure it
/// comes with all the features the tower had. Make sure it's a clean
/// effortless replacement and it doesn't ruin the rest of the app we built."
///
/// So this is deliberately a SWAP rather than a rewrite. Everything around
/// the tower stays exactly as it was and is not touched: the header with the
/// count and the Plan button, the replay pill, the add sheet, the edit sheet,
/// the plan sheet, the ground. `MainAppView` is already at the type checker's
/// ceiling — its own comments say so in four places — so it gains one line
/// and no state.
///
/// **What the tower did that this carries.** It showed today's wins and only
/// today's, which the owner asked to keep: "that's how the tower was designed
/// and I liked that because the focus was staying more in the presence." It
/// drew a win with no photograph as a plain coloured block, which
/// `ScatterWin` still does. And tapping a win opened the sheet that made it,
/// which is `onOpenWin` here, handed straight back to the same binding the
/// tower used.
///
/// **What it does not carry yet, and this is the honest list.** The outlined
/// blocks for habits planned but not yet done, which come from a different
/// array and want a design of their own rather than an empty card. The
/// tower's drop animation when a win lands. Long press to edit, which needs
/// to not fight the press-to-lift the scatter uses.
struct WinsFolderView: View {
    /// The same blocks the tower was given, so nothing upstream changes.
    var blocks: [PlacedBlock]
    var title: String = "Today"
    var tint: Color = WinFolder.defaultTint
    var onOpenWin: (UUID) -> Void = { _ in }

    @State private var isOpen = false
    @State private var openness: Double = 0
    @State private var photos: [String: UIImage] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// **The photographs come through `ImageManager`, not off the disk.**
    /// It is the app's bounded, cached, off-main decode path, and going round
    /// it is what froze the app the last time somebody did. 640 is the tier
    /// baked beside every original and is bigger than any card is drawn.
    private func loadPhotos() async {
        var loaded: [String: UIImage] = [:]
        for block in blocks {
            guard let name = block.look.imageFileName else { continue }
            if let image = await ImageManager.shared.loadThumbnail(
                fileName: name, maxWidth: 640) {
                loaded[block.id.uuidString] = image
            }
        }
        photos = loaded
    }

    private var wins: [ScatterWin] {
        blocks.map { block in
            ScatterWin(id: block.id.uuidString,
                       image: photos[block.id.uuidString],
                       size: block.look.blockSize,
                       title: block.look.title,
                       colour: block.look.displayCategory.style.baseColor)
        }
    }

    /// The folder falls open and the wins arrive in one movement rather than
    /// two, which is why the number is shared rather than each side having
    /// its own.
    private static let hinge = Animation.spring(response: 0.5, dampingFraction: 0.82)

    var body: some View {
        ZStack {
            folder
                .opacity(isOpen ? 0 : 1)
                .allowsHitTesting(!isOpen)

            if isOpen {
                FolderInside(title: title, wins: wins, tint: tint,
                             onClose: close,
                             onOpenWin: { id in
                                 if let uuid = UUID(uuidString: id) { onOpenWin(uuid) }
                             },
                             // The Wins screen's own header already says what
                             // this is and how many are in it.
                             showsTitle: false,
                             bottomInset: 96)
                    .transition(.opacity)
            }
        }
        .task(id: blocks.map(\.id)) { await loadPhotos() }
    }

    private var folder: some View {
        VStack {
            Spacer(minLength: 0)
            WinFolder(title: title, count: wins.count, tint: tint,
                      contents: wins,
                      expression: wins.isEmpty ? .sleepy : .idle,
                      isAlive: true,
                      openness: openness)
                .frame(maxWidth: 280)
                .contentShape(Rectangle())
                .onTapGesture { open() }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens today's wins")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func open() {
        HapticsEngine.lightTap()
        guard !reduceMotion else { isOpen = true; openness = 1; return }
        withAnimation(Self.hinge) { openness = 1 }
        // The inside arrives while the pocket is still falling, so the two
        // read as one movement. Waiting for the hinge to finish first makes
        // it two animations played in a row, which is the difference between
        // opening something and watching two things happen.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.22)) { isOpen = true }
        }
    }

    private func close() {
        HapticsEngine.lightTap()
        guard !reduceMotion else { isOpen = false; openness = 0; return }
        withAnimation(.easeIn(duration: 0.16)) { isOpen = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(Self.hinge) { openness = 0 }
        }
    }
}
