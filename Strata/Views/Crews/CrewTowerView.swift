import SwiftUI

/// A crew's tower for today.
///
/// Laid out the way a group thread is in Messages: back on the left, the
/// crew's faces in the middle with its name in a glass capsule under them,
/// and the page below is today's tower, drawn by the same blocks, lattice,
/// drop and dance as your own (`TowerBlocksForEach`).
///
/// A friend's win falls in while you watch. Every tenth win the tower dances,
/// and so does the win that makes everyone in today. Nothing else
/// celebrates, and nothing counts anyone against anyone.
struct CrewTowerView: View {
    let crewID: CrewID
    var onBack: () -> Void
    var onAddWin: () -> Void = {}
    /// The empty slot's one-tap win, sent to this crew. The same slot as
    /// Wins, doing the same thing (the owner, 2026-10-03: "where is the +
    /// block for the crew chats they should function pretty much the exact
    /// same"). Nil hides the slot.
    var onLogWin: ((BlockSize, HabitCategory) -> Void)? = nil
    /// A crew plan's box, pressed: the camera, the library and the sheets
    /// are the Wins page's (`PlannedAction`).
    var onPlanned: (PlanItem, PlannedAction) -> Void = { _, _ in }
    /// The app root's own, as handed in, before the chat steps aside for them.
    private let rootAddWin: () -> Void
    private let rootPlanned: (PlanItem, PlannedAction) -> Void
    /// The rows the crew's planned boxes need (`CrewPlannedLayer`), and a
    /// count that has them read again.
    @State private var plannedRows = 0
    @State private var plannedNudge = 0
    /// The size the slot is being drawn out to, and the colour it shows.
    @State private var drawingSize: BlockSize = .small
    @State private var slotColour: HabitCategory = HabitCategory.selectable.randomElement() ?? .health

    @State private var model = CrewTowerModel()
    @State private var parking: CrewParking
    @State private var showsInfo = false
    /// Today's crew chat, from the glass button top right.
    @State private var showsChat = false
    /// The drawer is over the resting bar (`ChatDrawer.covering`): the bar
    /// hides under it, so the two read as one panel.
    @State private var chatCovering = false
    /// The chat has finished rising (or not yet finished falling): the heads
    /// rest under it. A beat behind `showsChat`, so putting every head to
    /// sleep, or waking them, never shares a frame with the drawer moving
    /// (the probe, 2026-10-14: the first frame of the rise was held 160ms).
    @State private var chatSettled = false
    /// The resting bar's top edge on screen, where the drawer rises from.
    @State private var restTop: CGFloat = 0
    /// How the resting bar opened the chat: to read, to write, or with +.
    @State private var chatOpening: ChatRestBar.Opening = .reading
    /// The win Reply under the hold's bar is answering, for the chat.
    @State private var answeringWin: UUID?
    /// **The native chat** (`NativeChat`): a sheet only while the chat is
    /// open, at the height in `chatDetent`, stepping aside for the app root's
    /// sheets (`chatAside`). At rest the crew stands on `ChatRestBar`, flush
    /// with the foot of the screen (the owner, 2026-10-15: the floating
    /// resting card "looks like a glitch on the bottom", and the chat was
    /// "super laggy"; his pick "Bar, then sheet").
    private var chatUp: Bool { showsChat }
    @State private var chatDetent: PresentationDetent = NativeChat.reading
    @State private var chatAside = ChatAside()
    private var native: Bool { NativeChat.isOn }
    /// "Just you so far.": once a crew, while nobody else has joined.
    @State private var aloneTip = false
    /// The crew's week, offered from Sunday evening (`CrewWeekReplay`).
    @State private var weekCard: Replay?
    /// **The crew widget, said once** (the second round of research,
    /// 2026-10-15: nothing in the app mentioned it).
    @State private var widgetTip = false
    /// The days missed while away (`CrewWeekReplay.missed`), offered once.
    @State private var catchUp: Replay?
    @State private var playingWeek: Replay?
    @State private var plansRefresh = 0
    /// A photograph opened from its block, in the same viewer a past day's
    /// blocks open (the owner, 2026-10-02: "the same effect as clicking on a
    /// previous day").
    @State private var viewing: String?
    /// The crew day the viewer is showing, when it is not today's: a win a
    /// chat line quoted from an earlier day opens among its own day's.
    @State private var viewingDay: String?
    @State private var reporting: SharedWin?
    /// Reported a moment ago: the thank-you and the offer to block.
    /// Hold to react and double-tap hearts (`TowerReactions`, shared with
    /// a friend's profile).
    @State private var reacts = TowerReactions()
    @State private var touchRipples: [TouchRipple] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    init(crewID: CrewID, onBack: @escaping () -> Void, onAddWin: @escaping () -> Void = {},
         onLogWin: ((BlockSize, HabitCategory) -> Void)? = nil,
         onPlanned: @escaping (PlanItem, PlannedAction) -> Void = { _, _ in }) {
        self.crewID = crewID
        self.onBack = onBack
        self.onAddWin = onAddWin
        self.onLogWin = onLogWin
        self.onPlanned = onPlanned
        self.rootAddWin = onAddWin
        self.rootPlanned = onPlanned
        _parking = State(initialValue: CrewParking(crewID: crewID))
    }

    private var store: SocialStore { SocialStore.shared }
    private var crew: Crew? { store.visible(crewID) }
    private let spacing = GridConstants.spacing
    private let columns = GridConstants.columnCount
    private let hPad = GridConstants.horizontalPadding

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("CrewTowerView")
        #endif
        GeometryReader { geo in
            let gaps: CGFloat = spacing * CGFloat(columns - 1)
            let usable: CGFloat = geo.size.width - hPad * 2 - gaps
            let colW: CGFloat = floor(usable / CGFloat(columns))
            tower(colW: colW, viewport: geo.size.height)
        }
        // **The keyboard never moves the tower** (the owner's phone note,
        // 2026-10-13: the head "glitched when clicking back in chat going over
        // blocks"). Typing in the chat raised the keyboard, the tower's room
        // shrank under it and its blocks moved, while the heads' layer
        // ignores every safe area and kept simulating: they were suddenly
        // inside blocks and were shoved out sideways, through them. The heads
        // and the tower now answer to the same room.
        .ignoresSafeArea(.keyboard)
        // A bar, so the tower blurs away under it (`pinnedBar`): under a plain
        // inset the soft edge drew nothing.
        .pinnedBar({ header }, below: {
            // **A crew's plan waiting for your answer** (the owner,
            // 2026-10-13: "make sure the crew plan shows up on the crew page
            // as well"). The card the chat draws, floating under the header
            // as the tower's tips do, so nothing on the page moves. Under
            // the bar and not in it, or I'm In takes no touch. Once you are
            // in, it is a box on the tower below (`CrewPlannedLayer`).
            VStack(spacing: GridConstants.gapTight) {
                if aloneTip { justYouTip }
                if let catchUp { catchUpTip(catchUp) } else if let weekCard { weekTip(weekCard) } else if widgetTip { crewWidgetTip }
                CrewPlanCards(crewID: crewID, refresh: plansRefresh, onChanged: { plannedNudge += 1 })
            }
            .padding(.horizontal, hPad)
            .padding(.top, GridConstants.gapTight)
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: aloneTip)
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: weekCard?.id)
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: widgetTip)
            .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: catchUp?.id)
        })
        // What was joined or closed in the chat shows here when it shuts.
        .onChange(of: showsChat) { _, open in
            if !open { plansRefresh += 1; plannedNudge += 1; answeringWin = nil; chatOpening = .reading }
            // The native sheet opens at the height the bar asked for: the
            // whole height to write, part way to read.
            if native, open {
                chatDetent = chatOpening == .writing ? .large : NativeChat.reading
            }
            Task { @MainActor in
                try? await Task.sleep(for: GridConstants.drawerLands)
                if showsChat == open { chatSettled = open }
            }
        }
        // **The page answers a touch, as Wins does**, header and all: rings
        // on water behind the content, consuming nothing. It was missing
        // here (the owner, 2026-10-03: "the ripple taps dont go in the crew
        // chats... should be the same"). The ground goes on AFTER it, which
        // puts the ground UNDER it; the other way round it drew the rings
        // beneath an opaque page.
        .touchRipples($touchRipples)
        .background { WarmBackground().ignoresSafeArea().allowsHitTesting(false) }
        // Everyone's heads, over the header too, so one can be carried up
        // into the bubble. See `CrewHeadArena`.
        // **Today's chat, resting under the tower** (`ChatRestBar`). An
        // inset, so the tower's base stands above it rather than behind it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatRestBar(crewID: crewID) { how in
                chatOpening = how
                if native {
                    // The sheet brings its own motion.
                    showsChat = true
                    return
                }
                // An explicit transaction: the drawer's own implicit one was
                // not reaching the rise, which landed in one frame (filmed).
                // Over the bar in the same pass as the open, not a pass later.
                chatCovering = true
                withAnimation(GridConstants.drawerMove) { showsChat = true }
            }
            // Under the drawer while it is up: one panel, not two.
            .opacity(chatCovering ? 0 : 1)
            // A real object the heads meet, as the chat button was: never a
            // head resting on the Message field.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                parking.controls["chat"] = $0
                restTop = $0.minY
            }
        }
        // **No tab bar inside a crew**, as Messages and WhatsApp have none
        // inside a conversation: the drawer is the foot of the screen, and
        // the way out is the back button, which carries the other crews' news.
        // Hidden by the Crews tab's stack, on one curve with the page
        // (`crewTabBarHidden`), not here.
        .overlay { headsOverlay }
        // The fan, over everything, under the bubble; a tap anywhere else
        // folds it back.
        .overlay { fanOverlay }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            if CrewNotifications.visibleCrew == crewID { CrewNotifications.visibleCrew = nil }
            chatAside.cancel()
            NativeChatPresence.shared.up = false
        }
        // **The crew's midnight, while you are looking.** Today's tower is the
        // crew's day; when it ends the tower empties and starts again, as the
        // Wins tab does at yours.
        .task(id: crew?.timeZoneIdentifier) {
            while !Task.isCancelled, let zone = crew?.timeZone {
                let today = CrewDay.string(for: Date(), in: zone)
                guard let next = CrewDay.day(today, offsetBy: 1, in: zone).flatMap({ CrewDay.start(of: $0, in: zone) })
                else { return }
                try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow + 1)))
                guard !Task.isCancelled else { return }
                rebuild()
            }
        }
        // Ended by whoever started it, or you were removed: say so, and go.
        .onChange(of: store.crew(crewID) == nil) { _, gone in
            guard gone else { return }
            leave()
            // Said by the list, once the crew and its chat have gone.
            CrewRouter.shared.joinProblem = "This crew has ended."
        }
        .onAppear {
            CrewNotifications.visibleCrew = crewID
            model.wire(reduceMotion: reduceMotion)
            wireReactions()
            #if DEBUG
            // `-strataCrewSheet info|win`: the crew's sheets, for captures.
            switch DebugHarness.argument("-strataCrewSheet") {
            case "info": showsInfo = true
            // `-strataCrewSheet chat`: today's chat, over the crew.
            case "chat": chatOpening = .reading; showsChat = true
            case "win": viewing = store.today(in: crewID).last { $0.senderProfileID != store.me && $0.photo == nil }?.winID.uuidString
            case "mine": viewing = store.today(in: crewID).last { $0.senderProfileID == store.me }?.winID.uuidString
            case "photo": viewing = galleryPhotos.last { $0.byline != nil }?.id
            case "fan": parking.fanned = !parking.parked.isEmpty
            // Add Win with this crew ticked: its With row (shared wins).
            case "add": onAddWin()
            default: break
            }
            // `-strataCrewHold 1`: a press and hold on a friend's block, so
            // the reactions it opens can be captured.
            if DebugHarness.argument("-strataCrewHold") == "1" {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    if let win = store.today(in: crewID).first(where: { $0.senderProfileID != store.me }) {
                        reacts.hold(win.winID, .began)
                    }
                }
            }
            // `-strataCrewHeartEvery <s>`: a double-tap on a friend's block
            // every s seconds, so the heart can be filmed.
            if let every = DebugHarness.argument("-strataCrewHeartEvery").flatMap(Double.init) {
                Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(every))
                        if let win = store.today(in: crewID).filter({ $0.senderProfileID != store.me }).randomElement() {
                            reacts.doubleTap(win.winID)
                        }
                    }
                }
            }
            // `-strataChatCycle <s>`: the chat opens to read, shuts, opens to
            // write, shuts, every s seconds, so its frames can be measured
            // with nothing driving the app from outside (2026-10-15).
            if let every = DebugHarness.argument("-strataChatCycle").flatMap(Double.init) {
                Task { @MainActor in
                    var writing = false
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(every))
                        if showsChat {
                            PerfProbe.mark("chat-close")
                            if native { showsChat = false } else { withAnimation(GridConstants.drawerMove) { showsChat = false } }
                        } else {
                            chatOpening = writing ? .writing : .reading
                            writing.toggle()
                            PerfProbe.mark("chat-open")
                            if native { showsChat = true } else {
                                chatCovering = true
                                withAnimation(GridConstants.drawerMove) { showsChat = true }
                            }
                        }
                    }
                }
            }
            // `-strataCrewParkEvery <s>`: a head goes into the bubble, or one
            // pops out, every s seconds, so both can be filmed.
            if let every = DebugHarness.argument("-strataCrewParkEvery").flatMap(Double.init) {
                Task { @MainActor in
                    var going = true
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(every))
                        guard let crew else { continue }
                        let free = crew.members.map(\.profileID).filter { !parking.isHidden($0) }
                        if going, let next = free.randomElement() {
                            parking.beginArrival(next, from: .zero)
                        } else if let out = parking.parked.randomElement() {
                            // Alternately as a tap on the bubble would, and
                            // from where the fan puts a head.
                            let fan = CGPoint(x: parking.bubbleFrame.midX, y: parking.bubbleFrame.maxY + 110)
                            parking.pop(out, from: parking.parked.count % 2 == 0 ? fan : nil)
                        }
                        if parking.parked.count >= 3 { going = false }
                        if parking.parked.isEmpty { going = true }
                    }
                }
            }
            #endif
            rebuild()
            store.markSeen(crewID)
            openWinFromNotification()
            openChatFromNotification()
            // The developer's bans, read again as a crew opens (2026-10-08).
            Task { await store.crewOpened(crewID) }
        }
        .onChange(of: CrewRouter.shared.openWin) { _, _ in openWinFromNotification() }
        .onChange(of: CrewRouter.shared.openChat) { _, _ in openChatFromNotification() }
        .onChange(of: store.today(in: crewID)) { _, _ in
            rebuild()
            store.markSeen(crewID)
            // The notification's win often arrives with the refresh the tap
            // started, after the crew had opened: try again when it does
            // (found 2026-10-06; it was only tried on appear).
            openWinFromNotification()
        }
        .onChange(of: crew?.members) { _, members in
            rebuild()
            // Someone joined: the tip has said its piece.
            if (members?.count ?? 0) > 1, aloneTip { withAnimation(GridConstants.cueOut) { aloneTip = false } }
        }
        .task { await considerAloneTip() }
        .task { await considerCatchUp() }
        .task { await considerWeekCard() }
        .task { await considerWidgetTip() }
        .onChange(of: store.reactionsByCrew[crewID]) { _, _ in rebuild() }
        // While the crew is on screen it stays live: this crew's changes
        // (`refreshLive`, one small request when nothing moved), since a
        // push is only a nudge to look and may never come. **Paced**
        // (2026-10-08, `CrewLivePace`): every 3 seconds while things move,
        // every 12 once three asks found nothing, and quick again the
        // moment you post, say or react. Waited out in single seconds so a
        // nudge is heard at once, and never by cancelling a request.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            var pace = CrewLivePace()
            // **A push reads the crew at once** (2026-10-10): the loop
            // below asked every three seconds whether or not anything had
            // happened. It still asks, as the fallback, but once pushes are
            // seen to arrive it asks far less (`CrewLivePace`).
            store.liveCrew = crewID
            defer { if store.liveCrew == crewID { store.liveCrew = nil } }
            // The pushes already answered: kept across asks, so one that
            // lands while an ask is out is seen at the top of the next wait
            // rather than forgotten.
            var answered = store.livePush
            while !Task.isCancelled {
                let nudge = store.liveNudge
                var waited: TimeInterval = 0
                var byPush = false
                while waited < pace.interval, !Task.isCancelled {
                    if store.livePush != answered { answered = store.livePush; byPush = true; break }
                    try? await Task.sleep(for: .seconds(1))
                    waited += 1
                    if store.liveNudge != nudge { pace.nudged(); break }
                }
                guard !Task.isCancelled else { return }
                pace.asked(changed: await store.refreshLive(crewID), byPush: byPush)
            }
        }
        // The chat updates while it is open from the live sync above: the
        // store is observed, and `refreshLive` keeps running under a sheet.
        // **The chat rises from its bar as part of this page** (`ChatDrawer`,
        // 2026-10-14), not as a sheet: flush with the foot of the screen,
        // the tower above it.
        .overlay(alignment: .bottom) {
            if !native {
            ChatDrawer(isOpen: $showsChat, restTop: restTop, covering: $chatCovering) {
                CrewChatSheet(crewID: crewID, startsWriting: chatOpening == .writing,
                              startsWithPlus: chatOpening == .plus, visible: showsChat,
                              answeringWin: answeringWin,
                              close: { withAnimation(GridConstants.drawerMove) { showsChat = false } },
                              reopen: {
                                  chatOpening = .reading
                                  chatCovering = true
                                  withAnimation(GridConstants.drawerMove) { showsChat = true }
                              },
                              onOpenWin: openQuotedWin, onAddWin: { onAddWin() })
            }
            }
        }
        // The crew's own presentations hang here while the chat is down; with
        // the native chat up they hang on its sheet, the one thing that can
        // present while it is up (`nativeChatSheet`).
        .applying(true) { presenting($0, active: !sheetUp) }
        .environment(\.presentAside, PresentAside { action in
            if native, chatUp { chatAside.run(action) } else { action() }
        })
        // **The native chat** (`NativeChat`).
        .sheet(isPresented: Binding(get: { sheetUp },
                                    set: { if !$0, !chatAside.away { showsChat = false } })) {
            nativeChatSheet
        }
        .onChange(of: sheetUp, initial: true) { _, up in
            NativeChatPresence.shared.up = up
        }
        // Escape closes the reaction bar first, the way a tap outside it does,
        // rather than leaving the crew with the bar still open.
        .accessibilityAction(.escape) { if reacts.reacting != nil { reacts.close() } else { leave() } }
    }

    /// The native chat's sheet is on screen (not stepped aside).
    private var sheetUp: Bool { native && showsChat && !chatAside.away }

    /// The crew's own covers and sheets: the week's replay, the crew's card,
    /// the photo viewer and Report. On the tower while the chat is down, on
    /// the chat's sheet while it is up: each host presents only while it is
    /// `active`, so nothing is asked for twice.
    private func presenting<Host: View>(_ host: Host, active: Bool) -> some View {
        host
            .fullScreenCover(item: Binding(get: { active ? playingWeek : nil }, set: { playingWeek = $0 })) { shown in
                ReplayView(replay: shown) { playingWeek = nil }
            }
            .sheet(isPresented: Binding(get: { active && showsInfo }, set: { showsInfo = $0 })) {
                // **Straight to the crew** (the owner, 2026-10-10, on the Draw
                // tab this sheet used to share: "there is no way to delete
                // drawings or move them and honestly dont understand the point
                // of the feature"). Draw and the drawings it threw onto the
                // tower are gone; the middle opens the crew, as it first did.
                if let crew {
                    CrewInfoSheet(crewID: crew.id, onLeft: { leave() })
                        .presentationBackground { WarmBackground().ignoresSafeArea() }
                }
            }
            .fullScreenCover(item: Binding(get: { active ? viewingBinding.wrappedValue : nil },
                                           set: { viewingBinding.wrappedValue = $0 })) { photo in viewer(photo) }
            // Report, from the viewer's ⋯: the reasons, and nobody in the
            // crew is told. Hung on a point at the foot of the screen.
            .overlay(alignment: .bottom) { if active { reportAnchor } }
            // "Sam added you to a win", once per win, never over another
            // screen: with the native chat, from the chat's sheet, and only
            // while it rests (the review, 2026-10-15: it never showed).
            .keepTaggedWin(in: crewID, isBusy: !active || viewing != nil || showsInfo || showsChat || reporting != nil
                           || reacts.reacting != nil || playingWeek != nil)
            // The list's two alerts, from here while the chat is up
            // (`NativeChatPresence`).
            .alert("This photo stays with you", isPresented: Binding(
                get: { active && NativeChatPresence.shared.up && SocialStore.shared.heldBackPhoto != nil },
                set: { if !$0 { SocialStore.shared.clearHeldBackPhoto() } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It looked like something Some Wins doesn't send to crews. Your win was still sent, without it.")
            }
            .alert("Crews", isPresented: Binding(get: { active && NativeChatPresence.shared.up && CrewRouter.shared.joinProblem != nil },
                                                 set: { if !$0 { CrewRouter.shared.joinProblem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(CrewRouter.shared.joinProblem ?? "")
            }
    }

    /// **The chat, as a native sheet while it is open.** It rises from the
    /// resting bar part way to read, or the whole height to write, and a
    /// drag down puts it away into the bar again.
    private var nativeChatSheet: some View {
        presenting(
            CrewChatSheet(crewID: crewID, startsWriting: chatOpening == .writing,
                          startsWithPlus: chatOpening == .plus, visible: true,
                          answeringWin: answeringWin, native: true,
                          close: { showsChat = false },
                          reopen: {
                              chatOpening = .reading
                              withAnimation(GridConstants.drawerMove) { chatDetent = NativeChat.reading }
                          },
                          onOpenWin: openQuotedWin, onAddWin: { addWin() }),
            active: true
        )
        // Inside the chat, a sheet opens from the chat itself.
        .environment(\.presentAside, .direct)
        .environment(\.chatDrawerFull, chatDetent == .large)
        .environment(\.chatAtRest, false)
        // Writing takes the whole height, with the crew's name on top (the
        // owner, 2026-10-14); leaving the keyboard leaves the height alone.
        .environment(\.chatDrawerWriting, ChatDrawerWriting { now in
            guard now, chatDetent != .large else { return }
            withAnimation(GridConstants.drawerMove) { chatDetent = .large }
        })
        .presentationDetents(NativeChat.detents, selection: $chatDetent)
        // The tower stays the tower under the reading chat: a tap on a block
        // lands, as Maps' card leaves the map.
        .presentationBackgroundInteraction(.enabled(upThrough: NativeChat.reading))
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        // VoiceOver's escape: the chat down into its bar.
        .accessibilityAction(.escape) { showsChat = false }
    }

    /// **With the native chat, the viewer opens from the chat's sheet**, so a
    /// win asked for as the crew opens waits for the sheet to be up (at most
    /// three seconds). With the drawer it opens at once.
    private func untilChatIsUp() async {
        // Down, the tower presents it.
        guard native, showsChat else { return }
        var waited = 0
        while !(chatUp && ChatAside.rootIsPresenting() && !chatAside.away), waited < 30 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        // And risen: a cover asked for mid-presentation is dropped.
        try? await Task.sleep(for: GridConstants.drawerLands)
    }

    /// Out of the crew: the chat's sheet goes first, at once, so the pop is
    /// the only thing that moves.
    private func leave() {
        guard native, chatUp else { onBack(); return }
        chatAside.cancel()
        // The list's alerts are its own again before the sheet goes.
        NativeChatPresence.shared.up = false
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) { showsChat = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            onBack()
        }
    }

    /// Add a Win comes from the app root: the chat steps aside for it.
    private func addWin() {
        if native, chatUp { chatAside.run(rootAddWin) } else { rootAddWin() }
    }

    /// A planned box's camera, library or edit comes from the app root too.
    private func planned(_ item: PlanItem, _ action: PlannedAction) {
        let presents = [PlannedAction.camera, .library, .edit].contains(action)
        if presents, native, chatUp {
            chatAside.run { rootPlanned(item, action) }
        } else {
            rootPlanned(item, action)
        }
    }

    private struct ViewedPhoto: Identifiable { let id: String }

    /// Report, from the viewer's ⋯, and the thanks after it: hung on one
    /// point at the foot of the screen (see the call site).
    private var reportAnchor: some View {
        CrewReportAnchor(reporting: $reporting, crewID: crewID)
    }

    /// Two taps on a friend's block: a heart, every time, as on Instagram. A
    /// heart you already gave stays given (it is never taken back by the same
    /// gesture that gave it); a different reaction you gave becomes the heart.
    /// Your own block takes yours too (the owner, 2026-10-13, from a tester).

    /// A tapped notification named a win: open it in the carousel, as a tap
    /// on its block would, once it is here.
    private func openWinFromNotification() {
        // **Among the days the crew still holds, not today's alone** (found
        // by review, 2026-10-13): last night's win, tapped in the morning,
        // opened an empty tower. As a quoted win opens (`openQuotedWin`).
        guard let id = CrewRouter.shared.openWin, let crew,
              let win = store.wins(in: crewID).first(where: { $0.winID == id }) else { return }
        CrewRouter.shared.openWin = nil
        let today = CrewDay.string(for: Date(), in: crew.timeZone)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            await untilChatIsUp()
            viewingDay = win.crewDay == today ? nil : win.crewDay
            viewing = id.uuidString
        }
    }

    /// A tapped chat notification: the chat, once the crew is open.
    private func openChatFromNotification() {
        guard CrewRouter.shared.openChat else { return }
        CrewRouter.shared.openChat = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            chatOpening = .reading
            showsChat = true
        }
    }

    /// **A quote in the chat, tapped**: the chat closes and the win opens in
    /// the viewer a tap on its block opens, among its own day's wins. After
    /// the sheet has gone: UIKit drops a cover asked for while a sheet is
    /// still dismissing.
    private func openQuotedWin(_ id: UUID) {
        guard let win = store.wins(in: crewID).first(where: { $0.winID == id }), let crew else { return }
        showsChat = false
        let today = CrewDay.string(for: Date(), in: crew.timeZone)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            viewingDay = win.crewDay == today ? nil : win.crewDay
            viewing = id.uuidString
        }
    }

    /// The wins the viewer pages through: today's, or the quoted win's day.
    private var viewedWins: [SharedWin] {
        viewingDay.map { store.wins(in: crewID, on: $0) } ?? store.today(in: crewID)
    }

    /// A held friend's block: the reaction bar over it, and only that (the
    /// owner, 2026-10-02: "the hold... should just be to react"). Who reacted
    /// and Report are in the carousel a tap opens. Your own takes no
    /// reaction from you, so holding it does nothing.
    /// Everyone's heads, over the header too, so one can be carried up
    /// into the bubble. See `CrewHeadArena`.
    @ViewBuilder
    private var headsOverlay: some View {
        if let crew {
            CrewHeadArena(crew: crew, me: store.me, model: model, parking: parking)
                .ignoresSafeArea()
                // Still while something covers them (the chat, the crew's
                // card, a win full screen), as Memories does: nobody is
                // watching, and nothing moves under a sheet to be found
                // somewhere odd when it shuts.
                .environment(\.headsAwake, !(chatSettled || showsInfo || viewing != nil))
        }
    }

    /// The fan, over everything, under the bubble; a tap anywhere else folds
    /// it back.
    @ViewBuilder
    private var fanOverlay: some View {
        if parking.fanned, let crew {
            GeometryReader { geo in
                // Under the name, not over it: the crew stays legible
                // while you choose.
                let anchor = parking.controls["name"]?.maxY ?? parking.bubbleFrame.maxY
                let top = anchor - geo.frame(in: .global).minY + 10
                ZStack(alignment: .top) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(GridConstants.motionSnappy) { parking.fanned = false } }
                        .accessibilityHidden(true)
                    CrewFan(crew: crew, me: store.me, parking: parking)
                        .padding(.top, max(top, 0))
                        .transition(.scale(scale: 0.7, anchor: .top).combined(with: .opacity))
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .ignoresSafeArea()
        }
    }

    private var viewingBinding: Binding<ViewedPhoto?> {
        Binding(get: { viewing.map(ViewedPhoto.init) }, set: {
            viewing = $0?.id
            if $0 == nil { viewingDay = nil }
        })
    }

    private func viewer(_ photo: ViewedPhoto) -> some View {
        PhotoViewer(photos: galleryPhotos, startAt: photo.id, onClose: { viewing = nil },
                    crew: crewID,
                    onReport: { shown in
                        viewing = nil
                        // After the cover has gone: UIKit drops a sheet
                        // asked for while another is still dismissing.
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(450))
                            reporting = store.wins(in: crewID).first { $0.winID.uuidString == shown.id }
                        }
                    },
                    onWithdraw: { shown in
                        guard let id = UUID(uuidString: shown.id) else { return }
                        Task { await store.remove(winID: id, from: crewID) }
                    },
                    canRemove: { shown in
                        UUID(uuidString: shown.id).map { store.canRemove($0, from: crewID) } ?? false
                    },
                    onHide: { shown in
                        if let id = UUID(uuidString: shown.id) { CrewHiding.hide(id) }
                    },
                    reactions: { shown in
                        guard let id = UUID(uuidString: shown.id) else { return AnyView(EmptyView()) }
                        return AnyView(CrewPhotoReactions(winID: id, crewID: crewID, mine: shown.byline == nil))
                    })
    }

    /// Reply from a held block: the chat rises with the win quoted and the
    /// keyboard up.
    private func replyTo(_ id: UUID) {
        answeringWin = id
        chatOpening = .writing
        showsChat = true
        // Already up, the chat goes to the whole height to write (the
        // review, 2026-10-15: Reply did nothing at reading).
        if native, chatDetent != .large {
            withAnimation(GridConstants.drawerMove) { chatDetent = .large }
        }
    }

    /// Which of today's blocks take a reaction here: this crew's.
    private func wireReactions() {
        let crewID = crewID
        reacts.crewOf = { id in
            SocialStore.shared.today(in: crewID).contains { $0.winID == id } ? crewID : nil
        }
    }

    /// Today's wins in the order the tower stacks them, for the carousel:
    /// photographs, and the rest as their blocks.
    private var galleryPhotos: [GalleryPhoto] {
        CrewGallery.photos(viewedWins, crew: crew, me: store.me)
    }

    private func rebuild() {
        let names = Dictionary(uniqueKeysWithValues: (crew?.members ?? []).map { ($0.profileID, $0.shortName) })
        let wins = store.today(in: crewID)
        model.rebuild(wins: wins, me: store.me, names: names,
                      everyoneIn: CrewTowerModel.everyoneIn(wins: wins, members: (crew?.members ?? []).map(\.profileID)),
                      reactions: { store.reactions(to: $0, in: crewID) })
    }

    // MARK: Just you

    /// **A crew of one gets one quiet tip, not a button** (the invites
    /// research, 2026-10-13; the owner on a bare Invite under a crew's name:
    /// "i dont like how invite is just there"). The first time a crew is
    /// opened while it is still only you, the one tip container says so and
    /// offers the invite, then leaves by itself, as every tip does. Once a
    /// crew, ever.
    private var justYouTip: some View {
        TipCard(title: "Just you so far.",
                message: "A crew starts when one friend joins.",
                mark: "TipPersonPlus",
                actionTitle: "Invite",
                action: {
                    withAnimation(GridConstants.cueOut) { aloneTip = false }
                    Task { await CrewSharing.invite(crewID) }
                },
                close: {
                    HapticsEngine.lightTap()
                    withAnimation(GridConstants.cueOut) { aloneTip = false }
                })
            .accessibilityHint("Opens the invite")
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }

    static let aloneShownKey = "crews.justYouShown"

    /// **"Your week, put together."** (`docs/voice.md`, albums and recaps:
    /// the warmest the app gets, and still quiet.) The line under it is the
    /// week's own numbers.
    private func weekTip(_ replay: Replay) -> some View {
        // As the tower shows them: nobody blocked, nothing hidden.
        let people = Set(replay.period.days.flatMap { store.wins(in: crewID, on: $0) }
            .map(\.senderProfileID)).count
        let wins = replay.blocks.count
        return TipCard(title: "Your week, put together.",
                       message: people > 1 ? "\(wins) wins, from \(people) of you."
                           : wins == 1 ? "1 win." : "\(wins) wins.",
                       actionTitle: "Play",
                       action: {
                           HapticsEngine.tick()
                           CrewWeekReplay.markShown(replay, in: crewID)
                           withAnimation(GridConstants.cueOut) { weekCard = nil }
                           playingWeek = replay
                       },
                       close: {
                           HapticsEngine.lightTap()
                           CrewWeekReplay.markShown(replay, in: crewID)
                           withAnimation(GridConstants.cueOut) { weekCard = nil }
                       })
            .accessibilityHint("Plays the crew's week")
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }

    /// "While you were away.": the days you missed, never how many.
    private func catchUpTip(_ replay: Replay) -> some View {
        // Friends' wins only: the card is about them.
        let wins = replay.period.days.flatMap { store.wins(in: crewID, on: $0) }
            .filter { $0.senderProfileID != store.me }.count
        return TipCard(title: "While you were away.",
                       message: wins == 1 ? "1 win from your crew." : "\(wins) wins from your crew.",
                       actionTitle: "Catch Up",
                       action: {
                           HapticsEngine.tick()
                           withAnimation(GridConstants.cueOut) { catchUp = nil }
                           playingWeek = replay
                       },
                       close: {
                           HapticsEngine.lightTap()
                           withAnimation(GridConstants.cueOut) { catchUp = nil }
                       })
            .accessibilityHint("Plays the days you missed")
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }

    /// Read as the crew opens, then the day is noted as opened, so it is
    /// offered once for each time away.
    private func considerCatchUp() async {
        let found = CrewWeekReplay.missed(in: crewID)
        CrewWeekReplay.noteOpened(crewID)
        guard let found, !aloneTip else { return }
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cueIn) { catchUp = found }
    }

    static let widgetTipKey = "crews.widgetTipShown"

    /// "Your crew, on your Home Screen.": once ever, the first time a
    /// friend's win stands on a crew's tower, and never over another tip.
    private var crewWidgetTip: some View {
        TipCard(title: "Your crew, on your Home Screen.",
                message: "Hold the Home Screen, tap Edit, then Add Widget, and choose Some Wins.",
                mark: "TipPersonPlus",
                close: {
                    HapticsEngine.lightTap()
                    withAnimation(GridConstants.cueOut) { widgetTip = false }
                })
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }

    private func considerWidgetTip() async {
        guard !UserDefaults.standard.bool(forKey: Self.widgetTipKey) else { return }
        try? await Task.sleep(for: .milliseconds(1600))
        guard !aloneTip, weekCard == nil, catchUp == nil,
              store.today(in: crewID).contains(where: { $0.senderProfileID != store.me }) else { return }
        UserDefaults.standard.set(true, forKey: Self.widgetTipKey)
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.cueIn) { widgetTip = true }
        try? await Task.sleep(for: .seconds(14))
        if widgetTip { withAnimation(GridConstants.cueOut) { widgetTip = false } }
    }

    /// Once a week per crew, after the screen settles, and not over the
    /// just-you tip.
    private func considerWeekCard() async {
        try? await Task.sleep(for: .milliseconds(1200))
        guard !aloneTip, catchUp == nil, let replay = CrewWeekReplay.live(in: crewID),
              !CrewWeekReplay.wasShown(replay, in: crewID) else { return }
        weekCard = replay
    }

    private func considerAloneTip() async {
        guard let crew, crew.members.count == 1 else { return }
        let shown = UserDefaults.standard.stringArray(forKey: Self.aloneShownKey) ?? []
        guard !shown.contains(crewID.rawValue) else { return }
        UserDefaults.standard.set(shown + [crewID.rawValue], forKey: Self.aloneShownKey)
        // After the screen has settled, not over the push.
        try? await Task.sleep(for: .milliseconds(900))
        aloneTip = true
        try? await Task.sleep(for: .seconds(12))
        if aloneTip { withAnimation(GridConstants.cueOut) { aloneTip = false } }
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top) {
                BackToCrews(count: elsewhere) { leave() }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { parking.controls["back"] = $0 }
                Spacer(minLength: 0)
                // **No "+" here any more** (the owner, 2026-10-05: "kinda
                // useless because there is already a + block"). The tower's
                // own next slot adds a win, and holding it opens Add Win.
                // **The chat is the drawer at the foot now** (`ChatRestBar`,
                // the owner's pick, 2026-10-13), and its dot moved with it.
                // **The corner is Invite** (`docs/crew-corner-research-
                // 2026-10-14.md`; the owner asked for it researched): the
                // most wanted thing here that was not one press away, past
                // the name, a long card and a scroll. A glyph on glass, never
                // the bare word (his 2026-10-13 call), and gone once the crew
                // is full, with no count.
                if let crew, crew.members.count < CrewCaps.members {
                    GlassIconButton(systemName: "person.badge.plus", onPage: true, accessibilityLabel: "Invite") {
                        Task { await CrewSharing.invite(crewID) }
                    }
                    .accessibilityHint("Sends a link to join this crew.")
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { parking.controls["invite"] = $0 }
                }
            }
            if let crew {
                let crowded = !parking.parked.isEmpty
                // **Apart, not overlapping** (the owner, 2026-10-03: "the shadow
                // is too dark"). Each glass shape casts its own soft shadow, and
                // where the name overlapped the bubble the two shadows met and
                // read as a dark patch. A small gap between them leaves one
                // shadow each, as every other control in the app has. (A shared
                // glass container would merge them, but it frosted the heads
                // inside the bubble.)
                VStack(spacing: GridConstants.spacing) {
                    CrewBubble(crew: crew, me: store.me, parking: parking, side: 60)
                        // The whole bubble is the target, never one 34pt head.
                        .contentShape(Circle())
                        .onTapGesture { tapBubble() }
                        .contextMenu {
                            if !parking.parked.isEmpty {
                                Button("Let Everyone Out", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                                    parking.releaseAll()
                                }
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(!crowded
                            ? "\(crew.displayName(excluding: store.me)), \(crew.members.count) people"
                            : (parking.parked.count == 1 ? "1 head in the bubble" : "\(parking.parked.count) heads in the bubble"))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { tapBubble() }
                        .accessibilityActions {
                            if !parking.parked.isEmpty {
                                Button("Let Everyone Out") { parking.releaseAll() }
                            }
                        }
                        .zIndex(1)
                    Button { HapticsEngine.lightTap(); showsInfo = true } label: {
                        // The caption the Wins tower's goal uses too
                        // (`CrestCaption`), so the two middles are one object.
                        CrestCaption(text: crew.displayName(excluding: store.me), chevron: true)
                        // Wide enough for a long name at a large text size,
                        // clear of the two buttons either side.
                        .frame(maxWidth: 240)
                        // It was `minimumScaleFactor(0.85)`, which let a long
                        // name come down to 12.75pt at the default size, under
                        // the app's 15pt floor. `LargeTypeFit` shrinks only as
                        // far as 15 (the QoL review, 2026-10-06).
                        .fitsLargeType(.subheadline)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { parking.controls["name"] = $0 }
                        // A 44pt target round a 30pt capsule, so the press
                        // lands without hunting for the glass.
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    // `.plain`: a scaling press on interactive glass cancels
                    // the tap on a phone (`CrewReactions`). Found 2026-10-06.
                    .buttonStyle(.plain)
                    // **Over the bubble, always.** With heads parked the
                    // bubble's crowd spills onto the capsule, and the bubble
                    // sat above it and took the tap: the details were nearly
                    // impossible to open (the owner, 2026-10-02).
                    .zIndex(2)
                    .accessibilityLabel("\(crew.displayName(excluding: store.me)), details")
                    .accessibilityAddTraits(.isHeader)
                    // **No Invite standing here for a crew of one.** It was
                    // added on 2026-10-13 as a bare word under the name, and
                    // the owner, seeing it: "I dont like how invite is just
                    // there". The way to a second person is the crew's page,
                    // one tap on the name: Invite, and the code in its corner.
                    // **The starter's iCloud is full** (2026-10-08): one
                    // quiet line while new wins wait in the outbox, rather
                    // than posts that vanish (`SocialStore.fullCrews`).
                    if store.fullCrews.contains(crewID) {
                        Text(SocialStore.fullWords)
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 240)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, hPad)
        .padding(.top, GridConstants.gapTight)
        .padding(.bottom, GridConstants.gapTight)
    }

    /// Other crews with a new win, reaction or line: the back button's number.
    private var elsewhere: Int {
        store.unread.union(store.unreadChats).subtracting([crewID]).count
    }

    /// Empty, the bubble is the crew: its details. With heads in it, a tap
    /// fans them out to choose from.
    private func tapBubble() {
        if parking.parked.isEmpty {
            HapticsEngine.lightTap()
            showsInfo = true
        } else {
            HapticsEngine.tick()
            withAnimation(GridConstants.motionSnappy) { parking.fanned.toggle() }
        }
    }

    // MARK: Tower

    private func tower(colW: CGFloat, viewport: CGFloat) -> some View {
        let tower = model.tower
        let slot = onLogWin == nil ? nil : tower.computeGhostPosition(for: drawingSize)
        let rows = max(tower.totalRows, slot.map { $0.row + drawingSize.rowSpan } ?? 0, plannedRows)
        let gridW = CGFloat(columns) * colW + CGFloat(columns - 1) * spacing
        let gridH = rows > 0 ? CGFloat(rows) * colW + CGFloat(rows - 1) * spacing : 0
        return ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .allowsHitTesting(false)
                    .frame(width: gridW, height: max(gridH, 1))
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                        model.probe.gridTopOnScreen = rect.minY
                        model.probe.gridHeight = gridH
                        model.probe.cellSize = colW
                    }
                // **One person's same-colour wins run together**, under the
                // blocks, as on Wins (`BlockMerge.groups(perPerson:)`). Not
                // while anything is falling: a run's identity is its members,
                // and a shape that appears and vanishes mid-drop is a cut.
                let merging = model.animation.activelyAnimatingIDs.isEmpty && !model.animation.isCascading
                if rows > 0, merging {
                    ForEach(tower.mergeGroups) { group in
                        MergedGroupView(group: group, cellSize: colW, gridWidth: gridW, gridHeight: gridH)
                    }
                }
                if rows > 0 {
                    TowerBlocksForEach(
                        visibleBlocks: tower.placedBlocks, animCoord: model.animation, towerVM: tower,
                        groupedIDs: merging ? tower.groupedBlockIDs : [], mergeDestinedIDs: tower.groupedBlockIDs,
                        colW: colW, gridH: gridH,
                        cornerRadius: GridConstants.cornerRadius, expandedBlockID: nil,
                        reduceMotion: reduceMotion, colorScheme: colorScheme,
                        onTapExpandBlock: { id in
                            if reacts.reacting != nil { reacts.close(); return }
                            guard !reacts.justHeld else { return }
                            guard let win = store.today(in: crewID).first(where: { $0.winID == id }) else { return }
                            // Every block opens the day's carousel at itself,
                            // photograph or not: who reacted and Report live
                            // there, and the hold is only for reacting.
                            viewing = win.winID.uuidString
                        },
                        liftedBlockID: nil,
                        onDoubleTapBlock: { reacts.doubleTap($0) },
                        onHoldBlock: { id, phase in reacts.hold(id, phase) })
                }
                // The next slot, as on Wins: tap for a win in this crew, draw
                // it out for a bigger one, hold for the full Add Win.
                if !model.animation.isCascading, let pos = slot {
                    let f = GridConstants.blockFrame(column: pos.column, row: pos.row,
                                                     columnSpan: drawingSize.columnSpan,
                                                     rowSpan: drawingSize.rowSpan, cellSize: colW)
                    NextSlotButton(reduceMotion: reduceMotion,
                                   cornerRadius: GridConstants.cornerRadius,
                                   previewCategory: slotColour,
                                   onSizeChanged: { drawingSize = $0 },
                                   action: { size in
                                       onLogWin?(size, slotColour)
                                       slotColour = HabitCategory.selectable.filter { $0 != slotColour }.randomElement() ?? slotColour
                                       // Back to one square for the next win,
                                       // once this one has landed, as Wins
                                       // does after its drop (the owner: "the
                                       // next + box is also that size").
                                       Task { @MainActor in
                                           try? await Task.sleep(for: .milliseconds(700))
                                           withAnimation(GridConstants.slotSnap) { drawingSize = .small }
                                       }
                                   },
                                   onOpenMenu: addWin)
                        .frame(width: f.width, height: f.height)
                        .offset(x: f.minX, y: gridH - f.minY - f.height)
                }
                // **This crew's plans you are in, as boxes behind the slot**
                // (the owner, 2026-10-13). Your own tower's box, by the same
                // view, holding only this crew's lines.
                if !model.animation.isCascading {
                    CrewPlannedLayer(crewID: crewID, grid: tower.currentGrid, slot: slot, slotSize: drawingSize,
                                     cellSize: colW, gridHeight: gridH, cornerRadius: GridConstants.cornerRadius,
                                     nudge: plannedNudge, rowsNeeded: $plannedRows) { item, action in
                        planned(item, action)
                        // Not Today is kept beside the model, where no query
                        // sees it.
                        if action == .notToday { plannedNudge += 1 }
                    }
                }
            }
            .modifier(TowerReactionLayers(reactions: reacts, blocks: tower.placedBlocks,
                                          colW: colW, gridW: gridW, gridH: gridH, reply: replyTo))
            .environment(\.blockLight, BlockLight.over(rows: max(rows, 1)))
            .background(alignment: .bottom) {
                TowerLattice(cellSize: colW, contentHeight: max(gridH, 1), ripple: model.latticeRipple)
                    .frame(width: gridW)
            }
            .padding(.horizontal, hPad)
            // **The open chat covers the tower's foot; the tower never moves**
            // (the owner, 2026-10-14: "i dont think the bottom drawer should
            // push up the whole tower"; covering, as Maps' card covers its
            // map). It was lifted above the drawer for one build.
            .padding(.bottom, GridConstants.gapWide)
            .frame(minHeight: viewport, alignment: .bottom)
        }
        .defaultScrollAnchor(.bottom)
        // A finger choosing a reaction must not scroll the tower under it.
        .scrollDisabled(reacts.reacting != nil)
        .softScrollEdge(.top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rows == 0 ? "No wins yet today" : "Today's crew tower, \(tower.placedBlocks.count) wins")
    }
}

/// Over a crew photograph in the viewer: `CrewReactionsPanel`, in the
/// viewer's own appearance. It was always on the dark while the viewer was
/// always black; the viewer is the page at rest now (2026-10-14), and on a
/// light one the button's mark stayed white (the owner: "the reaction button
/// doesnt seem to be switching to light mode like the icon isnt becoming
/// ink").
struct CrewPhotoReactions: View {
    let winID: UUID
    let crewID: CrewID
    let mine: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        CrewReactionsPanel(winID: winID, crewID: crewID, mine: mine, onDark: scheme == .dark)
    }
}


private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

/// **The way back to the list, carrying how many other crews have news**
/// (the owner, 2026-10-13: "I like how Apple Messages works where the back
/// button also shows the number", then "more like the apple one where its
/// like in the button"). Messages writes the count beside its chevron,
/// inside the button; so does this. With nothing new it is the plain 44pt
/// glass circle every back button in the app is, and with news the same
/// glass grows into a capsule round the number, in ink like the chevron.
/// This crew's own news is not counted, since you are in it.
private struct BackToCrews: View {
    let count: Int
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                if count > 0 {
                    Text(count > 9 ? "9+" : "\(count)")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(count)))
                        .transition(.opacity)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, count > 0 ? 14 : 0)
            .frame(minWidth: GlassIconButton.defaultSide, minHeight: GlassIconButton.defaultSide)
            .glassCapsule(onPage: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(NewsDot.motion(reduceMotion: reduceMotion), value: count)
        .accessibilityLabel(count > 0 ? "Crews, \(count) with something new" : "Crews")
    }
}
