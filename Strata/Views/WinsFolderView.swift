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
    /// **Told to the screen, so its header can get out of the way.** The
    /// owner: "inside the folder there isn't a need for the top header with
    /// + and Plan buttons, it just looks weird in there." They belong to the
    /// day, not to what is inside the folder.
    @Binding var isOpenExternally: Bool

    /// **The folder's own face, drifting.** It was handed a fixed expression,
    /// so it wore one face for the life of the screen — the owner: "it should
    /// switch eyes naturally, not keep the same eyes and then never change."
    /// `FolderMood` owns the resting drift and the reactions.
    @State private var mood = FolderMood()
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

    /// **Newest on top.** The owner's call, and it is the right default for
    /// a folder of today: the thing you just did is the thing you want to
    /// see, and the tower put new blocks at the top for the same reason.
    private var wins: [ScatterWin] {
        blocks.reversed().map { block in
            ScatterWin(id: block.id.uuidString,
                       image: photos[block.id.uuidString],
                       size: block.look.blockSize,
                       title: block.look.title,
                       colour: block.look.displayCategory.style.baseColor)
        }
    }

    /// **Opening is going IN, not the folder coming at you.**
    ///
    /// The first version hinged the pocket forward on its bottom edge with
    /// perspective, which is what a real folder does and which the owner read
    /// immediately as wrong: "the opening animation doesn't look good, like
    /// it's a folder, why is it pushing in." A face rotating towards the
    /// viewer under perspective reads as being PRESSED, not opened, and on a
    /// screen there is no depth cue to say otherwise.
    ///
    /// What reads as opening a container on a phone is the container growing
    /// past you while its contents arrive: the folder scales up and fades as
    /// though you are moving into it, and the wins come up from where it was.
    /// No rotation at all, because the thing that looked wrong was the
    /// rotation.
    private static let hinge = Animation.spring(response: 0.5, dampingFraction: 0.82)

    var body: some View {
        ZStack {
            folder
                .scaleEffect(1 + 0.22 * openness)
                .opacity(1 - openness)
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
        // The face reads the contents, so it knows when the folder is empty
        // and when a win has just gone in.
        .onChange(of: blocks.count) { old, new in
            mood.contents = FolderContents(count: new)
            if new > old { mood.react(to: .winAdded) }
        }
        .onAppear { mood.contents = FolderContents(count: blocks.count) }
        .onDisappear { mood.stopDrifting() }
    }

    private var folder: some View {
        VStack {
            Spacer(minLength: 0)
            WinFolder(title: title, count: wins.count, tint: tint,
                      contents: wins,
                      expression: mood.expression,
                      isAlive: true)
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
        mood.react(to: .opened)
        guard !reduceMotion else { isOpen = true; openness = 1; isOpenExternally = true; return }
        isOpenExternally = true
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
        guard !reduceMotion else { isOpen = false; openness = 0; isOpenExternally = false; return }
        isOpenExternally = false
        withAnimation(.easeIn(duration: 0.16)) { isOpen = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(Self.hinge) { openness = 0 }
        }
    }
}
