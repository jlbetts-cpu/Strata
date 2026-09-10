import SwiftUI

/// The first two minutes.
///
/// **Every page is full-bleed and stands in the register of what it
/// introduces.** The tower pages on `WarmBackground`, the camera page inside a
/// real viewfinder, the map page on a real `MemoriesMapView`. Nothing is a
/// picture of the app drawn on a card — the owner's note after seeing the map
/// page was "I love how the maps screen takes up the whole screen, more of the
/// screens should be like that", and he is right: an app that opens by filling
/// the display reads as confident, and one that opens with a small illustration
/// in the middle of a lot of nothing does not.
///
/// **Read it, don't skim it.** Each page gets one line of title and at most two
/// of body. The earlier version ran to four and nobody would have read them.
struct OnboardingView: View {

    var onFinish: () -> Void

    @State private var step = 0
    @State private var landed = 0
    /// What the tutorial has actually watched the finger do.
    @State private var hasDrawn = false
    /// The tutorial's own tower, and the grid it is packed into — the same
    /// two things `TowerViewModel` keeps.
    @State private var built: [(c: Int, r: Int, w: Int, h: Int, category: HabitCategory)] = []
    @State private var grid: [[Bool]] = []
    /// The size the finger is drawing right now. The slot grows with it,
    /// exactly as the tower's does.
    @State private var drawingSize: BlockSize = .small
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var location = LocationService.shared

    #if DEBUG
    private static let debugStep = DebugHarness.onboardingStep
    #endif

    private static let lastStep = 4
    private static let cell: CGFloat = 74
    private static let slotCell: CGFloat = 84

    var body: some View {
        ZStack {
            stage.ignoresSafeArea()
            scrim
            VStack(spacing: 0) {
                // Not on the camera page: that screenshot has the real
                // wordmark in it already, and two would be one too many.
                StrataWordmark(size: 26, color: onDark ? .white : .primary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, GridConstants.gapItem)
                    .opacity(step == 2 ? 0 : 1)
                Spacer(minLength: 0)
                words
                actions
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.bottom, GridConstants.gapSection)
        }
        .task {
            #if DEBUG
            if let start = Self.debugStep { step = start }
            #endif
            await runFall()
        }
    }

    /// Whether this page's words are standing on a dark ground.
    private var onDark: Bool { step == 2 || step == 3 }

    // MARK: - The stage

    /// Full-bleed, always. No page has a picture floating in the middle of it.
    @ViewBuilder
    private var stage: some View {
        switch step {
        case 0:
            ZStack { WarmBackground(); tower }
        case 1:
            ZStack { WarmBackground(); workshop }
        case 2:
            // **The whole screen, and nothing added.** The owner sent a frame
            // of the real camera — his sunset, his composition guides, his
            // focus box, the wordmark and the tab bar — and his instruction
            // was to show it: "the photo I sent of the camera is stunning,
            // just show that, dont need to show everything else." Two earlier
            // versions drew our own ring on it or cropped its chrome away.
            // Both were the same mistake: improving a photograph that did not
            // need improving.
            GeometryReader { geo in
                Image("DemoViewfinder")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        case 3:
            // **A photograph of the map, not a live one.** A real
            // `MemoriesMapView` here spins up MapKit and fetches tiles over
            // the network — the owner saw it: "make sure the map loads faster,
            // right now I noticed some loading issues; no need to load in an
            // entire map, just need a photo of the map." He is right, and it
            // is the same call as the camera page. Onboarding is not the place
            // to make somebody wait for a network round trip, and nothing here
            // is interactive anyway. The picture IS the real map with the real
            // clusterer and his real photographs on it — it was rendered by
            // the app and then captured.
            GeometryReader { geo in
                Image("DemoMap")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        default:
            ZStack { WarmBackground(); thanks }
        }
    }

    /// Enough darkness under the words to read them, and none above.
    @ViewBuilder
    private var scrim: some View {
        if onDark {
            LinearGradient(
                stops: [
                    .init(color: AppColors.warmBlack.opacity(0.45), location: 0.0),
                    .init(color: .clear, location: 0.22),
                    .init(color: AppColors.warmBlack.opacity(0.55), location: 0.55),
                    .init(color: AppColors.warmBlack.opacity(0.95), location: 0.80)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - The tower

    /// Which of the opening blocks carry a photograph.
    ///
    /// **Not all of them.** The owner asked for "some photos in some of the
    /// blocks on the first page, just to put in that human element" — some,
    /// and he is right that it is some. A tower of nothing but pictures is a
    /// photo grid; the point of this screen is that a block is a block whether
    /// or not it has a picture on it, and the mix says that in one look.
    private static let openingPhotos: [Int: String] = [
        0: "DemoPhoto5", 2: "DemoPhoto9", 4: "DemoPhoto2", 7: "DemoPhoto11"
    ]

    private static let demo: [(size: BlockSize, category: HabitCategory)] = [
        (.medium, .health), (.small, .work), (.hard, .mindfulness),
        (.small, .social), (.medium, .creativity), (.small, .focus),
        (.small, .health), (.medium, .work)
    ]

    private static let packed: [(c: Int, r: Int, w: Int, h: Int, category: HabitCategory)] = {
        var grid: [[Bool]] = []
        var out: [(c: Int, r: Int, w: Int, h: Int, category: HabitCategory)] = []
        for item in demo {
            let w = item.size.columnSpan
            let h = item.size.rowSpan
            guard let spot = GridPacker.firstFit(columnSpan: w, rowSpan: h, grid: &grid) else { continue }
            out.append((spot.column, spot.row, w, h, item.category))
        }
        return out
    }()

    /// Real sizes, real colours, placed by the real packer — the same
    /// first-fit scan the tower runs, so this is the app's arrangement rather
    /// than one that resembles it.
    private var tower: some View {
        let gutter = GridConstants.spacing
        let rows = Self.packed.map { $0.r + $0.h }.max() ?? 1
        let height = CGFloat(rows) * Self.cell + CGFloat(rows - 1) * gutter
        let columns = CGFloat(GridConstants.columnCount)
        let width = columns * Self.cell + (columns - 1) * gutter

        return ZStack(alignment: .bottomLeading) {
            ForEach(Array(Self.packed.enumerated()), id: \.offset) { index, item in
                block(item.category, columns: item.w, rows: item.h,
                      photo: Self.openingPhotos[index])
                    .offset(x: CGFloat(item.c) * (Self.cell + gutter),
                            y: -CGFloat(item.r) * (Self.cell + gutter)
                                + (landed > index ? 0 : -640))
                    .opacity(landed > index ? 1 : 0)
            }
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
        .offset(y: -60)
    }

    private func runFall() async {
        guard step == 0, landed == 0 else { return }
        try? await Task.sleep(for: .milliseconds(300))
        for index in Self.packed.indices {
            let fall = GridConstants.dropFallCurve.speed(1 / fallSeconds)
            withAnimation(reduceMotion ? GridConstants.gentleReveal : fall) {
                landed = index + 1
            }
            HapticsEngine.tick()
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 90 : 160))
        }
    }

    /// `t = sqrt(2d/g)`, clamped the way the tower clamps it. Constant
    /// acceleration, no ease out — a falling object does not decelerate into
    /// the ground.
    private var fallSeconds: Double {
        let t = (2 * 640 / GridConstants.dropGravity).squareRoot()
        return min(max(Double(t), GridConstants.dropDurationRange.lowerBound),
                   GridConstants.dropDurationRange.upperBound)
    }

    // MARK: - The camera

    // MARK: - The map

    /// The owner's own photographs, spread by a GLOBAL index rather than one
    /// that restarts inside each place — restarting is why the first version
    /// showed the same three pictures over and over.
    private static let demoPins: [PlaceMap.Pin] = {
        let hubs: [(Double, Double, Int, HabitCategory)] = [
            (51.5074, -0.1278, 5, .health),
            (51.5155, -0.1410, 3, .work),
            (51.4975, -0.1357, 2, .mindfulness),
            (51.5210, -0.1180, 4, .creativity)
        ]
        var pins: [PlaceMap.Pin] = []
        var n = 0
        for (lat, lon, count, category) in hubs {
            for i in 0..<count {
                n += 1
                pins.append(PlaceMap.Pin(
                    dateString: "2026-09-0\((n % 9) + 1)",
                    completedAt: Date().addingTimeInterval(-Double(n) * 3600),
                    title: "Win",
                    category: category,
                    photoFileName: "bundle:DemoPhoto\((n % 7) + 1)",
                    place: WinPlace(latitude: lat + Double(i) * 0.0007,
                                    longitude: lon + Double(i) * 0.0005,
                                    accuracy: 20)
                ))
            }
        }
        return pins
    }()

    // MARK: - The tutorial

    /// **The slot grows under the finger, exactly as the tower's does.**
    ///
    /// This was the owner's complaint twice over: "the resize hold block is
    /// still not resizing like it should, it should actually just act like the
    /// tower in the main app." It was pinned inside a fixed square frame, so
    /// `onSizeChanged` had nowhere to go and the ghost never grew — you were
    /// drawing a size you could not see. The tower drives its slot's frame
    /// from `drawingSize` and so does this, with no animation modifier on it,
    /// because `onSizeChanged` already arrives inside a `slotSnap`
    /// transaction and a second one would fight it.
    ///
    /// Accurate in the other direction too: in the tower a tap opens the add
    /// form and only a DRAW logs directly, so the lesson here is the draw.
    private var workshop: some View {
        let gutter = GridConstants.spacing
        let columns = CGFloat(GridConstants.columnCount)
        let width = columns * Self.cell + (columns - 1) * gutter
        let spot = ghostSpot
        let rows = max((built.map { $0.r + $0.h }.max() ?? 0),
                       (spot?.r ?? 0) + drawingSize.rowSpan)
        let height = CGFloat(max(rows, 2)) * Self.cell + CGFloat(max(rows, 2) - 1) * gutter

        return ZStack(alignment: .bottomLeading) {
            ForEach(Array(built.enumerated()), id: \.offset) { _, item in
                block(item.category, columns: item.w, rows: item.h)
                    .offset(x: CGFloat(item.c) * (Self.cell + gutter),
                            y: -CGFloat(item.r) * (Self.cell + gutter))
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            if let spot {
                NextSlotButton(
                    reduceMotion: reduceMotion,
                    cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
                    previewCategory: Self.tutorialColours[built.count % Self.tutorialColours.count],
                    onSizeChanged: { drawingSize = $0 },
                    action: { size in place(size) },
                    onOpenMenu: { HapticsEngine.lightTap() }
                )
                .frame(width: Self.cell * CGFloat(drawingSize.columnSpan)
                            + gutter * CGFloat(drawingSize.columnSpan - 1),
                       height: Self.cell * CGFloat(drawingSize.rowSpan)
                            + gutter * CGFloat(drawingSize.rowSpan - 1))
                .offset(x: CGFloat(spot.c) * (Self.cell + gutter),
                        y: -CGFloat(spot.r) * (Self.cell + gutter))
            }
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
        .offset(y: -50)
    }

    private static let tutorialColours: [HabitCategory] = [
        .mindfulness, .health, .creativity, .work, .social
    ]

    /// Where the slot is standing right now.
    ///
    /// **The same first-fit scan the tower runs**, against the blocks already
    /// placed and at the size the finger is currently drawing — so the ghost
    /// sits exactly where the block will land and MOVES as you change the
    /// size, which is what `TowerViewModel.computeGhostPosition` does in the
    /// app. The owner's note: "it doesn't actually show the tower being built,
    /// it's all centered, it doesn't build the same as it would in the app."
    /// It was one block centred over one slot; it is a tower now.
    private var ghostSpot: (c: Int, r: Int)? {
        var copy = grid
        guard let spot = GridPacker.firstFit(columnSpan: drawingSize.columnSpan,
                                             rowSpan: drawingSize.rowSpan,
                                             grid: &copy) else { return nil }
        return (spot.column, spot.row)
    }

    private func place(_ size: BlockSize) {
        var next = grid
        guard let spot = GridPacker.firstFit(columnSpan: size.columnSpan,
                                             rowSpan: size.rowSpan,
                                             grid: &next) else { return }
        let category = Self.tutorialColours[built.count % Self.tutorialColours.count]
        withAnimation(GridConstants.dropSettleSpring) {
            grid = next
            built.append((spot.column, spot.row, size.columnSpan, size.rowSpan, category))
        }
        drawingSize = .small
        if size != .small { hasDrawn = true }
        HapticsEngine.success()
    }

    // MARK: - The thank you

    /// **A person, not a brand.** The owner's first app, so it is first person
    /// and it makes one offer rather than three. No rating prompt and no share
    /// sheet: asking for something on the screen where you are thanking
    /// somebody turns the thank you into a transaction.
    private var thanks: some View {
        VStack(spacing: GridConstants.gapItem) {
            Image("CreatorPortrait")
                .resizable()
                .scaledToFill()
                .frame(width: 190, height: 190)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(AppColors.inkQuiet.opacity(0.22), lineWidth: 1) }
                .shadow(color: .black.opacity(GridConstants.shadowOpacity), radius: 14, y: 6)
                .accessibilityLabel("Jayden, who made Strata")

            VStack(spacing: 2) {
                Text("Jayden")
                    .font(Typography.headerLarge)
                    .foregroundStyle(.primary.opacity(0.9))
                Text("Founder, developer and product designer")
                    .font(Typography.bodySmall)
                    .foregroundStyle(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .offset(y: -40)
    }

    private static let linkedIn = "https://www.linkedin.com/in/jaydenbetts"

    private var connectButton: some View {
        Button {
            if let url = URL(string: Self.linkedIn) { openURL(url) }
        } label: {
            Text("Connect on LinkedIn")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(AppColors.slotInk)
    }

    // MARK: - Words

    private var words: some View {
        VStack(spacing: GridConstants.gapTight) {
            Text(title)
                .font(Typography.headerLarge)
                .foregroundStyle(onDark ? Color.white : Color.primary.opacity(0.92))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(Typography.bodyMedium)
                .foregroundStyle(onDark ? Color.white.opacity(0.82) : AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, GridConstants.gapItem)
        .padding(.bottom, GridConstants.gapSection)
    }

    private var title: String {
        switch step {
        case 0: return "Everything you did, stacked up"
        case 1: return hasDrawn ? "That's how every win is made" : "Small, medium or big"
        case 2: return "A win can be a photograph"
        case 3: return "It remembers where you were"
        default: return "Thank you, genuinely"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: return "Finish something and it becomes a block — small, medium or big, depending on the effort."
        case 1: return hasDrawn
            ? "A quick thing stays small. A real push earns a big one."
            : "Hold the empty slot and pull. The further you pull, the bigger the win. Let go to drop it in."
        case 2: return "Take it here and the picture becomes the block."
        case 3: return "Your wins land on the map where you took them."
        default: return "You're one of the first people to open my first app. If you find a bug or want something added, I'd love to hear from you."
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: GridConstants.gapTight) {
            if step == Self.lastStep { connectButton }

            // **A native button.** It was a `BlockSurface` — the app's own
            // object, which sounded right and looked like a slab. The owner:
            // "simplify the button, it shouldnt have the block styling, just
            // make it simple like an apple native button." A block is a win.
            // A button is not a win.
            Button {
                HapticsEngine.lightTap()
                advance()
            } label: {
                Text(actionTitle)
                    .fontWeight(.medium)
                    .foregroundStyle(WarmBackground.top)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            // **`slotInk`, not `accentWarm`.** The app's accent IS a warm
            // black, which is right on a light page and invisible on a dark
            // one — and in dark mode every page here has a dark ground, the
            // two photographs included. A primary action only has to be one
            // thing: the opposite of what it is standing on.
            .tint(AppColors.slotInk)
            .disabled(!canAdvance)

            Button("Skip") {
                HapticsEngine.lightTap()
                onFinish()
            }
            .font(Typography.bodySmall)
            .foregroundStyle(onDark ? Color.white.opacity(0.6) : AppColors.inkQuiet)
            .opacity(step < Self.lastStep ? 1 : 0)
        }
    }

    private var canAdvance: Bool { step != 1 || hasDrawn }

    private var actionTitle: String {
        switch step {
        case 0: return "Let me try"
        case 1: return "What else"
        case 2: return "Go on"
        case 3: return location.canAsk ? "Turn on places" : "One more thing"
        default: return "Start"
        }
    }

    private func advance() {
        // **The map page is where the asking belongs.**
        //
        // It is the one screen that has just explained what the permission is
        // for, which is the whole of Apple's guidance on priming: ask where
        // the answer is obvious, never at launch. Leaving the page is the
        // moment — the button says what it will do.
        if step == 3, location.canAsk {
            location.requestAccess()
        }
        guard step < Self.lastStep else { onFinish(); return }
        withAnimation(GridConstants.naturalSettle) { step += 1 }
    }

    // MARK: - Drawing

    private func block(_ category: HabitCategory, columns: Int, rows: Int,
                       photo: String? = nil) -> some View {
        let gutter = GridConstants.spacing
        let width = Self.cell * CGFloat(columns) + gutter * CGFloat(columns - 1)
        let height = Self.cell * CGFloat(rows) + gutter * CGFloat(rows - 1)
        return BlockSurface(
            cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
            scale: Self.cell / GridConstants.blockReferenceCell,
            // The photo blocks' own wash. A white veil at the block's usual
            // strength floors a photograph's luminance; the tower drops to
            // 0.06 for exactly this and so does the map.
            washOpacity: photo == nil ? GridConstants.blockScrimOpacity : 0.06
        ) {
            ZStack {
                category.style.baseColor
                if let photo {
                    Image(photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                }
            }
        }
        .frame(width: width, height: height)
    }
}
