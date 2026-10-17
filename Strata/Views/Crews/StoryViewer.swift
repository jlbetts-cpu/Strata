import ImageIO
import SwiftUI

/// **Tonight's Story, watched** (the spec, 1.4 and 3; the plan, R9 to R11).
///
/// **As Snapchat and Instagram show a story, and as this app's camera is
/// framed** (the owner, 2026-10-16: "the story is most of the screen like it
/// is on the camera, light bottom black top, with the head in the corner with
/// the name and the bar up top"). One win a page as a card most of the screen
/// tall under the camera's black band, with the segments, their head and
/// their name over the top of the picture; under it, on the page, the
/// block's own label and the tower's reactions, with Reply into the crew's
/// chat. A hold pauses, a tap on the right goes on and on the left goes back,
/// a swipe across goes to the next friend and a swipe down closes.
///
/// **Never shown:** who watched, how many, a time, a count of stories.
struct StoryViewer: View {
    let people: [StoryPerson]
    let start: UUID
    let onClose: () -> Void

    @State private var current: UUID?
    @State private var drop: CGFloat = 0
    /// **The night's opening, once a night** (the owner, 2026-10-16: "it
    /// should feel like opening presents on Christmas ... like a Spotify
    /// Wrapped"): a title card before the first friend, their rings closing
    /// one by one, then a tap opens it. Held while it shows.
    @AppStorage("crews.storyOpenedNight") private var openedNight = ""
    @State private var opening = false
    /// **Edit, from your own story** (the owner, 2026-10-16): the viewer
    /// closes and Tonight's Story opens where the row opens it. Presented from
    /// inside the viewer it came up and went at once (filmed, 2026-10-16),
    /// so it is the row's own sheet, the one that works.
    var onEdit: (() -> Void)? = nil
    /// A friend's head or name tapped in their story: their profile, the
    /// row's own sheet, as Edit is (the audit, 2026-10-16: "a story's head
    /// and name should open their profile", as a face in the chat does).
    var onProfile: ((CrewMember, CrewID) -> Void)? = nil
    /// The page after everyone: "That's everyone tonight."
    private static let endID = UUID(uuidString: "00000000-0000-0000-0000-00000000E0D0")!
    /// Whether this is friends' stories (an end card) or only your own.
    private var hasEnd: Bool { people.contains { $0.profileID != store.me } }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shown: UUID { current ?? start }
    private var store: SocialStore { SocialStore.shared }

    /// **The people as they stand now**, not as they stood when it opened
    /// (the review, 2026-10-15): someone blocked or hidden here drops out,
    /// and a story past its window goes, whatever was tapped. Yours stays.
    private var live: [StoryPerson] {
        let now = StoryClock.now(store.now())
        return people.compactMap { person in
            if person.profileID == store.me { return person }
            guard !store.blocked.contains(person.profileID) else { return nil }
            let stories = person.stories.filter {
                store.storiesHidden[person.profileID] != $0.day
                    && StoryClock.phase(of: $0, at: now, in: .current) == .open
            }
            return stories.isEmpty ? nil
                : StoryPerson(profileID: person.profileID, stories: stories, phase: .open, watched: person.watched)
        }
    }

    var body: some View {
        let people = live
        TabView(selection: Binding(get: { shown }, set: { current = $0 })) {
            ForEach(people) { person in
                StoryPage(person: person, isCurrent: shown == person.id && !opening, dragging: drop > 0,
                          upNext: upNext(after: person.id),
                          edit: { onEdit?() },
                          profile: onProfile,
                          next: { step(from: person.id, by: 1) },
                          back: { step(from: person.id, by: -1) },
                          close: onClose)
                    .tag(person.id)
            }
            // **A finish line** (Instagram's "You're all caught up", 2018):
            // the evening is finite, and this says it is done.
            if hasEnd {
                // **The end asks for yours** when you have not posted (the
                // audit, 2026-10-16: seeing and sharing go together).
                StoryEnd(close: onClose,
                         addStory: store.myStory.isEmpty && store.canReply() ? onEdit : nil)
                    .tag(Self.endID)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // **The keyboard never squeezes the picture** (the stories standard,
        // rule 2): the pages ignore it, and each lifts its own reply over it.
        .ignoresSafeArea(.keyboard)
        // **Black above, the page below**, as the camera stands (its
        // `CameraCard`): the band runs from the top of the screen down behind
        // the card's top corners.
        .background(alignment: .top) {
            GeometryReader { geo in
                Color.black
                    .frame(height: geo.safeAreaInsets.top + GridConstants.radiusSurface)
                    .offset(y: -geo.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
        }
        // **Black all round, as the camera is** (the owner, 2026-10-16: "for
        // the story I think the bottom should be black like it is in the
        // camera"): the reply bar and the end page in their dark appearance.
        .background { Color.black.ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .offset(y: drop)
        .scaleEffect(1 - min(drop, 400) / 4000, anchor: .top)
        // **Down to close**, as Photos and every story closes (`OneWayPan`:
        // it refuses to begin unless the finger is going down, so a swipe
        // across still goes to the next friend).
        .gesture(OneWayPan(way: .down, changed: { drop = $0 }, ended: { distance, speed in
            if distance > 120 || speed > 900 {
                onClose()
            } else {
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { drop = 0 }
            }
        }))
        .statusBarHidden()
        .overlay {
            if opening {
                StoryOpening(people: people.filter { $0.profileID != store.me }, close: onClose) {
                    openedNight = Self.night(of: people) ?? ""
                    withAnimation(reduceMotion ? GridConstants.crossFade : .smooth(duration: 0.4)) { opening = false }
                }
                // Dark, as the story it opens is.
                .environment(\.colorScheme, .dark)
                .transition(.opacity)
            }
        }
        .onAppear {
            #if DEBUG
            if DebugHarness.argument("-strataReplayOpening") != nil { openedNight = "" }
            #endif
            if hasEnd, let night = Self.night(of: people), openedNight != night { opening = true }
        }
        // Nobody left to show (all blocked, hidden or past 9am): close.
        .onChange(of: people.isEmpty) { _, empty in if empty { onClose() } }
        .onChange(of: people.map(\.id)) { _, ids in
            if shown != Self.endID, !ids.contains(shown), let first = ids.first { current = first }
        }
    }

    /// The next friend's first page not yet watched, if it is a photograph:
    /// decoded while this friend plays (rule 7).
    private func upNext(after id: UUID) -> URL? {
        let people = live
        guard let i = people.firstIndex(where: { $0.id == id }), people.indices.contains(i + 1) else { return nil }
        let next = people[i + 1]
        let story = next.stories.first { !store.storiesSeen.contains($0.id) } ?? next.stories.first
        return story?.win.photo
    }

    /// The night these stories belong to.
    static func night(of people: [StoryPerson]) -> String? {
        people.first { $0.profileID != SocialStore.shared.me }?.stories.first?.day
    }

    /// The next friend, or the one before; past the last, the viewer closes.
    private func step(from id: UUID, by offset: Int) {
        let people = live
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        if people.indices.contains(j) {
            withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { current = people[j].id }
        } else if offset > 0 {
            if hasEnd {
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { current = Self.endID }
            } else {
                onClose()
            }
        }
    }
}

/// One friend's stories, a page at a time.
private struct StoryPage: View {
    let person: StoryPerson
    let isCurrent: Bool
    /// Being dragged down to close: the story waits.
    var dragging = false
    /// The next friend's first photograph, decoded ahead.
    var upNext: URL? = nil
    /// Opens Tonight's Story over your own story, to change it.
    var edit: () -> Void = {}
    var profile: ((CrewMember, CrewID) -> Void)? = nil
    let next: () -> Void
    let back: () -> Void
    let close: () -> Void

    @State private var page = 0
    /// **A finger on the picture, until it lifts** (the stories standard,
    /// rule 1). It was `onLongPressGesture`'s pressing, which ends when the
    /// hold is recognised, a quarter of a second in: an 8 second hold moved
    /// the story on (measured, 2026-10-17). `TouchHeld` ends when the
    /// finger lifts, and on a cancel, so it never sticks.
    @State private var touching = false
    /// Held past a tap: the bar, the name and the reply step aside so the
    /// picture is alone (rule 3; b: WhatsApp and Instagram on a hold).
    @State private var holding = false
    /// The "..." menu is open: the story waits (rule 1).
    @State private var menuOpen = false
    /// The keyboard's height, from the bottom of the screen, and the page's
    /// own bottom inset: the reply rides the keyboard while the picture
    /// stays where it is (rule 2).
    @State private var keyboard: CGFloat = 0
    @State private var bottomInset: CGFloat = 0
    /// The reply row's own height, kept under the picture so the picture's
    /// size never changes with what the row is doing.
    @State private var footRoom: CGFloat = 60
    /// **The picture is on screen** (rule 6): a photograph's page waits for
    /// it, up to `StoryTiming.photoWait`, so its time is not spent on a
    /// blank. The page's id when it arrived.
    @State private var drawn: UUID?
    @State private var waitedOut: UUID?
    @State private var cardSize: CGSize = .zero
    @Environment(\.displayScale) private var displayScale
    /// The reaction bar, Reply, a doodle or a sticker is open: the story waits.
    @State private var busy = false
    @State private var reporting: SharedWin?
    @State private var blocking = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorScheme) private var scheme

    private var store: SocialStore { SocialStore.shared }
    private var mine: Bool { person.profileID == store.me }
    /// **High, low, buffalo, a page of its own** (the owner, 2026-10-16:
    /// "should the high, low and buffalo be its own story slide, in the middle
    /// of the photographs"): between the first photographs and the rest.
    private var wordsIndex: Int? { person.hasWords ? (person.stories.count + 1) / 2 : nil }
    private var pageCount: Int { person.stories.count + (wordsIndex == nil ? 0 : 1) }
    private var isWords: Bool { page == wordsIndex }
    /// The story a page shows, or (the words page) the one before it, which a
    /// reply from there is about.
    private func storyIndex(_ page: Int) -> Int {
        guard let w = wordsIndex else { return page }
        return page >= w ? max(page - 1, 0) : page
    }
    private func pageOf(_ storyIndex: Int) -> Int {
        guard let w = wordsIndex else { return storyIndex }
        return storyIndex >= w ? storyIndex + 1 : storyIndex
    }
    private var story: CrewStory { person.stories[min(storyIndex(page), person.stories.count - 1)] }
    /// What each page is, by its mark for "seen": a story's id, or the
    /// words page's own (`StoryPerson.wordsKey`).
    private var keys: [UUID] {
        (0..<pageCount).map { p in
            p == wordsIndex ? (person.wordsKey ?? UUID()) : person.stories[min(storyIndex(p), person.stories.count - 1)].id
        }
    }
    /// The page on screen, by what it is, so a page arriving or a picture's
    /// check landing mid-story never moves you off it (the review,
    /// 2026-10-16).
    @State private var showing: UUID?
    private let hPad = GridConstants.horizontalPadding

    /// How long this page stands before the next (`StoryTiming`).
    private var pageLength: TimeInterval {
        isWords ? StoryTiming.words([person.line, person.low, person.buffalo]) : StoryTiming.photo
    }

    /// A photograph's page whose picture is not on screen yet.
    private var waitingForPicture: Bool {
        guard !isWords, story.win.photo != nil, let key = showing else { return false }
        return drawn != key && waitedOut != key
    }

    private var paused: Bool {
        touching || busy || menuOpen || waitingForPicture || dragging || !isCurrent || scenePhase != .active || reporting != nil || blocking || voiceOver
    }

    private var member: CrewMember? {
        store.crew(story.win.crewID)?.member(person.profileID)
    }

    private var name: String {
        if mine { return "Your Story" }
        let short = member?.shortName ?? ""
        return short.isEmpty ? "A friend" : short
    }

    var body: some View {
        VStack(spacing: 0) {
            card
                .overlay(alignment: .top) { top.stepsAside(holding) }
                .overlay(alignment: .bottomLeading) { label.stepsAside(holding) }
                // Answering, the story dims and waits under the reply
                // (b: Instagram's reply).
                .overlay {
                    RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                        .fill(Color.black.opacity(busy ? 0.42 : 0))
                        .allowsHitTesting(false)
                }
            Color.clear.frame(height: footRoom)
        }
        .overlay(alignment: .bottom) {
            foot
                // As the camera card's controls: past this the + and the
                // heart outgrew their glass and the field cut its words.
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .padding(.horizontal, hPad)
                .padding(.top, GridConstants.gapTight)
                .padding(.bottom, GridConstants.gapTight)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                    // Measured at rest only: the reactions over the field
                    // while writing grow up over the dimmed picture.
                    if keyboard == 0, !busy { footRoom = height }
                }
                .offset(y: -max(0, keyboard - bottomInset))
                .stepsAside(holding)
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.safeAreaInsets.bottom }) { bottomInset = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard isCurrent, let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screen = UIScreen.main.bounds.height
            let height = max(0, screen - end.minY)
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(GridConstants.keyboardRide(duration)) { keyboard = height }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(GridConstants.keyboardRide(duration)) { keyboard = 0 }
        }
        .onChange(of: touching) { _, now in
            if !now { withAnimation(GridConstants.crossFade) { holding = false } }
        }
        .task(id: touching) {
            guard touching else { return }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled, touching else { return }
            withAnimation(GridConstants.crossFade) { holding = true }
        }
        .overlay(alignment: .bottom) { CrewReportAnchor(reporting: $reporting, crewID: story.win.crewID) }
        .confirmationDialog("Block \(name)?", isPresented: $blocking, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                let (who, crew) = (person.profileID, story.win.crewID)
                Task { await CrewSafety.block(who, from: crew) }
                next()
            }
        } message: {
            Text("They're hidden from you everywhere, and they are not told.")
        }
        #if DEBUG
        // The held look, for a screenshot: a test cannot shoot while it holds.
        .onAppear { if DebugHarness.argument("-strataStoryHeld") != nil { holding = true } }
        #endif
        // Back to the first page not yet watched, as a story resumes.
        .onChange(of: isCurrent, initial: true) { _, now in
            busy = false
            touching = false
            guard now else { return }
            // The first page not yet watched, the words page among them.
            page = keys.firstIndex { !store.storiesSeen.contains($0) } ?? 0
            showing = (keys.indices.contains(page) ? keys[page] : nil)
            seen()
        }
        .onChange(of: page) {
            busy = false
            showing = (keys.indices.contains(page) ? keys[page] : nil)
            seen()
        }
        // A picture that does not come still lets the page go on, and the
        // next ones are decoded while this one stands (rules 6 and 7).
        .task(id: "\(showing?.uuidString ?? "")-\(isCurrent)") {
            guard isCurrent, let key = showing else { return }
            await prefetchAhead()
            try? await Task.sleep(for: .seconds(StoryTiming.photoWait))
            guard !Task.isCancelled else { return }
            waitedOut = key
        }
        .onChange(of: keys) { _, now in
            guard let showing, let at = now.firstIndex(of: showing) else {
                page = min(page, max(now.count - 1, 0))
                return
            }
            if at != page { page = at }
        }
    }

    /// This friend's next photograph and the next friend's first, at the
    /// card's size, into `CrewPhotoView`'s cache.
    private func prefetchAhead() async {
        guard cardSize.width >= 1 else { return }
        var urls: [URL] = []
        let after = storyIndex(page) + 1
        if person.stories.indices.contains(after), let url = person.stories[after].win.photo { urls.append(url) }
        if let upNext { urls.append(upNext) }
        for url in urls {
            await CrewPhotoView.prefetch(url, width: cardSize.width, height: cardSize.height, scale: displayScale)
        }
    }

    /// Yours too (the launch pass, 3½: "including your own"): watched to
    /// the end, your ring goes quiet until something new is on it.
    private func seen() {
        guard isCurrent else { return }
        if isWords, let key = person.wordsKey { store.markStorySeen(key) } else { store.markStorySeen(story.id) }
    }

    private func forward() {
        if page + 1 < pageCount { page += 1 } else { next() }
    }

    private func backward() {
        if page > 0 { page -= 1 } else { back() }
    }

    // MARK: The top

    /// Over the top of the picture, in white, on a short shade of the
    /// picture itself so the words read on a bright sky.
    private var top: some View {
        VStack(spacing: GridConstants.gapTight) {
            StoryProgress(count: pageCount, index: page, paused: paused,
                          length: pageLength, finished: forward)
                .id("\(person.id)-\(page)-\(isCurrent)")
                .padding(.top, GridConstants.gapTight)
            HStack(spacing: GridConstants.gapTight) {
                Button {
                    guard !mine, let member else { return }
                    HapticsEngine.lightTap()
                    profile?(member, story.win.crewID)
                } label: {
                    HStack(spacing: GridConstants.gapTight) {
                        Group {
                            if mine {
                                PersonHead(person: .me, side: 32)
                            } else if let member {
                                PersonHead(person: .member(member, crew: story.win.crewID, me: store.me), side: 32)
                            }
                        }
                        .accessibilityHidden(true)
                        Text(name)
                            .font(Typography.headerSmall)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .disabled(mine || profile == nil)
                .accessibilityHint(mine ? "" : "Opens their profile.")
                Spacer(minLength: 0)
                // The same glass circles as the bar at the foot, the chat's +
                // and every viewer's close (the owner, 2026-10-16: "the
                // reactions and buttons should feel the same").
                actions
                StoryGlyph(systemName: "xmark", tint: .white, label: "Close story", action: close)
            }
            // **The camera's cap** (the camera card's controls, 2026-10-17):
            // at the largest sizes the ... and the close ran into each other.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .padding(.horizontal, GridConstants.gapItem)
        .padding(.bottom, GridConstants.gapWide)
        .background {
            // A shade of the picture, not a surface: it is drawn into the
            // card and goes with it, so white words read on a bright sky.
            LinearGradient(colors: [.black.opacity(0.38), .clear], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: GridConstants.radiusSurface,
                                          topTrailingRadius: GridConstants.radiusSurface, style: .continuous))
    }

    private var actions: some View {
        Menu {
            Group {
            if mine {
                Button { edit() } label: {
                    Label("Edit Tonight's Story", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    let id = story.id
                    Task { await store.withdrawStory(winID: id) }
                    if person.stories.count == 1 { close() } else { forward() }
                } label: {
                    Label("Take Off Story", systemImage: "minus.circle")
                }
                // One tap to Instagram's story, once the App ID is set
                // (`InstagramShare`).
                if InstagramShare.isReady {
                    Button {
                        let (photo, line) = (story.win.photo, person.line)
                        Task {
                            let picture = photo.flatMap { $0.isFileURL ? UIImage(contentsOfFile: $0.path) : nil }
                            if let card = InstagramShare.card(picture: picture, line: line) {
                                await InstagramShare.share(card)
                            }
                        }
                    } label: {
                        Label("Share to Instagram", systemImage: "square.and.arrow.up")
                    }
                }
            } else {
                Button {
                    store.hideStory(of: person.profileID, day: story.day)
                    next()
                } label: {
                    Label("Hide Their Story", systemImage: "eye.slash")
                }
                Button(role: .destructive) { reporting = isWords ? wordsReported : story.win } label: {
                    Label("Report", systemImage: "exclamationmark.bubble")
                }
                Button(role: .destructive) { blocking = true } label: {
                    Label("Block", systemImage: "hand.raised")
                }
            }
            }
            // **Open, the story waits** (rule 1): the menu's own items
            // appear while it shows and go when it closes, chosen or not.
            .onAppear { menuOpen = true }
            .onDisappear { menuOpen = false }
        } label: {
            StoryGlyph.label("ellipsis", tint: .white)
        }
        .accessibilityLabel("Story actions")
    }

    /// **The words page, reportable** (the review, 2026-10-16): as a win the
    /// report already knows how to carry, its title their three lines and
    /// its picture the page's drawing, so no new kind of report is needed.
    private var wordsReported: SharedWin {
        var win = story.win
        let lines = [person.line.map { "\(StoryLine.high): \($0)" }, person.low.map { "\(StoryLine.low): \($0)" },
                     person.buffalo.map { "\(StoryLine.buffalo): \($0)" }].compactMap { $0 }
        win.title = "Story page. " + lines.joined(separator: " / ")
        win.photo = person.wordsArt
        return win
    }

    // MARK: The picture

    private var card: some View {
        GeometryReader { geo in
            // The camera's own card (`CameraView`'s `radiusSurface`).
            let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
            Group {
                if isWords {
                    StoryWordsPage(high: person.line, low: person.low, buffalo: person.buffalo,
                                   hasPicture: person.wordsPicture != nil) { size in
                        if let url = person.wordsPicture {
                            CrewPhotoView(url: url, width: size.width, height: size.height, crop: .zero)
                        }
                    } art: { _ in
                        if let art = person.wordsArt {
                            StoryArtImage(url: art)
                        }
                    }
                } else if let url = story.win.photo {
                    let key = story.id
                    // The words page's own dark while it arrives, never the
                    // block's colour: no flash of colour before a photograph.
                    ZStack {
                        Color(white: 0.09)
                        CrewPhotoView(url: url, width: geo.size.width, height: geo.size.height,
                                      crop: CGPoint(x: story.win.cropX ?? 0, y: story.win.cropY ?? 0),
                                      shown: { drawn = key })
                    }
                } else {
                    // A doodle, a plain block, or anyone under 16: the block.
                    ZStack {
                        story.win.colour.style.baseColor
                        if let icon = story.win.icon.iconName {
                            Image(systemName: icon)
                                .font(.system(size: min(geo.size.width, geo.size.height) * 0.22, weight: .medium))
                                .foregroundStyle(story.win.colour.style.text)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(shape)
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { cardSize = $0 }
            .id(isWords ? "words" : story.id.uuidString)
            .transition(.opacity)
            // **Tap on, tap back, hold to pause.** The left third goes back,
            // as every story does; the rest goes on.
            .contentShape(shape)
            .gesture(TouchHeld(changed: { touching = $0 }) { point in
                HapticsEngine.tick()
                if point.x < geo.size.width / 3 { backward() } else { forward() }
            })
        }
        .animation(GridConstants.crossFade, value: page)
        .accessibilityElement()
        .accessibilityLabel(spoken)
        .accessibilityHint("Swipe up or down for the next or the one before.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: forward()
            case .decrement: backward()
            @unknown default: break
            }
        }
    }

    private var spoken: String {
        var parts = ["\(mine ? "Your story" : "\(name)'s story"), \(page + 1) of \(pageCount)"]
        if isWords {
            for (name, text) in [(StoryLine.high, person.line), (StoryLine.low, person.low), (StoryLine.buffalo, person.buffalo)] {
                if let text { parts.append("\(name): \(text)") }
            }
            return parts.joined(separator: ", ")
        }
        if !story.win.title.isEmpty { parts.append(story.win.title) }
        parts.append(story.win.photo == nil ? "a block" : "a photo")
        return parts.joined(separator: ", ")
    }

    // MARK: The label and the reactions

    /// **The win's name, on the picture's foot**, in white on a short shade
    /// of it, as the name sits at its top. Nothing else (the owner,
    /// 2026-10-16: no colour dot, "the dot showing the category color isn't
    /// relevant", and no size, "the deep, quick isn't important for the
    /// story, that's personal").
    /// **Their line opens the story** (2026-10-16): on the first page, the
    /// best part of today in their words; after it, each win's own name.
    private var caption: String? {
        // The words have their own page now; a photograph says its win.
        if isWords { return nil }
        return story.win.title.isEmpty ? nil : story.win.title
    }

    @ViewBuilder
    private var label: some View {
        if let caption {
            labelText(caption)
        }
    }

    private func labelText(_ caption: String) -> some View {
        HStack {
            Text(caption)
                .font(Typography.headerMedium)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, GridConstants.gapWide)
        .padding(.top, GridConstants.gapWide * 2)
        .padding(.bottom, GridConstants.gapWide)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.38)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: GridConstants.radiusSurface,
                                          bottomTrailingRadius: GridConstants.radiusSurface, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The tower's reactions, on this story's own crew copy: the bar, Reply
    /// and Doodle into the crew's chat, and who reacted. **On your own, who
    /// reacted in every crew it went to** (the review: one crew's copy left
    /// out a friend who is only in another), as your block on Wins shows.
    @ViewBuilder
    private var foot: some View {
        if mine {
            // **Edit, from the story itself** (the owner, 2026-10-16: "why is
            // there no option to edit tonight's story from the story itself").
            // Tonight's Story opens over it: the wins, the three lines and
            // your page; what changes shows here as soon as it is posted.
            HStack(spacing: GridConstants.gapTight) {
                Button {
                    HapticsEngine.lightTap()
                    edit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.onDarkStrong)
                        .padding(.horizontal, GridConstants.gapLabel)
                        .frame(minHeight: 44)
                        .glassCapsule(carriesType: true)
                        .contentShape(Capsule())
                }
                // Plain, as the reaction panel's face is: a scaling press on
                // interactive glass cancelled the tap (2026-10-05).
                .buttonStyle(.plain)
                .accessibilityLabel("Edit Tonight's Story")
                MyStoryReactions(reactions: store.reactionsToMyWins()[story.id] ?? [])
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        } else if store.canReply() {
            StoryReplyBar(story: story, name: name, busy: { busy = $0 })
                .id(story.id)
        }
    }
}

private extension View {
    /// Held, a story's chrome is gone in every way: unseen, untouchable and
    /// unspoken, so nothing invisible can be tapped over the picture.
    func stepsAside(_ aside: Bool) -> some View {
        opacity(aside ? 0 : 1)
            .allowsHitTesting(!aside)
            .accessibilityHidden(aside)
    }
}

/// **The segments**: one a page, the ones before it full, this one filling
/// over `length` seconds while not paused. Its own view with its own clock,
/// so only the bar redraws as it fills, never the page.
private struct StoryProgress: View {
    let count: Int
    let index: Int
    let paused: Bool
    let length: TimeInterval
    /// White over a photograph; ink over the opening's page.
    var ink: Color = .white
    let finished: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var last: Date?
    @State private var done = false

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    GeometryReader { geo in
                        Capsule().fill(ink.opacity(0.25))
                            .overlay(alignment: .leading) {
                                Capsule().fill(ink)
                                    .frame(width: geo.size.width * fill(i))
                            }
                    }
                }
            }
            .frame(height: 3)
            .onChange(of: context.date) { _, now in tick(now) }
        }
        .onChange(of: paused) { last = nil }
        .accessibilityHidden(true)
    }

    private func fill(_ i: Int) -> CGFloat {
        i < index ? 1 : i > index ? 0 : CGFloat(min(1, elapsed / length))
    }

    private func tick(_ now: Date) {
        guard !paused, !done else { last = nil; return }
        if let last { elapsed += min(0.1, now.timeIntervalSince(last)) }
        last = now
        if elapsed >= length {
            done = true
            finished()
        }
    }
}

/// Who reacted to your story, across every crew it went to: their emoji and
/// their names, read only. Nothing about who opened it, ever.
private struct MyStoryReactions: View {
    let reactions: [Reaction]

    var body: some View {
        if !reactions.isEmpty {
            let ordered = reactions.sorted { $0.createdAt < $1.createdAt }
            var emoji: [String] = []
            let _ = ordered.forEach { if !emoji.contains($0.emoji) { emoji.append($0.emoji) } }
            let names = ordered.map { CrewReactionsPanel.name($0.profileID, crewID: $0.crewID) }
            let words = names.count > 3
                ? "\(names.prefix(2).joined(separator: ", ")) and \(names.count - 2) others"
                : names.formatted(.list(type: .and))
            HStack(spacing: 8) {
                HStack(spacing: -4) {
                    ForEach(Array(emoji.prefix(3).enumerated()), id: \.offset) { index, e in
                        Text(e).font(Typography.headerMedium).zIndex(Double(3 - index))
                    }
                }
                Text(words)
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .glassCapsule(onPage: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reactions: " + zip(names, ordered).map { "\($0) \($1.emoji)" }.joined(separator: ", "))
        }
    }
}

/// **The foot of a friend's story: the crew chat's own composer** (the owner,
/// 2026-10-16: "the bottom should be kind of like the crew chats with the
/// message and plus button and it saying reply"). The chat's +, its glass
/// field and its send arrow, one row. A tap on the field brings the quick
/// reactions up over it, as Instagram's story reply does, and the story
/// waits while you answer. What is sent goes to `SocialStore.replyToStory`.
private struct StoryReplyBar: View {
    let story: CrewStory
    let name: String
    let busy: (Bool) -> Void

    @State private var text = ""
    @FocusState private var writing: Bool
    @State private var doodling = false
    @State private var choosingSticker = false
    @State private var makingSticker = false
    /// The + menu is open (the stories standard, rule 1): it moved the story
    /// two pages on while it was open, into the next friend (measured,
    /// 2026-10-17).
    @State private var plusOpen = false
    /// "Sent", for a moment, where the words were.
    @State private var said: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var store: SocialStore { SocialStore.shared }
    private var motion: Animation { reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy }
    private var open: Bool { writing || doodling || choosingSticker || makingSticker || plusOpen }

    var body: some View {
        HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
                PlusMenu {
                    Group {
                        if store.photosAllowed() {
                            Button { choosingSticker = true } label: { Label("Send a Sticker", systemImage: "face.smiling") }
                        }
                        Button { doodling = true } label: { Label("Send a Doodle", systemImage: "scribble") }
                    }
                    .onAppear { plusOpen = true }
                    .onDisappear { plusOpen = false }
                }
                TextField("Reply", text: $text,
                          prompt: Text(said ?? "Reply to \(name)").foregroundStyle(AppColors.inkTertiary), axis: .vertical)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1...4)
                    .focused($writing)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, GridConstants.gapLabel)
                    .padding(.vertical, GridConstants.gapTight)
                    .frame(minHeight: GlassIconButton.defaultSide)
                    .glassField()
                    .accessibilityLabel("Reply to \(name)")
                // **A heart in one tap** (the audit, 2026-10-16, after
                // Instagram's story like and Strava's kudos): cheering a
                // friend's day cost a tap into the field and the keyboard.
                // The arrow takes its place once there are words to send.
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let liked = store.myReaction(to: story.id, in: story.win.crewID) == Reaction.doubleTap
                    GlassIconButton(systemName: liked ? "heart.fill" : "heart", onPage: true,
                                    accessibilityLabel: liked ? "Liked" : "Like") {
                        guard !liked else { return }
                        HapticsEngine.success()
                        Task { await store.reactToStory(Reaction.doubleTap, story: story) }
                        done("Sent")
                    }
                    .contentTransition(.symbolEffect(.replace))
                } else {
                    GlassIconButton(systemName: "arrow.up", onPage: true, accessibilityLabel: "Send", action: send)
                }
        }
        // **Over the row, never in it** (the stories standard, rule 2): the
        // reactions came in above the field and grew the row by 52pt before
        // the story knew you were writing, and the picture shrank by as much.
        .overlay(alignment: .top) {
            if writing {
                ReactionBar(mine: store.myReaction(to: story.id, in: story.win.crewID)) { emoji in
                    Task { await store.reactToStory(emoji, story: story) }
                    done("Sent")
                }
                .fixedSize()
                // A frame of no height at the row's top, the bar standing on
                // it: it rises above the row and takes none of its room.
                .frame(height: 0, alignment: .bottom)
                .offset(y: -GridConstants.gapTight)
                .transition(.opacity)
            }
        }
        .animation(motion, value: writing)
        .onChange(of: open) { _, now in busy(now) }
        .onDisappear { busy(false) }
        .sheet(isPresented: $choosingSticker) {
            StickerPicker(current: nil, purpose: .drawing, onPick: { symbol in
                choosingSticker = false
                guard let png = StickerStore.name(in: symbol).flatMap({ StickerStore.shared.image($0)?.pngData() }) else { return }
                Task { _ = await store.react(sticker: png, to: story.id, in: story.win.crewID) }
                done("Sent")
            }, onNewSticker: {
                choosingSticker = false
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    makingSticker = true
                }
            })
            .padding(GridConstants.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground { WarmBackground().ignoresSafeArea() }
        }
        .stickerMaking(isPresented: $makingSticker) { symbol in
            guard let png = StickerStore.name(in: symbol).flatMap({ StickerStore.shared.image($0)?.pngData() }) else { return }
            Task { _ = await store.react(sticker: png, to: story.id, in: story.win.crewID) }
            done("Sent")
        }
        .sheet(isPresented: $doodling) {
            DoodleSheet(owner: name) { drawing in
                guard let png = InkExport.doodlePNG(drawing) else { return }
                Task {
                    let (outcome, to) = await store.doodleToStory(png, story: story)
                    done(outcome == .sent ? "Sent to \(to)" : "Didn't send. Try again.")
                }
            }
        }
    }

    private func send() {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        HapticsEngine.lightTap()
        text = ""
        Task {
            let (outcome, to) = await store.replyToStory(words, story: story)
            if outcome != .sent { text = words }
            // **Where it went, every time** (the owner, 2026-10-16: "they
            // should know").
            done(outcome == .sent ? "Sent to \(to)" : outcome == .refusedWords ? "Try other words" : "Didn't send. Try again.")
        }
    }

    /// Says what happened in the field's own place, for a moment, and lets
    /// the story go on.
    private func done(_ words: String) {
        writing = false
        withAnimation(motion) { said = words }
        Task {
            // Long enough to be read by someone looking at the picture, not
            // the field (the stories standard, rule 5).
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(motion) { said = nil }
        }
    }
}

/// **The end of tonight's stories**: one line, and a tap anywhere closes it.
/// No count, no list of who posted, nothing more to see.
private struct StoryEnd: View {
    let close: () -> Void
    var addStory: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: GridConstants.gapSection) {
            Spacer()
            // His drawn check, the mark a reached goal wears (`RingMoment`).
            Image("MarkCheck")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Text("That's everyone tonight.")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
            if let addStory {
                Button {
                    HapticsEngine.lightTap()
                    addStory()
                } label: {
                    Label("Add Your Story", systemImage: "plus")
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.inkPrimary)
                        .padding(.horizontal, GridConstants.gapLabel)
                        .frame(minHeight: 44)
                        .glassCapsule(carriesType: true)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { WarmBackground().ignoresSafeArea() }
        // **A tap closes it, as a story's last page does** (the owner,
        // 2026-10-16: "doesn't need a done button, just make it like the
        // story and tap to close").
        .contentShape(Rectangle())
        .onTapGesture(perform: close)
        .accessibilityElement(children: addStory == nil ? .combine : .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Closes the stories.")
        .accessibilityAction(.escape, close)
    }
}

/// **The night's opening, a story page of its own** (2026-10-16; the owner,
/// of the first version with its Open button: "what is the point of this
/// having a button, lay it out like a story with the bar on top, and the
/// animation should involve their heads, all bouncing around").
///
/// Framed as every page is, the bar at the top filling, and when it is full
/// the first friend's story follows with nothing to press; a tap goes on at
/// once. On the card, everyone who shared tonight drops in one after
/// another, lands with a little squash and a tap under the finger, and keeps
/// hopping, each to its own time, their names under them. A ritual you are
/// in makes what follows better (Vohs et al. 2013); this one asks nothing of
/// you but to watch it start.
private struct StoryOpening: View {
    let people: [StoryPerson]
    let close: () -> Void
    let begin: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = 0
    private var store: SocialStore { SocialStore.shared }
    private let hPad = GridConstants.horizontalPadding
    /// **Any number of friends** (the owner, 2026-10-16: "make sure the head
    /// works with a lot of people"): up to three a row at full size, then
    /// four and five a row, smaller, and past fifteen the rest as a count.
    /// Live heads up to six; quieter ones beyond, so a big night stays smooth.
    private static let most = 15
    private var columns: Int { people.count <= 3 ? max(people.count, 1) : people.count <= 8 ? 4 : 5 }
    private var side: CGFloat {
        let room: CGFloat = 340
        let fit = (room - CGFloat(columns - 1) * GridConstants.gapWide) / CGFloat(columns)
        return min(88, fit)
    }
    private var shownCount: Int { people.count > Self.most ? Self.most - 1 : people.count }
    /// How long the page stands before the first story.
    static let length: TimeInterval = 3.8

    var body: some View {
        VStack(spacing: 0) {
            card
            Text(people.count == 1 ? "1 friend shared the best of today" : "\(people.count) friends shared the best of today")
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, hPad)
                .padding(.vertical, GridConstants.gapTight)
        }
        .background(alignment: .top) {
            GeometryReader { geo in
                Color.black
                    .frame(height: geo.safeAreaInsets.top + GridConstants.radiusSurface)
                    .offset(y: -geo.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
        }
        .background { Color.black.ignoresSafeArea() }
        .task {
            for i in 0..<shownCount {
                // Quicker the more there are, so fifteen land in about two seconds.
                try? await Task.sleep(for: .milliseconds(i == 0 ? 250 : (shownCount > 6 ? 110 : 180)))
                withAnimation(reduceMotion ? GridConstants.crossFade : .spring(duration: 0.55, bounce: 0.45)) { landed = i + 1 }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: landed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tonight. \(people.count == 1 ? "1 friend" : "\(people.count) friends") shared the best of today.")
        .accessibilityAction(named: "Begin") { begin() }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
        return ZStack {
            // Opaque: the camera's black band runs behind the card's top.
            shape.fill(WarmBackground.top)
            shape.fill(AppColors.quietFill)
            VStack(spacing: GridConstants.gapSection) {
                VStack(spacing: GridConstants.gapTight) {
                    Text(weekday + " night")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                    Text("Tonight")
                        .font(Typography.screenTitle)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                // Room for a hop above the heads, so no head ever reaches the
                // words (the owner: "I don't like how the head is interacting
                // with the text, like overlapping").
                heads
                    .padding(.top, side * BouncingHead<EmptyView>.hop)
            }
            .padding(.horizontal, hPad)
        }
        .overlay(alignment: .top) { top }
        .contentShape(shape)
        .onTapGesture { begin() }
    }

    /// The bar, then a close, as a page's top is.
    private var top: some View {
        VStack(spacing: GridConstants.gapTight) {
            StoryProgress(count: 1, index: 0, paused: false, length: Self.length, ink: AppColors.inkPrimary, finished: begin)
                .padding(.top, GridConstants.gapTight)
            HStack {
                Spacer(minLength: 0)
                StoryGlyph(systemName: "xmark", tint: AppColors.inkSecondary, label: "Close story", action: close)
            }
        }
        .padding(.horizontal, GridConstants.gapItem)
    }

    /// Rows of `columns`, the last row centred, and a count for the rest.
    private var heads: some View {
        let shown = Array(people.prefix(shownCount).enumerated())
        let rest = people.count - shownCount
        let rows = stride(from: 0, to: shown.count, by: columns).map { Array(shown[$0..<min($0 + columns, shown.count)]) }
        return VStack(spacing: side < 70 ? GridConstants.gapItem : GridConstants.gapWide) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(alignment: .top, spacing: GridConstants.gapWide) {
                    ForEach(rows[r], id: \.element.id) { index, person in
                        BouncingHead(person: person, side: side, index: index, landed: index < landed,
                                     still: reduceMotion || !alive(person), name: name(person)) { head(person, live: index < 6) }
                    }
                    if r == rows.count - 1, rest > 0 {
                        Text(verbatim: "+\(rest)")
                            .font(Typography.headerMedium)
                            .foregroundStyle(AppColors.inkSecondary)
                            .frame(width: side, height: side)
                            .background(Circle().fill(AppColors.quietFill))
                            .opacity(landed >= shownCount ? 1 : 0)
                            .accessibilityLabel("and \(rest) more")
                    }
                }
            }
        }
    }

    /// The stories' own night, not the clock's: after midnight it is still
    /// the evening they were from.
    private var weekday: String {
        let date = people.first?.stories.first.flatMap { DateUtils.date(from: $0.day) } ?? Date()
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func name(_ person: StoryPerson) -> String {
        guard let crew = person.stories.first?.win.crewID,
              let member = store.crew(crew)?.member(person.profileID) else { return "A friend" }
        return member.shortName.isEmpty ? "A friend" : member.shortName
    }

    /// Only a drawn head hops; a photograph stays put (`HeadIdentity.isAlive`).
    private func alive(_ person: StoryPerson) -> Bool {
        guard let crew = person.stories.first?.win.crewID,
              let member = store.crew(crew)?.member(person.profileID) else { return false }
        return HeadIdentity.isAlive(.member(member, crew: crew, me: store.me))
    }

    @ViewBuilder
    private func head(_ person: StoryPerson, live: Bool) -> some View {
        let crew = person.stories.first?.win.crewID
        if let crew, let member = store.crew(crew)?.member(person.profileID) {
            PersonHead(person: .member(member, crew: crew, me: store.me), side: side,
                       life: live ? .expressive : .calm, setting: .free)
        } else {
            Circle().fill(AppColors.inkTertiary.opacity(0.3)).frame(width: side, height: side)
        }
    }
}

/// **A head that dropped in and keeps hopping**: from above the card on a
/// bouncy spring, then a hop of its own every second or so, squashing as it
/// lands, each head to a slightly different time so they never march. Its
/// name stays put underneath.
private struct BouncingHead<Head: View>: View {
    let person: StoryPerson
    let side: CGFloat
    let index: Int
    let landed: Bool
    let still: Bool
    let name: String
    @ViewBuilder let head: () -> Head

    private struct Hop { var y: CGFloat = 0; var squash: CGFloat = 1 }
    /// How high a hop goes, as a share of the head.
    static var hop: CGFloat { 0.24 }

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            head()
                .frame(width: side, height: side)
                .keyframeAnimator(initialValue: Hop(), repeating: !still && landed) { content, hop in
                    content
                        .scaleEffect(x: 2 - hop.squash, y: hop.squash, anchor: .bottom)
                        .offset(y: hop.y)
                } keyframes: { _ in
                    // A rest of its own first, so no two heads hop together.
                    let rest = 0.35 + Double((index * 37) % 7) * 0.09
                    KeyframeTrack(\.y) {
                        LinearKeyframe(0, duration: rest)
                        SpringKeyframe(-side * Self.hop, duration: 0.24, spring: .snappy)
                        CubicKeyframe(0, duration: 0.2)
                        SpringKeyframe(-side * 0.08, duration: 0.14, spring: .snappy)
                        CubicKeyframe(0, duration: 0.12)
                    }
                    KeyframeTrack(\.squash) {
                        LinearKeyframe(1, duration: rest)
                        CubicKeyframe(0.9, duration: 0.06)
                        CubicKeyframe(1.06, duration: 0.18)
                        CubicKeyframe(1, duration: 0.2)
                        CubicKeyframe(0.92, duration: 0.05)
                        CubicKeyframe(1, duration: 0.21)
                    }
                }
                // In where it stands, popping up from small: nothing falls
                // past the words above.
                .scaleEffect(landed || still ? 1 : 0.2, anchor: .bottom)
                .opacity(landed ? 1 : 0)
            Text(name)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .lineLimit(1)
                .frame(maxWidth: side + GridConstants.gapWide)
                .opacity(landed ? 1 : 0)
        }
    }
}

/// **A story's own buttons: the glyph alone** (the owner, 2026-10-16: "the x
/// button is too noticeable"). Glass circles on a story drew a bright disc,
/// and its shadow, over the photograph; every story app since Snapchat's
/// puts a bare glyph there. A 44pt target round a quiet mark.
struct StoryGlyph: View {
    let systemName: String
    let tint: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { Self.label(systemName, tint: tint) }
            .buttonStyle(.press)
            .accessibilityLabel(label)
    }

    static func label(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(Typography.headerMedium)
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

/// **The night's words, a page of the story** (2026-10-16): High, Low and
/// Buffalo, each its name small above its line, on a dark card the size of
/// a photograph, so it sits among them as one of them. A reply from here is
/// a reply to their day, which is how a close friend's evening starts a
/// conversation.
///
/// **Made yours** (the owner, 2026-10-16: "like Instagram, where you can
/// easily doodle, add stickers, in a full screen editing format"): one of
/// tonight's photographs behind it, dimmed so the words read, and the
/// page's ink and stickers over it as one picture (`StoryPageEditor`). One
/// view, so the page you make is the page your friends see.
struct StoryWordsPage<Picture: View, Art: View>: View {
    let high: String?
    let low: String?
    let buffalo: String?
    var hasPicture = false
    @ViewBuilder var picture: (CGSize) -> Picture
    @ViewBuilder var art: (CGSize) -> Art

    /// The page's shape, the story card's: the editor draws at it.
    static var aspect: CGFloat { 9 / 16 }
    /// **The page is laid out once, at this size, and scaled to the card**
    /// (the review, 2026-10-16: on a friend's taller card the words wrapped
    /// differently and a circle drawn round one missed it). The words and
    /// the ink scale together, filling the card as a photograph does, so
    /// what you drew round a word is round it on every phone.
    static var page: CGSize { CGSize(width: 360, height: 640) }

    var body: some View {
        GeometryReader { geo in
            let k = max(geo.size.width / Self.page.width, geo.size.height / Self.page.height)
            ZStack {
                Color(white: 0.09)
                if hasPicture {
                    picture(geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    Color.black.opacity(0.45)
                }
                ZStack {
                    VStack(alignment: .leading, spacing: GridConstants.gapSection) {
                        Spacer(minLength: 0)
                        if let high { row(StoryLine.high, high) }
                        if let low { row(StoryLine.low, low) }
                        if let buffalo { row(StoryLine.buffalo, buffalo) }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, GridConstants.gapWide + 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    art(Self.page)
                        .frame(width: Self.page.width, height: Self.page.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .frame(width: Self.page.width, height: Self.page.height)
                .scaleEffect(k)
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .clipped()
        }
    }

    private func row(_ name: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            Text(name)
                .font(Typography.headerSmall)
                .foregroundStyle(Color.white.opacity(0.6))
            Text(text)
                .font(Typography.headerMedium)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension StoryWordsPage where Art == EmptyView {
    init(high: String?, low: String?, buffalo: String?, hasPicture: Bool = false,
         @ViewBuilder picture: @escaping (CGSize) -> Picture) {
        self.init(high: high, low: low, buffalo: buffalo, hasPicture: hasPicture, picture: picture) { _ in EmptyView() }
    }
}

/// A page's picture from a file on this phone: the art over the words.
struct StoryArtImage: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await Task.detached(priority: .userInitiated) { Self.decode(url) }.value
        }
    }

    /// **Never decoded whole** (the review, 2026-10-16): a friend's file could
    /// claim a huge size; read through ImageIO at no more than the page's
    /// own longest edge, as `CrewPhotoView` reads a photo.
    nonisolated static func decode(_ url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
