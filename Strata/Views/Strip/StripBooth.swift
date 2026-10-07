import SwiftUI

/// **The booth: the strip's own screen** (spec:
/// `docs/superpowers/specs/2026-10-06-photo-strip-booth.md`).
///
/// The owner: "the print out animation needs to really be a selling point
/// with the shake to reveal ... I want it so you are able to rotate it around
/// like a physical photo strip, I want it to feel as real as possible like
/// you really have it."
///
/// 1. **The print.** A glass printer across the top; the strip steps out of
///    its slot a frame at a time, a tap of the haptic each, undeveloped.
/// 2. **It drops free** and settles in the middle, turned a touch, as a strip
///    taken from a booth is held.
/// 3. **Shake to develop.** Each shake (or tap) lifts the dark and the blur a
///    step; developed, a success tap and the tools arrive.
/// 4. **In the hand, as a card** (2026-10-07: "Pokemon TCG level card
///    movement and look, how it genuinely looks like a card"). It leans
///    toward a pressing finger and follows it, sways a little with the phone
///    (`CardTilt`), is lit as a studio lights a sheet, a soft key light
///    sliding with the turn and a faint shade on the far side, shows a sliver of its edge, and casts a soft shadow on the ground
///    that moves as it turns. Drawn far across it turns over to its back,
///    stamped with the mark and the day; let go, it springs back with give.
struct StripBooth: View {
    let owner: PhotoStrip.Owner
    var day: String = DateUtils.dateString(from: Date())
    /// Print it now (the goal was just reached), rather than open on it.
    var prints = false
    /// Whether it may develop yet: yours develops at the goal, a crew's
    /// whenever it is opened. Asked at the shake, not at the opening, so a
    /// win that lands while the booth is open counts.
    var canDevelop: () -> Bool = { true }
    let load: () async -> PhotoStrip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var space

    @State private var strip: PhotoStrip?
    @State private var excluded: Set<UUID> = []
    @State private var paper = StripKeeping.paper
    @State private var decor: InkPicture?
    @State private var stage = Stage.loading
    /// How much of the strip is out of the printer, 0 to 1.
    @State private var printed: CGFloat = 0
    @State private var developed: Double = 0
    @State private var stripHeight: CGFloat = 0
    @State private var yaw: Double = 0
    @State private var pitch: Double = 0
    @State private var dragYaw: Double = 0
    /// The lean a finger gives the card where it presses, in degrees.
    @State private var press = CGSize.zero
    @State private var pressStarted = Date()
    /// The phone's own tilt (`CardTilt`).
    @State private var tilt = CardTilt()
    @State private var editing = false
    @State private var saved = false

    enum Stage { case loading, printing, held }

    /// The strip's width on this screen.
    static let width: CGFloat = 176

    private var frames: [PhotoStrip.Frame] { strip?.frames(excluding: excluded) ?? [] }
    private var isDeveloped: Bool { developed >= 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                WarmBackground().ignoresSafeArea()
                if stage == .printing {
                    printing
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 72)
                } else if stage == .held {
                    held(fitting: geo.size)
                }
                chrome
            }
        }
        .background(ShakeDetector { shook() }.frame(width: 0, height: 0))
        .task { await open() }
        .sheet(isPresented: $editing, onDismiss: { refreshDecor() }) {
            if let strip {
                StripEditor(strip: strip, excluded: $excluded, paper: $paper)
            }
        }
        .statusBarHidden(stage == .printing)
    }

    // MARK: Stages

    private func open() async {
        let loaded = await load()
        strip = loaded
        excluded = StripKeeping.excluded(owner, day: day)
        refreshDecor()
        let already = StripKeeping.isDeveloped(owner, day: day)
        developed = already ? 1 : 0
        if prints && !already && !reduceMotion {
            stage = .printing
            await printOut()
        } else {
            printed = 1
            withAnimation(GridConstants.cueIn) { stage = .held }
        }
    }

    /// The printer, its slot, and the strip stepping out of it under the
    /// glass, bottom edge first, a frame and a tap at a time.
    private var printing: some View {
        VStack(spacing: 0) {
            printer
                .zIndex(1)
            if let strip {
                StripView(frames: frames, day: day, signature: strip.signature, paper: paper,
                          width: Self.width, developed: 0, decor: decor)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stripHeight = $0 }
                    .frame(height: max(0, stripHeight * printed), alignment: .bottom)
                    .clipped()
                    .matchedGeometryEffect(id: "strip", in: space, anchor: .top)
                    .offset(y: -18)
            }
        }
    }

    /// The printer: a slab of glass with a dark slot across it.
    private var printer: some View {
        ZStack {
            Capsule()
                .fill(AppColors.inkPrimary.opacity(0.9))
                .frame(width: Self.width + 14, height: 6)
            Capsule()
                .fill(LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: Self.width + 14, height: 6)
        }
        .frame(width: Self.width + 64, height: 54)
        .glassCapsule(onPage: true)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityLabel("Printing today's strip")
    }

    private func printOut() async {
        try? await Task.sleep(for: .milliseconds(500))
        let steps = max(1, StripLayout.rows(frames.map(\.size)).count) + 1
        for step in 1...steps {
            withAnimation(GridConstants.stripStep) { printed = CGFloat(step) / CGFloat(steps) }
            HapticsEngine.lightTap()
            try? await Task.sleep(for: .milliseconds(430))
        }
        try? await Task.sleep(for: .milliseconds(250))
        // Free of the printer: it drops into the hand.
        HapticsEngine.snap()
        withAnimation(GridConstants.stripDrop) { stage = .held }
    }

    /// The strip in the middle, held: turned a touch at rest, dark until it
    /// is shaken, then turned in the hand.
    private func held(fitting size: CGSize) -> some View {
        let room = size.height - 260
        let fit = stripHeight > room && stripHeight > 0 ? room / stripHeight : 1
        let card = CGSize(width: Self.width * fit, height: stripHeight * fit)
        return VStack(spacing: GridConstants.gapSection) {
            ZStack {
                // **On the ground, under it**: a soft shadow that slides as
                // the card leans, the one thing that says it is held above
                // something. It does not turn with the card.
                RoundedRectangle(cornerRadius: Self.width * 0.02, style: .continuous)
                    .fill(Color.black.opacity(isDeveloped ? 0.16 : 0.1))
                    .frame(width: card.width * 0.92, height: card.height * 0.96)
                    .blur(radius: 16)
                    .offset(x: -turnYaw * 0.5, y: 18 + turnPitch * 0.4)
                    .opacity(facingFront || isDeveloped ? 1 : 0.6)
                ZStack {
                    if let strip {
                        // The paper's edge: a sliver of it shows on the side
                        // turned away, as a printed card's thickness does.
                        RoundedRectangle(cornerRadius: Self.width * 0.02, style: .continuous)
                            .fill(paper == .black ? Color(white: 0.24) : Color(white: 0.82))
                            .frame(width: Self.width, height: stripHeight)
                            .offset(x: -sin(turnYaw * .pi / 180) * 2.2, y: sin(turnPitch * .pi / 180) * 2.2)
                        StripView(frames: frames, day: day, signature: strip.signature, paper: paper,
                                  width: Self.width, developed: developed, decor: decor)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stripHeight = $0 }
                            .overlay { glare }
                            .opacity(facingFront ? 1 : 0)
                        StripBack(day: day, paper: paper, width: Self.width, height: stripHeight)
                            .overlay { glare }
                            .scaleEffect(x: -1, y: 1)
                            .opacity(facingFront ? 0 : 1)
                    }
                }
                .matchedGeometryEffect(id: "strip", in: space, anchor: .top)
                .scaleEffect(fit)
                .frame(height: stripHeight * fit)
                .rotation3DEffect(.degrees(yaw + dragYaw + press.width + tilt.yaw), axis: (x: 0, y: 1, z: 0),
                                  perspective: 0.45)
                .rotation3DEffect(.degrees(turnPitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                .rotationEffect(.degrees(isDeveloped ? 0 : -2.5))
            }
            .contentShape(Rectangle())
            .gesture(handle(card))
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Develop") { shook() }
            hint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if !reduceMotion { tilt.start() } }
        .onDisappear { tilt.stop() }
    }

    /// The card's lean around its upright axis, and across, everything in.
    private var turnYaw: Double { yaw + dragYaw + press.width + tilt.yaw }
    private var turnPitch: Double { pitch + press.height + tilt.pitch }

    private var facingFront: Bool {
        let a = (yaw + dragYaw).truncatingRemainder(dividingBy: 360)
        let n = a < 0 ? a + 360 : a
        return n < 90 || n > 270
    }

    /// **Light on photo paper, as a studio lights it** (the owner,
    /// 2026-10-07: "make sure the lighting on it genuinely is premium and
    /// expensive, not a cheap early 2000s looking light"). Not a hotspot and
    /// not a band: a broad, soft key light that slides gently across the
    /// sheen as the card turns, at a few percent, and a faint shade on the
    /// side turned away from it, which is what makes a flat sheet read as
    /// lit rather than as glowing. The first pass was a bright radial spot and
    /// a stripe added on top; that is the look he named.
    private var glare: some View {
        let lean = max(-1, min(1, (turnYaw.truncatingRemainder(dividingBy: 180)) / 24))
        let tip = max(-1, min(1, turnPitch / 24))
        let turned = min(1, abs(lean) + abs(tip))
        let lit = (isDeveloped ? 1.0 : 0.6)
        return ZStack {
            // The key light: wide and low, from above left, moving with the turn.
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0),
                                   .init(color: .white.opacity(0.06 + 0.08 * turned), location: 0.5),
                                   .init(color: .white.opacity(0), location: 1)],
                           startPoint: UnitPoint(x: -0.6 - lean * 0.5, y: -0.4 + tip * 0.4),
                           endPoint: UnitPoint(x: 1.0 - lean * 0.5, y: 1.2 + tip * 0.4))
                .blendMode(.screen)
            // The shade on the far side, so it reads as a lit sheet.
            LinearGradient(colors: [.black.opacity(0.10 * abs(lean)), .clear],
                           startPoint: lean > 0 ? .leading : .trailing, endPoint: .center)
                .blendMode(.multiply)
            LinearGradient(colors: [.black.opacity(0.08 * abs(tip)), .clear],
                           startPoint: tip > 0 ? .bottom : .top, endPoint: .center)
                .blendMode(.multiply)
        }
        .opacity(lit)
        .clipShape(RoundedRectangle(cornerRadius: Self.width * 0.02, style: .continuous))
        .allowsHitTesting(false)
    }

    /// **A finger on the card** (the owner: "Pokemon TCG level card
    /// movement"). Pressed, it leans toward the finger, as a card does under
    /// a thumb, and follows it; drawn across far, it turns over, settling
    /// face up or face down; let go, it springs back with a little give. A
    /// quick touch that does not move is a tap: before it develops, a tap
    /// develops it a step, for anyone who cannot shake.
    private func handle(_ card: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if value.translation == .zero { pressStarted = Date() }
                let across = value.translation.width
                // Far across, and developed: turning it over.
                if isDeveloped, abs(across) > Self.turnStart {
                    dragYaw = (across - (across > 0 ? Self.turnStart : -Self.turnStart)) * 0.75
                }
                let x = max(-1, min(1, (value.location.x / max(card.width, 1)) * 2 - 1))
                let y = max(-1, min(1, (value.location.y / max(card.height, 1)) * 2 - 1))
                let reach = reduceMotion ? 4.0 : Self.pressReach
                withAnimation(GridConstants.cardFollow) {
                    press = CGSize(width: x * reach, height: -y * reach)
                }
            }
            .onEnded { value in
                let moved = hypot(value.translation.width, value.translation.height)
                if moved < 8, Date().timeIntervalSince(pressStarted) < 0.35, !isDeveloped { shook() }
                let total = yaw + dragYaw + value.predictedEndTranslation.width * 0.15 * (abs(dragYaw) > 0 ? 1 : 0)
                let landing = (total / 180).rounded() * 180
                let flipped = Int((landing / 180).rounded()) % 2 != 0
                let wasFlipped = !facingFront
                withAnimation(GridConstants.cardRelease) {
                    yaw = landing
                    dragYaw = 0
                    press = .zero
                    pitch = 0
                }
                if flipped != wasFlipped { HapticsEngine.lightTap() }
            }
    }

    /// How far across a finger goes before it is turning the card over
    /// rather than leaning it, and how far a press leans it.
    static let turnStart: CGFloat = 44
    static let pressReach = 13.0

    /// What to do now, under the strip.
    @ViewBuilder
    private var hint: some View {
        Group {
            if !isDeveloped {
                Text(canDevelop() ? "Shake to develop" : "Reach your goal to develop it")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkSecondary)
                    .transition(.opacity)
            } else {
                tools
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(GridConstants.cueIn, value: isDeveloped)
    }

    // MARK: Developing

    private func shook() {
        guard canDevelop(), stage == .held, !isDeveloped, !frames.isEmpty else { return }
        HapticsEngine.lightTap()
        withAnimation(GridConstants.stripDevelop) { developed = min(1, developed + 0.26) }
        if developed >= 1 {
            StripKeeping.setDeveloped(owner, day: day)
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                HapticsEngine.success()
            }
        }
    }

    // MARK: Tools

    private var tools: some View {
        HStack(spacing: GridConstants.gapWide) {
            GlassIconButton(systemName: "pencil", onPage: true, accessibilityLabel: "Edit strip") {
                editing = true
            }
            if let image = rendered {
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview("Some Wins", image: Image(uiImage: image))) {
                    GlassIconLabel(systemName: "square.and.arrow.up", onPage: true)
                }
                .accessibilityLabel("Share strip")
                GlassIconButton(systemName: saved ? "checkmark" : "square.and.arrow.down", onPage: true,
                                accessibilityLabel: saved ? "Saved" : "Save strip") {
                    Task {
                        if await PhotoLibrarySaver.save(image, respectingPreference: false) {
                            HapticsEngine.success()
                            saved = true
                        }
                    }
                }
                .disabled(saved)
            }
        }
    }

    private var chrome: some View {
        HStack {
            Spacer(minLength: 0)
            GlassIconButton(systemName: "xmark", onPage: true, accessibilityLabel: "Close") { dismiss() }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(stage == .printing ? 0 : 1)
    }

    /// The strip as a picture to keep: its paper and no more, at three
    /// times a large width.
    private var rendered: UIImage? {
        guard let strip else { return nil }
        let renderer = ImageRenderer(content: StripView(frames: frames, day: day, signature: strip.signature,
                                                        paper: paper, width: 360, developed: 1, decor: decor))
        renderer.scale = 3
        return renderer.uiImage
    }

    private func refreshDecor() {
        decor = StripDecor.picture(owner: owner, day: day)
        saved = false
        StripKeeping.setExcluded(excluded, owner, day: day)
        StripKeeping.paper = paper
    }
}

/// **The strip's back**, as a photo's back is stamped: the paper, the mark
/// small in the middle, and the day.
struct StripBack: View {
    let day: String
    let paper: StripPaper
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: width * 0.04) {
            Wordmark(size: width * 0.075)
                .foregroundStyle(paper.quiet)
            Text(DateUtils.date(from: day).map { $0.formatted(.dateTime.month(.wide).day().year()) } ?? day)
                .font(.custom(Wordmark.fontName, fixedSize: width * 0.055))
                .foregroundStyle(paper.quiet)
        }
        .frame(width: width, height: max(height, width))
        .background(paper.ground)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.02, style: .continuous))
        .accessibilityHidden(true)
    }
}
