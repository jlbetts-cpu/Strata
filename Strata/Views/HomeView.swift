import SwiftUI
import SwiftData

/// **Home: the Wins screen, become a page.**
///
/// The owner, 2026-09-22: "since we are turning the Wins page into like an
/// actual home page... a folder standalone doesn't look all too good."
///
/// He is right, and it is worth writing down why rather than just doing it.
/// A single folder in the middle of a screen has no scale: nothing tells you
/// whether it is full, whether it is a good day, whether there were other
/// days. It is a logo of a folder. Put six of them in a row and every one of
/// those questions answers itself by comparison — today's is open and the
/// others are shut, today's is fuller, yesterday's is a different colour
/// because somebody chose one.
///
/// **This is the top of the page and only the top.** His words: "I just want
/// just this top part for now and we can work down as we go." What is below
/// Recents is deliberately empty; it is not a layout waiting to be finished
/// so much as the next conversation.
///
/// **Light, on a warm white, with the dark bar underneath.** See `HomeGround`
/// for why Home has a ground of its own rather than rebinding the app's.
struct HomeView: View {
    /// Today's wins, from the same view model the tower was given, so the
    /// count on Home and the count everywhere else cannot disagree.
    var todayBlocks: [PlacedBlock]
    var onOpenWin: (UUID) -> Void = { _ in }
    /// Told to the screen, so its header can get out of the way while a
    /// folder is open.
    @Binding var isOpenExternally: Bool
    /// What colour the tab bar's glyphs should be, which depends on the
    /// screen that is showing rather than on this one. See `TabBarGlyphs`.
    /// Home is always mounted, so this is where the one probe lives.
    var tabGlyphTint: UIColor? = nil
    /// Whether Home is the tab you are looking at. **Not the same as being on
    /// screen**: a `TabView` keeps every tab's content mounted, so `onAppear`
    /// fires once at launch and never again. This is what tells Home it has
    /// just been arrived at.
    var isActive: Bool = true

    /// **Its own query, over its own window, on purpose.**
    ///
    /// `MainAppView`'s `logs` is filtered to the current month, which on the
    /// first of the month is one day: Recents would show a single folder and
    /// look broken. Widening that query would change what the tower, the
    /// timeline and the perfect-day set are each handed. A second query with
    /// its own predicate changes nothing upstream, and `dateString` is
    /// indexed, so a range over two weeks is the index scan it was designed
    /// for rather than a table scan.
    @Query private var recentLogs: [HabitLog]

    /// How far back Recents reaches. Two weeks is the span a person still
    /// thinks of as "lately" — beyond it you want a calendar, not a shelf,
    /// and that is what Memories is.
    private static let window = 14

    @State private var store = FolderStyleStore()
    /// Small thumbnails for what shows through the glass. A peeking card is
    /// 38% of a 150pt folder, so 57pt, so 171px on a 3x screen: the 320 tier
    /// is already nearly twice what is drawn.
    @State private var peeks: [String: UIImage] = [:]
    /// The day whose folder is open, and the bigger photographs it needs.
    @State private var openDay: RecentDay?
    @State private var openPhotos: [String: UIImage] = [:]
    @State private var customising: RecentDay?
    /// The day cut-outs, by day. See `DayStickerService` — most days have
    /// none, and the service remembers that so a day is examined once.
    @State private var stickers: [String: UIImage] = [:]
    /// Where each folder sits on the page, and how big the page is: together
    /// they say where an opening folder should come FROM.
    @State private var folderFrames: [String: CGRect] = [:]
    @State private var pageSize: CGSize = .zero
    @State private var mood = FolderMood()
    /// How far the page has settled after arriving on it, 0 to 1.
    @State private var arrival: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The camera's own corner. See `CameraView.cornerRadius`.
    private static let panelRadius: CGFloat = 40

    init(todayBlocks: [PlacedBlock],
         onOpenWin: @escaping (UUID) -> Void = { _ in },
         isOpenExternally: Binding<Bool>,
         tabGlyphTint: UIColor? = nil,
         isActive: Bool = true) {
        self.todayBlocks = todayBlocks
        self.onOpenWin = onOpenWin
        self._isOpenExternally = isOpenExternally
        self.tabGlyphTint = tabGlyphTint
        self.isActive = isActive
        let start = Calendar.current.date(byAdding: .day, value: -(Self.window - 1), to: Date()) ?? Date()
        let key = DateUtils.dateString(from: start)
        _recentLogs = Query(filter: #Predicate<HabitLog> { log in
            log.dateString >= key && (log.completed || log.skipped)
        })
    }

    // MARK: - The days

    private var todayKey: String { DateUtils.dateString(from: Date()) }

    /// What has to change before the photographs and the cut-outs are worth
    /// working out again: which days are on the row, and which wins are in
    /// today's. Cheap to compute and stable while nothing has happened.
    private var signature: String {
        days.map(\.id).joined(separator: ",")
            + "#" + todayBlocks.map(\.id.uuidString).joined(separator: ",")
    }

    /// **Today first, then the days behind it, newest to oldest.**
    ///
    /// Days with nothing in them are left out — a row of empty folders is a
    /// row of days you are being reminded you failed at, which is the exact
    /// thing this app does not do. Today is the one exception and is always
    /// present, because an empty folder for today is not a reproach, it is
    /// the place the next win goes.
    private var days: [RecentDay] {
        var byDate: [String: [HabitLog]] = [:]
        for log in recentLogs where log.habit != nil && log.dateString != todayKey {
            byDate[log.dateString, default: []].append(log)
        }

        let past = byDate.keys.sorted(by: >).compactMap { key -> RecentDay? in
            guard let date = DateUtils.date(from: key),
                  let logs = byDate[key], !logs.isEmpty else { return nil }
            let ordered = logs.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            return RecentDay(id: key, date: date, count: logs.count,
                             peek: ordered.prefix(5).compactMap(win(from:)))
        }

        let today = RecentDay(id: todayKey, date: Date(), count: todayBlocks.count,
                              peek: todayBlocks.reversed().prefix(5).map(win(from:)),
                              isToday: true)
        return [today] + past
    }

    private func win(from log: HabitLog) -> ScatterWin? {
        guard let habit = log.habit else { return nil }
        return ScatterWin(id: log.id.uuidString,
                          image: peeks[log.id.uuidString],
                          size: habit.blockSize,
                          title: habit.title,
                          colour: habit.displayCategory.style.baseColor)
    }

    private func win(from block: PlacedBlock) -> ScatterWin {
        ScatterWin(id: block.id.uuidString,
                   image: peeks[block.id.uuidString],
                   size: block.look.blockSize,
                   title: block.look.title,
                   colour: block.look.displayCategory.style.baseColor)
    }

    /// **The photographs come through `ImageManager`, not off the disk.** It
    /// is the app's bounded, cached, off-main decode path, and going round it
    /// is what froze the app the last time somebody did.
    ///
    /// Bounded twice over: five per day, and only the days on the row. A
    /// fortnight of twelve-win days is 70 thumbnails at 320px, not 168
    /// originals at whatever the camera shot.
    private func loadPeeks() async {
        var wanted: [(String, String)] = []
        for block in todayBlocks.reversed().prefix(5) {
            if let name = block.look.imageFileName { wanted.append((block.id.uuidString, name)) }
        }
        for day in days where !day.isToday {
            for win in day.peek {
                guard peeks[win.id] == nil else { continue }
                if let log = recentLogs.first(where: { $0.id.uuidString == win.id }),
                   let name = log.imageFileName {
                    wanted.append((win.id, name))
                }
            }
        }
        // **The folders you can see, then the rest.**
        //
        // Every thumbnail was decoded and then published in ONE assignment,
        // which meant the row sat empty while a fortnight of photographs was
        // read and then re-rendered all fourteen folders on a single frame.
        // Measured with `-strataPerfProbe`: the twenty seconds from Home
        // appearing had four display-link gaps over 50ms, worst 106ms, while
        // the settled scroll had none at all. The jank was never the scroll.
        //
        // Publishing the first three days as soon as they are ready puts
        // photographs on the folders you are actually looking at within one
        // frame's work rather than fourteen, and the rest arrive behind
        // them. The split is `firstPaint` items rather than a time, because
        // what matters is how much lands in one render, not how long it took
        // to fetch.
        let firstPaint = 3 * 5
        var loaded = peeks
        var published = false
        for (index, item) in wanted.enumerated() where loaded[item.0] == nil {
            if let image = await ImageManager.shared.loadThumbnail(
                fileName: item.1, maxWidth: 320) {
                loaded[item.0] = image
            }
            if !published && index >= firstPaint - 1 {
                published = true
                peeks = loaded
                // Let the render happen before the rest is fetched, so the
                // decode of day four is not queued ahead of the frame that
                // draws day one.
                await Task.yield()
            }
        }
        if loaded.count != peeks.count { peeks = loaded }
    }

    /// **The day cut-outs, worked out after everything else has arrived.**
    ///
    /// A foreground-instance mask is the most expensive thing this app asks
    /// of the phone, so this runs LAST and one day at a time: the row is
    /// already drawn, the photographs behind the glass are already there, and
    /// a sticker arriving a second later reads as the app noticing something
    /// rather than as the screen still loading.
    ///
    /// `DayStickerService` remembers both answers — the cut-out and the
    /// "nothing here" — so a day is examined once ever, not once per appear.
    private func loadStickers() async {
        #if DEBUG
        if DebugHarness.fakesStickers {
            // **Real cut-outs, dropped in from outside.**
            //
            // Standing a plain demo photograph in was enough to judge the
            // placement and nothing else — it is a rectangle, so it says
            // nothing about whether the die line reads, whether a subject's
            // edges survive at 45pt, or whether a cut-out on a coloured
            // folder looks like a sticker. Any PNG copied into
            // `strata-images/stickers/fake-*.png` is used instead, so a
            // cut-out generated on a Mac (where the model can actually run)
            // can be looked at inside the real view.
            //
            //   xcrun simctl get_app_container <dev> JaydenBetts.Strata data
            //   cp *.png <container>/Documents/strata-images/stickers/
            let folder = ImageManager.shared.imageDirectory
                .appendingPathComponent("stickers", isDirectory: true)
            let dropped = ((try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.lastPathComponent.hasPrefix("fake-") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .compactMap { UIImage(contentsOfFile: $0.path) }
            // Every day, unlike the real thing where most have none: the
            // harness exists to judge how the placement VARIES, and a sample
            // of one says nothing about variety.
            for (index, day) in days.enumerated() {
                if !dropped.isEmpty {
                    stickers[day.id] = dropped[index % dropped.count]
                } else if let stand = UIImage(named: ["DemoPhoto4", "DemoPhoto11", "LookPreview"][index % 3]) {
                    stickers[day.id] = stand
                }
            }
            return
        }
        #endif
        let service = DayStickerService.shared
        var live: Set<String> = []
        for day in days {
            let logs = day.isToday
                ? todayBlocks.compactMap { block -> DayStickerService.Candidate? in
                    guard let name = block.look.imageFileName else { return nil }
                    return DayStickerService.Candidate(
                        fileName: name,
                        named: !block.look.title.isEmpty,
                        weight: block.look.blockSize.massTier,
                        located: block.log.latitude != nil)
                }
                : recentLogs.filter { $0.dateString == day.id }
                    .compactMap { log -> DayStickerService.Candidate? in
                        guard let name = log.imageFileName, let habit = log.habit else { return nil }
                        return DayStickerService.Candidate(
                            fileName: name,
                            named: !habit.title.isEmpty,
                            weight: habit.blockSize.massTier,
                            located: log.latitude != nil)
                    }
            guard logs.count >= 1 else { continue }
            let key = DayStickerService.key(day: day.id, winIDs: logs.map(\.fileName))
            let made = await service.sticker(key: key, candidates: logs)
            // **Assigned either way.** It only ever wrote a sticker in, so a
            // day that gained a photograph and stopped qualifying — or one
            // whose winner was deleted — kept showing the old cut-out until
            // the app was relaunched.
            if stickers[day.id] !== made { stickers[day.id] = made }
            live.insert(key)
            // **A pause between days, not just a yield.**
            //
            // On a phone the subject mask is a real model on the Neural
            // Engine — a few hundred milliseconds per photograph, up to four
            // photographs a day, fourteen days on a first run. Yielding
            // between them keeps the main thread free but still asks the
            // device to work flat out for the best part of a minute the
            // first time Home is opened, which is how an app becomes the one
            // that gets warm in your hand. A sixth of a second between days
            // costs nothing anybody will see — the stickers arrive over the
            // first half minute rather than the first ten seconds — and it
            // is all cached after that.
            try? await Task.sleep(for: .milliseconds(160))
        }
        // Everything not on the row any more, including the older key of a
        // day whose wins have changed. Off the main actor: it is a directory
        // walk and a handful of unlinks, and nothing is waiting on it.
        let directory = ImageManager.shared.imageDirectory
        Task.detached(priority: .background) {
            _ = DayStickerService.prune(keeping: live, in: directory)
        }
        #if DEBUG
        // A second window, opened once everything has actually arrived. The
        // first one starts at `onAppear` and therefore measures the launch —
        // photographs decoding, cut-outs being attempted — which is real but
        // is not what "does the scroll feel smooth" is asking.
        if !Self.measuredSettled {
            Self.measuredSettled = true
            PerfProbe.window("home-settled", seconds: 15)
        }
        #endif
    }

    #if DEBUG
    nonisolated(unsafe) private static var measuredSettled = false
    #endif

    /// The full-size-enough photographs for a day somebody actually opened.
    /// 640 is the tier baked beside every original and is bigger than any
    /// card inside the folder is drawn.
    private func loadOpen(_ day: RecentDay) async {
        var loaded: [String: UIImage] = [:]
        let names: [(String, String)] = day.isToday
            ? todayBlocks.compactMap { b in b.look.imageFileName.map { (b.id.uuidString, $0) } }
            : recentLogs.filter { $0.dateString == day.id }
                        .compactMap { l in l.imageFileName.map { (l.id.uuidString, $0) } }
        for (id, name) in names {
            if let image = await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: 640) {
                loaded[id] = image
            }
        }
        openPhotos = loaded
    }

    /// Every win in the opened day, at the size the inside draws them.
    private func openWins(_ day: RecentDay) -> [ScatterWin] {
        if day.isToday {
            return todayBlocks.reversed().map { block in
                ScatterWin(id: block.id.uuidString,
                           image: openPhotos[block.id.uuidString],
                           size: block.look.blockSize,
                           title: block.look.title,
                           colour: block.look.displayCategory.style.baseColor)
            }
        }
        return recentLogs
            .filter { $0.dateString == day.id && $0.habit != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap { log in
                guard let habit = log.habit else { return nil }
                return ScatterWin(id: log.id.uuidString,
                                  image: openPhotos[log.id.uuidString],
                                  size: habit.blockSize,
                                  title: habit.title,
                                  colour: habit.displayCategory.style.baseColor)
            }
    }

    // MARK: - Body

    var body: some View {
        #if DEBUG
        PerfProbe.count("HomeView")
        #endif
        return ZStack {
            // **The page's floor is the camera's black, and the light part is
            // a sheet laid on top of it.**
            //
            // The owner: "I want the dark mode bottom to actually go all the
            // way up to under the folders text... make sure it's like that
            // rounded vibe just like the bottom of the camera, that black
            // part, how it curves up." Then, on the first attempt: "it's
            // curved the wrong way, and I don't think it's the same darkness
            // as the camera."
            //
            // Both notes were the same mistake. I drew the dark part as a
            // panel with its own rounded TOP corners, which curves the dark
            // down and away at the edges. The camera does the opposite and
            // that is why it looks right: its black is a plain full-bleed
            // rectangle, and the LIT thing in front of it — the viewfinder —
            // has rounded BOTTOM corners. The black is not shaped at all; it
            // is what shows around a shape. That is what makes it curve up.
            //
            // So the dark is the ground here, `Grey.g950` exactly as
            // `CameraView` uses it, and the warm white is a sheet over it
            // with two rounded bottom corners.
            Grey.g950.ignoresSafeArea()

            // The bar's glyphs, told what they are sitting on. Zero sized,
            // draws nothing, and this is the only place in the app that
            // touches the bar.
            TabBarGlyphs(tint: tabGlyphTint).frame(width: 0, height: 0)

            VStack(alignment: .leading, spacing: 0) {
                // Recents sits at the top of the sheet and the room under it
                // is room, not a gap to fill. More sections are coming and
                // they start here, so nothing below Recents is centred,
                // stretched or padded to look occupied — the first thing the
                // next section would have to do is undo it.
                VStack(alignment: .leading, spacing: 0) {
                    RecentsRow(days: days,
                               styles: { store.style(for: $0) },
                               stickers: { stickers[$0] },
                               onOpen: open(_:),
                               onCustomise: { customising = $0 })
                        .padding(.top, GridConstants.gapItem)
                        // **The page settles onto itself when you arrive.**
                        //
                        // The owner: "make sure the transition between tabs
                        // is clean and effortless, I'm expecting some nice
                        // animations coming in and out cleanly."
                        //
                        // A `TabView` cross-fades, which is quick and correct
                        // and says nothing: filmed at 30fps the swap is two
                        // frames, and Home simply IS there. Ten points of
                        // rise over a quarter of a second is enough to read
                        // as the page arriving and short enough that it is
                        // finished before a thumb has left the bar.
                        //
                        // Only the content moves. The ground, the sheet and
                        // its rounded corners are still, because they are the
                        // page rather than what is on it — sliding those
                        // would be the whole screen lurching.
                        .offset(y: (1 - arrival) * 14)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(alignment: .bottom) { lightSheet }

                // **The strip, and it is the camera's own 20.** The first
                // version cut the page in half under the folders' labels and
                // filled everything below with black, which the owner read
                // straight away: "put the black part right where it is in the
                // camera, not so high up." The camera's black is not a panel
                // at all — it is a 20pt margin the viewfinder stops short of,
                // with the floating bar sitting in it. Home does the same
                // thing, which also gives the page back the room under
                // Recents that the next section has to go in.
                Color.clear.frame(height: GridConstants.bottomStrip)
            }

            inside
        }
        .modifier(HomePageWiring(frames: $folderFrames, size: $pageSize))
        // **One signature for both, and it has to include today's wins.**
        //
        // The sticker task was keyed on the day KEYS alone, which change at
        // midnight and when a day scrolls into the window — and not when you
        // photograph something. So a win logged today never produced a
        // sticker until the app was relaunched, which is the one case
        // somebody would actually watch for. `DayStickerService` already
        // keys its cache on the day's file names, so re-running the loop
        // costs nothing for the days that have not moved.
        .task(id: signature) { await loadPeeks() }
        .task(id: signature) { await loadStickers() }
        .onAppear {
            mood.contents = FolderContents(count: todayBlocks.count)
            store.prune(before: FolderStyleStore.cutoff(from: Date()))
            #if DEBUG
            // Twenty seconds from the moment Home appears, reported to
            // Documents/perf.log — frames, gaps, the worst one, and the
            // memory high-water. The unified log drops lines tens of seconds
            // late on a loaded simulator, which is why the file is the one to
            // read. Only with `-strataPerfProbe`.
            PerfProbe.window("home", seconds: 20)
            #endif
        }
        .onChange(of: todayBlocks.count) { old, new in
            mood.contents = FolderContents(count: new)
            if new > old { mood.react(to: .winAdded) }
        }
        .onDisappear { mood.stopDrifting() }
        // **Set it back, let a frame happen, THEN animate.**
        //
        // The first version did `arrival = 0` and `withAnimation { arrival = 1 }`
        // in the same block, which SwiftUI batches into one update: the view
        // never renders at 0, so the spring has nothing to travel from.
        // Filmed and measured, the folders moved 2pt of an intended 14.
        // The hop to the next main-actor turn is what gives it a frame to
        // start from.
        //
        // **Only on arriving, never on leaving.** Resetting on deactivate
        // made the page jump up 14pt while it was still cross-fading OUT,
        // so the exit popped. The cross-fade carries the exit on its own;
        // this only has to carry the entrance.
        //
        // **And only the offset.** Fading as well would be a second fade over
        // the `TabView`'s own, which is two animations disagreeing about the
        // same pixels. The swap is the system's; the settle is ours.
        .onChange(of: isActive) { _, active in
            guard active, !reduceMotion else { return }
            arrival = 0
            Task { @MainActor in
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) { arrival = 1 }
            }
        }
        .sheet(item: $customising) { day in
            FolderStyleSheet(title: day.title(),
                             dayKey: day.id,
                             count: day.count,
                             contents: day.peek,
                             style: store.style(for: day.id),
                             onChange: { store.set($0, for: day.id) })
                // Measured off the render rather than guessed: the content
                // ends about two thirds of the way down a 420 sheet, and the
                // empty third reads as something failing to load.
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
    }

    /// **Broken out of `body` because the type checker gave up on it.**
    ///
    /// "The compiler is unable to type-check this expression in reasonable
    /// time" is not a suggestion about style: a `ZStack` of four branches
    /// under a dozen modifiers is an exponential inference problem, and the
    /// only fix is fewer things in one expression. `MainAppView` has the
    /// same note in four places.
    @ViewBuilder
    private var inside: some View {
        if let day = openDay {
            FolderInside(title: day.title(),
                         wins: openWins(day),
                         tint: store.style(for: day.id).tint(for: day.id),
                         onClose: close,
                         onOpenWin: { id in
                             if let uuid = UUID(uuidString: id) { onOpenWin(uuid) }
                         },
                         showsTitle: true,
                         bottomInset: 96)
                    // **It comes out of the folder you pressed.**
                    //
                    // It crossfaded, which is the transition for "a different
                    // screen" and says nothing about where you came from. On
                    // a row of six identical objects that is exactly the
                    // thing the animation has to say: this one. Scaling up
                    // from the pressed folder's own centre makes the screen
                    // the inside of that folder rather than a page that
                    // replaced it, and it costs one `UnitPoint`.
                    //
                    // 0.34 rather than the folder's true share of the screen
                    // (about 0.38 wide but 0.15 tall): a transform that
                    // starts at the real rect squashes the layout on the way
                    // out, and what reads as opening is the MOVEMENT plus the
                    // origin, not a literal morph.
                .transition(.scale(scale: 0.34, anchor: openAnchor(day))
                    .combined(with: .opacity))
                .task(id: day.id) { await loadOpen(day) }
        }
    }

    /// The page's own measurements, as a modifier so `body` does not have to
    /// carry them: which coordinate space the folders report their frames in,
    /// the frames themselves, and how big the page is. Together they say
    /// where an opening folder should come from.
    private struct HomePageWiring: ViewModifier {
        @Binding var frames: [String: CGRect]
        @Binding var size: CGSize

        func body(content: Content) -> some View {
            content
                .coordinateSpace(HomeSpace.space)
                .onPreferenceChange(FolderFrames.self) { frames = $0 }
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { size = geo.size }
                            .onChange(of: geo.size) { _, new in size = new }
                    }
                }
        }
    }

    /// The warm white sheet the top of the page sits on.
    ///
    /// **It reaches a long way up on purpose.** The header is not inside this
    /// view — it is a `safeAreaInset` on the tab above — so the sheet has to
    /// extend past its own bounds and out under the status bar to get behind
    /// it. 1200 is more than any iPhone is tall, which is the point: there is
    /// no arithmetic here to get wrong on a different device, and the excess
    /// is off-screen.
    private var lightSheet: some View {
        UnevenRoundedRectangle(topLeadingRadius: 0,
                               bottomLeadingRadius: Self.panelRadius,
                               bottomTrailingRadius: Self.panelRadius,
                               topTrailingRadius: 0,
                               style: .continuous)
            .fill(HomeGround.top)
            .padding(.top, -1200)
            .ignoresSafeArea(edges: .top)
    }

    /// The point on the page the opening folder grows out of, as a fraction
    /// of the page. Falls back to the middle for a folder whose frame has not
    /// been reported — which is only ever the first frame after a rotation.
    private func openAnchor(_ day: RecentDay) -> UnitPoint {
        guard let frame = folderFrames[day.id],
              pageSize.width > 0, pageSize.height > 0 else { return .center }
        return UnitPoint(x: min(max(frame.midX / pageSize.width, 0), 1),
                         y: min(max(frame.midY / pageSize.height, 0), 1))
    }

    private func open(_ day: RecentDay) {
        openPhotos = [:]
        isOpenExternally = true
        guard !reduceMotion else { openDay = day; return }
        // A spring rather than an ease, because this is an object moving
        // rather than a value changing. Lightly damped enough to settle in
        // one pass: an overshoot on a full screen of photographs reads as a
        // wobble, not as life.
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { openDay = day }
    }

    private func close() {
        HapticsEngine.lightTap()
        isOpenExternally = false
        guard !reduceMotion else { openDay = nil; openPhotos = [:]; return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.90)) { openDay = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            openPhotos = [:]
        }
    }
}

/// **Dressing one day's folder: a colour, and whether it has a face.**
///
/// Two controls, because those are the two things the owner asked to be
/// able to change. It is reached by holding a folder rather than by a button
/// on the page: a colour picker that is always on screen is a page about
/// customisation, and this page is about the week.
struct FolderStyleSheet: View {
    var title: String
    /// The day this folder belongs to, because a folder nobody has recoloured
    /// takes the colour that day was dealt. See `FolderTint.seeded`.
    var dayKey: String
    var count: Int
    /// **What is actually in the folder.** The preview was drawn empty, so
    /// choosing a colour meant judging it on a bare plate — and the whole
    /// point of the front being glass is that the colour is seen WITH
    /// photographs behind it. A pale tint that looks weak on its own can be
    /// exactly right over a stack.
    var contents: [ScatterWin] = []
    @State var style: FolderStyle
    var onChange: (FolderStyle) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    /// The faces offered, out of the rig's own set. Not all nineteen: a
    /// picker with nineteen near-identical pairs of eyes is a test, not a
    /// choice. These are the ones that read apart from each other at 150pt.
    private static let faces = ["Idle", "Delighted", "Derp", "Wink", "Surprised", "Smug"]

    var body: some View {
        VStack(spacing: GridConstants.gapLabel) {
            // The folder itself, live and full, so a colour is chosen by
            // looking at the thing rather than at a swatch.
            WinFolder(title: title, count: count,
                      tint: style.tint(for: dayKey),
                      contents: contents,
                      openAmount: 1,
                      showsFace: style.faceName != nil,
                      expression: style.expression,
                      isAlive: true,
                      stickerSeed: dayKey)
                .frame(width: 168)
                .padding(.top, GridConstants.gapItem)

            // Which day is being dressed. The sheet had no title at all,
            // which is fine when you have just held a folder and forgettable
            // three seconds later.
            Text(title)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)

            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                Text("Colour")
                    .font(Typography.sectionLabel)
                    .kerning(Typography.sectionKerning)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.inkTertiary)

                HStack(spacing: GridConstants.gapItem) {
                    // **Auto first, and it is the way back.** Every other
                    // swatch writes a choice; without this one a folder
                    // recoloured by accident could never be returned to the
                    // colour its day was dealt, and the store would keep a
                    // row for it forever. It draws the dealt colour with a
                    // ring cut through it, so it is visibly "this one, but
                    // not pinned".
                    swatch(colour: FolderTint.seeded(for: dayKey).colour,
                           id: "", name: "Automatic")
                        .overlay {
                            Circle().strokeBorder(HomeGround.top.opacity(0.9), lineWidth: 2)
                                .frame(width: 16, height: 16)
                                .allowsHitTesting(false)
                        }
                    ForEach(FolderTint.all) { option in
                        swatch(colour: option.colour, id: option.id, name: option.name)
                    }
                }

                Text("Face")
                    .font(Typography.sectionLabel)
                    .kerning(Typography.sectionKerning)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.inkTertiary)
                    .padding(.top, GridConstants.gapTight)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GridConstants.gapTight) {
                        // Off first, because off is the default and the first
                        // chip is where the eye starts.
                        faceChip(label: "Off", name: nil)
                        ForEach(Self.faces, id: \.self) { name in
                            faceChip(label: name, name: name)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GridConstants.gapWide)

            Spacer(minLength: 0)
        }
        .background(HomeGround().ignoresSafeArea())
    }

    private func swatch(colour: Color, id: String, name: String) -> some View {
        Button {
            HapticsEngine.lightTap()
            style.tintID = id
            onChange(style)
        } label: {
            Circle()
                .fill(colour)
                .frame(width: 34, height: 34)
                .overlay {
                    Circle().strokeBorder(AppColors.inkPrimary,
                                          lineWidth: style.tintID == id ? 2 : 0)
                        .padding(-4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    private func faceChip(label: String, name: String?) -> some View {
        let on = style.faceName == name
        return Button {
            HapticsEngine.lightTap()
            style.faceName = name
            onChange(style)
        } label: {
            Text(label)
                .font(Typography.headerSmall)
                .foregroundStyle(on ? HomeGround.top : AppColors.inkPrimary)
                .padding(.horizontal, GridConstants.gapLabel)
                .frame(height: 36)
                .background {
                    Capsule().fill(on ? AnyShapeStyle(AppColors.inkPrimary)
                                      : AnyShapeStyle(AppColors.quietFill))
                }
        }
        .buttonStyle(.plain)
    }
}
