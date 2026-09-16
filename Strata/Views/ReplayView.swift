import SwiftUI

/// A replay, playing.
///
/// Time is the only state. Tap skips to the close, press and hold pauses,
/// and neither can put anything out of step because nothing is animating:
/// every frame is `ReplayFrame` at the clock's `t`.
///
/// **Gestures, and why the close button is never a skip.** The close button
/// is a SIBLING of the player in the ZStack, drawn above it, not a child of
/// the view that carries the gestures. A touch is hit-tested to the frontmost
/// view under it, and only gestures on that view and its ancestors take part,
/// so a touch on the button never reaches the tap or the hold at all.
/// `ReplayGestureTests` presses all three.
///
/// The controls under the close (Replay, Save Video, Share) are different:
/// they are children of the player. A child `Button` takes precedence over
/// the parent's `onTapGesture`, so a tap on one is the button's and not a
/// skip; the hold is SIMULTANEOUS, so holding a control would also pause,
/// which changes nothing once the replay has finished.
/// `testShareAfterTheCloseIsNotASkip` taps Share and reads the clock, and
/// `testReplayRestartsFromTheStart` taps Replay.
/// Before the close arrives `ReplayFrame` turns their hit testing off, so a
/// tap there falls through to the skip.
///
/// **After the close, a block with a photograph opens it**, in the app's
/// own viewer, out of the block. Before the close a tap anywhere is still the
/// skip. `testTapABlockAfterTheCloseOpensItsPhoto` presses it. A block whose
/// photograph was deleted, from this replay's viewer or anywhere else, opens
/// nothing: the replay keeps drawing the picture it decoded, but the file the
/// viewer would open is gone.
///
/// **VoiceOver.** The build is visual, so with VoiceOver running the replay
/// opens at the close, where the words and controls are, and it says the
/// close once as it arrives (`Replay.announcement`). A double tap on the
/// header or the close words is an accessibility ACTION that skips directly.
/// It has to be: an activation never passes through the hold gesture, so the
/// tap gesture's `press.held` could still be true from an earlier physical
/// hold and would swallow the skip.
struct ReplayView: View {
    let replay: Replay
    var isSample = false
    /// A photograph opened from a block was deleted. The page that owns the
    /// replay reloads what showed it; the replay keeps the picture it drew.
    var onPhotoDeleted: (() -> Void)? = nil
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// One `now` for the whole replay. The header's range is worded against
    /// it, and a fresh `Date()` per frame could reword it mid-play at
    /// midnight.
    @State private var now = Date()
    /// The photographs, arriving: playback starts once the first seconds'
    /// are in (`ReplayImageLoad`).
    @State private var load = ReplayImageLoad()
    /// Shown only when nothing could start within `replayLoadingDelay`.
    @State private var showsLoading = false
    /// The clock has started: the player replaces the empty ground.
    @State private var started = false
    @State private var scripts = ReplayScriptCache()
    /// Share's frame on screen, for the iPad's share popover.
    @State private var shareAnchor = ReplayShareAnchor()
    @State private var clock = ReplayClock()
    @State private var feedback = ReplayFeedback()
    /// Set once `t` reaches the end, so the timeline stops asking for frames
    /// of a picture that no longer changes.
    @State private var finished = false
    @GestureState private var holding = false
    @State private var press = PressMemory()
    /// Set when the close has been announced to VoiceOver, so it is said
    /// once a play (Replay says it again).
    @State private var announced = false
    /// The photograph opened from a block after the close.
    @State private var viewing: ViewedPhoto?
    /// Where that block is drawn, so the viewer can grow out of it.
    @State private var viewingSource: CGRect = .zero
    @Namespace private var photoTransition
    /// The video, for Save Video and Share. Its own observable, read only by
    /// the controls, so the progress ticking over does not rebuild the whole
    /// replay.
    @State private var video = ReplayVideo()
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var cadence = ReplayCadence()
    @State private var openTiming = ReplayOpenTiming()
    #endif

    var body: some View {
        // Two readers. The outer one keeps the safe area, so its insets are
        // the real status bar, Dynamic Island and home indicator. A reader
        // that itself ignores the safe area reports zero insets: photographed
        // that way, the header sat under the status bar. The inner one
        // ignores it, so its size is the whole screen, which the replay's
        // lines are fractions of.
        GeometryReader { safe in
            let insets = safe.safeAreaInsets
            GeometryReader { geo in
                let script = makeScript(size: geo.size, insets: insets)
                ZStack(alignment: .topTrailing) {
                    if started {
                        player(script: script, insets: insets)
                    } else {
                        WarmBackground()
                    }
                    if showsLoading && !started {
                        ReplayLoadingSlot(metrics: script.metrics)
                            .transition(.opacity)
                    }
                    // The block a photograph opens out of. A clear stand-in
                    // at the block's rect: the blocks are drawn by a pure
                    // frame, which knows nothing about transitions.
                    Color.clear
                        .frame(width: max(viewingSource.width, 1), height: max(viewingSource.height, 1))
                        .matchedTransitionSource(id: "replayBlockPhoto", in: photoTransition)
                        .position(x: viewingSource.midX, y: viewingSource.midY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    // From the first frame, loaded or not: leaving never waits
                    // on the animation.
                    GlassIconButton(systemName: "xmark", accessibilityLabel: "Close") {
                        video.close()
                        load.cancel()
                        onClose()
                    }
                        .padding(.trailing, GridConstants.horizontalPadding)
                        .padding(.top, insets.top + GridConstants.gapTight)
                }
                .animation(.easeOut(duration: GridConstants.replayLoadingFade), value: started)
                .task(id: script.metrics.cell) { await prepare(script: script) }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(false)
        // Closing the replay (the close button, above) stops a save in
        // progress and deletes the partial file. So does leaving the app: a
        // phone will not encode video in the background. Only `.background`,
        // not `.inactive`, which a pulled-down Control Center or the Photos
        // permission alert also report.
        //
        // Not `onDisappear`: the photo viewer is a full-screen cover over the
        // replay, and a disappearance there is not a close.
        // `testSaveVideoSurvivesOpeningAPhoto` opens one mid-save.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { video.cancel() }
        }
        #if DEBUG
        .onChange(of: finished) { _, done in
            if done, DebugHarness.exportsReplay { saveVideo() }
        }
        #endif
        .fullScreenCover(item: $viewing) { photo in
            PhotoViewer(photos: storedPhotos,
                        startAt: photo.id,
                        onClose: { viewing = nil },
                        // The replay keeps the picture it already decoded;
                        // the page under it reloads.
                        onDelete: { _ in
                            viewing = nil
                            onPhotoDeleted?()
                        })
                .navigationTransition(.zoom(sourceID: "replayBlockPhoto", in: photoTransition))
        }
    }

    /// The script for this frame size, made once. The body runs again for
    /// every state change on the way to the first frame, and a month's
    /// script solves its camera each time it is made.
    private func makeScript(size: CGSize, insets: EdgeInsets) -> ReplayScript {
        #if DEBUG
        let began = CACurrentMediaTime()
        defer { openTiming.mark("script", ms: (CACurrentMediaTime() - began) * 1000) }
        #endif
        let metrics = ReplayScript.Metrics.standard(frame: size, topInset: insets.top,
                                                    topCopy: ReplayFrame.topCopyHeight(dynamicTypeSize),
                                                    bottomInset: insets.bottom,
                                                    controlsHeight: GlassIconButton.defaultSide)
        return scripts.script(replay, metrics: metrics, reduceMotion: reduceMotion)
    }

    /// The replay's own photographs, in drop order. Sample wins' bundled
    /// pictures are not in the store and open nothing, and nor does one
    /// deleted since the replay opened: swiping to it would show a missing
    /// file.
    private var storedPhotos: [GalleryPhoto] {
        replay.blocks.compactMap { block -> GalleryPhoto? in
            guard case .stored(let name) = block.win.photo,
                  ImageManager.shared.fileExists(fileName: name) else { return nil }
            return GalleryPhoto(fileName: name,
                                title: Self.photoTitle(block.win.title),
                                date: block.win.completedAt,
                                dateString: block.win.dateString,
                                size: block.win.size)
        }
    }

    private func openPhoto(block index: Int, script: ReplayScript, t: Double) {
        // A press that got as far as a hold is not a tap on anything.
        if press.held { return }
        guard case .stored(let name) = replay.blocks[index].win.photo,
              // Deleted from the viewer a moment ago: the block still shows
              // the decoded picture, but there is nothing left to open.
              ImageManager.shared.fileExists(fileName: name) else { return }
        HapticsEngine.lightTap()
        viewingSource = script.screenRect(ofBlock: index, at: t)
        viewing = ViewedPhoto(id: name, title: Self.photoTitle(replay.blocks[index].win.title))
    }

    /// A win never named has no title, in the viewer as in the gallery.
    static func photoTitle(_ title: String) -> String? {
        (title.isEmpty || title == QuickWinService.untitled) ? nil : title
    }

    private func player(script: ReplayScript, insets: EdgeInsets) -> some View {
        // A finished replay keeps drawing until its last photographs have
        // arrived and faded in, or a late one would never be seen.
        TimelineView(.animation(paused: (finished && load.settled) || clock.isPaused || clock.isFrozen)) { context in
            let t = clock.time(at: context.date, duration: script.duration)
            #if DEBUG
            let _ = openTiming.markOnce("timeline")
            #endif
            ReplayFrame(script: script, images: load.images, t: t, now: now,
                        showsSampleBadge: isSample,
                        controls: AnyView(controls(script: script)),
                        photoOpacity: { load.opacity($0, at: t) },
                        expectsPhoto: { load.expects($0) },
                        topInset: insets.top,
                        onTapBlock: t >= script.closeStart
                            ? { index in openPhoto(block: index, script: script, t: t) }
                            : nil,
                        onAccessibilityActivate: { clock.skip(to: script.closeStart) })
                .onChange(of: t) { old, new in
                    clock.lastRendered = new
                    feedback.play(script, from: old, to: new)
                    #if DEBUG
                    if DebugHarness.probesReplay { cadence.record(script.phase(at: new), finished: new >= script.duration) }
                    #endif
                    if new >= script.duration { finished = true }
                }
                // Initial too: with VoiceOver running the first frame drawn
                // is already the close, and there is no crossing to see.
                .onChange(of: t >= script.closeStart, initial: true) { _, atClose in
                    guard atClose, !announced else { return }
                    announced = true
                    AccessibilityNotification.Announcement(replay.announcement(now: now)).post()
                }
                #if DEBUG
                .overlay(alignment: .topLeading) {
                    if DebugHarness.probesReplay { probe(script: script, t: t) }
                }
                .onAppear { openTiming.firstFrame(replay: replay) }
                #endif
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // A press that got as far as a hold is never also a skip.
            if press.held { return }
            clock.skip(to: script.closeStart)
        }
        .simultaneousGesture(hold)
        .onChange(of: holding) { _, isHolding in
            if isHolding { clock.pause() } else { clock.resume() }
        }
    }

    /// Press and hold: a long press SEQUENCED before a zero-distance drag, so
    /// it stays held for as long as the finger is down after the delay, and
    /// `@GestureState` resets it however the touch ends, cancellation
    /// included. A replay cannot be left paused by an interrupted press.
    ///
    /// A bare `onLongPressGesture(pressing:)` reports touch-down at once, so
    /// every tap would freeze the picture before skipping, and it reports
    /// the press over when the delay is met rather than when the finger
    /// lifts.
    ///
    /// **Simultaneous with the tap, not exclusive before it.**
    /// `hold.exclusively(before: TapGesture())` read correctly and never
    /// skipped: `ReplayGestureTests.testTapSkipsToTheClose` pressed it and the
    /// clock ran on from 1.66s to 2.90s. A release after a hold does not also
    /// count as a tap on its own after a 3s hold, BUT it does after a short
    /// one: `testShortHoldReleaseIsNotASkip` pressed for 0.35s, the replay
    /// paused, and the release skipped to the close (t 1.58 -> 13.95). So
    /// the hold remembers, per touch, that it got past the delay, and the tap
    /// checks. The memory is cleared when the next touch begins, so a hold
    /// whose release produced no tap cannot swallow the next real one.
    private var hold: some Gesture {
        LongPressGesture(minimumDuration: GridConstants.replayHoldToPause)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($holding) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                switch value {
                case .first: press.held = false
                case .second(true, _): press.held = true
                default: break
                }
            }
    }

    /// Replay, Save Video and Share. The row reserves their height from the
    /// first frame, so the close is laid out, and bounded above the home
    /// indicator, at the size it has once they are in it.
    ///
    /// **Share shares the video** (the owner, 2026-09-15: "sharing as an
    /// image shouldn't be the option"). It exports the same file Save Video
    /// does, once per replay, and hands it to the share sheet.
    ///
    /// **One row, always.** Stacking was tried: the close is bounded above
    /// the home indicator, so a taller close rose into the tower and printed
    /// over its bottom row. Instead Save Video's and Share's words may shrink,
    /// to 80% at most, when the row is short of room (an iPhone SE at
    /// xxLarge). Replay is a glyph and never does.
    private func controls(script: ReplayScript) -> some View {
        HStack(spacing: GridConstants.gapItem) {
            // Quieter than the two words beside it: the glyph in secondary ink.
            GlassIconButton(systemName: "arrow.counterclockwise", tint: AppColors.inkSecondary, accessibilityLabel: "Replay") {
                restart(script: script)
            }
            SaveVideoControl(video: video) { saveVideo() }
            ShareVideoControl(video: video) { shareVideo() }
                // Where the share sheet points from on an iPad. A reference,
                // written on layout, so it does not redraw the replay.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { shareAnchor.rect = $0 }
        }
        .frame(height: GlassIconButton.defaultSide)
    }

    private func saveVideo() {
        let load = load
        video.save(replay: replay, images: { await load.all() }, now: now, isSample: isSample)
    }

    private func shareVideo() {
        let load = load
        video.share(replay: replay, images: { await load.all() }, now: now, isSample: isSample) { url in
            ReplayShareSheet.present(url, from: shareAnchor.rect)
        }
    }

    /// From the start again: the clock, the landings' sounds and haptics,
    /// the dance's haptic and the VoiceOver announcement all fire again.
    ///
    /// **With VoiceOver, straight back to the close**, as the replay opens:
    /// played from 0 the controls went invisible and focus had nowhere to
    /// go for the whole build. The announcement is posted here: restart and
    /// skip land in one frame, so the close is never crossed for the
    /// `onChange` that says it on a first play.
    ///
    /// Photographs already decoded show whole from the start of the second
    /// play: their fade times belong to the first.
    ///
    /// Save Video's and Share's state survives on purpose: the video is the
    /// same video, so "Saved to Photos" stays and a finished file is reused.
    private func restart(script: ReplayScript) {
        feedback = ReplayFeedback()
        announced = false
        press.held = false
        finished = false
        load.forgetArrivals()
        clock.restart()
        if UIAccessibility.isVoiceOverRunning {
            clock.skip(to: script.closeStart)
            announced = true
            AccessibilityNotification.Announcement(replay.announcement(now: now)).post()
        }
    }

    private func prepare(script: ReplayScript) async {
        var start = 0.0
        #if DEBUG
        if let frozen = DebugHarness.replayAt { clock.freeze(at: frozen); start = frozen }
        openTiming.mark(String(format: "prepare (reveal %.2fs, close %.2fs, end %.2fs)", script.revealStart, script.closeStart, script.duration))
        let decodeBegan = CACurrentMediaTime()
        #endif
        // With VoiceOver the replay opens at the close: the build is a wait
        // with nothing to hear.
        let voiceOver = UIAccessibility.isVoiceOverRunning
        if voiceOver { start = script.closeStart }
        // A frozen moment is a photograph of the replay, so it waits for
        // every picture; playback waits only for its first seconds'.
        var required = ReplayImageLoad.required(script, from: start)
        #if DEBUG
        if DebugHarness.replayAt != nil { required = Set(replay.blocks.compactMap { $0.win.photo?.key }) }
        #endif
        // One decode serves the screen and the video, so at whichever cell is
        // bigger in pixels: this screen's, or the card's at the export scale
        // (a 402pt phone at 3x: a 267px cell against the card's 237px; an SE
        // at 2x: 164px, so the card's).
        // A photograph landing mid-play fades in on the replay's own clock;
        // one landing while it is held, frozen or finished shows at once, and
        // so does one landing in the last fade's length: the clock stops at
        // the end and would leave it half faded.
        let clock = clock
        let lastFade = script.duration - ReplayImageLoad.fade
        load.clock = { (clock.lastRendered, !clock.isPaused && !clock.isFrozen && clock.lastRendered < lastFade) }
        load.start(replay, cellPixels: max(script.metrics.cell * displayScale,
                                           ReplayCard.cell * ReplayCard.shareScale),
                   required: required)
        #if DEBUG
        // What the old path waited for before its first frame: every
        // photograph. Logged in the same run, so the two compare under the
        // same load.
        let needed = required.count
        Task {
            let all = await load.all()
            openTiming.log(String(format: "[REPLAY-OPEN] %@ all %d photos decoded %.0fms after prepare (%d needed to start)",
                                  replay.period.id, all.count, (CACurrentMediaTime() - decodeBegan) * 1000, needed))
        }
        #endif
        // Not on the first landing: starting the engine there held that
        // frame for 400ms. `prepare` hands the setup to its own queue.
        SoundEngine.prepare()
        if !load.canPlay {
            // A wait too short to notice shows nothing; a longer one shows
            // where the tower will stand.
            let indicator = Task {
                try? await Task.sleep(for: .milliseconds(Int(GridConstants.replayLoadingDelay * 1000)))
                if !Task.isCancelled, !load.canPlay { showsLoading = true }
            }
            await load.untilPlayable()
            indicator.cancel()
        }
        #if DEBUG
        if let hold = DebugHarness.replayHoldLoad {
            showsLoading = true
            try? await Task.sleep(for: .seconds(hold))
        }
        #endif
        #if DEBUG
        openTiming.mark("images", ms: (CACurrentMediaTime() - decodeBegan) * 1000)
        #endif
        started = true
        #if DEBUG
        openTiming.mark("started")
        #endif
        clock.start()
        // In the same turn as the start, so the first frame drawn is the close.
        if voiceOver { clock.skip(to: script.closeStart) }
        showsLoading = false
    }

    #if DEBUG
    /// The clock, readable by a UI test: a press cannot be verified by
    /// looking at a picture that is supposed to stop moving.
    private func probe(script: ReplayScript, t: Double) -> some View {
        ZStack(alignment: .topLeading) {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityIdentifier("replayProbe")
            .accessibilityLabel(String(format: "%.3f %.3f %.3f", t, script.closeStart, script.duration))
            Group {
                // Where the first block with a stored photograph is drawn, so
                // a test can tap it. Frame coordinates are screen points.
                if let index = replay.blocks.firstIndex(where: {
                    if case .stored = $0.win.photo { return true } else { return false }
                }) {
                    let r = script.screenRect(ofBlock: index, at: t)
                    let win = replay.blocks[index].win
                    let file: String = if case .stored(let name) = win.photo { name } else { "" }
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("replayPhotoBlock")
                        // "x y w h|file|title": the rect, then what should open.
                        .accessibilityLabel(String(format: "%.1f %.1f %.1f %.1f", r.midX, r.midY, r.width, r.height)
                                            + "|\(file)|\(Self.photoTitle(win.title) ?? "")")
                }
            }
        }
    }
    #endif
}

/// A replay's video, made once and used by Save Video and by Share.
///
/// **One export per replay.** Whichever is pressed first starts it; the
/// other, pressed meanwhile, waits on the same export, and pressed after, uses
/// the finished file. The file is deleted when the replay closes. Leaving the
/// app stops an export in progress (a phone will not encode video in the
/// background) but keeps a finished file.
@MainActor
@Observable
final class ReplayVideo {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed
    }

    enum ShareState: Equatable {
        case idle
        /// Exporting before the share sheet can open.
        case preparing
        case failed
    }

    private(set) var saveState: SaveState = .idle
    private(set) var shareState: ShareState = .idle
    /// The export's progress, 0 to 1, shared by both controls.
    private(set) var progress: Double = 0
    /// Whether an export is running. Save Video's ring follows it; once the
    /// file is made, saving to Photos is a moment with a full ring.
    private(set) var isExporting = false

    @ObservationIgnored private var exporter: ReplayVideoExporter?
    @ObservationIgnored private var running: Task<Result<URL, Error>, Never>?
    @ObservationIgnored private var cancelRequested = false
    @ObservationIgnored private(set) var file: URL?
    @ObservationIgnored private var closed = false
    /// A write to Photos holds the file until it finishes, even past a close.
    @ObservationIgnored private var writingToPhotos = false

    /// A press of Save Video. After a failure the same press tries again.
    func save(replay: Replay, images: @escaping () async -> ReplayImages, now: Date, isSample: Bool) {
        if saveState == .failed { saveState = .idle }
        guard saveState == .idle else { return }
        saveState = .saving
        Task {
            let result = await export(replay: replay, images: images, now: now, isSample: isSample)
            switch result {
            case .failure(let error):
                if Self.isCancel(error) {
                    // Closed, or the app was left: nothing went wrong, so the
                    // control offers Save Video again rather than an error.
                    saveState = .idle
                } else {
                    saveState = .failed
                    HapticsEngine.warning()
                }
            case .success(let url):
                #if DEBUG
                if DebugHarness.exportsReplay {
                    let images = await images()
                    let still = ReplayCard.image(replay, images: images, scale: ReplayCard.shareScale, now: now, isSample: isSample)?.pngData()
                    saveState = Self.keepForInspection(url, exporter: lastExporter, still: still) ? .saved : .failed
                    return
                }
                #endif
                writingToPhotos = true
                let saved = await PhotoLibrarySaver.saveVideo(at: url)
                writingToPhotos = false
                if closed { removeFile() }
                saveState = saved ? .saved : .failed
                if saved { HapticsEngine.success() } else { HapticsEngine.warning() }
            }
        }
    }

    /// A press of Share: the video, exported if it is not yet, then the share
    /// sheet with the file.
    func share(replay: Replay, images: @escaping () async -> ReplayImages, now: Date, isSample: Bool,
               present: @escaping (URL) -> Void) {
        guard shareState != .preparing else { return }
        shareState = .preparing
        Task {
            let result = await export(replay: replay, images: images, now: now, isSample: isSample)
            switch result {
            case .failure(let error):
                if Self.isCancel(error) {
                    shareState = .idle
                } else {
                    shareState = .failed
                    HapticsEngine.warning()
                }
            case .success(let url):
                shareState = .idle
                if !closed { present(url) }
            }
        }
    }

    /// Stops an export in progress. A finished file is kept.
    func cancel() {
        guard running != nil else { return }
        cancelRequested = true
        exporter?.cancel()
    }

    /// The replay closed: stop, and delete the file.
    func close() {
        closed = true
        cancel()
        removeFile()
    }

    private func removeFile() {
        guard let file, !writingToPhotos else { return }
        ReplayVideoExporter.remove(file)
        self.file = nil
    }

    #if DEBUG
    @ObservationIgnored private var lastExporter: ReplayVideoExporter?
    #endif

    /// The finished file, the export already running, or a new export.
    private func export(replay: Replay, images: @escaping () async -> ReplayImages, now: Date,
                        isSample: Bool) async -> Result<URL, Error> {
        if let file { return .success(file) }
        if let running { return await running.value }
        cancelRequested = false
        progress = 0
        isExporting = true
        let task = Task { () -> Result<URL, Error> in
            // Every photograph, not the first seconds': the video is drawn
            // with `ImageRenderer`, which draws what it has.
            let images = await images()
            if cancelRequested || closed { return .failure(ReplayVideoExporter.Failure.cancelled) }
            let job = ReplayVideoExporter(replay: replay, images: images, now: now, isSample: isSample)
            exporter = job
            #if DEBUG
            lastExporter = job
            #endif
            defer { exporter = nil }
            do {
                return .success(try await job.export { [weak self] p in self?.progress = p })
            } catch {
                return .failure(error)
            }
        }
        running = task
        let result = await task.value
        running = nil
        isExporting = false
        if case .success(let url) = result {
            // Finished as the replay closed: the file is deleted, so it is a
            // cancel, not a file for Save Video to hand to Photos.
            if closed {
                ReplayVideoExporter.remove(url)
                return .failure(ReplayVideoExporter.Failure.cancelled)
            }
            file = url
        }
        return result
    }

    private static func isCancel(_ error: Error) -> Bool {
        if case .cancelled? = error as? ReplayVideoExporter.Failure { return true }
        return false
    }

    var saveTitle: String {
        switch saveState {
        case .idle: "Save Video"
        case .saving: "Saving…"
        case .saved: "Saved to Photos"
        case .failed: "Couldn't save"
        }
    }

    /// Whether a press of Save Video does anything: saving, or trying again
    /// after a failure.
    var saveAcceptsPress: Bool { saveState == .idle || saveState == .failed }

    #if DEBUG
    /// `-strataExportReplay`: a copy of the file, and how long it took, in
    /// Documents. A copy, so Share can still use the original.
    private static func keepForInspection(_ url: URL, exporter job: ReplayVideoExporter?, still: Data?) -> Bool {
        let destination = URL.documentsDirectory.appending(path: "replay.mp4")
        ReplayVideoExporter.remove(destination)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            try still?.write(to: URL.documentsDirectory.appending(path: "replay-still.png"))
            guard let job else { return true }
            let s = job.stats
            let report = String(format: "duration %.4f frames %d drawn %d wall %.2fs mix %.0fms maxSlice %.0fms (%@) slices %d landings %d sounding %d\n",
                                s.duration, s.frames, s.drawn, s.wall, s.audioMix * 1000, s.maxSlice * 1000,
                                s.maxSliceAt, s.slices, s.landings, s.sounding)
                + "sounding " + s.soundingTimes.map { String(format: "%.4f", $0) }.joined(separator: " ") + "\n"
                + "draws " + ReplayVideoExporter.Stats.spread(s.draws) + "\n"
                + "slices " + ReplayVideoExporter.Stats.spread(s.sliceList.map(\.0))
                + " over100 \(s.sliceList.filter { $0.0 > 0.1 }.count)\n"
                + "longest " + s.sliceList.sorted { $0.0 > $1.0 }.prefix(6)
                    .map { String(format: "%.0fms %@", $0.0 * 1000, $0.1) }.joined(separator: ", ") + "\n"
            try report.write(to: URL.documentsDirectory.appending(path: "replay-export.txt"), atomically: true, encoding: .utf8)
            print("[REPLAY-EXPORT] \(report)")
            return true
        } catch {
            print("[REPLAY-EXPORT] could not keep the file: \(error)")
            return false
        }
    }
    #endif
}

/// The ring beside a control's word while the video exports.
private struct ExportRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.inkQuiet.opacity(0.3), lineWidth: 2)
            Circle().trim(from: 0, to: progress)
                .stroke(AppColors.inkSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: GridConstants.iconAction, height: GridConstants.iconAction)
        .accessibilityHidden(true)
    }
}

/// A glass capsule with a word, and the export ring beside it when asked.
private struct CapsuleControlLabel: View {
    let title: String
    var ring: Double?

    var body: some View {
        HStack(spacing: GridConstants.gapTight) {
            if let ring { ExportRing(progress: ring) }
            Text(title)
                .font(Typography.headerMedium)
                .lineLimit(1)
                // The words give way before the row does, for the reason
                // `ReplayView.controls` gives.
                .minimumScaleFactor(0.8)
                .foregroundStyle(AppColors.inkPrimary)
        }
        // Layout first, glass after: the Memories drawer's Done, which is
        // this app's glass capsule control.
        .padding(.horizontal, GridConstants.gapLabel)
        .frame(height: GlassIconButton.defaultSide)
        .glassCapsule()
        .contentShape(Capsule())
    }
}

/// Save Video. While saving, a ring beside the word fills with the export.
private struct SaveVideoControl: View {
    let video: ReplayVideo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CapsuleControlLabel(title: video.saveTitle,
                                ring: video.saveState == .saving ? (video.isExporting ? video.progress : 1) : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(video.saveTitle)
        .accessibilityValue(progressValue)
        // Saving… and Saved to Photos do nothing when pressed, so VoiceOver
        // reads them as words, not buttons. Not `.disabled`, which would grey
        // them.
        .accessibilityRemoveTraits(video.saveAcceptsPress ? [] : .isButton)
        .accessibilityAddTraits(video.saveAcceptsPress ? [] : .isStaticText)
        .accessibilityIdentifier("saveVideo")
    }

    private var progressValue: String {
        guard video.saveState == .saving, video.isExporting else { return "" }
        return "\(Int((video.progress * 100).rounded())) percent"
    }
}

/// Share. Pressed before the video exists, it shows the export's ring and
/// opens the share sheet when the file is made.
private struct ShareVideoControl: View {
    let video: ReplayVideo
    let action: () -> Void

    private var title: String { video.shareState == .failed ? "Couldn't share" : "Share" }

    var body: some View {
        Button(action: action) {
            CapsuleControlLabel(title: title, ring: video.shareState == .preparing ? video.progress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(video.shareState == .preparing ? "Preparing the video, \(Int((video.progress * 100).rounded())) percent" : "")
        .accessibilityIdentifier("shareVideo")
    }
}

/// Share's frame in window coordinates. A reference, not state: layout
/// writes it and only the share sheet reads it.
final class ReplayShareAnchor {
    var rect: CGRect = .zero
}

/// The system share sheet with a video file, from the top of whatever is
/// presented, so it opens over the replay's full-screen cover.
enum ReplayShareSheet {
    static func present(_ url: URL, from anchor: CGRect = .zero) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        guard var top = window?.rootViewController else { return }
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // An iPad shows it as a popover, which needs somewhere to point.
        // Pointed at Share itself, in window coordinates.
        if let popover = sheet.popoverPresentationController, let window {
            popover.sourceView = window
            popover.sourceRect = anchor.isEmpty
                ? CGRect(x: window.bounds.midX, y: window.bounds.maxY - 80, width: 1, height: 1)
                : anchor
        }
        top.present(sheet, animated: true)
    }
}

/// Where the tower will stand, while a replay waits for its photographs.
///
/// Shown only when nothing could start within `replayLoadingDelay`. The
/// tower's own empty slot, a dashed ghost in `slotInk`, breathing: the page
/// is about a tower, so the wait is the place it will stand rather than a
/// spinner that could belong to anything. Live only, never in a video, so
/// its breathing runs on the wall clock.
struct ReplayLoadingSlot: View {
    let metrics: ReplayScript.Metrics
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let side = metrics.cell
        let radius = GridConstants.blockCornerRadius(forCell: side)
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate / GridConstants.replayLoadingBreath
            let breath = 0.5 - 0.5 * cos(2 * .pi * phase)
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.slotInk.opacity(scheme == .dark ? 0.075 : 0.038))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AppColors.slotInk.opacity(scheme == .dark ? 0.42 : 0.26),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [GridConstants.ghostBlockDashLength]))
            }
            .frame(width: side, height: side)
            .opacity(0.45 + 0.55 * breath)
            .position(x: metrics.frame.width / 2, y: metrics.baseY - side / 2)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Loading the replay")
    }
}

/// The script for a frame size and motion setting, kept between bodies.
/// A reference, not state: nothing draws from it changing.
final class ReplayScriptCache {
    private var cached: ReplayScript?

    func script(_ replay: Replay, metrics: ReplayScript.Metrics, reduceMotion: Bool) -> ReplayScript {
        if let cached, cached.metrics == metrics, cached.reduceMotion == reduceMotion, cached.replay == replay {
            return cached
        }
        let made = ReplayScript(replay: replay, metrics: metrics, reduceMotion: reduceMotion)
        cached = made
        return made
    }
}

/// Whether the touch in progress became a hold. A reference, not state:
/// nothing draws from it, and gesture callbacks write it mid-touch.
final class PressMemory {
    var held = false
}

/// Wall-clock time into the replay, with pause and skip.
@Observable
final class ReplayClock {
    private var startedAt: Date?
    /// While paused, the moment being held.
    private var pausedT: Double?
    private var offset: Double = 0
    private var frozen: Double?
    /// The time the clock never reads below since the last resume.
    @ObservationIgnored private var floorT: Double = 0
    /// The last `t` a frame was drawn at. Not observed: it changes every
    /// frame, and nothing should re-render because of it.
    @ObservationIgnored var lastRendered: Double = 0

    var isPaused: Bool { pausedT != nil }
    var isFrozen: Bool { frozen != nil }

    func start() { if startedAt == nil { startedAt = Date() } }

    /// From 0 again, playing: pause, skip and the floor are all forgotten.
    /// A frozen clock stays frozen.
    func restart() {
        startedAt = Date()
        offset = 0
        floorT = 0
        pausedT = nil
        lastRendered = 0
    }
    func freeze(at t: Double) { frozen = t }

    func time(at date: Date, duration: Double) -> Double {
        if let frozen { return frozen }
        if let pausedT { return min(duration, pausedT) }
        guard let startedAt else { return 0 }
        return min(duration, max(floorT, date.timeIntervalSince(startedAt) + offset))
    }

    /// Holds the frame that is on screen. Stamping `Date()` instead could
    /// step the picture back by up to a frame, because frames are drawn for
    /// the timeline's `context.date`, which runs a little ahead of now.
    func pause() { if startedAt != nil, pausedT == nil { pausedT = lastRendered } }

    /// Carries on from exactly the held moment.
    func resume() {
        guard let p = pausedT, startedAt != nil else { return }
        startedAt = Date().addingTimeInterval(offset - p)
        floorT = p
        pausedT = nil
    }

    /// Forward only: a tap during the close changes nothing.
    func skip(to t: Double) {
        if let p = pausedT {
            if p < t { pausedT = t }
            return
        }
        guard let s = startedAt else { return }
        let current = Date().timeIntervalSince(s) + offset
        if current < t { offset += t - current }
    }
}

/// Haptics and sound for the landings a frame has passed.
///
/// Rate-limited to `replayFeedbackPerSecond`, so a busy month is a patter and
/// not noise. Under Reduce Motion a day's blocks appear together, and the day
/// gets one landing, its heaviest. Which landings sound is decided once per script by
/// `ReplayAudioMix.landingTimes`, the rule the saved video's track is mixed
/// by, so the video sounds like the replay did. A skip passes many landings
/// at once and plays none of them.
final class ReplayFeedback {
    private var danced = false
    private var landings: [ReplayScript.Landing] = []
    private var allowed: Set<Int> = []

    /// The block indices whose landings sound, for this script.
    func sounding(_ script: ReplayScript) -> Set<Int> {
        // The script is rebuilt with every body; its landings are the key.
        if script.landings != landings {
            landings = script.landings
            // Reduce Motion lands each day at one instant: one sound and one
            // haptic for the day, at its heaviest block.
            let candidates = script.reduceMotion ? ReplayAudioMix.heaviestPerInstant(landings) : landings
            allowed = Set(ReplayAudioMix.landingTimes(candidates, limitPerSecond: GridConstants.replayFeedbackPerSecond)
                .map(\.blockIndex))
        }
        return allowed
    }

    func play(_ script: ReplayScript, from old: Double, to new: Double) {
        guard new > old, new - old <= GridConstants.replaySkipGap else { return } // a skip is silent
        let allowed = sounding(script)
        for landing in script.landings where landing.time > old && landing.time <= new && allowed.contains(landing.blockIndex) {
            if landing.mass >= 3 { HapticsEngine.squish(mass: landing.mass) } else { HapticsEngine.tick() }
            SoundEngine.blockImpact(mass: landing.mass, column: landing.column,
                                    gain: GridConstants.replayImpactGain)
        }
        if !danced, old < script.danceStart, new >= script.danceStart {
            danced = true
            HapticsEngine.success()
        }
    }
}

#if DEBUG
/// `[REPLAY-OPEN]`: how long a replay takes from presenting to its first
/// drawn frame, and what that time went on. Printed, and appended to
/// `Documents/replay-open.log`, which survives the unified log's delays.
final class ReplayOpenTiming {
    private let began = CACurrentMediaTime()
    private var lines: [String] = []
    private var reported = false

    func mark(_ name: String, ms: Double? = nil) {
        let at = (CACurrentMediaTime() - began) * 1000
        lines.append(ms.map { String(format: "%@ %.1fms (at %.0fms)", name, $0, at) } ?? String(format: "%@ at %.0fms", name, at))
    }

    private var marked: Set<String> = []

    /// A mark made the first time only, for a view body.
    func markOnce(_ name: String) {
        guard marked.insert(name).inserted else { return }
        mark(name)
    }

    func firstFrame(replay: Replay) {
        guard !reported else { return }
        reported = true
        mark("appeared")
        // The frame is committed after this pass; the next turn of the main
        // queue is when it is on screen.
        DispatchQueue.main.async { [self] in
            let at = (CACurrentMediaTime() - began) * 1000
            let photos = Set(replay.blocks.compactMap { $0.win.photo }).count
            let line = String(format: "[REPLAY-OPEN] %@ wins %d photos %d first frame %.0fms | ", replay.period.id, replay.count, photos, at)
                + lines.joined(separator: ", ")
            print(line)
            ReplayOpenTiming.append(line)
        }
    }

    func log(_ line: String) {
        print(line)
        Self.append(line)
    }

    static func append(_ line: String) {
        let url = URL.documentsDirectory.appending(path: "replay-open.log")
        let data = Data((line + "\n").utf8)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url)
        }
    }
}

/// How evenly the live replay was drawn, phase by phase: the gap between one
/// evaluated frame and the next. A recording of the simulator drops frames of
/// its own, so a film alone cannot say whether the app kept up.
final class ReplayCadence {
    private var last: CFTimeInterval?
    private var gaps: [ReplayScript.Phase: [Double]] = [:]
    private var reported = false

    func record(_ phase: ReplayScript.Phase, finished: Bool) {
        let now = CACurrentMediaTime()
        if let last { gaps[phase, default: []].append(now - last) }
        last = now
        guard finished, !reported else { return }
        reported = true
        for (phase, g) in gaps.sorted(by: { "\($0.key)" < "\($1.key)" }) where !g.isEmpty {
            let s = g.sorted()
            func pct(_ p: Double) -> Double { s[min(s.count - 1, Int(Double(s.count) * p))] * 1000 }
            print(String(format: "[REPLAY-CADENCE] %@ frames %d p50 %.1fms p90 %.1fms p99 %.1fms max %.1fms over25ms %d over50ms %d",
                         "\(phase)", s.count, pct(0.5), pct(0.9), pct(0.99), s.last! * 1000,
                         s.filter { $0 > 0.025 }.count, s.filter { $0 > 0.05 }.count))
        }
    }
}
#endif
