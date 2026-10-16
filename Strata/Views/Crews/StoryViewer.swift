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
                StoryPage(person: person, isCurrent: shown == person.id, dragging: drop > 0,
                          next: { step(from: person.id, by: 1) },
                          back: { step(from: person.id, by: -1) },
                          close: onClose)
                    .tag(person.id)
            }
            // **A finish line** (Instagram's "You're all caught up", 2018):
            // the evening is finite, and this says it is done.
            if hasEnd {
                StoryEnd(close: onClose)
                    .tag(Self.endID)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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
        .background { WarmBackground().ignoresSafeArea() }
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
        // Nobody left to show (all blocked, hidden or past 9am): close.
        .onChange(of: people.isEmpty) { _, empty in if empty { onClose() } }
        .onChange(of: people.map(\.id)) { _, ids in
            if shown != Self.endID, !ids.contains(shown), let first = ids.first { current = first }
        }
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
    let next: () -> Void
    let back: () -> Void
    let close: () -> Void

    @State private var page = 0
    @State private var held = false
    /// The reaction bar, Reply, a doodle or a sticker is open: the story waits.
    @State private var busy = false
    @State private var reporting: SharedWin?
    @State private var blocking = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorScheme) private var scheme

    private var store: SocialStore { SocialStore.shared }
    private var mine: Bool { person.profileID == store.me }
    private var story: CrewStory { person.stories[min(page, person.stories.count - 1)] }
    private let hPad = GridConstants.horizontalPadding

    /// How long a page stands before the next.
    static let pageLength: TimeInterval = 5

    private var paused: Bool {
        held || busy || dragging || !isCurrent || scenePhase != .active || reporting != nil || blocking || voiceOver
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
                .overlay(alignment: .top) { top }
                .overlay(alignment: .bottomLeading) { label }
            foot
                .padding(.horizontal, hPad)
                .padding(.top, GridConstants.gapTight)
                .padding(.bottom, GridConstants.gapTight)
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
        // Back to the first page not yet watched, as a story resumes.
        .onChange(of: isCurrent, initial: true) { _, now in
            busy = false
            guard now else { return }
            page = person.stories.firstIndex { !store.storiesSeen.contains($0.id) } ?? 0
            seen()
        }
        .onChange(of: page) {
            busy = false
            seen()
        }
    }

    private func seen() {
        guard isCurrent, !mine else { return }
        store.markStorySeen(story.id)
    }

    private func forward() {
        if page + 1 < person.stories.count { page += 1 } else { next() }
    }

    private func backward() {
        if page > 0 { page -= 1 } else { back() }
    }

    // MARK: The top

    /// Over the top of the picture, in white, on a short shade of the
    /// picture itself so the words read on a bright sky.
    private var top: some View {
        VStack(spacing: GridConstants.gapTight) {
            StoryProgress(count: person.stories.count, index: page, paused: paused,
                          length: Self.pageLength, finished: forward)
                .id("\(person.id)-\(page)-\(isCurrent)")
                .padding(.top, GridConstants.gapTight)
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
                Spacer(minLength: 0)
                // The same glass circles as the bar at the foot, the chat's +
                // and every viewer's close (the owner, 2026-10-16: "the
                // reactions and buttons should feel the same").
                actions
                GlassIconButton(systemName: "xmark", accessibilityLabel: "Close story", action: close)
            }
            .buttonStyle(.plain)
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
            if mine {
                Button(role: .destructive) {
                    let id = story.id
                    Task { await store.withdrawStory(winID: id) }
                    if person.stories.count == 1 { close() } else { forward() }
                } label: {
                    Label("Take Off Story", systemImage: "minus.circle")
                }
            } else {
                Button {
                    store.hideStory(of: person.profileID, day: story.day)
                    next()
                } label: {
                    Label("Hide Their Story", systemImage: "eye.slash")
                }
                Button(role: .destructive) { reporting = story.win } label: {
                    Label("Report", systemImage: "exclamationmark.bubble")
                }
                Button(role: .destructive) { blocking = true } label: {
                    Label("Block", systemImage: "hand.raised")
                }
            }
        } label: {
            GlassIconLabel(systemName: "ellipsis", tint: .primary)
        }
        .accessibilityLabel("Story actions")
    }

    // MARK: The picture

    private var card: some View {
        GeometryReader { geo in
            // The camera's own card (`CameraView`'s `radiusSurface`).
            let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
            Group {
                if let url = story.win.photo {
                    CrewPhotoView(url: url, width: geo.size.width, height: geo.size.height,
                                  crop: CGPoint(x: story.win.cropX ?? 0, y: story.win.cropY ?? 0))
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
            .id(story.id)
            .transition(.opacity)
            // **Tap on, tap back, hold to pause.** The left third goes back,
            // as every story does; the rest goes on.
            .contentShape(shape)
            .onTapGesture(coordinateSpace: .local) { point in
                HapticsEngine.tick()
                if point.x < geo.size.width / 3 { backward() } else { forward() }
            }
            .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 24, perform: {}, onPressingChanged: { pressing in
                held = pressing
            })
        }
        .animation(GridConstants.crossFade, value: story.id)
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
        var parts = ["\(mine ? "Your story" : "\(name)'s story"), \(page + 1) of \(person.stories.count)"]
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
        if page == 0, let line = person.line { return "\u{201C}\(line)\u{201D}" }
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
            MyStoryReactions(reactions: store.reactionsToMyWins()[story.id] ?? [])
                .frame(maxWidth: .infinity, minHeight: 44)
        } else if store.canReply() {
            StoryReplyBar(story: story, name: name, busy: { busy = $0 })
                .id(story.id)
        }
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
    let finished: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var last: Date?
    @State private var done = false

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    GeometryReader { geo in
                        Capsule().fill(Color.white.opacity(0.35))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.white)
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
    /// "Sent", for a moment, where the words were.
    @State private var said: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var store: SocialStore { SocialStore.shared }
    private var motion: Animation { reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy }
    private var open: Bool { writing || doodling || choosingSticker || makingSticker }

    var body: some View {
        VStack(spacing: GridConstants.gapTight) {
            if writing {
                ReactionBar(mine: store.myReaction(to: story.id, in: story.win.crewID)) { emoji in
                    Task { await store.reactToStory(emoji, story: story) }
                    done("Sent")
                }
                .transition(.opacity)
            }
            HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
                PlusMenu {
                    if store.photosAllowed() {
                        Button { choosingSticker = true } label: { Label("Send a Sticker", systemImage: "face.smiling") }
                    }
                    Button { doodling = true } label: { Label("Send a Doodle", systemImage: "scribble") }
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
                GlassIconButton(systemName: "arrow.up", onPage: true, accessibilityLabel: "Send", action: send)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Task { _ = await store.doodle(png, to: story.id, in: story.win.crewID) }
                done("Sent")
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
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(motion) { said = nil }
        }
    }
}

/// **The end of tonight's stories**: one line and a way out. No count, no
/// list of who posted, nothing more to see.
private struct StoryEnd: View {
    let close: () -> Void

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
            Spacer()
            PrimaryCapsule(title: "Done", action: close)
                .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.bottom, GridConstants.gapItem)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { WarmBackground().ignoresSafeArea() }
    }
}
