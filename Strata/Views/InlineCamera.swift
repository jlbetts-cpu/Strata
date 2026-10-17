import AVFoundation
import AVKit
import PhotosUI
import SwiftUI

// MARK: - The tabs

/// **Add a Win is the camera** (the owner, 2026-10-17: "the camera IS the
/// Add a Win sheet"; 2026-10-18: "The inline camera is the camera, reachable
/// everywhere it's needed", no switch and no Camera tab).
extension StrataTab {
    /// The tabs the bar shows, in its order.
    static var visible: [StrataTab] {
        allCases.filter { tab in
            switch tab {
            case .crews: CrewsFlag.isOn
            // Three tabs (the owner, 2026-10-18): the camera is the card.
            case .camera: false
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
    /// From a plan line's box: its words, its size, and the line to tick.
    var title = ""
    var size: BlockSize = .small
    var planItemID: UUID? = nil
    /// A photograph to begin from (a plan line's from the library, a chat's
    /// picture kept as a win): the card opens on it, ready to name.
    var photo: UIImage? = nil
    /// Opens on the block to write on, no camera (a plan line logged
    /// without a photo, one of your three).
    var words = false
    /// Opens on the block with the pen out (Draw It).
    var drawing = false
    /// Told of the win once it is made (a chat says it in the chat).
    var afterSaved: ((Habit) -> Void)? = nil

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
    /// A drawn block (Draw It): its strokes and stickers.
    var doodle: InkDoodle? = nil
}

/// What the card hands back.
enum InlineCameraResult {
    /// Drop it onto the tower.
    case drop(DroppedWin)
    /// Send it in a chat (`InlineCameraCard.Purpose.send`).
    case send(UIImage)
    /// Today's photos, several at once (`QuickAddSheet`).
    case quickAdd
    /// **Planned instead** (the owner, 2026-10-18: "Put 'plan this instead'
    /// in the '...' of the Add sheet"): the words, for the day chosen.
    case plan(PlanScope, String)
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
    /// **The Camera tab's camera**: always open, nothing to grow from or
    /// fold into, no close; after a win it goes back to the lens.
    var docked = false
    let done: (InlineCameraResult?) -> Void

    private enum Mode: Equatable { case lens, shot, words }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var pageScheme
    @State private var open = false
    @State private var mode: Mode = InlineCamera.refused ? .words : .lens
    /// A drawn block (Draw It), and its pen open.
    @State private var doodle: InkDoodle?
    @State private var doodling = false
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
    /// Which of "..."'s details is being written (`WinDetailsSheet`).
    @State private var details: WinDetailsSheet.Which?

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
    /// The lens row written out, and a pinch or the focus square up (the
    /// card's swipe down waits for those).
    @State private var lensesOpen = false
    @State private var lensBusy = false
    /// "Drag out for a bigger block", over the shutter, the first few times.
    @State private var drawCue = false

    @State private var picking = false
    @State private var picked: PhotosPickerItem?
    @State private var drag: CGFloat = 0
    @State private var closing = false
    @State private var opened = CACurrentMediaTime()
    @FocusState private var naming: Bool
    /// The picture just taken, the same one on the lens and as the hero, so
    /// it moves from one to the other (the owner, 2026-10-18: "the photo you
    /// just took grows into the hero, no cut").
    @Namespace private var heroSpace
    /// The editor's controls, in a beat after the picture has moved into
    /// place: the picture leads, nothing ghosts over it (filmed, 2026-10-18:
    /// a crossfade of the whole card read as a cut).
    @State private var chromeIn = true
    /// The card's face, dissolving in over the slot and back out into it.
    @State private var shown = false
    /// Where the tab bar's top is, in the window: the card stands on it and
    /// the dim stops at it (2026-10-17). Nil where there is no bar.
    @State private var barTop: CGFloat? = TabGlyph.barFrame()?.minY

    private var camera: CameraService { InlineCamera.shared.camera }
    /// The ring is lit: the lens faces you, the flash is on, the card is on
    /// the lens.
    private var ringIsArmed: Bool { mode == .lens && open && !closing && camera.isFlashOn && camera.usesScreenFlash }
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
                    Color.black.opacity(open && !docked ? 0.22 : 0)
                        .frame(height: barTop.map { max($0 - origin.y - 4, 0) })
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                    if barTop != nil { Spacer(minLength: 0).allowsHitTesting(false) }
                }
                .accessibilityHidden(true)

                card(size: target.size)
                    .frame(width: target.width, height: target.height)
                    .opacity(shown ? 1 : 0)
                    .gesture(swipeDown, isEnabled: !docked)
                    .scaleEffect(cover)
                    .position(x: frame.midX, y: frame.midY + drag)
                    .mask {
                        RoundedRectangle(cornerRadius: open ? GridConstants.radiusSurface : opening.radius,
                                         style: .continuous)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY + drag)
                    }

                // **The front flash is the ring, held while you compose**
                // (the old camera's, and the owner's: "The ring is enough
                // ... the person still needs to be visible enough to admire
                // themselves"). No blast at the shot, and no wait for one.
                WarmRingLight(fillOpacity: WarmRingLight.modellingFill)
                    .opacity(ringIsArmed ? WarmRingLight.modellingLevel : 0)
                    .animation(GridConstants.screenFlashOut, value: ringIsArmed)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                   height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
        }
        .onAppear(perform: arrive)
        // **Gone without folding away** (a tab changed, the chat closed: the
        // second reader, 2026-10-17): nothing keeps running behind it.
        .onDisappear {
            countdownTask?.cancel()
            camera.stop()
            LocationService.shared.stop()
            RingBrightness.restore()
        }
        // The screen at full brightness while the ring is lit, as the old
        // camera's (`RingBrightness`), and back after.
        .onChange(of: ringIsArmed) { _, armed in if armed { RingBrightness.raise() } else { RingBrightness.restore() } }
        // **The volume buttons and Camera Control take the shot**, as every
        // camera on the phone, the Camera tab's included (`docs/camera.md`).
        .onCameraCaptureEvent(isEnabled: mode == .lens && open && !closing && (camera.isLive || Self.fakeLens)) { event in
            if event.phase == .ended { shutterPressed() }
        }
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
                // The lens held on the picture it took, for the frame before
                // it becomes the hero.
                if let shot {
                    Image(uiImage: shot)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .matchedGeometryEffect(id: "picture", in: heroSpace)
                        .accessibilityHidden(true)
                }
                if camera.showsGuides { guides }
                // Pinch, tap to focus, drag to expose, double tap to flip.
                LensGestureLayer(camera: camera, box: InlineCamera.shared.box,
                                 lensesOpen: $lensesOpen, busy: $lensBusy)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(live && countdown == nil)
                if let countdown {
                    Text("\(countdown)")
                        // The owner's own numerals, as the old camera's.
                        .font(Typography.numeral(96))
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
            // Gone at once under the editor's ground: the picture is what
            // moves, not two cards fading through each other.
            .transition(.identity)
        case .shot where purpose == .send:
            sendPage(size: size)
                .environment(\.colorScheme, .dark)
        case .shot, .words:
            composer(size: size)
                .transition(.identity)
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
                if !docked { glassGlyph("xmark", label: "Close") { close() } }
                Spacer(minLength: 0)
                if purpose == .win { pill("Just Words", systemImage: "textformat") { toWords() } }
                extras
            }
            Spacer(minLength: 0)
            // Stacked above the pill, never on it (the pill's row was hidden
            // under it, 2026-10-18).
            if drawCue {
                Text("Drag out for a bigger block")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(.white)
                    .fixedSize()
                    .padding(.horizontal, GridConstants.gapItem)
                    .frame(height: 30)
                    .lensGlass()
                    .padding(.bottom, GridConstants.gapTight)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            LensPill(camera: camera, open: $lensesOpen)
                .padding(.bottom, GridConstants.gapTight)
            HStack {
                glassGlyph(CameraView.flashSymbol(camera.flash), label: flashLabel, dim: !camera.isFlashOn) {
                    camera.cycleFlash()
                }
                Spacer(minLength: 0)
                shutter
                Spacer(minLength: 0)
                glassGlyph("arrow.triangle.2.circlepath", label: "Switch camera") {
                    if lensesOpen { withAnimation(GridConstants.motionSnappy) { lensesOpen = false } }
                    withAnimation(GridConstants.motionSnappy) { camera.flip() }
                }
            }
        }
        .padding(GridConstants.gapItem)
        // **A camera's controls hold their size**, as Apple's Camera does at
        // every text size: grown, the pill covered the picture and the glyphs
        // left their discs (filmed at the largest size, 2026-10-17). Their
        // names stay readable through the large content viewer.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
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
                Button("Draw It", systemImage: "scribble") { drawIt() }
                Button("Today's Photos", systemImage: "photo.stack") { leave(with: .quickAdd) }
            }
        } label: {
            glyphFace(camera.timerSeconds > 0 ? "timer" : "ellipsis",
                      badge: camera.timerSeconds > 0 ? camera.timerSeconds : nil)
        }
        .accessibilityLabel("More")
        .accessibilityValue(camera.timerSeconds > 0 ? "Timer \(camera.timerSeconds) seconds" : "")
    }

    /// A glyph on a soft glass disc, white, held legible over any picture as
    /// the Camera tab holds its own (`legibleOnImagery`).
    private func glassGlyph(_ symbol: String, label: String, dim: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            glyphFace(symbol, dim: dim)
        }
        // The app's press, as the old camera's glyphs had.
        .buttonStyle(.press)
        .accessibilityLabel(label)
    }

    /// `dim`: off (the flash), at the old camera's quieter white.
    private func glyphFace(_ symbol: String, dim: Bool = false, badge: Int? = nil) -> some View {
        Image(systemName: symbol)
            .iconSize(19, relativeTo: .body, weight: .semibold)
            .foregroundStyle(.white.opacity(dim ? 0.6 : 1))
            .legibleOnImagery()
            // The timer's seconds, beside its glyph, as the old camera's.
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(verbatim: "\(badge)")
                        .font(Typography.headerSmall)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .legibleOnImagery()
                        .offset(x: 10, y: -8)
                }
            }
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
        .buttonStyle(.press)
    }

    // MARK: The shutter

    private var shutter: some View {
        ShutterBlock(size: size, lit: true, scale: shutterScale)
            .animation(GridConstants.slotSnap, value: size)
            .legibleOnImagery()
            .frame(width: CameraView.shutterBounds(.hard).width, height: CameraView.shutterBounds(.hard).height)
            .contentShape(Rectangle())
            // **What it does, said once, small, where it is** (the old
            // camera's cue): over the shutter, the first three visits, until
            // a block has been drawn out once.
            .task {
                let seen = UserDefaults.standard.integer(forKey: CameraView.drawCueKey)
                guard purpose == .win, seen < 3, !UserDefaults.standard.bool(forKey: CameraView.drawTaughtKey) else { return }
                UserDefaults.standard.set(seen + 1, forKey: CameraView.drawCueKey)
                try? await Task.sleep(for: .seconds(1))
                withAnimation(GridConstants.crossFade) { drawCue = true }
                try? await Task.sleep(for: .seconds(5))
                withAnimation(GridConstants.crossFade) { drawCue = false }
            }
            .onChange(of: size) { _, now in
                guard now != .small, mode == .lens else { return }
                UserDefaults.standard.set(true, forKey: CameraView.drawTaughtKey)
                withAnimation(GridConstants.crossFade) { drawCue = false }
            }
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
            .onEnded { value in
                guard down else { return }
                down = false
                // Drawn while a countdown runs: the shot in flight changes
                // size rather than stopping (the old camera's rule).
                let moved = hypot(value.translation.width, value.translation.height) > 6
                if moved, countdownTask != nil { return }
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
        HapticsEngine.snap()
        withAnimation(GridConstants.shutterPress) { shutterScale = 0.86 }
        withAnimation(GridConstants.shutterRelease.delay(0.08)) { shutterScale = 1 }
        place = purpose == .win ? LocationService.shared.place() : nil
        Task { @MainActor in
            camera.capture { image in Task { @MainActor in
                guard let image else {
                    withAnimation(GridConstants.slotSnap) { size = .small }
                    return
                }
                let polished = await Task.detached(priority: .userInitiated) {
                    PortraitPolish.apply(to: image)
                }.value
                fromCamera = true
                HapticsEngine.lightTap()
                // Held on the lens for a frame, then grown into the hero.
                shot = polished
                camera.stop()
                try? await Task.sleep(for: .milliseconds(34))
                chromeIn = reduceMotion
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardOpen) {
                    mode = .shot
                }
                withAnimation(GridConstants.cardFaceIn.delay(0.18)) { chromeIn = true }
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
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: The page: after the shot, and words

    /// **The photograph as the block will show it**: the block's frame, the
    /// picture moved and pinched under it (the head overlay carries both
    /// gestures, as on the Camera tab's review), the drawing and the head on
    /// it, the look on it. The tools stand along its foot, small and quiet,
    /// and each opens only when pressed.
    private func photoStage(_ image: UIImage, width: CGFloat, aspect: CGFloat? = nil, still: Bool = false,
                            corner: CGFloat = GridConstants.radiusSurface) -> some View {
        let box = CGSize(width: width, height: width / max(aspect ?? size.cropAspectRatio, 0.01))
        let rests = CachedImageView.filled(image.size, in: box)
        let shift = CachedImageView.shift(crop: crop, photo: image.size, frame: box, zoom: zoom)
        // The tools at the top right, as a story's editor keeps them: the
        // foot is the name's (the owner, 2026-10-18: type on the win).
        return ZStack(alignment: .topTrailing) {
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
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .accessibilityLabel("Your photo")
            // Only where there is room for them: squeezed by the keyboard,
            // the photo was a sliver with three discs floating on it.
            if box.height >= 140, !naming {
                photoTools
                    .padding(GridConstants.gapTight)
                    .transition(.opacity)
            }
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
        tools.dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private var tools: some View {
        HStack(spacing: GridConstants.gapTight) {
            toolGlyph("camera.filters", label: "Looks", on: choosingLook || lookRaw != FilmLook.Kind.none.rawValue) {
                withAnimation(GridConstants.motionSnappy) { choosingLook.toggle() }
            }
            toolGlyph("pencil.tip", label: "Draw", on: marks != nil) { marking = .pen }
            // No Stickers of its own (the owner, 2026-10-18: "stickers
            // already live inside doodle"): Draw has them.
            if HeadStore.shared.head != nil {
                toolGlyph("face.smiling", label: sticker == nil ? "Add your head" : "Take your head off", on: sticker != nil) {
                    withAnimation(GridConstants.motionSnappy) {
                        // Inside what the block shows now, wherever the photo
                        // has been moved or zoomed to (the old camera's rule).
                        if sticker == nil, let photo = shot {
                            let shown = CachedImageView.visibleRect(
                                crop: crop, photo: photo.size,
                                frame: CGSize(width: size.cropAspectRatio, height: 1), zoom: zoom)
                            sticker = StickerPlacement(crop: shown, photoAspect: photo.size.width / max(photo.size.height, 1))
                        } else {
                            sticker = nil
                        }
                    }
                }
            }
        }
    }

    /// **A tool says what it is** (the owner, 2026-10-18: "No unexplained
    /// icons ... nothing hidden that matters"): its glyph and its word, on
    /// the card's darker glass so it holds on a white wall. On, it turns
    /// white with dark ink.
    private func toolGlyph(_ symbol: String, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .iconSize(15, relativeTo: .body, weight: .semibold)
                Text(toolWord(label))
                    .font(Typography.headerSmall)
                    .lineLimit(1)
            }
            .foregroundStyle(on ? Color.black : .white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background { if on { Capsule().fill(.white) } }
            .inlineGlass(in: Capsule(), deep: true)
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// The tool's word on its pill: the short form of its spoken label.
    private func toolWord(_ label: String) -> String {
        switch label {
        case "Add your head", "Take your head off": "Head"
        default: label
        }
    }

    private func showLook(on image: UIImage) async {
        let look = FilmLook.look(FilmLook.Kind(rawValue: lookRaw) ?? .none)
        guard look.kind != .none else { looked = nil; return }
        let rendered = await Task.detached(priority: .userInitiated) {
            FilmLookRenderer.shared.render(image.scaledDown(to: 1400), look: look)
        }.value
        if !Task.isCancelled { looked = rendered }
    }

    // MARK: The composer: after the shot, and words

    /// **The win is the screen** (the owner, 2026-10-18: "Redesign the Add a
    /// Win edit screen ... to feel immersive and minimal, like editing an
    /// Instagram story. Right now it's a form with a tiny picture attached").
    ///
    /// One layout for a photograph and for words; only the hero differs. The
    /// hero takes every point the card has left, above the keyboard when it
    /// is up, and the name is written on it in the block's own type, so what
    /// is seen is what lands. The controls are quiet glass round its edges:
    /// close, who sees it and a labelled way back to the camera at the top;
    /// the colour, the size and "..." under it; one Add. With the keyboard
    /// up they fold into one row above it, as iMessage's and Instagram's do.
    /// (b: Instagram Stories and Snapchat keep the picture full and the tools
    /// in its corners; Notes keeps the page and puts the bar over the
    /// keyboard.)
    private func composer(size card: CGSize) -> some View {
        ZStack {
            WarmBackground()
            VStack(spacing: GridConstants.gapItem) {
                composerTop
                    .opacity(chromeIn ? 1 : 0)
                hero
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                Group {
                    if naming { keyboardRow } else { composerControls }
                }
                .opacity(chromeIn ? 1 : 0)
            }
            .padding(GridConstants.gapItem)
            .opacity(open ? 1 : 0)
            .animation(GridConstants.motionSnappy, value: naming)
        }
        .frame(width: card.width, height: card.height)
        .sheet(isPresented: $doodling) {
            BlockDoodleSheet(aspect: size.cropAspectRatio, colour: colour, towerHeight: towerBlockHeight,
                             drawing: doodle?.drawing, stickers: doodle?.stickers ?? [], drawnOn: doodle?.canvas) { drawn in
                withAnimation(GridConstants.motionSnappy) { doodle = drawn.isEmpty ? nil : drawn }
            }
        }
    }

    /// One clear close, who sees it in the middle, and the camera named.
    private var composerTop: some View {
        ZStack {
            HStack {
                GlassIconButton(systemName: "xmark", onPage: true, accessibilityLabel: "Close") { close() }
                Spacer(minLength: 0)
                if mode == .shot || !InlineCamera.refused {
                    // Named, never a bare glyph (the owner: "No unexplained
                    // icons").
                    Button {
                        HapticsEngine.lightTap()
                        backToLens()
                    } label: {
                        Label(mode == .shot ? "Retake" : "Camera",
                              systemImage: mode == .shot ? "arrow.counterclockwise" : "camera")
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.inkPrimary)
                            .padding(.horizontal, GridConstants.gapLabel)
                            .frame(minHeight: 44)
                            .glassCapsule(onPage: true)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode == .shot ? "Retake the photo" : "Use the camera")
                }
            }
            recipientsChip
                .frame(maxWidth: 170)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    /// **The hero**: the photograph, or the block in its colour, at the
    /// block's shape and as large as the room allows.
    private var hero: some View {
        GeometryReader { g in
            let aspect = size.cropAspectRatio
            let width = max(min(g.size.width, g.size.height * aspect), 1)
            let k = width / WinHeroTitle.blockWidth(size)
            let corner = GridConstants.blockCornerRadius(forCell: GridConstants.blockReferenceCell) * k
            Group {
                if mode == .shot, let shot {
                    photoStage(shot, width: width, corner: corner)
                        .overlay(alignment: .bottom) {
                            WinHeroTitle(title: $title, size: size, width: width, onPhoto: true, focus: $naming)
                        }
                        .matchedGeometryEffect(id: "picture", in: heroSpace)
                } else {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(colour.style.baseColor)
                            .contentShape(Rectangle())
                            .onTapGesture { naming = true }
                        if let picture = doodlePicture {
                            Image(uiImage: picture)
                                .resizable()
                                .scaledToFit()
                                .frame(width: width, height: width / aspect)
                                .allowsHitTesting(false)
                                .accessibilityLabel("Your drawing")
                        }
                        WinHeroTitle(title: $title, size: size, width: width, onPhoto: false, focus: $naming)
                    }
                    .frame(width: width, height: width / aspect)
                    .overlay(alignment: .topTrailing) {
                        if !naming {
                            toolGlyph("scribble", label: "Draw", on: doodle != nil) { doodling = true }
                                .padding(GridConstants.gapTight)
                                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                                .transition(.opacity)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Your block")
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .animation(GridConstants.slotSnap, value: size)
        .animation(GridConstants.motionSnappy, value: colour)
    }

    /// Under the hero, at rest: the colour, the size and "...", then Add.
    private var composerControls: some View {
        VStack(spacing: GridConstants.gapItem) {
            if choosingLook, mode == .shot, let shot {
                FilmLookStrip(photo: shot, selection: Binding(
                    get: { FilmLook.Kind(rawValue: lookRaw) ?? .none },
                    set: { lookRaw = $0.rawValue }))
                    .transition(.opacity)
            } else {
                if InlineCamera.refused, mode == .words { cameraOff }
                // A photograph covers its colour: no ring claims a kind of win
                // nobody gave it until a dot is pressed.
                ColourSwatchRow(category: $colour, showsSelection: mode == .words || colourChosen) { _ in colourChosen = true }
                    .frame(maxWidth: .infinity)
                HStack(spacing: GridConstants.gapTight) {
                    sizeBar
                    moreMenu
                }
            }
            pageFoot
        }
    }

    /// **With the keyboard up, one tidy row above it**: the size and Add, all
    /// a name needs ("..." is a tap away with the keyboard down; beside them
    /// the three sizes shrank to fit). Words keep their colour one row up,
    /// since the block is the colour.
    private var keyboardRow: some View {
        VStack(spacing: GridConstants.gapTight) {
            if mode == .words {
                ColourSwatchRow(category: $colour) { _ in colourChosen = true }
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: GridConstants.gapTight) {
                sizeBar
                addButton
            }
        }
    }

    private var sizeBar: some View {
        GlassChoiceBar(items: [BlockSize.small, .medium, .hard], chosen: size,
                       title: { $0.effortLabel }, spoken: { $0.effortLabel },
                       choose: { chosen in withAnimation(GridConstants.slotSnap) { size = chosen } },
                       fills: true)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Size")
            // Three words that must each be whole: no larger than they fit.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    /// **Who sees it, one small chip** (the second reader, 2026-10-17:
    /// nothing reaches a crew before a yes, so the chip names them and Add is
    /// the yes).
    private var recipientsChip: some View {
        CrewPicker(selection: $recipients, story: $onStory)
    }

    /// **Everything else, behind "..."** (the owner, 2026-10-18: "note,
    /// mood, who you were with, high/low/buffalo, plan this instead: behind
    /// '...', never open by default").
    private var moreMenu: some View {
        Menu {
            Button(note.isEmpty ? "Add a Note" : "Edit the Note", systemImage: "text.alignleft") { details = .note }
            if !recipients.isEmpty {
                Button("Who You Were With", systemImage: "person.2") { details = .with }
            }
            Button("High, Low and Buffalo", systemImage: "moon.stars") {
                let words = SocialStore.shared.storyWords(on: DateUtils.dateString(from: Date()))
                if high.isEmpty, low.isEmpty, buffalo.isEmpty { (high, low, buffalo) = (words.high, words.low, words.buffalo) }
                details = .words
            }
            Menu("Plan This Instead", systemImage: "calendar") {
                ForEach(PlanScope.all, id: \.self) { scope in
                    Button(scope == .day(0) ? "Later Today" : scope.title()) { planInstead(scope) }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .semibold)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .glassCircle(onPage: true)
                .contentShape(Circle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("More")
        .sheet(item: $details) { which in
            WinDetailsSheet(which: which, note: $note, high: $high, low: $low, buffalo: $buffalo,
                            recipients: recipients, with: $with)
        }
    }

    /// The drawing as the block shows it.
    private var doodlePicture: UIImage? {
        guard let doodle, !doodle.isEmpty, doodle.canvas.width > 0 else { return nil }
        return InkExport.image(of: doodle.drawing, in: CGRect(origin: .zero, size: doodle.canvas), scale: 2)
    }

    /// **Draw It, on the card** (the old sheet's, 2026-10-18: the old Add a
    /// Win sheet is gone): the block to write on, with the pen out.
    private func drawIt() {
        toWords()
        naming = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            doodling = true
        }
    }

    /// The block's height on the tower, for the pen's width.
    private var towerBlockHeight: CGFloat {
        let cell = GridConstants.cellSize(
            forGridWidth: UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2)
        let rows = CGFloat(size.rowSpan)
        return rows * cell + (rows - 1) * GridConstants.spacing
    }

    /// The words, planned for the day chosen, instead of a win now.
    private func planInstead(_ scope: PlanScope) {
        guard DayComposing.hasWords(title) else {
            naming = true
            return
        }
        HapticsEngine.tick()
        leave(with: .plan(scope, title))
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
        PrimaryCapsule(title: postWord) { if !dropping { drop() } }
            .accessibilityLabel("Drop it on the tower")
    }

    /// The same primary, at its word's width, in the keyboard's row.
    private var addButton: some View {
        PrimaryCapsule(title: postWord) { if !dropping { drop() } }
            .frame(width: 92)
            .accessibilityLabel("Drop it on the tower")
    }

    private var postWord: String { !recipients.isEmpty || onStory ? "Post" : "Add" }

    // MARK: Going

    private func arrive() {
        opened = CACurrentMediaTime()
        if !standsOnBar { barTop = nil }
        recipients = opening.crews ?? CrewChoice.load()
        colour = opening.colour
        if !opening.title.isEmpty { title = opening.title }
        size = opening.size
        if let photo = opening.photo {
            (mode, shot, fromCamera, place) = (.shot, photo, false, nil)
        } else if opening.words || opening.drawing {
            mode = .words
        }
        if opening.drawing {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                doodling = true
            }
        }
        if opening.planItemID != nil { colourChosen = opening.colour != .unlabeled }
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
                // A chat's photo carries no place: no location for it.
                if !closing, purpose == .win { LocationService.shared.start() }
            }
        } else if !opening.drawing {
            naming = true
        }
        if docked {
            shown = true
            open = true
            return
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
        guard photo != nil || doodle != nil || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            naming = true
            return
        }
        HapticsEngine.snap()
        // Your usual next time, unless a crew's own camera chose for you.
        if opening.crews == nil, !crews.isEmpty { CrewChoice.save(recipients) }
        // Tonight's words, kept as Send To keeps them.
        let today = DateUtils.dateString(from: Date())
        var words = SocialStore.shared.storyWords(on: today)
        if (words.high, words.low, words.buffalo) != (high, low, buffalo), !(high + low + buffalo).isEmpty {
            words.high = high; words.low = low; words.buffalo = buffalo
            Task { await SocialStore.shared.setStoryWords(words, on: today) }
        }
        let kept = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var win = DroppedWin(photo: nil, size: size, title: title, place: photo == nil ? nil : place,
                             crews: crews.isEmpty ? [] : recipients, colour: colour,
                             colourChosen: colourChosen || mode == .words,
                             note: kept.isEmpty ? nil : kept, with: with, story: onStory)
        guard let photo else {
            win.doodle = mode == .words ? doodle : nil
            leave(with: .drop(win))
            return
        }
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
        if docked {
            // On the tab: hand it over and stand ready for the next one.
            naming = false
            countdownTask?.cancel()
            done(result)
            // A win or the sheet takes you to Wins: the lens starts again
            // when the tab is back (`arrive`), never on a tab out of sight.
            resetForNext(restart: result == nil)
            return
        }
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

    /// The tab's card, back on the lens with nothing left from the last win.
    private func resetForNext(restart: Bool) {
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardOpen) {
            mode = InlineCamera.refused ? .words : .lens
            shot = nil
        }
        (title, size, note, with, high, low, buffalo) = ("", .small, "", [], "", "", "")
        (lookRaw, looked, choosingLook, marks, markLayer, sticker, crop, zoom) =
            (FilmLook.Kind.none.rawValue, nil, false, nil, nil, nil, .zero, 1)
        (dropping, colourChosen, doodle) = (false, false, nil)
        recipients = opening.crews ?? CrewChoice.load()
        if restart, mode == .lens { Task { await camera.start() } }
    }

    /// Down, and it tucks away.
    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard mode == .lens || !naming, !lensBusy else { return }
                drag = max(0, value.translation.height)
            }
            .onEnded { value in
                guard !lensBusy else { withAnimation(GridConstants.slotSnap) { drag = 0 }; return }
                if value.translation.height > 120 || value.predictedEndTranslation.height > 260 {
                    close()
                } else {
                    withAnimation(GridConstants.slotSnap) { drag = 0 }
                }
            }
    }
}

/// **The name, written on the win** (the owner, 2026-10-18: "The name is
/// written directly on the photo or block, the way text sits on a story, in
/// our block typography, with a soft scrim on photos so it's always readable.
/// What you see is exactly what lands on the tower").
///
/// The block's title as the tower sets it (`BlockContentOverlay`: footnote,
/// medium, white, bottom left inside 12, 8 and 10, one line on a one-row
/// block and two on a taller one), scaled with the hero by the same factor
/// the hero is to a tower cell, and set at that size rather than magnified,
/// so it stays sharp. On a photograph a short soft scrim and the tower's own
/// halo; on a colour, neither (the owner, 2026-10-16: no shadow on flat
/// colour).
struct WinHeroTitle: View {
    @Binding var title: String
    let size: BlockSize
    /// The hero's width.
    let width: CGFloat
    let onPhoto: Bool
    var focus: FocusState<Bool>.Binding

    @Environment(\.dynamicTypeSize) private var typeSize

    static func blockWidth(_ size: BlockSize) -> CGFloat {
        let cell = GridConstants.blockReferenceCell
        return cell * CGFloat(size.columnSpan) + GridConstants.spacing * CGFloat(size.columnSpan - 1)
    }

    /// The tower's footnote at this person's text size, capped where the
    /// tower caps it (`BlockContentOverlay`: XXL).
    private var base: CGFloat {
        let capped = min(typeSize, .xxLarge)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(capped))
        return UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: traits).pointSize
    }

    var body: some View {
        let k = width / Self.blockWidth(size)
        let lines = size.rowSpan > 1 ? 2 : 1
        VStack(alignment: .leading, spacing: 0) {
            // The prompt drawn here rather than as the field's: UIKit's
            // placeholder clipped through its middle at the hero's size
            // (seen 2026-10-18); typed words were whole.
            TextField("", text: $title, axis: lines > 1 ? .vertical : .horizontal)
                .background(alignment: .leading) {
                    if title.isEmpty {
                        Text("Name it")
                            .font(.system(size: base * k, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .font(.system(size: base * k, weight: .medium))
                .foregroundStyle(.white)
                .tint(.white)
                .lineLimit(1...lines)
                .submitLabel(.done)
                .focused(focus)
                .shadow(color: .black.opacity(onPhoto ? Legibility.ink : 0),
                        radius: onPhoto ? Legibility.radius : 0, x: 0, y: Legibility.y)
                .padding(.leading, 12 * k)
                .padding(.trailing, 8 * k)
                .padding(.bottom, 10 * k)
                .padding(.top, 18 * k)
        }
        .frame(width: width, alignment: .leading)
        // Only the scrim is rounded to the photo's corners: clipping the
        // whole title cut the words through their middle at the hero's size
        // (seen 2026-10-18).
        .background(alignment: .bottom) {
            if onPhoto {
                LinearGradient(colors: [.clear, .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
                    .clipShape(UnevenRoundedRectangle(
                        bottomLeadingRadius: GridConstants.blockCornerRadius(forCell: GridConstants.blockReferenceCell) * k,
                        bottomTrailingRadius: GridConstants.blockCornerRadius(forCell: GridConstants.blockReferenceCell) * k,
                        style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("Name")
    }
}

/// **What "..." opens, one thing at a time**: a note, who you were with, or
/// tonight's high, low and buffalo. A half sheet in the page's own ground.
struct WinDetailsSheet: View {
    enum Which: String, Identifiable { case note, with, words; var id: String { rawValue } }
    let which: Which
    @Binding var note: String
    @Binding var high: String
    @Binding var low: String
    @Binding var buffalo: String
    let recipients: Set<CrewID>
    @Binding var with: [UUID]
    @Environment(\.dismiss) private var dismiss
    @FocusState private var writing: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                switch which {
                case .note:
                    TextField("", text: $note, prompt: Text("A note, just for you").foregroundStyle(AppColors.inkTertiary),
                              axis: .vertical)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(3...8)
                        .focused($writing)
                case .with:
                    CrewWithRow(crews: recipients, selection: $with)
                case .words:
                    ForEach([(StoryLine.high, StoryLine.highPrompt, $high), (StoryLine.low, StoryLine.lowPrompt, $low),
                             (StoryLine.buffalo, StoryLine.buffaloPrompt, $buffalo)], id: \.0) { name, prompt, text in
                        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                            FormSectionLabel(name)
                            TextField("", text: text, prompt: Text(prompt).foregroundStyle(AppColors.inkTertiary))
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkPrimary)
                                .frame(minHeight: 44)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(GridConstants.horizontalPadding)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle(title, drawn: false)
            .toolbar {
                BareToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done").sheetAction(.confirm) }
                        .buttonStyle(.pressWord)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .onAppear { if which != .with { writing = true } }
    }

    private var title: String {
        switch which {
        case .note: "Note"
        case .with: "Who You Were With"
        case .words: "High, Low and Buffalo"
        }
    }
}

// MARK: - The card's glass

private extension View {
    /// **A soft dark disc of glass**, as the reference camera's are: the
    /// card's controls sit on a picture that can be a white wall, and clear
    /// glass there lets a white glyph vanish (seen, 2026-10-17: More and Retake
    /// were all but gone over a white page). A fifth of black in the glass
    /// keeps the glyph's ground without becoming a dark button.
    /// `deep`: on a photograph the person chose, which can be all white: a
    /// third of black (the tools were pale discs on a bright photo, seen
    /// 2026-10-18).
    @ViewBuilder
    func inlineGlass(in shape: some Shape, deep: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(.black.opacity(deep ? 0.36 : 0.22)).interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .environment(\.colorScheme, .dark)
        }
    }
}
