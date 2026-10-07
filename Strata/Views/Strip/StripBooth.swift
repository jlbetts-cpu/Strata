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
    /// The island stretched into the printer.
    @State private var islandOpen = false
    /// **Shaken by hand, as a Polaroid is** (the owner, 2026-10-07: "make it
    /// so you can physically shake your phone or like shake it with your hand
    /// to reveal the photostrip"). Before it develops the strip follows a
    /// finger side to side; each turn back counts, and two make a shake.
    @State private var handShake: CGFloat = 0
    @State private var shakeTurns = 0
    @State private var shakeEdge: CGFloat = 0
    @State private var shakeHeading: CGFloat = 0
    /// The booth has finished sliding up: before then the drawn pill would
    /// ride up the screen under the real island, a second island.
    @State private var settled = false
    /// Where the printed strip and the held one sit on screen (their tops),
    /// and the drop between them as it falls into the hand.
    @State private var printTop: CGFloat = 0
    @State private var heldTop: CGFloat = 0
    @State private var drop: CGFloat = 0
    @State private var dropTilt: Double = 0
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
                // Laid out from the start, unseen while it prints, so the
                // printed strip knows where in the hand it will land.
                held(fitting: geo.size)
                    .opacity(stage == .held ? 1 : 0)
                    .allowsHitTesting(stage == .held)
                if stage == .printing {
                    printing(fitting: geo.size, safeTop: geo.safeAreaInsets.top)
                }
                chrome
            }
            .overlay(alignment: .top) {
                if stage == .printing { island(safeTop: geo.safeAreaInsets.top, fit: fit(geo.size)) }
            }
        }
        .background(ShakeDetector(usesMotion: false) { shook() }.frame(width: 0, height: 0))
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
        let already = StripKeeping.isDeveloped(owner, day: day)
        let printsNow = prints && !already && !reduceMotion
        // The island opens into the printer at once, and holds while the
        // day's pictures load: the wait is the printer warming, not a blank.
        if printsNow { stage = .printing }
        async let loading = load()
        if printsNow {
            try? await Task.sleep(for: .milliseconds(450))
            settled = true
            withAnimation(GridConstants.islandMorph) { islandOpen = true }
        }
        let loaded = await loading
        strip = loaded
        excluded = StripKeeping.excluded(owner, day: day)
        refreshDecor()
        developed = already ? 1 : 0
        #if DEBUG
        if DebugHarness.argument("-strataIslandProbe") != nil { return }
        #endif
        if printsNow {
            await printOut()
        } else {
            printed = 1
            withAnimation(GridConstants.cueIn) { stage = .held }
        }
    }

    /// The strip's scale, so a long one fits the room under it.
    private func fit(_ size: CGSize) -> CGFloat {
        let room = size.height - 260
        return stripHeight > room && stripHeight > 0 ? room / stripHeight : 1
    }

    /// **The island is the printer** (the owner, 2026-10-07: "the glass
    /// printer right now doesn't look premium, what if we made the pill turn
    /// into the printer", "the actual Apple pill"). A black pill drawn exactly
    /// over the Dynamic Island stretches to the strip's width and feeds it
    /// down, then shrinks back into the island. On a phone without one, the
    /// same pill grows from the top edge and goes back into it.
    ///
    /// The island's place is the safe area's top less 48 (14pt on a 17 Pro,
    /// 11 on a 14 Pro). At rest the pill is 120 by 35, a touch smaller than
    /// every island (125 by 36.7 the smallest), and it fades in as it starts
    /// to stretch and out as it shrinks back (the owner: "make sure it works
    /// with all the devices that have the dynamic island"), so a point of
    /// difference between one model's island and another's never shows.
    private func island(safeTop: CGFloat, fit: CGFloat) -> some View {
        let hasIsland = safeTop >= 51
        let width = islandOpen ? Self.width * fit + 30 : (hasIsland ? 120 : 60)
        let height: CGFloat = islandOpen ? 46 : 35
        #if DEBUG
        // `-strataIslandProbe 1`: the resting pill in red with a ring 4pt
        // wider in blue, held still, so each phone's screenshot shows whether
        // it sits wholly and evenly under the real island.
        if DebugHarness.argument("-strataIslandProbe") != nil {
            return AnyView(ZStack {
                Capsule().fill(Color.blue).frame(width: 128, height: 43)
                Capsule().fill(Color.red).frame(width: 120, height: 35)
            }
            .padding(.top, (hasIsland ? safeTop - 48 : 6) + 0.8 - 4)
            .ignoresSafeArea())
        }
        #endif
        return AnyView(Capsule()
            .fill(Color.black)
            .frame(width: width, height: height)
            .padding(.top, (hasIsland ? safeTop - 48 : 6) + (islandOpen ? 0 : 0.8))
            .opacity(settled && islandOpen ? 1 : 0)
            .ignoresSafeArea()
            .accessibilityLabel("Printing today's strip"))
    }

    /// The strip feeding out of the island, foot first, a frame and a tap
    /// at a time, and then dropping free into the hand: one view the whole
    /// way, so the fall is a fall and not a cut.
    private func printing(fitting size: CGSize, safeTop: CGFloat) -> some View {
        let fit = fit(size)
        let slot = (safeTop >= 51 ? safeTop - 48 : 6) + 46 - safeTop - 8
        return VStack(spacing: 0) {
            if let strip {
                StripView(frames: frames, day: day, signature: strip.signature, paper: paper,
                          width: Self.width, developed: 0, decor: decor)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stripHeight = $0 }
                    .frame(height: max(0, stripHeight * printed), alignment: .bottom)
                    .clipped()
                    .scaleEffect(fit, anchor: .top)
                    .frame(width: Self.width * fit, height: max(0, stripHeight * printed) * fit, alignment: .top)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { printTop = $0 }
                    .rotationEffect(.degrees(dropTilt))
                    .offset(y: drop)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, slot)
    }

    private func printOut() async {
        try? await Task.sleep(for: .milliseconds(350))
        let steps = max(1, StripLayout.rows(frames.map(\.size)).count) + 1
        for step in 1...steps {
            withAnimation(GridConstants.stripStep) { printed = CGFloat(step) / CGFloat(steps) }
            HapticsEngine.lightTap()
            try? await Task.sleep(for: .milliseconds(430))
        }
        try? await Task.sleep(for: .milliseconds(250))
        // Free of the printer: it drops into the hand, turning as it goes,
        // and the island closes behind it.
        HapticsEngine.snap()
        withAnimation(GridConstants.stripDrop) {
            drop = heldTop - printTop
            dropTilt = -2.5
            islandOpen = false
        }
        try? await Task.sleep(for: .milliseconds(700))
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            stage = .held
            drop = 0
            dropTilt = 0
        }
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
                .scaleEffect(fit)
                .frame(height: stripHeight * fit)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { heldTop = $0 }
                .rotation3DEffect(.degrees(yaw + dragYaw + press.width + tilt.yaw), axis: (x: 0, y: 1, z: 0),
                                  perspective: 0.45)
                .rotation3DEffect(.degrees(turnPitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                .rotationEffect(.degrees(isDeveloped ? 0 : -2.5 + Double(handShake) * 0.06))
                .offset(x: handShake)
            }
            .contentShape(Rectangle())
            .gesture(handle(card))
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Develop") { shook() }
            hint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            tilt.onShake = { shook() }
            tilt.leans = !reduceMotion
            tilt.start()
        }
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
                if !isDeveloped { follow(across) }
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
                    handShake = 0
                }
                shakeTurns = 0
                shakeEdge = 0
                shakeHeading = 0
                if flipped != wasFlipped { HapticsEngine.lightTap() }
            }
    }

    /// The undeveloped strip in the hand: it follows the finger across, a
    /// little less than the finger moves, and every turn back of more than a
    /// small distance is counted; two turns are one shake, a step developed.
    private func follow(_ across: CGFloat) {
        withAnimation(GridConstants.cardFollow) { handShake = across * 0.55 }
        // `shakeHeading` is the farthest this swing has gone from where the
        // last one turned (`shakeEdge`), signed.
        let d = across - shakeEdge
        let sameWay = shakeHeading == 0 || (d > 0) == (shakeHeading > 0)
        if sameWay, abs(d) >= abs(shakeHeading) {
            shakeHeading = d
        } else if !sameWay || abs(shakeHeading) - abs(d) > 10 {
            // Turned back: a swing, if it went far enough.
            if abs(shakeHeading) > Self.shakeSwing {
                shakeTurns += 1
                if shakeTurns >= 2 {
                    shakeTurns = 0
                    shook()
                }
            }
            shakeEdge += shakeHeading
            shakeHeading = across - shakeEdge
        }
    }

    /// How far one swing of a hand shake has to go to count.
    static let shakeSwing: CGFloat = 22

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
