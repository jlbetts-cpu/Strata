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

/// What the card hands back.
enum InlineCameraResult {
    /// Drop it: a photograph (or none), the size drawn, its name, where.
    case drop(photo: UIImage?, size: BlockSize, title: String, place: WinPlace?)
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
    let done: (InlineCameraResult?) -> Void

    private enum Mode: Equatable { case lens, shot, words }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var open = false
    @State private var mode: Mode = InlineCamera.refused ? .words : .lens
    @State private var live = false
    @State private var shot: UIImage?
    @State private var title = ""
    @State private var size: BlockSize = .small
    @State private var place: WinPlace?
    @State private var drag: CGFloat = 0
    @State private var down = false
    @State private var lock = HoldLock()
    @State private var shutterScale: CGFloat = 1
    @State private var picking = false
    @State private var picked: PhotosPickerItem?
    @State private var closing = false
    @State private var opened = CACurrentMediaTime()
    @FocusState private var naming: Bool
    /// The card's face, dissolving in over the slot and back out into it, on
    /// its own short curve so the morph never looks washed out midway.
    @State private var shown = false
    @Environment(\.colorScheme) private var pageScheme

    private var camera: CameraService { InlineCamera.shared.camera }

    var body: some View {
        GeometryReader { geo in
            let target = cardFrame(in: geo)
            let frame = open ? target : opening.from
            // **The slot, growing into the card**, as Photos grows a photo out
            // of its thumbnail: the card's face is scaled to cover the window
            // (aspect fill, never stretched) and the window's rounded edge is
            // the slot's at the start and the card's at the end. Both come
            // from one spring, so it is one motion with no seam.
            let cover = open ? 1 : max(frame.width / target.width, frame.height / target.height)
            ZStack {
                // The page stays, gently dimmed: it is still where you are.
                Color.black.opacity(open ? 0.22 : 0)
                    .onTapGesture { close() }
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

    /// Low on the screen, full width less the margins, a photograph's 3:4,
    /// and never taller than the room above the keyboard.
    private func cardFrame(in geo: GeometryProxy) -> CGRect {
        // The reader's size is the room between the safe areas (and above the
        // keyboard when it is up); the card is placed in the screen's space,
        // whose top is `inset.top` above the reader's.
        let inset = geo.safeAreaInsets
        let margin = GridConstants.gapTight
        let width = geo.size.width - margin * 2
        let room = geo.size.height - GridConstants.gapItem * 3
        let height = min(width * 4 / 3, room)
        let bottom = inset.top + geo.size.height - margin
        return CGRect(x: margin, y: bottom - height, width: width, height: height)
    }

    // MARK: The card's face

    private func card(size: CGSize) -> some View {
        ZStack {
            // The slot itself, under everything: what shows for the moment
            // before the first frame, so there is never a black box and the
            // card begins as exactly the thing that was tapped.
            ground
            switch mode {
            case .lens:
                lens(size: size)
                    .opacity(live ? 1 : 0)
            case .shot:
                if let shot {
                    Image(uiImage: shot)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .transition(.opacity)
                }
            case .words:
                EmptyView()
            }
            controls
                .opacity(open ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
    }

    /// **The slot's own glass and tint while the lens wakes; the win's colour
    /// for words.** It was the colour deepened toward black, and filmed that
    /// read as a dark red square that lightened as the lens arrived: a colour
    /// jolt in the one motion people see most (2026-10-17).
    @ViewBuilder
    private var ground: some View {
        if mode == .words {
            ZStack {
                opening.colour.style.baseColor
                Color.black.opacity(0.25)
            }
        } else {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                opening.colour.style.baseColor.opacity(0.14)
            }
            .environment(\.colorScheme, pageScheme)
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

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 0) {
            top
            Spacer(minLength: 0)
            if mode == .words && InlineCamera.refused { cameraOff }
            if mode != .lens { nameRow }
            bottom
        }
        .padding(GridConstants.gapItem)
    }

    /// The other ways a win is made, small, at the top: never a photograph
    /// you are made to take.
    private var top: some View {
        HStack(spacing: GridConstants.gapTight) {
            if mode != .words {
                pill("Just Words", systemImage: "textformat") {
                    withAnimation(GridConstants.motionSnappy) { mode = .words; shot = nil }
                    naming = true
                    camera.stop()
                }
            } else if !InlineCamera.refused {
                pill("Camera", systemImage: "camera") { backToLens() }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Choose a Photo", systemImage: "photo.on.rectangle") { picking = true }
                Button("Draw It", systemImage: "scribble") { toSheet(drawing: true) }
                Button("More Options", systemImage: "slider.horizontal.3") { toSheet() }
            } label: {
                glyphFace("ellipsis")
            }
            .accessibilityLabel("More ways to add")
        }
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

    /// Close, the shutter (or Drop), flip (or Retake): the camera's three.
    private var bottom: some View {
        HStack {
            glassGlyph("xmark", label: "Close") { close() }
            Spacer(minLength: 0)
            switch mode {
            case .lens: shutter
            case .shot, .words: dropButton
            }
            Spacer(minLength: 0)
            switch mode {
            case .lens:
                glassGlyph("arrow.triangle.2.circlepath", label: "Switch camera") {
                    withAnimation(GridConstants.motionSnappy) { camera.flip() }
                }
            case .shot:
                glassGlyph("arrow.counterclockwise", label: "Retake") { backToLens() }
            case .words:
                Color.clear.frame(width: 44, height: 44)
            }
        }
    }

    private var nameRow: some View {
        TextField("", text: $title, prompt: Text(mode == .words ? "What went right?" : "Name it, if you want")
            .foregroundStyle(AppColors.onDarkSecondary))
            .font(Typography.bodyLarge)
            .foregroundStyle(.white)
            .submitLabel(.done)
            .onSubmit(drop)
            .focused($naming)
            .padding(.horizontal, GridConstants.gapItem)
            .frame(minHeight: 48)
            .glassCapsule(carriesType: true, interactive: false)
            .padding(.bottom, GridConstants.gapItem)
    }

    private var cameraOff: some View {
        VStack(spacing: GridConstants.gapTight) {
            Text("The camera is off for \(AppName.display).")
                .font(Typography.bodyLarge)
                .foregroundStyle(.white)
            Button {
                HapticsEngine.lightTap()
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("Turn It On in Settings")
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, GridConstants.gapLabel)
                    .frame(minHeight: 44)
                    .glassCapsule(carriesType: true)
            }
            .buttonStyle(.plain)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.bottom, GridConstants.gapSection)
    }

    /// **Drop is the block itself**: the shutter's own shape at the size
    /// drawn, with the way it goes on it. It was a white circle in the place
    /// the shutter's rounded block had just been, two shapes for one role
    /// (2026-10-17, looking at the card whole rather than piece by piece).
    private var dropButton: some View {
        Button(action: drop) {
            ZStack {
                ShutterBlock(size: size, lit: true)
                Image(systemName: "arrow.down")
                    .iconSize(22, relativeTo: .body, weight: .semibold)
                    .foregroundStyle(.black)
            }
            .legibleOnImagery()
            .frame(width: CameraView.shutterBounds(.hard).width, height: CameraView.shutterBounds(.hard).height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel("Drop it on the tower")
    }

    // MARK: The shutter

    private var shutter: some View {
        ShutterBlock(size: size, lit: true, scale: shutterScale, fill: lock.fill)
            .animation(GridConstants.slotSnap, value: size)
            .legibleOnImagery()
            .frame(width: CameraView.shutterBounds(.hard).width, height: CameraView.shutterBounds(.hard).height)
            .contentShape(Rectangle())
            .gesture(shutterDraw, isEnabled: camera.isLive || Self.fakeLens)
            .accessibilityLabel("Take photo")
            .accessibilityValue(size.effortLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { shoot() }
    }

    private static var fakeLens: Bool {
        #if DEBUG
        FakeLens.shared != nil
        #else
        false
        #endif
    }

    /// The Camera tab's shutter, with its rule (`HoldLock`): a tap shoots
    /// one cell at once; a drawn size has to be rested on until the rim fills.
    private var shutterDraw: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !down {
                    down = true
                    HapticsEngine.tick()
                    lock.begin(at: value.location)
                }
                guard !reduceMotion else { return }
                let (lateral, up) = BlockSizeDraw.axes(translation: value.translation)
                let next = BlockSizeDraw.size(lateral: lateral, up: up, from: size)
                guard next != size else {
                    lock.moved(to: value.location, sizeChanged: false)
                    return
                }
                HapticsEngine.tick()
                withAnimation(GridConstants.slotSnap) { size = next }
                lock.moved(to: value.location, sizeChanged: true)
            }
            .onEnded { _ in
                guard down else { return }
                down = false
                let locked = lock.end()
                if size != .small, !locked {
                    withAnimation(GridConstants.slotSnap) { size = .small }
                } else {
                    shoot()
                }
            }
    }

    private func shoot() {
        guard !camera.isCapturing else { return }
        HapticsEngine.lightTap()
        withAnimation(GridConstants.shutterPress) { shutterScale = 0.86 }
        withAnimation(GridConstants.shutterRelease.delay(0.08)) { shutterScale = 1 }
        place = LocationService.shared.place()
        camera.capture { image in Task { @MainActor in
            guard let image else {
                withAnimation(GridConstants.slotSnap) { size = .small }
                return
            }
            let polished = await Task.detached(priority: .userInitiated) {
                PortraitPolish.apply(to: image)
            }.value
            withAnimation(GridConstants.motionSnappy) {
                shot = polished
                mode = .shot
            }
            camera.stop()
        } }
    }

    // MARK: Going

    private func arrive() {
        opened = CACurrentMediaTime()
        HapticsEngine.lightTap()
        if mode == .lens {
            Task {
                // **Nothing on the first frames but the motion.** Filmed, the
                // opening's first frames repeated while the lens and location
                // started beside them (2026-10-17). The session starts on its
                // own queue; asking for it waits a frame so the cover's first
                // composite is the card's, and location waits for the card.
                try? await Task.sleep(for: .milliseconds(16))
                await InlineCamera.shared.camera.start()
                if Self.fakeLens { showLive() }
                // Asked just now, and refused: words, with the way back on.
                if camera.isDenied {
                    withAnimation(GridConstants.motionSnappy) { mode = .words }
                    naming = true
                }
                try? await Task.sleep(for: .milliseconds(400))
                if !closing { LocationService.shared.start() }
            }
        } else {
            naming = true
        }
        withAnimation(.easeOut(duration: 0.14)) { shown = true }
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

    private func backToLens() {
        withAnimation(GridConstants.motionSnappy) {
            shot = nil
            mode = .lens
            size = .small
        }
        naming = false
        Task { await camera.start() }
    }

    private func drop() {
        let photo = mode == .shot ? shot : nil
        guard photo != nil || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            naming = true
            return
        }
        HapticsEngine.snap()
        leave(with: .drop(photo: photo, size: size, title: title, place: photo == nil ? nil : place))
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
        withAnimation(GridConstants.motionSnappy) {
            shot = image
            mode = .shot
            place = nil
        }
        camera.stop()
    }

    private func close() { leave(with: nil) }

    /// Back the way it came, then gone.
    private func leave(with result: InlineCameraResult?) {
        guard !closing else { return }
        closing = true
        naming = false
        // A drop hands over at once, so the block is already falling while
        // the card folds back into the slot it is falling toward.
        if case .drop = result { done(result) }
        // The face dissolves over the last of the way, so what reaches the
        // slot is the slot and not a tiny picture that then vanishes.
        withAnimation(.easeIn(duration: 0.16).delay(0.14)) { shown = false }
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cardClose) {
            open = false
            drag = 0
        } completion: {
            // Stopped after the motion, not at its start: filmed, stopping the
            // lens on the first frame of the close cost that frame (2026-10-17).
            camera.stop()
            LocationService.shared.stop()
            if case .drop = result { done(nil) } else { done(result) }
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

// MARK: - Motion

extension GridConstants {
    /// **The card opening out of what you tapped.** One soft spring and
    /// nothing else: no fade on the window, no second stage. A little bounce,
    /// as the system's own sheets and the Dynamic Island settle, because the
    /// card is a thing arriving; a quarter of what `bouncy` gives, because it
    /// is the moment people see most and it must never wobble.
    static var cardOpen: Animation { calm(.spring(duration: 0.42, bounce: 0.12)) }
    /// Back into the slot: the same path, no bounce, a touch quicker. A thing
    /// put away does not overshoot where it goes.
    static var cardClose: Animation { calm(.spring(duration: 0.34, bounce: 0)) }
}
