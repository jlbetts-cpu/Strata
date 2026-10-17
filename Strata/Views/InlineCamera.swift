import AVFoundation
import PhotosUI
import SwiftUI

// MARK: - The switch

/// **Add a Win opens on the camera** (the owner, 2026-10-17: "the camera IS
/// the Add a Win sheet ... Taking the photo is the first and main thing you
/// do. Everything else comes after, and only if you want it").
///
/// On by default because he asked for it by name; Settings can turn it off,
/// and then every way in opens the sheet as before.
enum CameraFirst {
    static let key = "cameraFirst"
    static var on: Bool {
        #if DEBUG
        if let forced = DebugHarness.argument("-strataCameraFirst") { return forced == "1" }
        #endif
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

/// **The Camera tab, while it is kept** (the owner, 2026-10-17: "Research
/// whether we need a Camera tab at all ... build the three-tab version behind
/// a switch that's off"). On: four tabs, as today. Off: Wins, Crews and
/// Memories, the camera card reachable everywhere a photo is made.
enum CameraTab {
    static let key = "cameraTabShown"
    static var shown: Bool {
        #if DEBUG
        if let forced = DebugHarness.argument("-strataCameraTab") { return forced == "1" }
        #endif
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

extension StrataTab {
    /// The tabs the bar shows, in its order.
    static var visible: [StrataTab] {
        allCases.filter { tab in
            switch tab {
            case .crews: CrewsFlag.isOn
            case .camera: CameraTab.shown
            default: true
            }
        }
    }
}

// MARK: - The camera behind it

/// The inline camera's lens: the app's own `CameraService`, the same preview,
/// the same face touch and polish as the Camera tab, held here so it can be
/// made ready before anybody asks.
@MainActor
final class InlineCamera {
    static let shared = InlineCamera()
    let camera = CameraService()
    let box = PreviewLayerBox()

    /// **Ready, never running.** The session is configured early, while the
    /// tower sits there, so a tap only has to start it. Not started: a running
    /// camera lights the phone's camera dot, and nothing in this app is
    /// pointed at anyone before they ask. Never asks permission either; that
    /// waits for the tap.
    func warm() async {
        guard !camera.isConfigured, Self.allowed else { return }
        await camera.prepare()
    }

    /// Allowed already, without asking.
    static var allowed: Bool {
        #if DEBUG
        if FakeLens.shared != nil { return true }
        if DebugHarness.cameraDenied { return false }
        #endif
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Refused, so the card opens on words with a way to turn it on.
    static var refused: Bool {
        #if DEBUG
        if FakeLens.shared != nil { return false }
        if DebugHarness.cameraDenied { return true }
        #endif
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .denied || status == .restricted
    }
}

// MARK: - Opening

/// Where Add a Win was opened from: the thing tapped, which the card grows
/// out of and goes back into.
struct AddWinOpening: Identifiable, Equatable {
    let id = UUID()
    /// The tapped thing's frame, in the window.
    var from: CGRect
    var radius: CGFloat
    var colour: HabitCategory
    /// Opened from a crew's tower: that crew, and only that crew.
    var crews: Set<CrewID>? = nil

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }

    /// A small square at the foot of the screen, middle, for a way in with
    /// nothing on screen to grow out of.
    @MainActor
    static func foot() -> CGRect {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        let bounds = window?.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
        let bottom = window?.safeAreaInsets.bottom ?? 34
        let side: CGFloat = 64
        return CGRect(x: bounds.midX - side / 2, y: bounds.maxY - bottom - side - GridConstants.gapItem,
                      width: side, height: side)
    }
}

/// **The rectangle a tap just came from**, for the ways in that reach Add a
/// Win through a closure with no room for one (a crew's tower calls up to the
/// root with only the crew). Taken once, and only while fresh: a stale one
/// would grow the card out of something nobody just touched.
@MainActor
enum AddWinFrom {
    private static var rect: CGRect?
    private static var at = Date.distantPast

    static func set(_ frame: CGRect) {
        rect = frame
        at = Date()
    }

    static func take() -> CGRect? {
        defer { rect = nil }
        return Date().timeIntervalSince(at) < 1 ? rect : nil
    }
}

/// A win made on the card, everything the add sheet would have saved.
struct DroppedWin {
    var photo: UIImage?
    var size: BlockSize
    var title: String
    var place: WinPlace?
    /// The crews named on the card (empty: your tower only).
    var crews: Set<CrewID>
    var colour: HabitCategory
    /// Chosen by a person rather than the slot's roll: a kind of win.
    var colourChosen: Bool
    var note: String?
    var with: [UUID]
    var story: Bool
    /// Which part of the photograph the block shows, and how far in.
    var window: CGPoint = .zero
    var zoom: CGFloat = 1
}

/// What the card hands back.
enum InlineCameraResult {
    /// Drop it onto the tower.
    case drop(DroppedWin)
    /// Send it in a chat (`InlineCameraCard.Purpose.send`).
    case send(UIImage)
    /// Everything else: the full sheet, holding whatever the card had.
    case sheet(WinDraft)
}

// MARK: - The card

/// **Add a Win, as a camera inside the screen you are on** (the owner,
/// 2026-10-17, with ChatGPT's inline camera as the reference: "the camera
/// rises as a rounded card inside the current screen, the page stays visible
/// above it, and the controls are a few soft glass buttons. Close, shutter,
/// flip").
///
/// It grows out of exactly what was tapped: the card is the slot, opened. The
/// viewfinder sits still at its final size and a rounded window over it opens
/// from the slot's rectangle to the card's, so nothing inside ever stretches,
/// as a card opening from the App Store's Today list shows what was under it.
/// Closing runs the same path back.
///
/// Three things live in it, one at a time: the live lens, the shot just
/// taken, and words (no photograph, never required). The shot and the words
/// both end the same way: a name if you want one, and Drop.
struct InlineCameraCard: View {
    let opening: AddWinOpening
    /// **One camera, two jobs** (the owner, 2026-10-17): a win, or a photo
    /// sent in a chat, snapped and sent in a second.
    enum Purpose { case win, send }
    var purpose: Purpose = .win
    /// Standing on the tab bar (the tower); off, on the screen's own foot
    /// (a chat in a sheet, where there is no bar).
    var standsOnBar = true
    let done: (InlineCameraResult?) -> Void

    private enum Mode: Equatable { case lens, shot, words }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var pageScheme
    @State private var open = false
    @State private var mode: Mode = InlineCamera.refused ? .words : .lens
    @State private var live = false
    @State private var shot: UIImage?
    @State private var place: WinPlace?

    // The win, as it is being made.
    @State private var title = ""
    @State private var size: BlockSize = .small
    @State private var colour: HabitCategory = .unlabeled
    @State private var colourChosen = false
    @State private var note = ""
    @State private var with: [UUID] = []
    /// **Who sees it, named on the card before it goes** (the second reader,
    /// 2026-10-17: nothing reaches a crew before a yes). The chip is the
    /// naming; the primary button is the yes.
    @State private var recipients: Set<CrewID> = []
    @State private var onStory = false
    @State private var high = ""
    @State private var low = ""
    @State private var buffalo = ""
    /// The rest of the details, tucked away until wanted.
    @State private var more = false

    // The photograph's tools, the Camera tab's review in one quiet row
    // (the owner, 2026-10-17: "crop, film looks/filters, doodle, stickers,
    // and adding your head. None of that goes away").
    @State private var lookRaw = FilmLook.Kind.none.rawValue
    @State private var looked: UIImage?
    @State private var choosingLook = false
    @State private var marks: InkDoodle?
    @State private var markLayer: UIImage?
    @State private var marking: PhotoMarksSheet.Opening?
    @State private var sticker: StickerPlacement?
    @State private var crop: CGPoint = .zero
    @State private var zoom: CGFloat = 1
    @State private var dropping = false
    /// Taken here rather than chosen from the library.
    @State private var fromCamera = false

    // The camera.
    @State private var down = false
    @State private var shutterScale: CGFloat = 1
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var frontFlash = false

    @State private var picking = false
    @State private var picked: PhotosPickerItem?
    @State private var drag: CGFloat = 0
    @State private var closing = false
    @State private var opened = CACurrentMediaTime()
    @FocusState private var naming: Bool
    /// The card's face, dissolving in over the slot and back out into it.
    @State private var shown = false
    /// Where the tab bar's top is, in the window: the card stands on it and
    /// the dim stops at it (2026-10-17). Nil where there is no bar.
    @State private var barTop: CGFloat? = TabGlyph.barFrame()?.minY

    private var camera: CameraService { InlineCamera.shared.camera }
    private var crews: [Crew] { CrewsFlag.isOn ? SocialStore.shared.groupCrews : [] }

    var body: some View {
        GeometryReader { geo in
            // In the window's space, whatever this is laid out in: at the root
            // the two agree, and in a sheet the sheet's top is moved down.
            let origin = CGPoint(x: geo.frame(in: .global).minX - geo.safeAreaInsets.leading,
                                 y: geo.frame(in: .global).minY - geo.safeAreaInsets.top)
            let target = cardFrame(in: geo, origin: origin)
            let from = opening.from.offsetBy(dx: -origin.x, dy: -origin.y)
            let frame = open ? target : from
            // **The slot, growing into the card**, as Photos grows a photo out
            // of its thumbnail: the card's face is scaled to cover the window
            // (aspect fill, never stretched) and the window's rounded edge is
            // the slot's at the start and the card's at the end. One spring.
            let cover = open ? 1 : max(frame.width / target.width, frame.height / target.height)
            ZStack {
                // The page stays, gently dimmed: it is still where you are.
                // Not the tab bar, which stays as it is under the card.
                VStack(spacing: 0) {
                    Color.black.opacity(open ? 0.22 : 0)
                        .frame(height: barTop.map { max($0 - origin.y - 4, 0) })
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                    if barTop != nil { Spacer(minLength: 0).allowsHitTesting(false) }
                }
                .accessibilityHidden(true)

                card(size: target.size)
                    .frame(width: target.width, height: target.height)
                    .opacity(shown ? 1 : 0)
                    .gesture(swipeDown)
                    .scaleEffect(cover)
                    .position(x: frame.midX, y: frame.midY + drag)
                    .mask {
                        RoundedRectangle(cornerRadius: open ? GridConstants.radiusSurface : opening.radius,
                                         style: .continuous)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY + drag)
                    }

                // The front camera's flash is the screen, lit warm for the
                // shot, as the Camera tab's is (`WarmRingLight`).
                if frontFlash {
                    WarmRingLight(fillOpacity: 1)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                   height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
        }
        .onAppear(perform: arrive)
        .onChange(of: picked) { _, item in Task { await take(item) } }
        .photosPicker(isPresented: $picking, selection: $picked, matching: .images)
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.didStartRunningNotification)) { note in
            guard (note.object as? AVCaptureSession) === camera.session else { return }
            showLive()
        }
    }

    /// The lens: low on the screen, full width less the margins, a
    /// photograph's 3:4. The win's details and the words: the whole height
    /// from under the status bar to the tab bar, so nothing is cramped.
    /// Never taller than the room above the keyboard.
    private func cardFrame(in geo: GeometryProxy, origin: CGPoint) -> CGRect {
        let inset = geo.safeAreaInsets
        let margin = GridConstants.gapTight
        let width = geo.size.width - margin * 2
        // On the tab bar, or above the keyboard when that is higher.
        let floor = min(inset.top + geo.size.height, barTop.map { $0 - origin.y } ?? .infinity) - margin
        let room = floor - inset.top - GridConstants.gapItem * 2
        let tall = purpose == .win && mode != .lens
        let height = tall ? max(room, 0) : min(width * 4 / 3, room)
        return CGRect(x: margin, y: floor - height, width: width, height: height)
    }

    // MARK: The card's face

    @ViewBuilder
    private func card(size: CGSize) -> some View {
        switch mode {
        case .lens:
            ZStack {
                // The slot's own clear glass, never a colour, under the lens
                // for the moment before the first frame (the owner, 2026-10-17:
                // "morph its shape only, not its colour").
                Rectangle().fill(.ultraThinMaterial)
                    .environment(\.colorScheme, pageScheme)
                lens(size: size)
                    .opacity(live ? 1 : 0)
                if camera.showsGuides { guides }
                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 96, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .legibleOnImagery()
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("\(countdown) seconds")
                }
                lensControls
                    .opacity(open ? 1 : 0)
            }
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
        case .shot where purpose == .send:
            sendPage(size: size)
                .environment(\.colorScheme, .dark)
        case .shot, .words:
            ZStack {
                WarmBackground()
                VStack(spacing: GridConstants.gapItem) {
                    pageTop
                    if mode == .shot { shotPage } else { wordsPage }
                    pageFoot
                }
                .padding(GridConstants.gapItem)
                .opacity(open ? 1 : 0)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func lens(size: CGSize) -> some View {
        ZStack {
            CameraPreview(session: camera.session, box: InlineCamera.shared.box, camera: camera)
            #if DEBUG
            if let fake = FakeLens.shared {
                FakeLensView(lens: fake)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            #endif
            if camera.facing == .front {
                RetouchPreview(retouch: camera.retouch)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    /// Rule of thirds, hairlines, as the Camera tab draws its own.
    private var guides: some View {
        GeometryReader { g in
            Path { p in
                for i in 1...2 {
                    let x = g.size.width * CGFloat(i) / 3, y = g.size.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: g.size.height))
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.45), lineWidth: GridConstants.strokeThin)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: The lens's controls

    /// **The camera's layout, everywhere a camera opens** (the owner,
    /// 2026-10-17: "flash on the left, flip on the right, shutter in the
    /// middle. A '...' holds the extras: a timer and a rule-of-thirds grid").
    /// Close at the top left; Just Words and the extras at the top right, so
    /// a win with no photo is one clear tap.
    private var lensControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: GridConstants.gapTight) {
                glassGlyph("xmark", label: "Close") { close() }
                Spacer(minLength: 0)
                if purpose == .win { pill("Just Words", systemImage: "textformat") { toWords() } }
                extras
            }
            Spacer(minLength: 0)
            HStack {
                glassGlyph(flashSymbol, label: flashLabel) {
                    camera.cycleFlash()
                }
                Spacer(minLength: 0)
                shutter
                Spacer(minLength: 0)
                glassGlyph("arrow.triangle.2.circlepath", label: "Switch camera") {
                    withAnimation(GridConstants.motionSnappy) { camera.flip() }
                }
            }
        }
        .padding(GridConstants.gapItem)
    }

    private var flashSymbol: String {
        switch camera.flash {
        case .off: "bolt.slash"
        case .auto: "bolt.badge.automatic"
        case .on: "bolt.fill"
        }
    }

    private var flashLabel: String {
        switch camera.flash {
        case .off: "Flash off"
        case .auto: "Flash auto"
        case .on: "Flash on"
        }
    }

    /// The extras, kept out of the way: the timer and the grid, and the other
    /// ways to make a win.
    private var extras: some View {
        Menu {
            Picker("Timer", selection: Binding(get: { camera.timerSeconds }, set: { seconds in
                camera.timerSeconds = seconds
                UserDefaults.standard.set(seconds, forKey: "cameraTimerSeconds")
            })) {
                Text("Timer Off").tag(0)
                Text("3 Seconds").tag(3)
                Text("10 Seconds").tag(10)
            }
            Toggle("Grid", systemImage: "grid", isOn: Binding(get: { camera.showsGuides }, set: { on in
                camera.showsGuides = on
                UserDefaults.standard.set(on, forKey: "cameraShowsGuides")
            }))
            Divider()
            Button("Choose a Photo", systemImage: "photo.on.rectangle") { picking = true }
            if purpose == .win {
                Button("Draw It", systemImage: "scribble") { toSheet(drawing: true) }
            }
        } label: {
            glyphFace(camera.timerSeconds > 0 ? "timer" : "ellipsis")
        }
        .accessibilityLabel("More")
        .accessibilityValue(camera.timerSeconds > 0 ? "Timer \(camera.timerSeconds) seconds" : "")
    }

    /// A glyph on a soft glass disc, white, held legible over any picture as
    /// the Camera tab holds its own (`legibleOnImagery`).
    private func glassGlyph(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            glyphFace(symbol)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func glyphFace(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .iconSize(19, relativeTo: .body, weight: .semibold)
            .foregroundStyle(.white)
            .legibleOnImagery()
            .frame(width: 44, height: 44)
            .inlineGlass(in: Circle())
            .contentShape(Circle())
    }

    private func pill(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(Typography.headerSmall)
                .foregroundStyle(.white)
                .legibleOnImagery()
                .padding(.horizontal, GridConstants.gapLabel)
                .frame(minHeight: 44)
                .inlineGlass(in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: The shutter

    private var shutter: some View {
        ShutterBlock(size: size, lit: true, scale: shutterScale)
            .animation(GridConstants.slotSnap, value: size)
            .legibleOnImagery()
            .frame(width: CameraView.shutterBounds(.hard).width, height: CameraView.shutterBounds(.hard).height)
            .contentShape(Rectangle())
            .gesture(shutterDraw, isEnabled: camera.isLive || Self.fakeLens)
            .accessibilityLabel("Take photo")
            .accessibilityValue(size.effortLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { shutterPressed() }
    }

    private static var fakeLens: Bool {
        #if DEBUG
        FakeLens.shared != nil
        #else
        false
        #endif
    }

    /// A tap shoots one cell, and a drag draws the size and shoots on release
    /// (a plain drag, the owner, 2026-10-17).
    private var shutterDraw: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !down {
                    down = true
                    HapticsEngine.tick()
                }
                guard !reduceMotion else { return }
                let (lateral, up) = BlockSizeDraw.axes(translation: value.translation)
                let next = BlockSizeDraw.size(lateral: lateral, up: up, from: size)
                guard next != size else { return }
                HapticsEngine.snap()
                withAnimation(GridConstants.slotSnap) { size = next }
            }
            .onEnded { _ in
                guard down else { return }
                down = false
                shutterPressed()
            }
    }

    /// Through the timer when there is one; a press during it stops it.
    private func shutterPressed() {
        if let task = countdownTask {
            task.cancel()
            countdownTask = nil
            withAnimation(GridConstants.crossFade) { countdown = nil }
            HapticsEngine.lightTap()
            return
        }
        let seconds = camera.timerSeconds
        guard seconds > 0 else { shoot(); return }
        HapticsEngine.tick()
        countdown = seconds
        countdownTask = Task { @MainActor in
            var left = seconds
            while left > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                left -= 1
                withAnimation(GridConstants.crossFade) { countdown = left > 0 ? left : nil }
                if left > 0 { HapticsEngine.tick() }
            }
            countdownTask = nil
            shoot()
        }
    }

    private func shoot() {
        guard !camera.isCapturing else { return }
        HapticsEngine.lightTap()
        withAnimation(GridConstants.shutterPress) { shutterScale = 0.86 }
        withAnimation(GridConstants.shutterRelease.delay(0.08)) { shutterScale = 1 }
        place = LocationService.shared.place()
        let lit = camera.facing == .front && camera.flash == .on
        Task { @MainActor in
            if lit {
                withAnimation(GridConstants.crossFade) { frontFlash = true }
                try? await Task.sleep(for: .milliseconds(250))
            }
            camera.capture { image in Task { @MainActor in
                if lit { withAnimation(GridConstants.crossFade) { frontFlash = false } }
                guard let image else {
                    withAnimation(GridConstants.slotSnap) { size = .small }
                    return
                }
                let polished = await Task.detached(priority: .userInitiated) {
                    PortraitPolish.apply(to: image)
                }.value
                fromCamera = true
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardOpen) {
                    shot = polished
                    mode = .shot
                }
                camera.stop()
            } }
        }
    }

    // MARK: Sending

    /// **Snapped, then sent** (the owner, 2026-10-17: "Snap and send in a
    /// second"): the photograph, whole, and two things to do with it.
    private func sendPage(size: CGSize) -> some View {
        ZStack {
            Color.black
            if let shot {
                // The same stage and tools as a win's photo (the owner,
                // 2026-10-17: "everything that touches a photo feels like one
                // editor"), the picture whole and still.
                photoStage(shot, width: size.width, aspect: size.width / max(size.height, 1), still: true)
                if choosingLook {
                    FilmLookStrip(photo: shot, selection: Binding(
                        get: { FilmLook.Kind(rawValue: lookRaw) ?? .none },
                        set: { lookRaw = $0.rawValue }))
                        .frame(maxHeight: .infinity, alignment: .center)
                        .transition(.opacity)
                }
            }
            VStack {
                HStack {
                    glassGlyph("xmark", label: "Close") { close() }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                HStack {
                    glassGlyph("arrow.counterclockwise", label: "Retake") { backToLens() }
                    Spacer(minLength: 0)
                    Button {
                        guard let shot, !dropping else { return }
                        HapticsEngine.snap()
                        dropping = true
                        Task { @MainActor in leave(with: .send(await finished(shot))) }
                    } label: {
                        Label("Send", systemImage: "arrow.up")
                            .font(Typography.headerSmall)
                            .foregroundStyle(.black)
                            .padding(.horizontal, GridConstants.gapWide)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(.white))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel("Send it")
                }
            }
            .padding(GridConstants.gapItem)
            .opacity(open ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: The page: after the shot, and words

    /// Back to the lens (or to it for the first time) on the left; away on
    /// the right.
    private var pageTop: some View {
        HStack {
            if mode == .shot || !InlineCamera.refused {
                GlassIconButton(systemName: mode == .shot ? "arrow.counterclockwise" : "camera", onPage: true,
                                accessibilityLabel: mode == .shot ? "Retake" : "Camera") { backToLens() }
            }
            Spacer(minLength: 0)
            GlassIconButton(systemName: "xmark", onPage: true, accessibilityLabel: "Close") { close() }
        }
    }

    /// **After the photo, one clean page** (the owner, 2026-10-17: "Don't put
    /// text over the photo itself. Put the details in a clean container above
    /// the photo ... the essentials up front, the rest tucked away until
    /// wanted"). Name, size and who sees it, then More; the photograph under
    /// them, nothing written on it.
    private var shotPage: some View {
        VStack(spacing: GridConstants.gapItem) {
            // **More takes the photograph's room while it is open**: the
            // details scroll there, and Less brings the picture back. Both
            // at once ran the page off the card under the keyboard.
            if more {
                ScrollView(.vertical, showsIndicators: false) { details }
                    .scrollDismissesKeyboard(.interactively)
                    .softScrollEdge([.top, .bottom])
            } else {
                details
            }
            // The photograph in the room that is left, whole, never scrolled:
            // a drag on it moves the picture under the block's frame.
            if let shot, !more {
                GeometryReader { g in
                    let width = min(g.size.width, g.size.height * size.cropAspectRatio)
                    photoStage(shot, width: max(width, 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .animation(GridConstants.slotSnap, value: size)
                if choosingLook {
                    FilmLookStrip(photo: shot, selection: Binding(
                        get: { FilmLook.Kind(rawValue: lookRaw) ?? .none },
                        set: { lookRaw = $0.rawValue }))
                        .transition(.opacity)
                }
            }
        }
    }

    /// **The photograph as the block will show it**: the block's frame, the
    /// picture moved and pinched under it (the head overlay carries both
    /// gestures, as on the Camera tab's review), the drawing and the head on
    /// it, the look on it. The tools stand along its foot, small and quiet,
    /// and each opens only when pressed.
    private func photoStage(_ image: UIImage, width: CGFloat, aspect: CGFloat? = nil, still: Bool = false) -> some View {
        let box = CGSize(width: width, height: width / max(aspect ?? size.cropAspectRatio, 0.01))
        let rests = CachedImageView.filled(image.size, in: box)
        let shift = CachedImageView.shift(crop: crop, photo: image.size, frame: box, zoom: zoom)
        // The tools along the foot; on a chat's photo, whose foot holds
        // Retake and Send, along the top right instead.
        return ZStack(alignment: still ? .topTrailing : .bottomLeading) {
            Image(uiImage: looked ?? image)
                .resizable()
                .frame(width: rests.width, height: rests.height)
                .overlay {
                    if let markLayer {
                        Image(uiImage: markLayer).resizable()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    // `still`: a photo sent whole, which the finger does not
                    // move (a chat's); the head still moves on it.
                    HeadStickerOverlay(
                        rig: sticker == nil ? nil : HeadStore.shared.head,
                        placement: $sticker, crop: still ? .constant(.zero) : $crop,
                        zoom: still ? .constant(1) : $zoom,
                        photo: image.size, box: box,
                        look: FilmLook.look(FilmLook.Kind(rawValue: lookRaw) ?? .none))
                }
                .scaleEffect(PhotoWindow.zoom(zoom))
                .offset(shift)
                .frame(width: box.width, height: box.height)
                .clipShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
                .accessibilityLabel("Your photo")
            photoTools
                .padding(GridConstants.gapTight)
        }
        .frame(width: box.width, height: box.height)
        .task(id: lookRaw) { await showLook(on: image) }
        .sheet(item: $marking) { opening in
            PhotoMarksSheet(photo: looked ?? image, marks: marks, opening: opening) { made in
                marks = made
                markLayer = made.flatMap { PhotoMarks.layer($0) }
            }
        }
    }

    private var photoTools: some View {
        HStack(spacing: GridConstants.gapTight) {
            toolGlyph("camera.filters", label: "Looks", on: choosingLook || lookRaw != FilmLook.Kind.none.rawValue) {
                withAnimation(GridConstants.motionSnappy) { choosingLook.toggle() }
            }
            toolGlyph("pencil.tip", label: "Draw", on: marks != nil) { marking = .pen }
            toolGlyph("sparkles", label: "Stickers", on: false) { marking = .stickers }
            if HeadStore.shared.head != nil {
                toolGlyph("face.smiling", label: sticker == nil ? "Add your head" : "Take your head off", on: sticker != nil) {
                    withAnimation(GridConstants.motionSnappy) {
                        sticker = sticker == nil ? StickerPlacement() : nil
                    }
                }
            }
        }
    }

    private func toolGlyph(_ symbol: String, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            Image(systemName: symbol)
                .iconSize(16, relativeTo: .body, weight: .semibold)
                .foregroundStyle(on ? Color.black : .white)
                .frame(width: 36, height: 36)
                .background { if on { Circle().fill(.white) } }
                .inlineGlass(in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func showLook(on image: UIImage) async {
        let look = FilmLook.look(FilmLook.Kind(rawValue: lookRaw) ?? .none)
        guard look.kind != .none else { looked = nil; return }
        let rendered = await Task.detached(priority: .userInitiated) {
            FilmLookRenderer.shared.render(image.scaledDown(to: 1400), look: look)
        }.value
        if !Task.isCancelled { looked = rendered }
    }

    /// The essentials in one container, the rest under More.
    private var details: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            TextField("", text: $title, prompt: Text("Name it, if you want").foregroundStyle(AppColors.inkTertiary))
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .submitLabel(.done)
                .focused($naming)
                .frame(minHeight: 44)
            sizeBar
            recipientsRow
            moreDetails
        }
        .padding(GridConstants.gapItem)
        .pageCard()
    }

    private var sizeBar: some View {
        GlassChoiceBar(items: [BlockSize.small, .medium, .hard], chosen: size,
                       title: { $0.effortLabel }, spoken: { $0.effortLabel },
                       choose: { chosen in withAnimation(GridConstants.slotSnap) { size = chosen } },
                       fills: true)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Size")
    }

    /// **Words are written on the block** (the owner, 2026-10-17: "it should
    /// feel like writing directly on the block itself: the block in front of
    /// you, the cursor on it, your words appearing on it as you type"). The
    /// block at its size and in its colour, the words in the tower's own type
    /// where the tower puts them, so what lands is exactly what was written.
    private var wordsPage: some View {
        VStack(spacing: GridConstants.gapItem) {
            if InlineCamera.refused { cameraOff }
            Spacer(minLength: 0)
            WordBlock(title: $title, size: size, colour: colour, focus: $naming)
                .animation(GridConstants.slotSnap, value: size)
                .animation(GridConstants.motionSnappy, value: colour)
            Spacer(minLength: 0)
            ColourSwatchRow(category: $colour) { _ in colourChosen = true }
                .frame(maxWidth: .infinity)
            sizeBar
            recipientsRow
        }
    }

    /// Who sees it, and what more there is to say.
    @ViewBuilder
    private var recipientsRow: some View {
        if !crews.isEmpty {
            let store = SocialStore.shared
            let names = crews.filter { recipients.contains($0.id) }.map { $0.displayName(excluding: store.me) }
            let words = names.isEmpty ? "Just you" : names.count == 1 ? names[0] : "\(names[0]) and \(names.count - 1) more"
            Menu {
                Toggle("Just Me", isOn: Binding(get: { recipients.isEmpty }, set: { if $0 { recipients = [] } }))
                ForEach(crews) { crew in
                    Toggle(crew.displayName(excluding: store.me),
                           isOn: Binding(get: { recipients.contains(crew.id) },
                                         set: { if $0 { recipients.insert(crew.id) } else { recipients.remove(crew.id) } }))
                }
                Divider()
                Toggle("Tonight's Story", systemImage: "moon.stars", isOn: $onStory)
            } label: {
                HStack(spacing: GridConstants.spacing) {
                    Text("To").foregroundStyle(AppColors.inkSecondary)
                    Text(words + (onStory ? ", and tonight's story" : "")).foregroundStyle(AppColors.inkPrimary).lineLimit(1)
                    Image(systemName: "chevron.down").foregroundStyle(AppColors.inkTertiary)
                }
                .font(Typography.headerSmall)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuActionDismissBehavior(.disabled)
            .accessibilityLabel("Sending to \(words)")
            .accessibilityHint("Choose who sees it.")
        }
    }

    /// The rest of what the add sheet held, one press away and never in the
    /// way: the colour (for a photograph, which mostly covers it), a note,
    /// who you were with, and tonight's high, low and buffalo.
    @ViewBuilder
    private var moreDetails: some View {
        Button {
            HapticsEngine.tick()
            if !more {
                let words = SocialStore.shared.storyWords(on: DateUtils.dateString(from: Date()))
                if high.isEmpty, low.isEmpty, buffalo.isEmpty { (high, low, buffalo) = (words.high, words.low, words.buffalo) }
            }
            withAnimation(GridConstants.motionSnappy) { more.toggle() }
        } label: {
            HStack {
                Text(more ? "Less" : "More")
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").rotationEffect(.degrees(more ? 180 : 0))
            }
            .font(Typography.headerSmall)
            .foregroundStyle(AppColors.inkSecondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityLabel(more ? "Fewer details" : "More details")
        if more {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                ColourSwatchRow(category: $colour, showsSelection: colourChosen) { _ in colourChosen = true }
                TextField("", text: $note, prompt: Text("A note, just for you").foregroundStyle(AppColors.inkTertiary),
                          axis: .vertical)
                    .font(Typography.bodyLarge)
                    .lineLimit(1...4)
                if !recipients.isEmpty {
                    CrewWithRow(crews: recipients, selection: $with)
                }
                Text("Tonight's high, low and buffalo")
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkSecondary)
                ForEach([("High", $high), ("Low", $low), ("Buffalo", $buffalo)], id: \.0) { word, text in
                    TextField("", text: text, prompt: Text(word).foregroundStyle(AppColors.inkTertiary))
                        .font(Typography.bodyLarge)
                        .frame(minHeight: 36)
                }
            }
            .transition(.opacity)
        }
    }

    private var cameraOff: some View {
        VStack(spacing: GridConstants.gapTight) {
            Text("The camera is off for \(AppName.display).")
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
            Button {
                HapticsEngine.lightTap()
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("Turn It On in Settings")
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkPrimary)
                    .padding(.horizontal, GridConstants.gapLabel)
                    .frame(minHeight: 44)
                    .glassCapsule(onPage: true)
            }
            .buttonStyle(.plain)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// One tap posts: Add, or Post when it goes to a crew or the story.
    private var pageFoot: some View {
        PrimaryCapsule(title: !recipients.isEmpty || onStory ? "Post" : "Add") { if !dropping { drop() } }
            .accessibilityLabel("Drop it on the tower")
    }

    // MARK: Going

    private func arrive() {
        opened = CACurrentMediaTime()
        if !standsOnBar { barTop = nil }
        recipients = opening.crews ?? CrewChoice.load()
        colour = opening.colour
        HapticsEngine.lightTap()
        if mode == .lens {
            Task {
                // **Nothing on the first frames but the motion.** The session
                // starts on its own queue; asking for it waits a frame so the
                // first composite is the card's, and location waits for it.
                try? await Task.sleep(for: .milliseconds(16))
                await InlineCamera.shared.camera.start()
                if Self.fakeLens { showLive() }
                // Asked just now, and refused: words, with the way back on.
                if camera.isDenied { toWords() }
                try? await Task.sleep(for: .milliseconds(400))
                if !closing { LocationService.shared.start() }
            }
        } else {
            naming = true
        }
        withAnimation(GridConstants.cardFaceIn) { shown = true }
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardOpen) { open = true }
    }

    /// The first frame is on its way: the lens shows over the ground.
    private func showLive() {
        guard !live else { return }
        #if DEBUG
        PerfProbe.duration("InlineCamera.tapToLive", since: opened)
        #endif
        withAnimation(GridConstants.crossFade) { live = true }
    }

    private func toWords() {
        camera.stop()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardOpen) {
            mode = .words
            shot = nil
        }
        naming = true
    }

    private func backToLens() {
        naming = false
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardOpen) {
            shot = nil
            mode = .lens
            size = .small
        }
        (lookRaw, looked, choosingLook, marks, markLayer, sticker, crop, zoom) =
            (FilmLook.Kind.none.rawValue, nil, false, nil, nil, nil, .zero, 1)
        Task { await camera.start() }
    }

    private func drop() {
        let photo = mode == .shot ? shot : nil
        guard photo != nil || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            naming = true
            return
        }
        HapticsEngine.snap()
        // Your usual next time, unless a crew's own camera chose for you.
        if opening.crews == nil, !crews.isEmpty { CrewChoice.save(recipients) }
        // Tonight's words, kept as Send To keeps them.
        let today = DateUtils.dateString(from: Date())
        var words = SocialStore.shared.storyWords(on: today)
        if more, (words.high, words.low, words.buffalo) != (high, low, buffalo) {
            words.high = high; words.low = low; words.buffalo = buffalo
            Task { await SocialStore.shared.setStoryWords(words, on: today) }
        }
        let kept = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var win = DroppedWin(photo: nil, size: size, title: title, place: photo == nil ? nil : place,
                             crews: crews.isEmpty ? [] : recipients, colour: colour,
                             colourChosen: colourChosen || mode == .words,
                             note: kept.isEmpty ? nil : kept, with: with, story: onStory)
        guard let photo else { leave(with: .drop(win)); return }
        // The photograph as the tools left it: the head, then the look, then
        // the drawing, as the Camera tab's Use Photo makes it, and its window.
        dropping = true
        win.window = CachedImageView.held(crop, photo: photo.size, frame: CGSize(width: size.cropAspectRatio, height: 1),
                                          zoom: PhotoWindow.zoom(zoom))
        win.zoom = PhotoWindow.zoom(zoom)
        Task { @MainActor in
            let finished = await finished(photo)
            // A photograph taken here is kept in the library, as the Camera
            // tab keeps its own; one chosen from the library is already there.
            if fromCamera { Task { await PhotoLibrarySaver.save(finished) } }
            win.photo = finished
            leave(with: .drop(win))
        }
    }

    /// The photograph as the tools left it: the head, then the look, then
    /// the drawing, as the Camera tab's Use Photo makes it.
    private func finished(_ photo: UIImage) async -> UIImage {
        let look = FilmLook.look(FilmLook.Kind(rawValue: lookRaw) ?? .none)
        var composed = photo
        if let placement = sticker, let rig = HeadStore.shared.head {
            composed = HeadSticker.composite(photo, rig: rig, placement: placement)
        }
        let base = composed
        let graded = look.kind == .none ? base : await Task.detached(priority: .userInitiated) {
            FilmLookRenderer.shared.render(base, look: look)
        }.value
        return marks.map { PhotoMarks.composite(graded, marks: $0) } ?? graded
    }

    private func toSheet(drawing: Bool = false) {
        var draft = WinDraft(title: title.isEmpty ? nil : title, photo: mode == .shot ? shot : nil,
                             size: size, place: mode == .shot ? place : nil)
        draft.colour = nil
        draft.crews = opening.crews
        draft.opensDrawing = drawing
        leave(with: .sheet(draft))
    }

    private func take(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        camera.stop()
        fromCamera = false
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardOpen) {
            shot = image
            mode = .shot
            place = nil
        }
    }

    private func close() { leave(with: nil) }

    /// Back the way it came, then gone.
    private func leave(with result: InlineCameraResult?) {
        guard !closing else { return }
        closing = true
        naming = false
        countdownTask?.cancel()
        // A drop hands over at once, so the block is already falling while
        // the card folds back into the slot it is falling toward.
        let handsOver: Bool = { switch result { case .drop?, .send?: true; default: false } }()
        if handsOver { done(result) }
        withAnimation(GridConstants.cardFaceOut) { shown = false }
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardClose) {
            open = false
            drag = 0
        } completion: {
            // Stopped after the motion, not at its start (filmed, 2026-10-17).
            camera.stop()
            LocationService.shared.stop()
            if handsOver { done(nil) } else { done(result) }
        }
    }

    /// Down, and it tucks away.
    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard mode == .lens || !naming else { return }
                drag = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 260 {
                    close()
                } else {
                    withAnimation(GridConstants.slotSnap) { drag = 0 }
                }
            }
    }
}

/// **The block, written on** (`InlineCameraCard`'s words). The tower's own
/// block at its size and colour, drawn at the tower's cell and scaled up so
/// it can be written on comfortably: the words sit where a block's title
/// sits, in its type, so what lands on the tower is what was typed here.
private struct WordBlock: View {
    @Binding var title: String
    let size: BlockSize
    let colour: HabitCategory
    var focus: FocusState<Bool>.Binding

    private var cell: CGFloat { GridConstants.blockReferenceCell }
    private var gutter: CGFloat { GridConstants.spacing }
    private var blockSize: CGSize {
        CGSize(width: cell * CGFloat(size.columnSpan) + gutter * CGFloat(size.columnSpan - 1),
               height: cell * CGFloat(size.rowSpan) + gutter * CGFloat(size.rowSpan - 1))
    }

    var body: some View {
        GeometryReader { g in
            let scale = min(g.size.width / blockSize.width, g.size.height / blockSize.height, 2.6)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: cell), style: .continuous)
                    .fill(colour.style.baseColor)
                TextField("", text: $title, prompt: Text("What went right?").foregroundStyle(.white.opacity(0.6)),
                          axis: .vertical)
                    .font(BlockContentOverlay.titleFont)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .lineLimit(1...3)
                    .submitLabel(.done)
                    .focused(focus)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .padding(.bottom, 10)
            }
            .frame(width: blockSize.width, height: blockSize.height)
            .scaleEffect(scale)
            .frame(width: g.size.width, height: g.size.height)
        }
        .frame(maxHeight: 260)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your block")
    }
}

// MARK: - The card's glass

private extension View {
    /// **A soft dark disc of glass**, as the reference camera's are: the
    /// card's controls sit on a picture that can be a white wall, and clear
    /// glass there lets a white glyph vanish (seen, 2026-10-17: More and Retake
    /// were all but gone over a white page). A fifth of black in the glass
    /// keeps the glyph's ground without becoming a dark button.
    @ViewBuilder
    func inlineGlass(in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(.black.opacity(0.22)).interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .environment(\.colorScheme, .dark)
        }
    }
}
