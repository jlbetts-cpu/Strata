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
    @State private var paper = StripPaper.white
    @Environment(\.colorScheme) private var colorScheme
    @State private var decor: InkPicture?
    @State private var stage = Stage.loading
    /// How much of the strip is out of the printer, 0 to 1.
    @State private var printed: CGFloat = 0
    @State private var developed: Double = 0
    @State private var stripHeight: CGFloat = 0
    @State private var yaw: Double = 0
    @State private var pitch: Double = 0
    @State private var dragYaw: Double = 0
    @State private var dragPitch: Double = 0
    /// The lean a finger gives the card where it presses, in degrees.
    @State private var pressStarted = Date()
    /// The phone's own tilt (`CardTilt`).
    @State private var tilt = CardTilt()
    /// The island stretched into the printer.
    @State private var islandOpen = false
    /// The drawn pill is up at all. It rests a hair inside the real island,
    /// so it can appear and go with no fade and still never be seen at rest.
    @State private var pillShown = false
    /// A breath of height as each frame feeds out (`islandFeed`).
    @State private var feedPulse: CGFloat = 0
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
    /// **The hand-over: the held strip is already there, under the printed
    /// one, and the printed one fades off it.** Fading the held one in on top
    /// brought its page with it at half strength over the strip (measured:
    /// the strip's area went from 114 to 153 in luminance for a few frames),
    /// and a symmetric cross-fade does the same. Identical in place, one
    /// opaque under one fading, the strip never changes.
    @State private var handingOver = false
    @State private var printFade: Double = 1
    /// The close button coming up as the strip lands, not after.
    @State private var chromeShown = false
    /// The editor, opened on its pen or its stickers.
    @State private var editing: StripEditor.Opening?
    @State private var saved = false
    /// The pose-and-share screen is up (`StripStoryComposer`).
    @State private var telling = false
    /// **Looking closer** (2026-10-07: "a way to zoom in to it"). Once it
    /// has developed, a pinch or a double tap brings it up to 3x, and a
    /// finger then moves around it instead of turning it; a double tap or
    /// pinching back under 1 puts it back in the hand.
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat = 1
    @State private var pan = CGSize.zero
    @State private var panStart = CGSize.zero
    private var zoomed: Bool { zoom > 1.02 }

    enum Stage { case loading, printing, held }

    /// The strip's width on this screen. It was 176, and the owner could not
    /// see into the photographs ("it's not really big enough to really look
    /// at the image"); the height still fits the page (`held`), and a pinch
    /// goes further (`zoom`).
    static let width: CGFloat = 228

    private var frames: [PhotoStrip.Frame] { strip?.frames(excluding: excluded) ?? [] }
    private var isDeveloped: Bool { developed >= 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                WarmBackground().ignoresSafeArea()
                // Laid out from the start, unseen while it prints, so the
                // printed strip knows where in the hand it will land.
                held(fitting: geo.size)
                    // Never quite 0 while it prints: a view at 0 is not
                    // drawn, so its photographs were decoded and faded in the
                    // moment it was handed the strip (a lighter flash).
                    .opacity(stage == .held || handingOver ? 1 : 0.001)
                    .allowsHitTesting(stage == .held)
                if stage == .printing {
                    printing(fitting: geo.size, safeTop: geo.safeAreaInsets.top)
                        .opacity(printFade)
                }
                chrome
            }
            .overlay(alignment: .top) {
                if stage == .printing { island(safeTop: geo.safeAreaInsets.top, fit: fit(geo.size)) }
            }
        }
        .background(ShakeDetector(usesMotion: false) { shook() }.frame(width: 0, height: 0))
        .task {
            await open()
            #if DEBUG
            // `-strataStory 1` opens the Story card once the strip is in.
            if DebugHarness.argument("-strataStory") == "1" {
                try? await Task.sleep(for: .milliseconds(600))
                telling = true
            }
            #endif
        }
        .sheet(item: $editing, onDismiss: { refreshDecor() }) { opening in
            if let strip {
                StripEditor(strip: strip, excluded: $excluded, paper: $paper, opening: opening)
            }
        }
        // **Share is a Story you turn first** (2026-10-07, his pick: "9:16
        // Stories strip", turned "at different angles").
        .fullScreenCover(isPresented: $telling) {
            if let strip {
                StripStoryComposer(strip: strip, frames: frames, day: day, paper: paper, decor: decor)
            }
        }
        .statusBarHidden(stage == .printing)
    }

    // MARK: Stages

    private func open() async {
        let already = StripKeeping.isDeveloped(owner, day: day)
        // **Printed before it develops, every time** (the owner, 2026-10-07:
        // "I would prefer if the printing animation actually played before
        // developing"). Any strip not yet developed comes out of the island
        // first, however the booth was opened, not only at the goal; one
        // that may not develop yet (before your goal) is not printed.
        let printsNow = !already && !reduceMotion && (prints || canDevelop())
        // The island opens into the printer at once, and holds while the
        // day's pictures load: the wait is the printer warming, not a blank.
        if printsNow { stage = .printing }
        async let loading = load()
        if printsNow {
            try? await Task.sleep(for: .milliseconds(450))
            settled = true
            // Up at rest, hidden in the real island, then out of it: the
            // island itself seems to stretch, as the system's does.
            pillShown = true
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(GridConstants.islandOpen) { islandOpen = true }
        }
        paper = StripKeeping.paper(for: colorScheme)
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

    /// The strip's scale, so a long one fits the room under it. **The held
    /// strip's own room** (230): the printing one used 260, so the strip grew
    /// about 5% in the frame it was handed over.
    private func fit(_ size: CGSize) -> CGFloat {
        let room = size.height - 230
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
        let height: CGFloat = (islandOpen ? 46 : 35) + feedPulse
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
            // Never faded: at rest it is inside the real island, so it can
            // simply be there or not.
            .opacity(settled && pillShown ? 1 : 0)
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
        // **One motion, not six** (2026-10-08): the feed runs the whole way on
        // one curve, and the printer's work is marked by a tick and a breath
        // of the island as each frame passes, not by the strip stopping.
        let each = 0.36
        withAnimation(GridConstants.stripFeed(duration: each * Double(steps))) { printed = 1 }
        for _ in 1...steps {
            withAnimation(GridConstants.islandBreath) { feedPulse = 1.5 }
            HapticsEngine.lightTap()
            try? await Task.sleep(for: .milliseconds(Int(each * 500)))
            withAnimation(GridConstants.islandBreath) { feedPulse = 0 }
            try? await Task.sleep(for: .milliseconds(Int(each * 500)))
        }
        try? await Task.sleep(for: .milliseconds(200))
        // Free of the printer: it drops into the hand, turning as it goes,
        // and the island closes behind it.
        HapticsEngine.snap()
        withAnimation(GridConstants.stripDrop) {
            drop = heldTop - printTop
            dropTilt = -2.5
        }
        // A beat behind the strip, the island draws back into itself, and
        // once it is the real island's size again the drawn one goes.
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(GridConstants.islandClose) { islandOpen = false }
        try? await Task.sleep(for: .milliseconds(480))
        pillShown = false
        // **Handed over, not swapped** (2026-10-08): the printed strip fades
        // as the held one comes up in the same place, with the chrome and the
        // status bar. It was one frame, with everything appearing at once.
        var still = Transaction()
        still.disablesAnimations = true
        // The held strip goes up under the printed one and is drawn there for
        // a moment, covered; then the printed one is taken away in one frame.
        // Every fade tried here showed: the held strip's first frames are not
        // yet its settled ones (measured lighter, 114 to 141).
        withTransaction(still) { handingOver = true }
        withAnimation(GridConstants.stripHandoff) { chromeShown = true }
        try? await Task.sleep(for: .milliseconds(450))
        withTransaction(still) {
            stage = .held
            handingOver = false
            chromeShown = false
            printFade = 1
            drop = 0
            dropTilt = 0
        }
    }

    /// The strip in the middle, held: turned a touch at rest, dark until it
    /// is shaken, then turned in the hand.
    private func held(fitting size: CGSize) -> some View {
        let room = size.height - 230
        let fit = stripHeight > room && stripHeight > 0 ? room / stripHeight : 1
        let card = CGSize(width: Self.width * fit, height: stripHeight * fit)
        return VStack(spacing: GridConstants.gapSection) {
            ZStack {
                // **No shadow** (the owner, 2026-10-07, after three tries:
                // "I'm really not a big fan of this shadow, it makes
                // everything look super cramped, doesn't fit the rest of the
                // app"). The strip stands on the page as everything else in
                // the app does; its turn, edge and light do the work.
                ZStack {
                    if let strip {
                        TurningCard(yaw: turnYaw, pitch: turnPitch, width: Self.width, height: stripHeight,
                                    // Photo paper's core: grey on black,
                                    // a light core under white or a colour.
                                    edge: paper == .black ? Color(white: 0.28) : Color(white: 0.84),
                                    lit: isDeveloped ? 1.0 : 0.6) {
                            StripView(frames: frames, day: day, signature: strip.signature, paper: paper,
                                      width: Self.width, developed: developed, decor: decor)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stripHeight = $0 }
                        } back: {
                            StripBack(day: day, paper: paper, width: Self.width, height: stripHeight)
                        }
                    }
                }
                .scaleEffect(fit)
                .frame(height: stripHeight * fit)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { heldTop = $0 }
                .rotationEffect(.degrees(isDeveloped ? 0 : -2.5 + Double(handShake) * 0.06))
                .offset(x: handShake)
                .scaleEffect(zoom)
                .offset(pan)
            }
            .contentShape(Rectangle())
            .gesture(handle(card))
            .simultaneousGesture(pinch)
            .simultaneousGesture(TapGesture(count: 2).onEnded { toggleZoom() })
            .zIndex(1)
            // **One element with its actions** (2026-10-08). As a container
            // the action had nothing to sit on, so VoiceOver could not reach
            // it, and a shake develops a quarter at a time with nothing said
            // between. Develop develops it in one go and says so.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your strip")
            .accessibilityValue(isDeveloped ? "Developed" : "Not developed yet")
            .accessibilityAction(named: "Develop") { shook(all: true) }
            .accessibilityAction(named: zoomed ? "Zoom out" : "Zoom in") { toggleZoom() }
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

    /// The card's turn around its upright axis, and its tip up or down,
    /// everything in: where it rests, the finger, and the phone's own lean.
    private var turnYaw: Double { yaw + dragYaw + tilt.yaw }
    private var turnPitch: Double { pitch + dragPitch + tilt.pitch }

    private var facingFront: Bool { cos(turnYaw * .pi / 180) >= 0 }

    /// **A finger turns it, on both axes** (the owner, 2026-10-07: "make it
    /// more controlled ... you can only really turn it a little back and
    /// forth but not up and down angling"). Across turns it about its long
    /// axis, all the way over to its back; up and down tips it toward or
    /// away, to 50 degrees either way. It follows the finger from wherever
    /// it was taken, not from where the finger lands, so nothing jumps at
    /// the touch. Let go, it springs to the nearest face and level. Before
    /// it develops the same drag is the hand shake, and a quick tap
    /// develops it a step, for anyone who cannot shake.
    private func handle(_ card: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Zoomed in, a finger moves around the strip.
                if zoomed {
                    pan = CGSize(width: panStart.width + value.translation.width,
                                 height: panStart.height + value.translation.height)
                    return
                }
                if value.translation == .zero { pressStarted = Date() }
                if !isDeveloped { follow(value.translation.width) }
                let reach = reduceMotion ? 0.35 : 1.0
                withAnimation(GridConstants.cardFollow) {
                    dragYaw = isDeveloped ? Double(value.translation.width) * Self.turnPerPoint * reach : 0
                    dragPitch = max(-Self.tipMost, min(Self.tipMost,
                                                      -Double(value.translation.height) * Self.tipPerPoint * reach))
                }
            }
            .onEnded { value in
                if zoomed {
                    panStart = pan
                    return
                }
                let moved = hypot(value.translation.width, value.translation.height)
                if moved < 8, Date().timeIntervalSince(pressStarted) < 0.35, !isDeveloped { shook() }
                // A flick carries the turn on a little, so a quick throw
                // across flips it as a card flicked in the fingers does.
                let flick = Double(value.predictedEndTranslation.width - value.translation.width)
                    * Self.turnPerPoint * 0.35
                let total = yaw + dragYaw + (isDeveloped ? flick : 0)
                let landing = (total / 180).rounded() * 180
                let wasFront = facingFront
                withAnimation(GridConstants.cardRelease) {
                    yaw = landing
                    dragYaw = 0
                    dragPitch = 0
                    pitch = 0
                    handShake = 0
                }
                shakeTurns = 0
                shakeEdge = 0
                shakeHeading = 0
                if (cos(landing * .pi / 180) >= 0) != wasFront { HapticsEngine.lightTap() }
            }
    }

    /// Degrees of turn per point across: about a third of the screen turns
    /// it edge-on, so its back is one deliberate drag away.
    static let turnPerPoint = 0.6
    /// Degrees of tip per point up or down, and the most it tips.
    static let tipPerPoint = 0.4
    static let tipMost = 50.0

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard isDeveloped else { return }
                zoom = max(0.85, min(Self.zoomMost, zoomStart * value.magnification))
            }
            .onEnded { _ in
                guard isDeveloped else { return }
                if zoom < 1.02 {
                    withAnimation(GridConstants.cardRelease) {
                        zoom = 1
                        pan = .zero
                    }
                    panStart = .zero
                }
                zoomStart = zoom
            }
    }

    private func toggleZoom() {
        guard isDeveloped else { return }
        HapticsEngine.lightTap()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardRelease) {
            zoom = zoomed ? 1 : 2.2
            pan = .zero
        }
        zoomStart = zoom
        panStart = .zero
    }

    /// The most a pinch brings the strip up.
    static let zoomMost: CGFloat = 3

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
                    .opacity(zoomed ? 0 : 1)
                    .allowsHitTesting(!zoomed)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? GridConstants.crossFade : GridConstants.cueIn, value: isDeveloped)
    }

    // MARK: Developing

    private func shook(all: Bool = false) {
        guard canDevelop(), stage == .held, !isDeveloped, !frames.isEmpty else { return }
        HapticsEngine.lightTap()
        withAnimation(GridConstants.stripDevelop) { developed = all ? 1 : min(1, developed + 0.26) }
        if developed >= 1 {
            if all { AccessibilityNotification.Announcement("Strip developed").post() }
            StripKeeping.setDeveloped(owner, day: day)
            Analytics.shared.signal(.stripDeveloped)
            if owner == .me { TipJar.shared.noteStripDeveloped() }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                HapticsEngine.success()
            }
        }
    }

    // MARK: Tools

    /// **The strip's tools, one each** (the owner, 2026-10-07: "make it one
    /// button ... any of the category colors or the dark or white version
    /// ... and you need a button for the doodle and adding stickers to it").
    /// Its colour, the pen, a sticker, share and save, in that order: what
    /// you do to it, then what you do with it.
    private var tools: some View {
        HStack(spacing: GridConstants.gapItem) {
            paperButton
            GlassIconButton(systemName: "scribble", onPage: true, accessibilityLabel: "Doodle on the strip") {
                editing = .pen
            }
            GlassIconButton(drawn: .sticker, onPage: true, accessibilityLabel: "Add a sticker") {
                editing = .stickers
            }
            if strip != nil {
                GlassIconButton(systemName: "square.and.arrow.up", onPage: true,
                                accessibilityLabel: "Share strip") {
                    telling = true
                }
                GlassIconButton(systemName: saved ? "checkmark" : "square.and.arrow.down", onPage: true,
                                accessibilityLabel: saved ? "Saved" : "Save strip") {
                    Task {
                        // A PNG, so the strip's rounded corners stay clear;
                        // drawn at the press, not on every redraw.
                        guard let data = rendered?.pngData() else { return }
                        if await PhotoLibrarySaver.savePNG(data) {
                            HapticsEngine.success()
                            saved = true
                        }
                    }
                }
                .disabled(saved)
            }
        }
    }

    /// **One button for the paper**: a tap steps to the next colour, black,
    /// white and then each block colour; a hold lists them all by name. Its
    /// face is the paper itself.
    private var paperButton: some View {
        Menu {
            Picker("Paper", selection: Binding(get: { paper }, set: { choosePaper($0) })) {
                ForEach(StripPaper.allCases) { option in
                    Text(option.name).tag(option)
                }
            }
        } label: {
            Circle()
                .fill(paper.fill)
                .overlay { Circle().strokeBorder(GridConstants.fillHairline, lineWidth: 1) }
                .frame(width: 24, height: 24)
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .glassCircle(onPage: true)
                .contentShape(Circle())
        } primaryAction: {
            choosePaper(paper.next)
        }
        .accessibilityLabel("Paper colour")
        .accessibilityValue(paper.name)
        .accessibilityHint("Tap for the next colour, hold for all of them.")
    }

    private func choosePaper(_ next: StripPaper) {
        HapticsEngine.tick()
        withAnimation(GridConstants.crossFade) { paper = next }
        StripKeeping.choose(next)
        refreshDecor()
    }

    private var chrome: some View {
        HStack {
            Spacer(minLength: 0)
            GlassIconButton(systemName: "xmark", onPage: true, accessibilityLabel: "Close") { dismiss() }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(stage == .printing && !chromeShown ? 0 : 1)
    }

    /// The strip as a picture to keep: its paper and no more, flat, at four
    /// times a large width, on clear.
    private var rendered: UIImage? {
        guard let strip else { return nil }
        let renderer = ImageRenderer(content: StripView(frames: frames, day: day, signature: strip.signature,
                                                        paper: paper, width: 360, developed: 1, decor: decor))
        renderer.scale = 4
        renderer.isOpaque = false
        return renderer.uiImage
    }

    private func refreshDecor() {
        decor = StripDecor.picture(owner: owner, day: day)
        saved = false
        StripKeeping.setExcluded(excluded, owner, day: day)
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
        .clipShape(RoundedRectangle(cornerRadius: StripView.corner(forWidth: width), style: .continuous))
        .accessibilityHidden(true)
    }
}
