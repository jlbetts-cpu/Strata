import SwiftData
import SwiftUI

/// **The plus in a crew's chat** (the owner's Launch Pack, 2026-10-12: "the
/// plus button as the gateway to richness in crew chat ... plans, wins,
/// photo strips, memories, and stickers, in an iMessage-style one tidy row
/// with the highest-value actions first ... clean single-focus glyphs, never
/// a busy grid"). The design he approved is `docs/crew-plus-design.md`.
///
/// One row, four things, each ending with one line in this chat
/// (`docs/chat-plus-research-2026-10-13.md`, section 3; the owner, 2026-10-13:
/// "the + button in the chat needs like real care done to it ... easy to use
/// and sleek and understandable", and "finish the recommended"). No drawer
/// behind it: four fit the smallest phone at 44 points each, and a drawer with
/// nothing in it is clutter. The doodle pad is inside Sticker.
///
/// **The row became a menu on 2026-10-15** (`ChatPlusMenu`); what it offers,
/// in what order and in what words, is still decided here.
enum ChatPlusRow {
    enum Choice: String, CaseIterable, Identifiable {
        case win, photo, plan, sticker, strip
        /// **Sticker's place for someone who may not send photos**: a
        /// sticker is lifted out of a photograph, so their row says what it
        /// opens, the doodle pad, rather than "Sticker" opening it.
        case doodle
        /// **Off the row** (the research's cut, the owner's "finish the
        /// recommended", 2026-10-13). The look back over the chat already
        /// brings the right photo back on the right day with Send It Again;
        /// the word was the Memories tab's and its own sheet said "Bring
        /// Back". The case and `CrewMemorySheet` stay, offered nowhere, for
        /// a later "From Earlier" inside Win.
        case memory
        var id: String { rawValue }

        /// **The row, in this order**: what you did, making plans, the quick
        /// reply, then the once-a-day thing (Sticker moved ahead of Strip:
        /// a sticker can go every day and a strip once).
        ///
        /// **Photo, second** (2026-10-15, the owner: "has all the components
        /// needed to be a successful chat"): every chat people use leads its
        /// + with a photo, and this one had no way to send one.
        static let offered: [Choice] = [.win, .photo, .plan, .sticker, .strip]
        /// Strip is photographs, and so is a sticker: not offered to
        /// someone who may not send one.
        static let withoutPhotos: [Choice] = [.win, .plan, .doodle]

        var word: String {
            switch self {
            case .win: "Win"
            case .photo: "Photo"
            case .plan: "Plan"
            case .sticker: "Sticker"
            case .strip: "Strip"
            case .doodle: "Doodle"
            case .memory: "Memory"
            }
        }

        /// System glyphs, as every tool in the app is; the sticker is the
        /// owner's own drawn one, as it is wherever stickers are. **Win is
        /// blocks stacked**, a tower: it was `plus.app`, a plus inside the
        /// plus menu, which reads as "more".
        var symbol: String {
            switch self {
            case .win: "square.stack.3d.up"
            case .photo: "photo"
            case .plan: "checklist"
            case .sticker: ""
            case .strip: "film"
            case .doodle: "scribble"
            case .memory: "clock.arrow.circlepath"
            }
        }

        /// What the menu says: what it does, in a few words.
        var menuWord: String {
            switch self {
            case .win: "Add a Win"
            case .photo: "Send a Photo"
            case .plan: "Make a Plan"
            case .sticker: "Send a Sticker"
            case .strip: "Send Today's Strip"
            case .doodle: "Draw a Doodle"
            case .memory: "Bring Back a Day"
            }
        }

        var spoken: String {
            switch self {
            case .win: "Add a win to this crew"
            case .photo: "Send a photo"
            case .plan: "Plan something with this crew"
            case .sticker: "Send a sticker or a doodle"
            case .strip: "Send today's photo strip"
            case .doodle: "Send a doodle"
            case .memory: "Bring back a day this crew saw"
            }
        }
    }
}

/// **The chat's +, as a menu** (the owner, 2026-10-15: "the pop up from the
/// + ... does not feel smooth ... the menus feel not very ux driven like they
/// are hard to understand"). The row of four slid in above the field, pushed
/// the thread up and shared the keys' room; iOS 26 Messages' + is a list of
/// what you can send, each with its word, opened in place. This is that: the
/// system's own menu from the + itself, nothing moves under it, and each
/// line says what it does. The same menu on the resting bar and in the chat.
struct ChatPlusMenu: View {
    var choices: [ChatPlusRow.Choice]
    let pick: (ChatPlusRow.Choice) -> Void

    var body: some View {
        PlusMenu {
            ForEach(choices) { choice in
                Button {
                    HapticsEngine.lightTap()
                    pick(choice)
                } label: {
                    if choice == .sticker {
                        // His drawn sticker, as on every sticker button.
                        Label { Text(choice.menuWord) } icon: { Image(Doodle.sticker.rawValue).renderingMode(.template) }
                    } else {
                        Label(choice.menuWord, systemImage: choice.symbol)
                    }
                }
            }
        }
        .accessibilityLabel("More to send")
    }
}

/// **The one + menu** (2026-10-15): the glass + at the foot of a bar, and
/// the system's menu from it, each line saying what it does. The chat's
/// (`ChatPlusMenu`) and the journal's are this, so the two cannot drift.
struct PlusMenu<Items: View>: View {
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu {
            items()
        } label: {
            Image(systemName: "plus")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .medium)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: GlassIconButton.defaultSide, height: GlassIconButton.defaultSide)
                .glassCircle(onPage: true)
                .contentShape(Circle())
        }
        // Top to bottom as written, wherever the menu opens.
        .menuOrder(.fixed)
    }
}

/// **Planning with a crew**: the words, and when, on the plan's own row of
/// days (`PlanScopeRow`) and its own weekday chips. Cancel on the left, Plan
/// on the right, as every plan is confirmed (`docs/ten.md`, rule 3).
struct GroupPlanSheet: View {
    /// When, counted from the crew's own day by whoever sends it.
    enum Choice: Equatable {
        case inDays(Int)
        case weekdays([Int])
    }

    let crewName: String
    /// The host's, so words a send refused are still here to change.
    @Binding var title: String
    /// Which crews, for a plan made from the Crews list (`CrewPicker`, Every
    /// crew among them: the owner, 2026-10-14, "there is no way to plan for
    /// multiple groups at the same time or all"); nil in a crew's own chat,
    /// where the crew is given.
    var crews: Binding<Set<CrewID>>? = nil
    let send: (String, Choice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scope: PlanScope = .day(0)
    @State private var days: Set<Int> = [Calendar.current.component(.weekday, from: Date())]
    @FocusState private var writing: Bool

    private var words: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The crew chosen in the row, as it changes; the given name otherwise.
    private var shownName: String {
        let store = SocialStore.shared
        guard let chosen = crews?.wrappedValue else { return crewName }
        if chosen.count > 1 {
            return chosen.count == store.crews.count ? "Every Crew" : "\(chosen.count) Crews"
        }
        return chosen.first.flatMap { store.crew($0)?.displayName(excluding: store.me) } ?? crewName
    }

    private var when: Choice? {
        switch scope {
        case .repeating: days.isEmpty ? nil : .weekdays(days.sorted())
        case .day(let offset): .inDays(offset)
        }
    }

    /// **Sent with the arrow, from a bar at the foot: your own plan's shape**
    /// (the owner, 2026-10-14: "the plan with crew and the plan needs to feel
    /// the same"; his pick "Same as my plan"). The field was a capsule at the
    /// top and a Plan word confirmed it. Now the days run along the top as
    /// they do on your plan, the chat's bar (`DayComposer`) is at the foot,
    /// Return sends, and Done closes.
    private func sendNow() {
        guard let when, !words.isEmpty, crews?.wrappedValue.isEmpty != true else { return }
        HapticsEngine.lightTap()
        send(words, when)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                if let crews {
                    CrewPicker(selection: crews)
                        .padding(.horizontal, GridConstants.horizontalPadding)
                }
                PlanScopeRow(scope: $scope)
                Spacer(minLength: 0)
                if scope == .repeating {
                    WeekdayChips(days: $days)
                        .padding(.horizontal, GridConstants.horizontalPadding)
                        .transition(.opacity)
                }
                DayComposer(canSend: !words.isEmpty && when != nil && crews?.wrappedValue.isEmpty != true,
                            onSend: sendNow) {
                    TextField(scope.prompt(), text: $title,
                              prompt: Text(scope.prompt()).foregroundStyle(AppColors.inkTertiary))
                        .focused($writing)
                        .submitLabel(.send)
                        .onSubmit(sendNow)
                        .onChange(of: title) { _, text in
                            if text.count > GroupPlan.titleLimit { title = String(text.prefix(GroupPlan.titleLimit)) }
                        }
                }
            }
            .padding(.top, GridConstants.gapItem)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Plan with \(shownName)", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("Done").sheetAction() }
                        .buttonStyle(.pressWord)
                }
            }
        }
        // **Your Plan's height** (the owner, 2026-10-15: "the plan and the
        // plan menu i notice is different one pops up more"; his pick "Full
        // height"). A short sheet floats as iOS's own glass card and flattens
        // the glass inside it: the send and repeat circles drew as bare
        // glyphs and the day bar sat flat, where your Plan's stand out. At
        // full height they are the same glass. The jitter of 2026-10-14 stays
        // fixed by the keyboard waiting for the sheet to land, below.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .animation(GridConstants.motionSnappy, value: scope == .repeating)
        // The keyboard after the sheet has landed, not during: both rising
        // at once was the jitter.
        .task {
            try? await Task.sleep(for: GridConstants.sheetLands)
            writing = true
        }
    }
}

/// **A group plan in the chat**, on the app's one card (`TipCard`): what,
/// when, who has done it today, and the one button.
///
/// **Only the people who did it are ever named.** There is no count, no
/// list of who is in, and nobody who has not is mentioned anywhere.
struct GroupPlanCard: View {
    let plan: GroupPlan
    let today: String
    /// Whether it is in your own plan already.
    let isIn: Bool
    /// The crew's people who sent a win of this name today, you first.
    let done: [String]
    /// Whether two or more of those wins have a photo: enough for a strip.
    let canStrip: Bool
    var join: () -> Void
    var strip: () -> Void
    /// Nil where the card is the plan's own line in the chat.
    var close: (() -> Void)? = nil

    var body: some View {
        TipCard(title: plan.title,
                message: Self.line(when: plan.whenWords(today: today), done: done),
                mark: "MarkChecklist",
                actionTitle: !isIn ? "I'm In" : canStrip ? "Make a Strip" : nil,
                action: !isIn ? join : canStrip ? strip : nil,
                close: close)
    }

    /// "Tomorrow", "Today. Rildy did it.", "Today. You and Sam did it."
    static func line(when: String, done: [String]) -> String {
        let day = when.prefix(1).uppercased() + when.dropFirst()
        guard !done.isEmpty else { return day }
        let who: String
        switch done.count {
        case 1: who = done[0]
        case 2: who = "\(done[0]) and \(done[1])"
        default: who = "\(done[0]), \(done[1]) and \(done.count - 2) more"
        }
        return "\(day). \(who) did it."
    }
}

/// What a plan's card needs to know and do, wherever it is drawn: the chat
/// and the crew's own screen.
@MainActor
enum GroupPlanActions {
    /// The people who sent this crew a win of the plan's name today, you
    /// first, and whether two of those wins have a photo.
    static func done(_ plan: GroupPlan, today: String, store: SocialStore = .shared) -> (names: [String], canStrip: Bool) {
        guard plan.isFor(today) else { return ([], false) }
        // By the name its win carries: a plan with a time is logged
        // without it ("Gym @ 6" is the win "Gym").
        let key = plan.proofKey
        // **Only what was done after it was planned** (found 2026-10-14: a
        // plan for "Gym at 6" read "Sam did it" the moment it was sent,
        // because Sam had logged "Gym" that morning). From the line's own
        // time while it is in today's chat; a plan proposed on an earlier
        // day counts all of today's.
        let sent = store.messages(in: plan.crewID).first { $0.messageID == plan.id }?.createdAt
        let wins = store.today(in: plan.crewID).filter { win in
            GroupPlan.key(win.title) == key && (sent.map { win.createdAt >= $0 } ?? true)
        }
        var senders: [UUID] = []
        for win in wins.sorted(by: { $0.createdAt < $1.createdAt }) where !senders.contains(win.senderProfileID) {
            senders.append(win.senderProfileID)
        }
        if let mine = senders.firstIndex(of: store.me) { senders.insert(senders.remove(at: mine), at: 0) }
        let crew = store.crew(plan.crewID)
        let names = senders.map { id -> String in
            if id == store.me { return "You" }
            let short = crew?.member(id)?.shortName ?? ""
            return short.isEmpty ? "A friend" : short
        }
        return (names, wins.filter { $0.photo != nil }.count >= 2)
    }

    /// **I'm In**: the plan goes in your own plan, and can be taken back.
    static func join(_ plan: GroupPlan, context: ModelContext, changed: @escaping () -> Void) {
        HapticsEngine.lightTap()
        guard let line = plan.join(context: context) else { return }
        changed()
        let id = line.id, key = plan.bookKey
        UndoLine.shared.show("In your plan", undo: {
            if let held = try? context.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == id })).first {
                context.delete(held)
                try? context.save()
            }
            GroupPlanBook.leave(key)
            changed()
        })
    }
}

/// **A crew's plan waiting for your answer, on the crew's own screen** (the
/// owner, 2026-10-13: "make sure the crew plan shows up on the crew page as
/// well"). The plans proposed in today's chat that you are not in, each
/// once, as the card the chat draws, with its I'm In. Two at most: the
/// screen is the tower's.
///
/// **A plan you are in is not a card here: it is a box on the crew's
/// tower** (the owner, the same day: "when you plan something in the crew
/// chat they should show up as a checkbox block in the crew tower ... if
/// the other person accepts it it also goes as a checkbox on their crew
/// tower"). `CrewPlannedLayer` draws it. So a card closed here closes a
/// proposal on this screen and nothing else: the plan's line stays in the
/// chat, where he found it gone ("why did it disappear from the chat when
/// I dismissed the notification, doesn't make sense").
struct CrewPlanCards: View {
    let crewID: CrewID
    /// Counted up by the host when something else may have changed the book
    /// (the chat closing): the book is on this phone and is not observed.
    var refresh = 0
    /// You are in one, or took that back: the tower's boxes are read again.
    var onChanged: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tick = 0
    @State private var closed: Set<String> = []
    @State private var strip: GroupPlan?
    @Environment(\.presentAside) private var presentAside

    private var store: SocialStore { SocialStore.shared }

    static let most = 2

    private static let closedHereKey = "crews.groupPlans.closedOnCrew"

    /// Proposals closed on the crew's screen today. Its own list, apart
    /// from the chat's (`GroupPlanBook.closed`): closing one here says
    /// nothing about the chat.
    static func closedHere(today: String, defaults: UserDefaults = .standard) -> Set<String> {
        guard let kept = defaults.dictionary(forKey: closedHereKey), kept["day"] as? String == today else { return [] }
        return Set(kept["keys"] as? [String] ?? [])
    }

    static func closeHere(_ bookKey: String, today: String, defaults: UserDefaults = .standard) {
        var keys = closedHere(today: today, defaults: defaults)
        keys.insert(bookKey)
        defaults.set(["day": today, "keys": keys.sorted()] as [String: Any], forKey: closedHereKey)
    }

    /// The plans proposed in today's chat that are waiting for you: each
    /// once, without the ones you are in (those are boxes on the tower) and
    /// the ones closed here.
    static func plans(proposed: [GroupPlan], joined: Set<String>, closed: Set<String>) -> [GroupPlan] {
        var seen: Set<String> = []
        return proposed.filter {
            !joined.contains($0.bookKey) && !closed.contains($0.bookKey) && seen.insert($0.bookKey).inserted
        }
    }

    var body: some View {
        let _ = (tick, refresh)
        let today = store.crew(crewID).map { CrewDay.string(for: store.now(), in: $0.timeZone) }
            ?? DateUtils.dateString(from: Date())
        let plans = Self.plans(proposed: store.messages(in: crewID).compactMap(\.groupPlan),
                               joined: Set(GroupPlanBook.all().keys),
                               closed: closed.union(Self.closedHere(today: today)))
        VStack(spacing: GridConstants.gapTight) {
            ForEach(plans.prefix(Self.most)) { plan in
                let state = GroupPlanActions.done(plan, today: today)
                GroupPlanCard(plan: plan, today: today, isIn: false, done: state.names,
                              canStrip: state.canStrip,
                              join: { GroupPlanActions.join(plan, context: modelContext) { tick += 1; onChanged() } },
                              strip: { presentAside { strip = plan } },
                              close: {
                                  Self.closeHere(plan.bookKey, today: today)
                                  withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                                      _ = closed.insert(plan.bookKey)
                                  }
                              })
                    .transition(.opacity)
            }
        }
        .task {
            GroupPlanBook.reconcile(context: modelContext)
            tick += 1
        }
        .fullScreenCover(item: $strip) { plan in
            StripBooth(owner: .crew(crewID.rawValue), day: today) {
                await PhotoStrip.crew(crewID, titled: plan.title)
            }
        }
    }
}

/// A picture in the chat, shown as it is: a sticker, or a photograph brought
/// back, with its line under it.
struct ChatPicture: View {
    let url: URL
    let caption: String
    let mine: Bool
    /// A sticker is its own cut-out shape; a photograph is rounded.
    var sticker = false

    static let side: CGFloat = 160

    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: GridConstants.spacing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: sticker ? 0 : GridConstants.radiusSurface, style: .continuous))
                } else {
                    // **A quiet fill at the picture's place while it loads**
                    // (the chat research, 2026-10-15, item 3): an empty
                    // frame drew nothing, then the thread moved when the
                    // picture landed in it.
                    RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                        .fill(AppColors.quietFill)
                        .frame(width: Self.side, height: Self.side)
                        // The app's own loader while it arrives (`WinsLoader`).
                        .overlay { WinsLoader(size: 24) }
                }
            }
            .frame(maxWidth: Self.side, maxHeight: Self.side * 4 / 3)
            if !caption.isEmpty {
                Text(caption)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .fitsLargeType(.subheadline)
            }
        }
        .task(id: url) {
            image = await Task.detached(priority: .userInitiated) { [url] in
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }
}

/// **A day this crew saw, brought back** (the Launch Pack, item 9: "On This
/// Day resurfacing. The app posts into crew chat like a thoughtful friend").
///
/// **Shown to you, and one tap sends it** (the owner's pick, 2026-10-12).
/// A crew's own records are gone after two weeks, so the only memory of what
/// it saw is on each person's phone: the wins they sent there. And the
/// people in a crew change. So nothing is posted by itself: on a day when
/// you sent this crew a photo a year, six months or a month ago, the chat
/// shows it to you, and Send It Again is yours to press.
///
/// The same ladder and the same words as the Memories card (`Flashback`).
nonisolated enum CrewLookBack {
    struct Found: Equatable, Sendable, Identifiable {
        var id: UUID { logID }
        let logID: UUID
        let fileName: String
        let day: String
        /// "A year ago today"
        let title: String
    }

    struct Candidate: Sendable {
        let id: UUID
        let day: String
        let fileName: String
    }

    /// The furthest back of today's dates on which you sent this crew a
    /// photo. `sent` is the wins that went to it.
    static func pick(_ candidates: [Candidate], sent: Set<UUID>, today: Date, calendar: Calendar) -> Found? {
        for rung in Flashback.rungs(today: today, calendar: calendar) {
            let that = candidates.filter { $0.day == rung.day && sent.contains($0.id) }.sorted { $0.fileName < $1.fileName }
            if let first = that.first {
                return Found(logID: first.id, fileName: first.fileName, day: rung.day, title: rung.title)
            }
        }
        return nil
    }

    private static func key(_ crew: CrewID) -> String { "crews.lookBack.answered.\(crew.rawValue)" }

    /// Sent or closed today: it is not offered again until another day.
    static func isAnswered(_ crew: CrewID, today: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: key(crew)) == today
    }

    static func answer(_ crew: CrewID, today: String, defaults: UserDefaults = .standard) {
        defaults.set(today, forKey: key(crew))
    }

    /// Today's look back for `crew`, from the store.
    @MainActor
    static func find(for crew: CrewID, context: ModelContext, store: SocialStore = .shared, now: Date = Date()) -> Found? {
        let calendar = DateUtils.keyCalendar()
        // Only for someone who may send a photograph at all.
        guard store.photosAllowed(), !isAnswered(crew, today: DateUtils.dateString(from: now)) else { return nil }
        let sent = store.winsSent(to: crew)
        guard !sent.isEmpty else { return nil }
        var candidates: [Candidate] = []
        for rung in Flashback.rungs(today: now, calendar: calendar) {
            let day = rung.day
            let logs = (try? context.fetch(FetchDescriptor<HabitLog>(
                predicate: #Predicate { $0.dateString == day && $0.completed }))) ?? []
            for log in logs {
                if let file = log.imageFileName { candidates.append(Candidate(id: log.id, day: day, fileName: file)) }
            }
        }
        return pick(candidates, sent: sent, today: now, calendar: calendar)
    }

    /// Every photographed win of yours this crew saw, newest first, for
    /// the plus row's Memory. One on a date the ladder reaches today wears
    /// that title; the rest wear their date.
    @MainActor
    static func all(for crew: CrewID, context: ModelContext, store: SocialStore = .shared, now: Date = Date(),
                    limit: Int = 60) -> [Found] {
        let sent = store.winsSent(to: crew)
        guard store.photosAllowed(), !sent.isEmpty else { return [] }
        let calendar = DateUtils.keyCalendar()
        let rungs = Dictionary(Flashback.rungs(today: now, calendar: calendar).map { ($0.day, $0.title) }, uniquingKeysWith: { a, _ in a })
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed && $0.imageFileName != nil }))) ?? []
        return logs.filter { sent.contains($0.id) }
            .sorted { ($0.dateString, $0.id.uuidString) > ($1.dateString, $1.id.uuidString) }
            .prefix(limit)
            .compactMap { log in
                guard let file = log.imageFileName else { return nil }
                return Found(logID: log.id, fileName: file, day: log.dateString,
                             title: rungs[log.dateString] ?? PastWin.dateWords(log.dateString, today: now, calendar: calendar))
            }
    }

    /// The photograph as it goes to a crew: no larger than a crew photo, and
    /// nothing of the original file's own data (`ShareDerivative`).
    static func picture(_ found: Found) -> Data? {
        let url = ImageManager.shared.imageDirectory.appendingPathComponent(found.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return ShareDerivative.jpeg(from: data)
    }
}

extension PhotoStrip {
    /// A crew's strip of one thing: today's photographed wins of that name,
    /// for a group plan two or more have done.
    @MainActor
    static func crew(_ crewID: CrewID, titled title: String, store: SocialStore = .shared) async -> PhotoStrip {
        let key = GroupPlan.key(PlanTime.title(title))
        var strip = await crew(crewID, store: store)
        let wanted = Set(store.today(in: crewID).filter { GroupPlan.key($0.title) == key }.map(\.winID))
        strip.candidates.removeAll { !wanted.contains($0.id) }
        return strip
    }
}

/// **The plus row's Strip: today's strip, shown, and Send sends it into
/// this chat** (the owner, 2026-10-13: "the strip, you can't even send it
/// to the chat. If there is a + button it should be able to be sent to the
/// chat"). It opened your booth, which develops only once the day's goal is
/// reached and sends from a share sheet two screens in: on most days the
/// button led nowhere.
///
/// The strip is what the booth would print: the frames you chose there, on
/// your paper, with what you drew on it. Shown first, since a chat line
/// cannot be taken back (`CrewMemorySheet` does the same).
struct CrewStripSendSheet: View {
    let send: (Data) -> Void
    /// **The empty page's one way forward** (the research, section 3, item
    /// 5): on a day with no photo it said "No photos today. Yet." over a
    /// greyed Send and only Cancel, a dead end two taps in. Add a Win goes
    /// where the row's Win goes. Nil leaves the page as it was.
    var addWin: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @State private var png: Data?
    @State private var picture: UIImage?
    @State private var looked = false

    static let empty = "No photos today. Yet."
    static let addWord = "Add a Win"

    /// Today's strip as the chat shows it, or nil on a day with no picture.
    @MainActor
    static func flat(context: ModelContext, scheme: ColorScheme) async -> Data? {
        let strip = await PhotoStrip.mine(context: context)
        let frames = strip.frames(excluding: StripKeeping.excluded(.me, day: strip.day))
        guard !frames.isEmpty else { return nil }
        return StripStory(strip: strip, frames: frames, day: strip.day, paper: StripKeeping.paper(for: scheme),
                          decor: StripDecor.picture(owner: .me, day: strip.day, frames: frames),
                          pose: StripStoryPose()).flatPNG()
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Group {
                    if let picture {
                        // At a strip's own width, as the booth holds it:
                        // stretched to the sheet it ran off both edges and
                        // went soft (looked at, 2026-10-13).
                        Image(uiImage: picture)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: StripStory.stripWidth)
                            .padding(.vertical, GridConstants.gapWide)
                            .accessibilityLabel("Today's photo strip")
                    } else if looked {
                        // The page's one sentence, as every empty page says
                        // its own, and the one thing that fills it.
                        VStack(spacing: GridConstants.gapWide) {
                            Text(Self.empty)
                                .font(Typography.headerMedium)
                                .foregroundStyle(AppColors.inkPrimary)
                                .multilineTextAlignment(.center)
                            if let addWin {
                                PrimaryCapsule(title: Self.addWord) {
                                    dismiss()
                                    addWin()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Today's Strip", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Text("Cancel").sheetAction(.cancel) }
                        .buttonStyle(.pressWord)
                }
                BareToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let png else { return }
                        send(png)
                        dismiss()
                    } label: { Text("Send").sheetAction(.confirm) }
                        .buttonStyle(.pressWord)
                        .disabled(png == nil)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .task {
            let data = await Self.flat(context: modelContext, scheme: scheme)
            png = data
            picture = data.flatMap(UIImage.init(data:))
            looked = true
        }
    }
}

/// **The plus row's Memory**: the photographs of yours this crew saw, to
/// bring one back. A tap sends it with its date under it.
struct CrewMemorySheet: View {
    let crewID: CrewID
    let send: (CrewLookBack.Found) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var items: [CrewLookBack.Found]?
    /// The one chosen. **Chosen, then sent** (found by review, 2026-10-12):
    /// a tap on a photo sent it to the crew at once, and a chat line cannot
    /// be taken back.
    @State private var chosen: CrewLookBack.Found?

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: GridConstants.gapTight), count: 3)

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let side = (geo.size.width - GridConstants.horizontalPadding * 2 - GridConstants.gapTight * 2) / 3
                ScrollView(.vertical, showsIndicators: false) {
                    if let items, items.isEmpty {
                        // The page's one sentence, as every empty page says its own.
                        Text("Nothing sent here with a photo. Yet.")
                            .font(Typography.headerMedium)
                            .foregroundStyle(AppColors.inkPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                            .padding(.horizontal, GridConstants.horizontalPadding)
                    } else {
                        LazyVGrid(columns: Self.columns, spacing: GridConstants.gapTight) {
                            ForEach(items ?? []) { item in
                                Button {
                                    HapticsEngine.tick()
                                    chosen = chosen == item ? nil : item
                                } label: {
                                    CachedImageView(fileName: item.fileName, width: side, height: side,
                                                    cornerRadius: GridConstants.radiusSurface)
                                        .opacity(chosen == nil || chosen == item ? 1 : 0.45)
                                        .overlay {
                                            if chosen == item {
                                                RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                                                    .strokeBorder(AppColors.inkPrimary, lineWidth: 3)
                                            }
                                        }
                                }
                                .buttonStyle(.pressSurface)
                                .accessibilityLabel(item.title)
                                .accessibilityAddTraits(chosen == item ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, GridConstants.horizontalPadding)
                        .padding(.vertical, GridConstants.gapItem)
                    }
                }
            }
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Bring Back", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Text("Cancel").sheetAction(.cancel) }
                        .buttonStyle(.pressWord)
                }
                BareToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let chosen else { return }
                        send(chosen)
                        dismiss()
                    } label: { Text("Send").sheetAction(.confirm) }
                        .buttonStyle(.pressWord)
                        .disabled(chosen == nil)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .task { items = CrewLookBack.all(for: crewID, context: modelContext) }
    }
}
