import SwiftData
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
    /// on every keystroke (`draftField`), so the words outlive the sheet.
    @State private var draft: String
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
    /// The plus row (`ChatPlusRow`), and what its five things open.
    @State private var showsPlus = false
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
    @State private var addingWin = false
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

    /// Opened by pressing the resting bar's field (`ChatRestBar`): the
    /// keyboard comes up with the thread.
    var startsWriting = false
    /// Opened by the resting bar's +: the plus row is already out.
    var startsWithPlus = false
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
        thread(messages, reactions: reactions, crew: crew)
            // Over the thread and above the message field (found by
            // review, 2026-10-13): hung on the whole sheet, "In your
            // plan · Undo" lay on the field for five seconds.
            .undoLine()
            .safeAreaInset(edge: .top, spacing: 0) { topCards(messages) }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            // Escape closes an open menu first, then the chat.
            .accessibilityAction(.escape) { if menuOn != nil { menuOn = nil } else { leave() } }
    }

    /// **In the drawer, its own title row and no navigation stack**: a
    /// stack inside the crew's own took the crew's navigation with it and
    /// left you on the list (walked, 2026-10-14). As a sheet, the stack's
    /// bar, as before.
    @ViewBuilder
    private func framed(_ page: some View, name: String) -> some View {
        if close != nil {
            VStack(spacing: 0) {
                ChatDrawerTitle(name: name, done: { leave() })
                page
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

    init(crewID: CrewID, startsWriting: Bool = false, startsWithPlus: Bool = false, visible: Bool = true,
         answeringWin: UUID? = nil,
         close: (() -> Void)? = nil,
         onOpenWin: @escaping (UUID) -> Void = { _ in }, onAddWin: @escaping () -> Void = {}) {
        self.crewID = crewID
        self.close = close
        self.startsWriting = startsWriting
        self.startsWithPlus = startsWithPlus
        self.visible = visible
        self.answeringWin = answeringWin
        self.onOpenWin = onOpenWin
        self.onAddWin = onAddWin
        _draft = State(initialValue: CrewDrafts.chat(crewID))
    }

    var body: some View {
        let crew = store.visible(crewID)
        // **A plan's line is a line of the chat, and stays in it** (the
        // owner, 2026-10-13: "why did it disappear from the chat when I
        // dismissed the notification, doesn't make sense"). Its card had a
        // close, and closing it, here or on the crew's screen, took the
        // line out of this chat for the day. Nothing takes it out now.
        let messages = store.messages(in: crewID)
        let reactions = store.messageReactions(in: crewID)
        framed(chatPage(messages, reactions: reactions, crew: crew),
               name: crew?.displayName(excluding: store.me) ?? "")
        .presentationDetents([Self.drawerHeight, .large], selection: $detent)
        // The tower above stays the tower: a tap on it lands while the chat
        // is part way up, as Maps' card leaves the map.
        .presentationBackgroundInteraction(.enabled(upThrough: Self.drawerHeight))
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        // Open is seen: the dot goes, and the hour's held alert with it. And
        // again as lines arrive while it is open, from the crew screen's
        // live sync underneath (`refreshLive`, every 3 seconds).
        .onAppear {
            guard visible else { return }
            store.markChatSeen(crewID)
            if startsWriting { writing = true }
            if startsWithPlus { showsPlus = true }
        }
        .onChange(of: messages.map(\.messageID)) { _, _ in if visible { store.markChatSeen(crewID) } }
        // Up: seen, and the plus row or the keyboard as it was asked for,
        // the keyboard only once the drawer has landed (both rising at once
        // was a jolt). Down: the keyboard and the row put away.
        .onChange(of: visible) { _, up in
            if up {
                store.markChatSeen(crewID)
                showsPlus = startsWithPlus
                if let answeringWin { replyingTo = nil; replyingToWin = answeringWin }
                guard startsWriting else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(360))
                    if visible { writing = true }
                }
            } else {
                writing = false
                showsPlus = false
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
        // Writing folds the plus row, which stands where the keyboard is
        // about to.
        .onChange(of: writing) { _, now in
            if now, showsPlus { withAnimation(GridConstants.motionSnappy) { showsPlus = false } }
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
            GroupPlanBook.reconcile(context: modelContext)
            planTick += 1
            lookBack = CrewLookBack.find(for: crewID, context: modelContext)
        }
        .sheet(isPresented: $planning) {
            GroupPlanSheet(crewName: store.crew(crewID)?.displayName(excluding: store.me) ?? "Your Crew",
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
        .sheet(isPresented: $addingWin) {
            AddWinSheet(modelContext: modelContext, tower: activeTower, initialCrews: [crewID],
                        onSaved: { habit in sayWin(habit) })
        }
        .sheet(isPresented: $doodling) {
            DoodleSheet(owner: store.crew(crewID)?.displayName(excluding: store.me) ?? "") { drawing in
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
            CrewStripSendSheet(send: { png in sendStrip(png) }, addWin: { afterSheet { addingWin = true } })
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
                                Text("Quiet here. Yet.")
                                    .font(Typography.headerMedium)
                                    .foregroundStyle(AppColors.inkPrimary)
                                clearsLine(crew)
                            }
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        } else {
                            LazyVStack(spacing: GridConstants.spacing) {
                                // The same line where a full thread stops.
                                clearsLine(crew)
                                    .padding(.bottom, GridConstants.gapItem)
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                    row(message, after: index > 0 ? messages[index - 1] : nil,
                                        reactions: reactions[message.messageID] ?? [], crew: crew)
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
                .scrollDismissesKeyboard(.interactively)
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
                } else {
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
                    if !mine, opensRun {
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
        let face = bubbleFace(message, mine: mine, quote: quote?.title ?? answered?.words)
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
        .simultaneousGesture(LongPressGesture(minimumDuration: Self.holdToReact).onEnded { _ in
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
                Button("Report") { reporting = message }
                Button("Block \(name(of: message.senderProfileID))") { blockingPerson = message.senderProfileID }
            }
        }
    }

    /// "Today's chat clears at midnight.", or at this phone's time for the
    /// crew's midnight when the two differ (M6). Quiet, in the app only.
    private func clearsLine(_ crew: Crew?) -> some View {
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
        ChatReactionBar(mine: store.myReaction(toMessage: id, in: crewID),
                        stickersAllowed: store.photosAllowed(),
                        pick: { emoji in
                            BlockMenuAfter.run(closing: close) { react(.emoji(emoji), to: id) }
                        },
                        stickers: {
                            BlockMenuAfter.run(closing: close) {
                                stickerFor = id
                                choosingSticker = true
                            }
                        })
            .padding(.horizontal, GridConstants.horizontalPadding - ReactionBar.inset - GridConstants.gapTight)
            .padding(.bottom, GridConstants.gapTight)
        Divider()
        BlockMenuRow("Reply", "arrowshape.turn.up.left") {
            BlockMenuAfter.run(closing: close) { reply(to: message) }
        }
        let hearted = isHearted(id)
        BlockMenuRow(hearted ? "Remove Heart" : "Heart", hearted ? "heart.slash" : "heart") {
            BlockMenuAfter.run(closing: close) { heart(message) }
        }
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
            BlockMenuRow("Report", "exclamationmark.bubble", destructive: true) {
                BlockMenuAfter.run(closing: close) { reporting = message }
            }
        }
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
        store.myReaction(toMessage: id, in: crewID)?.emoji == Reaction.doubleTap
    }

    /// **Heart** gives ❤️, or takes yours back if it is already the heart;
    /// another mark of yours becomes the heart. Taking it back tells nobody.
    private func heart(_ message: CrewMessage) {
        react(.emoji(Reaction.doubleTap), to: message.messageID)
    }

    private func react(_ pick: Reaction.Pick, to id: UUID) {
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
        withAnimation(GridConstants.motionSnappy) {
            replyingTo = message
            showsPlus = false
        }
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
        if line.isPicture { return line.caption == SocialStore.stickerWord || line.caption.isEmpty ? "a sticker" : line.caption }
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
            ChatPicture(url: picture, caption: message.caption == SocialStore.stickerWord ? "" : message.caption, mine: mine)
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
        let ink = mine ? WarmBackground.top : AppColors.inkPrimary
        // The quote steps down a rung on a friend's line (`inkTertiary`); on
        // yours it keeps the page's colour, since no ink token inverts onto
        // ink, and the arrow and the smaller size already make it the quote.
        let quoteInk = mine ? WarmBackground.top : AppColors.inkTertiary
        // A win said in the chat with no photo: its title, once, behind the
        // quote's mark. Drawn as a reply it read "↪ Gym / Gym".
        let saysWin = quote != nil && store.isWinLine(message)
        return VStack(alignment: .leading, spacing: GridConstants.spacing) {
            if let quote, !saysWin {
                // U+FE0E: the arrow as type, never the emoji tile it draws as bare.
                Text("\u{21AA}\u{FE0E} \(quote)")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(quoteInk)
                    .lineLimit(1)
                    .fitsLargeType(.subheadline)
            }
            if let sketch = message.sketch {
                InkImage(url: sketch, tint: mine ? ink : AppColors.drawingInk)
                    .frame(maxWidth: Self.doodleSide, maxHeight: Self.doodleSide * 3 / 4)
            }
            if !message.text.isEmpty {
                Text(saysWin ? "\u{21AA}\u{FE0E} \(message.text)" : message.text)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, GridConstants.gapLabel)
        .padding(.vertical, GridConstants.gapItem)
        .background {
            RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                .fill(mine ? AppColors.inkPrimary : AppColors.quietFill)
        }
        .contentShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
    }

    /// The win a line quotes, by its title, while it is still in the crew and
    /// still yours to see. A win taken back leaves the line with no quote.
    private func quoted(_ message: CrewMessage) -> (title: String, winID: UUID)? {
        guard let id = message.quoteWinID,
              let win = store.wins(in: crewID).first(where: { $0.winID == id }),
              store.wins(in: crewID, on: win.crewDay).contains(where: { $0.winID == id }) else { return nil }
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
            parts.append(message.caption == SocialStore.stickerWord || message.caption.isEmpty ? "a sticker" : "a photo, \(message.caption)")
            return parts.joined(separator: ", ")
        }
        if message.sketch != nil { parts.append("a doodle") }
        if !message.text.isEmpty { parts.append(message.text) }
        return parts.joined(separator: ", ")
    }

    // MARK: - The field

    @ViewBuilder
    private var composer: some View {
        if store.canReply() {
          VStack(spacing: 0) {
            if showsPlus {
                // Strip and a sticker are photographs: not offered to
                // someone who may not send one. Their third is Doodle.
                ChatPlusRow(choices: store.photosAllowed() ? ChatPlusRow.Choice.offered : ChatPlusRow.Choice.withoutPhotos) { choice in
                    choose(choice)
                }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let replyingTo {
                replyQuote(replyingTo)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let replyingToWin, let win = store.wins(in: crewID).first(where: { $0.winID == replyingToWin }) {
                quoteRow("\u{21AA}\u{FE0E} \(win.title)") {
                    withAnimation(GridConstants.motionSnappy) { self.replyingToWin = nil }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
                GlassIconButton(systemName: showsPlus ? "xmark" : "plus", onPage: true,
                                accessibilityLabel: showsPlus ? "Close" : "More to send") {
                    writing = false
                    withAnimation(GridConstants.motionSnappy) { showsPlus.toggle() }
                }
                TextField("Message", text: draftField, axis: .vertical)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1...5)
                    .focused($writing)
                    .padding(.horizontal, GridConstants.gapLabel)
                    .padding(.vertical, GridConstants.gapTight)
                    .frame(minHeight: GlassIconButton.defaultSide)
                    // A box as it grows, never a capsule: see `glassField`.
                    .glassField()
                    .accessibilityLabel("Message")
                GlassIconButton(systemName: "arrow.up", onPage: true, accessibilityLabel: "Send") { send() }
                    .disabled(isEmpty)
            }
            .padding(.horizontal, hPad)
            .padding(.top, GridConstants.gapTight)
            // Low, where the system's own bars sit (`GridConstants.barSink`).
            .modifier(BarSink())
            // 280 characters, the owner's number: the field stops there
            // rather than letting a long paste be cut on the way out.
            .onChange(of: draft) { _, text in
                guard text.count > CrewMessage.textLimit else { return }
                draft = String(text.prefix(CrewMessage.textLimit))
                CrewDrafts.keepChat(draft, for: crewID)
            }
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

    private var isEmpty: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The field's binding: a keystroke is the person's own edit, so it is
    /// the one thing that writes the kept draft. `send` empties the field
    /// without touching it, which is how the words survive a send that does
    /// not go.
    private var draftField: Binding<String> {
        Binding(get: { draft }, set: { draft = $0; CrewDrafts.keepChat($0, for: crewID) })
    }

    /// **A draft is cleared by a send that went, and by nothing else** (the
    /// QoL review, 2026-10-06). It lived in this sheet's `@State`, so a swipe
    /// down, a tap on a quoted win (which closes the sheet to open it) or a
    /// sheet closed while a refused send was coming back each lost what you
    /// had written. The field still empties at once, as Messages does; the
    /// kept copy goes only on `.sent`, and only if nothing new was typed
    /// since.
    private func send() {
        let text = draft
        guard !isEmpty else { return }
        draft = ""
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
                if draft.isEmpty { draft = CrewDrafts.chat(crewID) }
            case .dailyLimit:
                if draft.isEmpty { draft = CrewDrafts.chat(crewID) }
                atDailyLimit = true
            case .refusedWords, .refusedSketch, .notAllowed:
                // Refused words come back to the field, to be changed.
                if draft.isEmpty { draft = CrewDrafts.chat(crewID) }
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
        withAnimation(GridConstants.motionSnappy) { showsPlus = false }
        switch choice {
        // Over the chat, which stays open: the win lands here as a line.
        case .win: addingWin = true
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
                BareToolbarItem(placement: .topBarLeading) {
                    Button { choosingSticker = false } label: { Text("Cancel").sheetAction(.cancel) }
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
            .alert("Thanks for telling us",
                   isPresented: Binding(get: { reported != nil }, set: { if !$0 { reported = nil } }),
                   presenting: reported) { person in
                if !store.blocked.contains(person) {
                    Button("Block \(name(of: person))", role: .destructive) {
                        Task { await CrewSafety.block(person, from: crewID) }
                    }
                }
                Button("Done", role: .cancel) {}
            } message: { _ in
                Text("Every report is looked at within a day. Blocking hides them from you everywhere, and they are not told.")
            }
            .confirmationDialog(blockingPerson.map { "Block \(name(of: $0))?" } ?? "",
                                isPresented: Binding(get: { blockingPerson != nil }, set: { if !$0 { blockingPerson = nil } }),
                                titleVisibility: .visible, presenting: blockingPerson) { person in
                Button("Block", role: .destructive) {
                    Task { await CrewSafety.block(person, from: crewID) }
                }
            } message: { _ in
                Text(store.crew(crewID)?.isOwner(store.me) == true
                     ? "You won't see their wins or words in any crew, and they leave this one. They are not told."
                     : "You won't see their wins or words in any crew. They are not told.")
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

    var body: some View {
        ZStack {
            // **"Today", not the crew's name** (the owner, 2026-10-14: "in
            // the chat no need to put the name ... its already in the middle
            // header"): the crew's own screen names it right above.
            Text("Today")
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
