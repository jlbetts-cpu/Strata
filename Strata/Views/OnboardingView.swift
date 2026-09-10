import SwiftUI

/// The first two minutes.
///
/// **Each screen is in the register of the thing it introduces.** The tower
/// pages stand on `WarmBackground`; the camera page is the near-black room the
/// camera actually is, with the wordmark where the wordmark actually goes; the
/// map page is a real `MemoriesMapView` with real blocks on it. Nothing here is
/// a picture OF the app drawn on a neutral card — the app has three tabs and
/// this walks through all three in their own light.
///
/// That is the correction to the first version, and the owner listed every
/// fault in it: the app icon dropped in at the top for no reason, four
/// identical SMALL blocks that showed neither what a block is nor what a tower
/// looks like, a button that belonged to no design system, a tutorial that was
/// wrong about the app, and no mention of the camera or the map — "which I feel
/// are big parts of the app". They are; they are two of the three tabs.
///
/// **Not a funnel.** The published frameworks are fourteen screens ending in a
/// paywall. Strata has no account and no subscription. Two ideas from them
/// survive: the interactive demo is the most important screen and must be built
/// from real components, and the copy should sound like a person.
struct OnboardingView: View {

    var onFinish: () -> Void

    @State private var step = 0
    @State private var landed = 0
    /// What the tutorial has actually watched the finger do.
    @State private var hasDrawn = false
    @State private var madeBlocks: [BlockSize] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    #if DEBUG
    private static let debugStep = DebugHarness.onboardingStep
    #endif

    private static let lastStep = 4
    private static let cell: CGFloat = 58

    var body: some View {
        ZStack {
            ground
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                stage
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

    // MARK: - Ground

    /// The room each page is standing in.
    @ViewBuilder
    private var ground: some View {
        switch step {
        case 1:
            // The camera is a dark room whatever the phone is set to — the
            // same rule the real tab follows.
            AppColors.warmBlack.ignoresSafeArea()
        case 2:
            MemoriesMapView(pins: Self.demoPins, isInteractive: false, style: .quiet)
                .ignoresSafeArea()
                .overlay {
                    // **Heavier than the map's own title wash, and it has to
                    // be.** That one holds up two words at the very top of the
                    // screen; this one holds up a paragraph over the busiest
                    // part of a city map, where street names and park labels
                    // run straight under the type. Photographed at 0.62 the
                    // copy was unreadable.
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: AppColors.warmBlack.opacity(0.55), location: 0.45),
                            .init(color: AppColors.warmBlack.opacity(0.92), location: 0.72),
                            .init(color: AppColors.warmBlack.opacity(0.96), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
        default:
            WarmBackground().ignoresSafeArea()
        }
    }

    /// Whether this page's words are standing on a dark ground.
    private var onDark: Bool { step == 1 || step == 2 }

    // MARK: - Stage

    @ViewBuilder
    private var stage: some View {
        switch step {
        case 0: tower
        case 1: camera
        case 2: Color.clear.frame(height: 1)
        case 3: workshop
        default: thanks
        }
    }

    // MARK: - The tower

    /// Real sizes, real colours, packed by the real packer.
    ///
    /// The first version put four identical 1x1s in a row, which showed
    /// neither the thing that makes a block a block — that it has a SIZE — nor
    /// what a tower looks like. `GridPacker.firstFit` is the same first-fit
    /// scan the tower itself uses, so this is not an arrangement that looks
    /// like the app's: it is the app's.
    private static let demo: [(size: BlockSize, category: HabitCategory)] = [
        (.medium, .health), (.small, .work), (.hard, .mindfulness),
        (.small, .social), (.medium, .creativity), (.small, .focus),
        (.small, .health)
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

    private var tower: some View {
        let gutter = GridConstants.spacing
        let rows = Self.packed.map { $0.r + $0.h }.max() ?? 1
        let height = CGFloat(rows) * Self.cell + CGFloat(rows - 1) * gutter
        let columns = CGFloat(GridConstants.columnCount)
        let width = columns * Self.cell + (columns - 1) * gutter

        return ZStack(alignment: .bottomLeading) {
            ForEach(Array(Self.packed.enumerated()), id: \.offset) { index, item in
                block(item.category, columns: item.w, rows: item.h)
                    .offset(x: CGFloat(item.c) * (Self.cell + gutter),
                            y: -CGFloat(item.r) * (Self.cell + gutter)
                                + (landed > index ? 0 : -520))
                    .opacity(landed > index ? 1 : 0)
            }
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
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
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 90 : 165))
        }
    }

    /// `t = sqrt(2d/g)`, clamped the way the tower clamps it. Constant
    /// acceleration, no ease out — a falling object does not decelerate into
    /// the ground.
    private var fallSeconds: Double {
        let t = (2 * 520 / GridConstants.dropGravity).squareRoot()
        return min(max(Double(t), GridConstants.dropDurationRange.lowerBound),
                   GridConstants.dropDurationRange.upperBound)
    }

    // MARK: - The camera

    /// A still of the camera tab, in its own light.
    ///
    /// The wordmark at the top and the shutter below are where the real screen
    /// puts them, and the rounded square inside the ring is the footprint the
    /// real shutter draws while you pull a size out of it — which is the whole
    /// point being made here: the camera makes blocks too.
    private var camera: some View {
        VStack(spacing: GridConstants.gapSection) {
            StrataWordmark(size: 32, color: .white)
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.92), lineWidth: 3)
                    .frame(width: 92, height: 92)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white)
                    .frame(width: 62, height: 62)
            }
        }
    }

    // MARK: - The map

    /// Enough pins to look like somebody's map rather than a demo.
    ///
    /// Real `PlaceMap.Pin`s, so the real clusterer sizes and places them: what
    /// you see here is what your own map will do.
    private static let demoPins: [PlaceMap.Pin] = {
        let hubs: [(Double, Double, Int, HabitCategory)] = [
            (51.5074, -0.1278, 9, .health),
            (51.5155, -0.1410, 4, .work),
            (51.4975, -0.1357, 2, .mindfulness),
            (51.5210, -0.1180, 6, .creativity)
        ]
        var pins: [PlaceMap.Pin] = []
        for (lat, lon, count, category) in hubs {
            for i in 0..<count {
                pins.append(PlaceMap.Pin(
                    dateString: "2026-09-0\((i % 9) + 1)",
                    completedAt: Date().addingTimeInterval(-Double(i) * 3600),
                    title: "Win",
                    category: category,
                    // Deliberately empty: these are illustrative places, not
                    // photographs, and a name that resolves to nothing draws a
                    // broken-picture glyph. The blocks are their colour here.
                    photoFileName: "",
                    place: WinPlace(latitude: lat + Double(i) * 0.0006,
                                    longitude: lon + Double(i) * 0.0004,
                                    accuracy: 20)
                ))
            }
        }
        return pins
    }()

    // MARK: - The tutorial

    /// **The real control, taught accurately.**
    ///
    /// The first version was wrong about the app: it treated a TAP as the way
    /// to make a block. In the tower a tap opens the add form (`onOpenMenu` ->
    /// `winDraft`) and only a DRAW logs a block directly (`action` ->
    /// `logWin`). So the lesson is the draw, the copy says what a tap does
    /// instead, and the page will not let you past until a block has actually
    /// been drawn OUT — which is the difference between a tutorial and a
    /// slideshow.
    private var workshop: some View {
        VStack(spacing: GridConstants.gapItem) {
            ZStack(alignment: .bottomLeading) {
                ForEach(Array(madeBlocks.enumerated()), id: \.offset) { index, size in
                    block(Self.demo[index % Self.demo.count].category,
                          columns: size.columnSpan, rows: size.rowSpan)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .frame(width: Self.cell * 2 + GridConstants.spacing,
                   height: Self.cell * 2 + GridConstants.spacing,
                   alignment: .bottomLeading)

            NextSlotButton(
                reduceMotion: reduceMotion,
                cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
                previewCategory: .mindfulness,
                onSizeChanged: { _ in },
                action: { size in
                    withAnimation(GridConstants.dropSettleSpring) { madeBlocks = [size] }
                    if size != .small { hasDrawn = true }
                    HapticsEngine.success()
                },
                // In the app this opens the add form. There is no form to open
                // here, so it answers with the same tap it would there.
                onOpenMenu: { HapticsEngine.lightTap() }
            )
            .frame(width: Self.cell, height: Self.cell)
        }
    }

    // MARK: - The thank you

    /// **A person, not a brand.** The owner's first app, so it is first
    /// person, and it makes one offer rather than three. No rating prompt and
    /// no share sheet: asking for something on the screen where you are
    /// thanking somebody turns the thank you into a transaction.
    private var thanks: some View {
        VStack(spacing: GridConstants.gapItem) {
            Image("CreatorPortrait")
                .resizable()
                .scaledToFill()
                .frame(width: 128, height: 128)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(AppColors.inkQuiet.opacity(0.25), lineWidth: 1) }
                .shadow(color: .black.opacity(GridConstants.shadowOpacity), radius: 10, y: 4)
                .accessibilityLabel("Jayden, who made Strata")
            Text("Jayden")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.9))
        }
    }

    /// Where to find him. **Empty until it is filled in**, and the button is
    /// not drawn while it is: a dead link on the screen that asks somebody to
    /// get in touch is worse than not asking.
    private static let linkedIn = ""

    @ViewBuilder
    private var connectButton: some View {
        if !Self.linkedIn.isEmpty, let url = URL(string: Self.linkedIn) {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Connect on LinkedIn")
                }
                .font(Typography.headerMedium)
                .foregroundStyle(.primary.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                        .fill(AppColors.inkQuiet.opacity(0.14))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Words

    private var words: some View {
        VStack(spacing: GridConstants.gapTight) {
            Text(title)
                .font(Typography.headerLarge)
                .foregroundStyle(onDark ? Color.white : Color.primary.opacity(0.9))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(Typography.bodyMedium)
                .foregroundStyle(onDark ? Color.white.opacity(0.78) : AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, GridConstants.gapItem)
        .padding(.bottom, GridConstants.gapSection)
    }

    private var title: String {
        switch step {
        case 0: return "Everything you did, stacked up"
        case 1: return "A win can be a photograph"
        case 2: return "It remembers where you were"
        case 3: return hasDrawn ? "That's the whole app" : "Draw your first block"
        default: return "Thank you, genuinely"
        }
    }

    private var subtitle: String {
        switch step {
        case 0:
            return "Finish something and it becomes a block. Bigger things make bigger blocks, and they stack up into a tower you can actually look at."
        case 1:
            return "Take it in Strata and the picture becomes the block. Pull the shutter sideways or up first to say how big the win was."
        case 2:
            return "Photographed wins land where you took them, so the map fills in with the places you did things."
        case 3:
            return hasDrawn
                ? "Everything else in Strata is looking back at what you built."
                : "Press and hold the slot, then pull sideways for a wide block or up for a tall one. Let go and it drops in. A quick tap opens the full form instead, for naming it."
        default:
            return "Strata is the first app I've made, and you're one of the first people to open it. That means a lot. If you find a bug, want something added, or just fancy saying hello, I'd really like to hear from you."
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: GridConstants.gapTight) {
            if step == Self.lastStep { connectButton }

            Button {
                HapticsEngine.lightTap()
                advance()
            } label: {
                actionLabel
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.4)
            .animation(GridConstants.gentleReveal, value: canAdvance)

            // A way out that does not pretend to be anything else.
            Button("Skip") {
                HapticsEngine.lightTap()
                onFinish()
            }
            .font(Typography.bodySmall)
            .foregroundStyle(onDark ? Color.white.opacity(0.55) : AppColors.inkQuiet)
            .opacity(step < Self.lastStep ? 1 : 0)
        }
    }

    /// **A block, because that is what this app's surfaces are.**
    ///
    /// The first version used a plain filled rectangle, which is every app's
    /// button and none of this one's — the owner's words: "I don't think the
    /// button is our design system." `BlockSurface` is the real thing, rim
    /// brightest along its top edge and the frosted band across its bottom
    /// 26%, so the control you press to get into Strata is made of the object
    /// Strata is made of.
    private var actionLabel: some View {
        Text(actionTitle)
            .font(Typography.headerMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                BlockSurface(cornerRadius: GridConstants.blockCornerRadius(forCell: 54),
                             scale: 54 / GridConstants.blockReferenceCell) {
                    HabitCategory.mindfulness.style.baseColor
                }
            }
    }

    private var canAdvance: Bool { step != 3 || hasDrawn }

    private var actionTitle: String {
        switch step {
        case 0: return "What else"
        case 1: return "Go on"
        case 2: return "Let me try"
        case 3: return "One more thing"
        default: return "Start"
        }
    }

    private func advance() {
        guard step < Self.lastStep else { onFinish(); return }
        withAnimation(GridConstants.naturalSettle) { step += 1 }
    }

    // MARK: - Drawing

    private func block(_ category: HabitCategory, columns: Int, rows: Int) -> some View {
        let gutter = GridConstants.spacing
        let width = Self.cell * CGFloat(columns) + gutter * CGFloat(columns - 1)
        let height = Self.cell * CGFloat(rows) + gutter * CGFloat(rows - 1)
        return BlockSurface(
            cornerRadius: GridConstants.blockCornerRadius(forCell: Self.cell),
            scale: Self.cell / GridConstants.blockReferenceCell
        ) {
            category.style.baseColor
        }
        .frame(width: width, height: height)
    }
}
