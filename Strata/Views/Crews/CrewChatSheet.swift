import SwiftData
import PhotosUI
import SwiftUI

/// **Today's crew chat** (the owner, 2026-10-05).
///
/// Opened from the glass `bubble.left` in the crew screen's top right. One
/// day long: it clears at the crew's midnight (`SocialStore.prune`), and no
/// phone shows a line from another day (`SocialStore.messages(in:)`). Text and
/// emoji up to 280 characters, a doodle, and replies on a win, which arrive
/// here quoting it ("↪ Morning run"); a tap on the quote opens that win.
///
/// **The sheets' chrome**, as `DaySheet` wears it: full
/// height, the drag indicator, the page's own ground as the material, Done top
/// right in `sheetAction`. The title is the crew and "Today" under it.
///
/// **Minimal and airy**: yours on the right in ink, everyone else on the left
/// with their small face and name, told apart by space and never by lines.
/// Liquid Glass only on the controls (the field and Send). No read receipts
/// and no seen marks: nothing says who has opened it.
///
/// **Hold a line for its menu** (the owner, 2026-10-13): the reactions on
/// top (`ChatReactionBar`, "+" opening your stickers), then Reply, Heart,
/// Copy, and Report on a friend's line or Delete on your own. What everyone
/// chose sits under the line as small chips (`ChatReactionChips`), one a
/// person a line, as on a win. Block is on a friend's face (`faceMenu`).
struct CrewChatSheet: View {
    let crewID: CrewID
    /// A quoted win was tapped: the crew screen closes this sheet and opens
    /// that win in its viewer.
    var onOpenWin: (UUID) -> Void = { _ in }
    /// **Unused since the plus row's Win opens over the chat** (2026-10-14,
    /// `addingWin`). It closed this sheet and opened Add a Win on the crew,
    /// so the win landed on the tower and never in the chat, which broke the
    /// owner's rule that a plus-row button does its thing in the chat. Kept
    /// so a caller passing it still builds.
    var onAddWin: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What is in the field. Seeded from `CrewDrafts` and written back to it
    /// on every keystroke (`ChatTextInput`), so the words outlive the sheet.
    /// **Held in its own object, and read only by the field, the send
    /// button and the starters** (2026-10-15, the owner: "I try to type and
    /// it take forever not responsive"): as this view's `@State` String, a
    /// keystroke redrew the whole thread, every row and its look-ups.
    @State private var field: ChatFieldText
    @State private var refused = false
    @State private var atDailyLimit = false
    @State private var reporting: CrewMessage?
    /// Someone just reported, a line or the person: the thanks, and the
    /// offer to block them.
    @State private var reported: UUID?
    @State private var reportingPerson: CrewMember?
    @State private var blockingPerson: UUID?
    /// The line whose hold menu is open, if one is.
    @State private var menuOn: UUID?
    /// Where each line stands, for which way its menu opens. A reference,
    /// so a scroll moving every line redraws nothing.
    @State private var lineFrames = ChatLineFrames()
    /// The line Reply quoted, over the field until the reply goes.
    @State private var replyingTo: CrewMessage?
    /// **A win Reply quoted, from the hold on the tower** (the owner,
    /// 2026-10-14: "when you are holding to react reply should pop up as an
    /// option and the chat should pop up"). Over the field as a line's quote
    /// is, and sent with the win quoted.
    @State private var replyingToWin: UUID?
    /// The line "+" is choosing an emoji for, with the keyboard up.
    @State private var emojiFor: UUID?
    /// The chat went down for a sheet and comes back up when it goes.
    @State private var returnToChat = false
    /// A quoted line tapped: the thread goes to it, and it lights a moment.
    @State private var goingTo: UUID?
    @State private var lit: UUID?
    /// **The chat's clock**, moved on every few seconds while it is open:
    /// what a line that did not go is measured against (M1).
    @State private var clock = Date()
    /// Lines already said not to have gone, so the warning sounds once.
    @State private var toldUnsent: Set<UUID> = []
    /// **A new line arrived below while you were reading higher up** (M7):
    /// the thread stayed put and Newest offers the way down.
    @State private var newBelow = false
    /// Asked of the scroll view: to the newest line, now.
    @State private var toNewest = 0
    /// Bumped as the drawer starts to rise: the thread goes to its newest line
    /// at once, before it can be seen, so it never opens short of it.
    @State private var snapToNewest = 0
    /// A strip, picture or sticker open full screen (`ChatPictureViewer`).
    @State private var viewingPicture: CrewMessage?
    /// A heart just given by two taps, popping at its bubble's corner.
    @State private var bursts: [UUID: UUID] = [:]
    /// The line a sticker from the sheet goes on, when "+" in a line's
    /// menu opened it. Nil: the sheet sends a sticker into the chat.
    @State private var stickerFor: UUID?
    /// A quoted line just held: the lift of the finger that opened its bar
    /// is not also a tap that opens the win.
    @State private var held: UUID?
    @State private var stickerRefused = false
    /// Where you left off: the first line you had not seen when the chat
    /// last opened, marked "New" above it until it next goes down.
    @State private var newFrom: UUID?
    /// A friend's profile, from their face (`FriendProfileSheet`).
    @State private var profileOf: CrewMember?
    /// What the + menu's things open (`ChatPlusMenu`).
    @State private var pickingPhoto = false
    /// The camera card, open in the chat (`ChatPlusRow.Choice.camera`).
    @State private var snapping: AddWinOpening?
    @State private var pickedPhoto: PhotosPickerItem?
    /// A photo on its way: one at a time (a second pick while the first is
    /// checked and sent would send it twice).
    @State private var sendingPhoto = false
    @State private var planning = false
    @State private var choosingSticker = false
    @State private var makingSticker = false
    @State private var doodling = false
    @State private var showsStrip = false
    /// Why a strip did not go, in the words its share sheet uses.
    @State private var stripProblem: String?
    @State private var choosingMemory = false
    /// **Add a Win, over the chat** (the plus row's Win, and the empty
    /// strip's way forward). The chat stays open underneath.
    /// A chat photo being kept as a win (`ChatPictureViewer.onAddWin`).
    /// A sticker just lifted out of a photo: shown chosen in the grid, and
    /// sent only by a tap on it (the research, section 3, item 3: it sent on
    /// the lift, a sticker nobody had seen yet).
    @State private var newSticker: String?
    /// A group plan two or more have done with a photo, opened as a strip.
    @State private var planStrip: GroupPlan?
    /// Today's look back for this crew (`CrewLookBack`), if there is one.
    @State private var lookBack: CrewLookBack.Found?
    /// Plan cards closed on this phone today, and a count that redraws the
    /// cards after `GroupPlanBook` changes (it is not observed).
    @State private var closedPlans: Set<String> = []
    @State private var planTick = 0
    /// The plan being written: kept until it goes, so refused words come
    /// back to be changed, as a line's do.
    @State private var planDraft = ""
    @State private var pictureRefused = false
    @FocusState private var writing: Bool

    private var store: SocialStore { SocialStore.shared }
    private let hPad = GridConstants.horizontalPadding

    /// Bubbles never run to the far edge: the other side keeps this much air,
    /// the ladder's page rung.
    private static let otherSide: CGFloat = GridConstants.gapPage
    /// A friend's face beside their line: small, a name tag, not a portrait.
    private static let faceSide: CGFloat = 28
    /// A doodle's largest side in the chat: a mark, never a second photograph.
    private static let doodleSide: CGFloat = 160
    /// The double tap's heart at a bubble's corner: the tower's burst, small.
    private static let burstSide: CGFloat = 28
    /// How long a line is held before its bar opens: shorter than the
    /// system's half second, which the context menu it replaced waited.
    private static let holdToReact: Double = 0.35
    /// How near the newest line counts as at it, for keeping it in sight.
    private static let followsWithin: CGFloat = 120
    /// An emoji-only line's size: Messages' large emoji, a size a glance reads.
    private static let bigEmoji: CGFloat = 44

    /// Opened by pressing the resting bar's field (`ChatRestBar`): the
    /// keyboard comes up with the thread.
    var startsWriting = false
    /// Chosen from the resting bar's + menu: opened once the chat is up.
    var startsWith: ChatPlusRow.Choice? = nil
    /// **Part way up, the tower still showing above** (the owner,
    /// 2026-10-14: "it felt like it was taking me to another screen rather
    /// than just popping up enough to see the chat"). A drag takes it to the
    /// whole height.
    static let drawerHeight = PresentationDetent.fraction(0.62)
    @State private var detent: PresentationDetent = CrewChatSheet.drawerHeight

    /// **The drawer closes it, not `dismiss`** (`ChatDrawer`): in the
    /// crew's own page, `dismiss` would take you out of the crew.
    var close: (() -> Void)? = nil

    /// The thread with its cards above and its composer below.
    private func chatPage(_ messages: [CrewMessage], reactions: [UUID: [Reaction]], crew: Crew?) -> some View {
        // **The thread, then the field, in one column** (2026-10-15, the
        // owner: "sometimes it opens pushing up the chat and other times it
        // doesnt", and "it doesnt scroll to the bottom and the message isnt
        // visable"). The field was an inset laid over the thread's foot, so
        // the thread ran on under it and under the keys, and "the bottom" a
        // scroll aimed for was behind them; it caught up only when a timed
        // scroll fired. In a column the keys shorten the thread itself, its
        // anchor holds the newest line on the field, and a send lands in
        // sight every time, as Messages does.
        VStack(spacing: 0) {
        thread(messages, reactions: reactions, crew: crew)
            // **At rest, the line is a way up** (the native sheet,
            // 2026-10-15): a tap on it, or a drag up from it, raises the
            // chat to read, as the resting bar's line did. The field and +
            // below keep their own jobs.
            .overlay {
                if atRest {
                    Color.clear
                        .contentShape(Rectangle())
                        // **News, at rest** (as the resting bar showed it):
                        // the ink dot beside the newest line while the chat
                        // has lines you have not read.
                        .overlay(alignment: .bottomLeading) {
                            if store.unreadChats.contains(crewID) {
                                NewsDot()
                                    .padding(.leading, GridConstants.spacing)
                                    .padding(.bottom, GridConstants.gapItem + Self.faceSide / 2)
                                    .transition(NewsDot.transition(reduceMotion: reduceMotion))
                            }
                        }
                        .onTapGesture { HapticsEngine.lightTap(); reopen?() }
                        .gesture(DragGesture(minimumDistance: 10).onEnded { drag in
                            if drag.translation.height < -20 || drag.predictedEndTranslation.height < -60 { reopen?() }
                        })
                        .accessibilityElement()
                        .accessibilityLabel("Chat")
                        .accessibilityHint("Opens today's chat.")
                        .accessibilityAddTraits(.isButton)
                }
            }
            // Over the thread and above the message field (found by
            // review, 2026-10-13): hung on the whole sheet, "In your
            // plan · Undo" lay on the field for five seconds.
            .undoLine()
            composer
        }
            .safeAreaInset(edge: .top, spacing: 0) { if !atRest, !isDirect { topCards(messages) } }
            // The emoji keyboard for "+" on a held line, as a win's "+" opens
            // it. Here, not on `body`, which is at the type-checker's ceiling.
            .background { emojiPicker }
            // The chat back up once the sheet it went down for has gone, and
            // stayed gone (a sticker's maker follows its grid).
            .onChange(of: presenting) { _, up in
                guard !up, returnToChat else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    guard !presenting, returnToChat else { return }
                    returnToChat = false
                    reopen?()
                }
            }
            // **Take a Photo**: the app's camera card, here in the chat,
            // standing on its foot; snapped and sent through the same photo
            // check as every crew photo (the owner, 2026-10-17).
            .overlay {
                if let opening = snapping {
                    InlineCameraCard(opening: opening, purpose: .send, standsOnBar: false) { result in
                        switch result {
                        case .send(let image)?: sendSnap(image)
                        case nil: snapping = nil
                        default: snapping = nil
                        }
                    }
                    .id(opening.id)
                }
            }
            // **Send a Photo**: from the library, shrunk as every crew photo
            // is, through the same photo check (`sendPicture`).
            .photosPicker(isPresented: $pickingPhoto, selection: $pickedPhoto, matching: .images)
            .onChange(of: pickedPhoto) { _, item in
                guard let item, !sendingPhoto else { return }
                pickedPhoto = nil
                sendingPhoto = true
                Task {
                    defer { sendingPhoto = false }
                    // **Said, not swallowed** (found by review, 2026-10-15):
                    // a photo that will not open, or that the check keeps,
                    // gets the photo's own sentence, never "Try other words".
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let jpeg = ShareDerivative.jpeg(from: data) else { pictureRefused = true; return }
                    switch await store.sendPicture(jpeg, caption: "", in: crewID) {
                    case .refusedSketch, .notAllowed, .refusedWords: pictureRefused = true
                    case let other: answer(other)
                    }
                }
            }
            .sheet(item: $profileOf) { member in
                NavigationStack {
                    FriendProfileSheet(member: member, crewID: crewID)
                }
                .presentationBackground { WarmBackground().ignoresSafeArea() }
            }
            // **A win to answer while the chat is already up** (the review,
            // 2026-10-15): `visible` did not change, so the quote never came.
            .onChange(of: answeringWin) { _, id in
                guard let id, visible else { return }
                replyingTo = nil
                replyingToWin = id
                writing = true
            }
            // **The quote and its starters push the thread up, not over it**
            // (filmed, 2026-10-15: the starters stood on the newest line).
            // Once they have landed, the newest line goes back above them.
            .onChange(of: replyingToWin) { _, id in
                guard id != nil else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    snapToNewest += 1
                }
            }
            // Escape closes an open menu first, then the chat.
            .accessibilityAction(.escape) { if menuOn != nil { menuOn = nil } else { leave() } }
    }

    /// **In the drawer, its own title row and no navigation stack**: a
    /// stack inside the crew's own took the crew's navigation with it and
    /// left you on the list (walked, 2026-10-14). As a sheet, the stack's
    /// bar, as before.
    @ViewBuilder
    private func framed(_ page: some View, name: String) -> some View {
        if direct {
            page
        } else if close != nil {
            // **As a bar, so lines leave under it softly** (2026-10-15): in a
            // plain stack the thread was clipped flat at the header's foot,
            // and the bottom of a bubble showed as a hard dark sliver under
            // Done. `pinnedBar` is the bar iOS draws its scroll edge under.
            page.pinnedBar {
                // At rest the drawer is the newest line and the field: its
                // title and Done come with the first lift.
                if !atRest { ChatDrawerTitle(name: name, done: { leave() }) }
            }
        } else {
            NavigationStack {
                page
                    .navigationTitle(name.isEmpty ? "Chat" : name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ChatSheetToolbar(name: name, done: { leave() }) }
            }
        }
    }

    private func leave() {
        if let close { close() } else { dismiss() }
    }

    /// **Whether the drawer is up** (`ChatDrawer`, 2026-10-14). The drawer
    /// keeps the chat built under the screen so it slides rather than being
    /// made at the moment it is asked for (the owner: "opening chats and
    /// stuff im noticing a lot of not smooth elements that jolt out"). Down,
    /// it reads nothing as seen and takes no keyboard.
    var visible = true
    /// The win the chat rises to answer, when Reply under the hold's bar
    /// raised it.
    var answeringWin: UUID? = nil
    /// Raises the drawer again, after a sheet the chat went down for.
    var reopen: (() -> Void)? = nil

    /// **In the crew's persistent native sheet** (2026-10-15): the crew sets
    /// its heights and keeps it up; this view brings only its content.
    var native = false
    /// **The whole page of a message thread to one person**
    /// (2026-10-16): no frame of its own, the page's
    /// header is the page's.
    var direct = false

    init(crewID: CrewID, startsWriting: Bool = false, startsWith: ChatPlusRow.Choice? = nil, visible: Bool = true,
         answeringWin: UUID? = nil, native: Bool = false, direct: Bool = false,
         close: (() -> Void)? = nil, reopen: (() -> Void)? = nil,
         onOpenWin: @escaping (UUID) -> Void = { _ in }, onAddWin: @escaping () -> Void = {}) {
        self.crewID = crewID
        self.close = close
        self.startsWriting = startsWriting
        self.startsWith = startsWith
        self.visible = visible
        self.answeringWin = answeringWin
        self.native = native
        self.direct = direct
        self.reopen = reopen
        self.onOpenWin = onOpenWin
        self.onAddWin = onAddWin
        _field = State(initialValue: ChatFieldText(CrewDrafts.chat(crewID)))
    }

    var body: some View {
        #if DEBUG
        let _ = PerfProbe.count("CrewChatSheet")
        #endif
        let crew = store.visible(crewID)
        // **A plan's line is a line of the chat, and stays in it** (the
        // owner, 2026-10-13: "why did it disappear from the chat when I
        // dismissed the notification, doesn't make sense"). Its card had a
        // close, and closing it, here or on the crew's screen, took the
        // line out of this chat for the day. Nothing takes it out now.
        let messages = store.messages(in: crewID)
        let reactions = store.messageReactions(in: crewID)
        framed(chatPage(messages, reactions: reactions, crew: crew),
               name: crew == nil ? "" : store.chatName(crewID))
        // As a sheet of its own; in the crew's native sheet the crew sets
        // the heights (`CrewTowerView.nativeChat`).
        .modifier(OwnChatDetents(on: !native, detent: $detent))
        // Open is seen: the dot goes, and the hour's held alert with it. And
        // again as lines arrive while it is open, from the crew screen's
        // live sync underneath (`refreshLive`, every 3 seconds).
        // One of the hold tip's three showings, counted once a chat.
        .onAppear {
            if !holdTipCounted, !UserDefaults.standard.bool(forKey: Self.holdTaughtKey),
               store.messages(in: crewID).contains(where: { $0.senderProfileID != store.me }) {
                let shown = UserDefaults.standard.integer(forKey: Self.holdTipShownKey)
                if shown < 3 {
                    UserDefaults.standard.set(shown + 1, forKey: Self.holdTipShownKey)
                    holdTipCounted = true
                }
            }
        }
        .onAppear {
            guard visible else { return }
            // **In the crew's native sheet it appears already open**, so it
            // rises as the drawer did: seen and the keyboard once it has
            // landed, never during (2026-10-15: both fired mid-rise and held
            // its frames for 400ms).
            if native { risen(); return }
            newFrom = store.firstUnseenMessage(in: crewID)
            store.markChatSeen(crewID)
            if startsWriting { writing = true }
            if let startsWith { afterSheet { open(startsWith) } }
        }
        .onChange(of: messages.map(\.messageID)) { _, _ in if visible { store.markChatSeen(crewID) } }
        // Up: seen, and the plus row or the keyboard as it was asked for,
        // the keyboard only once the drawer has landed (both rising at once
        // was a jolt). Down: the keyboard and the row put away.
        .onChange(of: visible) { _, up in
            if up {
                risen()
            } else {
                writing = false
                replyingToWin = nil
            }
        }
        .alert("Try other words", isPresented: $refused) {
            Button("OK", role: .cancel) {}
        }
        // **200 lines in a crew day** (`CrewSendThrottle`, 2026-10-08): said
        // once, calmly, and the words wait in the field.
        .alert("That's plenty for today", isPresented: $atDailyLimit) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The chat takes more from you when the crew's day starts again.")
        }
        .alert("That sticker stays with you", isPresented: $stickerRefused) {
            Button("OK", role: .cancel) {}
        }
        .overlay(alignment: .bottom) { dialogs }
        .onChange(of: writing) { _, now in
            drawerWriting(now)
            // The newest line on the field once the keys have landed, never
            // tucked under it.
            if now {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(380))
                    snapToNewest += 1
                }
            }
        }
        // The clock a stuck line is read against, and the one warning when
        // a line of yours is first said not to have gone (M1).
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                // Moved only when what is stuck changes, so a quiet chat is
                // not redrawn every two seconds for nothing.
                let now = Date()
                let stuck = Set(store.messages(in: crewID).filter { store.isUnsent($0, now: now) }.map(\.messageID))
                guard stuck != toldUnsent else { continue }
                if !stuck.subtracting(toldUnsent).isEmpty { HapticsEngine.warning() }
                clock = now
                toldUnsent = stuck
            }
        }
        .task {
            // After the rise, not under it.
            if native { try? await Task.sleep(for: GridConstants.drawerLands) }
            GroupPlanBook.reconcile(context: modelContext)
            planTick += 1
            lookBack = CrewLookBack.find(for: crewID, context: modelContext)
        }
        .sheet(isPresented: $planning) {
            GroupPlanSheet(crewName: store.crew(crewID) == nil ? "Your Crew" : store.chatName(crewID),
                           title: $planDraft) { title, choice in
                propose(title, choice)
            }
        }
        .alert("That photo stays with you", isPresented: $pictureRefused) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $choosingSticker, onDismiss: {
            if !makingSticker { newSticker = nil; stickerFor = nil }
        }) { stickerSheet }
        .stickerMaking(isPresented: $makingSticker) { symbol in
            // Back to the grid with it chosen, once the lift has gone.
            newSticker = symbol
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                choosingSticker = true
            }
        }
        .sheet(isPresented: $doodling) {
            DoodleSheet(owner: store.chatName(crewID)) { drawing in
                guard let png = InkExport.doodlePNG(drawing) else { return }
                Task { answer(await store.sendDoodle(png, in: crewID)) }
            }
        }
        .sheet(isPresented: $choosingMemory) {
            CrewMemorySheet(crewID: crewID) { found in bringBack(found) }
        }
        .sheet(isPresented: $showsStrip) {
            // **Today's strip, shown, and Send puts it in this chat**
            // (`CrewStripSendSheet`). It opened the booth, which on most
            // days would not develop, and sent from a share sheet.
            CrewStripSendSheet(send: { png in sendStrip(png) }, addWin: { afterSheet { addWin(photo: nil) } })
        }
        .alert(stripProblem ?? "", isPresented: Binding(get: { stripProblem != nil },
                                                        set: { if !$0 { stripProblem = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .fullScreenCover(item: $viewingPicture) { message in
            ChatPictureViewer(message: message, sender: name(of: message.senderProfileID),
                              mine: message.senderProfileID == store.me, hearted: isHearted(message.messageID),
                              onClose: { viewingPicture = nil },
                              onHeart: { heart(message) },
                              onReport: {
                                  viewingPicture = nil
                                  afterSheet { reporting = message }
                              },
                              onAddWin: { image in
                                  viewingPicture = nil
                                  afterSheet { addWin(photo: image) }
                              })
        }
        .fullScreenCover(item: $planStrip) { plan in
            StripBooth(owner: .crew(crewID.rawValue), day: today) {
                await PhotoStrip.crew(crewID, titled: plan.title)
            }
        }
        #if DEBUG
        // `-strataChatReact open`: a friend's line held, its menu open, so
        // it can be photographed (the seed is `CrewDebugSeed`).
        .task {
            guard DebugHarness.argument("-strataChatReact") == "open" else { return }
            try? await Task.sleep(for: .milliseconds(900))
            let lines = store.messages(in: crewID).filter { $0.senderProfileID != store.me }
            menuOn = (lines.dropFirst().first ?? lines.first)?.messageID
        }
        #endif
    }

    /// Up: seen, and the plus row or the keyboard as it was asked for, the
    /// keyboard only once the chat has landed (both rising at once was a
    /// jolt).
    private func risen() {
        newFrom = store.firstUnseenMessage(in: crewID)
        // Seen once the drawer has risen, not during: marking it
        // redraws the bar's dot, the back button and the tab under
        // the rise (the probe, 2026-10-14). **And to the newest line
        // then too**: asked for as the native sheet appeared, it
        // scrolled against a thread not yet its final height and left
        // the last lines under the field (walked, 2026-10-15).
        Task { @MainActor in
            try? await Task.sleep(for: GridConstants.drawerLands)
            guard visible else { return }
            store.markChatSeen(crewID)
            snapToNewest += 1
        }
        // Chosen on the resting bar's +: it opens once the chat has landed.
        if let startsWith {
            Task { @MainActor in
                try? await Task.sleep(for: GridConstants.drawerLands)
                if visible { open(startsWith) }
            }
        }
        if let answeringWin { replyingTo = nil; replyingToWin = answeringWin }
        guard startsWriting else { return }
        Task { @MainActor in
            try? await Task.sleep(for: GridConstants.drawerLands)
            if visible { writing = true }
        }
    }

    // MARK: - The thread

    private func thread(_ messages: [CrewMessage], reactions: [UUID: [Reaction]], crew: Crew?) -> some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if messages.isEmpty {
                            // The page's one sentence in the type and ink
                            // every other empty page uses (`PhotoCollection
                            // View.emptyLine`); it was the quietest thing on it.
                            //
                            // **And that the chat is today's** (M6): without
                            // it a morning's empty chat reads as lost lines.
                            VStack(spacing: GridConstants.gapTight) {
                                if isDirect {
                                    EmptyPageLine("Say hi", icon: "bubble.left",
                                                  detail: "Just between the two of you. Messages stay two weeks.")
                                } else {
                                    EmptyPageLine(CrewChatWords.quiet, icon: "bubble.left",
                                                  detail: "The chat clears at midnight.")
                                    clearsLine(crew)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        } else {
                            LazyVStack(spacing: GridConstants.spacing) {
                                // The same line where a full thread stops.
                                clearsLine(crew)
                                    .padding(.bottom, GridConstants.gapItem)
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                    // A conversation runs over days: each
                                    // day starts under its own date, small.
                                    if isDirect, index == 0 || messages[index - 1].crewDay != message.crewDay {
                                        dayLine(message.crewDay)
                                    }
                                    row(message, after: index > 0 ? messages[index - 1] : nil,
                                        reactions: shownReactions(message, lines: reactions), crew: crew)
                                        // **The held line alone in focus**, as
                                        // Messages dims the rest under its menu
                                        // (2026-10-15: the menu lay over the
                                        // next bubble at full strength).
                                        .opacity(menuOn == nil || menuOn == message.messageID ? 1 : 0.25)
                                        .animation(GridConstants.crossFade, value: menuOn)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, hPad)
                            .padding(.vertical, GridConstants.gapItem)
                            // **Bottom-anchored**: a short chat sits on the
                            // field, newest at the foot, as Messages sits.
                            .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                        }
                    }
                }
                .defaultScrollAnchor(.bottom)
                // And when its own height changes (the field settling, the
                // drawer reaching its height): the newest line stays on the
                // field, never half under it (filmed, 2026-10-14).
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .scrollDismissesKeyboard(.interactively)
                // **At the newest line, it stays at the newest line** as the
                // thread gets shorter (the keys rising, the field growing),
                // as Messages keeps it (2026-10-15: the keys took the foot
                // of the thread and the top stayed put, so opening to write
                // showed the morning, not the last line). Read from before
                // the change: the distance from the foot grows by exactly
                // what the thread lost.
                .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.height } action: { old, new in
                    let lost = old - new
                    guard lost > 1, lineFrames.fromFoot < Self.followsWithin + lost,
                          let last = messages.last?.id else { return }
                    var still = Transaction()
                    still.disablesAnimations = true
                    withTransaction(still) { proxy.scrollTo(last, anchor: .bottom) }
                }
                // Lines leave under the title softly, as the tower's do.
                .softScrollEdge(.top)
                // Where the thread stands on screen, for which way a held
                // line's menu opens (`opensAbove`).
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { lineFrames.thread = $0 }
                // How far the newest line is below the screen's foot. Kept
                // without a redraw; only Newest going away is a state change.
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentSize.height - geo.contentOffset.y - geo.containerSize.height + geo.contentInsets.bottom
                } action: { _, fromFoot in
                    lineFrames.fromFoot = fromFoot
                    if newBelow, fromFoot < GridConstants.gapSection {
                        withAnimation(GridConstants.motionSnappy) { newBelow = false }
                    }
                }
                // **No jump while reading** (M7): a new line takes the
                // thread down only when it is yours or you are within a
                // screen of the newest. It went down on every line, from
                // wherever you were reading, every three seconds of a busy
                // chat.
                .onChange(of: messages.last?.id) { _, last in
                    guard let last else { return }
                    let mine = messages.last?.senderProfileID == store.me
                    guard ChatFollow.follows(newLineIsMine: mine, distanceFromFoot: lineFrames.fromFoot,
                                             screen: geo.size.height) else {
                        withAnimation(GridConstants.motionSnappy) { newBelow = true }
                        return
                    }
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
                .onChange(of: snapToNewest) { _, _ in
                    guard let last = messages.last?.id else { return }
                    // Still while the drawer is down; on the keys' pace once
                    // it is up and the person is watching.
                    if visible {
                        withAnimation(GridConstants.keyboard) { proxy.scrollTo(last, anchor: .bottom) }
                    } else {
                        var still = Transaction()
                        still.disablesAnimations = true
                        withTransaction(still) { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
                .onChange(of: toNewest) { _, _ in
                    guard let last = messages.last?.id else { return }
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                        proxy.scrollTo(last, anchor: .bottom)
                        newBelow = false
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if newBelow {
                        newestButton
                            .padding(.trailing, hPad)
                            .padding(.bottom, GridConstants.gapTight)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                // A quoted line, tapped: to it, and it lights a moment.
                .onChange(of: goingTo) { _, id in
                    guard let id else { return }
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    goingTo = nil
                }
            }
        }
    }

    /// One line: yours on the right, a friend's on the left with their face
    /// and, at the start of their run, their name.
    @ViewBuilder
    private func row(_ message: CrewMessage, after previous: CrewMessage?, reactions: [Reaction],
                     crew: Crew?) -> some View {
        let mine = message.senderProfileID == store.me
        // **A time above the day's first line, and above one that comes an
        // hour after the one before** (M5). After that gap the same
        // person's run starts again, face and name shown.
        let timed = ChatTimes.showsTime(message, after: previous)
        let opensRun = previous?.senderProfileID != message.senderProfileID || timed
        let member = crew?.member(message.senderProfileID)
        let unsent = mine && store.isUnsent(message, now: clock)
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            // **Where you left off** (`newFrom`), with air, never a rule.
            if message.messageID == newFrom, previous != nil {
                Text("New")
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkSecondary)
                    .padding(.horizontal, GridConstants.gapItem)
                    .frame(height: 28)
                    .background(Capsule(style: .continuous).fill(AppColors.quietFill))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GridConstants.gapTight)
                    .accessibilityLabel("New messages")
            }
            if timed {
                Text(ChatTimes.words(message.createdAt))
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, GridConstants.gapTight)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
                if mine {
                    Spacer(minLength: Self.otherSide)
                } else if !isDirect {
                    // Two of you: their face and name are the page's header,
                    // so the lines go without them, as Messages' do.
                    Group {
                        if opensRun, let member, let crew {
                            faceMenu(member, crew: crew)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: Self.faceSide, height: Self.faceSide)
                }
                VStack(alignment: mine ? .trailing : .leading, spacing: GridConstants.spacing) {
                    if !mine, opensRun, !isDirect {
                        Text(name(of: message.senderProfileID))
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkTertiary)
                            .lineLimit(1)
                            .fitsLargeType(.subheadline)
                            .padding(.leading, GridConstants.gapLabel)
                            .accessibilityHidden(true)
                    }
                    bubble(message, mine: mine)
                        .opacity(unsent ? 0.6 : 1)
                }
                if !mine { Spacer(minLength: Self.otherSide) }
            }
            // **A line that has not gone says so** (M1), in the voice's own
            // error line, under it. A tap on the line tries again.
            if unsent {
                Text(Self.unsentWords)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
            // What everyone chose, under the line, on the line's side. Out
            // of the line's own row, so a friend's face stays beside their
            // words rather than dropping to the chips.
            if !reactions.isEmpty {
                ChatReactionChips(reactions: reactions, me: store.me, name: name(of:))
                    .padding(.leading, mine ? 0 : Self.faceSide + GridConstants.gapTight)
                    .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
                    .padding(.top, -GridConstants.spacing)
            }
        }
        // Runs are told apart by air, never by a line.
        .padding(.top, opensRun && previous != nil ? GridConstants.gapItem : 0)
        .animation(motion, value: reactions)
        .animation(GridConstants.crossFade, value: unsent)
    }

    /// **A friend's face opens what you can do about them** (M2b; the
    /// owner's 2026-10-13 call: Block is reached from a person's face, which
    /// App Review 1.2 asks for). The system's menu, as a member's row in Crew
    /// Info opens it: their name, "Started the crew" where true, Report and
    /// Block. The face is drawn small; the finger gets 44 points.
    private func faceMenu(_ member: CrewMember, crew: Crew) -> some View {
        let who = member.shortName.isEmpty ? "A friend" : member.shortName
        return Menu {
            Section(crew.isOwner(member.profileID) ? "\(who), started the crew" : who) {
                // Their profile, as a press on their head in Crews opens it.
                // Not someone you blocked: their head and name are gone
                // from your phone, and a profile would bring them back.
                if !store.blocked.contains(member.profileID) {
                    Button("Profile", systemImage: "person.crop.circle") { alone { profileOf = member } }
                }
                Button("Report", systemImage: "exclamationmark.bubble") { reportingPerson = member }
                if !store.blocked.contains(member.profileID) {
                    Button("Block", systemImage: "nosign", role: .destructive) { blockingPerson = member.profileID }
                }
            }
        } label: {
            CrewFace(member: member, crew: crew.id, me: store.me, side: Self.faceSide)
                .contentShape(Rectangle().inset(by: -(GlassIconButton.defaultSide - Self.faceSide) / 2))
        }
        .accessibilityLabel("\(who)'s Card")
    }

    /// The bubble. **A tap opens what it quotes**: the win, or the line it
    /// answers. **A hold opens its menu** (M2, the owner's 2026-10-13 call):
    /// the reactions on top, then Reply, Heart, Copy, and Report on a
    /// friend's line or Delete on yours. VoiceOver has every one as an action,
    /// since a hold is a gesture it cannot make.
    @ViewBuilder
    private func bubble(_ message: CrewMessage, mine: Bool) -> some View {
        let id = message.messageID
        let quote = quoted(message)
        let answered = quotedLine(message)
        // A story reply says so, in the poster's words for it (Snapchat's
        // "Replied to your story").
        // "Your story" only in a chat of two, where it is true; in a crew,
        // whose story it was is not on the line.
        let personal = store.crew(crewID)?.isPersonal == true
        let storyLine = message.storyQuote.map {
            mine ? "You replied to their story: \($0)" : personal ? "Replied to your story: \($0)" : "Replied to a story: \($0)"
        }
        let face = bubbleFace(message, mine: mine, quote: quote?.title ?? answered?.words ?? storyLine)
        // **Two taps heart it** (M3; the owner, 2026-10-13: "double tap a
        // message to heart it"), yours or a friend's, and two more take the
        // heart back. Checked before the single tap, so on a bubble a tap
        // opens something from (the quoted win, the answered line) that tap
        // waits a beat, as Instagram's does. They were buttons; a button
        // answers the first tap and never sees a second.
        face
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { doubleTap(message) }
            .onTapGesture {
                // The lift that ended a hold is not a tap.
                if held == id { held = nil; return }
                if mine, store.isUnsent(message, now: clock) {
                    HapticsEngine.lightTap()
                    Task { await store.retry(message) }
                } else if let quote {
                    HapticsEngine.lightTap()
                    onOpenWin(quote.winID)
                } else if let answered {
                    HapticsEngine.lightTap()
                    goTo(answered.id)
                } else if message.isStrip || message.isPicture {
                    // **A strip, picture or sticker opens full screen** (M4).
                    HapticsEngine.lightTap()
                    viewingPicture = message
                }
            }
        .overlay(alignment: mine ? .topLeading : .topTrailing) {
            // The heart pops at the bubble's corner, the tower's own burst,
            // small.
            if let burst = bursts[id] {
                ReactionBurst(emoji: Reaction.doubleTap, size: Self.burstSide)
                    .id(burst)
                    .offset(x: mine ? -Self.burstSide / 3 : Self.burstSide / 3, y: -Self.burstSide / 3)
            }
        }
        .scaleEffect(lit == id ? 1.04 : 1, anchor: mine ? .trailing : .leading)
        .animation(motion, value: lit == id)
        // **Swiped right, it is quoted to reply**, as Messages does (the
        // interaction audit, 2026-10-15). Reply stays in the hold menu too.
        .modifier(SwipeToReply { if store.canReply() { reply(to: message) } })
        .simultaneousGesture(LongPressGesture(minimumDuration: Self.holdToReact).onEnded { _ in
            UserDefaults.standard.set(true, forKey: Self.holdTaughtKey)
            openMenu(on: message, fromQuote: quote != nil || answered != nil)
        })
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { lineFrames.mid[id] = $0 }
        .blockMenu(isPresented: menuBinding(id), above: opensAbove(id)) { lineMenu(message, mine: mine) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken(message, quote: quote?.title ?? answered?.words))
        .accessibilityHint(quote != nil ? "Opens the win." : answered != nil ? "Goes to the line it answers."
                           : message.isStrip || message.isPicture ? "Opens it full screen." : "")
        .accessibilityActions {
            if mine, store.isUnsent(message, now: clock) {
                Button("Try Again") { Task { await store.retry(message) } }
            }
            Button("React") { openMenu(on: message, fromQuote: false) }
            Button("Reply") { reply(to: message) }
            Button(isHearted(id) ? "Remove Heart" : "Heart") { heart(message) }
            if message.hasWordsToCopy { Button("Copy") { copy(message) } }
            if mine {
                if store.canDelete(message) { Button("Delete") { delete(message) } }
            } else {
                Button("Hide for Me") { CrewHiding.hide(message.messageID) }
                Button("Report") { reporting = message }
                Button("Block \(name(of: message.senderProfileID))") { blockingPerson = message.senderProfileID }
            }
        }
    }

    /// "Today's chat clears at midnight.", or at this phone's time for the
    /// crew's midnight when the two differ (M6). Quiet, in the app only.
    /// A conversation's day, over its first line: "Today", "Yesterday", or
    /// the weekday and date.
    private func dayLine(_ day: String) -> some View {
        let date = DateUtils.date(from: day) ?? store.now()
        let words: String = Calendar.current.isDateInToday(date) ? "Today"
            : Calendar.current.isDateInYesterday(date) ? "Yesterday"
            : date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return Text(words)
            .font(Typography.screenSubtitle)
            .foregroundStyle(AppColors.inkTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, GridConstants.gapTight)
            .accessibilityAddTraits(.isHeader)
    }

    /// A message thread to one person (`Crew.isPersonal`).
    private var isDirect: Bool { store.crew(crewID)?.isPersonal == true }

    @ViewBuilder
    private func clearsLine(_ crew: Crew?) -> some View {
        if crew?.isPersonal == true {
            Text("Messages stay two weeks.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkTertiary)
                .frame(maxWidth: .infinity)
        } else {
            crewClearsLine(crew)
        }
    }

    private func crewClearsLine(_ crew: Crew?) -> some View {
        Text(ChatClears.line(crewZone: crew?.timeZone ?? .current, here: .current, now: store.now()))
            .font(Typography.screenSubtitle)
            .foregroundStyle(AppColors.inkTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// **Newest** (M7): one round glass button over the field's right end,
    /// with the app's dot on its shoulder for what came in below.
    private var newestButton: some View {
        GlassIconButton(systemName: "arrow.down", onPage: true, accessibilityLabel: "Newest Messages") {
            toNewest += 1
        }
        .overlay(alignment: .topTrailing) {
            NewsDot(ringed: true).offset(x: 1, y: -1)
        }
        .accessibilityValue("New messages")
    }

    /// The voice's own error line (`docs/voice.md`, Error).
    static let unsentWords = "That didn't send. Try once more."

    // MARK: - The hold menu

    private var motion: Animation { reduceMotion ? GridConstants.crossFade : GridConstants.elasticPop }

    private func menuBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { menuOn == id }, set: {
            guard !$0, menuOn == id else { return }
            menuOn = nil
            // The lift that ended the hold has been and gone by now.
            held = nil
        })
    }

    /// `fromQuote` is kept for its callers; **every** held bubble now
    /// ignores the lift that ended the hold, since a picture's tap opens it
    /// full screen as a quote's opens the win.
    private func openMenu(on message: CrewMessage, fromQuote: Bool) {
        held = message.messageID
        HapticsEngine.lightTap()
        writing = false
        menuOn = message.messageID
    }

    /// A line in the lower half of the thread opens its menu above it, one
    /// in the upper half below it, so the menu always has the room.
    private func opensAbove(_ id: UUID) -> Bool {
        guard let mid = lineFrames.mid[id], lineFrames.thread != .zero else { return true }
        return mid > lineFrames.thread.midY
    }

    /// **The menu**, in the app's one menu drawing (`BlockMenuRow`), hung
    /// off the bubble. Reactions on top, as Messages draws its Tapbacks.
    /// Copy only where there are words; a plan's line has no Delete, since
    /// his rule is that it never leaves the chat. Each row runs once the
    /// menu has gone (`BlockMenuAfter`).
    @ViewBuilder
    private func lineMenu(_ message: CrewMessage, mine: Bool) -> some View {
        let id = message.messageID
        let close = menuBinding(id)
        ChatReactionBar(mine: store.myReaction(toMessage: target(id), in: crewID),
                        pick: { emoji in
                            BlockMenuAfter.run(closing: close) { react(.emoji(emoji), to: id) }
                        },
                        more: {
                            BlockMenuAfter.run(closing: close) { emojiFor = id }
                        },
                        sticker: store.photosAllowed() ? {
                            BlockMenuAfter.run(closing: close) {
                                stickerFor = id
                                alone { choosingSticker = true }
                            }
                        } : nil)
            .padding(.horizontal, GridConstants.horizontalPadding - ReactionBar.inset - GridConstants.gapTight)
            .padding(.bottom, GridConstants.gapTight)
        Divider()
        BlockMenuRow("Reply", "arrowshape.turn.up.left") {
            BlockMenuAfter.run(closing: close) { reply(to: message) }
        }
        // **No Heart row** (the owner, 2026-10-14: "the heart is clutter"):
        // ❤️ is on the row above and two taps give it, as in Messages.
        if message.hasWordsToCopy {
            BlockMenuRow("Copy", "doc.on.doc") {
                BlockMenuAfter.run(closing: close) { copy(message) }
            }
        }
        if mine {
            if store.canDelete(message) {
                BlockMenuRow("Delete", "trash", destructive: true) {
                    BlockMenuAfter.run(closing: close) { delete(message) }
                }
            }
        } else {
            // **Do It Too, from a friend's win in the chat** (the chat
            // research, 2026-10-15, item 9): the viewer's own action, where
            // the win is said. On your plan for today; nothing is sent.
            if store.isWinLine(message), let id = message.quoteWinID,
               let win = store.wins(in: crewID).first(where: { $0.winID == id }) {
                BlockMenuRow("Do It Too", "checklist") {
                    BlockMenuAfter.run(closing: close) {
                        let context = modelContext
                        let before = DayComposing.onPlan(win.title, in: (try? context.fetch(FetchDescriptor<PlanItem>())) ?? [])
                        guard let line = DayComposing.doItToo(win.title, colour: win.colour, size: win.blockSize,
                                                              context: context) else { return }
                        HapticsEngine.success()
                        UndoLine.shared.show("On your plan for today", undo: {
                            // Only a line this press made goes again.
                            guard before == nil, !line.isDeleted else { return }
                            PlanItem.remove(line, context: context)
                        })
                    }
                }
            }
            // **Out of your sight, for you** (the compliance audit,
            // 2026-10-15, §3.2): a win could be hidden and a line could not.
            BlockMenuRow("Hide for Me", "eye.slash") {
                BlockMenuAfter.run(closing: close) { CrewHiding.hide(id) }
            }
            BlockMenuRow("Report", "exclamationmark.bubble", destructive: true) {
                BlockMenuAfter.run(closing: close) { reporting = message }
            }
            // **Block, where the line is** (the App Store audit, 2026-10-17:
            // in a conversation, Block was only after a report). Guideline
            // 1.2 asks for both, plainly, wherever someone can reach you.
            if message.senderProfileID != store.me {
                BlockMenuRow("Block \(name(of: message.senderProfileID))", "nosign", destructive: true) {
                    BlockMenuAfter.run(closing: close) { blockingPerson = message.senderProfileID }
                }
            }
        }
    }

    @Environment(\.chatDrawerWriting) private var drawerWriting
    @Environment(\.chatAtRest) private var atRest

    /// The emoji keyboard "+" raises for a held line, from a field nobody sees.
    private var emojiPicker: some View {
        EmojiField(isActive: Binding(get: { emojiFor != nil }, set: { if !$0 { emojiFor = nil } })) { emoji in
            if let id = emojiFor { react(.emoji(emoji), to: id) }
            emojiFor = nil
        }
        .frame(width: 1, height: 1)
        .opacity(0.01)
        .accessibilityHidden(true)
    }

    /// Two taps: the heart, or the heart taken back if it was yours. A
    /// light tap either way; the pop only when one is given.
    private func doubleTap(_ message: CrewMessage) {
        let id = message.messageID
        held = nil
        HapticsEngine.lightTap()
        if !isHearted(id) {
            let burst = UUID()
            bursts[id] = burst
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                if bursts[id] == burst { bursts[id] = nil }
            }
        }
        heart(message)
    }

    private func isHearted(_ id: UUID) -> Bool {
        store.myReaction(toMessage: target(id), in: crewID)?.emoji == Reaction.doubleTap
    }

    /// **A win said in the chat is reacted to as the win** (the chat
    /// research, 2026-10-15, item 2): a heart on "↪ Gym" in the chat is the
    /// heart on Gym's block, on the tower and on its owner's phone, not a
    /// second, separate heart on a line. A line that is not a win is itself.
    private func target(_ lineID: UUID) -> UUID {
        guard let line = store.messages(in: crewID).first(where: { $0.messageID == lineID }) else { return lineID }
        return target(of: line)
    }

    private func target(of line: CrewMessage) -> UUID {
        guard store.isWinLine(line), let win = line.quoteWinID else { return line.messageID }
        return win
    }

    /// The reactions a line shows under it: the win's, for a win's line.
    private func shownReactions(_ message: CrewMessage, lines: [UUID: [Reaction]]) -> [Reaction] {
        let id = target(of: message)
        guard id != message.messageID else { return lines[message.messageID] ?? [] }
        return (store.reactionsByCrew[crewID] ?? [])
            .filter { $0.winID == id && !store.blocked.contains($0.profileID) && !$0.isSticker }
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    }

    /// **Heart** gives ❤️, or takes yours back if it is already the heart;
    /// another mark of yours becomes the heart. Taking it back tells nobody.
    private func heart(_ message: CrewMessage) {
        react(.emoji(Reaction.doubleTap), to: message.messageID)
    }

    private func react(_ pick: Reaction.Pick, to id: UUID) {
        // An emoji on a win's line goes to the win; a sticker stays a line's.
        if case .emoji(let emoji) = pick, target(id) != id {
            let win = target(id)
            Task { await store.react(emoji, to: win, in: crewID) }
            return
        }
        Task {
            if await store.react(pick, toMessage: id, in: crewID) == .refusedSketch { stickerRefused = true }
        }
    }

    /// One of your stickers on a line, from the sheet "+" opens.
    private func reactSticker(_ symbol: String, to id: UUID) {
        guard let name = StickerStore.name(in: symbol),
              let png = StickerStore.shared.image(name)?.pngData() else { return }
        react(.sticker(name: name, png: png), to: id)
    }

    /// The line's words on the pasteboard; the tick says so, and nothing else.
    private func copy(_ message: CrewMessage) {
        UIPasteboard.general.string = message.text
        HapticsEngine.tick()
    }

    /// **Reply**: the line quoted above the field, and the field ready.
    private func reply(to message: CrewMessage) {
        HapticsEngine.lightTap()
        withAnimation(GridConstants.motionSnappy) { replyingTo = message }
        writing = true
    }

    /// **Delete, with Undo** (M2; `docs/ten.md` rule 3: confirmed or
    /// undoable). The line leaves this screen at once and "Line deleted ·
    /// Undo" stands for five seconds; only then is it taken out of
    /// everyone's chat.
    private func delete(_ message: CrewMessage) {
        let id = message.messageID
        if replyingTo?.messageID == id { replyingTo = nil }
        withAnimation(motion) { store.holdBack(line: id) }
        UndoLine.shared.show("Line deleted", undo: {
            withAnimation(motion) { store.keepLine(id) }
        }, expire: {
            Task { await store.deleteLine(id, in: crewID) }
        })
    }

    /// To a quoted line, which lights for a moment.
    private func goTo(_ id: UUID) {
        goingTo = id
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            lit = id
            try? await Task.sleep(for: .milliseconds(700))
            if lit == id { lit = nil }
        }
    }

    /// The line a reply answers, while it is still in today's chat, as
    /// "Sam: see you at 6". Gone, and the reply stands with no quote.
    private func quotedLine(_ message: CrewMessage) -> (words: String, id: UUID)? {
        guard let id = message.quoteWinID, quoted(message) == nil,
              let line = store.messages(in: crewID).first(where: { $0.messageID == id }) else { return nil }
        return ("\(name(of: line.senderProfileID)): \(gist(line))", id)
    }

    /// A line in a few words, for a quote of it.
    private func gist(_ line: CrewMessage) -> String {
        if line.isStrip { return "a photo strip" }
        if let plan = line.groupPlan { return plan.title }
        if line.isSticker { return "a sticker" }
        if line.isPicture { return line.caption.isEmpty ? "a photo" : line.caption }
        if line.text.isEmpty { return "a doodle" }
        return line.text
    }

    @ViewBuilder
    private func bubbleFace(_ message: CrewMessage, mine: Bool, quote: String?) -> some View {
        if message.isStrip, let strip = message.sketch {
            CrewStripPicture(url: strip)
        } else if let plan = message.groupPlan {
            planCard(plan, pinned: false)
        } else if message.isPicture, let picture = message.sketch {
            ChatPicture(url: picture, caption: message.isSticker ? "" : message.caption, mine: mine,
                        sticker: message.isSticker)
        } else if let quote, let photo = winPhoto(message, mine: mine) {
            // **A win said in the chat, with its photo**: the picture, and
            // its title under it with the quote's mark. No sentence: the win
            // speaks for itself (the research, section 3, Wording).
            ChatPicture(url: photo, caption: "\u{21AA}\u{FE0E} \(quote)", mine: mine)
        } else {
            lineFace(message, mine: mine, quote: quote)
        }
    }

    /// The photo on a win said in the chat, when the line is one and its win
    /// has one this phone may show.
    private func winPhoto(_ message: CrewMessage, mine: Bool) -> URL? {
        guard store.isWinLine(message), let id = message.quoteWinID,
              let photo = store.wins(in: crewID).first(where: { $0.winID == id })?.photo else { return nil }
        return mine || store.photoIsShown(photo) ? photo : nil
    }

    private func lineFace(_ message: CrewMessage, mine: Bool, quote: String?) -> some View {
        // Yours in ink, with the page's own colour as its type, as the
        // filled `PrimaryCapsule` is; a friend's on a quiet fill in ink.
        let ink = mine ? AppColors.myLineInk : AppColors.inkPrimary
        // The quote steps down a rung on a friend's line (`inkTertiary`); on
        // yours it keeps the page's colour, since no ink token inverts onto
        // ink, and the arrow and the smaller size already make it the quote.
        let quoteInk = mine ? AppColors.myLineInk : AppColors.inkTertiary
        // A win said in the chat with no photo: its title, once, behind the
        // quote's mark. Drawn as a reply it read "↪ Gym / Gym".
        let saysWin = quote != nil && store.isWinLine(message)
        // Only emoji, one to three of them, and nothing quoted or drawn:
        // large and bare, as Messages draws it (`ChatEmoji`).
        let big = quote == nil && message.sketch == nil && ChatEmoji.isBig(message.text)
        return VStack(alignment: .leading, spacing: GridConstants.spacing) {
            if let quote, !saysWin {
                let answered = store.storyAnswered(message)
                HStack(spacing: GridConstants.gapTight) {
                    // The story it answers, small, while the story is on.
                    if let answered { StoryThumb(win: answered) }
                    // U+FE0E: the arrow as type, never the emoji tile it draws as bare.
                    // Two lines beside the story, so its title is not the
                    // part cut off.
                    Text("\u{21AA}\u{FE0E} \(quote)")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(quoteInk)
                        .lineLimit(answered == nil ? 1 : 2)
                        .fixedSize(horizontal: false, vertical: answered != nil)
                        .fitsLargeType(.subheadline)
                }
            }
            if let sketch = message.sketch {
                InkImage(url: sketch, tint: mine ? ink : AppColors.drawingInk)
                    .frame(maxWidth: Self.doodleSide, maxHeight: Self.doodleSide * 3 / 4)
            }
            if !message.text.isEmpty {
                if big {
                    Text(message.text)
                        .font(.system(size: Self.bigEmoji))
                } else {
                    // Links open in Safari, in the line's own ink, underlined.
                    Text(saysWin ? AttributedString("\u{21AA}\u{FE0E} \(message.text)") : ChatLinks.attributed(message.text))
                        .font(Typography.bodyLarge)
                        .foregroundStyle(ink)
                        .tint(ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(.horizontal, big ? 0 : GridConstants.gapLabel)
        .padding(.vertical, big ? 0 : GridConstants.gapItem)
        .background {
            if !big {
                RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                    .fill(mine ? AppColors.myLine : AppColors.quietFill)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
    }

    /// The win a line quotes, by its title, while it is still in the crew and
    /// still yours to see. A win taken back leaves the line with no quote.
    private func quoted(_ message: CrewMessage) -> (title: String, winID: UUID)? {
        guard let id = message.quoteWinID else { return nil }
        // A reply to a story quotes it while the story is on (Tonight's
        // Story, R10); after, the reply stands with its words alone.
        let win: SharedWin
        if let crewWin = store.wins(in: crewID).first(where: { $0.winID == id }),
           store.wins(in: crewID, on: crewWin.crewDay).contains(where: { $0.winID == id }) {
            win = crewWin
        } else if let story = store.storyWin(id, in: crewID) {
            win = story
        } else {
            return nil
        }
        let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (title.isEmpty ? "A win" : title, id)
    }

    private func name(of id: UUID) -> String {
        if id == store.me { return "You" }
        let short = store.crew(crewID)?.member(id)?.shortName ?? ""
        return short.isEmpty ? "A friend" : short
    }

    /// What VoiceOver says for a line: who, what, and when (M5), and that
    /// it has not gone (M1).
    private func spoken(_ message: CrewMessage, quote: String?) -> String {
        var said = said(message, quote: quote) + ", " + ChatTimes.words(message.createdAt)
        if message.senderProfileID == store.me, store.isUnsent(message, now: clock) { said += ", not sent" }
        return said
    }

    private func said(_ message: CrewMessage, quote: String?) -> String {
        var parts = [name(of: message.senderProfileID)]
        if let quote, store.isWinLine(message) {
            parts.append("a win, \(quote)")
            return parts.joined(separator: ", ")
        }
        if let quote { parts.append("replying to \(quote)") }
        if message.isStrip {
            parts.append("a photo strip")
            return parts.joined(separator: ", ")
        }
        if let plan = message.groupPlan {
            parts.append("a plan, \(plan.title), \(plan.whenWords(today: today))")
            return parts.joined(separator: ", ")
        }
        if message.isPicture {
            parts.append(message.isSticker ? "a sticker" : message.caption.isEmpty ? "a photo" : "a photo, \(message.caption)")
            return parts.joined(separator: ", ")
        }
        if message.sketch != nil { parts.append("a doodle") }
        if !message.text.isEmpty { parts.append(message.text) }
        return parts.joined(separator: ", ")
    }

    // MARK: - The hold, said once

    /// **A line can be held: said, on the first few chats** (the launch pass,
    /// 5½: nothing a person needs may hide behind a gesture nobody is told
    /// about). Over the field while a friend's line is there to hold, on the
    /// first three chats opened, and never again once a line has been held.
    static let holdTaughtKey = "chat.holdTaught"
    static let holdTipShownKey = "chat.holdTipShown"
    @State private var holdTipCounted = false

    private var showsHoldTip: Bool {
        guard !UserDefaults.standard.bool(forKey: Self.holdTaughtKey),
              UserDefaults.standard.integer(forKey: Self.holdTipShownKey) < 3 || holdTipCounted else { return false }
        return store.messages(in: crewID).contains { $0.senderProfileID != store.me }
    }

    // MARK: - The field

    @ViewBuilder
    private var composer: some View {
        if store.canReply() {
          VStack(spacing: 0) {
            if showsHoldTip, replyingTo == nil, replyingToWin == nil {
                Text("Hold a message to react or reply.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, GridConstants.spacing)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            if let replyingTo {
                replyQuote(replyingTo)
                    // A fade, so nothing travels against the keys (fix 6).
                    .transition(.opacity)
            } else if let replyingToWin, let win = store.wins(in: crewID).first(where: { $0.winID == replyingToWin }) {
                // Starters for a friend's win, while the field is empty
                // (`ReplyStarters`): a press fills the field, never sends.
                let starters = ReplyStarters.lines(title: win.title, mine: win.senderProfileID == store.me)
                if !starters.isEmpty {
                    WhileFieldEmpty(field: field) {
                        starterRow(starters)
                    }
                    .transition(.opacity)
                }
                quoteRow("\u{21AA}\u{FE0E} \(win.title)") {
                    withAnimation(GridConstants.motionSnappy) { self.replyingToWin = nil }
                }
                .transition(.opacity)
            }
            HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
                // Strip and a sticker are photographs: not offered to
                // someone who may not send one. Their third is Doodle.
                ChatPlusMenu(choices: isDirect
                             ? (store.photosAllowed() ? ChatPlusRow.Choice.direct : ChatPlusRow.Choice.directWithoutPhotos)
                             : (store.photosAllowed() ? ChatPlusRow.Choice.offered : ChatPlusRow.Choice.withoutPhotos)) { choice in
                    choose(choice)
                }
                // The hint in the resting bar's own ink, so the word does not
                // change colour as the chat rises (the consistency pass).
                // Its own view: built here with the binding, the chat counted
                // as reading the words and redrew on every key.
                ChatTextInput(field: field, crewID: crewID, writing: $writing) {
                    // A line more in the field: the newest line rides up
                    // with it rather than going under it (walked, 2026-10-15).
                    snapToNewest += 1
                }
                    .padding(.horizontal, GridConstants.gapLabel)
                    .padding(.vertical, GridConstants.gapTight)
                    .frame(minHeight: GlassIconButton.defaultSide)
                    // A box as it grows, never a capsule: see `glassField`.
                    .glassField()
                    .accessibilityLabel("Message")
                ChatSendButton(field: field) { send() }
            }
            .padding(.horizontal, hPad)
            .padding(.top, GridConstants.gapTight)
            // Low, where the system's own bars sit (`GridConstants.barSink`).
            .modifier(BarSink())
          }
        } else {
            // Off for an age not shared (`canReply`): the chat reads, and
            // says so in one line.
            Text("Writing here is off on this phone.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkTertiary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, hPad)
                .padding(.vertical, GridConstants.gapLabel)
        }
    }

    /// **What Reply is answering** (M2c), over the field: "↪ Sam: see you
    /// at 6", one line, and an x to drop it.
    private func replyQuote(_ line: CrewMessage) -> some View {
        quoteRow("\u{21AA}\u{FE0E} \(name(of: line.senderProfileID)): \(gist(line))") {
            withAnimation(GridConstants.motionSnappy) { replyingTo = nil }
        }
    }

    /// The starters, as chips in a row that scrolls, the plus row's own
    /// quiet capsule.
    private func starterRow(_ starters: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GridConstants.gapTight) {
                ForEach(starters, id: \.self) { line in
                    Button {
                        HapticsEngine.lightTap()
                        field.text = line
                        CrewDrafts.keepChat(line, for: crewID)
                        writing = true
                    } label: {
                        // The chat's own weight, not a heading's: a starter
                        // is words you might say (the fresh-eyes critique).
                        Text(line)
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkPrimary)
                            .padding(.horizontal, GridConstants.gapItem)
                            .frame(height: 34)
                            .background(Capsule(style: .continuous).fill(AppColors.quietFill))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressWord)
                    .accessibilityHint("Puts these words in the message, to change or send.")
                }
            }
            .padding(.horizontal, hPad)
        }
        .edgeFade()
    }

    /// The one quote over the field, for a line or a win.
    private func quoteRow(_ words: String, drop: @escaping () -> Void) -> some View {
        HStack(spacing: GridConstants.gapTight) {
            Text(words)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .lineLimit(1)
                .fitsLargeType(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                HapticsEngine.lightTap()
                drop()
            } label: {
                Image(systemName: "xmark")
                    .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressWord)
            .accessibilityLabel("Stop Replying")
        }
        .padding(.leading, hPad + GlassIconButton.defaultSide + GridConstants.gapTight + GridConstants.gapLabel)
        .padding(.trailing, hPad)
    }


    /// **A draft is cleared by a send that went, and by nothing else** (the
    /// QoL review, 2026-10-06). It lived in this sheet's `@State`, so a swipe
    /// down, a tap on a quoted win (which closes the sheet to open it) or a
    /// sheet closed while a refused send was coming back each lost what you
    /// had written. The field still empties at once, as Messages does; the
    /// kept copy goes only on `.sent`, and only if nothing new was typed
    /// since.
    private func send() {
        let text = field.text
        guard !field.isEmpty else { return }
        // The press is felt, as Messages' send is.
        HapticsEngine.lightTap()
        field.text = ""
        let answering = replyingTo
        let answeringWin = replyingToWin
        withAnimation(GridConstants.motionSnappy) { replyingTo = nil; replyingToWin = nil }
        Task {
            let outcome: SocialStore.ReplyOutcome
            if let answering {
                outcome = await store.send(text, in: crewID, answering: answering.messageID)
            } else if let answeringWin {
                outcome = await store.reply(text, to: answeringWin, in: crewID)
            } else {
                outcome = await store.send(text, in: crewID)
            }
            // Words that come back bring their quote back with them.
            if outcome != .sent, replyingTo == nil, replyingToWin == nil { replyingTo = answering; replyingToWin = answeringWin }
            switch outcome {
            case .sent:
                CrewDrafts.clearChat(crewID, ifStill: text)
            case .throttled:
                // A second send inside a second (2026-10-08): the words come
                // back to the field, and nothing is said.
                if field.text.isEmpty { field.text = CrewDrafts.chat(crewID) }
            case .dailyLimit:
                if field.text.isEmpty { field.text = CrewDrafts.chat(crewID) }
                atDailyLimit = true
            case .refusedWords, .refusedSketch, .notAllowed:
                // Refused words come back to the field, to be changed.
                if field.text.isEmpty { field.text = CrewDrafts.chat(crewID) }
                refused = true
            }
        }
    }

    // MARK: - The plus row

    /// The crew's day, which is the day a plan's "today" means.
    private var today: String {
        store.crew(crewID).map { CrewDay.string(for: store.now(), in: $0.timeZone) } ?? DateUtils.dateString(from: Date())
    }

    private var goalReached: Bool {
        let day = DateUtils.dateString(from: Date())
        let wins = (try? modelContext.fetchCount(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString == day && $0.completed }))) ?? 0
        return wins >= DailyGoal.stored(on: day)
    }

    private func choose(_ choice: ChatPlusRow.Choice) {
        writing = false
        // The card stands in its own window over everything: the chat stays
        // where it is (the second reader, 2026-10-18: lowered for Win, it
        // never came back).
        if choice == .win { open(choice); return }
        alone { open(choice) }
    }

    /// **Never a sheet over the chat** (the owner, 2026-10-14: "a sheet
    /// opening on top of a sheet I dont like that"). In the drawer, the chat
    /// goes down first and the sheet opens on its own; once it has gone, the
    /// chat comes back up, where what was sent has landed.
    private func alone(_ present: @escaping () -> Void) {
        // **Full height, it opens over the chat** (2026-10-15: the chat going
        // down and coming back up for each choice was the "sometimes it
        // pushes up" the owner saw). A card over a whole-screen chat is the
        // iOS stack Messages uses; the drawer's rule was for a part-height
        // panel with a sheet floating over it.
        guard close != nil, !native else { present(); return }
        returnToChat = true
        leave()
        Task { @MainActor in
            try? await Task.sleep(for: GridConstants.drawerLands)
            present()
        }
    }

    /// Something presented from the chat is up.
    private var presenting: Bool {
        planning || showsStrip || doodling || choosingSticker || makingSticker || choosingMemory
            || profileOf != nil
    }


    /// A photograph from the chat's camera, sent as Send a Photo sends one.
    private func sendSnap(_ image: UIImage) {
        guard !sendingPhoto else { return }
        sendingPhoto = true
        Task {
            defer { sendingPhoto = false }
            // Encoded off the main thread: a full camera frame (the reader).
            let encoded = await Task.detached(priority: .userInitiated) { () -> Data? in
                guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
                return ShareDerivative.jpeg(from: data)
            }.value
            guard let jpeg = encoded else { pictureRefused = true; return }
            switch await store.sendPicture(jpeg, caption: "", in: crewID) {
            case .refusedSketch, .notAllowed, .refusedWords: pictureRefused = true
            case let other: answer(other)
            }
        }
    }

    private func open(_ choice: ChatPlusRow.Choice) {
        switch choice {
        // Over the chat, which stays open: the win lands here as a line.
        case .win: addWin(photo: nil)
        case .camera: snapping = AddWinOpening(from: AddWinOpening.foot(), radius: GridConstants.radiusSurface,
                                               colour: .unlabeled, crews: [crewID])
        case .photo: pickingPhoto = true
        case .plan: planning = true
        case .strip: showsStrip = true
        case .doodle: doodling = true
        // Off the row (`ChatPlusRow.Choice.memory`); its sheet stays.
        case .memory: choosingMemory = true
        // Without photographs a sticker is not yours to send: the pad alone.
        case .sticker: if store.photosAllowed() { choosingSticker = true } else { doodling = true }
        }
    }

    /// Something asked for as a sheet leaves: after it has gone, since a
    /// presentation asked for while one is still dismissing is dropped.
    private func afterSheet(_ then: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            then()
        }
    }

    /// The tower a new win stands on: the one the Wins tab shows.
    private var activeTower: Tower? {
        let towers = TowerManager()
        towers.loadActiveTower(context: modelContext)
        return towers.activeTower
    }

    /// **The win, said in the chat once it has reached this crew.** It goes
    /// a moment after Add (its photo is checked first), so the line waits
    /// for it, fifteen seconds at most. A win whose crew was unticked on the
    /// sheet never arrives here, and nothing is said.
    /// **Add a Win from a chat: the camera card, as from everywhere** (the
    /// owner, 2026-10-18: one way in, never the old sheet). It stands over
    /// the chat in its own window. A win for the crew is said here once it
    /// lands; a kept chat photo goes on your tower only (the second reader,
    /// 2026-10-17: nothing reaches a crew without naming it on screen).
    private func addWin(photo: UIImage?) {
        let crew = crewID
        // To this crew only from a crew's chat. A conversation of two is not
        // a crew a win is posted to (the second reader, 2026-10-18: the chip
        // said Just you while it posted to the conversation).
        let toCrew = photo == nil && !isDirect
        AddWinRouter.shared.open(AddWinOpening(
            from: AddWinOpening.foot(), radius: GridConstants.radiusSurface, colour: .unlabeled,
            crews: toCrew ? [crew] : [], photo: photo,
            afterSaved: toCrew ? { habit in sayWin(habit) } : nil))
    }

    private func sayWin(_ habit: Habit) {
        guard let id = (habit.logs ?? []).max(by: { $0.createdAt < $1.createdAt })?.id else { return }
        Task {
            var tries = 0
            while tries < 60, !store.wins(in: crewID).contains(where: { $0.winID == id }) {
                tries += 1
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard store.wins(in: crewID).contains(where: { $0.winID == id }) else { return }
            answer(await store.sendWinLine(id, in: crewID))
        }
    }

    /// Today's strip, into this chat.
    private func sendStrip(_ png: Data) {
        Task {
            let outcome = await store.sendStrip(png, in: crewID)
            if outcome == .sent {
                HapticsEngine.success()
                Analytics.shared.signal(.stripShared, [.destination(.crew)])
            } else {
                HapticsEngine.warning()
                // After the sheet has gone: an alert asked for while it is
                // still leaving is dropped.
                try? await Task.sleep(for: .milliseconds(450))
                stripProblem = CrewStripActivity.words(for: outcome)
            }
        }
    }

    /// What a send that did not go says: the same three answers a line gets.
    private func answer(_ outcome: SocialStore.ReplyOutcome) {
        switch outcome {
        case .sent, .throttled: break
        case .dailyLimit: atDailyLimit = true
        case .refusedSketch: stickerRefused = true
        case .refusedWords, .notAllowed: refused = true
        }
    }

    /// A plan, sent, and put in your own plan at once: you proposed it.
    ///
    /// **The day is the crew's** (found by review, 2026-10-12): the sheet
    /// counted from this phone's date, and a phone behind the crew's zone
    /// late at night sent "today" as the crew's yesterday.
    private func propose(_ title: String, _ choice: GroupPlanSheet.Choice) {
        let when: GroupPlan.When
        switch choice {
        case .weekdays(let days): when = .weekdays(days)
        case .inDays(let offset):
            guard let base = DateUtils.date(from: today),
                  let date = DateUtils.keyCalendar().date(byAdding: .day, value: offset, to: base) else { return }
            when = .day(DateUtils.dateString(from: date))
        }
        Task {
            let result = await store.sendPlan(title: title, when: when, in: crewID)
            answer(result.outcome)
            if let plan = result.plan {
                planDraft = ""
                plan.join(context: modelContext)
                planTick += 1
            }
        }
    }

    /// I'm In, and who has done it: the card's own logic, shared with the
    /// crew's screen (`GroupPlanActions`).
    private func join(_ plan: GroupPlan) {
        GroupPlanActions.join(plan, context: modelContext) { planTick += 1 }
    }

    private func done(_ plan: GroupPlan) -> (names: [String], canStrip: Bool) {
        GroupPlanActions.done(plan, today: today)
    }

    /// `pinned`: the card over the thread, which can be put away for the
    /// day. A plan's own line in the thread cannot.
    private func planCard(_ plan: GroupPlan, pinned: Bool) -> some View {
        let state = done(plan)
        // Read on every draw: the book is on this phone and is not observed.
        _ = planTick
        return GroupPlanCard(plan: plan, today: today, isIn: GroupPlanBook.isIn(plan), done: state.names,
                             canStrip: state.canStrip,
                             join: { join(plan) },
                             strip: { planStrip = plan },
                             close: !pinned ? nil : {
                                 GroupPlanBook.close(plan.bookKey, today: today)
                                 withAnimation(motion) { _ = closedPlans.insert(plan.bookKey) }
                             })
    }

    /// Over the thread: today's look back, and the plans you are in that are
    /// for today and whose own line is not in today's chat (a plan made
    /// yesterday for today: its line went at midnight, and yours did not).
    @ViewBuilder
    private func topCards(_ messages: [CrewMessage]) -> some View {
        let _ = planTick
        let inChat = Set(messages.compactMap { $0.groupPlan?.bookKey })
        let closed = closedPlans.union(GroupPlanBook.closed(today: today))
        let mine = GroupPlanBook.plans(in: crewID, on: today, me: store.me)
            .filter { !inChat.contains($0.bookKey) && !closed.contains($0.bookKey) }
        if lookBack != nil || !mine.isEmpty {
            VStack(spacing: GridConstants.gapTight) {
                if let found = lookBack {
                    TipCard(title: found.title,
                            message: "You sent this here.",
                            mark: "MarkPhoto",
                            actionTitle: "Send It Again",
                            action: { bringBack(found) },
                            close: {
                                CrewLookBack.answer(crewID, today: DateUtils.dateString(from: Date()))
                                withAnimation(motion) { lookBack = nil }
                            })
                }
                ForEach(mine) { plan in planCard(plan, pinned: true) }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, GridConstants.gapTight)
        }
    }

    /// A photograph of yours this crew saw, sent again with its line.
    private func bringBack(_ found: CrewLookBack.Found) {
        HapticsEngine.lightTap()
        Task {
            guard let data = await Task.detached(priority: .userInitiated, operation: { CrewLookBack.picture(found) }).value else {
                pictureRefused = true
                return
            }
            let outcome = await store.sendPicture(data, caption: found.title + ".", in: crewID)
            // A photo held back says so as a photo, not as a sticker.
            if outcome == .refusedSketch || outcome == .notAllowed { pictureRefused = true } else { answer(outcome) }
            if outcome == .sent {
                CrewLookBack.answer(crewID, today: DateUtils.dateString(from: Date()))
                withAnimation(motion) { lookBack = nil }
            }
        }
    }

    private func sendSticker(_ symbol: String) {
        guard let name = StickerStore.name(in: symbol), let png = StickerStore.shared.image(name)?.pngData() else { return }
        Task { answer(await store.sendSticker(png, in: crewID)) }
    }

    /// Your stickers, and the doodle pad above them. **The app's sheet
    /// layout** (`docs/ten.md` rule 3; the research, section 3, item 6): it
    /// had no title and no way out but a swipe. "Stickers" in the middle,
    /// Cancel on the left, and no right word: a tap on a sticker sends it.
    private var stickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                // A doodle is a line, not a reaction: only when sending.
                if stickerFor == nil {
                    BlockMenuRow("Doodle", "scribble") {
                        choosingSticker = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            doodling = true
                        }
                    }
                }
                // **Your head, as a sticker** (the chat research, 2026-10-15,
                // item 8: BeReal's RealMoji without the camera). One press
                // makes it from the head you have, once per head, and it
                // goes as any sticker does. Only where photos may be sent,
                // which is the only place this sheet is offered.
                if HeadStore.shared.headForCrews != nil, store.photosAllowed() {
                    BlockMenuRow("Your Head", "face.smiling") {
                        guard let name = HeadSticker.current() else { return }
                        let symbol = StickerStore.symbol(for: name)
                        choosingSticker = false
                        if let line = stickerFor {
                            stickerFor = nil
                            reactSticker(symbol, to: line)
                        } else {
                            sendSticker(symbol)
                        }
                    }
                }
                // A sticker just lifted stands chosen: one look, then a tap.
                StickerPicker(current: newSticker, purpose: .drawing, onPick: { symbol in
                    choosingSticker = false
                    newSticker = nil
                    if let line = stickerFor {
                        stickerFor = nil
                        reactSticker(symbol, to: line)
                    } else {
                        sendSticker(symbol)
                    }
                }, onNewSticker: {
                    // The photos once this sheet has gone (`StickerMaking`).
                    choosingSticker = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        makingSticker = true
                    }
                })
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapItem)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Stickers", drawn: false)
            .toolbar {
                // **Done, top right**, as every sheet where a press does the
                // thing (the consistency pass, 2026-10-15): a sticker sends
                // on its tap, so there is nothing here to cancel.
                BareToolbarItem(placement: .topBarTrailing) {
                    Button { choosingSticker = false } label: { Text("Done").sheetAction() }
                        .buttonStyle(.pressWord)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    // MARK: - Report and Block

    /// Hung on one point at the foot of the sheet, as the crew screen hangs
    /// its own: iOS 26 draws a dialog from the view it hangs on.
    private var dialogs: some View {
        Color.clear.frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .confirmationDialog("Report this message?",
                                isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                                titleVisibility: .visible, presenting: reporting) { message in
                ForEach(CrewSafety.Reason.allCases) { reason in
                    Button(reason.words) {
                        // What you report leaves your sight at once.
                        store.hide(winID: message.messageID)
                        Task {
                            await CrewSafety.report(.message(message), in: crewID, reason: reason)
                            reported = message.senderProfileID
                        }
                    }
                }
            } message: { _ in
                Text("Your report goes to Some Wins. Nobody in the crew is told.")
            }
            // A person, from their face: the words Crew Info's own Report says.
            .confirmationDialog(reportingPerson.map { "Report \(name(of: $0.profileID))?" } ?? "",
                                isPresented: Binding(get: { reportingPerson != nil }, set: { if !$0 { reportingPerson = nil } }),
                                titleVisibility: .visible, presenting: reportingPerson) { member in
                ForEach(CrewSafety.Reason.allCases) { reason in
                    Button(reason.words) {
                        Task {
                            await CrewSafety.report(.person(member), in: crewID, reason: reason)
                            reported = member.profileID
                        }
                    }
                }
            } message: { _ in
                Text("Their name, photo or head. Your report goes to Some Wins and nobody in the crew is told.")
            }
            .confirmationDialog(blockingPerson.map { "Block \(name(of: $0))?" } ?? "",
                                isPresented: Binding(get: { blockingPerson != nil }, set: { if !$0 { blockingPerson = nil } }),
                                titleVisibility: .visible, presenting: blockingPerson) { person in
                Button("Block", role: .destructive) {
                    Task { await CrewSafety.block(person, from: crewID) }
                }
                // In a crew someone else started they stay in it, and can
                // still see you there: leaving is offered in the same breath.
                if store.crew(crewID)?.isOwner(store.me) != true {
                    Button("Block and Leave", role: .destructive) {
                        Task { await CrewSafety.block(person, from: crewID, andLeave: true) }
                    }
                }
            } message: { _ in
                Text(store.crew(crewID)?.isOwner(store.me) == true
                     ? "You won't see their wins or words in any crew, and they leave this one. Some Wins hears about it. They are not told."
                     : "You won't see their wins or words in any crew. Some Wins hears about it. They are not told.")
            }
            // His thumbs up and the alert's words (`ReportThanks`): a card,
            // so it is the one thing here at the whole size, after the
            // dialogs that need to hang on the point.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .reportThanks($reported, message: "Every report is looked at within a day. Blocking hides them from you everywhere, and they are not told.") { person in
                store.blocked.contains(person) ? nil
                    : ("Block \(name(of: person))", { Task { await CrewSafety.block(person, from: crewID, reported: true) } })
            }
    }
}

/// The crew's name with "Today" under it in the principal slot, and Done.
/// Without the system's glass behind either, for the reason `DaySheet`'s
/// toolbar records: a glass word inside a glass capsule is two materials.
private struct ChatSheetToolbar: ToolbarContent {
    let name: String
    let done: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .principal) { title }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) { title }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        }
    }

    /// "Roommates / Today", one line in two tones (`TwoToneTitle`, the
    /// owner's pick, 2026-10-06). It was the name over a smaller "Today".
    private var title: some View {
        TwoToneTitle(title: "\(name)\(TwoToneTitle.separator)Today")
            .fitsLargeType(.body)
    }

    private var doneButton: some View {
        Button(action: done) {
            Text("Done").sheetAction()
        }
        .buttonStyle(.pressWord)
    }
}

/// The chat's title and Done, as the sheet's toolbar draws them, for the
/// drawer, which has no navigation bar: "Roommates / Today" in the middle,
/// Done on the right.
private struct ChatDrawerTitle: View {
    let name: String
    let done: () -> Void
    @Environment(\.chatDrawerFull) private var full

    var body: some View {
        ZStack {
            // **"Today", not the crew's name** (the owner, 2026-10-14: "in
            // the chat no need to put the name ... its already in the middle
            // header"): the crew's own screen names it right above. **At the
            // whole height the header is covered, and the name comes back**
            // (the same day: "go full screen and then the name appear").
            Text(full && !name.isEmpty ? name : "Today")
                .contentTransition(.opacity)
                .animation(GridConstants.crossFade, value: full)
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkSecondary)
                .fitsLargeType(.body)
                .padding(.horizontal, 72)
            HStack {
                Spacer(minLength: 0)
                Button(action: done) { Text("Done").sheetAction() }
                    .buttonStyle(.pressWord)
                    .frame(minWidth: GlassIconButton.defaultSide, minHeight: GlassIconButton.defaultSide)
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapTight)
    }
}

/// **Unsent words, per crew, for as long as the app is open** (the QoL
/// review, 2026-10-06). A chat's field and a win's Reply both lost their words
/// to anything that closed them; these hold them until a send goes through.
/// In memory on purpose: a draft is a sentence half written, not a record,
/// and a relaunch clearing it is what anyone would expect of a chat.
@MainActor
enum CrewDrafts {
    private static var chats: [CrewID: String] = [:]
    private struct ReplyKey: Hashable { let crew: CrewID; let win: UUID }
    private static var replies: [ReplyKey: String] = [:]

    static func chat(_ crew: CrewID) -> String { chats[crew] ?? "" }

    static func keepChat(_ text: String, for crew: CrewID) {
        chats[crew] = text.isEmpty ? nil : text
    }

    /// Only if the kept words are still the ones that were sent: anything
    /// typed while the send was in flight stays.
    static func clearChat(_ crew: CrewID, ifStill sent: String) {
        if chats[crew] == sent { chats[crew] = nil }
    }

    static func reply(_ crew: CrewID, to win: UUID) -> String {
        replies[ReplyKey(crew: crew, win: win)] ?? ""
    }

    static func keepReply(_ text: String, for crew: CrewID, to win: UUID) {
        replies[ReplyKey(crew: crew, win: win)] = text.isEmpty ? nil : text
    }

    static func clearReply(_ crew: CrewID, to win: UUID, ifStill sent: String) {
        let key = ReplyKey(crew: crew, win: win)
        if replies[key] == sent { replies[key] = nil }
    }
}

/// **Where the chat's lines stand on screen**, for which way a held line's
/// menu opens. A plain reference, not observed: lines move on every scroll,
/// and nothing should redraw for that.
@MainActor
final class ChatLineFrames {
    var mid: [UUID: CGFloat] = [:]
    var thread: CGRect = .zero
    /// How far the newest line is below the screen's foot (M7).
    var fromFoot: CGFloat = 0
}

/// The chat's own heights, when it is a sheet of its own.
private struct OwnChatDetents: ViewModifier {
    let on: Bool
    @Binding var detent: PresentationDetent

    func body(content: Content) -> some View {
        if on {
            content
                .presentationDetents([CrewChatSheet.drawerHeight, .large], selection: $detent)
                // The tower above stays the tower: a tap on it lands while the
                // chat is part way up, as Maps' card leaves the map.
                .presentationBackgroundInteraction(.enabled(upThrough: CrewChatSheet.drawerHeight))
                .presentationDragIndicator(.visible)
                .presentationBackground { WarmBackground().ignoresSafeArea() }
        } else {
            content
        }
    }
}

/// **The chat field's words, apart from the chat** (2026-10-15). Only what
/// reads `text` redraws as you type: the field, `ChatSendButton` and
/// `WhileFieldEmpty`. The thread never does.
@MainActor @Observable
final class ChatFieldText {
    var text: String
    init(_ text: String) { self.text = text }
    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Send, dimmed while there is nothing to send: its own view, so the
/// keystroke that wakes it wakes nothing else.
private struct ChatSendButton: View {
    let field: ChatFieldText
    let send: () -> Void

    var body: some View {
        GlassIconButton(systemName: "arrow.up", onPage: true, accessibilityLabel: "Send") { send() }
            .disabled(field.isEmpty)
    }
}

/// What shows only while the field is empty (the reply starters).
private struct WhileFieldEmpty<Content: View>: View {
    let field: ChatFieldText
    @ViewBuilder let content: () -> Content

    var body: some View {
        if field.text.isEmpty { content() }
    }
}

/// The field itself. A keystroke is the person's own edit, so it is the one
/// thing that writes the kept draft; `send` empties the field without
/// touching it, which is how the words survive a send that does not go.
/// 280 characters, the owner's number: the field stops there rather than
/// letting a long paste be cut on the way out.
private struct ChatTextInput: View {
    let field: ChatFieldText
    let crewID: CrewID
    var writing: FocusState<Bool>.Binding
    /// The field grew a line.
    var grew: () -> Void = {}

    var body: some View {
        // The hint in the resting bar's own ink, so the word does not change
        // colour as the chat rises (the consistency pass).
        TextField("Message", text: Binding(get: { field.text }, set: { typed in
            let kept = typed.count > CrewMessage.textLimit ? String(typed.prefix(CrewMessage.textLimit)) : typed
            field.text = kept
            CrewDrafts.keepChat(kept, for: crewID)
        }), prompt: Text(CrewChatWords.placeholder).foregroundStyle(AppColors.inkTertiary), axis: .vertical)
            .font(Typography.bodyLarge)
            .foregroundStyle(AppColors.inkPrimary)
            .lineLimit(1...5)
            .focused(writing)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { old, new in
                if new > old + 1 { grew() }
            }
    }
}

/// **The story a reply answers, small** (`SocialStore.storyAnswered`): its
/// photograph, or the block's colour, a story's shape, at the quote line's
/// head, as Instagram puts the story beside a reply in the conversation.
private struct StoryThumb: View {
    let win: SharedWin
    private static let size = CGSize(width: 30, height: 40)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusMark, style: .continuous)
        Group {
            if let photo = win.photo {
                CrewPhotoView(url: photo, width: Self.size.width, height: Self.size.height,
                              crop: CGPoint(x: win.cropX ?? 0, y: win.cropY ?? 0))
            } else {
                win.colour.style.baseColor
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(AppColors.quietFill, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
