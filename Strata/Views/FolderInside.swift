import SwiftUI

/// One win, as it sits in the folder.
struct ScatterWin: Identifiable, Equatable {
    var id: String
    var image: UIImage
    var size: BlockSize
    static func == (a: ScatterWin, b: ScatterWin) -> Bool { a.id == b.id && a.size == b.size }
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
struct FolderInside: View {
    var title: String
    var wins: [ScatterWin]
    var tint: Color = WinFolder.defaultTint
    var onClose: () -> Void = {}

    @State private var pressed: String?
    @State private var tidy = false
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
        .task {
            guard !reduceMotion else { arrived = true; return }
            // The cards do not fade in, they ARRIVE: the folder has just
            // been opened and they are coming out of it.
            withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
                arrived = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapTight) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.screenTitle)
                    .foregroundStyle(.white)
                Text("\(wins.count) \(wins.count == 1 ? "win" : "wins")")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Grey.g400)
            }
            Spacer()
            // **Organise, which is a view and not a change.** It does not
            // move anything permanently: the scatter is where the wins live
            // and this is a way of reading them, so it is a toggle rather
            // than an action with consequences. Both layouts come out of one
            // function, so every card glides between them.
            GlassIconButton(systemName: tidy ? "square.grid.2x2.fill" : "square.grid.2x2",
                            tint: .white,
                            accessibilityLabel: tidy ? "Back to the scatter" : "Organise") {
                // No `withAnimation` here on purpose: the cards carry their
                // own, with a stagger, so this cannot animate them as one
                // block. An animation declared at the value it belongs to
                // also cannot be forgotten by a second caller later.
                tidy.toggle()
            }
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
                in: width, tidy: tidy)
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
                // The page is taller organised than scattered. Without this
                // the height cuts to its new value on the first frame and
                // the whole scroll jolts under cards that are still moving.
                .animation(.spring(response: 0.55, dampingFraction: 0.84), value: tidy)
                .padding(.horizontal, GridConstants.gapWide)
                .padding(.bottom, 80)
            }
        }
    }

    private func card(_ win: ScatterWin, spot: ScatterLayout.Placement, index: Int) -> some View {
        let isPressed = pressed == win.id
        let radius = spot.frame.width * 0.085
        return Image(uiImage: win.image)
            .resizable()
            .scaledToFill()
            .frame(width: spot.frame.width, height: spot.frame.height)
            // **No white border.** The owner: "I don't like the random outline
            // we added for the photos, I don't think we need that." It was a
            // polaroid idea applied to something that is not a polaroid, and
            // on a dark ground a white frame is the loudest thing on screen:
            // the eye goes to the border rather than to the photograph. The
            // shadow is what separates a card from the ground, and it is
            // enough.
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            // The one shadow, and it is the card standing off the ground
            // rather than chrome floating. It grows under a finger, which is
            // most of what makes the press feel like lifting something.
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
            // **Organising is a ripple, not a cut.**
            //
            // Every card moving at the same instant reads as the screen
            // being replaced; a small stagger reads as a hand tidying a
            // stack. 16ms apart is under a frame each, so twelve cards are
            // spread across about a fifth of a second and nothing feels
            // like it is waiting.
            //
            // One spring for the position, the size and the lean together,
            // because they are one movement: a card straightens as it
            // travels rather than arriving and then straightening.
            .animation(.spring(response: 0.55, dampingFraction: 0.84)
                        .delay(Double(index) * 0.016), value: tidy)
            .animation(GridConstants.motionSnappy, value: isPressed)
            // **Touch down, not tap.** The lift happens while the finger is
            // still deciding, which is the whole difference.
            .onLongPressGesture(minimumDuration: 6, maximumDistance: 40) {
            } onPressingChanged: { down in
                pressed = down ? win.id : nil
                if down { HapticsEngine.lightTap() }
            }
            .accessibilityLabel("Win \(index + 1) of \(wins.count)")
    }
}
