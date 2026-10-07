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
/// 4. **In the hand.** Drag to tilt and turn it, with a sheen across the
///    paper; turn it all the way over to its back, stamped with the mark and
///    the day. It springs back to rest.
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
        return VStack(spacing: GridConstants.gapSection) {
            ZStack {
                if let strip {
                    StripView(frames: frames, day: day, signature: strip.signature, paper: paper,
                              width: Self.width, developed: developed, decor: decor)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stripHeight = $0 }
                        .overlay { sheen }
                        .opacity(facingFront ? 1 : 0)
                    StripBack(day: day, paper: paper, width: Self.width, height: stripHeight)
                        .scaleEffect(x: -1, y: 1)
                        .opacity(facingFront ? 0 : 1)
                }
            }
            .matchedGeometryEffect(id: "strip", in: space, anchor: .top)
            .scaleEffect(fit)
            .frame(height: stripHeight * fit)
            .rotation3DEffect(.degrees(restTilt + yaw + dragYaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .rotationEffect(.degrees(isDeveloped ? 0 : -2.5))
            .gesture(turn)
            .onTapGesture { if !isDeveloped { shook() } }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Develop") { shook() }
            hint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var restTilt: Double { 0 }
    private var facingFront: Bool {
        let a = (restTilt + yaw + dragYaw).truncatingRemainder(dividingBy: 360)
        let n = a < 0 ? a + 360 : a
        return n < 90 || n > 270
    }

    /// Light across the paper, moving as it turns: a gloss, not a shadow.
    private var sheen: some View {
        let t = (yaw + dragYaw) / 90 + pitch / 60
        return LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.25 + t * 0.3),
                                      .init(color: .white.opacity(0.22), location: 0.45 + t * 0.3),
                                      .init(color: .white.opacity(0), location: 0.65 + t * 0.3)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
            .blendMode(.plusLighter)
            .opacity(isDeveloped && (abs(dragYaw) > 1 || abs(pitch) > 1) ? 1 : 0)
            .allowsHitTesting(false)
    }

    /// Drag to turn it: across turns it, up and down tips it. Let go and it
    /// settles face up or face down, whichever it was nearer.
    private var turn: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard isDeveloped else { return }
                dragYaw = value.translation.width * 0.75
                pitch = max(-28, min(28, -value.translation.height * 0.25))
            }
            .onEnded { value in
                guard isDeveloped else { return }
                let total = yaw + dragYaw + value.predictedEndTranslation.width * 0.15
                let landing = (total / 180).rounded() * 180
                let face = Int((landing / 180).rounded()) % 2 == 0
                withAnimation(GridConstants.stripSettle) {
                    yaw = landing
                    dragYaw = 0
                    pitch = 0
                }
                if face != facingFront { HapticsEngine.lightTap() }
            }
    }

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
